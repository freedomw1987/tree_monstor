#!/usr/bin/env bash
# tests/helpers/test-env.bash
#
# Shared test environment for install.sh tests.
# Provides:
#   - TEST_TMP_DIR:   a fresh tmp dir for each test (auto cleaned up)
#   - TEST_HOME:      a fake $HOME inside the tmp dir
#   - TEST_SOURCE:    a copy of the mock-tree-monstor fixture
#   - run_install:    helper to invoke install.sh with flags + auto-cleaned env

# Resolve paths relative to this file, not the caller's cwd.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
FIXTURE_SRC="$REPO_ROOT/tests/fixtures/mock-tree-monstor"
INSTALL_SH="$REPO_ROOT/install.sh"

setup_test_env() {
  TEST_TMP_DIR="$(mktemp -d -t install-sh-test.XXXXXX)"
  TEST_HOME="$TEST_TMP_DIR/home"
  TEST_SOURCE="$TEST_TMP_DIR/tree-monstor"
  mkdir -p "$TEST_HOME"

  # Copy fresh fixture so each test is isolated.
  rm -rf "$TEST_SOURCE"
  cp -R "$FIXTURE_SRC" "$TEST_SOURCE"
}

teardown_test_env() {
  if [[ -n "${TEST_TMP_DIR:-}" && -d "$TEST_TMP_DIR" ]]; then
    rm -rf "$TEST_TMP_DIR"
  fi
}

# run_install <args...>
# Runs install.sh with isolated HOME and the fixture as --source.
run_install() {
  env -i \
    HOME="$TEST_HOME" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="${TERM:-xterm}" \
    NO_COLOR="1" \
    bash "$INSTALL_SH" --source "$TEST_SOURCE" "$@"
}

# run_install_interactive <input> <args...>
# Same as run_install but feeds stdin (for prompts).
run_install_interactive() {
  local input="$1"
  shift
  env -i \
    HOME="$TEST_HOME" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="${TERM:-xterm}" \
    NO_COLOR="1" \
    bash "$INSTALL_SH" --source "$TEST_SOURCE" "$@" <<<"$input"
}

# assert_path_exists <path>
assert_path_exists() {
  [[ -e "$1" ]] || { echo "FAIL: expected path to exist: $1" >&2; return 1; }
}

# assert_path_is_symlink <path> [expected_target]
assert_path_is_symlink() {
  local p="$1"
  local expected="${2:-}"
  if [[ ! -L "$p" ]]; then
    echo "FAIL: expected symlink at $p, but it is not a symlink" >&2
    return 1
  fi
  if [[ -n "$expected" ]]; then
    local actual
    actual="$(readlink "$p")"
    if [[ "$actual" != "$expected" ]]; then
      echo "FAIL: symlink $p points to '$actual', expected '$expected'" >&2
      return 1
    fi
  fi
}

# assert_path_is_file <path>
assert_path_is_file() {
  [[ -f "$1" ]] || { echo "FAIL: expected file at $1" >&2; return 1; }
}

# assert_file_contains <path> <substring>
assert_file_contains() {
  local p="$1"
  local needle="$2"
  # TMO-032：先驗檔案存在，把「找不到檔案」與「找不到字串」分開報，避免誤導。
  [[ -f "$p" ]] || { echo "FAIL: expected file at $p (assert_file_contains)" >&2; return 1; }
  if ! grep -F -q -- "$needle" "$p"; then
    echo "FAIL: file $p does not contain: $needle" >&2
    return 1
  fi
}

# refute_file_contains <path> <substring>
# 負向斷言：檔案**不得**包含該字串。用於「廢棄守門」——被用戶決策廢除的功能
# 不得靜默回流（例如 dav-planner §2.7 用戶背景收集，v2.1 已廢除）。
refute_file_contains() {
  local p="$1"
  local needle="$2"
  # TMO-032（reviewer P2-a）：檔案不存在時 grep rc=2，原本 `if grep` 不成立
  # → 負向斷言「安靜地綠」（整類假綠）。改為明確 FAIL。
  [[ -f "$p" ]] || { echo "FAIL: expected file at $p (refute_file_contains)" >&2; return 1; }
  if grep -F -q -- "$needle" "$p"; then
    echo "FAIL: file $p must NOT contain: $needle" >&2
    return 1
  fi
}

# refute_file_body_contains <path> <substring>
# 同上，但**排除 `## 變動歷史` 章節**：SOP 政策是「撤銷的章節不抹去、只在變動歷史
# 加註（已廢棄）」，所以在變動歷史提到已廢除名稱是合法的，不該誤紅（reviewer P2-b）。
# round C P2-2：原本用 `grep -v -E '^\| v'` 排除「全檔任何 `| v` 起始列」→ 任何表內
# 以 `| v` 開頭的列（含別的表、甚至偽造的歷史列）都被靜默豁免。改為**只切掉變動歷史
# 章節**（`## 變動歷史` 到下一個 `## `），其餘全掃；檔案沒有該章節時等於全掃（更嚴）。
refute_file_body_contains() {
  local p="$1"
  local needle="$2"
  [[ -f "$p" ]] || { echo "FAIL: expected file at $p (refute_file_body_contains)" >&2; return 1; }
  if awk '/^## 變動歷史/{skip=1; next} /^## /{skip=0} !skip' "$p" | grep -F -q -- "$needle"; then
    echo "FAIL: file $p body (excluding 變動歷史 section) must NOT contain: $needle" >&2
    return 1
  fi
}

# mask_secrets
# 任何「被測程式的輸出」在寫進 FAIL 訊息／log 之前都要先過這一層（TMO-053 / NYH-2）：
# 2026-10-05 做 TMO-045 反向驗證時，探針 FAIL 訊息把本機真 `OPENROUTER_API_KEY`
# 印進了 session log。
# 遮罩範圍：①`sk-…` 形式的金鑰；②`*KEY=…` / `*TOKEN=…` / `*SECRET=…` 的指派值。
# 單一真相來源：探針檔不得自己再定義一份（靜態鎖 `scripts/ci/lint-probe-secrets.py`
# 的 R4 ＋ `tests/secret-masking.bats` SM-1 都會擋）。
mask_secrets() {
  sed -E \
    -e 's/sk-[A-Za-z0-9_-]+/sk-***MASKED***/g' \
    -e 's/([A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Za-z0-9_]*)=[^[:space:]]*/\1=***MASKED***/g'
}

# create_existing_claude_skills_dir
# Pre-populate $TEST_HOME/.claude/skills with two fake user skills plus
# one that will conflict with the source fixture's `conflict-skill`.
create_existing_claude_skills_dir() {
  mkdir -p "$TEST_HOME/.claude"
  mkdir -p "$TEST_HOME/.claude/skills/user-skill-a"
  mkdir -p "$TEST_HOME/.claude/skills/user-skill-b"
  mkdir -p "$TEST_HOME/.claude/skills/conflict-skill"

  cat > "$TEST_HOME/.claude/skills/user-skill-a/SKILL.md" <<'EOF'
# user-skill-a
Owned by user. Must survive install.
EOF
  cat > "$TEST_HOME/.claude/skills/user-skill-b/SKILL.md" <<'EOF'
# user-skill-b
Owned by user. Must survive install.
EOF
  cat > "$TEST_HOME/.claude/skills/conflict-skill/SKILL.md" <<'EOF'
# conflict-skill
User-owned version. Must NOT be overwritten by installer.
EOF
}

# create_existing_claude_wrapper_symlink <target_path>
# Pre-create $TEST_HOME/.claude/CLAUDE.md as a symlink pointing to <target_path>.
# Used to test that installer overwrites stale symlinks pointing to wrong sources.
create_existing_claude_wrapper_symlink() {
  local target="$1"
  mkdir -p "$TEST_HOME/.claude"
  ln -s "$target" "$TEST_HOME/.claude/CLAUDE.md"
}
