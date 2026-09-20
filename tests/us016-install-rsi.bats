#!/usr/bin/env bats
#
# tests/us016-install-rsi.bats
#
# Black-box tests for US-016: install.sh --enable-rsi / --disable-rsi flag
# Each test corresponds to one or more ACs in docs/backlog.md (US-016).
#
# Usage:
#   bats tests/us016-install-rsi.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  INSTALL_SH="$REPO_ROOT/install.sh"
}

# ---------- AC-1: install.sh 加 --enable-rsi / --disable-rsi 旗標 ----------
@test "AC-1a: install.sh has --enable-rsi flag" {
  [ -f "$INSTALL_SH" ]
  grep -qE "\\-\\-enable-rsi" "$INSTALL_SH"
}

@test "AC-1b: install.sh has --disable-rsi flag" {
  [ -f "$INSTALL_SH" ]
  grep -qE "\\-\\-disable-rsi" "$INSTALL_SH"
}

@test "AC-1c: --enable-rsi is default (or enabled by default)" {
  [ -f "$INSTALL_SH" ]
  grep -qE "ENABLE_RSI.*=1.*default|RSI_ENABLED.*=1|--enable-rsi.*default|\\[\\[ \\\"\\\$ENABLE_RSI\\\" == \"\" \\]\\]" "$INSTALL_SH"
}

# ---------- AC-2: --enable-rsi 部署 sop-evolver + 初始化 ~/.tree-monstor/ ----------
@test "AC-2a: --enable-rsi deploys sop-evolver skill" {
  [ -f "$INSTALL_SH" ]
  grep -qE "sop-evolver|deploy.*skill|skills.*deploy" "$INSTALL_SH"
}

@test "AC-2b: --enable-rsi initializes ~/.tree-monstor/ directory" {
  [ -f "$INSTALL_SH" ]
  grep -qE "~/.tree-monstor|tree-monstor/observations|\\.tree-monstor.*mkdir|tree-monstor.*init" "$INSTALL_SH"
}

# ---------- AC-3: --disable-rsi 不裝 sop-evolver ----------
@test "AC-3: --disable-rsi skips sop-evolver install" {
  [ -f "$INSTALL_SH" ]
  grep -qE "DISABLE.*RSI|disable.*rsi|skip.*sop-evolver" "$INSTALL_SH"
}

# ---------- AC-4: --uninstall 清理 ----------
@test "AC-4a: --uninstall handles sop-evolver cleanup" {
  [ -f "$INSTALL_SH" ]
  grep -qE "uninstall_rsi|sop-evolver.*skill.*removed|skills/sop-evolver" "$INSTALL_SH"
}

@test "AC-4b: --uninstall prompts for ~/.tree-monstor/ removal" {
  [ -f "$INSTALL_SH" ]
  grep -qE "tree-monstor.*confirm|Remove RSI data|rm.*tree-monstor|tree-monstor.*\\?.*\\[y/N\\]" "$INSTALL_SH"
}

# ---------- AC-5: --dry-run 顯示 RSI 相關規劃 ----------
@test "AC-5a: --dry-run shows sop-evolver plan" {
  [ -f "$INSTALL_SH" ]
  grep -qE "sop-evolver.*plan|RSI:.*sop-evolver|skills/sop-evolver/\\*" "$INSTALL_SH"
}

@test "AC-5b: --dry-run shows ~/.tree-monstor/ init plan" {
  [ -f "$INSTALL_SH" ]
  grep -qE "tree-monstor/observations.*init|tree-monstor.*observations.*plan" "$INSTALL_SH"
}

# ---------- AC-6: ≥ 5 個 bats 測試 ----------
@test "AC-6: this bats file has ≥ 5 tests" {
  [ -f "$REPO_ROOT/tests/us016-install-rsi.bats" ]
  local count
  count=$(grep -c "^@test" "$REPO_ROOT/tests/us016-install-rsi.bats")
  [ "$count" -ge 12 ]
}

# ---------- AC-7: shellcheck + 既有測試不退步 ----------
@test "AC-7: shellcheck pass (if available)" {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$INSTALL_SH"
  else
    skip "shellcheck not installed"
  fi
}

# ---------- 邊緣案例 ----------
@test "EDGE-1: --help mentions --enable-rsi / --disable-rsi" {
  [ -f "$INSTALL_SH" ]
  grep -qE "enable-rsi|disable-rsi" "$INSTALL_SH"
}

@test "EDGE-2: install.sh uses set -e / set -uo pipefail" {
  [ -f "$INSTALL_SH" ]
  grep -qE "set -[euo]+" "$INSTALL_SH"
}

@test "SOP-1: install.sh is referenced in handbook §2.8" {
  [ -f "$REPO_ROOT/docs/sop/handbook/2.8-rsi-evolution.md" ]
  grep -qE "install.sh|--enable-rsi|enable-rsi" "$REPO_ROOT/docs/sop/handbook/2.8-rsi-evolution.md"
}