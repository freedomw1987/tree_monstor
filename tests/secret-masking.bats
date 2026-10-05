#!/usr/bin/env bats
# TMO-053（NYH-2）：探針 FAIL 訊息不得外洩密鑰。
#
# 背景：2026-10-05 做 TMO-045 反向驗證時，探針的 FAIL 訊息把本機**真實**
# `OPENROUTER_API_KEY` 印進了 session log（NYH-1）。當時的遮罩函式
# `mask_secrets()` 只定義在單一探針檔（`tests/poc-clean-clone.bats`）內，
# 其他探針沒有任何防線，也沒有任何靜態鎖擋得住「下次忘記遮罩」。
#
# 本檔四層：
#   SM-1 單一真相：遮罩函式只准定義在共用 helper，`.bats` 不得自己再定義
#   SM-2 靜態鎖：實跑 scripts/ci/lint-probe-secrets.py（0 violation）
#   SM-3 單元：遮罩真的會遮（sk- 前綴／KEY= 指派），乾淨文字不動
#   SM-4 反向實測：**真的讓 CLEAN-POC-i 失敗**，bats 輸出不得含密鑰（且遮罩真的作用）
#   SM-5 掃描器會咬：合成違規（漏遮罩的 FAIL 訊息）必須被擋
load 'helpers/test-env'

HELPER="$REPO_ROOT/tests/helpers/test-env.bash"
SCANNER="$REPO_ROOT/scripts/ci/lint-probe-secrets.py"

@test "SM-1: mask_secrets 只有一份定義（共用 helper），其他檔不得自己再定義" {
  assert_file_contains "$HELPER" "mask_secrets()"
  local f n=0
  # 用檔案系統列舉（不用 git ls-files）：新寫、還沒 commit 的探針檔也要被掃到，
  # 否則「本機剛寫完的檔自己重定義一份」這個真實情境掃不到（與掃描器 R4 同目標集）。
  # 註：只掃深度 1（與掃描器一致）；未來新增 tests/unit/*.bats 時兩處都要同步。
  # 註：**不**排除 .gitignore 的檔（刻意與 ENV-EQ-12 的 git check-ignore 慣例不同）：
  # 「還沒 add 的新檔自己又定義一份」正是要擋的情境。
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$f" = "$HELPER" ]; then continue; fi   # 唯一允許的定義位置
    if grep -qE '^[[:space:]]*(function[[:space:]]+)?mask_secrets[[:space:]]*\([[:space:]]*\)' "$f"; then
      echo "FAIL: $f 重新定義 mask_secrets（應改用 tests/helpers/test-env.bash 的共用版，免得只遮一半）" >&2
      return 1
    fi
    n=$((n + 1))
  done < <(find "$REPO_ROOT/tests" -maxdepth 1 -name '*.bats'; \
           find "$REPO_ROOT/tests/helpers" -maxdepth 1 -name '*.bash'; \
           find "$REPO_ROOT"/skills/*/tests -maxdepth 1 -name '*.bats' 2>/dev/null)
  # 防空過：抽取器若壞掉，上面的迴圈會 0 圈全綠
  [ "$n" -ge 40 ] || {
    echo "FAIL: 只掃到 $n 個探針檔（<40）→ 抽取器可能壞了" >&2
    return 1
  }
}

@test "SM-2: 靜態鎖 lint-probe-secrets.py 全綠（含防空過）" {
  run python3 "$SCANNER" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
  [[ "$output" == *"0 violation"* ]]
  # 標記數是人工複核錙點（標記的真實語意見掃描器 docstring：它只能擋「標在無關行」）
  # 註：斷言字串刻意拆開（"SECRET-"*"OK 標記"）——否則本行自己就含標記字面，會被鎖 4 咬。
  [[ "$output" == *"SECRET-"*"OK 標記"* ]]
}

@test "SM-3: mask_secrets 真的會遮（sk- 前綴 / KEY= 指派），乾淨文字不動" {
  run bash -c 'source "$1"; mask_secrets <<< "OPENROUTER_API_KEY=sk-or-v1-abc123def456 x=y"' _ "$HELPER"  # SECRET-OK: 假值
  [ "$status" -eq 0 ]
  [[ "$output" != *"abc123def456"* ]]
  [[ "$output" != *"sk-or-v1-"* ]]  # SECRET-OK: 斷言的**樣式**（字面掃描用），非真 key
  [[ "$output" == *"MASKED"* ]]
  [[ "$output" == *"x=y"* ]]
}

@test "SM-4: 反向實測——讓 CLEAN-POC-i 真的失敗，bats 輸出不得含密鑰" {
  # 造一棵假 tree：**真探針檔** + 共用 helper + 假 .venv python shim。
  # shim 模擬 `_load_api_key()` 的來源順序（JEV_ENV_FILE 覆寫整份清單；
  # 否則讀 $HOME/.claude/... 的 .env）——這樣就 venv-free 也能跑到真 FAIL 訊息。
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/tests/helpers" "$tree/skills/regression-guard/PoC/.venv/bin"
  cp "$REPO_ROOT/tests/poc-clean-clone.bats" "$tree/tests/"
  cp "$HELPER" "$tree/tests/helpers/"

  local key="sk-or-v1-DEADBEEF0123456789ABCDEF"  # SECRET-OK: 假值，本地合成，非真 key
  local fake_home="$tree/home"
  mkdir -p "$fake_home/.claude/skills/regression-guard/PoC"
  printf 'OPENROUTER_API_KEY=%s\n' "$key" \
    > "$fake_home/.claude/skills/regression-guard/PoC/.env"

  cat > "$tree/skills/regression-guard/PoC/.venv/bin/python" <<'SHIM'
#!/usr/bin/env bash
# 假 python：只支援探針用到的那一種呼叫（print / print(repr(_load_api_key()))）
env_file="${JEV_ENV_FILE:-$HOME/.claude/skills/regression-guard/PoC/.env}"
# 模擬「seam 沒生效」：/dev/null 之後仍 fallback 到 $HOME 的 .env
[ "$env_file" = "/dev/null" ] && env_file="$HOME/.claude/skills/regression-guard/PoC/.env"
val=""
[ -f "$env_file" ] && val="$(sed -n 's/^OPENROUTER_API_KEY=//p' "$env_file" | head -1)"
case "${2:-}" in
  *repr*) printf "'%s'\n" "$val" ;;
  *) printf '%s\n' "$val" ;;
esac
SHIM
  chmod +x "$tree/skills/regression-guard/PoC/.venv/bin/python"

  run env -u OPENROUTER_API_KEY HOME="$fake_home" \
      bats "$tree/tests/poc-clean-clone.bats" --filter "CLEAN-POC-i"
  # ① 失敗路徑真的走到（否則這條探針在測空氣）
  [ "$status" -ne 0 ]
  # ② FAIL 訊息真的有把被測輸出印出來（證明下面那條「不含密鑰」不是真空通過）
  [[ "$output" == *"值已遮罩"* ]]
  [[ "$output" == *"MASKED"* ]]
  # ③ 密鑰不得外洩
  [[ "$output" != *"DEADBEEF"* ]]
  [[ "$output" != *"sk-or-v1-"* ]]  # SECRET-OK: 斷言的樣式字面，非真 key
}

@test "SM-5: 掃描器真的會咬（合成違規）+ 空樹防空過" {
  local tree="$BATS_TEST_TMPDIR/synth"
  mkdir -p "$tree/tests/helpers"
  cat > "$tree/tests/leaky.bats" <<'EOF'
@test "leaky" {
  run python3 -c "import jev_oracle; print(jev_oracle._load_api_key())"
  echo "FAIL: got $output" >&2  # SECRET-OK: 合成洩漏樣本（就是要讓掃描器咬）
}
EOF
  run python3 "$SCANNER" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"leaky.bats"* ]]
  [[ "$output" == *"mask_secrets"* ]]
  [[ "$output" == *"_load_api_key"* ]]

  # 防空過：抽取器什麼都沒掃到時必須紅（不得靜默全綠）
  local empty="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$empty"
  run python3 "$SCANNER" "$empty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"防空過"* ]]
}
