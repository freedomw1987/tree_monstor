#!/usr/bin/env bash
# ============================================================
# PM-System 客戶機一鍵安裝 — template
# Copy 落 <project>/deploy/install.sh, chmod +x install.sh
#
# 佢會做 6 個 step:
#   0. Pre-flight(docker + docker compose 齊唔齊)
#   1. 準備 .env + 驗必填 field
#   2. 搵 image tar + 驗 CHECKSUMS
#   3. Docker load 兩個 image
#   4. docker compose up -d
#   5. 等 backend health(最長 90s)
#   6. 印 access URL
# ============================================================
set -euo pipefail

# ── 顏色 ────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step()  { echo -e "\n${BLUE}==>${NC} $*"; }
ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }

# ── 0. Pre-flight ───────────────────────────
step "0/6 Pre-flight checks"
command -v docker >/dev/null 2>&1 || fail "Docker 冇裝"
ok "docker $(docker --version | awk '{print $3}' | tr -d ',')"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 唔識用"
ok "docker compose $(docker compose version --short)"

# ── 1. .env 準備 + 驗 ───────────────────────
step "1/6 準備 .env"
[[ -f .env.client.example ]] || fail "搵唔到 .env.client.example"
if [[ -f .env ]]; then
  warn ".env 已存在,留低唔覆寫"
else
  cp .env.client.example .env
  ok "由 .env.client.example 抄咗做 .env"
fi
source .env

# 驗必填 field(用 regex check PLACEHOLDER)
placeholder_check() { [[ ! "$1" =~ PLACEHOLDER ]]; }
MISSING=()
[[ "${VERSION:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || MISSING+=("VERSION (e.g. v1.0.0)")
[[ -n "${DB_USER:-}"   ]] || MISSING+=("DB_USER")
placeholder_check "${DB_PASSWORD:-}" || MISSING+=("DB_PASSWORD (run: openssl rand -hex 24)")
[[ -n "${DB_NAME:-}"   ]] || MISSING+=("DB_NAME")
placeholder_check "${JWT_SECRET:-}" || MISSING+=("JWT_SECRET (run: openssl rand -hex 32)")
(( ${#MISSING[@]} > 0 )) && fail "以下 .env field 未填或用緊 placeholder:\n    - ${MISSING[*]}\n\n請 edit .env 後再跑"
ok "所有必填 field 已就緒"

# ── 2. 搵 tar + 驗 checksum ───────────────
step "2/6 搵 image tar"
FRONTEND_TAR="$(ls pm-system-frontend-v*.tar 2>/dev/null | head -1 || true)"
BACKEND_TAR="$(ls pm-system-backend-v*-multiarch.tar 2>/dev/null | head -1 || true)"
[[ -n "$FRONTEND_TAR" ]] || fail "搵唔到 frontend image tar"
[[ -n "$BACKEND_TAR"  ]] || fail "搵唔到 backend image tar"
ok "frontend: $FRONTEND_TAR"
ok "backend:  $BACKEND_TAR"

if [[ -f CHECKSUMS.sha256 ]]; then
  step "(可選) 驗 CHECKSUMS.sha256"
  if shasum -a 256 -c CHECKSUMS.sha256 2>&1 | grep -q FAILED; then
    fail "Checksum 驗證失敗!tarball 可能壞咗"
  fi
  ok "Checksum OK"
else
  warn "冇 CHECKSUMS.sha256, skip"
fi

# ── 3. Docker load ──────────────────────────
step "3/6 Docker load images"
if docker image inspect "pm-system-frontend:$VERSION" >/dev/null 2>&1 \
   && docker image inspect "pm-system-backend:$VERSION" >/dev/null 2>&1; then
  warn "image 已經 load 過, skip"
else
  docker load -i "$FRONTEND_TAR"; ok "frontend loaded"
  docker load -i "$BACKEND_TAR";  ok "backend loaded(multi-arch)"
fi

# ── 4. Compose up ───────────────────────────
step "4/6 docker compose up -d"
docker compose \
  -f docker-compose.client.yml \
  --env-file .env \
  --project-name pm-system \
  up -d
ok "containers 啟動中"

# ── 5. 等 health ────────────────────────────
step "5/6 等 backend health(最長 90s)"
MAX_WAIT=90; WAITED=0
while (( WAITED < MAX_WAIT )); do
  if curl -fsS http://127.0.0.1:4000/api/projects >/dev/null 2>&1 \
     || curl -fsS http://127.0.0.1/api/projects >/dev/null 2>&1; then
    ok "backend healthy (${WAITED}s)"
    break
  fi
  sleep 3; WAITED=$((WAITED+3))
  echo "    等待中... ${WAITED}s / ${MAX_WAIT}s"
done
(( WAITED >= MAX_WAIT )) && fail "90s 內 backend 仲未 ready,試 docker compose logs -f 睇下咩事"

# ── 6. 印 access info ──────────────────────
step "6/6 完成 ✓"
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost')"
cat <<EOF

  ✅ PM-System 已經運行

  訪問 URL(本機):  http://localhost:${FRONTEND_HOST_PORT:-80}/
  訪問 URL(網絡):  http://${HOST_IP}:${FRONTEND_HOST_PORT:-80}/

  常用指令:
    docker compose -p pm-system ps           # status
    docker compose -p pm-system logs -f      # logs
    docker compose -p pm-system restart      # restart
    docker compose -p pm-system down         # 停(保留 data)
    docker compose -p pm-system down -v      # 完整清除

EOF
