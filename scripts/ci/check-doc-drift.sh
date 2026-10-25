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

# 嚴格模式：檢查**本 repo 自己**時（未指定 --root），要求 docs/deliverable/ 至少有一支
# 落在 from-date 窗內的交付摘要 —— 否則 D4/D8 的檢查件數為 0，「未對上不得宣告 ✅ 完成」
# 那條硬門檻會靜默失效（假綠）。對外（--root <別的專案>）維持可攜語意，只印警告。
# 判定要涵蓋 `--root <p>` 與 `--root=<p>` 兩種寫法，漏了等號形會誤把外部專案擋掉。
# 逐個引數比對（不用 `"$*"` 子字串）：否則 `--whitelist /tmp/--root=x.txt` 這類
# 「值裡剛好含 --root」的引數會誤命中，反而把 fail-closed 靜默關掉。
want_root=0
for _a in "$@"; do
  case "$_a" in
    --root|--root=*) want_root=1 ;;
  esac
done
if [ "$want_root" -eq 0 ]; then
  set -- --require-window-checks "$@"
fi

exec python3 "$IMPL" "$@"
