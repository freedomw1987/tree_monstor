#!/usr/bin/env bash
# ============================================================================
# 1-click commit 3 個 untracked providers
# 解 prod build fail(HEAD 嘅 deals.tsx / quotations.tsx 已 import 緊 untracked file)
# ============================================================================
#
# Usage:
#   cd ~/www/<project>
#   bash templates/commit-untracked-files.sh
#
# Pre-condition:
#   - 你 on 目標 branch(預設 feat/<feature>-<date>)
#   - N 個 untracked providers 仍 `??`(本腳本會 verify)
#   - Working tree 冇 modified file
#
# Post-condition:
#   - 1 個新 commit 加 N 個 untracked provider
#   - Handoff scratch doc 仍 untracked(由你決定 rm 或留)
#   - Ready to: bash templates/push-after-commit.sh
# ============================================================================

set -euo pipefail

# === 設定: 改呢度適配你個 stack ===
BRANCH="${BRANCH:-feat/system-settings-tabs-2026-06-07}"   # 你嘅 feature branch
PROVIDERS=(
  "apps/web/src/components/multi-autocomplete.tsx"
  "apps/web/src/components/multi-company-autocomplete.tsx"
  "apps/web/src/components/multi-user-autocomplete.tsx"
)
# 加多個 import + symbol 對應 common file
IMPORT_SENTINEL_FILE="${IMPORT_SENTINEL_FILE:-apps/web/src/pages/deals.tsx}"
IMPORT_SENTINEL_STRING="${IMPORT_SENTINEL_STRING:-from '@/components/multi-company-autocomplete'}"
COMMIT_MSG="${COMMIT_MSG:-feat(web): add 3 multi-select Autocomplete components used by deals.tsx + quotations.tsx

HEAD 嘅 consumer file 早已 import multi-*.tsx, 但 component file 從未 commit,
導致 dev build OK (Vite 攞 working tree) 但 prod build 必 FAIL (git clone 後 working tree 冇呢啲 file)。

Refs: retro/$(date +%Y-%m-%d)}"

# === safety check 0: on right branch ===
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ 你而家 on '$CURRENT_BRANCH',唔係 '$BRANCH'。abort。"
  exit 1
fi

# === safety check 1: confirm providers 仍 untracked ===
UNTRACKED=$(git status --porcelain | awk '{print $2}' | sort)
for f in "${PROVIDERS[@]}"; do
  if ! grep -qxF "$f" <<<"$UNTRACKED"; then
    echo "❌ Expected untracked file missing or already tracked: $f"
    echo "--- current untracked ---"
    echo "$UNTRACKED"
    exit 1
  fi
done
echo "✓ Safety check 1: ${#PROVIDERS[@]} 個 untracked provider 確認"

# === safety check 2: HEAD 真係 import 緊 (sanity) ===
if ! grep -q "$IMPORT_SENTINEL_STRING" "$IMPORT_SENTINEL_FILE"; then
  echo "❌ $IMPORT_SENTINEL_FILE 唔再含 '$IMPORT_SENTINEL_STRING',本 commit 可能無必要"
  exit 1
fi
echo "✓ Safety check 2: $IMPORT_SENTINEL_FILE 真係 import 緊 providers"

# === safety check 3: working tree 乾淨 ===
MODIFIED=$(git status --porcelain | awk '$1 != "??"' || true)
if [ -n "$MODIFIED" ]; then
  echo "❌ 有 modified/staged file,本腳本只處理 untracked,請先 stash 或 commit:"
  echo "$MODIFIED"
  exit 1
fi
echo "✓ Safety check 3: 冇 modified file"

# === step 1: stage providers ===
git add "${PROVIDERS[@]}"

echo "--- git status after git add ---"
git status --short

# === step 2: diff stat (Ctrl-C if looks wrong) ===
echo ""
echo "=== files staged for commit ==="
git diff --cached --stat

# === step 3: commit ===
git commit -m "$COMMIT_MSG"

echo ""
echo "=== result ==="
git log --oneline -3
echo ""
echo "--- git status ---"
git status --short
echo ""
echo "✅ ${#PROVIDERS[@]} 個 provider 已 commit。"
echo ""
echo "Next step:"
echo "  bash templates/push-after-commit.sh"
