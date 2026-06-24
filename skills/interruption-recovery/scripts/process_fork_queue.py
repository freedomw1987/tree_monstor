#!/usr/bin/env python3
"""
process_fork_queue.py — Consume session fork requests and create fresh sessions

Reads ~/.hermes/profiles/developer/session_fork_queue.jsonl (populated by
context_pressure_monitor.py) and:

  1. Marks the old session as `archived: 1` in state.db (so gateway stops routing to it)
  2. Clears the thread routing for the old session
  3. Notifies the user via Discord (best-effort)
  4. Deletes the fork queue entry

The gateway itself will create a fresh session when a new user message arrives
on the thread — we don't need to do that explicitly.

This is the "mid-task self-healing" exit point: the old session is no longer
a zombie risk, and the handoff file at ~/.hermes/profiles/developer/handoffs/
contains everything a fresh session needs to continue.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/Users/davidchu/.hermes"))
PROFILE_HOME = HERMES_HOME / "profiles" / "developer"
STATE_DB = PROFILE_HOME / "state.db"
SESSIONS_DIR = PROFILE_HOME / "sessions"
SESSIONS_JSON = SESSIONS_DIR / "sessions.json"
FORK_QUEUE = PROFILE_HOME / "session_fork_queue.jsonl"
HANDOFFS_DIR = PROFILE_HOME / "handoffs"
ENV_FILE = PROFILE_HOME / ".env"


def read_fork_queue() -> List[Dict[str, Any]]:
    if not FORK_QUEUE.exists():
        return []
    entries = []
    with open(FORK_QUEUE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def clear_fork_queue(keep: Optional[List[str]] = None) -> None:
    """Remove all fork queue entries (optionally keeping specific session_ids)."""
    if not FORK_QUEUE.exists():
        return
    keep_set = set(keep or [])
    remaining = []
    with open(FORK_QUEUE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("session_id") in keep_set:
                    remaining.append(line)
            except json.JSONDecodeError:
                pass
    FORK_QUEUE.write_text("\n".join(remaining) + ("\n" if remaining else ""))
    print(f"  🧹 Cleared fork queue ({len(remaining)} kept)")


def get_bot_token() -> Optional[str]:
    """Read Discord bot token from developer profile's .env file."""
    if not ENV_FILE.exists():
        return None
    content = ENV_FILE.read_text()
    m = re.search(r"DISCORD_BOT_TOKEN=([^\s\"'#]+)", content)
    if m:
        return m.group(1).strip()
    return None


def archive_session(sid: str) -> bool:
    """Mark a session as archived in state.db (read-write this time)."""
    try:
        conn = sqlite3.connect(str(STATE_DB))
        cur = conn.execute("UPDATE sessions SET archived = 1 WHERE id = ?", (sid,))
        conn.commit()
        updated = cur.rowcount
        conn.close()
        if updated > 0:
            print(f"  ✅ Archived session {sid} ({updated} row updated)")
            return True
        else:
            print(f"  ⚠️  Session {sid} not found in state.db (already archived?)")
            return False
    except sqlite3.OperationalError as e:
        print(f"  ❌ Failed to archive {sid}: {e}", file=sys.stderr)
        return False


def clear_thread_routing(sid: str) -> int:
    """Clear thread routing bindings for the given session."""
    if not SESSIONS_JSON.exists():
        return 0
    try:
        data = json.loads(SESSIONS_JSON.read_text())
    except json.JSONDecodeError:
        return 0

    cleared = 0
    # Iterate all routing entries
    routes = data.get("discord_thread_routing", [])
    new_routes = []
    for route in routes:
        if isinstance(route, dict) and route.get("session_id") == sid:
            cleared += 1
            continue
        new_routes.append(route)
    data["discord_thread_routing"] = new_routes
    SESSIONS_JSON.write_text(json.dumps(data, indent=2, default=str))
    print(f"  ✅ Cleared {cleared} thread routing rows for {sid}")
    return cleared


def notify_user_discord(sid: str, title: Optional[str], pressure: float, handoff_file: Optional[Path]) -> bool:
    """Best-effort: post a message to Discord about the session fork."""
    token = get_bot_token()
    if not token:
        print("  ⚠️  No Discord bot token, skipping notification")
        return False

    # We don't easily know the thread ID here; for now just log
    # (A future improvement: query sessions.json for the thread binding)
    print(f"  💬 Would notify user about fork of {sid} (pressure={pressure:.0%})")
    print(f"     title: {title}")
    print(f"     handoff: {handoff_file}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Report but don't modify")
    parser.add_argument("--keep-queue", action="store_true", help="Don't clear the fork queue")
    args = parser.parse_args()

    if args.dry_run:
        print("🧪 DRY RUN — no destructive actions")

    entries = read_fork_queue()
    if not entries:
        print("✅ Fork queue empty — nothing to do")
        return 0

    print(f"📋 Found {len(entries)} session(s) to fork")
    print()

    archived_count = 0
    routing_cleared = 0

    for entry in entries:
        sid = entry.get("session_id")
        pressure = entry.get("pressure", 0)
        title = entry.get("title")
        if not sid:
            continue

        print(f"--- Processing {sid} ---")
        print(f"  Title: {title or '(none)'}")
        print(f"  Pressure: {pressure:.0%}")

        if not args.dry_run:
            # 1. Archive the session
            if archive_session(sid):
                archived_count += 1
            # 2. Clear thread routing
            routing_cleared += clear_thread_routing(sid)
            # 3. Find handoff file
            safe_sid = sid.replace("/", "_").replace(":", "_")
            handoff_file = HANDOFFS_DIR / f"{safe_sid}.handoff.md"
            if not handoff_file.exists():
                handoff_file = None
            # 4. Notify user (best-effort)
            notify_user_discord(sid, title, pressure, handoff_file)

    if not args.keep_queue and not args.dry_run:
        clear_fork_queue()
    elif args.keep_queue:
        print(f"\n  ⏸️  Kept {len(entries)} entries in fork queue (--keep-queue)")

    print(f"\n📊 Summary: archived={archived_count} routing_cleared={routing_cleared}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
