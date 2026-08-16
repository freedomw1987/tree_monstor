#!/usr/bin/env bats
#
# tests/agents-md.bats
#
# Black-box tests for tree_monstor/AGENTS.md and SOUL.md consistency.
# Ensures pi will actually load the soul principles at startup
# (since pi does NOT read SOUL.md — see pi docs/usage.md:100).

setup() {
  load 'helpers/test-env'
  REPO_AGENTS="$REPO_ROOT/AGENTS.md"
  REPO_SOUL="$REPO_ROOT/SOUL.md"
}

# ---------- All SOUL bullets must be inlined into AGENTS.md ----------
@test "SOUL-1: every SOUL.md bullet appears verbatim in AGENTS.md" {
  while IFS= read -r bullet; do
    [[ -z "$bullet" ]] && continue
    grep -F -q -- "$bullet" "$REPO_AGENTS" || {
      echo "FAIL: missing bullet in AGENTS.md: $bullet" >&2
      return 1
    }
  done < <(grep -E '^- ' "$REPO_SOUL")
}

@test "SOUL-2: AGENTS.md does not reference [[SOUL]] (Obsidian-only syntax)" {
  ! grep -q '\[\[SOUL' "$REPO_AGENTS"
}

@test "SOUL-3: AGENTS.md has the same bullet count in the principles section as SOUL.md" {
  soul_count=$(grep -cE '^- ' "$REPO_SOUL")
  # Count bullets in the 萬事原則 section of AGENTS.md only.
  agents_count=$(awk '/^\*\*萬事原則/,/^> 註：/' "$REPO_AGENTS" | grep -cE '^- ')
  [ "$soul_count" -eq "$agents_count" ]
}

@test "SOUL-4: AGENTS.md explicitly notes that pi does not read SOUL.md" {
  grep -F -q "pi 不會讀" "$REPO_AGENTS"
}