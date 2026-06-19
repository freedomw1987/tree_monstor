#!/usr/bin/env bash
# verify-bundle-modal-uniqueness.sh
# Confirm a modal/form label exists exactly once in the production JS bundle.
# Use after extracting a duplicated modal into a single shared component.
#
# Usage:
#   ./verify-bundle-modal-uniqueness.sh <container-name> <search-text>
#
# Example:
#   ./verify-bundle-modal-uniqueness.sh pm-system-frontend-1 "智能分配"
#
# Exit codes:
#   0 — exactly 1 match (single source of truth confirmed)
#   1 — 0 matches (modal not found — wrong text or wrong container)
#   2 — 2+ matches (still duplicated — refactor incomplete)
#
# Notes:
#   - Greps every `assets/*.js` file inside the container's nginx html dir.
#   - Assumes nginx-alpine frontend image (the standard pm-system setup).
#   - If your frontend uses a different path, edit WEBROOT below.

set -euo pipefail

CONTAINER="${1:-}"
SEARCH_TEXT="${2:-}"

if [[ -z "$CONTAINER" || -z "$SEARCH_TEXT" ]]; then
  echo "Usage: $0 <container-name> <search-text>" >&2
  echo "Example: $0 pm-system-frontend-1 '智能分配'" >&2
  exit 1
fi

WEBROOT="/usr/share/nginx/html/assets"

# Run grep inside the container; count matches across all bundled JS files
COUNT=$(docker exec "$CONTAINER" sh -c "grep -c '$SEARCH_TEXT' $WEBROOT/*.js 2>/dev/null" | awk -F: '{s+=$2} END{print s}')

echo "Modal text '$SEARCH_TEXT' appears $COUNT time(s) in $CONTAINER:$WEBROOT"

case "$COUNT" in
  0) echo "❌ No matches found — verify the search text and container name." >&2
     exit 1 ;;
  1) echo "✅ Single source of truth confirmed (1 match = good)"
     exit 0 ;;
  *) echo "❌ $COUNT matches — modal is still duplicated. Extract to a single component and re-run." >&2
     exit 2 ;;
esac
