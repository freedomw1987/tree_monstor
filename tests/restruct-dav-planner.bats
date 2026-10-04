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
  local cl="$REPO_ROOT/skills/dav-planner/CHANGELOG.md"
  assert_file_contains "$skill" "## 變動歷史"
  # v2.2 拆檔：主檔只留最近 3 條，推到 CHANGELOG.md；v2.0 應在完整歷史裡
  assert_file_contains "$skill" "CHANGELOG.md"
  # 主檔仍須真的列出最近版本列，且最新的版本須與 CHANGELOG 一致（防漂移）
  local v_skill v_cl
  v_skill=$(awk '/^## 變動歷史/{flag=1} flag' "$skill" | grep -oE '^\| v[0-9]+\.[0-9]+' | head -1 | tr -d '| ')
  v_cl=$(grep -oE '^\| v[0-9]+\.[0-9]+' "$cl" | head -1 | tr -d '| ')
  [ -n "$v_skill" ] && [ "$v_skill" = "$v_cl" ] || {
    echo "FAIL: 主檔最新版本($v_skill) 與 CHANGELOG($v_cl) 不一致" >&2
    return 1
  }
  grep -qE "v2\.0" "$cl" || {
    echo "FAIL: CHANGELOG.md should reference v2.0" >&2
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

@test "RESTRUCT-DAV-PLANNER: v1.9 section 2.7 retired (not re-introduced)" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  # v2.1 用戶決策廢除 §2.7 用戶背景收集（見 skills/dav-planner/CHANGELOG.md）→ 不可回流
  # 用主題級字串而非 §2.7 編號（reviewer P2-2：避免未來合法編號誤紅）
  refute_file_contains "$skill" "用戶背景收集"
  refute_file_contains "$skill" "角色詢問"
  for role in "PM/PO" "業務"; do
    refute_file_contains "$skill" "$role"
  done
  # 但「不問對話用戶個人角色」的定位句必須留著
  assert_file_contains "$skill" "不問對話用戶的個人角色"
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

@test "RESTRUCT-DAV-PLANNER: V01/V02/V03 discipline referenced" {
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
