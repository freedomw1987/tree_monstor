#!/usr/bin/env bats
#
# tests/restruct-dav-trust.bats
#
# Regression guards for TMO-009 stage 4: dav-trust
# restructured to "task-navigation" style.

load 'helpers/test-env'

@test "RESTRUCT-DAV-TRUST: TL;DR section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## TL;DR"
}

@test "RESTRUCT-DAV-TRUST: TL;DR mentions trust-mode exit rule" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  awk '/^## TL;DR/,/^## [^T]/' "$skill" | grep -qiF "退出" || {
    echo "FAIL: TL;DR should mention trust-mode exit" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: trigger section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## 觸發時機"
}

@test "RESTRUCT-DAV-TRUST: trigger mentions deadline + large goal" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # Extract trigger section (robust to Unicode headings)
  local trigger_section
  trigger_section=$(awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag' "$skill")
  echo "$trigger_section" | grep -qF "Deadline" || {
    echo "FAIL: trigger section should mention Deadline" >&2
    return 1
  }
  echo "$trigger_section" | grep -qF "大目標" || {
    echo "FAIL: trigger section should mention 大目標" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: rules section exists" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "## 規則"
}

@test "RESTRUCT-DAV-TRUST: change history references current version" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  local cl="$REPO_ROOT/skills/dav-trust/CHANGELOG.md"
  assert_file_contains "$skill" "## 變動歷史"
  # 主檔最新版本列須與 CHANGELOG.md 首列一致（防版本漂移；同 dav-wiki / dav-planner）
  local v_skill v_cl
  v_skill=$(awk '/^## 變動歷史/{flag=1} flag' "$skill" | grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | tr -d '| ')
  v_cl=$(grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)?' "$cl" | head -1 | tr -d '| ')
  [ -n "$v_skill" ] && [ "$v_skill" = "$v_cl" ] || {
    echo "FAIL: 主檔最新版本($v_skill) 與 CHANGELOG($v_cl) 不一致" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: no ASCII box-drawing flow diagrams" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  if grep -qE '├─|└─|┌─' "$skill"; then
    echo "FAIL: skill still has ASCII box-drawing" >&2
    return 1
  fi
}

@test "RESTRUCT-DAV-TRUST: trust SOP path excludes planning/design stages" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # trust = 執行模式：SOP 路徑不得含 dav-planner / dav-designer（兩者需用戶互動）
  local path_line
  path_line=$(grep -m1 -F "預設 SOP 路徑" "$skill")
  if [ -z "$path_line" ]; then
    echo "FAIL: could not find 預設 SOP 路徑 line" >&2
    return 1
  fi
  if echo "$path_line" | grep -qF "dav-planner"; then
    echo "FAIL: trust SOP path must not include planning stage (dav-planner)" >&2
    return 1
  fi
  if echo "$path_line" | grep -qF "dav-designer"; then
    echo "FAIL: trust SOP path must not include design stage (dav-designer)" >&2
    return 1
  fi
  echo "$path_line" | grep -qF "執行" || {
    echo "FAIL: trust SOP path should include execution stage" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: Step 2 declares preconditions" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "前置條件"
  assert_file_contains "$skill" "執行期最小設計"
}

@test "RESTRUCT-DAV-TRUST: rule forbids planning/design inside trust" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "規劃 / 設計階段不得在 trust 內執行"
}

@test "RESTRUCT-DAV-TRUST: design-gap rule limits to minimal technical contract" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "最小技術契約"
}

@test "RESTRUCT-DAV-TRUST: no residual 5-stage path statements" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # 只排除「變動歷史章節內的版本列」（| vX.Y），其餘全掃（含交叉引用區、frontmatter、章節標題）
  # 註：不用 `grep -v -E '^\| v'`（該寫法會讓全檔任何 | v 開頭列靜默豁免，repo 已判為反模式）
  local body
  body=$(awk '/^## 變動歷史/{f=1;next} /^## /{f=0} f && /^\| v[0-9]/{next} {print}' "$skill")
  local needle
  for needle in "5 階段" "SOP 5 階段" "規劃→設計→執行" "規劃 → 設計 → 執行"; do
    if echo "$body" | grep -qF -- "$needle"; then
      echo "FAIL: SKILL.md body must NOT contain: $needle" >&2
      return 1
    fi
  done
  # 子檔同步守門（第 1 輪 examples.md:109 同類殘留即漏網）
  local f
  for f in examples.md time-anchor.md preflight.md; do
    local sub="$REPO_ROOT/skills/dav-trust/$f"
    local subbody
    subbody=$(awk '/^## 變動歷史/{f=1;next} /^## /{f=0} f && /^\| v[0-9]/{next} {print}' "$sub")
    local n2
    for n2 in "5 階段" "SOP 5 階段" "規劃→設計→執行" "規劃 → 設計 → 執行"; do
      if echo "$subbody" | grep -qF -- "$n2"; then
        echo "FAIL: $f must NOT contain: $n2" >&2
        return 1
      fi
    done
  done
  # README 的 dav-trust 列（只針對 dav-trust 行：README §2.1-§2.5 是全域 SOP 流程、本就含規劃 → 設計）
  local readme="$REPO_ROOT/README.md"
  if grep -F 'dav-trust' "$readme" | grep -qF '5 階段'; then
    echo "FAIL: README.md dav-trust row must NOT contain: 5 階段" >&2
    return 1
  fi
  return 0
}

@test "RESTRUCT-DAV-TRUST: preflight 3.2 offers no agent-side bypass" {
  # 第 3 輪 P1-1：話術若重新提供「可先用最小技術契約啟動」→ 全缺設計又能繞過拒絕啟動
  local pf="$REPO_ROOT/skills/dav-trust/preflight.md"
  local s32
  s32=$(awk '/^### 3\.2/{f=1} /^## /{f=0} f' "$pf")
  echo "$s32" | grep -qF "沒有繞道" || {
    echo "FAIL: preflight 3.2 should state there is no agent-side bypass" >&2; return 1; }
  if echo "$s32" | grep -qF -- "先做最小技術契約就啟動"; then
    echo "FAIL: preflight 3.2 must NOT offer 'minimal contract then start' bypass" >&2
    return 1
  fi
  if echo "$s32" | grep -qF -- "也可啟動"; then
    echo "FAIL: preflight 3.2 must NOT allow starting when design is entirely missing" >&2
    return 1
  fi
  # 覆核契約三條 + 先告知風險（否則契約可無聲蒸發）
  local c
  for c in "必須先輸出 §3.2 話術告知風險" "用戶覆核：設計全缺啟動" "逐 US" "只影響本次啟動"; do
    echo "$s32" | grep -qF -- "$c" || {
      echo "FAIL: preflight 3.2 missing override-contract clause: $c" >&2; return 1; }
  done
  return 0
}

@test "RESTRUCT-DAV-TRUST: Step 1 distinguishes ask-once vs refuse-to-start" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  local s1
  s1=$(awk '/^### Step 1/{f=1} /^### Step 2/{f=0} f' "$skill")
  echo "$s1" | grep -qF "問一次" || {
    echo "FAIL: Step 1 should allow asking once for a missing deadline" >&2; return 1; }
  echo "$s1" | grep -qF "拒絕啟動" || {
    echo "FAIL: Step 1 should refuse to start when backlog/design missing" >&2; return 1; }
  return 0
}

@test "RESTRUCT-DAV-TRUST: preflight.md is tracked by git" {
  # 只驗檔案存在會讓「未追蹤」靜默通過（第 1 輪 P0-1 成因）
  git -C "$REPO_ROOT" ls-files --error-unmatch skills/dav-trust/preflight.md >/dev/null 2>&1 || {
    echo "FAIL: skills/dav-trust/preflight.md must be tracked by git" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-TRUST: Step 2 section declares preconditions (in-section)" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  local s2
  s2=$(awk '/^### Step 2/{f=1} /^### Step 3/{f=0} f' "$skill")
  echo "$s2" | grep -qF "前置條件" || {
    echo "FAIL: Step 2 missing 前置條件" >&2; return 1; }
  echo "$s2" | grep -qF "執行期最小設計" || {
    echo "FAIL: Step 2 missing 執行期最小設計" >&2; return 1; }
  echo "$s2" | grep -qF "dav-planner" && {
    echo "FAIL: Step 2 must not run dav-planner" >&2; return 1; }
  echo "$s2" | grep -qF "dav-designer" && {
    echo "FAIL: Step 2 must not run dav-designer" >&2; return 1; }
  return 0
}

@test "RESTRUCT-DAV-TRUST: design-gap boundary forbids prototype/signoff" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "不產互動原型"
  assert_file_contains "$skill" "不等簽核"
}

@test "RESTRUCT-DAV-TRUST: preflight content guards" {
  local pf="$REPO_ROOT/skills/dav-trust/preflight.md"
  assert_file_contains "$pf" "拒絕啟動"
  assert_file_contains "$pf" "最小技術契約"
  assert_file_contains "$pf" "互動原型"
}

@test "RESTRUCT-DAV-TRUST: change history keeps at most 3 entries (v2.4 外移規範)" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  local n
  n=$(awk '/^## 變動歷史/{f=1;next} /^## /{f=0} f && /^\| v[0-9]/' "$skill" | wc -l | tr -d ' ')
  [ "$n" -le 3 ] || {
    echo "FAIL: 變動歷史 has $n entries (>3)" >&2; return 1; }
}

@test "RESTRUCT-DAV-TRUST: preflight subfile exists" {
  assert_path_is_file "$REPO_ROOT/skills/dav-trust/preflight.md"
}

@test "RESTRUCT-DAV-TRUST: trust-log SOP preserved" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "docs/trust-log.md"
}

@test "RESTRUCT-DAV-TRUST: need-you-help.md rule preserved" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  assert_file_contains "$skill" "need-you-help.md"
}

@test "RESTRUCT-DAV-TRUST: end-of-trust rule preserved (§9 equivalent)" {
  local skill="$REPO_ROOT/skills/dav-trust/SKILL.md"
  # v2.0: any of "退出 trust", "Trust Mode 已結束", "退出 Trust Mode"
  if grep -qF "退出 trust" "$skill"; then return 0; fi
  if grep -qF "Trust Mode 已結束" "$skill"; then return 0; fi
  if grep -qF "退出 Trust Mode" "$skill"; then return 0; fi
  echo "FAIL: should document Trust Mode exit phrase" >&2
  return 1
}
