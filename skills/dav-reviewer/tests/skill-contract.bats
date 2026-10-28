#!/usr/bin/env bats
#
# skills/dav-reviewer/tests/skill-contract.bats —— dav-reviewer 結構契約探針
#
# 為什麼有呢支：2026-10-28 起，Gate 4（品質審核）＋ Gate 4.5（需求對帳）由本 skill 承載，
# 而且**人手觸發**（§2.3 自動執行段只做 Gate 1/2/3 → 拆出嚟加快 dav-developer）。
# 呢兩道 Gate 嘅定義（pass_criteria／required_evidence／fail_action／mandatory_phrase）
# 係全 repo 最敏感嘅規則語意 → 一旦搬運／改寫時漏咗欄位，就會變成「冇人守」嘅假綠。
#
# skill-local 探針：helper 喺 repo 級 tests/helpers/ → 用絕對路徑 load
# （bats 嘅 `load` 支援絕對路徑；相對路徑相對 BATS_TEST_DIRNAME，搬咗 skill 就搵唔到）
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME" && git rev-parse --show-toplevel)"
load "$REPO_ROOT/tests/helpers/test-env"

SKILL_DIR="$REPO_ROOT/skills/dav-reviewer"
GATES="$SKILL_DIR/gates.md"

@test "RV-1: SKILL.md has the 4-section task navigation (TL;DR / 觸發時機 / 流程 / 規則)" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  for sec in "## TL;DR" "## 觸發時機" "## 流程" "## 規則"; do
    grep -qF "$sec" "$SKILL_DIR/SKILL.md" || {
      echo "FAIL: SKILL.md 缺少章節：${sec}" >&2
      return 1
    }
  done
}

@test "RV-2: every ./ sub-file referenced by SKILL.md exists and is non-empty" {
  local rel
  while IFS= read -r rel; do
    [ -f "$SKILL_DIR/$rel" ] || {
      echo "FAIL: 指標指向唔存在嘅子檔：./${rel}" >&2
      return 1
    }
    [ -s "$SKILL_DIR/$rel" ] || {
      echo "FAIL: 子檔係空嘅：./${rel}" >&2
      return 1
    }
  done < <(grep -oE '\./[A-Za-z0-9._/-]+\.md' "$SKILL_DIR/SKILL.md" | sed 's|^\./||' | sort -u)
}

@test "RV-3: SKILL.md stays within the 50-line hard cap (主檔只留指標)" {
  local lines
  lines="$(wc -l < "$SKILL_DIR/SKILL.md")"
  [ "$lines" -le 50 ] || {
    echo "FAIL: dav-reviewer/SKILL.md 有 ${lines} 行（上限 50）→ 內容搬去支援子檔" >&2
    return 1
  }
}

@test "RV-4: Gate 4 and Gate 4.5 both declare the four contract fields" {
  [ -f "$GATES" ] || {
    echo "FAIL: 缺 ${GATES}（Gate 定義嘅單一真相）" >&2
    return 1
  }
  python3 - "$GATES" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
sections = re.split(r"^## ", text, flags=re.M)
need = ["pass_criteria", "required_evidence", "fail_action", "mandatory_phrase"]
bad = []
for g in ("Gate 4 reviewer gate", "Gate 4.5 需求對帳"):
    body = next((s for s in sections if s.startswith(g)), None)
    if body is None:
        bad.append(f"{g} 缺段落")
        continue
    for f in need:
        if f"**{f}**" not in body:
            bad.append(f"{g} 缺 {f}")
if bad:
    print(f"FAIL: {path} → {'; '.join(bad)}", file=sys.stderr)
    sys.exit(1)
PYEOF
  [ "$?" -eq 0 ] || return 1
  # 「不引用 mandatory_phrase = 視為 gate 未觸發」呢句係硬規則，唔准喺搬運／改寫時漏咗
  assert_file_contains "$GATES" "視為 gate 未觸發"
}

@test "RV-5: both gates are declared as 人手觸發 (唔喺 §2.3 自動執行段內)" {
  assert_file_contains "$SKILL_DIR/SKILL.md" "人手觸發"
  assert_file_contains "$GATES" "人手觸發"
  # 機器可讀副本：gate-4 嘅 trigger_skill 必須係 dav-reviewer
  python3 - "$REPO_ROOT/docs/sop/gates.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
gates = {g["id"]: g for g in d["gates"]}
g4 = gates.get("gate-4")
if g4 is None:
    print("FAIL: gates.json 冇 gate-4", file=sys.stderr); sys.exit(1)
if g4.get("trigger_skill") != "dav-reviewer":
    print(f"FAIL: gates.json 嘅 gate-4 trigger_skill = {g4.get('trigger_skill')!r}（應為 dav-reviewer）", file=sys.stderr)
    sys.exit(1)
if "gate-4.5" in gates:
    print("FAIL: gates.json 唔可以有 gate-4.5（內嵌子閘，受 schema 限制）", file=sys.stderr); sys.exit(1)
PYEOF
  [ "$?" -eq 0 ] || return 1
}

@test "RV-6: the review flow and the reconcile flow both have their own file" {
  # 一次 review pass 出兩樣嘢（品質 verdict ＋ 對帳表）→ 兩條流程各自有子檔，唔可以合埋成一個而漏咗其中一條
  assert_file_contains "$SKILL_DIR/review.md" "Gate 4"
  assert_file_contains "$SKILL_DIR/workflow.md" "Gate 4.5"
  assert_file_contains "$SKILL_DIR/SKILL.md" "./review.md"
  assert_file_contains "$SKILL_DIR/SKILL.md" "./workflow.md"
  # 對帳表格式 ＋ 範本
  assert_file_contains "$SKILL_DIR/reconcile-format.md" "需求對帳表"
  assert_file_contains "$SKILL_DIR/templates/reconcile-table.md" "需求對帳表"
}

@test "RV-7: dav-developer no longer owns Gate 4 (拆出去咗，唔准兩處定義)" {
  local dev_gates="$REPO_ROOT/skills/dav-developer/gates.md"
  [ -f "$dev_gates" ] || {
    echo "FAIL: 缺 ${dev_gates}" >&2
    return 1
  }
  if grep -qE '^## Gate 4 ' "$dev_gates"; then
    echo "FAIL: ${dev_gates} 仲有 Gate 4 定義 → Gate 4 屬 dav-reviewer skill" >&2
    return 1
  fi
  # dav-developer 主檔要指標去 dav-reviewer（交接唔可以靜靜哋斷）
  assert_file_contains "$REPO_ROOT/skills/dav-developer/SKILL.md" "dav-reviewer"
}

@test "RV-8: no residual text anywhere still says dav-developer owns Gate 4" {
  # 防殘留：拆走 Gate 4 之後，repo 其他地方仲可能留住「Gate 1/2/3/4 全部由 dav-developer 承載」呢類舊描述
  # → agent 讀到會以為審核仍然喺 dav-developer 自動做（今次改動嘅目標就係唔要咁）。
  # （歷史檔 —— 交付摘要／需求錨點／對帳表 —— 係 append-only 記錄，唔喺呢個範圍。）
  local pat='Gate 1/2/3/4|Gate 1-4|Gate 1–4|gate-4 → `?dav-developer'
  local hit
  hit="$(grep -rInE "$pat" \
    "$REPO_ROOT/skills" "$REPO_ROOT/docs/sop" "$REPO_ROOT/docs/ci" \
    "$REPO_ROOT/README.md" "$REPO_ROOT/AGENTS.md" "$REPO_ROOT/CONTRIBUTING.md" \
    2>/dev/null | grep -v "/tests/" || true)"
  [ -z "$hit" ] || {
    echo "FAIL: 仲有殘留「dav-developer 承載 Gate 4」嘅描述：" >&2
    echo "$hit" >&2
    return 1
  }
}

@test "RV-9: the delivery rule (更新受影響文檔 ＋ docs/backlog.md) is locked in two places" {
  # 反向實測發現：刪走 SKILL.md 同 deliver.md 兩處嘅呢條規則，全部探針照樣全綠 → 零機械保護。
  # → 呢度補上雙重鎖：主檔規則表 ＋ deliver.md 嘅 Step 5 段 ＋ 交付模板嘅記錄位。
  assert_file_contains "$SKILL_DIR/SKILL.md" "更新受影響文檔"
  assert_file_contains "$SKILL_DIR/SKILL.md" "docs/backlog.md"
  assert_file_contains "$SKILL_DIR/deliver.md" "更新受影響文檔"
  assert_file_contains "$SKILL_DIR/deliver.md" "docs/backlog.md"
  grep -qE '^## §2 Step 5：更新受影響文檔' "$SKILL_DIR/deliver.md" || {
    echo "FAIL: deliver.md 缺少 §2 Step 5 段（交付時更新受影響文檔 ＋ docs/backlog.md）" >&2
    return 1
  }
  # 交付摘要模板要有記錄位（規則要有落腳位，唔可以只喺正文講）
  assert_file_contains "$SKILL_DIR/templates/deliverable-template.md" "本次更新咗邊啲文件"
}
