#!/usr/bin/env bats
#
# tests/restruct-dav-wiki.bats
#
# Regression guards for TMO-009 stage 6: dav-wiki
# restructured to "task-navigation" style + plain-text references.

load 'helpers/test-env'

@test "RESTRUCT-DAV-WIKI: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-WIKI: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-WIKI: explicit non-trigger for plain Q&A" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-WIKI: flow section with action/why/output/evidence" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-DAV-WIKI: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-WIKI: change history with v2.0 reference" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-WIKI: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-WIKI: 7-step wiki extraction flow preserved" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  # 7-step main flow should still mention all 7 steps
  grep -qF "來源識別" "$skill" || { echo "FAIL: missing 來源識別" >&2; return 1; }
  grep -qF "內容處理" "$skill" || { echo "FAIL: missing 內容處理" >&2; return 1; }
  grep -qF "Category" "$skill" || { echo "FAIL: missing Category" >&2; return 1; }
  grep -qF "Tag" "$skill" || { echo "FAIL: missing Tag" >&2; return 1; }
  grep -qF "交叉引用" "$skill" || { echo "FAIL: missing 交叉引用" >&2; return 1; }
  grep -qF "概念提取" "$skill" || { echo "FAIL: missing 概念提取" >&2; return 1; }
  grep -qF "寫入" "$skill" || { echo "FAIL: missing 寫入" >&2; return 1; }
}

@test "RESTRUCT-DAV-WIKI: FR-2 multi-module rule preserved" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "FR-2"
}

@test "RESTRUCT-DAV-WIKI: trust integration rule preserved" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  assert_file_contains "$skill" "dav-trust"
}

# ---------------------------------------------------------------------------
# v2.1 plain-text references rule
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-WIKI: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  # Should not contain markdown links pointing outside skills/dav-wiki/
  # (e.g., ../../../sop/handbook/, docs/DESIGN.md, docs/prd/...)
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link (../...)" >&2
    grep -nE '\]\(\.\./' "$skill" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    grep -nE '\]\(docs/' "$skill" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-WIKI: no Obsidian [[...]] cross-directory links" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-WIKI: file size sanity (was 143; allow up to 220)" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 220 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 220)" >&2
    return 1
  }
}
