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

# ---------- Skill references must use pi-recognised /skill:name form ----------
# pi does not parse Obsidian wiki-link syntax [[skills/...]]. See
# pi docs/skills.md#skill-commands: skills are invoked via /skill:name.
@test "SKILL-REF-1: AGENTS.md does not use Obsidian [[skills/...]] syntax" {
  ! grep -qE '\[\[skills/' "$REPO_AGENTS"
}

@test "SKILL-REF-2: every mandatory-skill-use line references a real /skill:<name> command" {
  # Each SOP step that says "務必使用" must point at a skill that actually
  # exists in skills/ (and therefore will be installed globally).
  installed=$(ls "$REPO_ROOT/skills" | sort -u)
  while IFS= read -r line; do
    [[ "$line" =~ /skill:([a-z-]+) ]] || {
      echo "FAIL: mandatory-use line missing /skill: reference: $line" >&2
      return 1
    }
    name="${BASH_REMATCH[1]}"
    if ! grep -Fxq "$name" <(echo "$installed"); then
      echo "FAIL: referenced skill not installed: $name" >&2
      return 1
    fi
  done < <(grep "務必使用" "$REPO_AGENTS")
}