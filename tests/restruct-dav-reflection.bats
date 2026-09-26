#!/usr/bin/env bats
#
# tests/restruct-dav-reflection.bats
#
# Regression guards for TMO-009 stage 1 (PoC): dav-reflection
# restructured to "task-navigation" style.
#
# Gate 1 (TDD): RED → implement → GREEN.

load 'helpers/test-env'

# ---------------------------------------------------------------------------
# TL;DR block
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: TL;DR section exists and is concise" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-REFLECTION: TL;DR mentions 6-check-dimensions and v2.0 deliverable" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  # TL;DR should mention the 6 dimensions and v2.0 merge-into-deliverable
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qiF "6" || {
    echo "FAIL: TL;DR should mention 6 dimensions" >&2
    return 1
  }
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qiF "v2.0" || {
    echo "FAIL: TL;DR should mention v2.0 deliverable merge rule" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Trigger conditions
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: trigger section exists with table" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-REFLECTION: explicit non-trigger for plain Q&A" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  # Non-trigger row with check/x mark
  awk '/^## 觸發時機/,/^## [^觸]/' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should explicitly mark non-trigger scenarios" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Flow steps
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: flow has N steps with action/why/output/evidence" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  # Each step should have these 4 anchors
  for keyword in "動作" "為什麼" "產出" "證據"; do
    awk '/^## 流程/,/^## [^流]/' "$skill" | grep -qF "$keyword" || {
      echo "FAIL: 流程 section missing keyword '$keyword'" >&2
      return 1
    }
  done
}

# ---------------------------------------------------------------------------
# Rules / exceptions / limits
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

# ---------------------------------------------------------------------------
# Change history (per-skill CHANGELOG)
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: change history section exists with version table" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Behavior preservation: v2.0 rule must still apply
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: still documents v2.0 reflection merge rule" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  # v2.0 rule: reflection merged into deliverable.md, no standalone reflection file
  assert_file_contains "$skill" "併入"
  assert_file_contains "$skill" "## 反思"
}

# ---------------------------------------------------------------------------
# Anti-pattern: the skill should not contain the old "工作流程" box-drawing ASCII
# art (which was LLM-unfriendly)
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing (LLM-unfriendly)" >&2
    grep -nE '├─|└─|┌─' "$skill" >&2
    return 1
  fi
}
