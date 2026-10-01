#!/usr/bin/env bats
#
# tests/restruct-dev-checker-loop.bats
#
# Regression guards for TMO-009 stage 9: dev-checker-loop
# restructured to "task-navigation" style + plain-text references.

load 'helpers/test-env'

@test "RESTRUCT-DEV-CHECKER-LOOP: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: trigger section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: explicit non-trigger" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill" | grep -qE "❌|不觸發|不該" || {
    echo "FAIL: trigger section should mark non-trigger" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: flow section with 4 anchors" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 流程"
  local flow
  flow=$(awk '/^## 流程/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$flow" | grep -qF "動作" || { echo "FAIL: missing 動作" >&2; return 1; }
  echo "$flow" | grep -qF "為什麼" || { echo "FAIL: missing 為什麼" >&2; return 1; }
  echo "$flow" | grep -qF "產出" || { echo "FAIL: missing 產出" >&2; return 1; }
  echo "$flow" | grep -qF "證據" || { echo "FAIL: missing 證據" >&2; return 1; }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: rules section exists" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DEV-CHECKER-LOOP: change history (v2.4: outer pointer OR CHANGELOG reference)" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "## 變動歷史"
  # Since v2.4 the change history is outer-pointed to CHANGELOG.md.
  # Accept either form: an explicit v2.x row in the master, OR a CHANGELOG pointer.
  if awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.[0-9]"; then
    return 0
  fi
  if grep -qF "CHANGELOG.md" "$skill"; then
    return 0
  fi
  echo "FAIL: 變動歷史 should reference v2.x OR point to CHANGELOG.md" >&2
  return 1
}

@test "RESTRUCT-DEV-CHECKER-LOOP: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: dev + checker dual role preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "dev" "$skill" || { echo "FAIL: missing dev role" >&2; return 1; }
  grep -qF "checker" "$skill" || { echo "FAIL: missing checker role" >&2; return 1; }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: 20-cycle limit preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "20" "$skill" || {
    echo "FAIL: should mention 20-cycle limit" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP: regression-guard integration preserved" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  grep -qF "regression-guard" "$skill" || {
    echo "FAIL: should reference regression-guard" >&2
    return 1
  }
}

# v2.1 plain-text references
@test "RESTRUCT-DEV-CHECKER-LOOP: no cross-directory markdown links outside skill dir" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '\]\(\.\./' "$skill"; then
    echo "FAIL: skill has cross-directory markdown link" >&2
    return 1
  fi
  if grep -qE '\]\(docs/' "$skill"; then
    echo "FAIL: skill has docs/ markdown link" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: no Obsidian cross-directory links" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  if grep -qE '\[\[.*\.\./|\[\[docs/' "$skill"; then
    echo "FAIL: skill has Obsidian cross-directory link" >&2
    return 1
  fi
}

@test "RESTRUCT-DEV-CHECKER-LOOP: file size sanity (target < 130 green zone)" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 130 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 130 green zone)" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# v2.4 jev integration probes
# ---------------------------------------------------------------------------

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: Step 0 (v2.4 availability probe) exists in SKILL.md" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "### Step 0：可用性偵測（v2.4 新增）"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: Step 0 references workflow.md for jev detail" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "workflow.md"
  assert_file_contains "$skill" "jev 整合細節"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: TL;DR mentions v2.4 jev optional enhancement" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qF "jev-use" || {
    echo "FAIL: TL;DR should mention jev-use availability" >&2
    return 1
  }
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: Step 3 jev embed detail (pre-scan + post-verify) in workflow.md" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "v2.4 新增 jev 嵌入細節"
  # Actual keyword anchors live in workflow.md after slim-down (v2.4)
  local workflow="$REPO_ROOT/skills/dev-checker-loop/workflow.md"
  assert_file_contains "$workflow" "校驗前 jev 快篩"
  assert_file_contains "$workflow" "校驗後 jev 驗證"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: rules table references v2.4 jev 6 rules (delegated to workflow.md)" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  assert_file_contains "$skill" "v2.4 jev 6 條規則"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B2-TermAlign]: workflow.md contains full jev integration chapter" {
  local workflow="$REPO_ROOT/skills/dev-checker-loop/workflow.md"
  assert_file_contains "$workflow" "## jev 整合細節（v2.4 新增）"
  assert_file_contains "$workflow" "可用性偵測"
  assert_file_contains "$workflow" "校驗前 jev 快篩"
  assert_file_contains "$workflow" "校驗後 jev 驗證"
  assert_file_contains "$workflow" "escalate 處理"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: workflow.md lists all 6 v2.4 jev rules" {
  local workflow="$REPO_ROOT/skills/dev-checker-loop/workflow.md"
  # Each rule keyword should appear in the v2.4 rules table
  for kw in "軟性降級" "降級為人類決策" "不取代主動校驗" "輕量路徑" "內部失敗 fallback" "M-Step 3 必跑探針"; do
    awk '/^## jev 整合細節/,EOF' "$workflow" | grep -qF "$kw" || {
      echo "FAIL: workflow.md jev rules missing keyword: $kw" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DEV-CHECKER-LOOP [B3-M-Step3]: CHANGELOG documents v2.4 jev + slim-down entry" {
  local changelog="$REPO_ROOT/skills/dev-checker-loop/CHANGELOG.md"
  assert_file_contains "$changelog" "| v2.4 |"
  assert_file_contains "$changelog" "可用性偵測"
}

@test "RESTRUCT-DEV-CHECKER-LOOP [frontmatter-mandatory]: SKILL.md has frontmatter name and description (dav-skill-creater mandatory)" {
  local skill="$REPO_ROOT/skills/dev-checker-loop/SKILL.md"
  local first_line
  first_line=$(head -1 "$skill")
  [ "$first_line" = "---" ] || {
    echo "FAIL: SKILL.md must start with frontmatter delimiter" >&2
    return 1
  }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^name: dev-checker-loop" || {
    echo "FAIL: missing frontmatter name in frontmatter block" >&2
    return 1
  }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^description:" || {
    echo "FAIL: missing frontmatter description in frontmatter block" >&2
    return 1
  }
}
