#!/bin/bash
# verify_boss_html.sh — Detect placeholder boss HTMLs in a project.
#
# Why: The per-doc build script (build.sh) ALWAYS succeeds and produces a
# 20-24 KB *-boss.html for every MD, even when no boss summary JSON exists.
# The result looks structurally complete but renders a "👀 老闆版摘要待生成"
# placeholder, which David immediately flags as "冇資料". You cannot rely on
# file size, file count, or build exit code to catch this — you MUST scan
# the rendered HTML body for the placeholder class.
#
# Usage:  verify_boss_html.sh <project-name>
#   project-name = folder under ~/www/ (e.g. "crm-system")
#
# Exit codes:
#   0 — all boss HTMLs have real content
#   1 — one or more boss HTMLs are placeholders (lists which ones)
#   2 — no boss HTMLs found at all (build was never run)
#
# Verification strategy (the one that works):
#   1. The placeholder class lives in <body>, not in <style> CSS rules.
#      A naive `grep -l 'boss-placeholder' file.html` will hit the CSS
#      class definition and report false positives on GOOD files.
#   2. Extract the region between </head> and <script> using awk —
#      that's the body. Grep the body region only.
#   3. This is the same recipe used to build the audit, verified 2026-06-06
#      on crm-system where 10/12 boss files were silently placeholders.
#
# Reference: see SKILL.md §"🛑 Boss HTML verification (mandatory)"

set -euo pipefail

PROJECT="${1:-}"
if [[ -z "$PROJECT" ]]; then
  echo "Usage: $0 <project-name>" >&2
  echo "  e.g. $0 crm-system" >&2
  exit 2
fi

PROJECT_DIR="$HOME/www/$PROJECT"
HTML_DIR="$PROJECT_DIR/docs/_html"

if [[ ! -d "$HTML_DIR" ]]; then
  echo "ERROR: $HTML_DIR does not exist — build was never run." >&2
  echo "Run: bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/build.sh --project $PROJECT" >&2
  exit 2
fi

# Find all boss HTMLs (sorted for stable output)
mapfile -t BOSS_FILES < <(find "$HTML_DIR" -name '*-boss.html' -type f | sort)
if [[ ${#BOSS_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no *-boss.html files in $HTML_DIR — build was never run." >&2
  exit 2
fi

ok=0
bad=0
bad_files=()

for f in "${BOSS_FILES[@]}"; do
  # Extract body region: between </head> and <script>. This avoids the
  # CSS rules (which legitimately mention .boss-placeholder) and the
  # inlined JS (which queries .boss-decision .option etc.).
  if awk '/<\/head>/,/<script>/' "$f" | grep -q 'class="boss-placeholder"'; then
    bad=$((bad + 1))
    bad_files+=("$(basename "$f")")
  else
    ok=$((ok + 1))
  fi
done

echo "Boss HTML verification for '$PROJECT': $ok OK, $bad placeholder(s)"

if [[ $bad -gt 0 ]]; then
  echo ""
  echo "❌ The following boss HTMLs render the '待生成' placeholder:"
  for f in "${bad_files[@]}"; do
    echo "   - $f"
  done
  echo ""
  echo "Root cause: missing docs/_meta/<doc>.json for each placeholder above."
  echo "Fix: write a boss summary JSON for each, then re-run build.sh."
  echo "Schema reference: see SKILL.md §'Generating the boss summary JSON'"
  exit 1
fi

echo "✅ All ${#BOSS_FILES[@]} boss HTMLs have real content."
exit 0
