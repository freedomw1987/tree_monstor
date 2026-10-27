#!/usr/bin/env bash
# scripts/install-local-hooks.sh — 安裝 pre-push 閘（.git/hooks/pre-push）
#
# 做咩：把 `scripts/hooks/pre-push.sh` 裝成 git 嘅 pre-push hook，
#        令 push 之前自動跑一次本機 CI 等價檢查（scripts/check-all.sh）。
#
# 用法：bash scripts/install-local-hooks.sh [--uninstall]
# 移除：rm -f "$(git rev-parse --git-path hooks)/pre-push"     # 等價手動指令
#
# ⚠️ 唔會靜靜哋覆蓋你原有嘅 hook：目標已經係本 repo 嘅 hook（內容有 marker）→ 直接更新；
#    目標係你自己嘅 hook → 先備份成 `<原檔>.bak.<時間戳>`，再裝 ours。

set -euo pipefail

if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "FAIL: 唔喺 git repo 入面" >&2
  exit 2
fi
cd "$REPO_ROOT"

SRC="$REPO_ROOT/scripts/hooks/pre-push.sh"
MARKER="tree_monstor-local-ci-gate-v1"

HOOK_DIR="$(git rev-parse --git-path hooks)"
case "$HOOK_DIR" in
  /*) ;;
  *) HOOK_DIR="$REPO_ROOT/$HOOK_DIR" ;;
esac
DEST="$HOOK_DIR/pre-push"

if [ "${1:-}" = "--uninstall" ]; then
  if [ ! -e "$DEST" ]; then
    echo "冇 hook 要卸（${DEST} 唔存在）"
    exit 0
  fi
  if ! grep -qF "$MARKER" "$DEST" 2>/dev/null; then
    echo "⚠️  ${DEST} 唔係本 repo 嘅 hook（冇 marker）→ 唔郁它" >&2
    exit 1
  fi
  rm -f "$DEST"
  echo "✅ 已移除：${DEST}"
  echo "   （手動等價指令：rm -f \"\$(git rev-parse --git-path hooks)/pre-push\"）"
  exit 0
fi
if [ $# -gt 0 ]; then
  echo "未知參數：${1}（用 --help 睇用法）" >&2
  exit 2
fi

[ -f "$SRC" ] || { echo "FAIL: 搵唔到 $SRC" >&2; exit 2; }
bash -n "$SRC" || { echo "FAIL: $SRC 語法錯（bash -n 紅）" >&2; exit 2; }
mkdir -p "$HOOK_DIR"

if [ -e "$DEST" ]; then
  if grep -qF "$MARKER" "$DEST" 2>/dev/null; then
    echo "==> 已有本 repo 嘅 hook → 直接更新"
  else
    BACKUP="${DEST}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$DEST" "$BACKUP"
    echo "==> 目標已經有 hook（唔係本 repo 嘅）→ 已備份成 ${BACKUP}"
  fi
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"
echo "✅ 已安裝：${DEST}"
echo
echo "之後 push 就會自動跑本機 CI 等價檢查：bash scripts/check-all.sh"
echo "一次性繞過：SKIP_LOCAL_CI=1 git push"
echo "移除：bash scripts/install-local-hooks.sh --uninstall"
