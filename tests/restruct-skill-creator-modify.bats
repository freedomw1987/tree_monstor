#!/usr/bin/env bats
#
# tests/restruct-skill-creator-modify.bats
#
# v2.3 rule: dav-skill-creator must cover skill MODIFICATION (not just new skill creation).
# Every skill modification must follow the skill-creator workflow.
# v2.2 rules automatically apply to all 9 skills post-TMO-009.

load 'helpers/test-env'

@test "SKILL-MODIFY: dav-skill-creator mentions skill modification in trigger" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  grep -qE '修改.*skill|skill.*修改|修改既有' "$skill" || {
    echo "FAIL: dav-skill-creator should mention skill modification in triggers" >&2
    return 1
  }
}

@test "SKILL-MODIFY: dav-skill-creator has modify-flow section" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # Should have a dedicated flow for modifying existing skills
  grep -qE '## 流程.*修改|M-Step|### 修改.*既有' "$skill" || {
    echo "FAIL: dav-skill-creator should have a modify-existing-skill flow" >&2
    return 1
  }
}

@test "SKILL-MODIFY: dav-skill-creator rules table includes 'modification follows same rules'" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  grep -qE '修改.*同樣|修改.*必遵|修改.*遵守|modif.*same.*rule' "$skill" || {
    echo "FAIL: dav-skill-creator rules should state 'modification follows same rules'" >&2
    return 1
  }
}

@test "SKILL-MODIFY: dav-skill-creator description includes modify" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # description in frontmatter should mention modify
  sed -n '/^description:/p' "$skill" | grep -qiE '修改|modify' || {
    echo "FAIL: dav-skill-creator description should include modify" >&2
    sed -n '/^description:/p' "$skill" >&2
    return 1
  }
}

@test "SKILL-MODIFY: dav-skill-creator documents v2.3 in changelog" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # v2.3 entry in 變動歷史
  grep -qE 'v2\.3' "$skill" || {
    echo "FAIL: dav-skill-creator should document v2.3" >&2
    return 1
  }
}

@test "SKILL-MODIFY: changelog has v2.3 entry" {
  local changelog="$REPO_ROOT/docs/sop/handbook/changelog.md"
  grep -qE '^## v2\.3' "$changelog" || {
    echo "FAIL: changelog should have v2.3 entry" >&2
    return 1
  }
}
