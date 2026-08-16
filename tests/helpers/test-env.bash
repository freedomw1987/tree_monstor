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
  if ! grep -F -q -- "$needle" "$p"; then
    echo "FAIL: file $p does not contain: $needle" >&2
    return 1
  fi
}
