#!/usr/bin/env bats
#
# tests/install-qoder.bats
#
# Qoder 安裝支援的驗收測試（TMO-069）。
#
# 對應的實作決策（來源：Qoder CLI/IDE 官方文件 + 本機實測）：
#   - Qoder skills：使用者層 `~/.qoder/skills/<name>/SKILL.md`、
#     專案層 `<project>/.qoder/skills/<name>/SKILL.md`（兩者皆為 per-skill 目錄）
#   - Qoder AGENTS.md：CLI 讀使用者層 `~/.qoder/AGENTS.md`；
#     CLI 與 IDE 都讀專案層 `<project>/AGENTS.md`
#   - Qoder subagents：`<root>/agents/<name>.md`
#
# 覆蓋範圍：全域／專案層／target 三種 scope、merge 行為、冪等、
# 安裝與卸載安全性（絕不覆寫使用者自己的 AGENTS.md）。

setup() {
  load 'helpers/test-env'
  setup_test_env
}

teardown() {
  teardown_test_env
}

# create_project_with_agents_md <dir>
# 建立一個「已經有自己的 AGENTS.md」的專案目錄（使用者擁有，安裝器不得覆寫）。
create_project_with_agents_md() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/AGENTS.md" <<'EOF'
# Project-owned AGENTS.md
This file belongs to the project and must NOT be overwritten.
EOF
}

# create_user_qoder_skill <name>
# 在 ~/.qoder/skills/ 放一個使用者自有的 skill（安裝／卸載都要保留）。
create_user_qoder_skill() {
  local name="$1"
  mkdir -p "$TEST_HOME/.qoder/skills/$name"
  cat > "$TEST_HOME/.qoder/skills/$name/SKILL.md" <<EOF
# $name
Owned by the user. Must survive install and uninstall.
EOF
}

# ---------- 全域安裝 ----------

@test "QODER-1: --global --agent qoder creates ~/.qoder/AGENTS.md symlink to source AGENTS.md" {
  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  # symlink 必須可解析（不是斷鏈）
  assert_path_is_file "$TEST_HOME/.qoder/AGENTS.md"
}

@test "QODER-2: --global --agent qoder merges per-skill symlinks into ~/.qoder/skills/" {
  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  [ -d "$TEST_HOME/.qoder/skills" ]
  [ ! -L "$TEST_HOME/.qoder/skills" ]
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner"  "$TEST_SOURCE/skills/dav-planner"
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-designer" "$TEST_SOURCE/skills/dav-designer"
}

@test "QODER-3: --agent qoder installs ONLY qoder parts (no .claude / .pi)" {
  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.qoder/AGENTS.md"
  [ ! -e "$TEST_HOME/.claude" ]
  [ ! -e "$TEST_HOME/.pi" ]
}

@test "QODER-4: default install covers qoder too (all supported agents)" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  # 既有 agent 不得因此被漏掉
  assert_path_exists "$TEST_HOME/.claude/CLAUDE.md"
  assert_path_exists "$TEST_HOME/.pi/agent/AGENTS.md"
}

# ---------- 專案層安裝 ----------

@test "QODER-5: --local installs .qoder/skills/ and project-level AGENTS.md into cwd" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj"
  cd "$proj"

  run run_install --local --yes
  [ "$status" -eq 0 ]

  # 專案層 skills：Qoder IDE 與 CLI 都讀 <project>/.qoder/skills/
  assert_path_is_symlink "$proj/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  # 專案層 AGENTS.md：CLI 與 IDE 都讀 <project>/AGENTS.md
  assert_path_is_symlink "$proj/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  # 專案層模式不該動到使用者層 ~/.qoder/AGENTS.md
  [ ! -e "$TEST_HOME/.qoder/AGENTS.md" ]
}

@test "QODER-6: --local does NOT overwrite a project-owned AGENTS.md" {
  local proj="$TEST_TMP_DIR/proj"
  create_project_with_agents_md "$proj"
  cd "$proj"

  run run_install --local --yes
  [ "$status" -eq 0 ]

  # 使用者自己的 AGENTS.md 必須原封不動（不是 symlink、內容沒被換掉）
  if [[ -L "$proj/AGENTS.md" ]]; then
    echo "FAIL: installer replaced the project-owned AGENTS.md with a symlink" >&2
    return 1
  fi
  assert_file_contains "$proj/AGENTS.md" "belongs to the project"
  # 其它部分照常安裝
  assert_path_is_symlink "$proj/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
}

@test "QODER-7: --target installs .qoder/skills/ and AGENTS.md into the target dir" {
  local target="$TEST_TMP_DIR/my-project"
  mkdir -p "$target"

  run run_install --target "$target" --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$target/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  assert_path_is_symlink "$target/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
}

# ---------- 卸載安全性 ----------

@test "QODER-8: --uninstall removes our qoder symlinks but keeps user-owned skills" {
  create_user_qoder_skill "user-qoder-skill"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"

  run run_install --uninstall --global --agent qoder --yes
  [ "$status" -eq 0 ]

  [ ! -L "$TEST_HOME/.qoder/AGENTS.md" ]
  [ ! -L "$TEST_HOME/.qoder/skills/dav-planner" ]
  [ ! -L "$TEST_HOME/.qoder/skills/dav-designer" ]
  # 使用者自己的 skill 必須活著
  assert_path_is_file "$TEST_HOME/.qoder/skills/user-qoder-skill/SKILL.md"
}

@test "QODER-9: --uninstall (project scope) removes the project AGENTS.md symlink we created" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj"
  cd "$proj"

  run run_install --local --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$proj/AGENTS.md" "$TEST_SOURCE/AGENTS.md"

  run run_install --uninstall --local --agent qoder --yes
  [ "$status" -eq 0 ]

  [ ! -L "$proj/AGENTS.md" ]
}

@test "QODER-10: --uninstall keeps a project-owned AGENTS.md that we never created" {
  local proj="$TEST_TMP_DIR/proj"
  create_project_with_agents_md "$proj"
  cd "$proj"

  run run_install --local --agent qoder --yes
  [ "$status" -eq 0 ]

  run run_install --uninstall --local --agent qoder --yes
  [ "$status" -eq 0 ]

  # 我們從未動過它 → 必須仍在，且不是 symlink
  if [[ -L "$proj/AGENTS.md" ]]; then
    echo "FAIL: uninstall removed/replaced a project-owned AGENTS.md" >&2
    return 1
  fi
  assert_file_contains "$proj/AGENTS.md" "belongs to the project"
}

# ---------- 其它行為 ----------

@test "QODER-11: --dry-run --agent qoder prints the plan and creates nothing" {
  run run_install --global --agent qoder --dry-run
  [ "$status" -eq 0 ]

  [ ! -e "$TEST_HOME/.qoder" ]
  printf '%s\n' "$output" | grep -F -q ".qoder"
  # F7：dry-run 的計畫必須描述「真實會做的事」＝ per-skill merge，
  # 而不是會誤導的 whole-tree symlink。
  printf '%s\n' "$output" | grep -F -q "per-skill"
  if printf '%s\n' "$output" | grep -F -q "skills -> "; then
    echo "FAIL: dry-run plan still shows a whole-tree skills symlink" >&2
    return 1
  fi
  # dry-run 不得宣稱「已建立」
  if printf '%s\n' "$output" | grep -F -q "symlink created"; then
    echo "FAIL: dry-run claims a symlink was created" >&2
    return 1
  fi
}

@test "QODER-12: installing twice is idempotent (no error, same state)" {
  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
}

@test "QODER-13: merge mode preserves user skills already in ~/.qoder/skills/" {
  create_user_qoder_skill "user-qoder-skill"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_file "$TEST_HOME/.qoder/skills/user-qoder-skill/SKILL.md"
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
}

@test "QODER-14: --help documents the qoder agent" {
  run run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"qoder"* ]]
}

@test "QODER-15: an unknown --agent name fails loudly (exit 2) instead of silently skipping" {
  run run_install --global --agent qoder-typo --yes
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -F -q "qoder-typo"
  [ ! -e "$TEST_HOME/.qoder" ]
}

# ---------- Gate 4 reviewer 二審補強 ----------
# 覆蓋 reviewer 指出的 F1（使用者自有 ~/.qoder/AGENTS.md 讓整個安裝中斷）、
# F2（使用者自有 symlink 被靜默替換）、F3（~/.qoder/skills symlink 被替換），
# 以及 reviewer 列出的未覆蓋情境（--agent all / 可重複 / local dry-run /
# skill 名稱衝突 / 無安裝過就卸載 / 專案層冪等 / subagents / 相對 --source）。

@test "QODER-16: user-owned ~/.qoder/AGENTS.md does not abort the whole install (F1)" {
  mkdir -p "$TEST_HOME/.qoder"
  cat > "$TEST_HOME/.qoder/AGENTS.md" <<'EOF'
# My own Qoder memory
Owned by the user. Must survive install.
EOF

  # qoder 已在預設安裝清單 → 使用者自有的 AGENTS.md 不得讓安裝整個失敗
  run run_install --global --yes
  [ "$status" -eq 0 ]

  if [[ -L "$TEST_HOME/.qoder/AGENTS.md" ]]; then
    echo "FAIL: installer replaced the user-owned ~/.qoder/AGENTS.md" >&2
    return 1
  fi
  assert_file_contains "$TEST_HOME/.qoder/AGENTS.md" "Owned by the user"
  # 後續步驟仍要跑完（skills + .agents 本機副本）
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  assert_path_exists "$TEST_HOME/.agents/tree_monstor/AGENTS.md"
}

@test "QODER-17: a user-owned ~/.qoder/AGENTS.md symlink survives install AND uninstall (F2)" {
  mkdir -p "$TEST_HOME/.qoder" "$TEST_TMP_DIR/elsewhere"
  echo "# elsewhere" > "$TEST_TMP_DIR/elsewhere/memory.md"
  ln -s "$TEST_TMP_DIR/elsewhere/memory.md" "$TEST_HOME/.qoder/AGENTS.md"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$TEST_TMP_DIR/elsewhere/memory.md"

  run run_install --uninstall --global --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$TEST_TMP_DIR/elsewhere/memory.md"
}

@test "QODER-18: a project AGENTS.md symlink to the project's own doc survives install AND uninstall (F2)" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj/docs"
  echo "# project doc" > "$proj/docs/AGENTS.md"
  ln -s "$proj/docs/AGENTS.md" "$proj/AGENTS.md"
  cd "$proj"

  run run_install --local --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$proj/AGENTS.md" "$proj/docs/AGENTS.md"

  run run_install --uninstall --local --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$proj/AGENTS.md" "$proj/docs/AGENTS.md"
}

@test "QODER-19: ~/.qoder/skills symlinked to the user's own skills dir is not replaced (F3)" {
  mkdir -p "$TEST_HOME/.qoder" "$TEST_TMP_DIR/my-skills/mine"
  echo "# mine" > "$TEST_TMP_DIR/my-skills/mine/SKILL.md"
  ln -s "$TEST_TMP_DIR/my-skills" "$TEST_HOME/.qoder/skills"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.qoder/skills" "$TEST_TMP_DIR/my-skills"
  assert_path_is_file "$TEST_HOME/.qoder/skills/mine/SKILL.md"

  # 卸載也不能動它（只刪「我們自己建的 symlink」）
  run run_install --uninstall --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.qoder/skills" "$TEST_TMP_DIR/my-skills"
  assert_path_is_file "$TEST_HOME/.qoder/skills/mine/SKILL.md"
}

@test "QODER-20: --agent all installs claude, pi and qoder" {
  run run_install --global --agent all --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.claude/CLAUDE.md"
  assert_path_exists "$TEST_HOME/.pi/agent/AGENTS.md"
  assert_path_exists "$TEST_HOME/.qoder/AGENTS.md"
}

@test "QODER-21: --agent is repeatable (claude + qoder only, no pi)" {
  run run_install --global --agent claude --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.claude/CLAUDE.md"
  assert_path_exists "$TEST_HOME/.qoder/AGENTS.md"
  [ ! -e "$TEST_HOME/.pi" ]
}

@test "QODER-22: repeating the same --agent twice is deduped, not an error" {
  run run_install --global --agent qoder --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.qoder/AGENTS.md"
  # 去重的實際證據：Qoder 只被安裝一次（否則會印兩次 "Installing for Qoder..."）
  local n
  n="$(printf '%s\n' "$output" | grep -c "Installing for Qoder")"
  [ "$n" -eq 1 ] || {
    echo "FAIL: expected Qoder to be installed exactly once, got $n" >&2
    return 1
  }
}

@test "QODER-23: --local --dry-run creates nothing in the project dir" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj"
  cd "$proj"

  run run_install --local --dry-run
  [ "$status" -eq 0 ]

  [ ! -e "$proj/AGENTS.md" ]
  [ ! -e "$proj/.qoder" ]
  [ ! -e "$proj/.claude" ]
}

@test "QODER-24: a user-owned skill with the same name is not overwritten" {
  mkdir -p "$TEST_HOME/.qoder/skills/dav-planner"
  echo "# my own dav-planner" > "$TEST_HOME/.qoder/skills/dav-planner/SKILL.md"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_file_contains "$TEST_HOME/.qoder/skills/dav-planner/SKILL.md" "my own dav-planner"
  if [[ -L "$TEST_HOME/.qoder/skills/dav-planner" ]]; then
    echo "FAIL: installer symlinked over the user-owned skill" >&2
    return 1
  fi
}

@test "QODER-25: --uninstall --local in a project that never had qoder installed exits 0" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj"
  cd "$proj"

  run run_install --uninstall --local --agent qoder --yes
  [ "$status" -eq 0 ]

  [ ! -e "$proj/AGENTS.md" ]
  [ ! -e "$proj/.qoder" ]
}

@test "QODER-26: --local is idempotent (second run keeps our own symlink)" {
  local proj="$TEST_TMP_DIR/proj"
  mkdir -p "$proj"
  cd "$proj"

  run run_install --local --agent qoder --yes
  [ "$status" -eq 0 ]
  run run_install --local --agent qoder --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$proj/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  assert_path_is_symlink "$proj/.qoder/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
}

@test "QODER-27: qoder subagents are installed per-file and user-owned ones survive uninstall" {
  mkdir -p "$TEST_SOURCE/agents" "$TEST_HOME/.qoder/agents"
  echo "# reviewer subagent" > "$TEST_SOURCE/agents/reviewer.md"
  echo "# my own subagent" > "$TEST_HOME/.qoder/agents/mine.md"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]
  assert_path_is_symlink "$TEST_HOME/.qoder/agents/reviewer.md" "$TEST_SOURCE/agents/reviewer.md"

  run run_install --uninstall --global --agent qoder --yes
  [ "$status" -eq 0 ]

  [ ! -L "$TEST_HOME/.qoder/agents/reviewer.md" ]
  assert_path_is_file "$TEST_HOME/.qoder/agents/mine.md"
}

@test "QODER-28: a relative --source still lets uninstall recognise our own symlink (F5)" {
  cd "$TEST_TMP_DIR"

  run run_install --source tree-monstor --global --agent qoder --yes
  [ "$status" -eq 0 ]
  # symlink 目標必指向 source 的 AGENTS.md
  # （macOS 上 /var → /private/var 會讓絕對路徑有兩種寫法，故比對結尾而非全字串）
  local link_target
  link_target="$(readlink "$TEST_HOME/.qoder/AGENTS.md")"
  [[ "$link_target" == */tree-monstor/AGENTS.md ]] || {
    echo "FAIL: qoder 的 AGENTS.md 應 symlink 到 tree-monstor（實際：${link_target}）" >&2; return 1; }
  assert_path_is_file "$TEST_HOME/.qoder/AGENTS.md"

  run run_install --source tree-monstor --uninstall --global --agent qoder --yes
  [ "$status" -eq 0 ]

  [ ! -L "$TEST_HOME/.qoder/AGENTS.md" ]
}

@test "QODER-29: a relative --source still yields ABSOLUTE @paths in the Claude wrapper (F5)" {
  cd "$TEST_TMP_DIR"

  run run_install --source tree-monstor --global --agent claude --yes
  [ "$status" -eq 0 ]

  local wrapper body
  wrapper="$TEST_HOME/.claude/CLAUDE.md"
  assert_path_is_file "$wrapper"
  body="$(cat "$wrapper")"

  # wrapper 裡的 @ 引用必須是絕對路徑（相對路徑會讓 ~/.claude/CLAUDE.md 讀不到東西）
  printf '%s\n' "$body" | grep -qE '^@/[^[:space:]]+/AGENTS\.md$'
  printf '%s\n' "$body" | grep -qE '^@/[^[:space:]]+/SOUL\.md$'
  if printf '%s\n' "$body" | grep -qE '^@[^/[:space:]]'; then
    echo "FAIL: Claude wrapper contains a relative @path:" >&2
    printf '%s\n' "$body" | grep -E '^@' >&2
    return 1
  fi
}

@test "QODER-30: --source auto-detection (no --source flag) installs from the script's own dir" {
  # 不傳 --source：安裝器必須從 install.sh 自己的所在目錄推導 source
  run env -i \
    HOME="$TEST_HOME" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="${TERM:-xterm}" \
    NO_COLOR="1" \
    bash "$INSTALL_SH" --global --agent qoder --yes
  # 失敗時一定要印安裝器輸出（2026-10-27：呢支曾喺一次全套跑入面紅、單跑綠 →
  # 冇輸出就查唔到原因；TMO-089 待觀察項）
  [ "$status" -eq 0 ] || {
    echo "FAIL: install.sh --agent qoder 離開碼 ${status}（安裝器輸出見下）" >&2
    printf '%s\n' "$output" >&2
    return 1
  }

  assert_path_is_symlink "$TEST_HOME/.qoder/AGENTS.md" "$REPO_ROOT/AGENTS.md"
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$REPO_ROOT/skills/dav-planner"
}

@test "QODER-31: a foreign per-skill symlink in ~/.qoder/skills is not repointed" {
  mkdir -p "$TEST_HOME/.qoder/skills" "$TEST_TMP_DIR/my-skill"
  echo "# mine" > "$TEST_TMP_DIR/my-skill/SKILL.md"
  ln -s "$TEST_TMP_DIR/my-skill" "$TEST_HOME/.qoder/skills/dav-planner"

  run run_install --global --agent qoder --yes
  [ "$status" -eq 0 ]

  # 使用者自己的 symlink 必須原封不動（不得被「repair」成指向我們的 source）
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-planner" "$TEST_TMP_DIR/my-skill"
  assert_path_is_file "$TEST_HOME/.qoder/skills/dav-planner/SKILL.md"
  # 其他 skills 仍然照常安裝（不能因為一個衝突就整批不裝）
  assert_path_is_symlink "$TEST_HOME/.qoder/skills/dav-designer" "$TEST_SOURCE/skills/dav-designer"
}
