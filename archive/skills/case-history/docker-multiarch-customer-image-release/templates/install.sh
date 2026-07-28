#!/usr/bin/env bash
# ============================================================
# 客戶機一鍵安裝腳本 — known-good template
#
# 自動偵測 uname -m 揀返合 arch 嘅 tar load:
#   x86_64  → load amd64 tar
#   aarch64 → load arm64 tar
#
# 用法:
#   1. 解壓 release package
#   2. cd 入 folder
#   3. ./install.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step()  { echo -e "\n${BLUE}==>${NC} $*"; }
ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }

# ── 0. Pre-flight ────────────────────────────────────────────
step "0/6 Pre-flight checks"
command -v docker >/dev/null 2>&1 || fail "Docker 冇裝: https://docs.docker.com/engine/install/"
ok "docker $(docker --version | awk '{print $3}' | tr -d ',')"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 唔識用"
ok "docker compose $(docker compose version --short)"

# ── 1. 偵測 architecture ────────────────────────────────────
step "1/6 偵測 server architecture"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64)        ARCH_DIR="amd64" ;;
  aarch64|arm64) ARCH_DIR="arm64" ;;
  *) fail "唔支援嘅 architecture: $ARCH_RAW" ;;
esac
ok "本機 architecture: $ARCH_RAW → 用 $ARCH_DIR image"

# ── 2. .env ───────────────────────────────────────────────────
step "2/6 準備 .env"
[[ ! -f .env.client.example ]] && fail "搵唔到 .env.client.example"
if [[ -f .env ]]; then
  warn ".env 已經存在, 留低唔覆寫"
else
  cp .env.client.example .env
  ok "由 .env.client.example 抄咗做 .env"
fi
source .env

placeholder_check() { [[ "$1" =~ PLACEHOLDER ]] && return 1 || return 0; }

MISSING=()
[[ "${VERSION:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || MISSING+=("VERSION (e.g. v1.0.0)")
placeholder_check "${DB_PASSWORD:-}" || MISSING+=("DB_PASSWORD (run: openssl rand -hex 24)")
placeholder_check "${JWT_SECRET:-}" || MISSING+=("JWT_SECRET (run: openssl rand -hex 32)")

if (( ${#MISSING[@]} > 0 )); then
  fail "以下 .env field 未填或用緊 placeholder:\n    - ${MISSING[*]}\n\n請 edit .env 後再跑"
fi
ok "所有必填 field 已就緒"

# ── 3. 搵對應 arch 嘅 tar ────────────────────────────────────
step "3/6 搵 $ARCH_DIR image tar"
FRONTEND_TAR="$(ls myapp-frontend-${VERSION}-${ARCH_DIR}.tar 2>/dev/null | head -1 || true)"
BACKEND_TAR="$(ls  myapp-backend-${VERSION}-${ARCH_DIR}.tar  2>/dev/null | head -1 || true)"
[[ -n "$FRONTEND_TAR" ]] || fail "搵唔到 frontend tar(預期 myapp-frontend-${VERSION}-${ARCH_DIR}.tar)"
[[ -n "$BACKEND_TAR"  ]] || fail "搵唔到 backend tar(預期 myapp-backend-${VERSION}-${ARCH_DIR}.tar)"
ok "frontend tar: $FRONTEND_TAR"
ok "backend  tar: $BACKEND_TAR"

if [[ -f CHECKSUMS.sha256 ]]; then
  step "(可選) 驗 CHECKSUMS.sha256"
  if shasum -a 256 -c CHECKSUMS.sha256 2>&1 | grep -q FAILED; then
    fail "Checksum 驗證失敗!tarball 可能壞咗, 請重新下載"
  fi
  ok "Checksum OK"
else
  warn "冇 CHECKSUMS.sha256, skip"
fi

# ── 4. Docker load + re-tag ───────────────────────────────────
step "4/6 Docker load images"
if docker image inspect "myapp-frontend:$VERSION" >/dev/null 2>&1 \
   && docker image inspect "myapp-backend:$VERSION"  >/dev/null 2>&1; then
  warn "image 已經 load 過($VERSION), skip"
else
  docker load -i "$FRONTEND_TAR"; ok "frontend loaded ($ARCH_DIR)"
  docker load -i "$BACKEND_TAR";  ok "backend  loaded ($ARCH_DIR)"
  # Docker daemon image index 嘅 sync 偶爾有 race
  sleep 1
fi

# 我哋 build script 將 image tag 為 :v1.0.0-{arch}, 改做 :v1.0.0 畀 compose 用
step "→ Re-tag images: $VERSION-{arch} → $VERSION"
docker tag "myapp-frontend:$VERSION-${ARCH_DIR}" "myapp-frontend:$VERSION"
docker tag "myapp-backend:$VERSION-${ARCH_DIR}"  "myapp-backend:$VERSION"
ok "re-tag done"

docker image inspect "myapp-frontend:$VERSION" >/dev/null || fail "frontend re-tag 後搵唔到"
docker image inspect "myapp-backend:$VERSION"  >/dev/null || fail "backend re-tag 後搵唔到"

# ── 5. 啟動 ──────────────────────────────────────────────────
step "5/6 啟動 containers"
docker compose \
  -f docker-compose.client.yml \
  --env-file .env \
  --project-name myapp \
  up -d
ok "containers 啟動中"

# ── 6. 等 health check ───────────────────────────────────────
step "6/6 等 backend health (最長 90 秒)"
MAX_WAIT=90; WAITED=0
while (( WAITED < MAX_WAIT )); do
  if curl -fsS "http://127.0.0.1:${FRONTEND_HOST_PORT:-80}/api/health" >/dev/null 2>&1; then
    ok "backend healthy (用咗 ${WAITED}s)"
    break
  fi
  sleep 3; WAITED=$((WAITED+3))
  echo "    等待中... ${WAITED}s / ${MAX_WAIT}s"
done
(( WAITED >= MAX_WAIT )) && fail "90 秒內 backend 仲未 ready, 試 docker compose -p myapp logs -f"

FRONT_PORT="${FRONTEND_HOST_PORT:-80}"
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -z "$HOST_IP" ]] && HOST_IP="localhost"

cat <<EOF

  ✅ MyApp 已經運行

  訪問 URL(本機):    http://localhost:${FRONT_PORT}/
  訪問 URL(網絡):    http://${HOST_IP}:${FRONT_PORT}/

  常用指令:
    docker compose -p myapp ps           # 睇 status
    docker compose -p myapp logs -f      # 睇 logs
    docker compose -p myapp restart      # 重啟
    docker compose -p myapp down         # 停機(保留 data)
    docker compose -p myapp down -v      # 完全清除(包埋 database)

EOF
