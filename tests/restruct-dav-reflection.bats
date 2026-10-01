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

# ---------------------------------------------------------------------------
# v2.1 jev integration probes
# ---------------------------------------------------------------------------

@test "RESTRUCT-DAV-REFLECTION [B3-M-Step3]: Step 1 mentions v2.1 jev availability probe" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "Step 1：確認反省範圍"
  assert_file_contains "$skill" "v2.1 新增 — jev 可用性偵測"
  assert_file_contains "$skill" "which jev-use"
}

@test "RESTRUCT-DAV-REFLECTION [B2-TermAlign]: Step 2 has jev per-dimension scoring (score type only)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "Step 2：檢查 6 維度"
  assert_file_contains "$skill" "v2.1 新增 — jev 逐維度打分"
  assert_file_contains "$skill" "僅 score 類型"
}

@test "RESTRUCT-DAV-REFLECTION [B3-M-Step3]: Step 2 has reflection-result jev verification (noul)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "v2.1 新增 — 反思結果驗證"
  assert_file_contains "$skill" "noul"
}

@test "RESTRUCT-DAV-REFLECTION [S1-EscalateLanding]: escalate landing point is deliverable.md (NOT checklist.md)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  # The rule text must point at deliverable.md `## 反思` 清單, not checklist.md
  assert_file_contains "$skill" "deliverable.md"
  assert_file_contains "$skill" "## 反思"
  # And the rule must explicitly forbid writing escalate into checklist.md
  grep -qF "不寫在 checklist.md" "$skill" || {
    echo "FAIL: rule should forbid writing escalate into checklist.md" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-REFLECTION [S2-LightPath]: US-level lightweight path (only 2 critical dimensions)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "US 級別 jev 只打 2 維度"
  assert_file_contains "$skill" "需求對齊"
  assert_file_contains "$skill" "測試覆蓋率"
}

@test "RESTRUCT-DAV-REFLECTION [S3-InternalFail]: jev internal failure fallback (S3)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  assert_file_contains "$skill" "v2.1 內部失敗 fallback"
  assert_file_contains "$skill" "不 fail-fast"
}

@test "RESTRUCT-DAV-REFLECTION [B3-M-Step3]: rules table includes all 6 v2.1 jev rules" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  for kw in "jev 軟性降級" "jev escalate 降級為人類決策" "jev 不取代 LLM 評分" "US 級別 jev 只打 2 維度" "jev 內部失敗 fallback" "M-Step 3 必跑探針"; do
    awk '/^## 規則/,/^## [^規]/' "$skill" | grep -qF "$kw" || {
      echo "FAIL: rules table missing v2.1 rule: $kw" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DAV-REFLECTION [B2-TermAlign]: checklist.md has jev-judge mapping table (section 7)" {
  local checklist="$REPO_ROOT/skills/dav-reflection/checklist.md"
  assert_file_contains "$checklist" "## 7. jev_judge 對接表"
  assert_file_contains "$checklist" "score 類型"
  # 6 dimensions should be present in the mapping table
  for dim in "UX/UI 一致性" "RWD 響應式設計" "技術債" "可維護性" "測試覆蓋率" "需求對齊"; do
    grep -qF "$dim" "$checklist" || {
      echo "FAIL: jev mapping table missing dimension: $dim" >&2
      return 1
    }
  done
}

@test "RESTRUCT-DAV-REFLECTION [B3-M-Step3]: CHANGELOG documents v2.1 jev integration" {
  local changelog="$REPO_ROOT/skills/dav-reflection/CHANGELOG.md"
  assert_file_contains "$changelog" "| v2.1 |"
  assert_file_contains "$changelog" "可用性偵測"
  assert_file_contains "$changelog" "score 類型"
}

@test "RESTRUCT-DAV-REFLECTION [frontmatter-mandatory]: SKILL.md has frontmatter name and description" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  local first_line
  first_line=$(head -1 "$skill")
  [ "$first_line" = "---" ] || {
    echo "FAIL: SKILL.md must start with frontmatter delimiter" >&2
    return 1
  }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^name: dav-reflection" || {
    echo "FAIL: missing frontmatter name in frontmatter block" >&2
    return 1
  }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^description:" || {
    echo "FAIL: missing frontmatter description in frontmatter block" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-REFLECTION [B1-LineGuard]: SKILL.md file size sanity (target < 150)" {
  local skill="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  local lines
  lines=$(wc -l < "$skill")
  [ "$lines" -lt 150 ] || {
    echo "FAIL: skill grew too large ($lines lines, target < 150)" >&2
    return 1
  }
}
