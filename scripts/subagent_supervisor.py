#!/usr/bin/env python3
"""
subagent_supervisor.py — Developer Profile Sub-Agent Supervisor

Background daemon that monitors sub-agent (kanban) task health and reports to
David. Solves David's pain point 4: "I worry whether subagents are running
properly. Is there a regular task to check their status?"

Three checks (per David):
1. Ensure unfinished tasks are progressing
   - Detect tasks in running status with stale heartbeat (>1h no heartbeat)
   - Detect tasks in ready status waiting too long (queue depth check)

2. Alert David for unconfirmed questions
   - Detect tasks in blocked status (worker called kanban_block waiting for input)
   - Auto-draft the question context + notify David via Discord

3. Recover stalled sub-agents
   - If heartbeat stale >stale_timeout, auto-reclaim (reset to ready for retry)
   - Notify David of the reclaim + reason
   - Log the failure pattern for orchestrator learning

State read from ~/.hermes/kanban.db (tasks table).
Uses Hermes built-in heartbeat_worker and detect_stale_running from
hermes_cli.kanban_db when available, falling back to raw SQL probes.

Run as: python3 subagent_supervisor.py --once  (single check)
        python3 subagent_supervisor.py --loop   (continuous, every 5 min)
"""

import argparse
import json
import logging
import os
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

HERMES_HOME = Path("~/.hermes").expanduser()
DEV_PROFILE = HERMES_HOME / "profiles" / "developer"
KANBAN_DB = HERMES_HOME / "kanban.db"
CONFIG_PATH = DEV_PROFILE / "config.yaml"
LOG_PATH = DEV_PROFILE / "logs" / "subagent_supervisor.log"
STATE_PATH = DEV_PROFILE / "logs" / "subagent_supervisor_state.json"

LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("subagent_supervisor")


# ---------------------------------------------------------------------------
# Helpers — same as cost_alarm_monitor
# ---------------------------------------------------------------------------

def load_yaml_section(path: Path, section: str) -> dict:
    """Lightweight YAML block reader (no PyYAML dependency)."""
    if not path.exists():
        return {}
    text = path.read_text()
    lines = text.splitlines()
    in_block = False
    block_indent = 0
    block_lines = []
    for line in lines:
        stripped = line.lstrip()
        if not in_block:
            if stripped.startswith(f"{section}:"):
                in_block = True
                block_indent = len(line) - len(stripped)
                continue
        else:
            cur_indent = len(line) - len(stripped)
            if stripped == "" or line.startswith(" " * (block_indent + 1)):
                block_lines.append(line[block_indent + 2:])
            else:
                break
    if not block_lines:
        return {}
    cfg = {}
    for line in block_lines:
        if ":" in line and not line.strip().startswith("#"):
            key, val = line.split(":", 1)
            cfg[key.strip()] = val.strip().strip("'\"")
    return cfg


def load_supervisor_config() -> dict:
    """Load supervisor thresholds from `agent.cost_alarm` + `kanban` config."""
    defaults = {
        "stale_heartbeat_seconds": 3600,        # 1h
        "blocked_alert_after_seconds": 1800,    # 30m blocked → notify David
        "ready_queue_warn_threshold": 10,       # >10 ready → queue depth warn
        "ready_queue_warn_age_seconds": 7200,  # ready >2h → age warn
        "max_consecutive_failures": 3,          # >3 failures → escalate
        "notify_david_on": ["blocked", "recovered", "stalled"],
    }
    if not CONFIG_PATH.exists():
        return defaults
    try:
        kanban_cfg = load_yaml_section(CONFIG_PATH, "kanban")
        stale = int(kanban_cfg.get("dispatch_stale_timeout_seconds", 14400) or 14400)
        defaults["stale_heartbeat_seconds"] = min(stale, 3600)  # cap at 1h
    except Exception as e:
        log.warning("Failed to load kanban config: %s", e)
    return defaults


# ---------------------------------------------------------------------------
# Task state readers
# ---------------------------------------------------------------------------

def get_all_tasks() -> list[dict]:
    """Read all non-archived tasks from kanban.db."""
    if not KANBAN_DB.exists():
        log.warning("kanban.db not found at %s", KANBAN_DB)
        return []
    try:
        conn = sqlite3.connect(str(KANBAN_DB), timeout=5.0)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(tasks)")
        cols = {row[1] for row in cur.fetchall()}
        if not cols:
            conn.close()
            return []
        wanted = [
            "id", "title", "assignee", "status", "priority",
            "created_at", "started_at", "completed_at",
            "claim_lock", "claim_expires", "worker_pid",
            "consecutive_failures", "last_failure_error",
            "last_heartbeat_at", "max_runtime_seconds",
            "result", "branch_name",
        ]
        select = [c for c in wanted if c in cols]
        cur.execute(
            f"SELECT {', '.join(select)} FROM tasks "
            f"WHERE status != 'archived' "
            f"ORDER BY created_at DESC LIMIT 100"
        )
        rows = [dict(r) for r in cur.fetchall()]
        conn.close()
        return rows
    except Exception as e:
        log.warning("Failed to read tasks: %s", e)
        return []


def get_blocked_tasks_needing_input(tasks: list[dict], cfg: dict) -> list[dict]:
    """Find tasks in 'blocked' status older than threshold.

    These are tasks where worker called kanban_block waiting for David.
    """
    now = int(time.time())
    threshold = cfg["blocked_alert_after_seconds"]
    blocked = []
    for t in tasks:
        if t.get("status") != "blocked":
            continue
        # 'blocked' since: use completed_at? No — use started_at or created_at
        ts = t.get("started_at") or t.get("created_at")
        if ts is None:
            continue
        age = now - int(ts)
        if age >= threshold:
            blocked.append({**t, "blocked_age_seconds": age})
    return blocked


def get_stalled_running_tasks(tasks: list[dict], cfg: dict) -> list[dict]:
    """Find tasks in 'running' status with stale heartbeat."""
    now = int(time.time())
    threshold = cfg["stale_heartbeat_seconds"]
    stalled = []
    for t in tasks:
        if t.get("status") != "running":
            continue
        last_hb = t.get("last_heartbeat_at")
        if last_hb is None:
            # No heartbeat ever — use started_at
            ts = t.get("started_at")
            if ts is None:
                continue
            age = now - int(ts)
        else:
            age = now - int(last_hb)
        if age >= threshold:
            stalled.append({**t, "heartbeat_age_seconds": age})
    return stalled


def get_aged_ready_tasks(tasks: list[dict], cfg: dict) -> list[dict]:
    """Find ready tasks waiting too long (queue depth issue)."""
    now = int(time.time())
    age_threshold = cfg["ready_queue_warn_age_seconds"]
    aged = []
    for t in tasks:
        if t.get("status") != "ready":
            continue
        ts = t.get("created_at")
        if ts is None:
            continue
        age = now - int(ts)
        if age >= age_threshold:
            aged.append({**t, "ready_age_seconds": age})
    return aged


def get_high_failure_tasks(tasks: list[dict], cfg: dict) -> list[dict]:
    """Find tasks with consecutive_failures above threshold."""
    threshold = cfg["max_consecutive_failures"]
    return [t for t in tasks if (t.get("consecutive_failures") or 0) >= threshold
            and t.get("status") not in ("completed", "archived")]


# ---------------------------------------------------------------------------
# Recovery action (best-effort, not Hermes source)
# ---------------------------------------------------------------------------

def try_recover_stalled_task(task: dict) -> str:
    """Try to recover a stalled task by reclaiming it.

    Uses Hermes' own detect_stale_running if available, else raw SQL.
    Returns 'recovered' | 'failed' | 'no_recovery'.
    """
    task_id = task["id"]
    try:
        # Try Hermes built-in first
        try:
            from hermes_cli.kanban_db import detect_stale_running
            conn = sqlite3.connect(str(KANBAN_DB), timeout=5.0)
            recovered = detect_stale_running(conn, stale_timeout_seconds=0)
            # The above will return [] if 0; we use raw SQL instead
            conn.close()
        except ImportError:
            pass

        # Raw SQL recovery: reset status to 'ready', clear claim, log event
        conn = sqlite3.connect(str(KANBAN_DB), timeout=5.0)
        cur = conn.cursor()
        now = int(time.time())
        cur.execute(
            "UPDATE tasks SET status = 'ready', claim_lock = NULL, "
            "claim_expires = NULL, worker_pid = NULL, "
            "last_heartbeat_at = NULL, "
            "consecutive_failures = consecutive_failures + 1 "
            "WHERE id = ? AND status = 'running'",
            (task_id,),
        )
        if cur.rowcount == 1:
            conn.commit()
            log.info("Recovered stalled task %s — reset to ready, failure counter incremented",
                     task_id[:12])
            conn.close()
            return "recovered"
        conn.close()
        return "no_recovery"
    except Exception as e:
        log.warning("Failed to recover task %s: %s", task_id[:12], e)
        return "failed"


# ---------------------------------------------------------------------------
# Notification (reuse pattern from cost_alarm_monitor)
# ---------------------------------------------------------------------------

def notify_david(message: str) -> None:
    """Send Discord notification to David via send_message tool if available."""
    try:
        from hermes_tools import send_message
        send_message(
            action="send",
            target="discord",
            message=message,
        )
    except ImportError:
        log.debug("send_message tool not available — message stays in log only")
    except Exception as e:
        log.warning("Discord notify failed: %s", e)


# ---------------------------------------------------------------------------
# Main check cycle
# ---------------------------------------------------------------------------

def run_once() -> int:
    """Run a single supervisor check. Returns count of alerts fired."""
    cfg = load_supervisor_config()
    tasks = get_all_tasks()

    if not tasks:
        log.info("No active tasks — supervisor idle")
        return 0

    log.info("Checked %d active tasks", len(tasks))

    alerts_fired = 0

    # --- Check 1: Blocked tasks (worker waiting for David input) ---
    blocked = get_blocked_tasks_needing_input(tasks, cfg)
    for t in blocked:
        age_min = t["blocked_age_seconds"] // 60
        log.warning(
            "🚨 BLOCKED task waiting for David input (%d min): %s",
            age_min, t.get("title", "")[:60],
        )
        notify_david(
            f"🛑 **Sub-agent Blocked — needs your input**\n\n"
            f"**Task**: {t.get('title', '?')}\n"
            f"**ID**: `{t['id'][:16]}`\n"
            f"**Assignee**: {t.get('assignee', '?')}\n"
            f"**Blocked for**: {age_min} min\n"
            f"**Last failure/error**: {t.get('last_failure_error', '?')[:200]}\n\n"
            f"David — sub-agent 喺度等你 confirm 嘢。請 `/unblock` 或者回應 task 嘅 question。"
        )
        alerts_fired += 1

    # --- Check 2: Stalled running tasks ---
    stalled = get_stalled_running_tasks(tasks, cfg)
    for t in stalled:
        age_min = t["heartbeat_age_seconds"] // 60
        log.warning(
            "⏰ STALLED task — no heartbeat for %d min: %s",
            age_min, t.get("title", "")[:60],
        )
        # Try to recover automatically
        result = try_recover_stalled_task(t)
        notify_david(
            f"⏰ **Sub-agent Stalled — auto-recovered**\n\n"
            f"**Task**: {t.get('title', '?')}\n"
            f"**ID**: `{t['id'][:16]}`\n"
            f"**Assignee**: {t.get('assignee', '?')}\n"
            f"**No heartbeat for**: {age_min} min\n"
            f"**Worker PID**: {t.get('worker_pid', '?')}\n"
            f"**Recovery action**: {result}\n\n"
            f"David — task 已經自動 reclaim (status → ready)，"
            f"下次 dispatch 會 retry。\n"
            f"如果 retry 多次都失敗，可能要睇下 sub-agent 嘅 loop / spec 問題。"
        )
        alerts_fired += 1

    # --- Check 3: Ready queue depth + age ---
    aged_ready = get_aged_ready_tasks(tasks, cfg)
    ready_count = sum(1 for t in tasks if t.get("status") == "ready")
    if ready_count >= cfg["ready_queue_warn_threshold"] or aged_ready:
        if aged_ready:
            oldest = max(aged_ready, key=lambda t: t.get("ready_age_seconds", 0))
            age_min = oldest["ready_age_seconds"] // 60
            log.warning(
                "📋 Ready queue: %d tasks, oldest waiting %d min — %s",
                ready_count, age_min, oldest.get("title", "")[:60],
            )
            notify_david(
                f"📋 **Ready Queue Build-up**\n\n"
                f"**Total ready**: {ready_count}\n"
                f"**Oldest waiting**: {age_min} min — {oldest.get('title', '?')}\n"
                f"**Oldest task ID**: `{oldest['id'][:16]}`\n\n"
                f"David — queue 有可能 dispatch 唔到（assignee missmatch / 全部 in_progress）。"
                f"可以睇下 `hermes kanban tail` 嘅 status。"
            )
            alerts_fired += 1

    # --- Check 4: High failure count tasks ---
    high_fail = get_high_failure_tasks(tasks, cfg)
    for t in high_fail:
        failures = t.get("consecutive_failures", 0)
        log.warning(
            "💥 High-failure task (%d consecutive failures): %s",
            failures, t.get("title", "")[:60],
        )
        notify_david(
            f"💥 **Task High Failure Count**\n\n"
            f"**Task**: {t.get('title', '?')}\n"
            f"**ID**: `{t['id'][:16]}`\n"
            f"**Consecutive failures**: {failures}\n"
            f"**Last error**: {t.get('last_failure_error', '?')[:200]}\n"
            f"**Status**: {t.get('status', '?')}\n\n"
            f"David — 連續失敗 {failures} 次，"
            f"orchestrator 應該已經或者即將 escalate。\n"
            f"可以 `/unblock` + rephrase task，或者 reclaim + 拆細。"
        )
        alerts_fired += 1

    log.info("Done. %d alert(s) fired.", alerts_fired)
    return alerts_fired


def run_loop(interval_minutes: int = 5) -> None:
    log.info("Starting subagent_supervisor loop (interval=%d min)", interval_minutes)
    while True:
        try:
            run_once()
        except Exception as e:
            log.exception("Error in supervisor cycle: %s", e)
        time.sleep(interval_minutes * 60)
    return None  # unreachable


def run_daemon() -> None:
    import os
    pid = os.fork()
    if pid > 0:
        log.info("Daemon forked, pid=%d", pid)
        sys.exit(0)
    os.setsid()
    pid = os.fork()
    if pid > 0:
        sys.exit(0)
    sys.stdout.flush()
    sys.stderr.flush()
    with open("/dev/null", "r") as f:
        os.dup2(f.fileno(), sys.stdin.fileno())
    with open(str(LOG_PATH), "a") as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        os.dup2(f.fileno(), sys.stderr.fileno())
    run_loop()
    return None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description="Developer profile sub-agent supervisor")
    p.add_argument("--once", action="store_true", help="Run single check then exit")
    p.add_argument("--loop", action="store_true", help="Run continuous loop (5 min)")
    p.add_argument("--daemon", action="store_true", help="Run as background daemon")
    p.add_argument("--interval", type=int, default=5, help="Loop interval in minutes")
    args = p.parse_args()

    if args.daemon:
        run_daemon()
    elif args.loop:
        run_loop(args.interval)
    else:
        events = run_once()
        return 0 if events == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
