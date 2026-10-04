#!/usr/bin/env bash
# scripts/ci/check-python-heredocs.sh
#
# 用途：抽出 bash 腳本內嵌的 Python heredoc，用 `ast.parse` 驗「語法」（不執行）。
#
# 背景（TMO-044）：`ci.yml` 原本這一步做兩件不會失敗的事——
#   ① `python3 -c "...open('.../wiki-cleanup.yaml')" 2>/dev/null || true`：開的是**不存在**的檔案 + `|| true`
#   ② `grep -c "^PYEOF$" ... | grep -v ":0$" | ...`：對正常值（3 個 PYEOF）發 `::warning::`，但 step 仍 success
#   → 恆綠的假檢查（假紅也沒咬住任何東西）；且只涵蓋 wiki-cleanup.sh / wiki-cross-ref.sh 的 5 個 heredoc，
#     另外 4 個（wiki-extract-media.sh ×2 / wiki-merge-media.sh / wiki-index.sh）從來沒被驗過。
#   本腳本改成真檢查：抽出來 → `ast.parse` → 有錯 rc=1。
#
# 用法：scripts/ci/check-python-heredocs.sh [file ...]
#       未給檔案時，預設掃 `skills/dav-wiki/scripts/*.sh`（相對 repo root）。
# 環境變數：MIN_HEREDOCS（預設 1）— 抽到的 heredoc 少於此數視為「掃描邏輯失效」而失敗（防空過）。
set -uo pipefail

MIN_HEREDOCS="${MIN_HEREDOCS:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

files=()
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do files+=("$arg"); done
else
    for f in "$REPO_ROOT"/skills/dav-wiki/scripts/*.sh; do
        [[ -f "$f" ]] && files+=("$f")
    done
fi

if [[ ${#files[@]} -eq 0 ]]; then
    echo "::error::沒有可掃描的檔案（掃描邏輯失效）"
    exit 1
fi

tmpdir="$(mktemp -d -t heredoc-check-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

total=0
fail=0
missing=0

for f in ${files[@]+"${files[@]}"}; do
    if [[ ! -f "$f" ]]; then
        echo "::error::找不到檔案 $f"
        missing=$((missing + 1))
        continue
    fi

    lineno=0
    idx=0
    delim=""
    start_line=0
    out=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))

        if [[ -z "$delim" ]]; then
            # 只看「真的 python3 heredoc」：
            #   ① 略過註解行（否則說明文字裡的 `python3` + `<<EOF` 會被誤判）
            #   ② 要求 `<<` 前是空白（真正的重導向），避免字串／比較運算中的 `<<` 誤中
            head="${line#"${line%%[![:space:]]*}"}"
            if [[ "$head" != '#'* && "$line" == *python3* && "$line" == *" <<"* ]]; then
                delim=$(printf '%s\n' "$line" |
                        sed -n "s/.*[[:space:]]<<[-]\{0,1\}['\"]\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)['\"]\{0,1\}.*/\1/p")
            fi
            if [[ -n "$delim" ]]; then
                start_line=$lineno
                idx=$((idx + 1))
                out="$tmpdir/$(basename "$f").$idx.py"
                : > "$out"
            fi
            continue
        fi

        # 結尾：整行去掉前導空白後等於 delimiter（支援 <<- 的 tab 縮排）
        trimmed="${line#"${line%%[![:space:]]*}"}"
        if [[ "$trimmed" == "$delim" ]]; then
            closed="$delim"
            delim=""
            total=$((total + 1))
            if ! python3 -c 'import ast,sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$out"; then
                echo "::error file=$f,line=$start_line::Python heredoc 語法錯誤（delimiter=$closed）"
                fail=$((fail + 1))
            fi
            continue
        fi

        printf '%s\n' "$line" >> "$out"
    done < "$f"

    if [[ -n "$delim" ]]; then
        echo "::error file=$f,line=$start_line::heredoc 未結束（delimiter=$delim 找不到結尾行）"
        fail=$((fail + 1))
    fi
done

if [[ $total -lt $MIN_HEREDOCS ]]; then
    echo "::error::只抽到 $total 個 Python heredoc（預期 >= $MIN_HEREDOCS）→ 掃描邏輯可能失效"
    exit 1
fi

if [[ $missing -gt 0 || $fail -gt 0 ]]; then
    echo "FAIL: $fail 個 heredoc 語法錯誤、$missing 個檔案不存在（共掃到 $total 個 heredoc）"
    exit 1
fi

echo "OK: $total embedded Python heredocs syntax-checked (${#files[@]} files)"