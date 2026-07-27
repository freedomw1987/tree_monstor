# Context Compression Subagent — Developer Profile

A proactive, automatic context-compression subagent for long-running development tasks in Developer Profile.

## The Problem

Long-running dev tasks accumulate context. When context fills up:

- The model starts emitting `[CONTEXT COMPACTION]` markers and zombie-loops
- Tokens cost money, latency, and response quality
- Sessions die right when they're most valuable (deep into a multi-step task)

Hermes 0.15.1 has built-in `compression.threshold: 0.30` (60K tokens) auto-trigger, but:

- Auto-compression is **silent** — David can't tell it's happening
- It doesn't preserve the structured decisions/goals/next-steps that matter
- For sessions with 200+ API calls, compression alone isn't enough — need to **fork** to a fresh session

## The Solution: 3-Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 1: SUMMARIZER (compression_summarizer.py)             │
│   - LLM-powered structured summary                           │
│   - 6 sections: Goal, Decisions, State, Next, Insights, Risks│
│   - Falls back to extractive (heuristic) if LLM unavailable  │
│   - Auto-detects Anthropic vs OpenAI endpoint format         │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ Layer 2: DECISION (compression_executor.py: get_pressure)   │
│   - Multi-factor pressure scoring (api + msg + tokens)       │
│   - pressure 0.85-1.20 → compress (cheap)                    │
│   - pressure > 1.20    → fork (compress can't save it)       │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ Layer 3: EXECUTOR (compression_executor.py: execute_compress)│
│   - Mark head messages active=0 (model won't see them)       │
│   - Insert summary as new system message                     │
│   - Update session.message_count                             │
│   - Write handoff file for /rollback safety                  │
│   - OR queue a fork (if pressure > 1.20)                     │
└──────────────────────────────────────────────────────────────┘
```

## When does it run?

### 1. Manual / On-Demand

```bash
# Compress a specific session
python3 <profile-root>/skills/interruption-recovery/scripts/compression_executor.py <session_id> [--force] [--dry-run]

# Auto-process all high-pressure sessions
python3 .../compression_executor.py auto
```

### 2. Scheduled (cron, recommended)

Already wired in `cron` job `e3bee8fc99f6` (every 5 min). Add the executor:

```bash
# Add to the existing cron job, or create a new one
# <historical 2026-07-25 retired: cron compression automation retired; Claude Code uses plan mode + session resume>
*/5 * * * * python3 .../compression_executor.py auto --json >> ~/.hermes/cron/output/long-task-resilience.log 2>&1
```

Or run a wrapper script that combines monitor + executor + fork processor:

```bash
python3 .../context_pressure_monitor.py --once && \
python3 .../compression_executor.py auto && \
python3 .../process_fork_queue.py
```

### 3. Agent-Triggered (manual call during a long task)

The agent itself can call the executor mid-task when it sees pressure rising:

```python
# In SOUL.md Rule 38: "Session > 100 API calls 主動 emit 📊 context_status"
# When pressure > 0.85, run:
subprocess.run(["python3", ".../compression_executor.py", current_session_id])
```

## What gets preserved vs. compressed?

```
BEFORE (118 messages, 60K+ tokens):
[1] system: You are a developer agent...
[2] user: Help me build CRM with 3 features
[3] assistant: Let me plan...
[4-100] assistant/tool: planning, exploring, file edits
[101-117] user/assistant: GP display work
[118] tool: tsc clean

AFTER compression:
[NEW] system: [CONTEXT COMPRESSION — Auto-generated summary]
[NEW] system:    Goal: CRM 3 features (CompanyAutocomplete refactor + GP display + Activity timeline)
[NEW] system:    Decisions: ... 6 sections ...
[NEW] system:    Current state: 134 messages, 47/74 API calls, 3.8M input tokens
[NEW] system:    Next: Add GP badge to line items
[119-134] PRESERVED VERBATIM (16 messages = 4 exchanges * 4 fallback)
```

**Net effect**: Same model call count, but context window drops from ~64K to ~10K. Model can keep going.

## Why LLM-powered (not just extractive)?

Tested both:
- **Extractive** (heuristic regex on `goal:` / `decided:` / `⚠️`): ~500 chars, miss context
- **LLM** (minimax-m3 via anthropic endpoint): ~5000 chars, captures actual decisions + reasoning

The 4-second LLM call is worth the 10× better summary quality. If the LLM call fails (rate limit, network), we **gracefully fall back** to extractive — never block.

## Threshold tuning

| Pressure | Action | When to use |
|----------|--------|-------------|
| 0.0-0.5  | No-op (healthy) | normal session |
| 0.5-0.85 | Warn (emit `📊 context_status`) | agent tells user "context filling up" |
| 0.85-1.20 | **Compress** (cheap, fast) | long task in progress |
| 1.20+    | **Fork** (compress can't save) | session too bloated |

These match Hermes's `compression.threshold: 0.30` (60K trigger) so we run BEFORE Hermes auto-compresses silently.

## Pitfalls (learned the hard way)

1. **The first version tried to call `https://api.minimax.io/chat/completions` → 404.**
   The correct endpoint is the **Anthropic-format** one at `/v1/messages` (URL contains `/anthropic`).
   Auto-detect via URL pattern.

2. **Default `minimax-m3` is wrong** — Developer Profile uses `MiniMax-M3` (3 dashes, different casing).
   Read model name from env, fallback to `MiniMax-M3`.

3. **`MINIMAX_URL` vs `MINIMAX_BASE_URL`** — env var names are inconsistent.
   Check both, profile env first then root env.

4. **Zombie sessions have very few user turns** — partition logic that snaps to user-turn
   boundary returns empty tail. Fallback: keep last 16 messages regardless.

5. **Hermes's `input_tokens` is cumulative** — divide by `api_call_count` to get
   tokens-per-call (the real "context size" signal).

6. **Compression is reversible** — original messages stay in DB with `active=0`.
   Handoff file documents the rollback SQL. Don't fear trying it.

## Related skills

- `interruption-recovery` — manual recovery after a crash
- `dev-task-memory` — long-term state for multi-session tasks
- `interruption-recovery` (parent skill) — pre-tool checkpoint + pressure monitor

The compression subagent is the **mid-task** layer of `interruption-recovery`.
