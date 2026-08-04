---
name: dev-checker-loop
description: 內層 dev + checker 驗證 loop（merged into orchestrator skill）。本 adapter redirect 觸發 inner loop 模式 — 通過 `<repo-root>/skills/orchestrator/SKILL.md` 載入 canonical。Triggers on dev-loop、dev checker loop、checker agent、雙 agent 開發、自動檢查循環、regression 開關。
---

# Dev Checker Loop（Claude Code wrapper → redirects to orchestrator）

> **Status (2026-08-02):** The dev-checker-loop concept is **merged into the orchestrator skill**. This adapter is preserved so the `/dev-loop` slash command continues to work, but it now redirects to the unified orchestrator canonical which contains both outer loop (multi-subagent coordination) and inner loop (dev+checker verification) in one file.

This is a thin adapter. The canonical skill is:

**`../orchestrator/SKILL.md`** （相對本 adapter 檔案路徑）

1. Read the canonical orchestrator/SKILL.md in full before acting — it now contains the full inner loop pattern (Core rule, Agent roles, Regression harness, STATE.md contract, Loop lifecycle, Checker standards, Termination) plus the outer loop (Task Board, multi-role dispatch, Failure Policy).
2. Follow it exactly — STATE.md format, regression switch + logs requirements, checker evidence rules, and escalation limits.
3. The loop is an additive layer on the normal dev flow, never a replacement for it.
4. When user invokes `/dev-loop`, treat as "inner loop mode" of orchestrator — focus on per-work-item dev+checker iteration; outer loop multi-subagent coordination is invoked via `/orchestrator` or default path per AGENTS.md.
