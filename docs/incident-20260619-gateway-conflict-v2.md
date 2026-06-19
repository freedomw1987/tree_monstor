# Incident Report v2 — 2026-06-19 ~14:55–17:05 — Developer Profile Streaming Loop

**Status**: 🟡 Open — Awaiting manual intervention
**Severity**: High (David 觀察到 developer profile agent 不斷 push 重覆 response)
**Reporter**: David Chu
**Operator**: developer profile (this session)
**Started**: 2026-06-19 ~14:55 (after incident v1 rollback paused, before launchctl restart)
**Detected**: 2026-06-19 ~16:00 ("不斷重複"睇下"")
**Documented**: 2026-06-19 ~17:05

---

## TL;DR

After incident v1 (14:00 — gateway conflict) was partially remediated (cron jobs
paused, but `launchctl bootstrap` blocked by Hermes security), the developer
profile gateway SIGTERM'd at 15:08:00 due to sustained high load (loadavg 6.56)
+ sub-agent timeout cascade. Gateway auto-resumed the same hang session
`20260619_140627_eaf0f6`, which had accumulated 50+ historical messages.
On every new user message, the agent sent a 500-13000 char response, and
Hermes 0.15.1's Discord streaming adapter split each response into 1-10 char
chunks that pushed repeatedly to the same thread — David saw continuous
"睇下" / fragmented response spam.

**Two distinct sub-issues**:

1. **Session auto-resume loop** — Hermes re-resumes a hang session on gateway
   restart instead of letting it die. The resumed session has stale state
   (52+ messages, 158k tokens) and produces excessive output.

2. **Discord streaming chunking bug** — Hermes 0.15.1 splits large responses
   into 1-10 char chunks and pushes each chunk via Discord API. With Discord's
   rate limits, this creates a visible "fragmented" effect (David saw "睇下"
   repeated).

**Immediate action** (David, manual):
- `kill -9 88441 88442` (or wait for gateway to stabilize)
- Discord `/new session` to escape the hang session

**Root cause** (most likely):
- R1 from v1 (kanban dispatcher conflict) is the trigger
- R2 from v1 (subagent_auto_approve runaway) is the amplifier
- New finding: R5 (session auto-resume doesn't validate state health)
- New finding: R6 (Discord streaming chunking 1-10 chars is too aggressive)

---

## Timeline (v1 → v2)

| Time (HKT) | Event |
|---|---|
| 2026-06-19 14:00 | Incident v1 detected — gateway "沒反應" |
| 2026-06-19 14:05 | Incident v1 report written: `docs/incident-20260619-gateway-conflict.md` |
| 2026-06-19 14:07 | Rollback plan Step 1-2 executed: cron jobs paused, config verified baseline |
| 2026-06-19 14:08 | Rollback plan Step 3: kill 2 gateway processes (PID 63743 + 65879) |
| 2026-06-19 14:09 | Rollback plan Step 4: `launchctl bootstrap` BLOCKED by Hermes security (timeout without consent) |
| 2026-06-19 14:10–14:55 | (Estimated) Gateway auto-restart via launchd — new PIDs spawned (likely PID 67533 developer, 85009 default) |
| 2026-06-19 14:35 | **Subagent 0 timed out after 600.1s** (40 API calls stuck on slow API) |
| 2026-06-19 14:35:46 | **Discord: 400 Bad Request (50006) "Cannot send an empty message"** (x2) — caused by session resume sending empty chunks |
| 2026-06-19 14:40 | David "修正吧" (re: incident v1) |
| 2026-06-19 14:41 | Memory tool errors (refusing to write, background review denied) |
| 2026-06-19 14:45 | Corrupted tool_call arguments repaired mid-flight |
| 2026-06-19 14:50 | Streaming failed after partial delivery, not retrying |
| 2026-06-19 14:55 | Session `20260619_140627_eaf0f6` continues running (125 tool turns, 56+ API calls) |
| 2026-06-19 14:57 | (New session `20260619_144659_8ce074` opened — likely auto-triggered) |
| 2026-06-19 15:00 | David "D" + "developer profile 出現不斷重覆的output" |
| 2026-06-19 15:03 | David "C" (probably selecting D option's C sub-step) |
| 2026-06-19 15:08:00 | **Gateway SIGTERM** (loadavg 6.56) — another restart cycle |
| 2026-06-19 15:08:22 | **Session `20260619_140627_eaf0f6` auto-resumes** — first API call after resume |
| 2026-06-19 15:08:26 | Hermes: "Suppressing normal final send ... final delivery already confirmed (streamed=True)" |
| 2026-06-19 15:08:48 | David "您指的ABCD是什麼" → response 470 chars |
| 2026-06-19 15:09:12 | David "C" → session continues |
| 2026-06-19 15:11 | (Likely) Agent sent 13339 char mega-response → Discord streaming bug fires |
| 2026-06-19 15:11:27 | "response ready: ... response=830 chars" — first chunk |
| 2026-06-19 15:12+ | **David observes "不斷重複'睇下'"** — Discord streaming chunking pushing 1-10 char fragments repeatedly |
| 2026-06-19 15:13–17:00 | David sends multiple "stop" / status messages; session continues responding |
| 2026-06-19 17:02 | Read-only audit: supervisor script still works, kanban has 0 active tasks |
| 2026-06-19 17:05 | This v2 report written |

---

## Evidence

### E1: Session auto-resume after gateway restart

```
14:55:16 — tool terminal completed (last activity of session 140627 before v1 incident)
15:08:00 — Gateway SIGTERM (loadavg 6.56, parent_pid=1)
15:08:22 — Session 140627 auto-resumes: "API call #1: model=MiniMax-M3 ... in=159755 out=289"
15:08:26 — "Suppressing normal final send for session agent:main:discord:thread:...
            final delivery already confirmed (streamed=True previewed=False
            content_delivered=True)"
```

**Interpretation**: When gateway restarted, Hermes automatically re-attached
to the existing session instead of starting a new one. The session state had
52+ messages + 158k tokens, but the session was effectively frozen. On auto-
resume, Hermes tried to "deliver the final response" that was already
streamed, which causes the streaming bug to fire repeatedly.

### E2: Discord streaming chunking 1-10 chars

```
15:11:26 — "send_message completed (0.75s, 129 chars)" — first chunk
15:12:00 — "Flushing text batch ... (1 chars)" — 1 char chunk
15:12:30 — "Flushing text batch ... (3 chars)" — 3 char chunk
15:13:00 — "Flushing text batch ... (10 chars)" — 10 char chunk
```

**Interpretation**: Hermes 0.15.1's Discord adapter (`plugins/platforms/
discord/adapter.py`) is splitting the 13339 char response into 1-10 char
batches. With Discord's rate limits, each batch push creates a visible
Discord message (or message edit). David sees "睇下" or fragments repeatedly
as each batch fires.

### E3: Discord 400 Bad Request on empty message

```
14:35:46 — ERROR [Discord] Failed to send: 400 Bad Request (50006):
            Cannot send an empty message
14:35:48 — ERROR [Discord] Failed to send: 400 Bad Request (50006):
            Cannot send an empty message
```

**Interpretation**: When a streaming chunk is empty (e.g. 0 chars), the
adapter tries to send it anyway, fails, and retries — adding to the spam.

### E4: State file write regression (from v1, still present)

```
gateway_state.json `updated_at`: 2026-06-19T05:50:49 (8+ hours stale)
gateway_state.json `start_time`: null
```

**Interpretation**: Hermes 0.15.1 has a state file write bug where the JSON
is not being updated on gateway restart / Discord event. This is a Hermes
internal bug, not caused by our config changes. **R3 from v1 still
unresolved.**

### E5: Two gateways still conflicting (from v1, not fixed)

```
PID 88441 — hermes gateway run --replace (default profile)
PID 88442 — hermes --profile developer gateway run --replace
```

**Interpretation**: Despite v1 rollback, both gateways are still running.
This is because launchd auto-restarted them after the v1 kill. The same
Discord shard conflict that caused v1 is still happening in v2.

### E6: Read-only audit confirms no kanban damage

```
$ python3 ~/.hermes/profiles/developer/scripts/subagent_supervisor.py --once
2026-06-19 17:02:22 [INFO] No active tasks — supervisor idle

$ sqlite3 ~/.hermes/kanban.db "SELECT status, COUNT(*) FROM tasks GROUP BY status;"
archived|1
```

**Interpretation**: Kanban state is clean. Only 1 archived task. No
running/blocked/ready tasks. The supervisor script is functional. The issue
is **purely Discord streaming + session auto-resume**, not kanban or
supervisor design.

---

## Suspected Root Causes (new + carried from v1)

### R5 (NEW): Session auto-resume doesn't validate state health
- **Symptom**: After gateway SIGTERM + restart, Hermes auto-resumes the
  existing session (with 50+ messages, 158k tokens) instead of marking it
  as dead and starting fresh
- **Effect**: User sees stale context, agent sends excessive response
- **Workaround**: David manually `/new session` to start a fresh thread
- **Permanent fix**: Hermes 0.15.1 upstream fix (out of our scope)

### R6 (NEW): Discord streaming chunking too aggressive
- **Symptom**: 13339 char response split into 1-10 char chunks, each pushed
  as separate Discord message
- **Effect**: User sees fragmented "睇下" spam
- **Workaround**: Set `display.streaming: false` in config to disable
  streaming (revert to non-streaming response delivery)
- **Permanent fix**: Hermes upstream fix in `plugins/platforms/discord/
  adapter.py` (out of our scope)

### R1–R4 (from v1, still relevant)
- **R1**: kanban dispatcher conflict (auto-dev Phase 1B config)
- **R2**: subagent_auto_approve runaway (auto-dev Phase 1A config)
- **R3**: state file write regression (Hermes internal bug)
- **R4**: 3 daemon concurrency (gateway + 2 cron) on same DB

---

## Mitigation Status

| Action | Status | Notes |
|---|---|---|
| Pause cron jobs | ✅ Done | `developer-cost-alarm-watchdog` + `developer-subagent-supervisor` paused |
| Rollback Phase 1 config | ✅ Done | Hermes auto-rolled-back; disk config = pre-Phase-1 baseline |
| Kill 2 conflict gateways | ✅ Done (v1) | But launchd auto-restarted → 2 new PIDs |
| Restart developer profile gateway | ❌ Blocked | `launchctl bootstrap` blocked by Hermes security (v1) |
| Kill 2 new conflict gateways | ❌ Blocked | Hermes blocks kill from within gateway process |
| `/new session` to escape hang | ⏳ David pending | Discord-side action, agent can't do |
| Rollback Phase 2C (AGENTS.md §0 session resume) | ⏳ Optional | Would prevent v2's auto-resume issue |
| Fix R6 streaming chunking | ⏳ Optional | `display.streaming: false` config change |

---

## What We Cannot Do (agent blocked)

- ❌ Kill gateway from within gateway (Hermes blocks with SIGTERM)
- ❌ `launchctl bootstrap/bootout` (Hermes security blocks with timeout)
- ❌ Modify `~/.hermes/hermes-agent/` source (out of scope per design doc)
- ❌ Pause the hang session from this agent (we ARE the hang session)

**We can do (read-only / non-destructive)**:
- ✅ Audit kanban / log / state.db (read-only)
- ✅ Run supervisor / cost alarm `python3 ... --once` (read-only)
- ✅ Update docs / write incident reports (file writes)
- ✅ Update memory with lessons (memory tool)
- ✅ Suggest David manual commands (no execution)

---

## Recommended Manual Steps (David)

### Step 1: Stop the streaming loop

Option A (preferred): Discord-side escape
```
1. Open Discord #home channel
2. Send /new session (or just /new)
3. Start a new thread
4. Old hang session stops receiving messages → loop dies
```

Option B (terminal):
```bash
# Find gateway PIDs
ps aux | grep -E "hermes.*gateway" | grep -v grep | awk '{print $2}'

# Kill them
kill -9 <PID_1> <PID_2>

# Wait, then restart cleanly
launchctl bootout gui/$(id -u)/com.hermes.gateway-developer 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.hermes.gateway-developer.plist
```

### Step 2: Verify clean state

```bash
ps aux | grep -E "hermes.*gateway" | grep -v grep
# Should show 1 gateway (developer profile only, default off)

tail -20 ~/.hermes/profiles/developer/logs/gateway.log
# Should show "Gateway running" with fresh timestamp
```

### Step 3: Confirm supervisor is paused (don't re-enable yet)

```bash
hermes cron list
# Both cost-alarm and subagent-supervisor should show "paused"
```

### Step 4: Wait for David to confirm before any re-apply

Per incident v1's re-apply plan, do NOT re-enable cron jobs or apply config
changes without David's explicit approval, with 30 min test windows between
each step.

---

## Future Prevention (when re-apply time comes)

### For R5 (session auto-resume)
- Set `session.auto_prune: true` in config (already in v1 baseline)
- Set `sessions.retention_days: 7` (currently 90) — older sessions auto-archived
- Don't apply Phase 2C's AGENTS.md §0 session resume handshake (it amplifies
  R5 by actively loading old session state)

### For R6 (Discord streaming)
- Set `display.streaming: false` to disable streaming
- Or set `discord.streaming: false` per-platform override
- This will deliver responses as single messages, not chunks

### For R1–R4 (from v1)
- Follow v1's incremental re-apply plan
- DO NOT apply `kanban.enabled: true` + `subagent_auto_approve: true` in
  the same step
- Test 30 min between each step

---

## Appendix A: Files Modified (this incident)

- `docs/incident-20260619-gateway-conflict.md` (v1, 14:05) — 271 lines
- `docs/incident-20260619-gateway-conflict-v2.md` (v2, 17:05) — this file

## Appendix B: Backup Files (preserved)

- `config.yaml.backup-auto-dev-20260619-085546` — pre-Phase-1
- `config.yaml.rollback-test-140754` — v1 rollback snapshot
- `config.yaml.broken-20260619-1400` — Hermes's own auto-rollback snapshot
  (contains our Phase 1 patches, useful for re-apply later)
- `AGENTS.md.backup-20260619-090029` — pre-Phase-2C
- `skills/context-summarizer/SKILL.md.backup-20260619-090003` — pre-Phase-2C
- `SKILL.md.backup-20260619-085924` (subagent-driven-development) — pre-Phase-2B

## Appendix C: Commits to Revert (if David decides)

- `6d99125` — auto-dev v0.5 (Phase 1A+1B+1C+1D+2A+2B+2C)
- `0e1e359` — subagent_supervisor (痛點四)

If we decide to git revert: `git revert 6d99125 0e1e359` (creates revert commits
rather than rewriting history — safer for shared branches).

Note: Skills (test-coverage-table, subagent-driven-development patch,
context-summarizer v2) are kept — they're pure doc/skill changes with no
runtime impact.

## Appendix D: Lessons Learned (2026-06-19)

1. **Apply config changes incrementally**, not in one big commit. The 4
   Phase 1 changes + cron activation all at once made root cause isolation
   hard.

2. **Launchd auto-restart is the silent killer**. Kill a gateway, it comes
   back. Need to either:
   - Disable launchd plist before killing
   - Use `launchctl kickstart -k` (kill+restart in one)

3. **Session auto-resume amplifies gateway failures**. A hang session that
   gets auto-resumed will keep spamming. Consider explicit `session.
   auto_prune: true` + 7-day retention.

4. **Discord streaming chunking 1-10 chars is a UX problem**. Even without
   hang sessions, large responses can fragment into many small Discord
   messages. Consider `display.streaming: false` for stability.

5. **Agent cannot fix infrastructure issues mid-incident**. The agent is
   *part of* the system that's failing. When David asks "點處理 / 你幫忙
   處理下", the agent should:
   - Run read-only diagnostics immediately
   - Document findings in incident report
   - Suggest manual commands David can run
   - NOT pretend to have more power than it has

_Recovery 2026-06-19 ~17:18 — David ran `kill -9 88441 88442` from terminal.
Both PIDs already dead ("no such process"). launchd auto-spawned new gateways
(PID 54270 default + 54275 developer) at 17:17. Gateway log shows clean
reconnect: "Gateway running with 1 platform(s) ... kanban dispatcher: embedded
in gateway". Both cron jobs (cost-alarm + subagent-supervisor) re-resumed at
17:12, ran auto-checks at 17:17, reported "No active tasks — supervisor idle"
and "0 events fired". State stable. Two-gateway conflict still present (not
fixed) but no observable impact._

---

_Draft 2026-06-19 ~17:05 — v2 incident, awaiting David manual intervention_
_Recovery added 2026-06-19 ~17:18 — incident closed, system stable_
