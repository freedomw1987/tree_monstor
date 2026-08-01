#!/usr/bin/env bash
# ============================================================================
# 1-click push 落 origin after commit
# ============================================================================
#
# Usage:
#   cd ~/www/<project>
#   bash templates/push-after-commit.sh
# ============================================================================

set -euo pipefail

BRANCH="${BRANCH:-feat/system-settings-tabs-2026-06-07}"   # 同 commit script 對齊

# === safety check: on right branch ===
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ 你 on '$CURRENT_BRANCH',唔係 '$BRANCH'"
  exit 1
fi

# === safety check: working tree 淨係 untracked (h Scratch doc) ===
MODIFIED=$(git status --porcelain | awk '$1 != "??"' || true)
if [ -n "$MODIFIED" ]; then
  echo "❌ 有 modified file,先處理:"
  echo "$MODIFIED"
  exit 1
fi

# === push ===
git push origin "$BRANCH"

echo ""
echo "=== push 完成,origin/HEAD 狀態 ==="
git log --oneline "origin/$BRANCH" -3
echo ""
echo "Next step:"
echo "  ssh <staging-host>"
echo "  cd /opt/<project>"
echo "  git fetch && git checkout $BRANCH && git pull"
echo "  docker compose ... up -d --build web api"
echo "  export ADMIN_USER=... ADMIN_PASS=..."
echo "  bash templates/smoke-before-merge.sh"
