#!/usr/bin/env bats
#
# tests/skill-size.bats —— skill 行數硬門檻（v2.11 減法版）
#
# 為什麼有呢支：2026-10-28 實測 —— 11 個 skill **全部**主檔超 50 行、7 支子檔超 150 行。
# v2.8 嘅「主檔 ≤150／子檔 ≤300／context ≤ baseline」靠自律冇人守 → 規則失效（假規則）。
# → 呢支探針守住新規則，而且**逐個 skill 目錄掃** → 之後新造嘅 skill 自動受約束，
#   唔需要有人記得「手動量一次」。
#
# 口徑（單一真相：skills/dav-skill-creater/editor-guide.md「文檔行數限制（v2.11 減法版）」）：
#   - 主檔 SKILL.md ≤ 50 行
#   - 支援子檔 ≤ 150 行
#   - 單 skill context（主檔 + 支援子檔）≤ 400 行
#   - 例外：路徑／檔名命中 example / template / fixture / poc 者 **不計**
#     （樣例資料、可填充模板、demo 實作 —— 唔係每次觸發都要讀嘅指引）
#
# 用 `find`（唔用 `git ls-files`）：**未 commit 嘅新 skill 都要即刻被捉**，
# 否則「新 skill 寫完未 commit」呢段真空期冇人守。
# （find 會見到 `PoC/.venv/` 內嘅 LICENSE.md → 由 poc 例外口徑自然排除。）

load 'helpers/test-env'

# ⚠️ 上限寫喺**檔案層**（唔喺 setup()）→ SS-5 可以由本檔反解析出嚟，
# 同規則文件（editor-guide.md ＋ AGENTS.md）對數；改任何一邊都會令 SS-5 紅。
MAIN_CAP=50
SUB_CAP=150
CTX_CAP=400
# 例外口徑：路徑／檔名命中即不計（case-insensitive；PoC → poc）
EXCL_RE='example|template|fixture|poc'

setup() {
  SKILLS_DIR="$REPO_ROOT/skills"
}

# 列出某 skill 嘅支援 .md 檔（已剔除例外口徑），每行一個相對路徑
support_files() {
  local skill_dir="${1%/}"
  find "$skill_dir" -type f -name '*.md' \
    -not -path '*/.git/*' \
    -not -path '*/.venv/*' \
    -not -path '*/node_modules/*' \
    | sed "s|^$skill_dir/||" \
    | grep -viE "$EXCL_RE" \
    | grep -v '^SKILL\.md$' \
    | sort
}

# 量行數（檔唔存在 → 直接 FAIL，唔可以靜靜哋當 0）
count_lines() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "FAIL: 量行數嘅檔唔存在：$f" >&2
    return 1
  fi
  wc -l < "$f" | tr -d ' '
}

# --- 三個上限檢查（回傳 0＝合規／1＝超標；MSG 印去 stderr）-------------------

check_main() {
  local skill_dir="${1%/}" main n
  main="$skill_dir/SKILL.md"
  if [ ! -f "$main" ]; then
    echo "FAIL: $(basename "$skill_dir") 冇 SKILL.md（每個 skill 都要有主檔）" >&2
    return 1
  fi
  n="$(count_lines "$main")" || return 1
  if [ "$n" -gt "$MAIN_CAP" ]; then
    echo "FAIL: $main 有 $n 行（上限 ${MAIN_CAP}）→ 主檔只留指標，內容搬去支援子檔" >&2
    return 1
  fi
  return 0
}

check_sub() {
  local skill_dir="${1%/}" rel n
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n="$(count_lines "$skill_dir/$rel")" || return 1
    if [ "$n" -gt "$SUB_CAP" ]; then
      echo "FAIL: $skill_dir/$rel 有 $n 行（上限 ${SUB_CAP}）→ 拆檔或壓成清單" >&2
      return 1
    fi
  done < <(support_files "$skill_dir")
  return 0
}

check_ctx() {
  local skill_dir="${1%/}" n
  n="$( { cat "$skill_dir/SKILL.md"; while IFS= read -r rel; do
            [ -n "$rel" ] && cat "$skill_dir/$rel"
          done < <(support_files "$skill_dir"); } | wc -l | tr -d ' ')"
  if [ "$n" -gt "$CTX_CAP" ]; then
    echo "FAIL: $(basename "$skill_dir") 嘅 context 有 $n 行（上限 ${CTX_CAP}）→ 減法（去重 → 列表化 → 指標化）或拆 skill" >&2
    return 1
  fi
  return 0
}

# --- 測試 ---------------------------------------------------------------------

@test "SS-1: every skill has a SKILL.md within the 50-line hard cap" {
  local d n=0
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$((n + 1))
    check_main "$d" || return 1
  done
  # fail-closed：列舉唔到 skill 目錄 → glob 失效 → 唔准靜靜哋全綠
  #（repo 慣例，見 scripts/check-all.sh 嘅 skill-tests 步驟）
  [ "$n" -ge 11 ] || {
    echo "FAIL: 只列舉到 $n 個 skill 目錄（下限 11）→ glob 失效，唔准空過" >&2
    return 1
  }
}

@test "SS-2: every support sub-file within the 150-line hard cap" {
  local d n=0
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$((n + 1))
    check_sub "$d" || return 1
  done
  [ "$n" -ge 11 ] || {
    echo "FAIL: 只列舉到 $n 個 skill 目錄（下限 11）→ glob 失效，唔准空過" >&2
    return 1
  }
}

@test "SS-3: every skill context (main + support sub-files) within the 400-line cap" {
  local d n=0
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    n=$((n + 1))
    check_ctx "$d" || return 1
  done
  [ "$n" -ge 11 ] || {
    echo "FAIL: 只列舉到 $n 個 skill 目錄（下限 11）→ glob 失效，唔准空過" >&2
    return 1
  }
}

@test "SS-4: the exception pattern really excludes example/template/fixture/poc files" {
  # 自我檢查：例外口徑唔係空轉（將來改錯 regex 呢支會紅）
  local excluded
  excluded="$(find "$SKILLS_DIR" -type f -name '*.md' -not -path '*/.git/*' -not -path '*/.venv/*' \
    | grep -icE "$EXCL_RE")"
  [ "$excluded" -gt 0 ] || {
    echo "FAIL: 冇任何 .md 命中例外口徑 → regex 可能寫錯（樣例會被當指引計）" >&2
    return 1
  }
  # 主檔一定唔可以被排除（排除口徑只適用於支援檔）
  if echo "SKILL.md" | grep -qiE "$EXCL_RE"; then
    echo "FAIL: 例外口徑會連主檔都排除 → 主檔必須永遠計入上限" >&2
    return 1
  fi
}

@test "SS-5: the rule doc and this probe quote the same caps" {
  # 契約鎖（雙向）：規則文件（editor-guide.md ＋ AGENTS.md）同**本檔嘅常數**唔准漂移
  # → 改任何一邊，另一邊就會對唔上 → 紅。
  local guide="$SKILLS_DIR/dav-skill-creater/editor-guide.md"
  local agents="$REPO_ROOT/AGENTS.md"
  local fmain fsub fctx
  fmain="$(grep -oE '^MAIN_CAP=[0-9]+' "$BATS_TEST_FILENAME" | tail -1 | cut -d= -f2)"
  fsub="$(grep -oE '^SUB_CAP=[0-9]+' "$BATS_TEST_FILENAME" | tail -1 | cut -d= -f2)"
  fctx="$(grep -oE '^CTX_CAP=[0-9]+' "$BATS_TEST_FILENAME" | tail -1 | cut -d= -f2)"
  [ -n "$fmain" ] && [ -n "$fsub" ] && [ -n "$fctx" ] || {
    echo "FAIL: 解析唔到本檔嘅上限常數（MAIN_CAP/SUB_CAP/CTX_CAP）→ SS-5 會變成空過" >&2
    return 1
  }
  assert_file_contains "$guide" "≤ ${fmain} 行"
  assert_file_contains "$guide" "≤ ${fsub} 行"
  assert_file_contains "$guide" "≤ ${fctx} 行"
  assert_file_contains "$agents" "≤${fmain} 行"
  assert_file_contains "$agents" "≤${fsub} 行"
  assert_file_contains "$agents" "≤${fctx} 行"
  # 例外口徑（example／template／fixture／poc）同樣要雙向鎖：
  # 改探針嘅 EXCL_RE 或改規則文件嘅例外清單，另一邊都會對唔上 → 紅。
  local excl kw
  excl="$(grep -oE "^EXCL_RE='[^']*'" "$BATS_TEST_FILENAME" | tail -1 | cut -d"'" -f2)"
  [ -n "$excl" ] || {
    echo "FAIL: 解析唔到本檔嘅 EXCL_RE → 例外口徑嘅鎖會變成空過" >&2
    return 1
  }
  for kw in example template fixture poc; do
    case "$excl" in
      *"$kw"*) : ;;
      *)
        echo "FAIL: EXCL_RE 冇 ${kw}（例外口徑被改窄咗）" >&2
        return 1
        ;;
    esac
    # 例外關鍵字喺規則文件入面大小寫唔拘（`PoC` vs `poc`）→ 用 case-insensitive 比對
    grep -qi -- "$kw" "$guide" || {
      echo "FAIL: ${guide} 冇提例外關鍵字 ${kw}（例外口徑同探針唔一致）" >&2
      return 1
    }
    grep -qi -- "$kw" "$agents" || {
      echo "FAIL: ${agents} 冇提例外關鍵字 ${kw}（例外口徑同探針唔一致）" >&2
      return 1
    }
  done
}

@test "SS-6: the three cap checks really bite (reverse test on a temp copy)" {
  # 唔可以「恆綠假過」：喺臨時目錄種違規 skill，三個檢查都必須紅；再種合規 skill，必須綠。
  local base="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$base/bad-main" "$base/bad-sub" "$base/bad-ctx" "$base/ok-skill"
  for i in $(seq 1 60); do echo "x $i" >> "$base/bad-main/SKILL.md"; done
  for i in $(seq 1 5);  do echo "x $i" >> "$base/bad-sub/SKILL.md"; done
  for i in $(seq 1 200); do echo "y $i" >> "$base/bad-sub/guide.md"; done
  for i in $(seq 1 60);  do echo "x $i" >> "$base/bad-ctx/SKILL.md"; done
  for i in $(seq 1 400); do echo "y $i" >> "$base/bad-ctx/guide.md"; done
  for i in $(seq 1 10);  do echo "x $i" >> "$base/ok-skill/SKILL.md"; done
  for i in $(seq 1 20);  do echo "y $i" >> "$base/ok-skill/guide.md"; done

  run check_main "$base/bad-main"; [ "$status" -ne 0 ] || { echo "FAIL: 主檔超限但 check_main 冇紅" >&2; return 1; }
  run check_sub "$base/bad-sub";  [ "$status" -ne 0 ] || { echo "FAIL: 子檔超限但 check_sub 冇紅" >&2; return 1; }
  run check_ctx "$base/bad-ctx";  [ "$status" -ne 0 ] || { echo "FAIL: context 超限但 check_ctx 冇紅" >&2; return 1; }
  run check_main "$base/ok-skill"; [ "$status" -eq 0 ] || { echo "FAIL: 合規 skill 竟然紅咗（check_main）" >&2; return 1; }
  run check_sub "$base/ok-skill";  [ "$status" -eq 0 ] || { echo "FAIL: 合規 skill 竟然紅咗（check_sub）" >&2; return 1; }
  run check_ctx "$base/ok-skill";  [ "$status" -eq 0 ] || { echo "FAIL: 合規 skill 竟然紅咗（check_ctx）" >&2; return 1; }
}
