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

@test "H1: 真 repo 的 9 個 Python heredoc 全數通過（且數量 >= 8）" {
  [ -x "$CHECK" ]
  run bash "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: "*"embedded Python heredocs syntax-checked"* ]]
  # 防空過 + 覆蓋不倒退（reviewer P2-5）：抽到的數量必須 >= 8（目前 9）。
  # 若真的重構到 heredoc 變少，請刻意下調此門檻與腳本的 MIN_HEREDOCS 預設值。
  local n
  n=$(printf '%s' "$output" | sed -n 's/^OK: \([0-9][0-9]*\) .*/\1/p')
  [ -n "$n" ]
  [ "$n" -ge 8 ]
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
@test "H6: delimiter 含 '-'（<<'PY-EOF'）也能正確抽出（reviewer P2-4）" {
  local good="$BATS_TEST_TMPDIR/hyphen-good.sh"
  cat > "$good" <<'SH'
#!/usr/bin/env bash
python3 - <<'PY-EOF'
import json
print(json.dumps({"a": 1}))
PY-EOF
SH
  run env MIN_HEREDOCS=1 bash "$CHECK" "$good"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 合法的 - delimiter heredoc 被誤判（$output）" >&2
    return 1
  }

  # 同一個 delimiter、但內容有語法錯 → 必須抓到（證明真的抽出來驗了，不是「找不到就當過」）
  local bad="$BATS_TEST_TMPDIR/hyphen-bad.sh"
  cat > "$bad" <<'SH'
#!/usr/bin/env bash
python3 - <<'PY-EOF'
this is not python(
PY-EOF
SH
  run env MIN_HEREDOCS=1 bash "$CHECK" "$bad"
  [ "$status" -ne 0 ]
  [[ "$output" == *"語法錯誤"* ]]
}

@test "H7: << 的結尾 delimiter 不可空白縮排（比 bash 寬會提早收尾而漏驗）" {
  # bash 對 `<<` 只認行首頂格的 delimiter；若掃描器把 "  PYEOF" 也當結尾，
  # 後面的壞語法就落在「被誤認為 heredoc 之外」而不會被驗到 → 假綠。
  local tmp="$BATS_TEST_TMPDIR/space-indent.sh"
  printf '#!/usr/bin/env bash\npython3 - <<%s\n' "'PYEOF'" > "$tmp"
  printf 'import json\n' >> "$tmp"
  printf '  PYEOF\n' >> "$tmp"      # 空白縮排：bash 語意上「不是」結尾
  printf 'this is not python(\n' >> "$tmp"
  printf 'PYEOF\n' >> "$tmp"        # 真正結尾（頂格）
  run env MIN_HEREDOCS=1 bash "$CHECK" "$tmp"
  [ "$status" -ne 0 ] || {
    echo "FAIL: 縮排 delimiter 被提早當成結尾 → 後面的壞語法漏驗（假綠）" >&2
    return 1
  }
  [[ "$output" == *"語法錯誤"* ]]
}

@test "H8: <<- 允許 tab 縮排結尾（不誤報未結束）" {
  local tmp="$BATS_TEST_TMPDIR/tab-indent.sh"
  printf '#!/usr/bin/env bash\npython3 - <<-%s\n' "'PYEOF'" > "$tmp"
  printf 'import json\n' >> "$tmp"
  printf '\tPYEOF\n' >> "$tmp"
  run env MIN_HEREDOCS=1 bash "$CHECK" "$tmp"
  [ "$status" -eq 0 ] || {
    echo "FAIL: <<- 的 tab 縮排結尾未被接受（$output）" >&2
    return 1
  }
}

@test "H9: 覆蓋下限鎖（MIN_HEREDOCS 預設 8）與 ci.yml 不得放寬它" {
  # 只有 1 個 heredoc 的檔案 → 必須因「低於下限」失敗（防空過鎖有效）
  local tmp="$BATS_TEST_TMPDIR/one-only.sh"
  cat > "$tmp" <<'SH'
#!/usr/bin/env bash
python3 - <<'PYEOF'
import json
PYEOF
SH
  run bash "$CHECK" "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"只抽到 1 個"* ]]

  # 真 repo 掃描時，預設下限就是 8（不得被環境變數悄悄放寬）
  run bash -c 'cd "$0" && env -u MIN_HEREDOCS bash scripts/ci/check-python-heredocs.sh' "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 預設下限下真 repo 掃描失敗（$output）" >&2
    return 1
  }

  # ci.yml 不得把下限放寬（例如 MIN_HEREDOCS=0 / =1）
  if grep -qE 'MIN_HEREDOCS=(0|1)\b' "$CI_YML"; then
    echo "FAIL: ci.yml 把 MIN_HEREDOCS 放寬到下界以下" >&2
    return 1
  fi
}
