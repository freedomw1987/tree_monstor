#!/usr/bin/env bats
#
# tests/v2-reduce-deliverables.bats
#
# Regression guards for SOP v2.0 "reduce deliverables" (TMO-008).
# These probes ensure the new "two-layer deliverable" rule is not
# silently reverted, and that deliverable.html / standalone reflection.md
# are no longer required.
#
# Gate 1 (TDD): RED → implement → GREEN.

load 'helpers/test-env'

# ---------------------------------------------------------------------------
# changelog v2.0
# ---------------------------------------------------------------------------

@test "CHANGELOG: v2.0 entry documents reduce deliverables rule" {
  local cl="$REPO_ROOT/docs/sop/handbook/changelog.md"
  assert_file_contains "$cl" "v2.0"
  assert_file_contains "$cl" "減法"
  assert_file_contains "$cl" "文件產出物精簡"
}

# ---------------------------------------------------------------------------
# dav-submitter: no longer mandates three-layer (md + html)
# ---------------------------------------------------------------------------

@test "DAV-SUBMITTER: skill no longer mandates three-layer deliverable" {
  local submitter="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  # v2.0: should be two-layer (對話 + Markdown), not three-layer
  # The old wording "三層產出物" should be gone (or replaced with "兩層")
  if grep -qF "三層產出物" "$submitter"; then
    echo "FAIL: dav-submitter still has '三層產出物' (should be removed in v2.0)" >&2
    return 1
  fi
  # Should explicitly mention two-layer or one-layer
  grep -qiF "兩層" "$submitter" || \
  grep -qiF "二層" "$submitter" || {
    echo "FAIL: dav-submitter should explicitly mention '兩層' or '二層'" >&2
    return 1
  }
}

@test "DAV-SUBMITTER: skill does not require HTML deliverable" {
  local submitter="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  # v2.0: HTML is optional / not required
  # Check that "必須" + "HTML" pattern is removed
  if grep -qE "必須.*HTML|HTML.*必須" "$submitter"; then
    echo "FAIL: dav-submitter still mandates HTML deliverable" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AGENTS.md / SOP handbook
# ---------------------------------------------------------------------------

@test "SOP: 2.5-submission.md self-check no longer requires HTML deliverable" {
  local sub="$REPO_ROOT/docs/sop/handbook/2.5-submission.md"
  # Self-check checklist items start with "- [ ]". The HTML item should NOT
  # appear in any checklist line (it's allowed in narrative/change notes).
  if grep -E '^- \[ \]' "$sub" | grep -qF "HTML"; then
    echo "FAIL: 2.5-submission.md self-check list still has an HTML item" >&2
    grep -E '^- \[ \]' "$sub" | grep "HTML" >&2
    return 1
  fi
}

@test "SOP: 2.4-reflection.md documents reflection-merged-into-deliverable rule" {
  local refl="$REPO_ROOT/docs/sop/handbook/2.4-reflection.md"
  # Should mention reflection is now part of deliverable.md
  grep -qiE "併入|deliverable.*reflection|reflection.*deliverable" "$refl" || {
    echo "FAIL: 2.4-reflection.md should document reflection-merged-into-deliverable rule" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Backlog
# ---------------------------------------------------------------------------

@test "BACKLOG: TMO-008 reduce deliverables entry exists" {
  local bl="$REPO_ROOT/docs/backlog.md"
  assert_file_contains "$bl" "TMO-008"
  assert_file_contains "$bl" "減法"
}
