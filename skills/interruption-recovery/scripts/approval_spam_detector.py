#!/usr/bin/env python3
"""
approval_spam_detector.py — Detect and auto-suspend approval-request loops

On 2026-06-07 David reported: "Developer 又有zombie 了，不斷出「詳細…」"
The root cause: the agent was emitting approval requests every 15-30s, David
clicking "always approve", and the loop never broke.

This script detects that pattern by scanning the gateway log for
"Discord button resolved 1 approval" events in a rolling 5-minute window.
If a single (thread, session) pair sees more than `MAX_APPROVALS_PER_5MIN`,
the session is auto-archived (using Hermes's native archived=1 flag, which
is the only flag the SessionRecoveryManager respects).

Replaces manual intervention ("kill zombie" via Discord) with automatic
detection at the same granularity.
"""

from __future__ import annotations

import argparse
import os
import re
import sqlite3
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/Users/davidchu/.hermes"))
PROFILE_HOME = HERMES_HOME / "profiles" / "developer"
GATEWAY_LOG = PROFILE_HOME / "logs" / "gateway.log"
STATE_DB = PROFILE_HOME / "state.db"
SESSIONS_JSON = PROFILE_HOME / "sessions" / "sessions.json"

# Trigger threshold: more than N approval resolutions in 5 minutes = spam
MAX_APPROVALS_PER_5MIN = 5
WINDOW_SECONDS = 300  # 5 minutes

# Approval line pattern from gateway.log
APPROVAL_PATTERN = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ INFO.*"
    r"Discord button resolved (?P<count>\d+) approval\(s\) for session "
    r"agent:main:discord:thread:(?P<thread_id>\d+):(?P=thread_id)"
)


def parse_recent_approvals() -> List[Dict[str, Any]]:
    """Parse approval events from the last WINDOW_SECONDS of gateway.log."""
    if not GATEWAY_LOG.exists():
        return []

    cutoff = time.time() - WINDOW_SECONDS
    approvals = []

    try:
        # Read last 5MB (enough for 5min of activity)
        file_size = GATEWAY_LOG.stat().st_size
        with open(GATEWAY_LOG, 'rb') as f:
            f.seek(max(0, file_size - 5_000_000))
            content = f.read().decode('utf-8', errors='replace')

        for line in content.splitlines():
            m = APPROVAL_PATTERN.match(line)
            if not m:
                continue
            try:
                # Parse timestamp
                ts_str = m.group("ts")
                ts = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp()
                if ts < cutoff:
                    continue
                approvals.append({
                    "timestamp": ts,
                    "thread_id": m.group("thread_id"),
                    "count": int(m.group("count")),
                })
            except (ValueError, AttributeError):
                continue
    except OSError as e:
        print(f"  ⚠️  Cannot read gateway log: {e}", file=sys.stderr)
        return []

    return approvals


def aggregate_by_thread(approvals: List[Dict[str, Any]]) -> Dict[str, int]:
    """Count approvals per thread in the window."""
    counts: Dict[str, int] = defaultdict(int)
    for a in approvals:
        counts[a["thread_id"]] += a["count"]
    return dict(counts)


def find_session_for_thread(thread_id: str) -> str | None:
    """Look up the session_id currently bound to this thread."""
    import json
    if not SESSIONS_JSON.exists():
        return None
    try:
        with open(SESSIONS_JSON) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        return None

    key = f"agent:main:discord:thread:{thread_id}:{thread_id}"
    if key in data:
        return data[key].get("session_id")
    return None


def auto_suspend_session(sid: str, reason: str) -> bool:
    """Archive a session using the native Hermes archived=1 flag.

    Also clear thread routing so the gateway won't try to re-bind.
    """
    try:
        conn = sqlite3.connect(str(STATE_DB))
        cur = conn.execute("UPDATE sessions SET archived = 1 WHERE id = ?", (sid,))
        conn.commit()
        updated = cur.rowcount
        conn.close()
        if updated > 0:
            # Also delete messages so SessionRecoveryManager doesn't re-activate
            conn = sqlite3.connect(str(STATE_DB))
            conn.execute("DELETE FROM messages WHERE session_id = ?", (sid,))
            conn.commit()
            conn.close()
            print(f"  ✅ Auto-suspended session {sid} ({reason})")
            return True
    except sqlite3.OperationalError as e:
        print(f"  ❌ Failed to suspend {sid}: {e}", file=sys.stderr)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="Run once and exit (for daemon/cron)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.dry_run:
        print("🧪 DRY RUN — no destructive actions")

    approvals = parse_recent_approvals()
    if not approvals:
        # Quiet: this is the normal case
        return 0

    by_thread = aggregate_by_thread(approvals)
    print(f"[{datetime.now(timezone.utc).isoformat()}] approval_spam_detector")
    print(f"  Window: last {WINDOW_SECONDS}s, threshold: {MAX_APPROVALS_PER_5MIN} approvals")
    print(f"  Found {len(approvals)} approval events across {len(by_thread)} thread(s)")

    actions_taken = 0
    for thread_id, count in by_thread.items():
        if count <= MAX_APPROVALS_PER_5MIN:
            icon = "✅"
            action = "ok"
        else:
            icon = "🚨"
            action = f"SPAM (>{MAX_APPROVALS_PER_5MIN})"
            # Find and suspend the session
            sid = find_session_for_thread(thread_id)
            if sid:
                if not args.dry_run:
                    if auto_suspend_session(sid, f"approval_spam: {count} in {WINDOW_SECONDS}s"):
                        actions_taken += 1
            else:
                print(f"  ⚠️  Thread {thread_id} has spam but no session binding found")
        print(f"  {icon} thread={thread_id[:24]}... approvals={count} | {action}")

    print(f"\n  📈 Summary: {actions_taken} session(s) auto-suspended")
    return 0


if __name__ == "__main__":
    sys.exit(main())
