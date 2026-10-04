#!/usr/bin/env bats
# tests/markdownlint-guard.bats
#
# TMO-037 鎖：markdownlint 這條線必須「真會擋」，而且政策不可被靜默放寬。
#
# 背景：TMO-029 為了不讓既有 270 個 markdownlint 債卡住 CI，把 `Markdown lint`
# job 設成 `continue-on-error: true`（假綠）。TMO-037 把債清成 0 之後，本檔負責
# 防止兩種回歸：
#   ① 有人再把 lint 改成不擋（continue-on-error / `|| true` / 縮小 glob）
#   ② 有人用「放寬規則」取代「修文件」（例如把 MD013 上限從 120 調大）
#
# MLG-7 需要本機有 markdownlint-cli2；缺席時明確 skip（不是空過），因為實際
# 阻擋者是 CI 的 `Markdown lint` job（MLG-1/MLG-2 已靜態釘住它必須存在且會擋）。
load 'helpers/test-env'

setup() {
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
  MDLINT_CFG="$REPO_ROOT/.markdownlint.json"
  MDLINT_CLI2="$REPO_ROOT/.markdownlint-cli2.jsonc"
  CONTRIB="$REPO_ROOT/CONTRIBUTING.md"
  LINT_GLOBS=('skills/**/*.md' 'docs/**/*.md' 'tests/**/*.md' '*.md')
}

@test "MLG-1: ci.yml 有 Markdown lint job，且真的執行 markdownlint-cli2" {
  [ -f "$CI_YML" ] || { echo "FAIL: 找不到 $CI_YML" >&2; return 1; }
  grep -q '^    name: Markdown lint' "$CI_YML" || {
    echo "FAIL: ci.yml 沒有名為 'Markdown lint' 的 job" >&2; return 1; }
  grep -q 'markdownlint-cli2' "$CI_YML" || {
    echo "FAIL: ci.yml 的 lint job 沒跑 markdownlint-cli2" >&2; return 1; }
}

@test "MLG-2: lint job 不得是假綠（無 continue-on-error、無 || true）" {
  # 只看真 YAML 內容：剝掉註解行，否則「說明用的註解」會自我命中（探針自我匹配）
  local code
  code=$(grep -vE '^[[:space:]]*#' "$CI_YML")
  [[ -n "$code" ]] || { echo "FAIL: 剝註解後 ci.yml 變空，抽取邏輯壞了" >&2; return 1; }
  if printf '%s\n' "$code" | grep -q 'continue-on-error'; then
    echo "FAIL: ci.yml 仍有 continue-on-error 這個 YAML 鍵（lint 不會擋）:" >&2
    printf '%s\n' "$code" | grep -n 'continue-on-error' >&2
    return 1
  fi
  # 抽 lint job 區塊：以 job key `lint-only` 為錨，到下一個頂層 job 鍵為止
  # （reviewer round B P2-3 + 本輪突變 M4b 修正：原版從 `name:` 起算，插在 name 之前
  #  的 `if:` 會落在區塊外 → 盲點；原版又印到 EOF，後面新增 job 會被誤判）
  local block
  block=$(printf '%s\n' "$code" | awk '/^  lint-only:$/{flag=1; print; next} flag && /^  [A-Za-z0-9_-]+:$/{exit} flag{print}')
  [[ -n "$block" ]] || { echo "FAIL: 抽不到 lint job 區塊" >&2; return 1; }
  # 比對前去掉所有空白：`||true`（無空白）同樣是假綠
  if printf '%s' "$block" | tr -d '[:space:]' | grep -q '||true'; then
    echo "FAIL: lint step 有 '|| true'（假綠）" >&2; return 1
  fi
}

@test "MLG-3: lint step 的 glob 覆蓋 skills / docs / tests(含 fixture) / 根目錄" {
  local runline
  runline=$(grep -F 'markdownlint-cli2 "skills/**/*.md"' "$CI_YML")
  [[ -n "$runline" ]] || { echo "FAIL: 找不到 lint step 的執行行" >&2; return 1; }
  local g
  for g in "${LINT_GLOBS[@]}"; do
    case "$runline" in
      *"\"$g\""*) ;;
      *) echo "FAIL: lint glob 少了 \"$g\"（縮小範圍＝放寬）" >&2; return 1 ;;
    esac
  done
  # tests/**/*.md 必須真的涵蓋 fixture：fixture 內有 .md 才算有效鎖
  [ -n "$(find "$REPO_ROOT/tests/fixtures" -name '*.md' -print -quit)" ] || {
    echo "FAIL: tests/fixtures 內沒有 .md，glob 覆蓋宣稱無法驗證" >&2; return 1; }
}

@test "MLG-4: .markdownlint-cli2.jsonc 排除 .venv 與 node_modules" {
  [ -f "$MDLINT_CLI2" ] || { echo "FAIL: 找不到 $MDLINT_CLI2" >&2; return 1; }
  grep -q '\.venv' "$MDLINT_CLI2" || {
    echo "FAIL: 未排除 .venv（PoC venv 會灌入假錯誤）" >&2; return 1; }
  grep -q 'node_modules' "$MDLINT_CLI2" || {
    echo "FAIL: 未排除 node_modules" >&2; return 1; }
}

@test "MLG-5: MD013 上限鎖 120，且表格 / 程式碼區塊 / 標題豁免設定不得消失" {
  grep -q '"line_length": 120' "$MDLINT_CFG" || {
    echo "FAIL: MD013 line_length 不再是 120（放寬規則≠清債）" >&2; return 1; }
  grep -q '"tables": false' "$MDLINT_CFG" || {
    echo "FAIL: MD013 tables 豁免設定消失" >&2; return 1; }
  grep -q '"code_blocks": false' "$MDLINT_CFG" || {
    echo "FAIL: MD013 code_blocks 豁免設定消失" >&2; return 1; }
  grep -q '"headings": false' "$MDLINT_CFG" || {
    echo "FAIL: MD013 headings 豁免設定消失" >&2; return 1; }
}

@test "MLG-6: CONTRIBUTING 文件化本地 lint 指令與 120 欄政策" {
  grep -q 'markdownlint-cli2' "$CONTRIB" || {
    echo "FAIL: CONTRIBUTING 沒寫本地 lint 指令" >&2; return 1; }
  grep -q '120' "$CONTRIB" || {
    echo "FAIL: CONTRIBUTING 沒寫 120 欄政策" >&2; return 1; }
}

@test "MLG-7: 本機實跑 markdownlint-cli2 於 repo 全範圍必須 0 錯" {
  command -v markdownlint-cli2 >/dev/null 2>&1 || \
    skip "本機未安裝 markdownlint-cli2（CI 由阻擋式 Markdown lint job 保證）"
  cd "$REPO_ROOT"
  run markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
  [ "$status" -eq 0 ] || {
    echo "FAIL: markdownlint 有錯，輸出見上" >&2; return 1; }
}

@test "MLG-8: fixture 的 markdown 真的在 lint 範圍內（不得被 ignore 掉）" {
  local sample
  sample=$(find "$REPO_ROOT/tests/fixtures" -name '*.md' -print -quit)
  [[ -n "$sample" ]] || { echo "FAIL: fixture 無 .md" >&2; return 1; }
  local rel="${sample#"$REPO_ROOT"/}"
  # cli2 ignore 清單若命中 fixture 路徑（任何提到 tests/fixtures 的 ignore 字串，
  # 不論寫成 "!**/tests/**" / "tests/**" / "**/fixtures/**"）→ glob 覆蓋就是假的
  # （reviewer round B P2-3：原 regex 只認以 **/tests/ 開頭的形式，可繞過）
  # round C P2-3：再去掉行首錨——單行陣列 `"ignores": ["**/.venv/**", "tests/fixtures/**"]`
  # 的行首引號 token 是 `ignores`，行首錨版本咬不到（註解被誤咬＝fail-closed，可接受）
  if grep -qE '"[^"]*(tests|fixtures)[^"]*"' "$MDLINT_CLI2"; then
    echo "FAIL: .markdownlint-cli2.jsonc 有排除 tests/fixtures 的規則（glob 覆蓋失效）" >&2
    return 1
  fi
  command -v markdownlint-cli2 >/dev/null 2>&1 || \
    skip "本機未安裝 markdownlint-cli2（僅能靜態驗證：fixture 未被 ignore）"
  cd "$REPO_ROOT"
  run markdownlint-cli2 "$rel"
  [ "$status" -eq 0 ] || {
    echo "FAIL: fixture markdown 不乾淨: $rel" >&2; return 1; }
  # round C P2-3：rc=0 也可能是「一個檔都沒 lint 到」（ignore 生效時）→ 必須確認有實掃
  printf '%s' "$output" | grep -qE 'Linting: [1-9][0-9]* file' || {
    echo "FAIL: cli2 沒有真的 lint 到任何檔（Linting: 0 file）＝glob/ignore 生效中，rc=0 不可信" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
}

@test "MLG-9: lint job 不得被停用（不得有 if: 阻斷式條件）" {
  # reviewer round B P2-3 缺口：job/step 掛 `if: false` 沒有任何一條會抓到。
  # lint 是「文件債清零」的執行者，必須無條件跑；任何 if: 條件（含 ${{ … }} 條件式）
  # 都讓阻擋性變成不保證 → 一律視為停用。
  local code block
  code=$(grep -vE '^[[:space:]]*#' "$CI_YML")
  block=$(printf '%s\n' "$code" | awk '/^  lint-only:$/{flag=1; print; next} flag && /^  [A-Za-z0-9_-]+:$/{exit} flag{print}')
  [[ -n "$block" ]] || { echo "FAIL: 抽不到 lint job 區塊" >&2; return 1; }
  if printf '%s' "$block" | tr -d '[:space:]' | grep -q 'if:'; then
    echo "FAIL: lint job 帶 if: 條件（可被跳過＝阻擋不保證）" >&2
    printf '%s\n' "$block" | grep -n 'if:' >&2
    return 1
  fi
}
