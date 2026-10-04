#!/usr/bin/env bats
#
# tests/ci-heredoc-check.bats
#
# TMO-044：`ci.yml` 的 "Verify Python heredoc syntax" 原本是恆綠假檢查
#   （開不存在的 wiki-cleanup.yaml + `2>/dev/null || true`；PYEOF 計數式對正常值發假警告）
#   → 換成 scripts/ci/check-python-heredocs.sh（真的抽 heredoc + ast.parse + 會失敗）。
#
# 本檔不只看字串：H2/H3/H4 會真的種錯誤進臨時複本，證明這條檢查咬得住（不是空過）。
#
# Usage:
#   bats tests/ci-heredoc-check.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CHECK="$REPO_ROOT/scripts/ci/check-python-heredocs.sh"
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
  export REPO_ROOT CHECK CI_YML
}

@test "H1: 真 repo 的 9 個 Python heredoc 全數通過（且數量 >= 5）" {
  [ -x "$CHECK" ]
  run bash "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: "*"embedded Python heredocs syntax-checked"* ]]
  # 防空過：抽到的數量必須 >= 5（目前 9，掃描邏輯失效時不得安靜變綠）
  local n
  n=$(printf '%s' "$output" | sed -n 's/^OK: \([0-9][0-9]*\) .*/\1/p')
  [ -n "$n" ]
  [ "$n" -ge 5 ]
}

@test "H2: heredoc 內種一個語法錯誤 → 必須失敗（證明檢查有效）" {
  local tmp="$BATS_TEST_TMPDIR/syntax-broken.sh"
  cp "$REPO_ROOT/skills/dav-wiki/scripts/wiki-index.sh" "$tmp"
  # 在 heredoc 內插入不合法的 Python
  python3 - "$tmp" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
assert "import json" in s
p.write_text(s.replace("import json", "import json\nthis is not python(", 1))
PY
  run bash "$CHECK" "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"語法錯誤"* ]]
}

@test "H3: heredoc 沒結束（缺結尾 delimiter）→ 必須失敗" {
  local tmp="$BATS_TEST_TMPDIR/unterminated.sh"
  python3 - "$REPO_ROOT/skills/dav-wiki/scripts/wiki-merge-media.sh" "$tmp" <<'PY'
import sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text().split("\n")
kept = [l for l in src if l.strip() != "PYEOF"]
pathlib.Path(sys.argv[2]).write_text("\n".join(kept))
PY
  run bash "$CHECK" "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"未結束"* ]]
}

@test "H4: 只有註解裡的假 heredoc → 防空過必須失敗（不可安靜變綠）" {
  local tmp="$BATS_TEST_TMPDIR/comment-only.sh"
  cat > "$tmp" <<'SH'
#!/usr/bin/env bash
# python3 - <<'PYEOF'
# print("hi")
# PYEOF
echo real
SH
  run bash "$CHECK" "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"只抽到 0 個"* ]]
}

@test "H5: ci.yml 的該步驟真的呼叫檢查腳本，且不再有 || true 假綠構造" {
  # 取出該 step 的 run: 區塊（到本 step 結束為止）
  local block
  block=$(awk '/Verify Python heredoc syntax/{flag=1} flag{print} /^      - name:/&&flag&&!/Verify Python/{exit}' "$CI_YML")
  # 防空過：block 必須真的抓到（含 step 名）
  [[ -n "$block" ]]
  [[ "$block" == *"Verify Python heredoc syntax"* ]]

  [[ "$block" == *"check-python-heredocs.sh"* ]] || {
    echo "FAIL: ci.yml 該 step 未呼叫 scripts/ci/check-python-heredocs.sh" >&2
    return 1
  }
  if printf '%s' "$block" | grep -q '|| true'; then
    echo "FAIL: ci.yml 該 step 仍有 '|| true' 假綠構造" >&2
    return 1
  fi
  if printf '%s' "$block" | grep -q 'wiki-cleanup\.yaml'; then
    echo "FAIL: ci.yml 該 step 仍在開不存在的 wiki-cleanup.yaml" >&2
    return 1
  fi
}