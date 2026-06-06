#!/usr/bin/env python3
"""save_state.py — Capture current dev task state to docs/dev-task-state.md.

Layer 1 trigger fires this script. Sources of state:
  1. SOUL.md / AGENTS.md / MEMORY.md (read-only, always there)
  2. docs/PROJECT-OVERVIEW.md, PRD.md, DESIGN.md (if exist)
  3. Recent session messages (last 5 turns from session DB)
  4. Git state of current project (branch, last commit, uncommitted)
  5. Uncommitted file changes in cwd

Usage:
  python3 save_state.py --project <project_name> [--trigger <reason>]
  python3 save_state.py --project crm-system --trigger "auto-compress"

Outputs:
  ~/www/<project>/docs/_meta/dev-task-state.md (gitignored)
  Updated Last save timestamp
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

TEMPLATE_PATH = Path(__file__).parent.parent / "templates" / "dev-task-state.md"


def find_project_root(project_name: str) -> Path:
    """Locate project root (~/www/<project_name>)."""
    candidates = [
        Path.home() / "www" / project_name,
        Path.cwd() / project_name,
        Path.cwd(),
    ]
    for c in candidates:
        if c.exists() and (c / ".git").exists():
            return c
        if c.exists() and any(c.glob("package.json")):
            return c
    # Fallback to first candidate even if it doesn't exist
    return Path.home() / "www" / project_name


def get_git_state(cwd: Path) -> dict:
    """Read git state from cwd. Returns dict with branch, commit, dirty."""
    if not (cwd / ".git").exists():
        return {"branch": "(not a git repo)", "commit": "—", "dirty": False}

    try:
        branch = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip() or "(detached)"

        commit_sha = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip() or "—"

        commit_msg = subprocess.run(
            ["git", "-C", str(cwd), "log", "-1", "--pretty=%s"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip() or ""

        # Check dirty (uncommitted)
        status = subprocess.run(
            ["git", "-C", str(cwd), "status", "--porcelain"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()
        dirty = bool(status)
        dirty_files_count = len([l for l in status.split("\n") if l.strip()]) if status else 0

        return {
            "branch": branch,
            "commit": f"{commit_sha} \"{commit_msg[:50]}\"",
            "dirty": dirty,
            "dirty_files": dirty_files_count,
        }
    except Exception as e:
        return {"branch": f"(error: {e})", "commit": "—", "dirty": False}


def get_recent_files(cwd: Path, since_minutes: int = 60) -> list:
    """List files modified in the last N minutes."""
    if not (cwd / ".git").exists():
        return []

    try:
        # Find recently modified files (uncommitted + recently committed)
        result = subprocess.run(
            ["git", "-C", str(cwd), "status", "--porcelain", "--untracked-files=all"],
            capture_output=True, text=True, timeout=5
        )
        files = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            # Porcelain format: "XY filename" or "XY old -> new"
            match = re.match(r"^..\s+(.+)$", line)
            if match:
                files.append({
                    "path": match.group(1).strip(),
                    "status": line[:2].strip() or "modified",
                })
        return files[:30]  # cap at 30
    except Exception:
        return []


def read_recent_session_turns(project_name: str, limit: int = 5) -> list:
    """Read the most recent N session turns for this project.

    Uses hermes sessions list to find sessions mentioning this project.
    Returns last N user/assistant message snippets.
    """
    try:
        result = subprocess.run(
            ["hermes", "sessions", "list", "--limit", "20", "--format", "json"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return []
        sessions = json.loads(result.stdout)
        # Filter sessions with project name in preview
        project_sessions = [s for s in sessions if project_name in str(s.get("preview", "")).lower()][:1]
        if not project_sessions:
            return []
        # Could expand to read full session via session_search, but keep simple
        return [{"session_id": s.get("id", "?"), "preview": s.get("preview", "")[:200]}
                for s in project_sessions]
    except Exception:
        return []


def get_session_id() -> str:
    """Try to get current Hermes session ID from env or session DB."""
    return os.environ.get("HERMES_SESSION_ID", os.environ.get("SESSION_ID", "current-session"))


def detect_decisions_from_session() -> list:
    """Heuristic: look for 'Decision:', 'We decided', '方案 A' markers in last turns.

    This is a stub — full version would parse the actual session DB.
    Returns empty for now; user can manually add decisions.
    """
    # TODO: integrate with hermes_state.py for actual session DB read
    return []


def main():
    parser = argparse.ArgumentParser(description="Save dev task state to docs/dev-task-state.md")
    parser.add_argument("--project", required=True, help="Project name (e.g. crm-system)")
    parser.add_argument("--trigger", default="manual", help="Trigger reason (auto-compress, /new, restart, etc.)")
    parser.add_argument("--goal", help="Override goal text (one-liner)")
    parser.add_argument("--dry-run", action="store_true", help="Print without writing")
    args = parser.parse_args()

    project_root = find_project_root(args.project)
    meta_dir = project_root / "docs" / "_meta"
    output_path = meta_dir / "dev-task-state.md"

    # Read template
    if not TEMPLATE_PATH.exists():
        print(f"❌ Template not found: {TEMPLATE_PATH}")
        sys.exit(1)
    template = TEMPLATE_PATH.read_text()

    # Collect state
    git_state = get_git_state(project_root)
    files = get_recent_files(project_root)
    session_id = get_session_id()
    recent_sessions = read_recent_session_turns(args.project)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Build files table
    if files:
        files_table = "\n".join(
            f"| `{f['path']}` | `{f['status']}` | (now) |"
            for f in files[:15]  # cap at 15
        )
    else:
        files_table = "| (no uncommitted files) | — | — |"

    # Build recent sessions list
    if recent_sessions:
        sessions_list = "\n".join(
            f"- `{s['session_id']}`: {s['preview']}"
            for s in recent_sessions
        )
    else:
        sessions_list = "(none)"

    # Render template
    rendered = template
    rendered = rendered.replace("<PROJECT_NAME>", args.project)
    rendered = rendered.replace("<一句話講清楚要做咩, e.g. \"Fix CRM Companies page: 編輯公司資料表單可以加聯繫人 sub-row\">",
                               args.goal or "(待填寫 — 從 session first message 提取)")
    rendered = rendered.replace("<一句話講清楚要做咩...>",
                               args.goal or "(待填寫)")
    rendered = rendered.replace("| `<file path>` | `created` / `modified` / `deleted` | `<HH:MM>` |", files_table.split("\n")[0])
    rendered = rendered.replace("| ... | ... | ... |",
                               "\n".join(files_table.split("\n")[1:]) if "\n" in files_table else "| ... | ... | ... |")
    rendered = rendered.replace("**Branch**: `<branch name>`", f"**Branch**: `{git_state['branch']}`")
    rendered = rendered.replace("**Last commit**: `<commit SHA> \"<message>\"`",
                               f"**Last commit**: `{git_state['commit']}`")
    rendered = rendered.replace("**Uncommitted changes**: `<yes / no, brief description>`",
                               f"**Uncommitted changes**: `{'yes' if git_state['dirty'] else 'no'} ({git_state.get('dirty_files', 0)} files)`")
    rendered = rendered.replace("**Current session ID**: `<2026XXXX_HHMMSS_xxxxxx>`",
                               f"**Current session ID**: `{session_id}`")
    rendered = rendered.replace("**Last save timestamp**: `<YYYY-MM-DD HH:MM:SS>` (auto-updated)",
                               f"**Last save timestamp**: `{now}` (trigger: {args.trigger})")
    rendered = rendered.replace("- **<Risk 1>**: <description + mitigation>",
                               "- (待填寫)")
    rendered = rendered.replace("- **<Risk 2>**: <description + mitigation>",
                               "- (待填寫)")

    if args.dry_run:
        print(rendered)
        return

    # Write
    meta_dir.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)

    print(f"✅ Saved dev task state to: {output_path}")
    print(f"   Trigger: {args.trigger}")
    print(f"   Files captured: {len(files)}")
    print(f"   Git: {git_state['branch']} @ {git_state['commit'][:20]}")
    print(f"   Sessions referenced: {len(recent_sessions)}")
    print(f"\n💡 To resume: read this file at session start, then continue with the 'Next 3-5 Steps'")


if __name__ == "__main__":
    main()
