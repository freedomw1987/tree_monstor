#!/usr/bin/env bash
# ============================================================
# PM-System — Build multi-arch images + save to .tar
# Copy 落 <project>/scripts/build-release.sh, chmod +x
#
# 用法:
#   ./scripts/build-release.sh v1.0.0
#
# Output:
#   deploy/dist/pm-system-frontend-v1.0.0.tar
#   deploy/dist/pm-system-backend-v1.0.0-multiarch.tar
#   deploy/dist/CHECKSUMS.sha256
#   deploy/dist/RELEASE-NOTES.md
#
# 重點:
# - 用 docker buildx + docker-container driver 做 multi-arch
# - Backend 兩 platform 各 build 一個 tag,再 docker manifest create 做 manifest list
# - Frontend 雖然 nginx platform-neutral 唔使 multi-arch,為咗結構一致都 build 兩份
# ============================================================
set -euo pipefail

VERSION="${1:-}"
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "❌ 用法: $0 vX.Y.Z"; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/deploy/dist"
mkdir -p "$DIST_DIR"

FRONTEND_TAG="pm-system-frontend:$VERSION"
BACKEND_TAG="pm-system-backend:$VERSION"
TMP_AMD="pm-system-backend:$VERSION-amd64"
TMP_ARM="pm-system-backend:$VERSION-arm64"
FRONTEND_TAR="$DIST_DIR/pm-system-frontend-$VERSION.tar"
BACKEND_TAR="$DIST_DIR/pm-system-backend-$VERSION-multiarch.tar"
CHECKSUMS="$DIST_DIR/CHECKSUMS.sha256"

echo "============================================================"
echo " PM-System Release Build: $VERSION"
echo "============================================================"

# buildx builder
BUILDER_NAME="pm-system-multiarch"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER_NAME"

# Build frontend
echo "→ Build frontend"
docker buildx build --platform linux/amd64,linux/arm64 \
  --tag "$FRONTEND_TAG" --file "$PROJECT_ROOT/frontend/Dockerfile" --load \
  "$PROJECT_ROOT/frontend"

# Build backend per-arch
echo "→ Build backend linux/amd64"
docker buildx build --platform linux/amd64 \
  --tag "$TMP_AMD" --file "$PROJECT_ROOT/backend/Dockerfile" --load \
  "$PROJECT_ROOT/backend"

echo "→ Build backend linux/arm64"
docker buildx build --platform linux/arm64 \
  --tag "$TMP_ARM" --file "$PROJECT_ROOT/backend/Dockerfile" --load \
  "$PROJECT_ROOT/backend"

# Manifest list
echo "→ Create manifest list: $BACKEND_TAG"
docker manifest create "$BACKEND_TAG" --amend "$TMP_AMD" --amend "$TMP_ARM"
docker manifest annotate "$BACKEND_TAG" "$TMP_ARM" --os linux --arch arm64
docker manifest annotate "$BACKEND_TAG" "$TMP_AMD" --os linux --arch amd64

# Save
echo "→ Save frontend tar"
docker save -o "$FRONTEND_TAR" "$FRONTEND_TAG"
echo "  ✓ $(du -h "$FRONTEND_TAR" | cut -f1)"

echo "→ Save backend multi-arch tar"
docker save -o "$BACKEND_TAR" "$BACKEND_TAG" "$TMP_AMD" "$TMP_ARM"
echo "  ✓ $(du -h "$BACKEND_TAR" | cut -f1)"

# Checksums
( cd "$DIST_DIR" && shasum -a 256 \
    "$(basename "$FRONTEND_TAR")" "$(basename "$BACKEND_TAR")" > "$CHECKSUMS" )
cat "$CHECKSUMS"

# Cleanup intermediate
docker rmi "$TMP_AMD" "$TMP_ARM" 2>/dev/null || true

# Release notes template
cat > "$DIST_DIR/RELEASE-NOTES.md" <<EOF
# PM-System Release $VERSION

**Build date:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Architectures:** linux/amd64, linux/arm64

## What's in this release
<!-- 寫返今次 release 改咗咩 -->

## Install
詳見 package 入面 README.md。

\`\`\`
$(cat "$CHECKSUMS")
\`\`\`
EOF

echo ""
echo " ✅ Build complete → $DIST_DIR"
ls -lh "$DIST_DIR"
