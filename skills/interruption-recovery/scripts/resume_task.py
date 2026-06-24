#!/usr/bin/env python3
"""
resume_task.py — Recover a long-running development task

When a developer profile session has been forked (due to context pressure,
interruption, or zombie detection), this script gathers all available
context for the new session to continue:

  1. Handoff markdown from ~/.hermes/profiles/developer/handoffs/<sid>.handoff.md
  2. Progress checkpoint from ~/.hermes/profiles/developer/task_state/<sid>.progress.json
  3. dev-task-state.md from the project workdir
  4. Git log (last 20 commits) in the workdir
  5. pre-tool-checkpoint journal (.hermes-checkpoints.log) in the workdir

Outputs a unified brief that the new session can use to continue work.

Usage:
  resume_task.py <session_id> [--workdir <path>]

If session_id is "latest" or omitted, picks the most recent handoff.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/Users/davidchu/.hermes"))
PROFILE_HOME = HERMES_HOME / "profiles" / "developer"
HANDOFFS_DIR = PROFILE_HOME / "handoffs"
TASK_STATE_DIR = PROFILE_HOME / "task_state"

DEFAULT_DEV_STATE = Path("/Users/davidchu/www/hermes-developer-profile/docs/_meta/dev-task-state.md")


def find_latest_handoff() -> Optional[Path]:
    if not HANDOFFS_DIR.exists():
        return None
    handoffs = sorted(HANDOFFS_DIR.glob("*.handoff.md"), key=lambda p: p.stat().st_mtime, reverse=True)
    return handoffs[0] if handoffs else None


def find_handoff(sid: str) -> Optional[Path]:
    if not HANDOFFS_DIR.exists():
        return None
    safe_sid = sid.replace("/", "_").replace(":", "_")
    p = HANDOFFS_DIR / f"{safe_sid}.handoff.md"
    return p if p.exists() else None


def find_progress(sid: str) -> Optional[Path]:
    if not TASK_STATE_DIR.exists():
        return None
    safe_sid = sid.replace("/", "_").replace(":", "_")
    p = TASK_STATE_DIR / f"{safe_sid}.progress.json"
    return p if p.exists() else None


def get_git_log(workdir: str, n: int = 20) -> str:
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", f"-{n}", "--decorate", "--stat"],
            capture_output=True, text=True, timeout=10, cwd=workdir
        )
        if result.returncode != 0:
            return f"  (not a git repo: {result.stderr.strip()[:200]})"
        return result.stdout.strip()[:3000]
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return f"  (git log failed: {e})"


def get_checkpoint_journal(workdir: str, n: int = 10) -> str:
    journal = Path(workdir) / ".hermes-checkpoints.log"
    if not journal.exists():
        return f"  (no .hermes-checkpoints.log in {workdir})"
    try:
        with open(journal) as f:
            lines = f.readlines()
        recent = lines[-n:] if len(lines) > n else lines
        return "".join(f"  {l.strip()}\n" for l in recent)
    except OSError as e:
        return f"  (cannot read journal: {e})"


def find_workdir_for_session(progress_data: Optional[Dict[str, Any]]) -> Optional[str]:
    """Heuristic: look for cwd in progress, or use dev-task-state.md parent dir."""
    if progress_data:
        cwd = progress_data.get("session_meta", {}).get("cwd")
        if cwd:
            return cwd
    if DEFAULT_DEV_STATE.exists():
        return str(DEFAULT_DEV_STATE.parent.parent.parent)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session_id", nargs="?", default="latest",
                        help="Session ID to resume (or 'latest' for most recent)")
    parser.add_argument("--workdir", help="Project workdir to inspect (auto-detect if not given)")
    parser.add_argument("--no-color", action="store_true")
    args = parser.parse_args()

    # 1. Find handoff
    if args.session_id == "latest":
        handoff = find_latest_handoff()
        if not handoff:
            print("❌ No handoff files found in", HANDOFFS_DIR)
            return 1
        sid = handoff.name.replace(".handoff.md", "")
        print(f"📌 Auto-selected latest handoff: {sid}")
    else:
        sid = args.session_id
        handoff = find_handoff(sid)
        if not handoff:
            print(f"❌ No handoff file for session: {sid}")
            print(f"   Searched: {HANDOFFS_DIR}")
            return 1

    # 2. Find progress checkpoint
    progress = find_progress(sid)
    progress_data: Optional[Dict[str, Any]] = None
    if progress:
        try:
            progress_data = json.loads(progress.read_text())
        except json.JSONDecodeError:
            pass

    # 3. Determine workdir
    workdir = args.workdir or find_workdir_for_session(progress_data)

    print()
    print("=" * 70)
    print(f"🔄 RESUME BRIEF — Session {sid}")
    print("=" * 70)
    print(f"Generated: {datetime.now().isoformat()}")
    print()

    # Section 1: Handoff
    print("## 1. HANDOFF STATE")
    print("-" * 70)
    print(handoff.read_text())

    # Section 2: Progress checkpoint
    if progress_data:
        print()
        print("## 2. PROGRESS CHECKPOINT (machine-readable)")
        print("-" * 70)
        print(json.dumps(progress_data, indent=2))

    # Section 3: dev-task-state.md
    if DEFAULT_DEV_STATE.exists():
        print()
        print("## 3. DEV TASK STATE")
        print("-" * 70)
        content = DEFAULT_DEV_STATE.read_text()
        print(content[:5000])
        if len(content) > 5000:
            print(f"\n  ... (truncated, {len(content)} total chars)")

    # Section 4: Git log
    if workdir:
        print()
        print("## 4. GIT LOG (last 20 commits)")
        print("-" * 70)
        print(f"  Workdir: {workdir}")
        print(get_git_log(workdir))

    # Section 5: Pre-tool checkpoint journal
    if workdir:
        print()
        print("## 5. PRE-TOOL CHECKPOINT JOURNAL (last 10)")
        print("-" * 70)
        print(get_checkpoint_journal(workdir))

    print()
    print("=" * 70)
    print("✅ Recovery brief complete. Use this context to continue work.")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
