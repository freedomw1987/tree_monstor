#!/usr/bin/env bash
# ============================================================
# 客戶 release image build script — known-good template
#
# 用法: ./scripts/build-release.sh v1.0.0
#
# 設計:
#   - Per-arch tarball(2 個 service × 2 個 arch = 4 個 tar)
#   - Tag pattern: <service>:vX.Y.Z-<arch>     (e.g. pm-system-backend:v1.0.0-amd64)
#   - install.sh 會 load 對 arch 嘅 tar,再 docker tag 改做 :vX.Y.Z
#
# 環境:
#   - Docker Desktop 23+ (內置 buildx)
#   - Mac arm64 / Linux x86_64 都行(Mac QEMU 模擬 arm64 慢 5-10x, 接受)
#
# Output 喺 deploy/dist/:
#   myapp-{service}-{version}-{arch}.tar  (4 份)
#   CHECKSUMS.sha256
#   RELEASE-NOTES.md
# ============================================================
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "❌ 用法: $0 <version>   e.g. $0 v1.0.0"
  exit 1
fi
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ 版本格式要 vX.Y.Z, 你入嘅: $VERSION"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/deploy/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "============================================================"
echo " Release build (per-arch tarballs)"
echo " Version: $VERSION"
echo " Output:  $DIST_DIR"
echo "============================================================"

# Named buildx builder(可重用)
BUILDER_NAME="myapp-multiarch"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "→ 建立 buildx builder: $BUILDER_NAME"
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER_NAME"

# Build + save 4 次
build_one() {
  local SERVICE="$1" PLATFORM="$2" SUFFIX="$3"
  local TAG="myapp-${SERVICE}:${VERSION}-${SUFFIX}"
  local TAR="$DIST_DIR/myapp-${SERVICE}-${VERSION}-${SUFFIX}.tar"

  echo ""
  echo "→ Build $SERVICE for $PLATFORM (tag: $TAG)"
  docker buildx build \
    --platform "$PLATFORM" \
    --tag "$TAG" \
    --file "$PROJECT_ROOT/$SERVICE/Dockerfile" \
    --load \
    "$PROJECT_ROOT/$SERVICE"

  echo "→ Save $TAG → $TAR"
  docker save -o "$TAR" "$TAG"
  echo "  ✓ $(du -h "$TAR" | cut -f1)"
}

build_one frontend linux/amd64 amd64
build_one frontend linux/arm64 arm64
build_one backend  linux/amd64 amd64
build_one backend  linux/arm64 arm64

# Checksums
echo ""
echo "→ CHECKSUMS.sha256"
(
  cd "$DIST_DIR"
  shasum -a 256 myapp-*.tar > CHECKSUMS.sha256
)
cat "$DIST_DIR/CHECKSUMS.sha256"

# Release notes template(人手填 TBD)
RELEASE_NOTES="$DIST_DIR/RELEASE-NOTES.md"
cat > "$RELEASE_NOTES" <<EOF
# Release $VERSION

**Build date:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Architectures:** linux/amd64, linux/arm64

## What's in this release
<!-- 寫返今次 release 改咗咩: bug fixes, new features, breaking changes -->
- TBD

## Install
詳見 install.sh。客戶機: \`./install.sh\`
EOF

echo ""
echo "============================================================"
echo " ✅ Build complete — $DIST_DIR"
ls -lh "$DIST_DIR"
