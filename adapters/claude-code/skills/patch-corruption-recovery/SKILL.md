---
name: patch-corruption-recovery
description: Tree Monstor patch/edit corruption prevention and recovery — Triggers on bulk replace-all (any editor, including Claude Code Edit replace_all), regex edit failures, fuzzy-match mis-anchoring, syntax corruption after batch edits, broken patch attempts, mismatched braces after find/replace, mismatched indentation, and the git-restore + re-patch recovery workflow. Enforces "stop, restore, re-patch cleanly" before continuing any other edits.
---

# Patch Corruption Recovery（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`/Users/apple/www/tree_monstor/skills/patch-corruption-recovery/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — never trust another broken edit to fix a broken one.
3. Downstream-project rules (its own CLAUDE.md / docs) take precedence where they conflict; say so explicitly when they do.