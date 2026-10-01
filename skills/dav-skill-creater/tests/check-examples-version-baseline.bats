#!/usr/bin/env bats
# check-examples-version-baseline.bats
# 守則：每個 skill 的 examples/ 子目錄下檔案必含「對應 skill 版本基線」標記
# 守則起源：skill 自包含化任務 Reviewer F4 修正（防範例與 skill 版本漂移）
# 守則適用：~/.pi/agent/skills/*/examples/*.{md,ts}
# 觸發：2026-09-26 skill 自包含化

setup() {
  SKILLS_DIR="${HOME}/.pi/agent/skills"
}

@test "each example file declares its skill version baseline" {
  local violations=0
  local found_any=0
  # 掃所有 skill 的 examples/ 子目錄（含子目錄內的 .ts 等）
  for skill_dir in "$SKILLS_DIR"/*/; do
    if [ -d "${skill_dir}examples" ]; then
      for f in "${skill_dir}examples"/* "${skill_dir}examples"/*/*; do
        if [ -f "$f" ]; then
          found_any=1
          case "$f" in
            *.md|*.ts)
              # 接受兩種格式：
              # 1. 明確標記：對應 skill 版本基線：v?.?
              # 2. 既有格式：對應 skill：`<name>`（v?.? ...）
              if ! grep -qE '(對應 skill 版本基線|對應 skill：?`[a-z-]+`（v[0-9]+\.[0-9]+)' "$f"; then
                echo "VIOLATION: $f missing skill version baseline marker" >&2
                violations=$((violations + 1))
              fi
              ;;
          esac
        fi
      done
    fi
  done
  # 若完全沒有 examples/ 子目錄，視為通過（探針不強制要求每個 skill 都有 examples）
  if [ "$found_any" -eq 0 ]; then
    skip "no examples/ subdirectory found in any skill"
  fi
  [ "$violations" -eq 0 ]
}