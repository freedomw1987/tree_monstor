#!/usr/bin/env bats
#
# tests/dav-planner-user-background.bats
#
# Regression guards for dav-planner v1.9 "user background collection"
# (Section 2.7 in SKILL.md). These probes ensure the new chapter
# and its role-mapping table are not silently removed.
#
# Gate 1 (TDD): RED → implement SKILL.md / changelog / backlog → GREEN.

load 'helpers/test-env'

# ---------------------------------------------------------------------------
# Section existence
# ---------------------------------------------------------------------------

@test "SKILL: dav-planner documents user background collection (section 2.7)" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## 2.7"
  assert_file_contains "$skill" "用戶背景收集"
}

@test "SKILL: dav-planner section 2.7 has a role-to-followup mapping table" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "PM/PO"
  assert_file_contains "$skill" "開發者"
  assert_file_contains "$skill" "設計師"
  assert_file_contains "$skill" "業務"
}

@test "SKILL: dav-planner section 2.7 documents the skip rule (2.7.1)" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "### 2.7.1"
  # Must mention "skip" behavior so future maintainers don't remove the rule
  grep -qiF "跳過" "$skill" || {
    echo "FAIL: §2.7.1 must mention the skip rule (跳過)" >&2
    return 1
  }
}

@test "SKILL: dav-planner section 2.7.2 distinguishes from §3 Persona" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "### 2.7.2"
  assert_file_contains "$skill" "Persona"
}

# ---------------------------------------------------------------------------
# Cross-file consistency
# ---------------------------------------------------------------------------

@test "CHANGELOG: v1.9 entry documents user background collection rule" {
  local cl="$REPO_ROOT/docs/sop/handbook/changelog.md"
  assert_file_contains "$cl" "v1.9"
  assert_file_contains "$cl" "用戶背景收集"
}

@test "BACKLOG: TMO-007 dav-planner user background entry exists" {
  local bl="$REPO_ROOT/docs/backlog.md"
  assert_file_contains "$bl" "TMO-007"
  assert_file_contains "$bl" "用戶背景收集"
}

@test "PRD: docs/prd/02-dav-planner-user-background.md exists" {
  local prd="$REPO_ROOT/docs/prd/02-dav-planner-user-background.md"
  [[ -f "$prd" ]] || {
    echo "FAIL: $prd does not exist" >&2
    return 1
  }
}
