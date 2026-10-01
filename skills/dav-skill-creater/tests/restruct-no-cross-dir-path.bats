#!/usr/bin/env bats
# restruct-no-cross-dir-path.bats
# 守則：任何 skill 的 SKILL.md 交叉引用段不得含具體跨目錄 path（除非白名單例外）
# 守則起源：dav-skill-creater editor-guide.md v2.2 純文字引用零容忍
# 守則適用：~/.pi/agent/skills/*/SKILL.md
# 觸發：2026-09-26 清存量任務 + skill 自包含化任務（Reviewer F2 修正探針邏輯）

setup() {
  SKILLS_DIR="${HOME}/.pi/agent/skills"
}

@test "no skill SKILL.md references banned monorepo cross-dir path token" {
  # 被禁用的 token 列表（明確列舉，不依靠通用 regex、避免誤殺）：
  # - 'examples/module-lifecycle'：原 monorepo 範例總目錄名稱，v2.5 自包含化後已過期
  # 白名單例外：「見本 skill 的 `examples/...`」同 dir 子檔引用可通過
  local violations=0
  local banned_tokens=("examples/module-lifecycle")
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    for token in "${banned_tokens[@]}"; do
      if grep -q "$token" "$f"; then
        if ! grep -qE '見本 skill 的 `examples/' "$f"; then
          echo "VIOLATION: $f still references banned token: $token" >&2
          violations=$((violations + 1))
        fi
      fi
    done
  done
  [ "$violations" -eq 0 ]
}

@test "no skill SKILL.md contains ../path cross-dir markdown link in cross-reference section" {
  local violations=0
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    if grep -qE '\]\(\.\./' "$f"; then
      echo "VIOLATION: $f contains ../ markdown link" >&2
      violations=$((violations + 1))
    fi
  done
  [ "$violations" -eq 0 ]
}