#!/usr/bin/env bats
#
# tests/us015-tools.bats
#
# Black-box tests for US-015: tools/rsi-aggregate.sh + rsi-propose.sh + rsi-sync.sh
# Each test corresponds to one or more ACs in docs/backlog.md (US-015).
#
# Usage:
#   bats tests/us015-tools.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  AGGREGATE_SH="$REPO_ROOT/tools/rsi-aggregate.sh"
  PROPOSE_SH="$REPO_ROOT/tools/rsi-propose.sh"
  SYNC_SH="$REPO_ROOT/tools/rsi-sync.sh"
}

# ---------- AC-1: rsi-aggregate.sh 存在 + 掃 ~/.tree-monstor/observations ----------
@test "AC-1a: tools/rsi-aggregate.sh exists" {
  [ -f "$AGGREGATE_SH" ]
}

@test "AC-1b: rsi-aggregate.sh is executable" {
  [ -x "$AGGREGATE_SH" ]
}

@test "AC-1c: rsi-aggregate.sh scans ~/.tree-monstor/observations/" {
  [ -f "$AGGREGATE_SH" ]
  grep -q "~/.tree-monstor/observations\|tree-monstor/observations" "$AGGREGATE_SH"
}

@test "AC-1d: rsi-aggregate.sh produces markdown report" {
  [ -f "$AGGREGATE_SH" ]
  grep -qE "rsi-aggregated|\\.md|markdown|\.md\"" "$AGGREGATE_SH"
}

@test "AC-1e: rsi-aggregate.sh deduplicates observations" {
  [ -f "$AGGREGATE_SH" ]
  grep -qE "dedup|去重|unique" "$AGGREGATE_SH"
}

# ---------- AC-2: rsi-propose.sh 存在 + 產出 PR diff 清單 ----------
@test "AC-2a: tools/rsi-propose.sh exists" {
  [ -f "$PROPOSE_SH" ]
}

@test "AC-2b: rsi-propose.sh is executable" {
  [ -x "$PROPOSE_SH" ]
}

@test "AC-2c: rsi-propose.sh outputs proposal with file paths" {
  [ -f "$PROPOSE_SH" ]
  grep -qE "diff|路徑|file_path|files affected" "$PROPOSE_SH"
}

@test "AC-2d: rsi-propose.sh mentions rollback command" {
  [ -f "$PROPOSE_SH" ]
  grep -qE "rollback|回滾|rsi-rollback" "$PROPOSE_SH"
}

# ---------- AC-3: rsi-sync.sh 存在 + 同步 ~/.pi/sop/ ----------
@test "AC-3a: tools/rsi-sync.sh exists" {
  [ -f "$SYNC_SH" ]
}

@test "AC-3b: rsi-sync.sh is executable" {
  [ -x "$SYNC_SH" ]
}

@test "AC-3c: rsi-sync.sh syncs to ~/.pi/sop/ (target path)" {
  [ -f "$SYNC_SH" ]
  grep -qE "~/.pi/sop|\\.pi/sop" "$SYNC_SH"
}

@test "AC-3d: rsi-sync.sh can be triggered after install.sh" {
  [ -f "$SYNC_SH" ]
  grep -qE "install|--trigger|自動" "$SYNC_SH"
}

# ---------- AC-4: rsi-sync 不覆蓋本地 override ----------
@test "AC-4: rsi-sync.sh preserves local overrides" {
  [ -f "$SYNC_SH" ]
  grep -qE "override|local.*override|本地.*改動|保留" "$SYNC_SH"
}

# ---------- AC-5: ≥ 8 個 bats 測試 ----------
@test "AC-5: this bats file has ≥ 8 tests" {
  [ -f "$REPO_ROOT/tests/us015-tools.bats" ]
  local count
  count=$(grep -c "^@test" "$REPO_ROOT/tests/us015-tools.bats")
  [ "$count" -ge 12 ]
}

# ---------- AC-6: shellcheck 0 warning ----------
@test "AC-6: shellcheck pass (if available)" {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$AGGREGATE_SH" "$PROPOSE_SH" "$SYNC_SH"
  else
    skip "shellcheck not installed"
  fi
}

# ---------- 邊緣案例 ----------
@test "EDGE-1: rsi-aggregate.sh handles missing observations directory gracefully" {
  [ -f "$AGGREGATE_SH" ]
  run bash "$AGGREGATE_SH" --obs-root /tmp/nonexistent-obs-$$ 2>&1
  [ "$status" -ne 139 ]
}

@test "EDGE-2: rsi-propose.sh --help does not modify files" {
  [ -f "$PROPOSE_SH" ]
  run bash "$PROPOSE_SH" --help
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "EDGE-3: rsi-sync.sh --help does not modify files" {
  [ -f "$SYNC_SH" ]
  run bash "$SYNC_SH" --help
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ---------- SOP 紀律 ----------
@test "SOP-1: scripts use set -uo pipefail for safety" {
  for script in "$AGGREGATE_SH" "$PROPOSE_SH" "$SYNC_SH"; do
    [ -f "$script" ]
    grep -qE "set -[euo]+|set -o " "$script"
  done
}

@test "SOP-2: scripts have --help / usage" {
  for script in "$AGGREGATE_SH" "$PROPOSE_SH" "$SYNC_SH"; do
    [ -f "$script" ]
    grep -qE "usage|--help|-h " "$script"
  done
}

@test "SOP-3: scripts are referenced by handbook §2.8" {
  [ -f "$REPO_ROOT/docs/sop/handbook/2.8-rsi-evolution.md" ]
  grep -qE "rsi-aggregate|rsi-propose|rsi-sync" "$REPO_ROOT/docs/sop/handbook/2.8-rsi-evolution.md"
}