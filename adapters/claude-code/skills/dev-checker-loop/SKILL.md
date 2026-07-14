---
name: dev-checker-loop
description: Tree Monstor dev-agent / checker-agent collaboration loop coordinated through a downstream project's docs/STATE.md. Triggers on dev-loop、dev checker loop、checker agent、雙 agent 開發、自動檢查循環、regression 開關 requests, or multi-item development needing a built-in quality gate. Dev agent implements with per-feature regression tests; an independent checker verifies with real evidence until all items are VERIFIED or escalation limits hit.
---

# Dev Checker Loop（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`/Users/apple/www/tree_monstor/skills/dev-checker-loop/SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — STATE.md format, regression switch + logs requirements, checker evidence rules, and escalation limits.
3. The loop is an additive layer on the normal dev flow, never a replacement for it.
