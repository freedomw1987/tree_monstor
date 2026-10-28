#!/usr/bin/env bats
#
# tests/skill-contract.bats — dav-developer 結構契約探針
#
# 為什麼有呢支：2026-10-27 合併 + 拆分之後，`dav-developer` 嘅「界線」靠文件守住，
# 但冇機械探針 → 有人將 Jev Oracle 內容又塞返入去、或者指標指住唔存在嘅子檔，都唔會有人知。
# → 呢支探針守住「結構契約」：4 段導航、核心規則、指標可達、跨 skill 邊界。
#
# ⚠️ **行數上限唔喺呢度守**：2026-10-28 v2.11 減法版起，行數上限（主檔 ≤50／子檔 ≤150／
# context ≤400，樣例／模板除外）由 repo 級 `tests/skill-size.bats`（SS-1..SS-3）統一守，
# 逐個 skill 目錄掃 → **避免同一條上限有兩處定義而漂移**。
#
# skill-local 探針：helper 喺 repo 級 tests/helpers/ → 用絕對路徑 load
# （bats 嘅 `load` 支援絕對路徑；相對路徑相對 BATS_TEST_DIRNAME，搬咗 skill 就搵唔到）
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
load "$REPO_ROOT/tests/helpers/test-env"

SKILL_DIR="$REPO_ROOT/skills/dav-developer"
JEV_SKILL_DIR="$REPO_ROOT/skills/dav-jev-oracle"

@test "SD-1: SKILL.md has the 4-section task navigation (TL;DR / 觸發時機 / 流程 / 規則)" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  for sec in "## TL;DR" "## 觸發時機" "## 流程" "## 規則"; do
    grep -qF "$sec" "$SKILL_DIR/SKILL.md" || {
      echo "FAIL: SKILL.md 缺少章節：$sec" >&2
      return 1
    }
  done
}

@test "SD-3: every ./ sub-file referenced by SKILL.md exists and is non-empty" {
  local rel
  while IFS= read -r rel; do
    [ -f "$SKILL_DIR/$rel" ] || {
      echo "FAIL: 指標指向唔存在嘅子檔：./$rel" >&2
      return 1
    }
    [ -s "$SKILL_DIR/$rel" ] || {
      echo "FAIL: 子檔係空嘅：./$rel" >&2
      return 1
    }
  done < <(grep -oE '\./[A-Za-z0-9._/-]+\.md' "$SKILL_DIR/SKILL.md" | sed 's|^\./||' | sort -u)
}

@test "SD-4: the four execution steps are present and in order" {
  local order
  # ⚠️ 用行首錨定（唔係 greedy `.*Step N`）：Step 嘅描述句入面可能再出現「Step 2」等字樣
  #    （例：「有問題返 Step 2 修」）→ greedy 會捉錯位，變成假紅。
  order="$(grep -oE '^### Step [0-9]' "$SKILL_DIR/SKILL.md" | sed 's/^### Step //' | tr '\n' ' ')"
  [ "$order" = "1 2 3 4 " ] || {
    echo "FAIL: Step 順序唔對（期望 1 2 3 4）：$order" >&2
    return 1
  }
  # Step 標題數一定要啱 4（否則「### Step notes」呢類非數字標題會被靜靜哋 ignore）
  local n
  n="$(grep -cE '^### Step ' "$SKILL_DIR/SKILL.md")"
  [ "$n" -eq 4 ] || {
    echo "FAIL: SKILL.md 有 $n 個 Step 標題（應為 4）" >&2
    return 1
  }
}

@test "SD-5: Jev Oracle belongs to dav-jev-oracle, not to dav-developer" {
  # 跨 skill 邊界：Jev Oracle 係可選加深，內容歸 dav-jev-oracle
  grep -qF "dav-jev-oracle" "$SKILL_DIR/SKILL.md" || {
    echo "FAIL: dav-developer/SKILL.md 應指標去 dav-jev-oracle（可選加深）" >&2
    return 1
  }
  if grep -qE '\./(jev-oracle|examples|api-contract|output-format)\.md' "$SKILL_DIR/SKILL.md"; then
    echo "FAIL: dav-developer/SKILL.md 仲指標住已搬走嘅 Jev 相關子檔" >&2
    return 1
  fi
  [ -f "$JEV_SKILL_DIR/SKILL.md" ] || {
    echo "FAIL: 缺 skills/dav-jev-oracle/SKILL.md" >&2
    return 1
  }
}

@test "SD-6: dav-jev-oracle is self-contained (PoC + its own probes)" {
  [ -d "$JEV_SKILL_DIR/PoC" ] || {
    echo "FAIL: dav-jev-oracle 缺 PoC/（要自足）" >&2
    return 1
  }
  [ -d "$JEV_SKILL_DIR/tests" ] || {
    echo "FAIL: dav-jev-oracle 缺 tests/（探針要跟 skill 走）" >&2
    return 1
  }
  [ -f "$JEV_SKILL_DIR/PoC/run_ci.sh" ] || {
    echo "FAIL: 缺 PoC/run_ci.sh（本機 CI runner）" >&2
    return 1
  }
}

@test "SD-7: the four gates are declared in ./gates.md (主檔只留指標)" {
  # ⚠️ 2026-10-28 v2.11 減法版：Gate 定義由主檔搬去 ./gates.md（主檔 ≤ 50 行嘅硬上限）。
  #    → 呢條探針要跟住搬，否則「主檔出現過 Gate 1..4 字串」會變成假綠、Gate 定義零機械保護。
  local gates="$SKILL_DIR/gates.md"
  [ -f "$gates" ] || {
    echo "FAIL: 缺 ${gates}（Gate 定義嘅單一真相）" >&2
    return 1
  }
  python3 - "$gates" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
sections = re.split(r"^## ", text, flags=re.M)
need = ["pass_criteria", "required_evidence", "fail_action", "mandatory_phrase"]
bad = []
for g in ("Gate 1", "Gate 2", "Gate 3", "Gate 4"):
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
  # 「不引用 mandatory_phrase = 視為 gate 未觸發」呢句係硬規則，唔准喺搬運時漏咗
  assert_file_contains "$gates" "視為 gate 未觸發"
  # 主檔要指標去 gates.md（指標唔可以靜靜哋消失）
  assert_file_contains "$SKILL_DIR/SKILL.md" "./gates.md"
}
