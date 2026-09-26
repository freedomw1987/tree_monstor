#!/usr/bin/env bats
#
# tests/restruct-tdd-test-writer.bats
#
# Regression guards for TMO-009 stage 8: tdd-test-writer
# restructured to "task-navigation" style + plain-text references.

load 'helpers/test-env'

@test "RESTRUCT-TDD-TEST-WRITER: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-TDD-TEST-WRITER: trigger section exists" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-TDD-TEST-WRITER: explicit non-trigger" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-TDD-TEST-WRITER: flow section with 4 anchors" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-TDD-TEST-WRITER: rules section exists" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-TDD-TEST-WRITER: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-TDD-TEST-WRITER: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-TDD-TEST-WRITER: docs/backlog.md analysis rule preserved" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  grep -qF "backlog.md" "$skill" || {
    echo "FAIL: should reference backlog.md" >&2
    return 1
  }
}

@test "RESTRUCT-TDD-TEST-WRITER: framework selection preserved" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  grep -qE "Frontend|Backend|Full-stack" "$skill" || {
    echo "FAIL: should document Frontend/Backend/Full-stack" >&2
    return 1
  }
}

@test "RESTRUCT-TDD-TEST-WRITER: Given-When-Then test structure preserved" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  grep -qF "Given" "$skill" || { echo "FAIL: missing Given" >&2; return 1; }
  grep -qF "When" "$skill" || { echo "FAIL: missing When" >&2; return 1; }
  grep -qF "Then" "$skill" || { echo "FAIL: missing Then" >&2; return 1; }
}

# v2.1 plain-text references
@test "RESTRUCT-TDD-TEST-WRITER: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    return 1
  fi
}

@test "RESTRUCT-TDD-TEST-WRITER: no Obsidian cross-directory links" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-TDD-TEST-WRITER: file size sanity (was 142; allow up to 220)" {
  local skill="$REPO_ROOT/skills/tdd-test-writer/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 220 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 220)" >&2
    return 1
  }
}
