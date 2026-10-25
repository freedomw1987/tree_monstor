#!/usr/bin/env bash
# check-doc-drift.sh — 文件漂移檢查 wrapper（framework repo 用）
#
# 實作檔在 skill 內（skills/dav-reconciler/scripts/check-doc-drift.py），
# 這樣安裝 tree_monstor 的專案會隨 skill 一起拿到這個工具（單一來源，不兩份）。
#
# 用法：
#   scripts/ci/check-doc-drift.sh [--root <專案根>] [--whitelist <白名單檔>] [--from-date YYYY-MM-DD]
#
# rc：0 = 無違規｜1 = 有違規｜2 = 用法 / 環境錯誤

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMPL="$REPO_ROOT/skills/dav-reconciler/scripts/check-doc-drift.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "用法錯誤：需要 python3 才能執行文件漂移檢查" >&2
  exit 2
fi

if [[ ! -f "$IMPL" ]]; then
  echo "用法錯誤：找不到實作檔 $IMPL" >&2
  exit 2
fi

exec python3 "$IMPL" "$@"
