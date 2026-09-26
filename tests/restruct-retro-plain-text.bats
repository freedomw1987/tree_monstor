#!/usr/bin/env bats
#
# tests/restruct-retro-plain-text.bats
#
# Regression guards for TMO-009 stage 11: retro-fix existing skills + AGENTS.md
# so all cross-file references are plain-text (skill-independent portability).

load 'helpers/test-env'

# All skills restructured in TMO-009 (stages 1-10) must have NO cross-dir
# markdown links and NO Obsidian cross-directory wiki links.

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

@test "RESTRUCT-RETRO: all skills have no cross-dir markdown links (../...)" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '\]\(\.\./' "$abs"; then
      echo "FAIL: $rel has cross-dir markdown link" >&2
      grep -nE '\]\(\.\./' "$abs" >&2
      return 1
    fi
  done
}

@test "RESTRUCT-RETRO: all skills have no docs/ markdown links" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '\]\(docs/' "$abs"; then
      echo "FAIL: $rel has docs/ markdown link" >&2
      grep -nE '\]\(docs/' "$abs" >&2
      return 1
    fi
  done
}

@test "RESTRUCT-RETRO: all skills have no Obsidian cross-dir wiki links" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '\[\[.*\.\./|\[\[docs/' "$abs"; then
      echo "FAIL: $rel has Obsidian cross-dir link" >&2
      grep -nE '\[\[.*\.\./|\[\[docs/' "$abs" >&2
      return 1
    fi
  done
}

@test "RESTRUCT-RETRO: AGENTS.md is the master index (links to handbook/gates.json are allowed)" {
  local agents="$REPO_ROOT/AGENTS.md"
  # AGENTS.md is NOT a skill; it's the master index for the whole repo
  # so links to docs/sop/handbook/... and docs/sop/gates.json are allowed
  # (v2.1 exception: master index file)
  [ -f "$agents" ] || { echo "FAIL: AGENTS.md missing" >&2; return 1; }
}

@test "RESTRUCT-RETRO: all 9 skills account for (no orphans)" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    [ -f "$abs" ] || { echo "FAIL: missing skill $rel" >&2; return 1; }
  done
}

@test "RESTRUCT-RETRO: SKILL.md files are reasonably sized (all < 300 lines)" {
  for rel in "${SKILLS[@]}"; do
    local abs="$REPO_ROOT/$rel"
    local lines
    lines=$(wc -l < "$abs")
    [ "$lines" -lt 300 ] || {
      echo "FAIL: $rel grew too large ($lines lines)" >&2
      return 1
    }
  done
}
