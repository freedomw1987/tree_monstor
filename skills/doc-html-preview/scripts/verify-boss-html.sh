#!/usr/bin/env bash
# verify-boss-html.sh — Confirm every boss.html in a project has real content.
# Build script does NOT fail when JSONs are missing, so this is the safety net.
#
# Usage: bash verify-boss-html.sh <project-name>
# Example: bash verify-boss-html.sh crm-system

set -euo pipefail

PROJECT="${1:?usage: $0 <project-name>}"
DOCS_DIR="$HOME/www/$PROJECT/docs/_html"

if [ ! -d "$DOCS_DIR" ]; then
  echo "ERROR: $DOCS_DIR does not exist. Run build.sh first." >&2
  exit 2
fi

MISSING=0
TOTAL=0
for f in "$DOCS_DIR"/*-boss.html; do
  [ -f "$f" ] || continue
  TOTAL=$((TOTAL + 1))
  # The placeholder div has class="boss-placeholder" in the body region
  # (between </head> and the first <script> which is the decision-capture JS).
  if awk '/<\/head>/,/<script>/' "$f" | grep -q 'boss-placeholder'; then
    echo "❌ PLACEHOLDER  $f"
    MISSING=$((MISSING + 1))
  else
    echo "✅ HAS CONTENT  $f"
  fi
done

echo ""
echo "Summary: $((TOTAL - MISSING))/$TOTAL boss.html populated"

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "Fix: write docs/_meta/<doc>.json for each missing doc, then re-run"
  echo "     bash $HOME/.hermes/profiles/developer/skills/doc-html-preview/scripts/build.sh --project $PROJECT"
  echo "     See: $HOME/.hermes/profiles/developer/skills/doc-html-preview/references/boss-summary-schema-and-recipe.md"
  exit 1
fi

exit 0
