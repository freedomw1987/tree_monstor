#!/usr/bin/env bats
#
# tests/restruct-dav-trust.bats
#
# Regression guards for TMO-009 stage 4: dav-trust
# restructured to "task-navigation" style.

load 'helpers/test-env'

@test "RESTRUCT-DAV-TRUST: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-TRUST: TL;DR mentions trust-mode exit rule" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qiF "退出" || {
    echo "FAIL: TL;DR should mention trust-mode exit" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-TRUST: trigger mentions deadline + large goal" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # Extract trigger section (robust to Unicode headings)
  local trigger_section
  trigger_section=$(awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$trigger_section" | grep -qF "Deadline" || {
    echo "FAIL: trigger section should mention Deadline" >&2
    return 1
  }
  echo "$trigger_section" | grep -qF "大目標" || {
    echo "FAIL: trigger section should mention 大目標" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-TRUST: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-TRUST: trust-log SOP preserved" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "docs/trust-log.md"
}

@test "RESTRUCT-DAV-TRUST: need-you-help.md rule preserved" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "need-you-help.md"
}

@test "RESTRUCT-DAV-TRUST: end-of-trust rule preserved (§9 equivalent)" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # v2.0: any of "退出 trust", "Trust Mode 已結束", "退出 Trust Mode"
  if grep -qF "退出 trust" "$skill"; then return 0; fi
  if grep -qF "Trust Mode 已結束" "$skill"; then return 0; fi
  if grep -qF "退出 Trust Mode" "$skill"; then return 0; fi
  echo "FAIL: should document Trust Mode exit phrase" >&2
  return 1
}
