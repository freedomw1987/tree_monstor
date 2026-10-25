#!/usr/bin/env bats
#
# tests/dav-wiki.bats
#
# Black-box tests for the dav-wiki skill structure and content.
# Each test corresponds to one or more ACs in docs/backlog.md (US-009).
#
# Usage:
#   bats tests/dav-wiki.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  SKILL_DIR="$REPO_ROOT/skills/dav-wiki"
}

# ---------- AC-1: skill folder structure ----------
@test "AC-1: skill folder exists at skills/dav-wiki/" {
  [ -d "$SKILL_DIR" ]
}

@test "AC-1a: SKILL.md exists" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC-1b: examples.md exists" {
  [ -f "$SKILL_DIR/examples.md" ]
}

@test "AC-1c: frontmatter-schema.md exists" {
  [ -f "$SKILL_DIR/frontmatter-schema.md" ]
}

@test "AC-1d: concept-evolution.md exists" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
}

# ---------- AC-1e/1f: 結構性守護（原 tests/restruct-dav-wiki.bats 已於 2026-10-26 減法刪除，這兩支接手）----------
# 為什麼要在這裡：被刪的那支探針守的不是文字存在，而是「主檔指標指向的子檔真的還在、
# 且沒被掏空」——這是 TMO-026 / TMO-033 的原始目標，不隨 meta 層減法消失。

@test "AC-1e: subfile pointers in SKILL.md resolve (no silent loss)" {
  local skill="$SKILL_DIR/SKILL.md"
  local found=0 rel
  while IFS= read -r rel; do
    found=$((found + 1))
    [ -f "$SKILL_DIR/${rel#./}" ] || {
      echo "FAIL: pointer target missing: skills/dav-wiki/${rel#./}" >&2
      return 1
    }
  done < <(grep -oE '\./[A-Za-z0-9._-]+\.md' "$skill" | sort -u)
  # 防空過：指標擷取失效時 found=0 也會紅
  [ "$found" -ge 4 ] || {
    echo "FAIL: expected >=4 subfile pointers, found $found" >&2
    return 1
  }
}

@test "AC-1f: sub-file content anchor (emptying a subfile must be red)" {
  local skill="$SKILL_DIR/SKILL.md"
  local checked=0 rel lines
  while IFS= read -r rel; do
    local f="$SKILL_DIR/${rel#./}"
    [ -f "$f" ] || continue
    lines=$(grep -c '[^[:space:]]' "$f")
    [ "$lines" -ge 8 ] || {
      echo "FAIL: skills/dav-wiki/${rel#./} 有效行僅 ${lines}（< 8）＝子檔被掏空" >&2
      return 1
    }
    checked=$((checked + 1))
  done < <(grep -oE '\./[A-Za-z0-9._-]+\.md' "$skill" | sort -u)
  [ "$checked" -ge 4 ] || { echo "FAIL: 只檢查到 $checked 個子檔（擷取失效）" >&2; return 1; }
}

@test "AC-1g: sub-file product anchors survive (product nouns must not drift away)" {
  # 原 tests/restruct-dav-wiki.bats 的「② 關鍵內容鎖」（TMO-033）：
  # ①/AC-1f 只鎖「子檔有內容」，子檔被改成別的內容仍綠；這裡鎖的是 dav-wiki 的
  # **產品名詞**（產物檔名、CLI 旗標、frontmatter 欄位）——那是行為契約，不是文字。
  # 錨點必須是「獨立詞」（前後不得為英數／底線／連字號），否則 `--purge-x` 也會誤過。
  anchor_hit() {
    local pat="${2//./\\.}"
    grep -qE "(^|[^A-Za-z0-9_-])${pat}([^A-Za-z0-9_-]|$)" "$1"
  }
  local anchors=0 token f
  for token in '_index.json' '_tags.json' '_concepts.json' 'transcript.md'; do
    f="$SKILL_DIR/output-structure.md"
    anchor_hit "$f" "$token" || {
      echo "FAIL: output-structure.md 缺獨立詞 '$token'（內容漂移／掏空）" >&2; return 1; }
    anchors=$((anchors + 1))
  done
  for token in 'deprecated_at' '--older-than' '--purge'; do
    f="$SKILL_DIR/soft-delete.md"
    anchor_hit "$f" "$token" || {
      echo "FAIL: soft-delete.md 缺獨立詞 '$token'（內容漂移／掏空）" >&2; return 1; }
    anchors=$((anchors + 1))
  done
  [ "$anchors" -ge 7 ] || { echo "FAIL: 內容錨點只驗到 $anchors 個（< 7）＝錨點表被削弱" >&2; return 1; }
}

@test "AC-1h: change history references current version" {
  # 原 tests/restruct-dav-wiki.bats 的「主檔最新版本列須與 CHANGELOG.md 首列一致」
  # ——這是**跨檔一致性**契約（防版本漂移），不是文字存在性；同 dav-trust 做法。
  local skill="$SKILL_DIR/SKILL.md"
  local cl="$SKILL_DIR/CHANGELOG.md"
  [ -f "$cl" ] || { echo "FAIL: 缺 CHANGELOG.md，無法比對版本" >&2; return 1; }
  awk '/^## 變動歷史/{flag=1} flag' "$skill" | grep -qE 'v2\.0' || {
    echo "FAIL: 變動歷史應保留 v2.0 首版錨點" >&2
    return 1
  }
  local v_skill v_cl
  v_skill=$(awk '/^## 變動歷史/{flag=1} flag' "$skill" | grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | tr -d '| ')
  v_cl=$(grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)?' "$cl" | head -1 | tr -d '| ')
  [ -n "$v_skill" ] && [ "$v_skill" = "$v_cl" ] || {
    echo "FAIL: 主檔最新版本($v_skill) 與 CHANGELOG($v_cl) 不一致" >&2
    return 1
  }
}

# ---------- AC-2: SKILL.md ≤ 150 lines ----------
@test "AC-2: SKILL.md is at most 150 lines" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

# ---------- AC-3: SKILL.md frontmatter ----------
@test "AC-3: SKILL.md has valid YAML frontmatter with name + description" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  # First non-empty line must be ---
  local first
  first=$(head -1 "$SKILL_DIR/SKILL.md")
  [ "$first" = "---" ]
  # Must contain 'name: dav-wiki' and 'description:' within first 10 lines
  run head -10 "$SKILL_DIR/SKILL.md"
  [[ "$output" =~ "name: dav-wiki" ]] || {
    echo 'FAIL: tests/dav-wiki.bats:54: assertion failed' >&2; return 1; }
  [[ "$output" =~ "description:" ]] || {
    echo 'FAIL: tests/dav-wiki.bats:56: assertion failed' >&2; return 1; }
}

# ---------- AC-4: SKILL.md mentions the 7-step workflow ----------
@test "AC-4: SKILL.md describes the 7-step workflow" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  # Should mention all 7 steps by name
  for step in "來源識別" "內容處理" "Category" "Tag" "交叉引用" "概念提取" "寫入"; do
    run grep -F "$step" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

# ---------- AC-5: frontmatter-schema.md has both schemas ----------
@test "AC-5a: frontmatter-schema.md documents wiki doc schema (title/source/extracted_at/category/tags/summary/related/concepts)" {
  [ -f "$SKILL_DIR/frontmatter-schema.md" ]
  for field in "title" "source" "extracted_at" "category" "tags" "summary" "related" "concepts"; do
    run grep -F "$field" "$SKILL_DIR/frontmatter-schema.md"
    [ "$status" -eq 0 ]
  done
}

@test "AC-5b: frontmatter-schema.md documents concept schema (slug/definition/status/parents/children/history)" {
  [ -f "$SKILL_DIR/frontmatter-schema.md" ]
  for field in "slug" "definition" "status" "parents" "children" "history"; do
    run grep -F "$field" "$SKILL_DIR/frontmatter-schema.md"
    [ "$status" -eq 0 ]
  done
}

# ---------- AC-6: concept-evolution.md has 4 evolution actions ----------
@test "AC-6a: concept-evolution.md documents 'derive'" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "derive|衍生" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6b: concept-evolution.md documents 'revise'" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "revise|修正" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6c: concept-evolution.md documents 'merge'" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "merge|合併" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6d: concept-evolution.md documents 'deprecate'" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "deprecate|棄用|superseded" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

# ---------- AC-7: examples.md has 5+ examples ----------
@test "AC-7: examples.md has at least 5 numbered examples" {
  [ -f "$SKILL_DIR/examples.md" ]
  # Count occurrences of "## 範例 N" pattern
  local count
  count=$(grep -cE "^## 範例 [0-9]+" "$SKILL_DIR/examples.md" || true)
  [ "$count" -ge 5 ]
}

# ---------- AC-8: SKILL.md mentions all 5 source types ----------
@test "AC-8: SKILL.md mentions all 5 source types" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  for keyword in "pdf" "docx" "url" "ocr" "字幕"; do
    run grep -iE "$keyword" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

# ---------- AC-9: SKILL.md describes /trust prefix ----------
@test "AC-9: SKILL.md documents /trust prefix integration" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  run grep -F "/trust" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

# ---------- AC-10: SKILL.md mentions Obsidian-style wikilinks ----------
@test "AC-10: SKILL.md documents Obsidian wikilink syntax [[xxx]]" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  # Should mention [[ syntax
  run grep -F "[[" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

# ---------- AC-11: SKILL.md mentions soft-delete mechanism ----------
@test "AC-11: SKILL.md documents soft-delete via frontmatter (deprecated/superseded_by)" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  for keyword in "deprecated" "superseded_by"; do
    run grep -F "$keyword" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

# ---------- AC-12: SKILL.md describes docs/README.md auto-rebuild ----------
@test "AC-12: SKILL.md documents docs/README.md auto-rebuild" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  run grep -F "README.md" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

teardown() {
  :;
}
