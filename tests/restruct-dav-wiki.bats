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
  local cl="$REPO_ROOT/skills/dav-wiki/CHANGELOG.md"
  assert_file_contains "$skill" "## 變動歷史"
  awk '/^## 變動歷史/,EOF' "$skill" | grep -qE "v2\.0" || {
    echo "FAIL: 變動歷史 should reference v2.0" >&2
    return 1
  }
  # 主檔最新版本列須與 CHANGELOG.md 首列一致（防版本漂移；同 dav-planner / regression-guard）
  local v_skill v_cl
  v_skill=$(awk '/^## 變動歷史/{flag=1} flag' "$skill" | grep -oE '^\| v[0-9]+\.[0-9]+' | head -1 | tr -d '| ')
  v_cl=$(grep -oE '^\| v[0-9]+\.[0-9]+' "$cl" | head -1 | tr -d '| ')
  [ -n "$v_skill" ] && [ "$v_skill" = "$v_cl" ] || {
    echo "FAIL: 主檔最新版本($v_skill) 與 CHANGELOG($v_cl) 不一致" >&2
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

@test "RESTRUCT-DAV-WIKI: subfile pointers in SKILL.md resolve (no silent loss)" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  local dir
  dir="$(dirname "$skill")"
  # 主檔所有 `./xxx.md` 指標都必須指向真實存在的子檔
  # （子檔被删/改名時不應安静變綠——TMO-026「最安静的債是沒在跑的探針」）
  local found=0 rel
  while IFS= read -r rel; do
    found=$((found + 1))
    [ -f "$dir/$rel" ] || {
      echo "FAIL: pointer target missing: skills/dav-wiki/${rel#./}" >&2
      return 1
    }
  done < <(grep -oE '\./[A-Za-z0-9._-]+\.md' "$skill" | sort -u)
  # 防空過：指標擷取失效時 found=0 也會紅
  [ "$found" -ge 4 ] || {
    echo "FAIL: expected >=4 subfile pointers, found $found" >&2
    return 1
  }
}

@test "RESTRUCT-DAV-WIKI: 子檔內容錨點（掏空即紅，TMO-033）" {
  local dir="$REPO_ROOT/skills/dav-wiki"
  # TMO-033：原本只鎖「指標指向的檔案存在」→ 子檔被掏空（只剩標題）仍綠。
  # ① 通用鎖：每個被指到的子檔都要有實質內容（非空白行 ≥ 8）
  local checked=0 rel lines
  while IFS= read -r rel; do
    local f="$dir/${rel#./}"
    lines=$(grep -c '[^[:space:]]' "$f")
    [ "$lines" -ge 8 ] || {
      echo "FAIL: skills/dav-wiki/${rel#./} 有效行僅 ${lines}（< 8）＝子檔被掏空" >&2
      return 1
    }
    checked=$((checked + 1))
  done < <(grep -oE '\./[A-Za-z0-9._-]+\.md' "$REPO_ROOT/skills/dav-wiki/SKILL.md" | sort -u)
  [ "$checked" -ge 4 ] || { echo "FAIL: 只檢查到 $checked 個子檔（擷取失效）" >&2; return 1; }

  # ② 關鍵內容鎖：被 TMO-028 拆出去的子檔，其核心產物／機制名詞必須還在
  #    錨點須為「獨立詞」（前後不得為英數/底線/連字號），否則 `--purge-x` 也會誤過
  anchor_hit() {
    local pat="${2//./\\.}"
    grep -qE "(^|[^A-Za-z0-9_-])${pat}([^A-Za-z0-9_-]|\$)" "$1"
  }
  local anchors=0 token f
  for token in '_index.json' '_tags.json' '_concepts.json' 'transcript.md'; do
    f="$dir/output-structure.md"
    anchor_hit "$f" "$token" || {
      echo "FAIL: output-structure.md 缺獨立詞 '$token'（內容漂移／掏空）" >&2; return 1; }
    anchors=$((anchors + 1))
  done
  for token in 'deprecated_at' '--older-than' '--purge'; do
    f="$dir/soft-delete.md"
    anchor_hit "$f" "$token" || {
      echo "FAIL: soft-delete.md 缺獨立詞 '$token'（內容漂移／掏空）" >&2; return 1; }
    anchors=$((anchors + 1))
  done
  [ "$anchors" -ge 7 ] || { echo "FAIL: 內容錨點只驗到 $anchors 個（< 7）＝錨點表被削弱" >&2; return 1; }
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
