#!/usr/bin/env bats
#
# tests/restruct-dev-checker-loop.bats
#
# Regression guards for TMO-009 stage 9: dev-checker-loop
# restructured to "task-navigation" style + plain-text references.

load 'helpers/test-env'

@test "RESTRUCT-DEV-CHECKER-LOOP: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: trigger section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: explicit non-trigger" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: flow section with 4 anchors" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: rules section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: dev + checker dual role preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "dev" "$skill" || { echo "FAIL: missing dev role" >&2; return 1; }
  grep -qF "checker" "$skill" || { echo "FAIL: missing checker role" >&2; return 1; }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: 20-cycle limit preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "20" "$skill" || {
    echo "FAIL: should mention 20-cycle limit" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: regression-guard integration preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "regression-guard" "$skill" || {
    echo "FAIL: should reference regression-guard" >&2
    return 1
  }
}

# v2.1 plain-text references
@test "RESTRUCT-DEV-CHECKER-LOOP: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: no Obsidian cross-directory links" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: file size sanity (was 63; allow up to 130)" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 130 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 130)" >&2
    return 1
  }
}
