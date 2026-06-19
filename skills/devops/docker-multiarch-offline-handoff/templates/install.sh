#!/usr/bin/env bash
# ============================================================
# Template: per-arch install.sh for customer
# Drop into deploy/install.sh alongside docker-compose.yml and
# the per-arch tarballs produced by build-release.sh.
# See the docker-multiarch-offline-handoff skill for the full
# decision context and pitfalls.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step()  { echo -e "\n${BLUE}==>${NC} $*"; }
ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }

# ── 0. Pre-flight ────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || fail "Docker not installed"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 not installed"

# ── 1. Auto-detect arch ──────────────────────────────────────
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64)        ARCH_DIR="amd64" ;;
  aarch64|arm64) ARCH_DIR="arm64" ;;
  *) fail "Unsupported arch: $ARCH_RAW" ;;
esac
ok "Architecture: $ARCH_RAW → using $ARCH_DIR images"

# ── 2. Read .env ─────────────────────────────────────────────
if [[ ! -f .env.client.example ]]; then
  fail ".env.client.example missing — release package incomplete"
fi
[[ -f .env ]] || cp .env.client.example .env
set -a; source .env; set +a
[[ "${VERSION:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION not set in .env"

# ── 3. Find per-arch tars ────────────────────────────────────
# Adjust the service name list to match your build script.
for SVC in frontend backend; do
  T=$(ls ${SVC}-${VERSION}-${ARCH_DIR}.tar 2>/dev/null | head -1) || true
  [[ -n "$T" ]] || fail "Missing ${SVC}-${VERSION}-${ARCH_DIR}.tar"
  eval "TAR_${SVC^^}=$T"
done
ok "Tars found: $TAR_FRONTEND, $TAR_BACKEND"

# ── 4. Load images ───────────────────────────────────────────
docker load -i "$TAR_FRONTEND"
docker load -i "$TAR_BACKEND"

# CRITICAL: re-tag to arch-less version. See skill pitfall section.
docker tag "frontend:${VERSION}-${ARCH_DIR}" "frontend:${VERSION}"
docker tag "backend:${VERSION}-${ARCH_DIR}"  "backend:${VERSION}"
ok "Images loaded and re-tagged to ${VERSION}"

# ── 5. Compose up ────────────────────────────────────────────
docker compose -f docker-compose.yml --env-file .env up -d
ok "Containers started"

# ── 6. Health check ──────────────────────────────────────────
echo "Waiting for backend to become healthy (up to 90s)..."
for i in {1..30}; do
  if docker compose ps backend 2>/dev/null | grep -q "(healthy)"; then
    ok "Backend healthy after ${i}*3s"
    break
  fi
  sleep 3
done

echo ""
echo "${GREEN}✅ PM-System is running${NC}"
echo "  Access: http://localhost/"
