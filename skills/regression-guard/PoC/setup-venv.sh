#!/usr/bin/env bash
# skills/regression-guard/PoC/setup-venv.sh
#
# 建立 Jev PoC 專用 venv（.venv/）並安裝 requirements.txt。
# 目的（TMO-029）：clean clone 後 `bats tests/` 不再 38 條全紅（venv-dependent）——一行就能把環境建起來。
#
# 用法：
#   bash skills/regression-guard/PoC/setup-venv.sh               # 建/更新 .venv
#   bash skills/regression-guard/PoC/setup-venv.sh --force       # 砍掉重建（預設路徑免確認）
#   bash skills/regression-guard/PoC/setup-venv.sh --force --yes # 自訂 POC_VENV_DIR 時的非互動豁免
#
# 依賴：uv（最快，若有）或 python3（-m venv）—— uv 非必要。
# 環境變數 POC_VENV_DIR 可覆寫 venv 位置（探針用），預設 PoC/.venv。
# ⚠️ 破壞性護欄（TMO-040 / NYH-5 方案 A）：--force 會 `rm -rf "$VENV_DIR"`，因此
#   ①危險清單（`$HOME` 本體、`/private/tmp`、`/usr`、`/etc` 等）即使 --force 也拒；
#   ②自訂 POC_VENV_DIR 且目錄已存在時，--force 需輸入目錄名二次確認（--yes 豁免）。
#   守門探針：tests/poc-venv-guard.bats
# 註：本 repo 的探針另需 python >= 3.10（取 sys.stdlib_module_names）；httpx/PyYAML 本身不挑版本。
# 退出碼：0 成功 / 1 參數或環境問題（含建不出 venv）/ 2 安裝或驗證失敗

set -euo pipefail

POC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${POC_VENV_DIR:-$POC_DIR/.venv}"
REQ="$POC_DIR/requirements.txt"
FORCE=0
YES=0

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        # 非互動豁免：只對「自訂 POC_VENV_DIR 的 --force 二次確認」生效，
        # 不能繞過危險清單（見下方 _is_dangerous_venv_dir）。
        --yes|-y) YES=1 ;;
        -h|--help)
            # 印檔頭註解區塊（不用硬編行號，表頭長度改了不會漂移）
            awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "ERROR: 未知參數 ${arg}（可用：--force / --yes / --help）" >&2
            exit 1
            ;;
    esac
done

[ -f "$REQ" ] || {
    echo "ERROR: 缺 ${REQ}" >&2
    exit 1
}

# 護欄（reviewer Round-2 P2 / Round-3 P1）：POC_VENV_DIR 由外部指定，而 --force 會 `rm -rf "$VENV_DIR"`。
# 需要：非空、絕對、至少兩層、且不含結尾斜線或 `.` / `..` 段
# （`/tmp/` 與 `/tmp` 同義、`//` 與 `/` 同義、`/tmp/..` 就是 `/`）。
_reject_venv_dir() {
    echo "ERROR: 可疑的 VENV_DIR=${1}（POC_VENV_DIR 護欄：需為非空、絕對、至少兩層、且無結尾斜線或 . / .. 段）" >&2
    exit 1
}
case "$VENV_DIR" in
    ""|/*/*) : ;;
    *) _reject_venv_dir "$VENV_DIR" ;;
esac
case "$VENV_DIR" in
    */|*/./*|*/../*|*/..|*/.|*//*) _reject_venv_dir "$VENV_DIR" ;;
esac

# 危險清單護欄（TMO-040 / NYH-5 方案 A）：結構合法的路徑仍可能「合法但危險」——
# `POC_VENV_DIR=$HOME --force` 會把家目錄整個 rm -rf；`/private/tmp`、`/usr`、`/etc` 同理。
# 只做「整條路徑完全相等」比對：子路徑（例：`$HOME/projects/x`、`/opt/venvs/x`）仍允許——
# 那通常是使用者明示的自訂位置，且 --force 另有目錄名二次確認把關。
# `--force` / `--yes` 都**不能**繞過這一關。
# 三個字面比對的繞道已堵（各有反向探針）：
#   ①`HOME` 結尾斜線：`HOME=/Users/x/` 會讓 `/Users/x` 字面不相等 → `_home_norm` 去尾斜線。
#   ②symlink 祖先：`ln -s "$HOME" /tmp/e` 後 `/tmp/e/Documents` 字面看不到家目錄，`rm -rf` 卻會
#     沿著連結刪到真目錄 → 存在的目錄再用 `pwd -P` 取物理路徑比對一次（兩邊都正規化）。
#   ③大小寫：macOS 預設 case-insensitive，`/private/TMP` 與 `/private/tmp` 是同一個目錄，
#     但字面不相等；`pwd -P` 也保留使用者輸入的大小寫（實測：`cd /private/TMP && pwd -P`
#     → `/private/TMP`）→ 兩邊都 `_lower` 後再比。
_reject_dangerous_venv_dir() {
    echo "ERROR: VENV_DIR=${1} 命中危險清單（POC_VENV_DIR 護欄：$HOME 本體、/private/tmp、/usr、/etc 等系統或使用者資料目錄）→ 即使 --force 也拒絕" >&2
    exit 1
}
_resolve_dir() {
    (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"
}
_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}
_home_norm="${HOME%/}"
_home_resolved="$(_resolve_dir "$_home_norm")"
_is_dangerous_venv_dir() {
    local _d _h
    _d="$(_lower "$1")"
    case "$_d" in
        /|/bin|/sbin|/usr|/etc|/var|/tmp|/opt|/private|/private/etc|/private/tmp|/private/var|/dev|/cores|/network|/library|/system|/applications|/users|/volumes|/home|/root)
            return 0 ;;
    esac
    for _h in "$_home_norm" "$_home_resolved"; do
        [ -n "$_h" ] || continue
        _h="$(_lower "$_h")"
        case "$_d" in
            "$_h"|"$_h/library"|"$_h/.ssh"|"$_h/desktop"|"$_h/documents"|"$_h/downloads"|"$_h/movies"|"$_h/music"|"$_h/pictures"|"$_h/public")
                return 0 ;;
        esac
    done
    return 1
}
# 兩次呼叫：①在二次確認之前（早拒，不浪費使用者輸入）②`rm -rf` 正前方（
# 縮小 TOCTOU 窗——確認的 `read` 可能無限期阻塞，期間中間層目錄可被換成 symlink）。
_assert_safe_venv_dir() {
    if _is_dangerous_venv_dir "$VENV_DIR"; then
        _reject_dangerous_venv_dir "$VENV_DIR"
    fi
    if [ -d "$VENV_DIR" ]; then
        _venv_resolved="$(_resolve_dir "$VENV_DIR")"
        if [ "$_venv_resolved" != "$VENV_DIR" ] && _is_dangerous_venv_dir "$_venv_resolved"; then
            _reject_dangerous_venv_dir "$_venv_resolved"
        fi
    fi
}
_assert_safe_venv_dir

if [ "$FORCE" -eq 1 ] && [ -d "$VENV_DIR" ]; then
    # 二次確認（TMO-040）：--force 是破壞性的，而 POC_VENV_DIR 由外部指定。
    # 只在「使用者自訂 POC_VENV_DIR」時要求——預設的 PoC/.venv 是腳本自己算出來的，沒有外部輸入。
    # --yes 供 CI／非互動腳本豁免；讀不到輸入一律 fail-closed（不刪就退出）。
    if [ -n "${POC_VENV_DIR:-}" ] && [ "$YES" -eq 0 ]; then
        _base="$(basename "$VENV_DIR")"
        printf '將移除既有目錄：%s\n請輸入目錄名 [%s] 以確認（非互動請改用 --yes）：' "$VENV_DIR" "$_base" >&2
        if ! IFS= read -r _answer; then
            printf '\n' >&2
            echo "ERROR: 讀不到確認輸入（非互動環境請加 --yes）" >&2
            exit 1
        fi
        if [ "$_answer" != "$_base" ]; then
            echo "ERROR: 確認失敗（輸入 '${_answer}' != 目錄名 '${_base}'）→ 未刪除任何東西" >&2
            exit 1
        fi
    fi
    echo "==> --force：移除既有 ${VENV_DIR}"
    # TOCTOU：確認的 read 可能等很久，刪前再驗一次
    _assert_safe_venv_dir
    rm -rf "$VENV_DIR"
fi

if [ -x "$VENV_DIR/bin/python" ]; then
    echo "==> 既有 venv：${VENV_DIR}（更新依賴）"
else
    if command -v uv >/dev/null 2>&1; then
        echo "==> 用 uv 建立 venv"
        uv venv "$VENV_DIR"
    elif command -v python3 >/dev/null 2>&1; then
        echo "==> 用 python3 -m venv 建立 venv"
        python3 -m venv "$VENV_DIR"
    else
        echo "ERROR: 既無 uv 也無 python3，無法建立 venv（請先安裝其一）" >&2
        exit 1
    fi
fi

PY="$VENV_DIR/bin/python"
[ -x "$PY" ] || {
    echo "ERROR: 建完仍找不到 ${PY}" >&2
    exit 2
}

echo "==> 安裝依賴（${REQ}）"
if command -v uv >/dev/null 2>&1; then
    # uv pip 需要目標 venv；--python 指到剛建好的直譯器
    uv pip install --python "$PY" -r "$REQ" || {
        echo "ERROR: uv pip install 失敗" >&2
        exit 2
    }
else
    # python3 -m venv 附帶 pip；若因系統限制缺 pip 則用 ensurepip 補
    if ! "$PY" -m pip --version >/dev/null 2>&1; then
        "$PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi
    "$PY" -m pip install -r "$REQ" || {
        echo "ERROR: pip install 失敗" >&2
        exit 2
    }
fi

echo "==> 驗證"
"$PY" -c "import httpx, yaml; print('  httpx', httpx.__version__, '/ PyYAML', yaml.__version__)" || {
    echo "ERROR: 依賴驗證失敗" >&2
    exit 2
}

echo
echo "完成。接著可跑："
echo "  bats tests/                                    # 全套"
echo "  bats tests/v2.1-jev-poc.bats                   # 只跑 PoC 探針"
