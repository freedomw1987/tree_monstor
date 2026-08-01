#!/usr/bin/env bash
# ============================================================================
# 1-click 落 commit N 個 untracked files (解 prod build fail)
# Pattern: safety-checked auto-commit of WIP untracked files
# 跳過 handoff scratch docs (已 superseded by shipped retro)
# ============================================================================
#
# Usage:
#   bash /tmp/commit-untracked-files.sh
#
# Pre-condition:
#   - 你 on feature branch <branch-name>
#   - N 個 untracked file 仍然 expected (呢個 script 會 verify)
#
# Post-condition:
#   - 1 個新 commit 加晒 N 個 untracked file
#   - Skip list (handoff docs) 仍然 untracked (由你決定 rm 或留)
#   - 推送後 staging / prod 即可 build
#
# 安全: 3-4 個 safety check 確認 branch / file list / working tree / HEAD
# imports 對齊,全綠先 commit。
# ============================================================================

set -euo pipefail

# --- 1. Customize 呢 3 段 per project ---
BRANCH="feat/your-feature-branch-YYYY-MM-DD"
COMMIT_FILES=(
  "apps/web/src/components/multi-autocomplete.tsx"
  "apps/web/src/components/multi-company-autocomplete.tsx"
  "apps/web/src/components/multi-user-autocomplete.tsx"
)
# Files to leave untracked (handoff scratch, WIP, etc.)
SKIP_FILES=(
  "docs/retros/2026-MM-DD-feature-handoff.md"
)
# A file that imports one of COMMIT_FILES (sanity check)
IMPORT_CHECK_FILE="apps/web/src/pages/deals.tsx"
IMPORT_CHECK_PATTERN="multi-company-autocomplete"
# --- End customize ---

# --- safety check 0: 必須 on right branch ---
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ 你而家 on '$CURRENT_BRANCH',唔係 '$BRANCH'。abort。"
  exit 1
fi

# --- safety check 1: confirm N 個 untracked file 仍然 expected ---
UNTRACKED=$(git status --porcelain | awk '{print $2}' | sort)
EXPECTED=("${COMMIT_FILES[@]}" "${SKIP_FILES[@]}")
for f in "${EXPECTED[@]}"; do
  if ! grep -qxF "$f" <<<"$UNTRACKED"; then
    echo "❌ Expected untracked file missing or already tracked: $f"
    echo "--- current untracked ---"
    echo "$UNTRACKED"
    exit 1
  fi
done
echo "✓ Safety check 1: ${#EXPECTED[@]} 個 expected untracked file 確認"

# --- safety check 2: HEAD import the file (sanity, ensures needed) ---
if [ -n "$IMPORT_CHECK_FILE" ] && [ -n "$IMPORT_CHECK_PATTERN" ]; then
  if ! grep -q "$IMPORT_CHECK_PATTERN" "$IMPORT_CHECK_FILE" 2>/dev/null; then
    echo "⚠️ $IMPORT_CHECK_FILE 唔再 import $IMPORT_CHECK_PATTERN"
    echo "可能 N 個 file 已經唔再需要,continue 仍 OK。"
  else
    echo "✓ Safety check 2: $IMPORT_CHECK_FILE 真係 import $IMPORT_CHECK_PATTERN"
  fi
fi

# --- safety check 3: working tree clean (no other modifications) ---
MODIFIED=$(git status --porcelain | awk '$1 != "??"' || true)
if [ -n "$MODIFIED" ]; then
  echo "❌ 有 modified/staged file,本腳本只處理 untracked,請先 stash 或 commit:"
  echo "$MODIFIED"
  exit 1
fi
echo "✓ Safety check 3: 冇 modified file"

# --- step 1: stage N 個 target file ---
git add "${COMMIT_FILES[@]}"

echo "--- git status after git add ---"
git status --short

# --- step 2: show diff stat (you can Ctrl-C if looks wrong) ---
echo ""
echo "=== files staged for commit ==="
git diff --cached --stat

# --- step 3: commit ---
# Customize message: explain why N 個 file 必須 commit (常見 reason:
# HEAD 已 commit consumer imports, prod build 必 fail without components)
COMMIT_MSG="feat(<scope>): add N 個 <component-type> components used by <consumer-files>

HEAD 嘅 <consumer-files> 早已 import 呢 N 個 component(commit <hash>),
但 component file 從未 commit,導致 prod build 必 fail (Vite 喺
git clone 出嘅 working tree 內 resolve 唔到 import path)。

Call sites:
- file1.tsx line N <Component>
- file2.tsx line M <Component>

Refs: retro/YYYY-MM-DD-feature.md §Decisions N"

git commit -m "$COMMIT_MSG"

# --- step 4: print result ---
echo ""
echo "=== result ==="
git log --oneline -3
echo ""
echo "--- git status ---"
git status --short
echo ""
echo "✅ ${#COMMIT_FILES[@]} 個 file 已 commit。"
echo ""
echo "Next step:"
echo "  bash /tmp/push-after-commit.sh  # generic version, customize BRANCH"
echo ""
echo "(optional) cleanup handoff doc(s):"
for f in "${SKIP_FILES[@]}"; do
  echo "  rm $f"
done
