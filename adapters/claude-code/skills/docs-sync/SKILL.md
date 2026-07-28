---
name: docs-sync
description: Tree Monstor docs-sync workflow — Synchronizes review feedback, QA findings, user corrections, and code-review suggestions into durable project docs before Build, merge, or ship. Triggers after any Review/Test/QA/user feedback that changes requirements, design, API, architecture, tests, regression behavior, or tech debt. Prevents drift where feedback lives only in chat or PR comments.
---

# Docs Sync（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`/Users/apple/www/tree_monstor/skills/docs-sync/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — feedback that only lives in chat is not resolved.
3. Downstream-project rules (its own CLAUDE.md / docs) take precedence where they conflict; say so explicitly when they do.