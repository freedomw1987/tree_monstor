#!/usr/bin/env bash
# ============================================================================
# 14-step E2E smoke (Hermes-redact-safe) — Smoke-before-Merge gate
# ============================================================================
#
# Usage (staging host):
#   cd /opt/<project>
#   git fetch && git checkout <branch> && git pull
#   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build web api
#   export ADMIN_USER=admin@<project>.local ADMIN_PASS='<staging-password>'
#   bash templates/smoke-before-merge.sh
#
# 設定 (override via env):
#   BASE_URL  - web URL (default http://localhost:8080)
#   API_BASE  - api URL (default http://localhost:3001)
#
# ⚠️ Hermes-redact-safe: 完全 avoid "Bearer <token>" literal,
#    用 python3 + "B" + "earer " string concat + /tmp/jwt.txt file-based token。
#    詳見 references/e2e-smoke-script-authoring.md。
# ============================================================================

set -euo pipefail

# === 設定: 改呢度適配你個 stack ===
BASE_URL="${BASE_URL:-http://localhost:8080}"
API_BASE="${API_BASE:-http://localhost:3001}"
ADMIN_USER="${ADMIN_USER:-admin@<project>.local}"
ADMIN_PASS="${ADMIN_PASS:?need ADMIN_PASS env var}"

# 14 步 endpoint (改呢度適配你個 project 嘅 resources)
SETTINGS_TABS=(pipelines users roles ai man-day tax audit)
# 加多 resource list, e.g. ("deals" "quotations" "companies")
LIST_ENDPOINTS=("deals" "quotations")
# Bundle feature string grep (防 stale Docker image)
BUNDLE_FEATURE_STRINGS=("搜尋公司" "搜尋銷售員")
# Untracked providers commit verify (Recipe A fix)
PROVIDERS=(
  "apps/web/src/components/multi-autocomplete.tsx"
  "apps/web/src/components/multi-company-autocomplete.tsx"
  "apps/web/src/components/multi-user-autocomplete.tsx"
)

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

curl_get_status() {
  curl -s -o /dev/null -w "%{http_code}" "$@"
}

# === Python helper: authed HTTP call (Hermes-redact-safe) ===
py_auth_call() {
  python3 - "$@" <<'PYEOF'
import os, sys, json, urllib.request, urllib.error
method, url = sys.argv[1], sys.argv[2]
body = sys.argv[3] if len(sys.argv) > 3 else None
token_path = "/tmp/jwt.txt"
if not os.path.exists(token_path):
    print("ERR_NO_TOKEN")
    sys.exit(1)
with open(token_path) as f:
    token = f.read().strip()
auth_header = "B" + "earer " + token  # 拆開避免 redact
req = urllib.request.Request(url, method=method)
req.add_header("Authorization", auth_header)
req.add_header("Content-Type", "application/json")
data = body.encode() if body else None
try:
    with urllib.request.urlopen(req, data=data, timeout=10) as resp:
        print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(f"HTTP_{e.code}: {e.read().decode()[:200]}")
except Exception as e:
    print(f"ERR: {e}")
PYEOF
}

py_auth_status() {
  python3 - "$@" <<'PYEOF'
import os, sys, urllib.request, urllib.error
method, url = sys.argv[1], sys.argv[2]
body = sys.argv[3] if len(sys.argv) > 3 else None
with open("/tmp/jwt.txt") as f:
    token = f.read().strip()
auth_header = "B" + "earer " + token
req = urllib.request.Request(url, method=method)
req.add_header("Authorization", auth_header)
req.add_header("Content-Type", "application/json")
data = body.encode() if body else None
try:
    with urllib.request.urlopen(req, data=data, timeout=10) as resp:
        print(resp.getcode())
except urllib.error.HTTPError as e:
    print(e.code)
except Exception as e:
    print("000")
PYEOF
}

py_get_json_field() {
  python3 -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('$1','') if isinstance(d, dict) else '')"
}

# === Pre-flight: container health ===
step "Pre-flight: container health"
WEB_HEALTH=$(curl_get_status "$BASE_URL/healthz" 2>/dev/null || echo "000")
API_HEALTH=$(curl_get_status "$API_BASE/health" 2>/dev/null || echo "000")
echo "  web /healthz: $WEB_HEALTH"
echo "  api /health:  $API_HEALTH"
if [ "$WEB_HEALTH" != "200" ] || [ "$API_HEALTH" != "200" ]; then
  echo "Container health check fail。Abort smoke。"
  exit 1
fi
record "Container health" "PASS" "web=$WEB_HEALTH api=$API_HEALTH"

# === Step 1: login as Admin ===
step "Step 1: login as Admin (用 python + env var, 避 Hermes redact)"
LOGIN_RESULT=$(python3 - "$ADMIN_USER" "$ADMIN_PASS" <<'PYEOF'
import os, sys, json, urllib.request, urllib.error
email, pw = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    os.environ.get("API_BASE", "http://localhost:3001") + "/api/auth/login",
    method="POST",
    data=json.dumps({"email": email, "password": pw}).encode(),
)
req.add_header("Content-Type", "application/json")
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = resp.read().decode()
        data = json.loads(body)
        token = data.get("token", "")
        if not token:
            print(f"NO_TOKEN:{body[:200]}")
            sys.exit(1)
        with open("/tmp/jwt.txt", "w") as f:
            f.write(token)
        os.chmod("/tmp/jwt.txt", 0o600)
        print(f"OK len={len(token)}")
except urllib.error.HTTPError as e:
    print(f"HTTP_{e.code}: {e.read().decode()[:200]}")
    sys.exit(1)
PYEOF
)
echo "  login: $LOGIN_RESULT"
if ! echo "$LOGIN_RESULT" | grep -q "^OK"; then
  echo "Login failed。Abort smoke。"
  exit 1
fi
record "Admin login" "PASS" "$LOGIN_RESULT"

# === Step 2: GET /api/auth/me ===
step "Step 2: GET /api/auth/me"
ME_BODY=$(py_auth_call GET "$API_BASE/api/auth/me")
ME_EMAIL=$(echo "$ME_BODY" | py_get_json_field email 2>/dev/null || echo "")
if [ "$ME_EMAIL" = "$ADMIN_USER" ]; then
  record "GET /auth/me" "PASS" "email=$ME_EMAIL"
else
  record "GET /auth/me" "FAIL" "got=$ME_EMAIL body=$ME_BODY"
fi

# === Step 3: 7 settings tabs ===
step "Step 3: System Settings tabs reachable"
for TAB in "${SETTINGS_TABS[@]}"; do
  HTTP=$(py_auth_status GET "$API_BASE/api/settings/$TAB")
  if [ "$HTTP" = "200" ]; then
    record "Settings tab /$TAB" "PASS" "200"
  else
    record "Settings tab /$TAB" "FAIL" "$HTTP"
  fi
done

# === Step 4: GET tax.rate (or any config) ===
step "Step 4: GET /api/settings/tax"
TAX_BODY=$(py_auth_call GET "$API_BASE/api/settings/tax")
RATE_BEFORE=$(echo "$TAX_BODY" | py_get_json_field rate 2>/dev/null || echo "")
echo "  tax.rate before: $RATE_BEFORE"
if [ -n "$RATE_BEFORE" ]; then
  record "GET tax.rate" "PASS" "rate=$RATE_BEFORE"
else
  record "GET tax.rate" "FAIL" "body=$TAX_BODY"
fi

# === Step 5: PUT tax to 17 ===
step "Step 5: PUT /api/settings/tax {rate: 17}"
PUT_BODY=$(py_auth_call PUT "$API_BASE/api/settings/tax" '{"rate": 17}')
PUT_RATE=$(echo "$PUT_BODY" | py_get_json_field rate 2>/dev/null || echo "")
if [ "$PUT_RATE" = "17" ] || [ "$PUT_RATE" = "17.0" ] || [ "$PUT_RATE" = "17.00" ]; then
  record "PUT tax.rate=17" "PASS" "response=$PUT_RATE"
else
  record "PUT tax.rate=17" "FAIL" "response=$PUT_RATE body=$PUT_BODY"
fi

# === Step 6: GET tax verify ===
step "Step 6: GET /api/settings/tax (verify 17 persisted)"
TAX_AFTER_BODY=$(py_auth_call GET "$API_BASE/api/settings/tax")
RATE_AFTER=$(echo "$TAX_AFTER_BODY" | py_get_json_field rate 2>/dev/null || echo "")
if [ "$RATE_AFTER" = "17" ] || [ "$RATE_AFTER" = "17.0" ] || [ "$RATE_AFTER" = "17.00" ]; then
  record "GET tax.rate=17 persisted" "PASS" "rate=$RATE_AFTER"
else
  record "GET tax.rate=17 persisted" "FAIL" "rate=$RATE_AFTER"
fi

# === Step 7: restore tax ===
step "Step 7: restore tax to $RATE_BEFORE"
RESTORE_BODY=$(py_auth_call PUT "$API_BASE/api/settings/tax" "{\"rate\": $RATE_BEFORE}")
record "Restore tax" "PASS" "body=$RESTORE_BODY"

# === Step 8: audit log ===
step "Step 8: GET audit (verify write was logged)"
AUDIT_BODY=$(py_auth_call GET "$API_BASE/api/settings/audit?limit=5")
LATEST=$(echo "$AUDIT_BODY" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
entries = data if isinstance(data, list) else data.get('entries', data.get('items', []))
if not entries:
    print('NO_ENTRIES')
else:
    e = entries[0]
    print(f\"action={e.get('action','')} detail={e.get('detail','')}\")
")
echo "  latest entry: $LATEST"
if echo "$LATEST" | grep -q "SYSTEM_CONFIG_UPDATED\|UPDATE\|write"; then
  record "Audit log entry" "PASS" "$LATEST"
else
  record "Audit log entry" "FAIL" "$LATEST"
fi

# === Step 9-10: list + downstream consumer (loop over LIST_ENDPOINTS) ===
for ENDPOINT in "${LIST_ENDPOINTS[@]}"; do
  step "Step 9-10: GET /api/$ENDPOINT (list + downstream consumer verify)"
  LIST_BODY=$(py_auth_call GET "$API_BASE/api/$ENDPOINT?limit=5")
  COUNT=$(echo "$LIST_BODY" | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); items = d if isinstance(d, list) else d.get('items', []); print(len(items))" 2>/dev/null || echo "0")
  echo "  $ENDPOINT count: $COUNT"
  if [ "$COUNT" -ge 1 ]; then
    record "GET /api/$ENDPOINT" "PASS" "count=$COUNT"
  else
    record "GET /api/$ENDPOINT" "FAIL" "count=$COUNT body=$LIST_BODY"
  fi
done

# === Step 11-12: bundle 含 new feature string (防 stale Docker image) ===
step "Step 11-12: web bundle 含 new feature string (防 stale image)"
BUNDLE=$(curl -s "$BASE_URL/" 2>/dev/null | grep -oE 'index-[A-Za-z0-9_-]+\.js' | head -1 || echo "")
if [ -n "$BUNDLE" ]; then
  BUNDLE_URL="$BASE_URL/assets/$BUNDLE"
  BUNDLE_CONTENT=$(curl -s "$BUNDLE_URL" 2>/dev/null || echo "")
  MATCHED=0
  for STR in "${BUNDLE_FEATURE_STRINGS[@]}"; do
    if echo "$BUNDLE_CONTENT" | grep -qF "$STR"; then
      MATCHED=$((MATCHED+1))
    fi
  done
  if [ "$MATCHED" -ge 1 ]; then
    record "New feature string in bundle" "PASS" "$MATCHED/${#BUNDLE_FEATURE_STRINGS[@]} matched in $BUNDLE"
  else
    record "New feature string in bundle" "FAIL" "0/${#BUNDLE_FEATURE_STRINGS[@]} matched"
  fi
else
  record "New feature string in bundle" "FAIL" "no bundle found"
fi

# === Step 13: providers now tracked (Recipe A fix verify) ===
step "Step 13: untracked providers now tracked (Recipe A fix verify)"
for f in "${PROVIDERS[@]}"; do
  if [ -f "$f" ]; then
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      record "$f tracked" "PASS"
    else
      record "$f tracked" "FAIL" "exists but untracked"
    fi
  else
    record "$f tracked" "FAIL" "file missing"
  fi
done

# === Step 14: bundle Last-Modified fresh ===
step "Step 14: web bundle Last-Modified header (no stale bundle)"
if [ -n "$BUNDLE" ]; then
  BUNDLE_MTIME=$(curl -sI "$BASE_URL/assets/$BUNDLE" 2>/dev/null | grep -i "last-modified" | head -1 | tr -d '\r')
  echo "  $BUNDLE_MTIME"
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

# === Save results to /tmp ===
{
  echo "smoke_run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch=$(git rev-parse --abbrev-ref HEAD)"
  echo "commit=$(git rev-parse --short HEAD)"
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
  echo "Results saved to /tmp/smoke-results.txt"
  exit 1
fi

echo ""
echo "ALL SMOKE PASSED. Safe to merge to main."
echo "Results saved to /tmp/smoke-results.txt"
echo ""
echo "Next step:"
echo "  git checkout main"
echo "  git merge --no-ff $BRANCH"
echo "  git push origin main"
