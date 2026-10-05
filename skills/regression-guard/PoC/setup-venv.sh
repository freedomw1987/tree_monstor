#!/usr/bin/env bash
# skills/regression-guard/PoC/setup-venv.sh
#
# 建立 Jev PoC 專用 venv（.venv/）並安裝 requirements.txt。
# 目的（TMO-029）：clean clone 後 `bats tests/` 不再 38 條全紅（venv-dependent）——一行就能把環境建起來。
#
# 用法：
#   bash skills/regression-guard/PoC/setup-venv.sh          # 建/更新 .venv
#   bash skills/regression-guard/PoC/setup-venv.sh --force  # 砍掉重建
#
# 依賴：uv（最快，若有）或 python3（-m venv）—— uv 非必要。
# 環境變數 POC_VENV_DIR 可覆寫 venv 位置（探針用），預設 PoC/.venv。
# 註：本 repo 的探針另需 python >= 3.10（取 sys.stdlib_module_names）；httpx/PyYAML 本身不挑版本。
# 退出碼：0 成功 / 1 參數或環境問題（含建不出 venv）/ 2 安裝或驗證失敗

set -euo pipefail

POC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${POC_VENV_DIR:-$POC_DIR/.venv}"
REQ="$POC_DIR/requirements.txt"
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        -h|--help)
            # 印檔頭註解區塊（不用硬編行號，表頭長度改了不會漂移）
            awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "ERROR: 未知參數 ${arg}（可用：--force / --help）" >&2
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

if [ "$FORCE" -eq 1 ] && [ -d "$VENV_DIR" ]; then
    echo "==> --force：移除既有 ${VENV_DIR}"
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
