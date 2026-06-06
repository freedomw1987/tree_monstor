#!/usr/bin/env python3
"""sync_external.py — Sync dev-task-state decisions to external memory provider.

Layer 4 trigger. Pulls facts from docs/dev-task-state.md and pushes them to the
active external memory provider (holographic / mem0 / honcho / etc.) so they
survive across sessions, gateways, and machines.

For now, writes to a local fallback file at ~/.hermes/memories/dev-task-facts.jsonl
that any new session can read. When an external provider is configured
(via `hermes memory setup`), this script can be extended to push to that
provider's API.

Usage:
  python3 sync_external.py --project <name>          # sync from dev-task-state.md
  python3 sync_external.py --read --project <name>   # read previously-synced facts
  python3 sync_external.py --search "auth"            # search facts by keyword
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

DEFAULT_FACTS_FILE = Path.home() / ".hermes" / "memories" / "dev-task-facts.jsonl"


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


def extract_facts_from_state(state_path: Path) -> list:
    """Parse dev-task-state.md and pull out Decisions + Insights as discrete facts."""
    text = state_path.read_text()
    facts = []

    # Decisions
    in_decisions = False
    current_decision = None
    for line in text.split("\n"):
        if "## 📋 Decisions" in line:
            in_decisions = True
            continue
        if in_decisions and line.startswith("## ") and "Decisions" not in line:
            in_decisions = False
        if in_decisions:
            m = re.match(r"^\d+\.\s+\*\*(.+?)\*\*", line)
            if m:
                current_decision = {"type": "decision", "title": m.group(1), "why": ""}
                facts.append(current_decision)
            elif current_decision and "**Why**:" in line:
                current_decision["why"] = line.split("**Why**:", 1)[1].strip()

    # Insights
    in_insights = False
    for line in text.split("\n"):
        if "## 🧠 Key Insights" in line:
            in_insights = True
            continue
        if in_insights and line.startswith("## ") and "Insights" not in line:
            in_insights = False
        if in_insights:
            m = re.match(r"^-\s+\*\*(.+?)\*\*:\s*(.+)$", line)
            if m:
                facts.append({"type": "insight", "title": m.group(1), "detail": m.group(2)})

    # Risks
    in_risks = False
    for line in text.split("\n"):
        if "## 🚨 Risks" in line:
            in_risks = True
            continue
        if in_risks and line.startswith("## ") and "Risks" not in line:
            in_risks = False
        if in_risks:
            m = re.match(r"^-\s+\*\*(.+?)\*\*:\s*(.+)$", line)
            if m:
                facts.append({"type": "risk", "title": m.group(1), "detail": m.group(2)})

    return facts


def get_active_provider() -> str:
    """Check which external memory provider is active."""
    try:
        result = __import__("subprocess").run(
            ["hermes", "memory", "status"],
            capture_output=True, text=True, timeout=5
        )
        if "active" in result.stdout.lower() or "honcho" in result.stdout.lower():
            for line in result.stdout.split("\n"):
                if "Provider:" in line:
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return "(built-in only)"


def push_to_external(facts: list, project: str, provider: str) -> int:
    """Push facts to external memory. Returns count synced.

    For holographic (local): append to facts file.
    For mem0/honcho (API): would call their SDK. (TODO: implement when provider active.)
    """
    if provider == "(built-in only)" or "holographic" in provider.lower():
        # Local fallback: append to facts file
        DEFAULT_FACTS_FILE.parent.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().isoformat()
        with DEFAULT_FACTS_FILE.open("a") as f:
            for fact in facts:
                record = {
                    "ts": ts,
                    "project": project,
                    "provider": provider,
                    "fact": fact,
                }
                f.write(json.dumps(record) + "\n")
        return len(facts)
    else:
        # External provider (mem0/honcho/etc) — would need their SDK.
        # Print a notice and skip for now.
        print(f"⚠️ External provider '{provider}' detected but not yet implemented.")
        print(f"   Facts extracted: {len(facts)}")
        print(f"   To enable: install the provider plugin and configure API key.")
        print(f"   Fallback: writing to local file: {DEFAULT_FACTS_FILE}")
        # Still write local copy as backup
        DEFAULT_FACTS_FILE.parent.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().isoformat()
        with DEFAULT_FACTS_FILE.open("a") as f:
            for fact in facts:
                record = {
                    "ts": ts,
                    "project": project,
                    "provider": f"{provider} (queued, not synced)",
                    "fact": fact,
                }
                f.write(json.dumps(record) + "\n")
        return len(facts)


def read_local_facts(project: Optional[str] = None) -> list:
    """Read all previously-synced facts, optionally filtered by project."""
    if not DEFAULT_FACTS_FILE.exists():
        return []
    facts = []
    with DEFAULT_FACTS_FILE.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
                if project is None or record.get("project") == project:
                    facts.append(record)
            except json.JSONDecodeError:
                continue
    return facts


def search_facts(query: str, project: Optional[str] = None) -> list:
    """Simple keyword search across facts."""
    query_lower = query.lower()
    results = []
    for record in read_local_facts(project):
        fact_str = json.dumps(record["fact"]).lower()
        if query_lower in fact_str:
            results.append(record)
    return results


def main():
    parser = argparse.ArgumentParser(description="Sync dev task state to external memory")
    parser.add_argument("--project", help="Project name to find state for")
    parser.add_argument("--read", action="store_true", help="Read previously-synced facts")
    parser.add_argument("--search", help="Search facts by keyword")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.read or args.search:
        if args.search:
            results = search_facts(args.search, args.project)
            print(f"🔍 Search '{args.search}' (project: {args.project or 'all'}): {len(results)} hits")
            for r in results[:20]:
                print(f"  [{r['ts']}] {r['project']}: {r['fact']}")
        else:
            facts = read_local_facts(args.project)
            print(f"📚 Read {len(facts)} facts (project: {args.project or 'all'})")
            for r in facts[-20:]:  # last 20
                print(f"  [{r['ts']}] {r['project']}: {r['fact']}")
        return

    # Default: sync from state file
    state_path = find_state_file(args.project)
    if not state_path:
        print(f"❌ No dev-task-state.md found for project '{args.project}'")
        sys.exit(1)

    facts = extract_facts_from_state(state_path)
    print(f"📖 Extracted {len(facts)} facts from {state_path}")
    if not facts:
        print("   (No decisions/insights/risks to sync — file is empty)")
        return

    provider = get_active_provider()
    print(f"🔌 Active memory provider: {provider}")

    if args.dry_run:
        print("\n[DRY RUN] Would sync these facts:")
        for f in facts:
            print(f"  - {f}")
        return

    count = push_to_external(facts, args.project, provider)
    print(f"✅ Synced {count} facts to {provider or 'local fallback'}")
    print(f"   Local file: {DEFAULT_FACTS_FILE}")


if __name__ == "__main__":
    main()
