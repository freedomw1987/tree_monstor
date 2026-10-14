#!/usr/bin/env bats
#
# tests/restruct-pptx-slim.bats
#
# pptx-slim 的結構探針：守住「任務導航」5 段結構（dav-skill-creater v2.1/v2.2 規範）
# 與「流程裡真的指向存在的腳本」的錨點，避免結構被掏空成只剩標題。

load 'helpers/test-env'

skill_file() {
  echo "$REPO_ROOT/skills/pptx-slim/SKILL.md"
}

section() {
  awk -v want="$1" '$0 == want {flag=1; next} /^## /{flag=0} flag' "$(skill_file)"
}

@test "RESTRUCT-PPTX-SLIM: frontmatter has name + description" {
  local skill
  skill=$(skill_file)
  assert_file_contains "$skill" "name: pptx-slim"
  assert_file_contains "$skill" "description:"
}

@test "RESTRUCT-PPTX-SLIM: TL;DR section exists with 5 bullets" {
  local skill
  skill=$(skill_file)
  assert_file_contains "$skill" "## TL;DR"
  local n
  n=$(section "## TL;DR" | grep -cE '^[0-9]+\. ')
  [ "$n" -ge 5 ] || { echo "FAIL: TL;DR 只有 $n 條（< 5）" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: trigger section marks both trigger and non-trigger" {
  local trig
  trig=$(section "## 觸發時機")
  echo "$trig" | grep -qF "✅" || { echo "FAIL: 缺正向觸發" >&2; return 1; }
  echo "$trig" | grep -qE "❌|不觸發" || { echo "FAIL: 缺非觸發（❌）" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: flow section keeps the 4 anchors" {
  local flow
  flow=$(section "## 流程（7 步）")
  [ -n "$flow" ] || { echo "FAIL: 找不到流程段落" >&2; return 1; }
  local token
  for token in "動作" "為什麼" "產出" "證據"; do
    echo "$flow" | grep -qF "$token" || { echo "FAIL: 流程缺 '$token'" >&2; return 1; }
  done
}

@test "RESTRUCT-PPTX-SLIM: rules table keeps rule/exception/limit columns" {
  local rules
  rules=$(section "## 規則 / 例外 / 限制")
  [ -n "$rules" ] || { echo "FAIL: 找不到規則段落" >&2; return 1; }
  echo "$rules" | grep -qF "| 規則 | 例外 | 限制 |" || {
    echo "FAIL: 規則表不是 規則/例外/限制 三欄" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: 流程提到的 5 支腳本真的存在且可執行（TMO-064 加圖片那支）" {
  local skill scripts n=0 name
  skill=$(skill_file)
  scripts="$REPO_ROOT/skills/pptx-slim/scripts"
  for name in pptx-probe.py pptx-shrink-media.py pptx-shrink-images.py pptx-repack.py pptx-verify.py; do
    grep -qF "$name" "$skill" || { echo "FAIL: SKILL.md 沒提到 $name" >&2; return 1; }
    [ -x "$scripts/$name" ] || { echo "FAIL: $name 不存在或不可執行" >&2; return 1; }
    n=$((n + 1))
  done
  [ "$n" -eq 5 ] || { echo "FAIL: 只驗到 $n 支腳本" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: 變動歷史存在，且完整歷史外移到同目錄 CHANGELOG.md" {
  local skill
  skill=$(skill_file)
  assert_file_contains "$skill" "## 變動歷史"
  assert_file_contains "$skill" "CHANGELOG.md"
  [ -f "$REPO_ROOT/skills/pptx-slim/CHANGELOG.md" ] || {
    echo "FAIL: 缺 skills/pptx-slim/CHANGELOG.md" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: no cross-dir markdown link in SKILL.md" {
  local skill hits
  skill=$(skill_file)
  # 同目錄子檔（./CHANGELOG.md）允許；指到目錄外的相對路徑一律不允許
  hits=$(grep -nE '\]\((\.\./|/|[a-z-]+/)' "$skill" || true)
  [ -z "$hits" ] || { echo "FAIL: 出現跨目錄 markdown 連結：" >&2; echo "$hits" >&2; return 1; }
}

@test "RESTRUCT-PPTX-SLIM: SKILL.md 行數 <= 130（150 硬上限的預警線）" {
  local lines
  lines=$(wc -l < "$(skill_file)" | tr -d ' ')
  [ "$lines" -le 130 ] || {
    echo "FAIL: SKILL.md $lines 行（> 130）→ 請把細節移子檔" >&2; return 1; }
}
