#!/usr/bin/env bats
#
# tests/wiki-dead-code.bats
#
# TMO-043：dav-wiki 腳本死碼靜態鎖。
# 起因：`wiki-extract-video.sh` 的 `probe_metadata()` 定義後從未被呼叫（shellcheck SC2329 info），
#       同批掃描另發現 `wiki-media-describe.sh` 的 `ext_pattern` 算完未用（真 bug：批次不吃 mode 過濾）。
#
# 本檔不做「字串存在性」檢查，而是實際解析每個 .sh 的函式定義，逐檔驗證
# 「每個被定義的函式在該檔內至少被引用一次」——這樣任何新增的死函式都會被咬住。
#
# Usage:
#   bats tests/wiki-dead-code.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  SCRIPTS_DIR="$REPO_ROOT/skills/dav-wiki/scripts"
  export REPO_ROOT SCRIPTS_DIR
}

# 列出某檔內「定義了但整檔只出現一次」的函式名
find_dead_functions() {
  local file="$1"
  local fn count
  grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$file" 2>/dev/null | sed 's/()$//' | sort -u |
    while IFS= read -r fn; do
      [[ -n "$fn" ]] || continue
      count=$(grep -cE "(^|[^A-Za-z0-9_])${fn}([^A-Za-z0-9_]|$)" "$file" 2>/dev/null || true)
      if [[ "${count:-0}" -le 1 ]]; then
        printf '%s\n' "$fn"
      fi
    done
}

@test "WDC-1: dav-wiki 腳本無「定義但從未引用」的死函式" {
  # 防空過：先確認真的掃到足夠的函式（掃描邏輯失效時不得安靜變綠）
  local total=0
  local f
  for f in "$SCRIPTS_DIR"/*.sh; do
    local n
    n=$(grep -cE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$f" 2>/dev/null || true)
    total=$((total + n))
  done
  [ "$total" -ge 20 ] || {
    echo "FAIL: 只掃到 $total 個函式定義（預期 >= 20），掃描邏輯可能失效" >&2
    return 1
  }

  local dead=""
  for f in "$SCRIPTS_DIR"/*.sh; do
    local d
    d=$(find_dead_functions "$f")
    if [[ -n "$d" ]]; then
      dead="${dead}${f##*/}: $(printf '%s' "$d" | tr '\n' ' ')
"
    fi
  done

  if [[ -n "$dead" ]]; then
    echo "FAIL: 發現死函式（定義後從未被引用）：" >&2
    printf '%s' "$dead" >&2
    return 1
  fi
}

@test "WDC-2: 掃描器本身咬得住死函式（種一個假死函式必須變紅）" {
  # 反向驗證：在臨時複本種一個從未被呼叫的函式，find_dead_functions 必須回報它
  local tmp="$BATS_TEST_TMPDIR/dead-fn-sample.sh"
  printf '#!/usr/bin/env bash\nnever_called_fn() {\n  echo hi\n}\nused_fn() {\n  echo ok\n}\nused_fn\n' > "$tmp"
  local out
  out=$(find_dead_functions "$tmp")
  [[ "$out" == "never_called_fn" ]] || {
    echo "FAIL: 掃描器未回報 never_called_fn，實際輸出='$out'" >&2
    return 1
  }
  ! printf '%s' "$out" | grep -q "^used_fn$" || {
    echo "FAIL: 掃描器誤報 used_fn（有被呼叫）" >&2
    return 1
  }
}