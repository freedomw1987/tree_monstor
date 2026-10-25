#!/usr/bin/env bats
#
# tests/skill-frontmatter.bats
#
# 為什麼有這支：skill 的註冊／載入靠 `SKILL.md` 的 YAML frontmatter（`name` + `description`）。
# 缺了 frontmatter，skill **根本不會被載入** —— 這是產品層故障，不是「某段文字在不在」。
#
# 原本由 `tests/restruct-dav-reflection.bats` 與 `tests/restruct-dev-checker-loop.bats`
# 各守自己那一個 skill；那兩支 meta 探針已於 2026-10-26 減法刪除
# → 這裡改為 **repo 級一支**，一次涵蓋全部 `skills/*/SKILL.md`（比被刪的版本覆蓋更廣）。
#
# 反假綠（兩道）：
#   ① 掃到的 skill 數必須 >= 13 —— 掃不到就紅，不得空過。
#   ② SKILL-FM-2 用壞 fixture 證明偵測器真的會咬，且**合格 fixture 必須通過**
#      （否則偵測器變成「一律紅」的假咬，同樣沒有驗證力）。

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
}

# 回傳 0 = 合格；非 0 並印出原因 = 不合格
check_skill_frontmatter() {
  local skill="$1" dir="$2"
  [ -f "$skill" ] || { echo "FAIL: 缺 $skill"; return 1; }
  [ "$(head -1 "$skill")" = "---" ] || {
    echo "FAIL: $skill 未以 frontmatter 分隔線 '---' 開頭"; return 1; }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^name: $dir$" || {
    echo "FAIL: $skill 的 frontmatter 缺 'name: $dir'（skill 不會被載入）"; return 1; }
  awk '/^---$/{n++; next} n==1' "$skill" | grep -qE "^description:" || {
    echo "FAIL: $skill 的 frontmatter 缺 'description:'（skill 不會被載入）"; return 1; }
  return 0
}

@test "SKILL-FM-1: every skills/*/SKILL.md has frontmatter with name + description" {
  local d skill n=0 out
  for d in "$REPO_ROOT"/skills/*/; do
    d="$(basename "$d")"
    skill="$REPO_ROOT/skills/$d/SKILL.md"
    [ -f "$skill" ] || continue
    if ! out=$(check_skill_frontmatter "$skill" "$d"); then
      echo "$out" >&2
      return 1
    fi
    n=$((n + 1))
  done
  [ "$n" -ge 13 ] || {
    echo "FAIL: 只驗到 $n 個 skill 的 frontmatter（< 13）→ 列舉壞了或 skills/ 被搬走（掃不到不得空過）" >&2
    return 1
  }
}

@test "SKILL-FM-2: the frontmatter checker itself bites (and does not false-alarm)" {
  local tmp="$BATS_TEST_TMPDIR/skills/broken"
  mkdir -p "$tmp"

  # ① 完全沒有 frontmatter → 必須紅
  printf 'name: broken\n' > "$tmp/SKILL.md"
  run check_skill_frontmatter "$tmp/SKILL.md" broken
  [ "$status" -ne 0 ] || { echo "FAIL: 缺 frontmatter 竟通過（偵測器空過）" >&2; return 1; }

  # ② name 與目錄名不符 → 必須紅
  printf -- '---\nname: something-else\ndescription: x\n---\n# t\n' > "$tmp/SKILL.md"
  run check_skill_frontmatter "$tmp/SKILL.md" broken
  [ "$status" -ne 0 ] || { echo "FAIL: name 與目錄名不符竟通過" >&2; return 1; }

  # ③ 缺 description → 必須紅
  printf -- '---\nname: broken\n---\n# t\n' > "$tmp/SKILL.md"
  run check_skill_frontmatter "$tmp/SKILL.md" broken
  [ "$status" -ne 0 ] || { echo "FAIL: 缺 description 竟通過" >&2; return 1; }

  # ④ 合格 fixture → 必須綠（否則偵測器是「一律紅」的假咬，同樣沒有驗證力）
  printf -- '---\nname: broken\ndescription: x\n---\n# t\n' > "$tmp/SKILL.md"
  run check_skill_frontmatter "$tmp/SKILL.md" broken
  [ "$status" -eq 0 ] || { echo "FAIL: 合格 fixture 竟紅（偵測器一律紅＝假咬）：$output" >&2; return 1; }
}
