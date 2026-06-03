---
name: kanban-worker
description: Pitfalls, examples, and edge cases for Hermes Kanban workers. The lifecycle itself is auto-injected into every worker's system prompt as KANBAN_GUIDANCE (from agent/prompt_builder.py); this skill is what you load when you want deeper detail on specific scenarios — including the optional Codex lane pattern, reconciliation, and the `kanban_complete.metadata.codex_lane` schema.
version: 2.1.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [kanban, multi-agent, collaboration, workflow, pitfalls, codex, worktrees, autonomous-agents]
    related_skills: [kanban-orchestrator, codex, hermes-agent]
---

# Kanban Worker — Pitfalls and Examples

> You're seeing this skill because the Hermes Kanban dispatcher spawned you as a worker with `--skills kanban-worker` — it's loaded automatically for every dispatched worker. The **lifecycle** (6 steps: orient → work → heartbeat → block/complete) also lives in the `KANBAN_GUIDANCE` block that's auto-injected into your system prompt. This skill is the deeper detail: good handoff shapes, retry diagnostics, edge cases.

## Workspace handling

Your workspace kind determines how you should behave inside `$HERMES_KANBAN_WORKSPACE`:

| Kind | What it is | How to work |
|---|---|---|
| `scratch` | Fresh tmp dir, yours alone | Read/write freely; it gets GC'd when the task is archived. |
| `dir:<path>` | Shared persistent directory | Other runs will read what you write. Treat it like long-lived state. Path is guaranteed absolute (the kernel rejects relative paths). |
| `worktree` | Git worktree at the resolved path | If `.git` doesn't exist, run `git worktree add <path> ${HERMES_KANBAN_BRANCH:-wt/$HERMES_KANBAN_TASK}` from the main repo first, then cd and work normally. Commit work here. |

## Tenant isolation

If `$HERMES_TENANT` is set, the task belongs to a tenant namespace. When reading or writing persistent memory, prefix memory entries with the tenant so context doesn't leak across tenants:

- Good: `business-a: Acme is our biggest customer`
- Bad (leaks): `Acme is our biggest customer`

## Good summary + metadata shapes

The `kanban_complete(summary=..., metadata=...)` handoff is how downstream workers read what you did. Patterns that work:

**Coding task:**
```python
kanban_complete(
    summary="shipped rate limiter — token bucket, keys on user_id with IP fallback, 14 tests pass",
    metadata={
        "changed_files": ["rate_limiter.py", "tests/test_rate_limiter.py"],
        "tests_run": 14,
        "tests_passed": 14,
        "decisions": ["user_id primary, IP fallback for unauthenticated requests"],
    },
)
```

**Coding task that needs human review (review-required):**

For most code-changing tasks, the work isn't truly *done* until a human reviewer has eyes on it. Block instead of complete, with `reason` prefixed `review-required: ` so the dashboard surfaces the row as needing review. Drop the structured metadata (changed files, test counts, diff/PR url) into a comment first, since `kanban_block` only carries the human-readable reason — comments are the durable annotation channel. Reviewer either approves and runs `hermes kanban unblock <id>` (which re-spawns you with the comment thread for any follow-ups) or asks for changes via another comment.

```python
import json

kanban_comment(
    body="review-required handoff:\n" + json.dumps({
        "changed_files": ["rate_limiter.py", "tests/test_rate_limiter.py"],
        "tests_run": 14,
        "tests_passed": 14,
        "diff_path": "/path/to/worktree",  # or PR url if pushed
        "decisions": ["user_id primary, IP fallback for unauthenticated requests"],
    }, indent=2),
)
kanban_block(
    reason="review-required: rate limiter shipped, 14/14 tests pass — needs eyes on the user_id/IP fallback choice before merging",
)
```

Use `kanban_complete` only when the task is genuinely terminal — e.g. a one-line typo fix, a docs change with no functional consequences, or a research task where the artifact IS the writeup itself.

**Research task:**
```python
kanban_complete(
    summary="3 competing libraries reviewed; vLLM wins on throughput, SGLang on latency, Tensorrt-LLM on memory efficiency",
    metadata={
        "sources_read": 12,
        "recommendation": "vLLM",
        "benchmarks": {"vllm": 1.0, "sglang": 0.87, "trtllm": 0.72},
    },
)
```

**Review task:**
```python
kanban_complete(
    summary="reviewed PR #123; 2 blocking issues found (SQL injection in /search, missing CSRF on /settings)",
    metadata={
        "pr_number": 123,
        "findings": [
            {"severity": "critical", "file": "api/search.py", "line": 42, "issue": "raw SQL concat"},
            {"severity": "high", "file": "api/settings.py", "issue": "missing CSRF middleware"},
        ],
        "approved": False,
    },
)
```

Shape `metadata` so downstream parsers (reviewers, aggregators, schedulers) can use it without re-reading your prose.

## Claiming cards you actually created

If your run produced new kanban tasks (via `kanban_create`), pass the ids in `created_cards` on `kanban_complete`. The kernel verifies each id exists and was created by your profile; any phantom id blocks the completion with an error listing what went wrong, and the rejected attempt is permanently recorded on the task's event log. **Only list ids you captured from a successful `kanban_create` return value — never invent ids from prose, never paste ids from earlier runs, never claim cards another worker created.**

```python
# GOOD — capture return values, then claim them.
c1 = kanban_create(title="remediate SQL injection", assignee="security-worker")
c2 = kanban_create(title="fix CSRF middleware", assignee="web-worker")

kanban_complete(
    summary="Review done; spawned remediations for both findings.",
    metadata={"pr_number": 123, "approved": False},
    created_cards=[c1["task_id"], c2["task_id"]],
)
```

```python
# BAD — claiming ids you don't have captured return values for.
kanban_complete(
    summary="Created remediation cards t_a1b2c3d4, t_deadbeef",  # hallucinated
    created_cards=["t_a1b2c3d4", "t_deadbeef"],                   # → gate rejects
)
```

If a `kanban_create` call fails (exception, tool_error), the card was NOT created — do not include a phantom id for it. Retry the create, or omit the id and mention the failure in your summary. The prose-scan pass also catches `t_<hex>` references in your free-form summary that don't resolve; these don't block the completion but show up as advisory warnings on the task in the dashboard.

## Block reasons that get answered fast

Bad: `"stuck"` — the human has no context.

Good: one sentence naming the specific decision you need. Leave longer context as a comment instead.

```python
kanban_comment(
    task_id=os.environ["HERMES_KANBAN_TASK"],
    body="Full context: I have user IPs from Cloudflare headers but some users are behind NATs with thousands of peers. Keying on IP alone causes false positives.",
)
kanban_block(reason="Rate limit key choice: IP (simple, NAT-unsafe) or user_id (requires auth, skips anonymous endpoints)?")
```

The block message is what appears in the dashboard / gateway notifier. The comment is the deeper context a human reads when they open the task.

## Heartbeats worth sending

Good heartbeats name progress: `"epoch 12/50, loss 0.31"`, `"scanned 1.2M/2.4M rows"`, `"uploaded 47/120 videos"`.

Bad heartbeats: `"still working"`, empty notes, sub-second intervals. Every few minutes max; skip entirely for tasks under ~2 minutes.

## Retry scenarios

If you open the task and `kanban_show` returns `runs: [...]` with one or more closed runs, you're a retry. The prior runs' `outcome` / `summary` / `error` tell you what didn't work. Don't repeat that path. Typical retry diagnostics:

- `outcome: "timed_out"` — the previous attempt hit `max_runtime_seconds`. You may need to chunk the work or shorten it.
- `outcome: "crashed"` — OOM or segfault. Reduce memory footprint.
- `outcome: "spawn_failed"` + `error: "..."` — usually a profile config issue (missing credential, bad PATH). Ask the human via `kanban_block` instead of retrying blindly.
- `outcome: "reclaimed"` + `summary: "task archived..."` — operator archived the task out from under the previous run; you probably shouldn't be running at all, check status carefully.
- `outcome: "blocked"` — a previous attempt blocked; the unblock comment should be in the thread by now.

## Notification routing

You can configure the gateway to receive cross-profile Kanban task notifications by adding `notification_sources` to `~/.hermes/config.yaml`.
- `notification_sources: ['*']` accepts subscriptions from all profiles.
- `notification_sources: ['default', 'zilor-ppt']` or `"default,zilor-ppt"` restricts subscriptions to specified profiles.
- Omitting the key keeps the default behavior (profile isolation).

## Do NOT

- Call `delegate_task` as a substitute for `kanban_create`. `delegate_task` is for short reasoning subtasks inside YOUR run; `kanban_create` is for cross-agent handoffs that outlive one API loop.
- Call `clarify` to ask the human a question. You are running headless — there is no live user to answer. The call will time out (default ~120s) and the task will sit silently in `running` with no signal that it needs input. Use `kanban_comment` (context) + `kanban_block(reason=...)` (decision needed) instead — the task surfaces on the board as blocked, the operator sees it, unblocks with their answer in a comment, and you respawn with the thread.
- Modify files outside `$HERMES_KANBAN_WORKSPACE` unless the task body says to.
- Create follow-up tasks assigned to yourself — assign to the right specialist.
- Complete a task you didn't actually finish. Block it instead.

## Pitfalls

**Task state can change between dispatch and your startup.** Between when the dispatcher claimed and when your process actually booted, the task may have been blocked, reassigned, or archived. Always `kanban_show` first. If it reports `blocked` or `archived`, stop — you shouldn't be running.

**Workspace may have stale artifacts.** Especially `dir:` and `worktree` workspaces can have files from previous runs. Read the comment thread — it usually explains why you're running again and what state the workspace is in.

**Don't rely on the CLI when the guidance is available.** The `kanban_*` tools work across all terminal backends (Docker, Modal, SSH). `hermes kanban <verb>` from your terminal tool will fail in containerized backends because the CLI isn't installed there. When in doubt, use the tool.

## CLI fallback (for scripting)

Every tool has a CLI equivalent for human operators and scripts:
- `kanban_show` ↔ `hermes kanban show <id> --json`
- `kanban_complete` ↔ `hermes kanban complete <id> --summary "..." --metadata '{...}'`
- `kanban_block` ↔ `hermes kanban block <id> "reason"`
- `kanban_create` ↔ `hermes kanban create "title" --assignee <profile> [--parent <id>]`
- etc.

Use the tools from inside an agent; the CLI exists for the human at the terminal.

## Optional integrations: Codex Lane

> **Heads up:** this section is the formerly-standalone `kanban-codex-lane` skill, absorbed here for discoverability. Skip it if you're not running Codex inside a worker run.

A worker may choose to spawn **Codex CLI as an implementation lane** for bounded coding, refactor, test, or mechanical-migration tasks. Hermes remains the task owner; Codex is an input lane only. This is **opt-in per task** — most workers never need it.

### When to use the Codex lane

Use it when **all** of these are true:

- The task is a coding, refactor, documentation, test, or mechanical-migration task with clear acceptance criteria.
- A bounded diff can be evaluated by Hermes in one run.
- The repo can be copied or checked out in an isolated git worktree/branch.
- Hermes can run the relevant tests itself after Codex exits.
- The prompt can state all safety constraints and files that must not change.

Skip it when any of these are true: the task needs human judgment not already in the body; the worker lacks repo access, Codex auth, or time to reconcile; the change touches secrets/credentials/private data/production order-entry; a small direct edit is faster and safer; the task is research-only; or the worker would be tempted to mark Done based only on Codex self-report.

### Ownership rules (the hard ones)

1. **Hermes owns the Kanban lifecycle.** Codex must never call `kanban_complete`, `kanban_block`, `kanban_create`, gateway messaging, or any Hermes board CLI as a substitute for the worker.
2. **Hermes owns final acceptance.** Treat Codex commits/diffs as untrusted patches until reviewed and verified.
3. **Hermes owns test execution.** Codex may run tests, but those runs are advisory; repeat required verification from Hermes with the repo's canonical wrapper.
4. **Hermes owns safety.** If Codex changes safety boundaries, risk gates, live trading behavior, or secrets handling, reject the lane even if tests pass.
5. **Hermes owns cleanup.** Kill stuck Codex processes and remove temporary worktrees when they are no longer needed.

### Required worktree and branch pattern

Never run Codex directly in a shared dirty checkout. Use a branch/worktree name that ties the lane to the Kanban task and keeps untrusted edits isolated.

```bash
TASK_ID="${HERMES_KANBAN_TASK:-t_manual}"
REPO="/path/to/repo"
BASE="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
SAFE_TASK="$(printf '%s' "$TASK_ID" | tr -cd '[:alnum:]_-')"
BRANCH="codex/${SAFE_TASK}/$(date -u +%Y%m%d%H%M%S)"
WORKTREE="/tmp/${SAFE_TASK}-codex-lane"

git -C "$REPO" fetch --all --prune
git -C "$REPO" worktree add -b "$BRANCH" "$WORKTREE" "$BASE"
git -C "$WORKTREE" status --short --branch
```

If the current Kanban workspace is already an isolated git worktree created for this task, you may create a sibling Codex branch inside it only if `git status --short` is clean except for intentional Hermes edits. Otherwise create a separate temporary worktree and cherry-pick or copy accepted commits back after reconciliation.

Cleanup after reconciliation:

```bash
git -C "$REPO" worktree remove "$WORKTREE"
git -C "$REPO" branch -D "$BRANCH"  # only after accepted commits were copied/cherry-picked or intentionally rejected
```

Keep the worktree if it's needed as an artifact for review; record it in `codex_lane.artifacts` and mention it in the handoff.

### Codex capability checks

Run these before spawning Codex. Missing Codex is a normal reason to skip the lane, not a task blocker if Hermes can do the task directly.

```bash
command -v codex
codex --version
codex features list | grep -i goals || true
```

If `/goal` support is required, enable or launch with the feature flag only after checking availability:

```bash
codex features enable goals || true
codex --enable goals --version
```

Authentication can be via `OPENAI_API_KEY` or the Codex CLI OAuth state (often `~/.codex/auth.json`). Do not print token files. A missing `OPENAI_API_KEY` is not proof that auth is unavailable.

### Mode selection

Use `codex exec` for bounded one-shot edits where Codex should exit on its own:

```python
terminal(
    command="codex exec --full-auto '$(cat /tmp/codex_prompt.md)'",
    workdir=WORKTREE,
    background=True,
    pty=True,
    notify_on_complete=True,
)
```

Use Codex `/goal` only for broader multi-step work that benefits from durable objective tracking. Launch interactively in a PTY/tmux session or with `codex --enable goals` if the feature is disabled by default. Keep the goal objective self-contained: repo path, task id, safety constraints, allowed scope, acceptance criteria, tests, and commit expectations.

Example `/goal` objective text to paste into Codex:

```text
/goal Work in this repository only: <WORKTREE>. Task: <TASK_ID> <TITLE>.
Hermes owns the Kanban lifecycle; do not call Hermes kanban tools or messaging.
Create small commits on branch <BRANCH>. Follow the PMB safety constraints in the prompt.
Run the requested verification commands and report exact outputs. Stop after producing a diff and summary.
```

Do not use `--yolo` for prediction-market-bot or safety-sensitive repos. Prefer `--full-auto` inside the isolated worktree, then rely on Hermes reconciliation.

### Prompt construction

Use the linked template at `templates/pmb-codex-lane-prompt.md` for prediction-market-bot work. For other repos, keep the same structure and replace the PMB-specific safety block with repo-specific invariants.

Every Codex prompt must include:

- `task_id`, title, and full Kanban acceptance criteria.
- Repo path, worktree path, branch name, and allowed file scope.
- Explicit statement: Hermes owns Kanban lifecycle; Codex is an input lane only.
- Required output: concise summary, files changed, commits, tests run, and known risks.
- Prohibited actions: secrets access, external messaging, board mutation, unrelated refactors, dependency upgrades unless required.
- Verification commands Codex may run and commands Hermes will run afterward.

For PMB, include these mandatory safety constraints verbatim:

```text
PMB safety constraints:
- live-SIM is paper-only; do not add or enable live REST order entry.
- Never use market orders.
- Do not add execution crossing or bypass price/risk checks.
- Do not fake passive fills, fills, PnL, order states, or reconciliation evidence.
- Do not weaken risk gates, limits, kill switches, or fail-closed behavior.
- Keep research/selection outside the C++ hot path unless explicitly requested.
- Do not read, print, write, or require secrets/tokens/credentials.
```

### Monitoring, timeout, and kill behavior

Start long Codex lanes in the background with PTY and completion notification:

```python
result = terminal(
    command="codex exec --full-auto '$(cat /tmp/codex_prompt.md)'",
    workdir=WORKTREE,
    background=True,
    pty=True,
    notify_on_complete=True,
)
session_id = result["session_id"]
```

Monitor without interfering:

```python
process(action="poll", session_id=session_id)
process(action="log", session_id=session_id, limit=200)
process(action="wait", session_id=session_id, timeout=300)
```

Send a Kanban heartbeat every few minutes for lanes longer than two minutes, e.g. `kanban_heartbeat(note="Codex lane running in <WORKTREE>; waiting for tests/diff")`.

Kill conditions:

- No useful output for the task's remaining runtime budget.
- Codex requests secrets, production credentials, or external permissions.
- Codex attempts to modify files outside the worktree.
- Codex starts unrelated rewrites or dependency churn.
- Codex is still running near the worker timeout and no safe partial artifact exists.

Kill command:

```python
process(action="kill", session_id=session_id)
```

After kill, inspect `git status --short`, preserve useful patches only if safe, and record `codex_lane.result: timed_out` or `rejected` with a concrete `rejected_reason`.

### Reconciliation checklist

Hermes must perform this checklist before accepting any Codex lane result:

- [ ] `git -C <WORKTREE> status --short --branch` shows only expected files.
- [ ] `git -C <WORKTREE> diff --stat` and `git diff` were reviewed by Hermes.
- [ ] No secrets, credentials, generated caches, unrelated data, or local artifacts are included.
- [ ] PMB safety constraints were preserved: no live REST order entry, no market orders, no execution crossing, no fake passive fills/PnL, no risk-gate weakening, no secrets.
- [ ] Codex commits are small enough to cherry-pick or squash cleanly.
- [ ] Hermes ran the canonical tests itself, using `scripts/run_tests.sh` for Hermes Agent or the repo's documented wrapper for other repos.
- [ ] Any Codex-run tests are listed separately from Hermes-run tests.
- [ ] Accepted commits/diffs were applied to the Hermes-owned workspace/branch.
- [ ] Rejected or partial work has a concrete reason and artifact path if useful.

Acceptance outcomes:

- `accepted`: Codex diff/commits were reviewed, applied, and verified.
- `partial`: Some Codex work was accepted after edits or cherry-picks; rejected parts are documented.
- `rejected`: No Codex changes were accepted; reason is documented.
- `timed_out`: Codex exceeded the lane budget; useful artifacts may or may not exist.

### `kanban_complete` metadata schema for the Codex lane

Include this object under `metadata.codex_lane` for every task where the lane was considered. If Codex was not used, set `used: false` and explain why in `rejected_reason` or a sibling `notes` field.

```json
{
  "codex_lane": {
    "used": true,
    "mode": "exec | goal | skipped",
    "worktree": "/absolute/path/to/codex/worktree",
    "branch": "codex/t_caa69668/20260508100000",
    "command": "codex exec --full-auto ...",
    "result": "accepted | rejected | partial | timed_out",
    "accepted_commits": ["<sha1>", "<sha2>"],
    "rejected_reason": "empty when fully accepted; otherwise concrete reason",
    "tests_run": [
      {"command": "scripts/run_tests.sh tests/tools/test_x.py", "exit_code": 0, "owner": "hermes"},
      {"command": "codex-reported: npm test", "exit_code": 0, "owner": "codex"}
    ],
    "artifacts": ["/absolute/path/to/log-or-patch"]
  }
}
```

For tasks that intentionally skip Codex:

```json
{
  "codex_lane": {
    "used": false,
    "mode": "skipped",
    "worktree": null,
    "branch": null,
    "command": null,
    "result": "rejected",
    "accepted_commits": [],
    "rejected_reason": "Direct Hermes edit was smaller and safer than spawning Codex.",
    "tests_run": [],
    "artifacts": []
  }
}
```

### Codex lane pitfalls

1. Treating Codex self-report as verification. Always inspect the diff and rerun tests from Hermes.
2. Running Codex in the user's dirty main checkout. Always isolate in a worktree/branch.
3. Letting Codex own Kanban. Codex may summarize progress, but Hermes writes board state.
4. Forgetting PMB safety invariants in the prompt. Missing safety text is a lane setup failure.
5. Using `/goal` for quick edits. Prefer `codex exec` unless durable multi-step continuation is needed.
6. Killing a stuck lane without recording why. `rejected_reason` must explain the decision.
7. Accepting broad unrelated cleanup because tests pass. Reject or cherry-pick only the scoped changes.

### Codex lane verification checklist

- [ ] Codex was skipped or started only after `command -v codex`, `codex --version`, and optional goals feature checks.
- [ ] Codex ran only in an isolated worktree/branch.
- [ ] Prompt included task scope, ownership rules, PMB safety constraints when applicable, and verification commands.
- [ ] Hermes reviewed `git diff` and safety-sensitive files.
- [ ] Hermes ran canonical tests independently.
- [ ] `kanban_complete.metadata.codex_lane` follows the schema above.
- [ ] Temporary processes and unnecessary worktrees were cleaned up.

### Linked template

- `templates/pmb-codex-lane-prompt.md` — fillable Codex prompt template for prediction-market-bot work; for other repos, keep the same structure and replace the PMB safety block with the repo's invariants.
