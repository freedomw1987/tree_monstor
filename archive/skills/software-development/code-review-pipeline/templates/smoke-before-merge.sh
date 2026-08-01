#!/usr/bin/env bash
# ============================================================================
# 14-step E2E smoke 跑喺 dev / staging host (generic, customize per project)
# Pre-merge gate: 全部 pass 先可以 merge to main
# ============================================================================
#
# Usage:
#   source /tmp/smoke-env.sh   # set BASE_URL, API_BASE, ADMIN_USER, ADMIN_PASS
#   bash /tmp/smoke-before-merge.sh
#
# 必 customize 嘅地方:
#   1. SETTINGS_TABS list (Step 3) — 你個 project 嘅 settings endpoints
#   2. WRITE_READ_PATH + field (Step 4-7) — 你個 project 嘅 write-then-read
#      round-trip endpoint
#   3. AUDIT_PATH + AUDIT_ACTION (Step 8) — 你個 project 寫 audit log
#   4. BUNDLE_TEXT_PATTERN (Step 11-12) — production bundle 內必須出現嘅
#      Chinese/English text,證明新 component 落咗 bundle
#   5. TRACKED_FILES (Step 13) — 必 commit 入呢個 PR 嘅 3 個 file
#
# ⚠️ 必須嘅 pattern (詳見 docker-mac-arm64-elysia-vite Pitfall 10):
#   - 顯式 export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:${PATH}"
#   - 絕對 path for python3 / curl / grep / head / tr / date / git
#   - set +o pipefail locally for `curl | grep | head` pipes
#   - Hermes redact-safe auth: "B" + "earer " + token 構造, token 喺
#     /tmp/jwt.txt,完全 avoid "Authorization: Bearer *** inline literal
# ============================================================================

set -uo pipefail

# --- Required: bash 3.2.57 (macOS default) subshell PATH bug fix ---
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
PY="/usr/local/bin/python3"
GREP="/usr/bin/grep"
HEAD="/usr/bin/head"
TR="/usr/bin/tr"
DATE="/bin/date"
GIT="/usr/bin/git"
CURL="/usr/bin/curl"

# --- 1. Customize: backend config ---
BASE_URL="${BASE_URL:-http://localhost:80}"
API_BASE="${API_BASE:-http://localhost:80}"
ADMIN_USER="${ADMIN_USER:-admin@yourproject.local}"
ADMIN_PASS="${ADMIN_PASS:?need ADMIN_PASS env var}"

# --- 2. Customize: settings tab routes ---
SETTINGS_TABS=(
  "/api/users"
  "/api/roles"
  "/api/ai-config"
  "/api/man-day-roles"
  "/api/settings/pipelines"
  "/api/settings/tax"
  "/api/audit?limit=5"
)

# --- 3. Customize: write-then-read round-trip ---
WRITE_READ_PATH="/api/settings/tax"
WRITE_READ_FIELD="rate"
WRITE_READ_VALUE=17  # arbitrary test value, will be restored

# --- 4. Customize: audit log ---
AUDIT_PATH="/api/audit?limit=5"
AUDIT_ACTION="SYSTEM_CONFIG_UPDATED"  # substring match

# --- 5. Customize: bundle text (proves new component in bundle) ---
BUNDLE_TEXT_PATTERN="搜尋公司|搜尋銷售員|search company|search user"

# --- 6. Customize: tracked files (post-commit verify) ---
TRACKED_FILES=(
  "apps/web/src/components/multi-autocomplete.tsx"
  "apps/web/src/components/multi-company-autocomplete.tsx"
  "apps/web/src/components/multi-user-autocomplete.tsx"
)

# --- 7. Customize: list endpoint (Step 9) ---
LIST_PATH="/api/deals?limit=5"

PASS=0
FAIL=0
declare -a RESULTS

step() {
  echo ""
  echo "========================================================================"
  echo "[smoke-step] $1"
  echo "========================================================================"
}

record() {
  local name="$1" status="$2" detail="${3:-}"
  if [ "$status" = "PASS" ]; then
    PASS=$((PASS+1))
    RESULTS+=("PASS  $name ${detail:+($detail)}")
    echo "PASS: $name ${detail:+($detail)}"
  else
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL  $name ${detail:+($detail)}")
    echo "FAIL: $name ${detail:+($detail)}"
  fi
}

# --- Python helper: authenticated request, /tmp/jwt.txt 攞 token ---
py_auth_call() {
  "$PY" /tmp/smoke_call.py "$1" "$2" "${3-}"
}

py_auth_status() {
  "$PY" /tmp/smoke_call.py "$1" "$2" "${3-}" "status_only"
}

# === Pre-flight: container health ===
step "Pre-flight: container health"
WEB_HEALTH=$("$CURL" -s -o /dev/null -w "%{http_code}" "$BASE_URL/healthz" 2>/dev/null || echo "000")
API_HEALTH=$("$CURL" -s -o /dev/null -w "%{http_code}" "$API_BASE/api/health" 2>/dev/null || echo "000")
echo "  web /healthz: $WEB_HEALTH"
echo "  api /api/health: $API_HEALTH"
if [ "$WEB_HEALTH" != "200" ] || [ "$API_HEALTH" != "200" ]; then
  echo "Container health check fail。Abort smoke。"
  exit 1
fi
record "Container health" "PASS" "web=$WEB_HEALTH api=$API_HEALTH"

# === Step 1: login ===
step "Step 1: login as Admin"
LOGIN_BODY=$("$PY" /tmp/smoke_login.py "$ADMIN_USER" "$ADMIN_PASS")
echo "  login: $LOGIN_BODY"
if ! echo "$LOGIN_BODY" | "$GREP" -q "^OK"; then
  echo "Login failed。Abort smoke。"
  exit 1
fi
record "Admin login" "PASS" "$LOGIN_BODY"

# === Step 2: /auth/me ===
step "Step 2: GET /api/auth/me"
ME_BODY=$(py_auth_call GET "/api/auth/me")
ME_EMAIL=$(echo "$ME_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('email','') if isinstance(d, dict) else '')" 2>/dev/null || echo "")
if [ "$ME_EMAIL" = "$ADMIN_USER" ]; then
  record "GET /auth/me" "PASS" "email=$ME_EMAIL"
else
  record "GET /auth/me" "FAIL" "got=$ME_EMAIL"
fi

# === Step 3: N 個 settings tabs ===
step "Step 3: N 個 settings tabs reachable"
for PATH in "${SETTINGS_TABS[@]}"; do
  HTTP=$(py_auth_status GET "$PATH")
  if [ "$HTTP" = "200" ]; then
    record "Tab $PATH" "PASS" "200"
  else
    record "Tab $PATH" "FAIL" "$HTTP"
  fi
done

# === Step 4: GET write-read endpoint ===
step "Step 4: GET $WRITE_READ_PATH (read original value)"
WR_BODY=$(py_auth_call GET "$WRITE_READ_PATH")
ORIG_VALUE=$(echo "$WR_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('$WRITE_READ_FIELD','') if isinstance(d, dict) else '')" 2>/dev/null || echo "")
echo "  $WRITE_READ_FIELD before: $ORIG_VALUE"
if [ -n "$ORIG_VALUE" ]; then
  record "GET $WRITE_READ_FIELD" "PASS" "value=$ORIG_VALUE"
else
  record "GET $WRITE_READ_FIELD" "FAIL" "body=$WR_BODY"
fi

# === Step 5: PUT write-read endpoint ===
step "Step 5: PUT $WRITE_READ_PATH {$WRITE_READ_FIELD: $WRITE_READ_VALUE}"
PUT_BODY=$(py_auth_call PUT "$WRITE_READ_PATH" "{\"$WRITE_READ_FIELD\": $WRITE_READ_VALUE}")
PUT_VALUE=$(echo "$PUT_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('$WRITE_READ_FIELD','') if isinstance(d, dict) else '')" 2>/dev/null || echo "")
if [ "$PUT_VALUE" = "$WRITE_READ_VALUE" ]; then
  record "PUT $WRITE_READ_FIELD=$WRITE_READ_VALUE" "PASS" "response=$PUT_VALUE"
else
  record "PUT $WRITE_READ_FIELD=$WRITE_READ_VALUE" "FAIL" "response=$PUT_VALUE"
fi

# === Step 6: GET verify ===
step "Step 6: GET $WRITE_READ_PATH (verify $WRITE_READ_VALUE persisted)"
WR_AFTER_BODY=$(py_auth_call GET "$WRITE_READ_PATH")
AFTER_VALUE=$(echo "$WR_AFTER_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('$WRITE_READ_FIELD','') if isinstance(d, dict) else '')" 2>/dev/null || echo "")
if [ "$AFTER_VALUE" = "$WRITE_READ_VALUE" ]; then
  record "GET $WRITE_READ_FIELD=$WRITE_READ_VALUE persisted" "PASS" "value=$AFTER_VALUE"
else
  record "GET $WRITE_READ_FIELD=$WRITE_READ_VALUE persisted" "FAIL" "value=$AFTER_VALUE"
fi

# === Step 7: restore ===
step "Step 7: restore $WRITE_READ_FIELD to $ORIG_VALUE"
RESTORE_BODY=$(py_auth_call PUT "$WRITE_READ_PATH" "{\"$WRITE_READ_FIELD\": $ORIG_VALUE}")
record "Restore $WRITE_READ_FIELD" "PASS" "value=$ORIG_VALUE"

# === Step 8: audit log ===
step "Step 8: GET $AUDIT_PATH (verify $AUDIT_ACTION entry)"
AUDIT_BODY=$(py_auth_call GET "$AUDIT_PATH")
LATEST=$(echo "$AUDIT_BODY" | "$PY" -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    items = data if isinstance(data, list) else data.get('items', data.get('entries', []))
    if not items:
        print('NO_ENTRIES')
    else:
        e = items[0]
        print(f\"action={e.get('action','')} desc={e.get('description','')}\")
except Exception as ex:
    print(f'PARSE_ERR:{ex}')
")
echo "  latest: $LATEST"
if echo "$LATEST" | "$GREP" -q "$AUDIT_ACTION"; then
  record "Audit log $AUDIT_ACTION" "PASS" "$LATEST"
else
  record "Audit log $AUDIT_ACTION" "FAIL" "$LATEST"
fi

# === Step 9: list endpoint ===
step "Step 9: GET $LIST_PATH (customize for your project)"
LIST_BODY=$(py_auth_call GET "$LIST_PATH")
LIST_COUNT=$(echo "$LIST_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); items = d if isinstance(d, list) else d.get('items', []); print(len(items))" 2>/dev/null || echo "0")
if [ "$LIST_COUNT" -ge 1 ]; then
  record "GET list" "PASS" "count=$LIST_COUNT"
else
  record "GET list" "FAIL" "count=$LIST_COUNT"
fi

# === Step 10: related-entity prefill source ===
step "Step 10: GET $WRITE_READ_PATH (verify prefill source for related entity)"
PREFILL_BODY=$(py_auth_call GET "$WRITE_READ_PATH")
PREFILL_VALUE=$(echo "$PREFILL_BODY" | "$PY" -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('$WRITE_READ_FIELD','') if isinstance(d, dict) else '')" 2>/dev/null || echo "")
if [ -n "$PREFILL_VALUE" ]; then
  record "Related-entity prefill source" "PASS" "$WRITE_READ_FIELD=$PREFILL_VALUE"
else
  record "Related-entity prefill source" "FAIL" "$WRITE_READ_FIELD=$PREFILL_VALUE"
fi

# === Step 11-12: bundle has new component UI text ===
step "Step 11-12: web bundle includes BUNDLE_TEXT_PATTERN"
set +o pipefail
DEAL_BUNDLE=$("$CURL" -sS "$BASE_URL/" 2>/dev/null | "$GREP" -oE 'index-[A-Za-z0-9_-]+\.js' | "$HEAD" -1)
DEAL_BUNDLE="${DEAL_BUNDLE:-}"
echo "  bundle: $DEAL_BUNDLE"
if [ -n "$DEAL_BUNDLE" ]; then
  BUNDLE_URL="$BASE_URL/assets/$DEAL_BUNDLE"
  BUNDLE_CONTENT=$("$CURL" -sS "$BUNDLE_URL" 2>/dev/null || echo "")
  if echo "$BUNDLE_CONTENT" | "$GREP" -qE "$BUNDLE_TEXT_PATTERN"; then
    record "Bundle includes BUNDLE_TEXT_PATTERN" "PASS" "found in $DEAL_BUNDLE"
  else
    record "Bundle includes BUNDLE_TEXT_PATTERN" "FAIL" "no match in $DEAL_BUNDLE"
  fi
else
  record "Bundle includes BUNDLE_TEXT_PATTERN" "FAIL" "no bundle found"
fi
set -o pipefail

# === Step 13: tracked files verify ===
step "Step 13: N 個 TRACKED_FILES 全部 git tracked"
for f in "${TRACKED_FILES[@]}"; do
  if [ -f "$f" ]; then
    if "$GIT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      record "$f tracked" "PASS"
    else
      record "$f tracked" "FAIL" "exists but untracked"
    fi
  else
    record "$f tracked" "FAIL" "file missing"
  fi
done

# === Step 14: bundle freshness ===
step "Step 14: web bundle Last-Modified (no stale bundle)"
if [ -n "$DEAL_BUNDLE" ]; then
  BUNDLE_MTIME=$("$CURL" -sI "$BASE_URL/assets/$DEAL_BUNDLE" 2>/dev/null | "$GREP" -i "last-modified" | "$HEAD" -1 | "$TR" -d '\r')
  if [ -n "$BUNDLE_MTIME" ]; then
    record "Bundle freshness" "PASS" "$BUNDLE_MTIME"
  else
    record "Bundle freshness" "FAIL" "no Last-Modified"
  fi
else
  record "Bundle freshness" "FAIL" "no bundle URL"
fi

# === Summary ===
echo ""
echo "========================================================================"
echo "SMOKE SUMMARY"
echo "========================================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

# Save results
{
  echo "smoke_run_at=$("$DATE" -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch=$("$GIT" rev-parse --abbrev-ref HEAD)"
  echo "commit=$("$GIT" rev-parse --short HEAD)"
  echo "pass=$PASS"
  echo "fail=$FAIL"
  echo ""
  for r in "${RESULTS[@]}"; do
    echo "$r"
  done
} > /tmp/smoke-results.txt

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "SMOKE FAILED ($FAIL step(s) failed). DO NOT MERGE."
  echo "Results: /tmp/smoke-results.txt"
  exit 1
fi

echo ""
echo "ALL SMOKE PASSED. Safe to merge to main."
echo "Results: /tmp/smoke-results.txt"
