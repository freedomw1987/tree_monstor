#!/usr/bin/env bats
#
# tests/restruct-dav-skill-creater.bats
#
# Regression guards for TMO-009 stage 10: dav-skill-creater
# enhanced with "readability + LLM attention" guidelines + plain-text refs.

load 'helpers/test-env'

@test "RESTRUCT-DAV-SKILL-CREATER: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-SKILL-CREATER: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-SKILL-CREATER: explicit non-trigger" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SKILL-CREATER: flow section with 4 anchors" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-DAV-SKILL-CREATER: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-SKILL-CREATER: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SKILL-CREATER: 150-line SKILL.md size limit preserved" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  grep -qF "150" "$skill" || {
    echo "FAIL: should mention 150-line limit" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SKILL-CREATER: naming convention (kebab-case) preserved" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  grep -qE "英文字符|kebab-case|減號" "$skill" || {
    echo "FAIL: should document naming convention" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SKILL-CREATER: LLM attention writing guidelines section (v2.1)" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # v2.1: should add a section about LLM-attention-friendly writing
  grep -qiE "LLM 注意力|LLM 注意|LLM attention" "$skill" || {
    echo "FAIL: should document LLM attention writing guidelines" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-SKILL-CREATER: task-navigation structure recommendation (v2.1)" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # v2.1: should recommend the 5-section task-navigation structure
  grep -qiE "任務導航|TL;DR" "$skill" || {
    echo "FAIL: should recommend task-navigation structure" >&2
    return 1
  }
}

# v2.1 plain-text references (dav-skill-creater must use plain text, not wiki links)
@test "RESTRUCT-DAV-SKILL-CREATER: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-SKILL-CREATER: no Obsidian cross-directory links" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-SKILL-CREATER: file size sanity (was 20; allow up to 200 after enhancement)" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 200 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 200)" >&2
    return 1
  }
}
