---
name: agent-stuck-recovery
description: Recover when the main agent is stuck mid-task. Search or read_file loops expanding without progress, response is explanation-only, or user sends "stop" / single-letter cues. Ship a minimal real artifact (ADR, spec doc, config) within a HARD 4-5 tool call budget. Distinct from subagent timeouts and session interruptions, this covers the gap where the main agent is still LIVE but has lost forward motion.
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Agent Stuck Recovery

The gap between "subagent timed out" and "session was interrupted": the main agent is still running, the user is still waiting, but forward motion is lost. Tool calls are happening but no shipped work is being produced.

## When You Are In This State

Any ONE of these triggers the protocol:

- Search or read_file loop returns no useful state across 3+ iterations with growing keyword space
- Tool output totals balloon (1k then 5k then 20k) without any file written
- Response is over 500 words of explanation with 0 tool calls
- User has sent "stop" or single letter (A / B / C / X) or "Zombie?"
- Long silence then short message from user (they are tired, not negotiating)
- Working tree is empty but tool call count is over 10 for what should be a simple task
- **User picks an option in `clarify` but does NOT supply the follow-up details** (e.g. chose "SSH access" but never gave user@host) AND a follow-up `clarify` also times out → **STOP. You do not have the access to fix the bug. Ship a retro + archive any stale skill referencing the un-fixable system. Resume path = wait for access.** (2026-06-19 umac_ai lesson)

## Why Existing Skills Do Not Cover This

- `subagent-timeout-recovery` covers subagent death, not your own loop
- `interruption-recovery` covers session ended mid-task, not mid-task but LIVE
- `dev-task-memory` 紅線 24-32 covers compression, interruption, decision preservation, not search or recon loop expansion
- `context-summarizer` covers auto-compression on schedule, not on-demand stuck-state recovery
- `agent-stuck-recovery` (this skill) covers main agent LIVE but losing forward motion

The gap: main agent's own search, recon, or gen loops can run unbounded, especially when the LLM treats "I need more context" as forward motion. `dev-task-memory` 紅線 29 covers the CONTEXT COMPACTION loop specifically, not the more common search or recon loop case.

## Early Warning Signals (Detect BEFORE Full Stuck State)

**Day 14 lesson (2026-06-07)**: The session showed **two stacked `[CONTEXT COMPACTION —
REFERENCE ONLY]` headers** at the top of the latest user message before any forward motion was
emitted. This is **the leading edge of 紅線 29's compaction loop**, not the loop itself. Detecting
this earlier saves 3-5 tool calls and 5-10 minutes of confused work.

**3 leading signals** to watch for at the start of EVERY turn (after the user's message):

| Signal | Severity | What it means |
|--------|----------|---------------|
| Single `[CONTEXT COMPACTION]` header | 🟡 warn | Normal: gateway just compacted context. Read the handoff in the header, continue. |
| **Two stacked `[CONTEXT COMPACTION]` headers** | 🟠 crit | **The previous compaction didn't actually emit work** — the session is in 紅線 29 territory. Stop expanding the loop. |
| Header at top + assistant message itself opens with `[CONTEXT COMPACTION]` | 🔴 fail | Session is **already zombie** — the LLM is repeating the header as its own response. Emit sentinel, end session. |
| User message contains ONLY a todo list (no instruction) + multiple compaction headers | 🟠 crit | User pressed `/new` or session forked, but the *previous* session's todo is being carried forward. Ask for confirmation, don't burn tool calls on stale items. |

**Action when any of the above fires**:

1. **DO NOT** call more search / read / re-discover tools (that IS the loop)
2. **DO** emit a brief progress note (≤ 4 lines) summarizing what was actually done this session
3. **DO** ask user: "I see stacked compaction headers — recommend `/new` and a handoff doc. Want me
   to (A) continue here with the existing state, or (B) write a handoff and stop?"
4. If user picks B (or says single letter / 「之後」/ 「停」): write the handoff doc
   (`dev-task-memory/templates/handoff-doc-scaffold.md`), save state, print resume command, stop.

**Why this matters**: Without this detection, the agent treats stacked headers as just "more
context to read" and re-spends 5-10 tool calls re-discovering what it already knows. With it, the
agent recognizes the pattern in 1 turn and ships a real artifact instead.

**Cross-reference**: This complements `dev-task-memory` 紅線 29. 紅線 29 says *what to do when
already in compaction loop* (mark session ended, sentinel, load_state). This section says
*how to detect the loop's leading edge* (stacked headers) and *short-circuit* before full
stuck state.

## The Discipline: HARD BUDGET

Set a budget BEFORE the next tool call. State it. Do not exceed.

- 4-5 tool calls: recovery from stuck state (this skill)
- 10-15 tool calls: one focused normal task
- 30+ tool calls: subagent territory, delegate, do not go inline

When budget is exhausted: STOP. Commit what you have. Emit progress.

## The Recovery Procedure (4-5 Tool Calls Total)

Call 1: WRITE STATE. Update docs/_meta/dev-task-state.md OR terminal one-liner "I'm stuck on X. Will commit minimal spec in 3 calls."

Call 2: WRITE ARTIFACT. ADR or spec or config or docs entry. Use schema names from prior context. If 100% uncertain, write a SPEC with Open Questions, still real work.

Call 3: COMMIT. git add + commit, real file on disk.

Call 4: EMIT. One-paragraph final response with: what shipped (file path + commit SHA), what is parked, what user should validate.

The artifact MUST be real, not a plan. A 50-line ADR with open questions is real work. A "I will do X next session" message is not.

## Anti-Patterns (What NOT To Do)

- Run more search_files or read_file (that IS the loop)
- Ask user "should I do A or B" (they are frustrated, pick a reasonable default and ship)
- Write 5+ paragraphs explaining what went wrong (1 paragraph max)
- Promise "next session I will..." (commit something real NOW)
- Re-attempt the original task (that is why you are stuck)
- `git status` or filesystem explore to "understand the situation" (more recon = more loop)
- Give the user 4 options when they sent 1 letter

## User Cues That Trigger Recovery

- "stop" / "停" → STOP and ship → commit ADR or spec in 4 calls
- "Zombie?" → Agent stuck in tool loop → stop, emit sentinel, ship minimal
- Single letter A/B/C → Pick last option, execute, do not re-prompt → run the picked option, commit
- Long silence then short msg → Tired or over it → do not propose options, just do
- "park" / "later" / "之後" → Park task, write TODO → commit a TODO or ADR, do not keep doing
- "X 吧" where X is an option → Pick X and execute → no discussion, run X
- **User picks option in `clarify` BUT follow-up `clarify` for details times out** → Cannot proceed without access. **Ship a retro + mark stale skill as DEPRECATED in 4-5 calls, then stop.** Do NOT burn more tokens guessing what access they meant. (2026-06-19 umac_ai lesson: user picked "I know hosting, I'll supply access" but two 3-minute follow-ups timed out. Right move: write `/tmp/<project>_investigation/YYYY-MM-DD-<topic>-investigation.md` retro + add `> ⚠️ DEPRECATED <date>` banner to any loaded skill whose recipe references the broken infra. Memory for the next session; resume path printed for the user.)
- "完成？" (with question mark) sent after scope is already answered → **agent emitted a confirmation question when it should have started work**. Treat as single-letter cue. Do NOT re-clarify scope. Pick the most reasonable default and ship (4-5 calls max). Common cause: agent thinks it needs one more "sub-decision confirmation" (e.g. Q1 sub-decision) when the user has already greenlit the main scope. The fix is to: (a) bundle default sub-decisions into the same answer that picked the main scope, (b) state the default explicitly in the next message so user can correct if wrong, (c) start work in the same turn if reasonable. (2026-06-16 <project> Sprint 21 lesson — `A) 全部 5 個` was answered, then 1 more clarify for sub-decisions, then "完成？" arrived → should have just used defaults and started work.)

## Self-Detection (Stop The Loop Earlier)

After EVERY 3 search_files, ask yourself:

- Did any of these 3 return useful new state? Y or N
- Have I written any file in the last 5 calls? Y or N
- Is my last response over 300 words with 0 tool calls? Y or N

If 2 of 3 are "no / yes / yes", you are in the loop. Stop. Switch to the recovery procedure.

## What To Commit When Stuck (Even With Zero Context)

These are always-valid minimal artifacts:

1. ADR with open questions: `docs/architecture/NNNN-<topic>.md` with Context, Decision (placeholder), Open Questions (5 specific ones), Awaiting sign-off
2. `docs/_meta/dev-task-state.md` with explicit "Status: STUCK" + what was recon'd + next-session plan
3. docs/RETROSPECTIVE entry: `docs/retros/YYYY-MM-DD-<incident>.md` with what went wrong + lesson + prevention
4. Test stub: a `tests/X.test.ts` codifying the bug as a regression guard (see regression-guard skill)
5. Hygiene commit: `.gitignore`, config, docs lint fix, small but real progress

A real 50-line ADR beats a 2000-word explanation with no file.

## Verification After Recovery

- `git log --oneline -1` shows your new commit
- `git status --short` shows your changes are committed (or expected-untracked docs like `docs/_meta/*`)
- File you wrote exists with real content (not placeholder or TODO)
- Final response is under 200 words with file path, commit SHA, what user should validate

## Related Skills

- `dev-task-memory` 紅線 24-32 covers session and interruption recovery (different scenario)
- `subagent-timeout-recovery` covers subagent death (different scope)
- `interruption-recovery` covers session ended (different state)
- `regression-guard` for committing regression test stubs as recovery artifact

## When To Delegate Instead

If the original task is genuinely large (over 30 tool calls), do not try to fit it in 4-5 calls. Use the recovery procedure to commit a SPEC, then `delegate_task` the implementation to a subagent in a fresh session. The subagent gets clean context, you ship a real planning artifact, user gets forward motion.
