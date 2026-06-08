#!/usr/bin/env python3
"""load_state.py — Restore dev task context from docs/dev-task-state.md.

Called when:
  - New session starts (auto-detect via session_search)
  - User sends /new
  - Context auto-compression just happened
  - User says "繼續" / "resume" / "where were we"

Outputs:
  - Prints the saved state to stdout (agent reads it)
  - Updates session DB with state-injection marker
  - Optionally injects into the conversation as a "system" turn
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional


def find_state_file(project_name: Optional[str] = None) -> Optional[Path]:
    """Find dev-task-state.md in ~/www/<project>/docs/_meta/ or current cwd."""
    candidates = []
    if project_name:
        candidates.append(Path.home() / "www" / project_name / "docs" / "_meta" / "dev-task-state.md")
    candidates.append(Path.cwd() / "docs" / "_meta" / "dev-task-state.md")
    candidates.append(Path.cwd() / "dev-task-state.md")

    for c in candidates:
        if c.exists():
            return c
    return None


def search_sessions_for_project(project_name: str, limit: int = 3) -> list:
    """Use FTS5 to find recent sessions mentioning this project."""
    try:
        result = subprocess.run(
            ["hermes", "sessions", "list", "--limit", "30", "--format", "json"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return []
        import json
        sessions = json.loads(result.stdout)
        # Score by project name + relevant keywords
        scored = []
        for s in sessions:
            preview = str(s.get("preview", "")).lower()
            title = str(s.get("title", "")).lower()
            score = 0
            if project_name.lower() in preview or project_name.lower() in title:
                score += 10
            for kw in ["decision", "implement", "fix", "build", "create", "bug", "deploy", "test"]:
                if kw in preview:
                    score += 1
            if score > 0:
                scored.append((score, s))
        scored.sort(reverse=True)
        return [s for _, s in scored[:limit]]
    except Exception:
        return []


def extract_resume_command(state_text: str) -> Optional[str]:
    """Pull the resume command from the state file."""
    match = re.search(r"\*\*Resume command\*\*: `([^`]+)`", state_text)
    return match.group(1) if match else None


def extract_session_id(state_text: str) -> Optional[str]:
    """Pull the current session ID from the state file."""
    match = re.search(r"\*\*Current session ID\*\*: `([^`]+)`", state_text)
    return match.group(1) if match else None


def main():
    parser = argparse.ArgumentParser(description="Load dev task state and inject into context")
    parser.add_argument("--project", help="Project name to find state for")
    parser.add_argument("--search-sessions", action="store_true",
                        help="Also search past sessions for relevant context")
    parser.add_argument("--dry-run", action="store_true", help="Print state without action")
    args = parser.parse_args()

    state_path = find_state_file(args.project)
    if not state_path:
        print(f"❌ No dev-task-state.md found")
        if args.project:
            print(f"   Searched: ~/www/{args.project}/docs/_meta/dev-task-state.md")
        print(f"   Also searched: cwd/docs/_meta/dev-task-state.md, cwd/dev-task-state.md")
        print(f"\n💡 To create: run `python3 save_state.py --project <name> --trigger manual`")
        sys.exit(1)

    print(f"📂 Found state: {state_path}")
    state_text = state_path.read_text()

    # Print header
    print("\n" + "=" * 70)
    print("🔄 DEV TASK STATE — Loaded from file (not LLM memory)")
    print("=" * 70)
    print(state_text)
    print("=" * 70)

    # Extract metadata
    resume_cmd = extract_resume_command(state_text)
    session_id = extract_session_id(state_text)

    if resume_cmd:
        print(f"\n🔗 To continue full session: {resume_cmd}")
    if session_id:
        print(f"🆔 Current session lineage: {session_id}")

    # Optional: search related sessions
    if args.search_sessions and args.project:
        print(f"\n🔍 Related sessions for '{args.project}':")
        sessions = search_sessions_for_project(args.project)
        for i, s in enumerate(sessions, 1):
            print(f"  {i}. [{s.get('id', '?')[:24]}] {s.get('title', '?')[:40]} — {s.get('preview', '?')[:60]}")
            print(f"     Resume: `hermes --resume {s.get('id', '?')}`")

    if args.dry_run:
        return

    # Optional: trigger Hermes resume (if user requested it)
    if resume_cmd and "--auto-resume" in sys.argv:
        print(f"\n🚀 Auto-resuming: {resume_cmd}")
        os.system(resume_cmd)


if __name__ == "__main__":
    main()
