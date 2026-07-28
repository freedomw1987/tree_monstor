---
name: regression-guard
description: Tree Monstor regression-guard workflow — use for EVERY bug fix or regression-prone change. Triggers on recurring bugs（舊 bug 又出現、fix 完又壞、bug 翻發、regression）, RG-XXX entries, /__qa endpoints, REGRESSION_MODE, regression hooks/switches, qa:seed/qa:reset. Enforces red lines 13-15 and 53 — no merge without an RG entry containing root cause + prevention.
---

# Regression Guard（Claude Code wrapper）

This is a thin adapter. The canonical skill is:

**`<repo-root>SKILL.md`**

1. Read the canonical SKILL.md above in full before acting.
2. Follow it exactly — RG-XXX entry format, root cause + prevention sections, QA regression mode fields, and production safety boundaries.
3. Downstream-project rules (its own CLAUDE.md / docs) take precedence where they conflict; say so explicitly when they do.
