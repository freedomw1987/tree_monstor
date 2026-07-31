---
name: spec-driven-development
description: Tree Monstor foreground BA spec gate for every T2/T3 new feature or user-story request. Produces docs/specs/REQ-XXX/spec.md with atomic AC-XXX Given/When/Then criteria and tests.md with AC-to-RT-XXX mappings before Build. Quick fixes, read-only, QA-only and trivial ops are exempt; bug fixes use regression-guard. dev-checker-loop cannot close until every AC has real passing evidence.
---

# Spec-Driven Development（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`<repo-root>/skills/spec-driven-development/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly: the BA subagent is fresh, foreground, and blocking; no implementation starts before the spec gate is ready.
3. The gate is additive, never a replacement for downstream-project rules, task tiering, PRD / QA sync, verification, regression-guard, or dev-checker-loop.
