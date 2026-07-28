---
name: orchestrator
description: Tree Monstor Orchestrator — Coordinates all subagents, manages the task board, handles parallel/sequential execution, tracks dependencies and failures. The conductor of the development orchestra. Triggers on long multi-phase tasks, parallel subagent work, dependency tracking, or when 3+ subagents need coordination.
---

# Orchestrator（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`/Users/apple/www/tree_monstor/skills/orchestrator/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — keep the task board current; never lose a dependency.
3. Downstream-project rules (its own CLAUDE.md / docs) take precedence where they conflict; say so explicitly when they do.