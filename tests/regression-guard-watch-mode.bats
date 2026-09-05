#!/usr/bin/env bats
#
# tests/regression-guard-watch-mode.bats
#
# Regression tests for the "test commands must disable watch / interactive
# mode" rule (added v1.3). Ensures the rule is documented in all three places
# that an agent reads when running Gate 3:
#
#   1. skills/regression-guard/SKILL.md  (the skill body)
#   2. docs/sop/gates.json               (Gate 3 definition, single source)
#   3. docs/sop/handbook/2.3-execution.md (the human-readable explanation)
#
# If any of these drop the rule, an agent may invoke a watch-mode test runner
# and freeze the session (the symptom that motivated this rule: the
# "Waiting for task" screenshot). These tests guard against that.

setup() {
  load 'helpers/test-env'
  # REPO_ROOT is set by helpers/test-env.bash — do NOT recompute via
  # ${BASH_SOURCE[0]}, which inside a bats setup() may point at a
  # temporary copy of the test file.
}

# ---------- regression-guard SKILL.md ----------
@test "SKILL: regression-guard documents the watch-mode rule" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "測試指令執行規範"
  assert_file_contains "$f" "禁用 interactive / watch"
  assert_file_contains "$f" "vitest run"
  assert_file_contains "$f" "jest --ci"
  assert_file_contains "$f" "< /dev/null"
}

@test "SKILL: regression-guard has a fail-fast self-check section" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "Fail-fast 自檢"
  assert_file_contains "$f" "Watch Usage"
}

# ---------- gates.json (Gate 3 single source) ----------
@test "GATES: gates.json Gate 3 notes mention watch-mode rule" {
  local f="$REPO_ROOT/docs/sop/gates.json"
  # Use python so we get a real JSON parse + path navigation
  python3 - "$f" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
gates = data["gates"]
gate3 = next((g for g in gates if g["id"] == "gate-3"), None)
assert gate3 is not None, "gate-3 not found in gates.json"
notes = gate3.get("notes", "")
assert "watch" in notes.lower() or "interactive" in notes.lower(), \
    f"Gate 3 notes should mention watch/interactive mode. Got: {notes!r}"
assert "regression-guard" in notes, \
    f"Gate 3 notes should cross-ref regression-guard SKILL.md. Got: {notes!r}"
PY
}

# ---------- handbook 2.3-execution.md ----------
@test "HANDBOOK: 2.3-execution.md has the watch-mode warning section" {
  local f="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  assert_file_contains "$f" "Gate 3 測試指令的常見陷阱"
  assert_file_contains "$f" "vitest"
  assert_file_contains "$f" "< /dev/null"
}

# ---------- Cross-consistency ----------
@test "CROSS: all three documents agree on the < /dev/null universal fallback" {
  local skill="$REPO_ROOT/skills/regression-guard/SKILL.md"
  local handbook="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  assert_file_contains "$skill" "< /dev/null"
  assert_file_contains "$handbook" "< /dev/null"
}
