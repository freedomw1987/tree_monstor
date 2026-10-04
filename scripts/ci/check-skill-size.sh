#!/usr/bin/env bash
# scripts/ci/check-skill-size.sh
#
# SKILL.md 行數上限檢查（規範見 skills/dav-skill-creater/editor-guide.md：主檔 ≤ 150 行）。
#
# 為什麼要獨立成腳本（TMO-041 追加）：
#   1. 原本 CI 只硬編檢查 `skills/dav-wiki/SKILL.md` 一檔 → 其他 10 檔（含 149 行的
#      `tdd-test-writer/SKILL.md`）改爆了也不會被擋（同 TMO-038 ④ 的教訓：硬編清單＝漏抓）。
#      現在改成**自動列舉** `skills/**/SKILL.md`。
#   2. 抽成腳本才能被探針用「假 root」實測（見 tests/skill-size-guard.bats SSG-3），
#      而不是只在 CI 裡跑一次就沒人驗。
#
# 用法：bash scripts/ci/check-skill-size.sh [repo_root]
#   SKILL_MAX 可覆寫上限（預設 150）；SKILL_MIN 可覆寫「至少要列舉到幾檔」（預設 11，防空過）
set -uo pipefail

MAX="${SKILL_MAX:-150}"
MIN="${SKILL_MIN:-11}"
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [ ! -d "$ROOT/skills" ]; then
  echo "FAIL: 找不到 $ROOT/skills（root 參數錯了嗎？）" >&2
  exit 1
fi

files=0
over=0
worst_lines=0
worst_file=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f" | tr -d ' ')
  files=$((files + 1))
  if [ "$lines" -gt "$worst_lines" ]; then worst_lines="$lines"; worst_file="$f"; fi
  if [ "$lines" -gt "$MAX" ]; then
    echo "::error file=$f::$f too long: $lines lines (max $MAX)"
    over=$((over + 1))
  fi
done < <(find "$ROOT/skills" -name SKILL.md -type f | sort)

if [ "$files" -lt "$MIN" ]; then
  echo "FAIL: 只列舉到 $files 個 SKILL.md（< $MIN）→ 枚舉可能壞了（防空過），root=$ROOT" >&2
  exit 1
fi

if [ "$over" -ne 0 ]; then
  echo "FAIL: $over 個 SKILL.md 超過 $MAX 行" >&2
  exit 1
fi

echo "OK: $files 個 SKILL.md 皆 <= $MAX 行（最長 $worst_lines 行：$worst_file）"
