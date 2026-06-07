---
name: long-task-resilience
description: Proactive resilience for long-running dev tasks in Developer Profile. Use when (a) about to mutate files in a long-running dev task, (b) session context is filling up, (c) user reports context compaction / zombie session / interruption, (d) needing to resume a forked/interrupted task. Triggers pre-tool checkpointing, context-pressure monitoring, session-fork handoff, and recovery briefs.
---

# Long-Task Resilience (Developer Profile)

This skill solves the **root cause** of zombie sessions, context-compaction loops, and interruption loss in long-running development tasks. It provides **proactive** (not reactive) recovery so the user never has to manually intervene.

## When to use this skill

Load this skill when **any** of the following is true:

- You are about to call `write_file`, `patch`, or a destructive `terminal` command during a long-running task
- A session has accumulated >100 API calls or >150 messages
- The user reports "context compaction", "session stuck", "session 死咗", "中斷"
- A new session needs to continue work from an interrupted predecessor
- You are about to do something that might trigger a context-pressure fork

## The 4 components

### 1. Pre-Tool Checkpoint (`pre_tool_checkpoint.sh`)

**What it does**: Before any file-mutating tool call, snapshots the working directory to a git ref. If the mutation goes wrong, you can `git checkout refs/checkpoints/<dir>/<ts>` to revert.

**Why it exists**: Hermes 0.15.1's built-in `CheckpointManager` is configured (`enabled: true`) but **does not actually trigger** in Developer Profile — verified 2026-06-07. This hook is our safety net.

**How to use**:
```bash
# Before any write_file / patch / destructive terminal:
~/.hermes/profiles/developer/skills/long-task-resilience/scripts/pre_tool_checkpoint.sh \
  "$WORKDIR" "before write_file: $FILE_PATH"

# Parse the stdout (key=value):
#   STATUS=ok|skipped
#   CHECKPOINT_HASH=<7-char hash>
#   FILES_DIRTY=<count>
#   REF=refs/checkpoints/<dir>/<timestamp>
```

**Rollback** (if mutation goes wrong):
```bash
git checkout refs/checkpoints/<dir>/<timestamp> -- <file_path>
# OR restore whole workdir:
git checkout refs/checkpoints/<dir>/<timestamp>
```

### 2. Context-Pressure Monitor (`context_pressure_monitor.py`)

**What it does**: Polls `state.db` for active sessions. Uses multi-factor scoring (api_call_count, message_count, input_tokens) to determine context pressure. At warn (60-80%) writes a progress checkpoint; at crit (≥80%) writes a handoff file and queues a fork.

**Why it exists**: Replaces reactive zombie-killing with proactive forking. By the time a session is at 80% pressure, we already have a complete handoff ready.

**How to use**:
```bash
# One-shot (for cron / manual):
python3 ~/.hermes/profiles/developer/skills/long-task-resilience/scripts/context_pressure_monitor.py --once

# Dry-run to see what would happen:
python3 ... --once --dry-run
```

**Thresholds** (tunable in script):
- `WARN_API_CALLS = 100` — emit progress
- `CRIT_API_CALLS = 200` — save handoff, queue fork
- `WARN_MESSAGES = 150` / `CRIT_MESSAGES = 300` — secondary signals

**Output locations**:
- Progress: `~/.hermes/profiles/developer/task_state/<sid>.progress.json`
- Handoff: `~/.hermes/profiles/developer/handoffs/<sid>.handoff.md`
- Fork queue: `~/.hermes/profiles/developer/session_fork_queue.jsonl`

### 3. Session-Fork Processor (`process_fork_queue.py`)

**What it does**: Consumes the fork queue. For each pending session: archives it in `state.db` (`archived=1`), clears its thread routing, notifies the user via Discord. Then the gateway's next message on the thread will create a fresh session automatically.

**How to use**:
```bash
python3 ~/.hermes/profiles/developer/skills/long-task-resilience/scripts/process_fork_queue.py
```

**Important**: This is the "exit point" of the self-healing loop. Once a session is archived, it can no longer zombie. The handoff file is what the new session reads to continue.

### 4. Resume Command (`resume_task.py`)

**What it does**: When a new session needs to continue work, this script gathers **everything** the new agent needs:
1. Handoff markdown (what the old session was doing)
2. Progress checkpoint (machine-readable state)
3. `dev-task-state.md` (the WHAT/WHERE/WHO/HOW)
4. Last 20 git commits in the workdir
5. Last 10 entries from `.hermes-checkpoints.log`

**How to use**:
```bash
# Most recent handoff:
python3 ~/.hermes/profiles/developer/skills/long-task-resilience/scripts/resume_task.py latest

# Specific session:
python3 ... <session_id>

# Custom workdir (overrides auto-detect):
python3 ... <session_id> --workdir ~/www/my-project
```

The output is a **unified recovery brief** the agent reads to get fully back in context.

## The auto-loop (cron / daemon)

For continuous self-healing, run two cron jobs:

```bash
# Every 5 minutes: check context pressure, write handoffs at crit
*/5 * * * * python3 .../context_pressure_monitor.py --once

# Every 15 minutes: process pending forks (archive old sessions)
*/15 * * * * python3 .../process_fork_queue.py
```

Or use the macOS `launchd` plist for boot-time auto-start (see `templates/launchd.plist`).

## SOUL.md Rules (39-43) to add to Developer Profile

After installing this skill, add the following 紅線 to `SOUL.md`:

- **Rule 39**: Before `write_file` / `patch` / destructive `terminal` in a long task, MUST call `pre_tool_checkpoint.sh`
- **Rule 40**: When a session reaches 100 API calls, emit `📊 context_status` (in/out/msgs/api/pressure)
- **Rule 41**: When a session is at WARN or CRIT pressure, do NOT start new subagents — let it finish
- **Rule 42**: After any interruption > 5 minutes, MUST read the latest handoff before continuing
- **Rule 43**: Never manually delete a handoff file — let the cron archive them after resume is verified

## Pitfalls (things we learned the hard way)

1. **Hermes's `token_count` column is sparsely populated** — do not trust per-message token counts. Use `api_call_count` as the primary signal.
2. **Hermes's `input_tokens` is cumulative** — divide by `api_call_count` to get tokens-per-call, which is the real "context size" signal.
3. **`hermes checkpoints` CLI works but AIAgent doesn't trigger it** — the config flag `checkpoints.enabled: true` is read, but the tool_executor path that calls `ensure_checkpoint` is never reached in Developer Profile. Don't rely on it.
4. **`git checkout -` fails when no previous branch** — v1 of the hook had `set -e` abort because of this. Use `git stash push/pop` instead, which never touches HEAD.
5. **mtime-based "latest" can race** — when a monitor run creates both a handoff and a progress file in the same second, the handoff may sort before its progress. The resume script handles this by falling back to JSON, but it's a fragile UX.
6. **`session_fork_queue.jsonl` grows unbounded** — call `process_fork_queue.py` regularly; the script clears the queue after each successful fork.
7. **Discord bot token must be re-read from `.env`** — daemon processes don't inherit interactive-shell env vars. The `process_fork_queue.py` reads it from `~/.hermes/profiles/developer/.env` directly.
