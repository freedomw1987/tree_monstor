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
  SKILL_DIR="$REPO_ROOT/.agents/skills/dav-wiki"
}

# ---------- AC-1: skill folder structure ----------
@test "AC-1: skill folder exists at .agents/skills/dav-wiki/" {
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
  [[ "$output" =~ "name: dav-wiki" ]]
  [[ "$output" =~ "description:" ]]
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
@test "AC-6a: concept-evolution.md documents 'derive' (衍生)" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "derive|衍生" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6b: concept-evolution.md documents 'revise' (修正)" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "revise|修正" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6c: concept-evolution.md documents 'merge' (合併)" {
  [ -f "$SKILL_DIR/concept-evolution.md" ]
  run grep -iE "merge|合併" "$SKILL_DIR/concept-evolution.md"
  [ "$status" -eq 0 ]
}

@test "AC-6d: concept-evolution.md documents 'deprecate' (棄用)" {
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
