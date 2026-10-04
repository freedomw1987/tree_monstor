#!/usr/bin/env bats
#
# tests/dav-planner-user-background.bats
#
# Regression guards for dav-planner "user background collection" (v1.9 §2.7).
#
# ⚠️ v2.1 起該功能已由用戶決策**廢除**（理由：對話用戶角色對後續開發無實質幫助，
# 反引導用戶進入「搞不清自己要什麼」的狀態；見 skills/dav-planner/CHANGELOG.md v2.1）。
# 因此本檔由「守著 §2.7 存在」改成「**廢棄守門**」：
#   1. §2.7 章節不得靜默回流（負向斷言）
#   2. 但「為什麼廢除」的定位句必須留著，避免後人誤以為漏寫而補回
#   3. 廢除紀錄（本地 + 全域 CHANGELOG）必須留著
#
# Gate 1 (TDD): 先確認新守門為綠（現狀成立）→ 再以突變證明它會咬人。

load 'helpers/test-env'

# ---------------------------------------------------------------------------
# Deprecation guards（取代原本 4 條「§2.7 存在」探針）
# ---------------------------------------------------------------------------

@test "DEPRECATED: dav-planner must not re-introduce section 2.7 user background" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  local ref="$REPO_ROOT/skills/dav-planner/reference.md"
  # 正向錨定（reviewer P2-1）：否則檔案被刪/改名時，下方 refute 會因 grep rc=2 而「安靜地綠」
  assert_file_contains "$ref" "### 核心 4 維度（必問）"
  # 主題級負向斷言（reviewer P2-2）：不用 §2.7 編號——reference.md 的 §2.1–§2.6 序列未來
  # 合法長出 §2.7（與已廢功能無關）時不應誤紅
  for target in "$skill" "$ref"; do
    # TMO-032（reviewer P2-b）：body-only（排除 `^| v` 變動歷史列，避免政策誤紅）
    refute_file_body_contains "$target" "用戶背景收集"
    refute_file_body_contains "$target" "角色詢問"
  done
  # TMO-032（M11 缺口）：同義詞改詞回流 best-effort
  for syn in "使用者背景" "自我介紹" "你的角色是" "您的角色"; do
    for target in "$skill" "$ref"; do
      refute_file_body_contains "$target" "$syn"
    done
  done
  # 「為什麼廢除」的定位句必須留著（防後人「補回缺失章節」）
  assert_file_contains "$skill" "不問對話用戶的個人角色"
  assert_file_contains "$skill" "§3 Persona"
}

@test "DEPRECATED: role-to-followup mapping must not return (PM/PO)" {
  local ref="$REPO_ROOT/skills/dav-planner/reference.md"
  local rules="$REPO_ROOT/skills/dav-planner/backlog-rules.md"
  refute_file_contains "$ref" "PM/PO"
  refute_file_contains "$rules" "PM/PO"
  refute_file_contains "$ref" "角色詢問"
}

@test "DEPRECATED: retirement of v1.9 section 2.7 is recorded (local + global)" {
  local cl="$REPO_ROOT/skills/dav-planner/CHANGELOG.md"
  local gcl="$REPO_ROOT/docs/sop/handbook/changelog.md"
  # TMO-032：列級錨定（原本 whole-file grep，任何一列寫到這句就算過）
  if ! grep -F '| v1.9 |' "$cl" | grep -qF '已被 v2.1 撤銷'; then
    echo "FAIL: $cl v1.9 row must record 已被 v2.1 撤銷" >&2
    return 1
  fi
  # 列級錨定（whole-file grep 會被 v2.2 列的「已廢棄」蒙混過關）
  if ! grep -F '| v1.9 |' "$cl" | grep -qF '已廢棄'; then
    echo "FAIL: $cl v1.9 row must be annotated 已廢棄" >&2
    return 1
  fi
  if ! grep -F '| v2.1 |' "$cl" | grep -qF -- '-§2.7 用戶背景收集整套'; then
    echo "FAIL: $cl v2.1 row must record the retirement (-§2.7 用戶背景收集整套)" >&2
    return 1
  fi
  assert_file_contains "$gcl" "刪除 §2.7 整套"
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
