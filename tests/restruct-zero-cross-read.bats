#!/usr/bin/env bats
#
# tests/restruct-zero-cross-read.bats
#
# v2.2 zero-tolerance rule for cross-directory "read" references in skills:
# skills must not contain references like "見 docs/...", "讀 docs/...", or
# "讀 other-skill" because skills must be independently movable.
#
# docs/ is allowed as a WRITE destination (project convention).
# But READING from docs/ or other skill directories breaks portability.

load 'helpers/test-env'

# Skills covered (excluding dav-designer which is intentionally unchanged)
SKILLS=(
  "skills/dav-planner/SKILL.md"
  "skills/dav-reflection/SKILL.md"
  "skills/dav-submitter/SKILL.md"
  "skills/dav-trust/SKILL.md"
  "skills/dav-skill-creater/SKILL.md"
  "skills/dav-wiki/SKILL.md"
  "skills/regression-guard/SKILL.md"
  "skills/tdd-test-writer/SKILL.md"
  "skills/dev-checker-loop/SKILL.md"
)

@test "ZERO-CROSS-READ: no skill says 'read docs/backlog.md'" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '讀 `?docs/backlog\.md' "$abs"; then
      echo "FAIL: $rel reads docs/backlog.md directly" >&2
      grep -nE '讀 `?docs/backlog\.md' "$abs" >&2
      return 1
    fi
  done
}

@test "ZERO-CROSS-READ: no skill says 'see docs/...' for cross-file reference" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    # Look for "見 docs/..." or "詳見 docs/..." or "見 (docs/..." patterns
    if grep -qE '(見|詳見|詳閱|參考|讀) `?docs/' "$abs"; then
      echo "FAIL: $rel has cross-file 'read docs/' reference" >&2
      grep -nE '(見|詳見|詳閱|參考|讀) `?docs/' "$abs" >&2
      return 1
    fi
  done
}

@test "ZERO-CROSS-READ: no skill says 'see other-skill/SKILL.md'" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    # Look for cross-skill markdown references: "見 `skills/other-skill/..."
    # Excludes same-dir subfiles (./template.md, ./examples.md)
    if grep -qE '(見|詳見|詳閱|參考) `?skills/' "$abs"; then
      # But ./skills/X is OK if it's just describing own skill location
      local hits
      hits=$(grep -nE '(見|詳見|詳閱|參考) `?skills/' "$abs" | grep -vE '`\./skills/' || true)
      if [ -n "$hits" ]; then
        echo "FAIL: $rel references other-skill" >&2
        echo "$hits" >&2
        return 1
      fi
    fi
  done
}

@test "ZERO-CROSS-READ: no skill says 'read tests/...'" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '(讀|見|詳見) `?tests/' "$abs"; then
      echo "FAIL: $rel references tests/ directory" >&2
      grep -nE '(讀|見|詳見) `?tests/' "$abs" >&2
      return 1
    fi
  done
}

@test "ZERO-CROSS-READ: dav-skill-creater documents v2.2 rule" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # v2.2: should document zero-tolerance for cross-dir read references
  grep -qE "v2\.2|跨.*讀|zero-tolerance|0 容忍" "$skill" || {
    echo "FAIL: dav-skill-creater should document v2.2 cross-read rule" >&2
    return 1
  }
}

@test "ZERO-CROSS-READ: dav-wiki marks [[xxx]] as teaching example (not link)" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  # dav-wiki has [[xxx]] examples for Obsidian bidirectional linking
  # v2.2: should mark them as teaching examples, not actual links
  # Check that context around [[xxx]] mentions "教學" or "example"
  grep -B1 -A1 '\[\[xxx\]\]' "$skill" | grep -qiE "教學|example|範例" || {
    echo "FAIL: dav-wiki [[xxx]] should be marked as teaching example" >&2
    return 1
  }
}
