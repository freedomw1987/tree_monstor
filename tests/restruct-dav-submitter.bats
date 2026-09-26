#!/usr/bin/env bats
#
# tests/restruct-dav-submitter.bats
#
# Regression guards for TMO-009 stage 2: dav-submitter
# restructured to "task-navigation" style.

load 'helpers/test-env'

@test "RESTRUCT-DAV-SUBMITTER: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-SUBMITTER: TL;DR mentions v2.0 two-layer rule" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qiF "v2.0" || {
    echo "FAIL: TL;DR should mention v2.0 two-layer rule" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SUBMITTER: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-SUBMITTER: explicit non-trigger for plain Q&A" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  awk '/^## 觸發時機/,/^## [^觸]/' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should explicitly mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SUBMITTER: flow has steps with action/why/output/evidence" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  for keyword in "動作" "為什麼" "產出" "證據"; do
    awk '/^## 流程/,/^## [^流]/' "$skill" | grep -qF "$keyword" || {
      echo "FAIL: 流程 section missing keyword '$keyword'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DAV-SUBMITTER: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-SUBMITTER: change history section with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SUBMITTER: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-SUBMITTER: still mandates deliverable.md output" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "docs/deliverable"
}

@test "RESTRUCT-DAV-SUBMITTER: v2.0 reflection merge rule preserved" {
  local skill="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  assert_file_contains "$skill" "## 反思"
}
