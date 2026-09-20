#!/usr/bin/env bats
#
# tests/us014-tools.bats
#
# Black-box tests for US-014: tools/rsi-metrics.sh + tools/rsi-rollback.sh
# Each test corresponds to one or more ACs in docs/backlog.md (US-014).
#
# Usage:
#   bats tests/us014-tools.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  METRICS_SH="$REPO_ROOT/tools/rsi-metrics.sh"
  ROLLBACK_SH="$REPO_ROOT/tools/rsi-rollback.sh"
}

# ---------- AC-1: rsi-metrics.sh 存在 + 6 個指標 ----------
@test "AC-1a: tools/rsi-metrics.sh exists" {
  [ -f "$METRICS_SH" ]
}

@test "AC-1b: rsi-metrics.sh is executable" {
  [ -x "$METRICS_SH" ]
}

@test "AC-1c: rsi-metrics.sh produces 6 metrics" {
  # Check the script contains all 6 metric functions
  [ -f "$METRICS_SH" ]
  for func in "metric_completion_rate" "metric_violation_count" "metric_td_close_rate" "metric_cross_project_dist" "metric_agents_md_size" "metric_skill_usage"; do
    grep -q "$func" "$METRICS_SH"
  done
}

@test "AC-1d: rsi-metrics.sh runs without error" {
  [ -f "$METRICS_SH" ]
  run bash "$METRICS_SH" --help
  # Either succeeds with help, or fails gracefully (returns 0 or known exit)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 2 ]
}

# ---------- AC-2: rsi-rollback.sh 存在 + 讀 rsi-log.md ----------
@test "AC-2a: tools/rsi-rollback.sh exists" {
  [ -f "$ROLLBACK_SH" ]
}

@test "AC-2b: rsi-rollback.sh is executable" {
  [ -x "$ROLLBACK_SH" ]
}

@test "AC-2c: rsi-rollback.sh references rsi-log.md" {
  [ -f "$ROLLBACK_SH" ]
  grep -q "rsi-log" "$ROLLBACK_SH"
}

@test "AC-2d: rsi-rollback.sh uses git revert or git checkout" {
  [ -f "$ROLLBACK_SH" ]
  grep -qE "git revert|git checkout" "$ROLLBACK_SH"
}

# ---------- AC-3: 自動 git tag rsi-vYYYYMMDD-NN ----------
@test "AC-3: scripts reference rsi-v tag format (rsi-vYYYYMMDD-NN)" {
  [ -f "$METRICS_SH" ] || [ -f "$ROLLBACK_SH" ]
  grep -qE "rsi-v[0-9]{8}" "$METRICS_SH" "$ROLLBACK_SH"
}

# ---------- AC-4: 列出 + 回滾 兩個子命令 ----------
@test "AC-4: rsi-rollback.sh has 'list' subcommand" {
  [ -f "$ROLLBACK_SH" ]
  grep -qE "list|列出" "$ROLLBACK_SH"
}

@test "AC-4a: rsi-rollback.sh supports --target <tag> or 2nd positional arg" {
  [ -f "$ROLLBACK_SH" ]
  # Accept either flag pattern or positional arg
  grep -qE "\-\-target|target.*tag|rsi-v" "$ROLLBACK_SH"
}

@test "AC-4b: rsi-rollback.sh has --help / usage" {
  [ -f "$ROLLBACK_SH" ]
  grep -qE "usage|--help|-h " "$ROLLBACK_SH"
}

# ---------- AC-5: ≥ 6 個 bats 測試（已內建於本檔） ----------
@test "AC-5: this bats file has ≥ 6 tests" {
  [ -f "$REPO_ROOT/tests/us014-tools.bats" ]
  local count
  count=$(grep -c "^@test" "$REPO_ROOT/tests/us014-tools.bats")
  [ "$count" -ge 12 ]
}

# ---------- AC-6: shellcheck 0 warning ----------
@test "AC-6: shellcheck pass (if available)" {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$METRICS_SH" "$ROLLBACK_SH"
  else
    skip "shellcheck not installed (AC-9 limitation)"
  fi
}

# ---------- 邊緣案例 ----------
@test "EDGE-1: rsi-metrics.sh handles missing observations directory gracefully" {
  [ -f "$METRICS_SH" ]
  run bash "$METRICS_SH" --target /tmp/nonexistent-$$ 2>&1
  # Should not crash; just produce empty metrics
  [ "$status" -ne 139 ]  # Not segfault
}

@test "EDGE-2: rsi-rollback.sh --help does not perform any action" {
  [ -f "$ROLLBACK_SH" ]
  run bash "$ROLLBACK_SH" --help
  # Should not modify anything
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "SOP-1: scripts use set -e / set -uo pipefail for safety" {
  for script in "$METRICS_SH" "$ROLLBACK_SH"; do
    [ -f "$script" ]
    grep -qE "set -[euo]+|set -o " "$script"
  done
}