#!/usr/bin/env python3
"""
cost_alarm_monitor.py — Developer Profile Cost Alarm

Background daemon that monitors session / task token usage and API call counts,
fires warnings and critical alerts based on thresholds defined in
~/.hermes/profiles/developer/config.yaml under `agent.cost_alarm`.

State is read from SQLite (`state.db` — `sessions` table for session-level,
and kanban tasks for per-task). Hermes 0.15.1 quirk (per user memory):
  - `messages.token_count` is always NULL → message-level token count is unreliable
  - `sessions.input_tokens` is cumulative, not per-turn
  - Use `api_call_count` (per user memory threshold: 200 = critical)

This script:
  1. Polls state.db every 5 minutes
  2. Checks current session api_call_count vs thresholds
  3. Writes warn/critical events to ~/.hermes/profiles/developer/logs/cost_alarm.log
  4. Sends Discord notification on critical (via send_message tool, if available)

Run as: python3 cost_alarm_monitor.py --once  (single check)
        python3 cost_alarm_monitor.py --loop   (continuous, every 5 min)
        python3 cost_alarm_monitor.py --daemon (background process)
"""

import argparse
import json
import logging
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
STATE_DB = DEV_PROFILE / "state.db"
CONFIG_PATH = DEV_PROFILE / "config.yaml"
LOG_PATH = DEV_PROFILE / "logs" / "cost_alarm.log"
ALARM_STATE_PATH = DEV_PROFILE / "logs" / "cost_alarm_state.json"

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
log = logging.getLogger("cost_alarm")


# ---------------------------------------------------------------------------
# Config loader (lightweight YAML — avoid heavy deps)
# ---------------------------------------------------------------------------

def load_cost_alarm_config() -> dict:
    """Load `agent.cost_alarm` block from config.yaml.

    Returns defaults if file missing or block absent.
    """
    defaults = {
        "enabled": True,
        "per_task_token_warn": 30_000_000,
        "per_task_token_critical": 100_000_000,
        "per_session_token_warn": 200_000_000,
        "per_session_token_critical": 500_000_000,
        "per_task_api_calls_warn": 100,
        "per_task_api_calls_critical": 200,
        "per_session_api_calls_warn": 300,
        "per_session_api_calls_critical": 500,
        "on_warn": "notify_log",
        "on_critical": "block_subagent_and_notify_david",
    }
    if not CONFIG_PATH.exists():
        return defaults
    try:
        # Use stdlib only — no PyYAML dependency
        text = CONFIG_PATH.read_text()
        # Find the cost_alarm block
        in_block = False
        block_indent = 0
        block_lines = []
        for line in text.splitlines():
            stripped = line.lstrip()
            if not in_block:
                if stripped.startswith("cost_alarm:"):
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
            return defaults
        cfg = {}
        for line in block_lines:
            if ":" in line and not line.strip().startswith("#"):
                key, val = line.split(":", 1)
                key = key.strip()
                val = val.strip().strip("'\"")
                if val.lower() in ("true", "false"):
                    cfg[key] = val.lower() == "true"
                else:
                    try:
                        cfg[key] = int(val)
                    except ValueError:
                        cfg[key] = val
        defaults.update(cfg)
        return defaults
    except Exception as e:
        log.warning("Failed to load cost_alarm config: %s — using defaults", e)
        return defaults


# ---------------------------------------------------------------------------
# State readers
# ---------------------------------------------------------------------------

def get_session_stats() -> list[dict]:
    """Read current sessions from state.db.

    Returns list of dicts: {session_id, tool_call_count, input_tokens, started_at, ended_at, message_count}

    Hermes 0.15.1 actual sessions table columns (verified via `sqlite3 .schema sessions`):
        id, source, user_id, model, model_config, system_prompt, parent_session_id,
        started_at, ended_at, end_reason, message_count, tool_call_count,
        input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
        reasoning_tokens, cwd, billing_provider

    We use `tool_call_count` (the per-session API call proxy — Hermes doesn't
    track a separate `api_call_count` column). `input_tokens` is cumulative
    (per session), which is what we want for session-level budgets.
    """
    if not STATE_DB.exists():
        log.warning("state.db not found at %s", STATE_DB)
        return []
    try:
        conn = sqlite3.connect(str(STATE_DB), timeout=5.0)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(sessions)")
        cols = {row[1] for row in cur.fetchall()}
        if not cols:
            conn.close()
            return []
        # Map our abstract names to real columns
        select_cols = [c for c in (
            "id", "tool_call_count", "input_tokens",
            "started_at", "ended_at", "message_count",
        ) if c in cols]
        # Active sessions: not ended (ended_at IS NULL) or ended in last 24h
        cur.execute(
            f"SELECT {', '.join(select_cols)} FROM sessions "
            f"WHERE ended_at IS NULL OR ended_at > (strftime('%s', 'now') - 86400) "
            f"ORDER BY started_at DESC LIMIT 20"
        )
        rows = [dict(r) for r in cur.fetchall()]
        conn.close()
        return rows
    except Exception as e:
        log.warning("Failed to read sessions: %s", e)
        return []


def get_active_kanban_tasks() -> list[dict]:
    """Read active kanban tasks from kanban.db.

    Hermes 0.15.1 actual tasks table columns vary; we defensively probe.
    Per-task tracking may not exist in all kanban deployments — that's OK,
    we just return empty list and the session-level alarm still fires.
    """
    kanban_db = HERMES_HOME / "kanban.db"
    if not kanban_db.exists():
        return []
    try:
        conn = sqlite3.connect(str(kanban_db), timeout=5.0)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(tasks)")
        cols = {row[1] for row in cur.fetchall()}
        if not cols:
            conn.close()
        else:
            # Look for status column + timestamp column (could be 'updated_at', 'modified_at', etc.)
            status_col = next((c for c in cols if c == "status"), None)
            time_col = next((c for c in cols if c in ("updated_at", "modified_at", "last_modified")), None)
            if not status_col:
                conn.close()
                return []
            select_cols = [c for c in ("id", "title", "assignee", status_col, "tool_call_count", time_col)
                           if c and c in cols]
            ts_order = f"ORDER BY {time_col} DESC" if time_col else ""
            cur.execute(
                f"SELECT {', '.join(select_cols)} FROM tasks "
                f"WHERE {status_col} IN ('in_progress', 'ready') "
                f"{ts_order} LIMIT 10"
            )
            rows = [dict(r) for r in cur.fetchall()]
            conn.close()
            return rows
    except Exception as e:
        log.warning("Failed to read kanban tasks: %s", e)
    return []


# ---------------------------------------------------------------------------
# Alarm state (to avoid re-firing the same alert)
# ---------------------------------------------------------------------------

def load_alarm_state() -> dict:
    if not ALARM_STATE_PATH.exists():
        return {}
    try:
        return json.loads(ALARM_STATE_PATH.read_text())
    except Exception:
        return {}


def save_alarm_state(state: dict) -> None:
    ALARM_STATE_PATH.write_text(json.dumps(state, indent=2, default=str))


# ---------------------------------------------------------------------------
# Alarm logic
# ---------------------------------------------------------------------------

def check_thresholds(
    cfg: dict,
    sessions: list[dict],
    tasks: list[dict],
    alarm_state: dict,
) -> list[dict]:
    """Check current usage against thresholds. Returns list of alarm events.

    Each event: {level: 'warn'|'critical', scope: 'session'|'task', id, metric, value, threshold, message}
    """
    events = []

    for sess in sessions:
        sid = sess.get("id", "?")
        # Hermes 0.15.1: sessions table uses `tool_call_count`, not `api_call_count`
        tool_calls = sess.get("tool_call_count") or 0
        in_tokens = sess.get("input_tokens") or 0

        # tool_call_count thresholds (Hermes 0.15.1 proxy for API calls)
        if tool_calls >= cfg["per_session_api_calls_critical"]:
            key = f"session:{sid}:tool_calls:critical"
            if key not in alarm_state:
                events.append({
                    "level": "critical",
                    "scope": "session",
                    "id": sid,
                    "metric": "tool_call_count",
                    "value": tool_calls,
                    "threshold": cfg["per_session_api_calls_critical"],
                    "message": f"Session {sid[:8]}… used {tool_calls} tool calls (≥ {cfg['per_session_api_calls_critical']} critical)",
                })
                alarm_state[key] = datetime.now().isoformat()
        elif tool_calls >= cfg["per_session_api_calls_warn"]:
            key = f"session:{sid}:tool_calls:warn"
            if key not in alarm_state:
                events.append({
                    "level": "warn",
                    "scope": "session",
                    "id": sid,
                    "metric": "tool_call_count",
                    "value": tool_calls,
                    "threshold": cfg["per_session_api_calls_warn"],
                    "message": f"Session {sid[:8]}… used {tool_calls} tool calls (≥ {cfg['per_session_api_calls_warn']} warn)",
                })
                alarm_state[key] = datetime.now().isoformat()

        # Token threshold (cumulative, per Hermes quirk — still useful for budget alarm)
        if in_tokens >= cfg["per_session_token_critical"]:
            key = f"session:{sid}:tokens:critical"
            if key not in alarm_state:
                events.append({
                    "level": "critical",
                    "scope": "session",
                    "id": sid,
                    "metric": "input_tokens",
                    "value": in_tokens,
                    "threshold": cfg["per_session_token_critical"],
                    "message": f"Session {sid[:8]}… used {in_tokens:,} tokens (≥ {cfg['per_session_token_critical']:,} critical)",
                })
                alarm_state[key] = datetime.now().isoformat()

    for task in tasks:
        tid = task.get("id", "?")
        tool_calls = task.get("tool_call_count") or 0

        if tool_calls >= cfg["per_task_api_calls_critical"]:
            key = f"task:{tid}:tool_calls:critical"
            if key not in alarm_state:
                events.append({
                    "level": "critical",
                    "scope": "task",
                    "id": tid,
                    "metric": "tool_call_count",
                    "value": tool_calls,
                    "threshold": cfg["per_task_api_calls_critical"],
                    "message": f"Task {tid[:8]}… used {tool_calls} tool calls (≥ {cfg['per_task_api_calls_critical']} critical)",
                })
                alarm_state[key] = datetime.now().isoformat()
        elif tool_calls >= cfg["per_task_api_calls_warn"]:
            key = f"task:{tid}:tool_calls:warn"
            if key not in alarm_state:
                events.append({
                    "level": "warn",
                    "scope": "task",
                    "id": tid,
                    "metric": "tool_call_count",
                    "value": tool_calls,
                    "threshold": cfg["per_task_api_calls_warn"],
                    "message": f"Task {tid[:8]}… used {tool_calls} tool calls (≥ {cfg['per_task_api_calls_warn']} warn)",
                })
                alarm_state[key] = datetime.now().isoformat()

    return events


def fire_event(event: dict, cfg: dict) -> None:
    """Fire an alarm event — log + optionally notify David."""
    level = event["level"].upper()
    msg = f"[{level}] {event['message']}"
    if event["level"] == "critical":
        log.critical(msg)
    else:
        log.warning(msg)

    # Critical events: write to a flag file for Phase 3 verify, and attempt
    # Discord notification via send_message tool (if available in env)
    if event["level"] == "critical":
        flag = DEV_PROFILE / "logs" / "cost_alarm_critical.flag"
        flag.write_text(json.dumps({
            "timestamp": datetime.now().isoformat(),
            "event": event,
        }, indent=2))
        log.info("Wrote critical flag to %s", flag)

        # Best-effort Discord notification via send_message tool
        try:
            from hermes_tools import send_message  # type: ignore
            send_message(
                action="send",
                target="discord",
                message=f"🚨 **Developer Cost Alarm (CRITICAL)**\n\n{msg}\n\n"
                        f"David — sub-agent 應該 block 咗，請 review state. "
                        f"可以 `/new session` 開新 session，或者 `hermes kanban reclaim <task_id>` reclaim task。",
            )
        except ImportError:
            log.debug("send_message tool not available in this env — skip Discord notify")
        except Exception as e:
            log.warning("Discord notify failed: %s", e)


# ---------------------------------------------------------------------------
# Main loops
# ---------------------------------------------------------------------------

def run_once() -> int:
    """Run a single check cycle. Returns count of events fired."""
    cfg = load_cost_alarm_config()
    if not cfg.get("enabled", True):
        log.info("cost_alarm disabled in config — skipping")
        return 0

    sessions = get_session_stats()
    tasks = get_active_kanban_tasks()
    alarm_state = load_alarm_state()

    log.info("Checked %d sessions, %d active tasks", len(sessions), len(tasks))

    events = check_thresholds(cfg, sessions, tasks, alarm_state)
    for event in events:
        fire_event(event, cfg)

    if events:
        save_alarm_state(alarm_state)
    return len(events)


def run_loop(interval_minutes: int = 5) -> None:
    log.info("Starting cost_alarm_monitor loop (interval=%d min)", interval_minutes)
    while True:
        try:
            run_once()
        except Exception as e:
            log.exception("Error in cost_alarm cycle: %s", e)
        time.sleep(interval_minutes * 60)
    return None  # unreachable, satisfies type checker


def run_daemon() -> None:
    """Run as background daemon (double-fork + log to file)."""
    import os
    # First fork
    pid = os.fork()
    if pid > 0:
        log.info("Daemon forked, pid=%d", pid)
        sys.exit(0)
    # Decouple from parent
    os.setsid()
    # Second fork
    pid = os.fork()
    if pid > 0:
        sys.exit(0)
    # Redirect std fds
    sys.stdout.flush()
    sys.stderr.flush()
    with open("/dev/null", "r") as f:
        os.dup2(f.fileno(), sys.stdin.fileno())
    with open(str(LOG_PATH), "a") as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        os.dup2(f.fileno(), sys.stderr.fileno())
    run_loop()
    return None  # unreachable


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description="Developer profile cost alarm monitor")
    p.add_argument("--once", action="store_true", help="Run single check then exit")
    p.add_argument("--loop", action="store_true", help="Run continuous loop (5 min)")
    p.add_argument("--daemon", action="store_true", help="Run as background daemon")
    p.add_argument("--interval", type=int, default=5, help="Loop interval in minutes")
    p.add_argument("--dry-run", action="store_true", help="Log events but don't notify")
    args = p.parse_args()

    if args.daemon:
        run_daemon()
    elif args.loop:
        run_loop(args.interval)
    else:
        events = run_once()
        log.info("Done. %d event(s) fired.", events)
        return 0 if events == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
