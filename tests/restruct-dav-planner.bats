#!/usr/bin/env bats
#
# tests/restruct-dav-planner.bats
#
# Regression guards for TMO-009 stage 3: dav-planner
# restructured to "task-navigation" style.
# Note: dav-planner is large (492 lines), so the new structure
# may have multiple ## sections; we verify the 5 core anchors exist.

load 'helpers/test-env'

@test "RESTRUCT-DAV-PLANNER: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-PLANNER: TL;DR mentions 7 SOP stages" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qE "§2\.1" || {
    echo "FAIL: TL;DR should mention SOP §2.1" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-PLANNER: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-PLANNER: explicit non-trigger for executed work" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  awk '/^## 觸發時機/,/^## [^觸]/' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should explicitly mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-PLANNER: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-PLANNER: change history section with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-PLANNER: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-PLANNER: v1.9 §2.7 user background collection rule preserved" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  # v2.0 restructured: header may be "## §2.7" (with § prefix)
  grep -qF "§2.7" "$skill" || {
    echo "FAIL: skill should reference §2.7" >&2
    return 1
  }
  # 5 roles
  for role in "PM/PO" "開發者" "設計師" "業務" "其他"; do
    grep -qF "$role" "$skill" || {
      echo "FAIL: §2.7 missing role '$role'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DAV-PLANNER: v1.8 AC template generation rule preserved" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "docs/ac"
  assert_file_contains "$skill" "Given-When-Then"
}

@test "RESTRUCT-DAV-PLANNER: SWOT trigger rule preserved" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "SWOT"
}

@test "RESTRUCT-DAV-PLANNER: 4 core + 5 supplementary dimensions preserved" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "核心 4 維度"
  assert_file_contains "$skill" "補充 5 維度"
}

@test "RESTRUCT-DAV-PLANNER: V01/V02/V03 紀律 referenced" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  for v in "V01" "V02" "V03"; do
    grep -qF "$v" "$skill" || {
      echo "FAIL: missing $v 紀律 reference" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DAV-PLANNER: file size sanity check (target: shrink or stable)" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  # Original was 492; allow up to 600 (we add structure anchors)
  [ "$lines" -lt 600 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 600)" >&2
    return 1
  }
}
