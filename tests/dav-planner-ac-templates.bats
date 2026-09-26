#!/usr/bin/env bats
#
# tests/dav-planner-ac-templates.bats
#
# Regression tests for the "dav-planner AC templates" rule (TMO-006, v1.8).
# Ensures the rule is documented in all expected places:
#
#   1. skills/dav-planner/SKILL.md   (the skill body)
#        - section 4.3.2 AC column slim rule
#        - section 4.6  AC template generation SOP
#   2. docs/prd/01-dav-planner-ac-templates.md  (the PRD)
#   3. docs/ac/                                     (template files)
#        - README.md
#        - US-101.md + US-101.html  (examples)
#   4. docs/sop/handbook/changelog.md (v1.8 entry)
#
# If any of these drop the rule, an agent may regress to "AC stuffed inside
# the backlog.md table cell" anti-pattern.
#
# NOTE: Test names are pure ASCII (English) due to homebrew bats UTF-8 bug
# (see changelog v1.7.1). Functional grep checks still verify Chinese content.

setup() {
  load 'helpers/test-env'
}

# ---------- dav-planner SKILL.md ----------
@test "SKILL: dav-planner documents AC column slim rule (section 4.3.2)" {
  local f="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$f" "4.3.2"
  assert_file_contains "$f" "AC 欄位精簡"
  assert_file_contains "$f" "AC 摘要"
}

@test "SKILL: dav-planner documents HTML generation SOP (section 4.6)" {
  local f="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$f" "4.6"
  assert_file_contains "$f" "HTML 生成 SOP"
  assert_file_contains "$f" "docs/ac/"
  assert_file_contains "$f" "US-XXX.html"
}

# ---------- docs/prd ----------
@test "PRD: docs/prd/01-dav-planner-ac-templates.md exists and has AC summary section" {
  local f="$REPO_ROOT/docs/prd/01-dav-planner-ac-templates.md"
  assert_path_is_file "$f"
  assert_file_contains "$f" "AC 範本獨立化"
  assert_file_contains "$f" "Story Point"
}

# ---------- docs/ac/ ----------
@test "AC: docs/ac/README.md exists and documents naming convention" {
  local f="$REPO_ROOT/docs/ac/README.md"
  assert_path_is_file "$f"
  assert_file_contains "$f" "命名規範"
  assert_file_contains "$f" "US-XXX.md"
  assert_file_contains "$f" "US-XXX.html"
}

@test "AC: docs/ac/US-101.md example file exists with Given-When-Then" {
  local f="$REPO_ROOT/docs/ac/US-101.md"
  assert_path_is_file "$f"
  assert_file_contains "$f" "Given"
  assert_file_contains "$f" "When"
  assert_file_contains "$f" "Then"
  assert_file_contains "$f" "DoD"
}

@test "AC: docs/ac/US-101.html example file exists with print-friendly CSS" {
  local f="$REPO_ROOT/docs/ac/US-101.html"
  assert_path_is_file "$f"
  assert_file_contains "$f" "<style>"
  assert_file_contains "$f" "@media print"
  assert_file_contains "$f" "US-101"
}

# ---------- changelog ----------
@test "CHANGELOG: v1.8 entry documents dav-planner AC templates rule" {
  local f="$REPO_ROOT/docs/sop/handbook/changelog.md"
  assert_file_contains "$f" "v1.8"
  assert_file_contains "$f" "dav-planner"
  assert_file_contains "$f" "AC 範本"
}

# ---------- cross-consistency ----------
@test "CROSS: SKILL.md and PRD both reference docs/ac/<US-ID>.md pattern" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  local prd="$REPO_ROOT/docs/prd/01-dav-planner-ac-templates.md"
  assert_file_contains "$skill" "docs/ac/US-XXX.md"
  assert_file_contains "$prd"   "docs/ac/US-XXX.md"
}

@test "CROSS: SKILL.md and PRD both reference US-XXX.html" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  local prd="$REPO_ROOT/docs/prd/01-dav-planner-ac-templates.md"
  assert_file_contains "$skill" "US-XXX.html"
  assert_file_contains "$prd"   "US-XXX.html"
}

@test "GUARD: SKILL.md AC example uses correct relative path to docs/ac/" {
  # SKILL.md lives at skills/dav-planner/SKILL.md (2 levels deep from repo
  # root). To reach docs/ac/<file>, the relative path is ../../docs/ac/<file>.
  # This guard ensures the AC column slim example uses this correct path.
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  # The example table row must reference docs/ac/ via the correct ../../docs/ac/
  if ! grep -qF "../../docs/ac/" "$skill"; then
    echo "FAIL: SKILL.md AC example should use '../../docs/ac/' (from skills/dav-planner/ to docs/ac/)" >&2
    return 1
  fi
  # And must NOT use the wrong '../ac/' which would resolve to skills/ac/
  if grep -qE '\(\.\./ac/' "$skill"; then
    echo "FAIL: SKILL.md AC example uses wrong path '../ac/' (resolves to skills/ac/, not docs/ac/)" >&2
    return 1
  fi
}
