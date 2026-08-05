---
name: orchestrator
description: Multi-subagent 協調（outer loop: task board + 跨 phase dependency）+ per-work-item dev+checker verification（inner loop: STATE.md + regression test）
tools: Read, Write, Edit, Bash, WebFetch
---

# Orchestrator — Multi-subagent coordination with dev+checker inner loop

**Use when**:
- Multi-phase project (Plan → BA → SA → Frontend/Backend → QA → Ship)
- Multi-item feature dev needing built-in quality gate
- High-failure-cost work (regression risk, production, security-sensitive)

**Two layers**:
- **Outer loop** = multi-subagent / multi-role / task board (`docs/task-board.md`)
- **Inner loop** = per-work-item dev+checker (`docs/STATE.md` + regression test)

**Workflow**:
1. Read orchestrator SKILL.md `Subagent trigger table` → 自動 dispatch 對應 role（CEO / BA / Designer / SA / Frontend / Backend / QA / ...）
2. Multi-role parallel dispatch via Agent tool calls
3. Each code work item → inner loop dev+checker iteration
4. Update docs/task-board.md + docs/STATE.md as coordination hub

**Default path**: For multi-item feature work, this skill is **default path** (not optional). Loop only adds two things on top of normal dev; original flow (red lines, Think/Plan, plan mode, skill routing) still apply inside.

**When NOT to use**:
- 1-2 line typo / config change
- Pure research / pure reading
- Single US change, unambiguous, low failure cost
- Environment broken (fix env first)