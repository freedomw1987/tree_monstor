#!/usr/bin/env bats
# check-examples-version-baseline.bats
# 守則：每個 skill 的 examples/ 子目錄下檔案必含「對應 skill 版本基線」標記
# 守則起源：skill 自包含化任務 Reviewer F4 修正（防範例與 skill 版本漂移）
# 守則適用：~/.pi/agent/skills/*/examples/*.{md,ts}
# 觸發：2026-09-26 skill 自包含化

setup() {
  # TMO-047：預設掃「已安裝」的 skills；CI 以 SKILLS_DIR_OVERRIDE 指向 repo 的 skills/。
  # 沒有 root 就大聲紅（否則整支探針會空過：掃不到檔 → 0 violations）。
  SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-${HOME}/.pi/agent/skills}"
  if [ ! -d "$SKILLS_DIR" ]; then
    echo "FAIL: SKILLS_DIR 不存在：$SKILLS_DIR（探針會空過）→ 設 SKILLS_DIR_OVERRIDE 或檢查環境" >&2
    return 1
  fi
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
  # TMO-047：原本「掃不到就 skip」＝空過（CI 上會靜默綠）。改為大聲紅：
  # 掃不到任何 examples/ 通常代表 root 指錯，而不是「大家剛好都沒有 examples」。
  if [ "$found_any" -eq 0 ]; then
    echo "FAIL: 在 $SKILLS_DIR 掃不到任何 skill 的 examples/（found_any=0）→ 探針空過，root 可能指錯" >&2
    return 1
  fi
  [ "$violations" -eq 0 ]
}