#!/usr/bin/env bash
# scripts/test-skill.sh — 跑**單一 skill** 嘅測試（2026-10-27 用戶決策）
#
# 做咩：探針跟 skill 搬到 `skills/<name>/tests/`（2026-10-27）→ 改動某個 skill 時
#       只跑嗰個 skill 嘅探針，唔使等成 repo 嘅測試套件。
#
# 用法：
#   bash scripts/test-skill.sh dav-developer        # 跑一個 skill
#   bash scripts/test-skill.sh dav-developer dav-wiki   # 跑多個
#   bash scripts/test-skill.sh --list                 # 列有測試嘅 skill
#
# 退出碼：0 = 全綠；1 = 有測試紅；2 = 用法／環境錯誤（skill 名不存在、冇 tests/、缺 bats）

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${REPO_ROOT}" ]; then
  echo "FAIL: 唔喺 git repo 入面" >&2
  exit 2
fi
cd "${REPO_ROOT}"

list_skills() {
  local d
  for d in skills/*/; do
    [ -d "${d}tests" ] || continue
    ls "${d}tests/"*.bats >/dev/null 2>&1 || continue
    basename "${d}"
  done
}

if [ $# -eq 0 ]; then
  echo "用法：bash scripts/test-skill.sh [--list] <skill> [<skill>...]" >&2
  echo "有測試嘅 skill：$(list_skills | tr '\n' ' ')" >&2
  exit 2
fi

if [ "$1" = "--list" ]; then
  list_skills
  exit 0
fi

if ! command -v bats >/dev/null 2>&1; then
  echo "FAIL: 本機冇 bats（安裝：brew install bats-core）" >&2
  exit 2
fi

overall=0
for skill in "$@"; do
  dir="skills/${skill}/tests"
  if [ ! -d "${dir}" ]; then
    echo "FAIL: ${dir} 唔存在（skill 名錯？用 --list 睇清單）" >&2
    overall=2
    continue
  fi
  echo "═══ ${skill} ═══"
  rc=0
  bats "${dir}/" || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FAIL: ${skill} 嘅測試紅（rc=${rc}）" >&2
    overall=1
  fi
done

exit "${overall}"
