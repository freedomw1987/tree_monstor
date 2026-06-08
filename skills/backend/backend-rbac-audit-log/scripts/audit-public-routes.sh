#!/usr/bin/env bash
# audit-public-routes.sh — 60-second recipe to find unauthenticated
# endpoints in an Elysia (or any TS-backend) routes directory.
#
# Pairs with backend-rbac-audit-log Step 16. Run from the routes/ dir:
#
#   cd apps/api/src/routes
#   bash ~/.hermes/profiles/developer/skills/backend/backend-rbac-audit-log/scripts/audit-public-routes.sh
#
# Exit code 0 = all files pass; 1 = at least one public endpoint.

set -u

ROUTES_DIR="${1:-.}"

cd "$ROUTES_DIR" || { echo "Cannot cd into $ROUTES_DIR" >&2; exit 2; }

printf "%-30s %-7s %-13s %-13s %s\n" "FILE" "verbs" "requirePerm" "authContext" "STATUS"
printf "%-30s %-7s %-13s %-13s %s\n" "------------------------------" "-----" "-------------" "------------" "------"

exit_code=0

for f in *.ts; do
  [ -f "$f" ] || continue
  [ "$f" = "index.ts" ] && continue
  [ "$f" = "auth.ts" ] && continue  # auth routes are by-design unauth'd

  name="${f%.ts}"
  verbs=$(grep -cE "\.(get|post|patch|delete)\(" "$f" 2>/dev/null || echo 0)
  perms=$(grep -c "requirePermission" "$f" 2>/dev/null || echo 0)
  authctx=$(grep -c "authContext" "$f" 2>/dev/null || echo 0)

  status="OK"
  if [ "$authctx" -eq 0 ] && [ "$perms" -eq 0 ]; then
    status="🔴 PUBLIC (catastrophic)"
    exit_code=1
  elif [ "$authctx" -eq 0 ] && [ "$perms" -gt 0 ]; then
    status="🟠 authContext missing"
    exit_code=1
  elif [ "$perms" -lt "$verbs" ]; then
    status="🟠 PARTIAL PUBLIC ($perms/$verbs verbs gated)"
    exit_code=1
  fi

  printf "%-30s %-7s %-13s %-13s %s\n" "$name" "$verbs" "$perms" "$authctx" "$status"
done

if [ "$exit_code" -ne 0 ]; then
  echo ""
  echo "❌ Found public / partially public routes. Fix with:"
  echo "   - Add .use(authContext) at the top of flagged files"
  echo "   - Add .use(requirePermission('X:Y')) before EACH .get/.post/.patch/.delete"
  echo "   See: backend-rbac-audit-log skill, Step 14 + Step 16"
  echo "   Reference: references/p0-public-routes-audit-recipe.md"
fi

exit "$exit_code"
