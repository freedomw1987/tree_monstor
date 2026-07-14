---
name: existing-project-intake
description: Tree Monstor intake workflow for existing/inherited projects before continuing development. Triggers on taking over a project, continuing development where docs/tests/QA state is unknown, incomplete, or stale（接手現有專案、補 docs then continue、baseline audit、project intake）. Produces a source-first truthful docs baseline, QA/regression gap list, and a safe continuation plan.
---

# Existing Project Intake（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`/Users/apple/www/tree_monstor/skills/existing-project-intake/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — source/tests/config/git history are the evidence base, not stale docs.
3. Downstream-project rules (its own CLAUDE.md / docs) take precedence where they conflict; say so explicitly when they do.
