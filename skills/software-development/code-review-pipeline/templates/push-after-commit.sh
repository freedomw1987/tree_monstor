#!/usr/bin/env bash
# ============================================================================
# 1-click push to origin after commit (generic, customize BRANCH)
# Pattern: lightweight safety-checked push script
# ============================================================================
#
# Usage:
#   bash /tmp/push-after-commit.sh
#
# Customize: BRANCH variable below
# ============================================================================

set -euo pipefail

# --- Customize: 你的 feature branch 名 ---
BRANCH="feat/your-feature-branch-YYYY-MM-DD"
# --- End customize ---

# --- safety check 0: on right branch ---
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ 你 on '$CURRENT_BRANCH',唔係 '$BRANCH'"
  exit 1
fi

# --- safety check 1: clean working tree (only skip list should be untracked) ---
MODIFIED=$(git status --porcelain | awk '$1 != "??"' || true)
if [ -n "$MODIFIED" ]; then
  echo "❌ 有 modified file,先處理:"
  echo "$MODIFIED"
  exit 1
fi

# --- push ---
git push origin "$BRANCH"

echo ""
echo "=== push 完成 ==="
git log --oneline origin/"$BRANCH" -3
