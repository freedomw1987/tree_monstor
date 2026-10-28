#!/usr/bin/env bats
#
# tests/skill-contract.bats — dav-developer 結構契約探針
#
# 為什麼有呢支：2026-10-27 合併 + 拆分之後，`dav-developer` 嘅「界線」靠文件守住，
# 但冇機械探針 → 有人將 Jev Oracle 內容又塞返入去、或者指標指住唔存在嘅子檔，都唔會有人知。
# → 呢支探針守住「結構契約」：4 段導航、核心規則、指標可達、行數上限、跨 skill 邊界。
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

@test "SD-2: SKILL.md stays within the 150-line hard cap" {
  local lines
  lines="$(wc -l < "$SKILL_DIR/SKILL.md")"
  [ "$lines" -le 150 ] || {
    echo "FAIL: dav-developer/SKILL.md 有 $lines 行（上限 150）→ 要拆子檔" >&2
    return 1
  }
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
  done < <(grep -oE '\./[A-Za-z0-9._-]+\.md' "$SKILL_DIR/SKILL.md" | sed 's|^\./||' | sort -u)
}

@test "SD-4: the four execution steps are present and in order" {
  local order
  order="$(grep -nE '^### Step ' "$SKILL_DIR/SKILL.md" | sed 's/.*Step \([0-9]\).*/\1/' | tr '\n' ' ')"
  [ "$order" = "1 2 3 4 " ] || {
    echo "FAIL: Step 順序唔對（期望 1 2 3 4）：$order" >&2
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

@test "SD-7: the four gates are all declared in dav-developer/SKILL.md" {
  for g in "Gate 1" "Gate 2" "Gate 3" "Gate 4"; do
    grep -qF "$g" "$SKILL_DIR/SKILL.md" || {
      echo "FAIL: SKILL.md 缺少 $g 定義" >&2
      return 1
    }
  done
}
