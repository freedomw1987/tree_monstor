#!/usr/bin/env bash
# ============================================================
# Template: PM-System-style per-arch release build
# Drop into scripts/build-release.sh, adjust the build_one() call
# sites for your service names. See the docker-multiarch-offline-handoff
# skill for the full decision context and pitfalls.
#
# Usage: ./scripts/build-release.sh v1.0.0
# ============================================================
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]] || [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Usage: $0 vX.Y.Z"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/deploy/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

BUILDER_NAME="multiarch-offline-handoff"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER_NAME"

# Adjust this list to your services.
SERVICES=(frontend backend)
# Add more services if needed; each gets 2 platform builds + 2 tars.

build_one() {
  local SERVICE="$1" PLATFORM="$2" SUFFIX="$3"
  local TAG="${SERVICE}:${VERSION}-${SUFFIX}"
  local TAR="$DIST_DIR/${SERVICE}-${VERSION}-${SUFFIX}.tar"

  echo "→ Build $SERVICE for $PLATFORM"
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

for SVC in "${SERVICES[@]}"; do
  build_one "$SVC" linux/amd64 amd64
  build_one "$SVC" linux/arm64 arm64
done

# Checksums
( cd "$DIST_DIR" && shasum -a 256 *.tar > CHECKSUMS.sha256 )
cat "$DIST_DIR/CHECKSUMS.sha256"

echo ""
echo "✅ Done. Output: $DIST_DIR"
ls -lh "$DIST_DIR"
