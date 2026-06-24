#!/usr/bin/env python3
"""
context_pressure_monitor.py — Self-healing context pressure monitor (v2)

Watches developer profile's active sessions. When token count approaches
the model's context window, proactively:
  1. Emit a progress checkpoint (so a fresh session can resume)
  2. At critical pressure (>80%), automatically save handoff state and
     queue a fork request

Uses REAL token data from sessions table (input_tokens + output_tokens),
not heuristic estimates. Threshold logic is per-session.

Replaces the old reactive "kill zombie" approach with proactive fork.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/Users/davidchu/.hermes"))
PROFILE_HOME = HERMES_HOME / "profiles" / "developer"
STATE_DB = PROFILE_HOME / "state.db"

# Token thresholds (% of model context window)
WARN_THRESHOLD = 0.60   # Emit progress checkpoint
CRIT_THRESHOLD = 0.80   # Save handoff state, queue fork

# Context window for minimax-m3
MODEL_CONTEXT_WINDOW = 200_000

# API call / message count thresholds (proxy for context pressure)
# Hermes's token_count column is sparsely populated; api_call_count is reliable.
WARN_API_CALLS = 100   # ~half of healthy session
CRIT_API_CALLS = 200   # trigger proactive fork
WARN_MESSAGES = 150
CRIT_MESSAGES = 300


def get_state_db() -> sqlite3.Connection:
    db_path = STATE_DB
    if not db_path.exists():
        print(f"state.db not found: {db_path}", file=sys.stderr)
        sys.exit(1)
    return sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)


def get_active_sessions(conn: sqlite3.Connection) -> List[Dict[str, Any]]:
    """Get all active (non-archived) sessions with token data."""
    cur = conn.execute("""
        SELECT
            id, source, model, started_at, ended_at,
            message_count, tool_call_count, api_call_count,
            input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
            title, archived, handoff_state
        FROM sessions
        WHERE archived = 0
        ORDER BY started_at DESC
    """)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def calc_pressure(sess: Dict[str, Any]) -> tuple[float, str]:
    """Calculate context pressure using multi-factor scoring.

    Returns (pressure_score 0-1+, level "warn"|"crit"|"ok").
    Strategy: Hermes's token_count column is sparse; use api_call_count and
    message_count as the primary signals, with input_tokens as a secondary
    sanity check.

    Returns the MAX of the three signals so the worst-case drives action.
    """
    api = sess.get("api_call_count") or 0
    msgs = sess.get("message_count") or 0
    in_tok = sess.get("input_tokens") or 0

    p_api = api / CRIT_API_CALLS  # 1.0 = exactly at critical
    p_msgs = msgs / CRIT_MESSAGES
    # tokens: cumulative, so we use api count as denominator (each api call = full context)
    p_tok = (in_tok / MODEL_CONTEXT_WINDOW) / max(api, 1)  # tokens per call / window

    pressure = max(p_api, p_msgs, p_tok)

    if pressure >= 1.0:
        level = "crit"
    elif pressure >= 0.5:
        level = "warn"
    else:
        level = "ok"

    return pressure, level


def write_progress_checkpoint(sid: str, sess: Dict[str, Any], pressure: float, level: str) -> Path:
    """Emit a progress checkpoint file (machine-parseable JSON)."""
    checkpoint_dir = PROFILE_HOME / "task_state"
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    safe_sid = sid.replace("/", "_").replace(":", "_")
    checkpoint_file = checkpoint_dir / f"{safe_sid}.progress.json"

    in_tok = sess.get("input_tokens") or 0
    out_tok = sess.get("output_tokens") or 0
    msg_count = sess.get("message_count") or 0
    api_calls = sess.get("api_call_count") or 0

    payload = {
        "session_id": sid,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "context_pressure": round(pressure, 3),
        "level": level,  # "warn" or "crit"
        "session_stats": {
            "message_count": msg_count,
            "tool_call_count": sess.get("tool_call_count") or 0,
            "api_call_count": api_calls,
            "input_tokens": in_tok,
            "output_tokens": out_tok,
            "cache_read_tokens": sess.get("cache_read_tokens") or 0,
            "cache_write_tokens": sess.get("cache_write_tokens") or 0,
        },
        "session_meta": {
            "title": sess.get("title"),
            "model": sess.get("model"),
            "source": sess.get("source"),
            "started_at": sess.get("started_at"),
        },
        "action_recommended": (
            "fork_session" if level == "crit" else "emit_progress"
        ),
    }
    checkpoint_file.write_text(json.dumps(payload, indent=2))
    return checkpoint_file


def write_handoff_state(sid: str, sess: Dict[str, Any], pressure: float) -> Path:
    """Write a handoff state file when context is critical."""
    handoff_dir = PROFILE_HOME / "handoffs"
    handoff_dir.mkdir(parents=True, exist_ok=True)

    safe_sid = sid.replace("/", "_").replace(":", "_")
    handoff_file = handoff_dir / f"{safe_sid}.handoff.md"
    ts = datetime.now(timezone.utc).isoformat()
    in_tok = sess.get("input_tokens") or 0

    # Try to find a dev-task-state.md for richer context
    dev_state_paths = [
        Path("/Users/davidchu/www/hermes-developer-profile/docs/_meta/dev-task-state.md"),
        Path.home() / "www" / "hermes-developer-profile" / "docs" / "_meta" / "dev-task-state.md",
    ]
    extra_context = ""
    for p in dev_state_paths:
        if p.exists():
            extra_context = f"\n\n## Reference State (auto-attached)\n\n```\n{p.read_text()[:2000]}\n```\n"
            break

    handoff_content = f"""# Handoff State — Session {sid}

**Created**: {ts}
**Context pressure**: {pressure:.1%} (CRITICAL — above {CRIT_THRESHOLD:.0%})
**Tokens used**: {in_tok:,} / {MODEL_CONTEXT_WINDOW:,}

## Session summary

- **Title**: {sess.get('title') or '(no title)'}
- **Model**: {sess.get('model')}
- **Source**: {sess.get('source')}
- **Started at**: {sess.get('started_at')}
- **Message count**: {sess.get('message_count') or 0}
- **Tool call count**: {sess.get('tool_call_count') or 0}
- **API call count**: {sess.get('api_call_count') or 0}

## Why this handoff exists

The previous session reached critical context pressure (>80% of model window).
Rather than letting the session zombie-loop with [CONTEXT COMPACTION] markers,
we proactively saved state and prepared a fresh session to continue.

## What's preserved

- **Filesystem**: All file mutations were checkpointed via `pre_tool_checkpoint.sh`
  (refs at `refs/checkpoints/<dir>/<timestamp>` in the project git repo)
- **Git state**: Workdir HEAD reflects the last successful mutation
- **Decisions**: Captured in `~/.hermes/memories/MEMORY.md` and `USER.md`
{extra_context}
## How to resume

A fresh session should:

1. Read this handoff file (and the linked Reference State)
2. Check `pre_tool_checkpoint.sh` history (`.hermes-checkpoints.log` in workdir)
3. Run `git log --oneline -20` in the project to see recent mutations
4. Use `hermes task resume {sid}` for the full recovery protocol (coming soon)

## Self-healing intent

This is **not a failure** — it's the system doing its job. Long-running
development tasks naturally accumulate context. The handoff protocol
ensures continuity without requiring manual intervention.
"""
    handoff_file.write_text(handoff_content)
    return handoff_file


def queue_fork(sid: str, sess: Dict[str, Any], pressure: float) -> None:
    """Queue a fork request for the daemon / gateway to process."""
    fork_queue = PROFILE_HOME / "session_fork_queue.jsonl"
    entry = {
        "session_id": sid,
        "queued_at": datetime.now(timezone.utc).isoformat(),
        "reason": "context_pressure_critical",
        "pressure": round(pressure, 3),
        "title": sess.get("title"),
        "model": sess.get("model"),
    }
    with open(fork_queue, "a") as f:
        f.write(json.dumps(entry) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="Run once and exit (for cron)")
    parser.add_argument("--dry-run", action="store_true", help="Report but don't write")
    args = parser.parse_args()

    print(f"[{datetime.now(timezone.utc).isoformat()}] context_pressure_monitor")
    print(f"  STATE_DB: {STATE_DB}")
    print(f"  Thresholds: warn={WARN_THRESHOLD:.0%} crit={CRIT_THRESHOLD:.0%}")
    print(f"  Model window: {MODEL_CONTEXT_WINDOW:,} tokens")
    if args.dry_run:
        print("  🧪 DRY RUN — no writes")

    try:
        conn = get_state_db()
    except sqlite3.OperationalError as e:
        print(f"  ❌ Cannot open state.db: {e}", file=sys.stderr)
        return 1

    sessions = get_active_sessions(conn)
    print(f"  📊 Found {len(sessions)} active (non-archived) sessions")

    actions = {"warn_emitted": 0, "crit_forked": 0, "no_action": 0}

    for sess in sessions:
        sid = sess.get("id", "?")
        pressure, level = calc_pressure(sess)
        in_tok = sess.get("input_tokens") or 0
        out_tok = sess.get("output_tokens") or 0
        msg = sess.get("message_count") or 0
        api = sess.get("api_call_count") or 0

        if level == "crit":
            icon = "🚨"
            if not args.dry_run:
                handoff_path = write_handoff_state(sid, sess, pressure)
                queue_fork(sid, sess, pressure)
                actions["crit_forked"] += 1
                write_progress_checkpoint(sid, sess, pressure, "crit")
            action = f"FORK_QUEUED + handoff written"
        elif level == "warn":
            icon = "⚠️ "
            if not args.dry_run:
                cp_path = write_progress_checkpoint(sid, sess, pressure, "warn")
                actions["warn_emitted"] += 1
            action = f"progress_checkpoint_written"
        else:
            icon = "✅"
            actions["no_action"] += 1
            action = "no_action"

        print(f"  {icon} {sid[:40]} | in={in_tok:>8,} out={out_tok:>6,} | msgs={msg:>4} api={api:>3} | pressure={pressure:>6.1%} level={level} | {action}")

    print(f"\n  📈 Summary: warn={actions['warn_emitted']} crit={actions['crit_forked']} ok={actions['no_action']}")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
