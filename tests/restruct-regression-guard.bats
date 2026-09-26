#!/usr/bin/env bats
#
# tests/restruct-regression-guard.bats
#
# Regression guards for TMO-009 stage 7: regression-guard
# restructured to "task-navigation" style + plain-text references.

load 'helpers/test-env'

@test "RESTRUCT-REGRESSION-GUARD: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-REGRESSION-GUARD: trigger section exists" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-REGRESSION-GUARD: explicit non-trigger for plain tasks" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-REGRESSION-GUARD: flow section with action/why/output/evidence" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-REGRESSION-GUARD: rules section exists" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-REGRESSION-GUARD: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-REGRESSION-GUARD: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-REGRESSION-GUARD: REGRESSION_MODE env var documented" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "REGRESSION_MODE"
}

@test "RESTRUCT-REGRESSION-GUARD: probe/assert/describe API preserved" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$skill" "probe("
  assert_file_contains "$skill" "assert("
  assert_file_contains "$skill" "describe("
}

@test "RESTRUCT-REGRESSION-GUARD: TTY fail-fast rule preserved" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  # The TTY/watch mode rule is the most important fail-fast guard
  grep -qF "/dev/null" "$skill" || {
    echo "FAIL: should document '/dev/null' TTY fix" >&2
    return 1
  }
  grep -qiE "watch|interactive" "$skill" || {
    echo "FAIL: should mention watch/interactive mode" >&2
    return 1
  }
}

# v2.1 plain-text references
@test "RESTRUCT-REGRESSION-GUARD: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    return 1
  fi
}

@test "RESTRUCT-REGRESSION-GUARD: no Obsidian cross-directory links" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-REGRESSION-GUARD: file size sanity (was 203; allow up to 280)" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 280 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 280)" >&2
    return 1
  }
}
