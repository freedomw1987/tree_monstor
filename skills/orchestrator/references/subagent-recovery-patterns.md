# Subagent recovery patterns

> Compact patterns folded from the now-archived
> `skills/autonomous-ai-agents/agent-stuck-recovery/` and
> `skills/general/subagent-timeout-recovery/`. Full source preserved in
> `archive/skills/`.

## 1. Trust-but-verify on `status: completed`

Subagent summary is **self-report, not verified fact**. Before reporting back to user, parent must verify in 3 quick steps (≤ 5 minutes):

1. **Typecheck yourself** — don't trust subagent's `exit_code 0` claim (buffer can be stale). Run `bun run typecheck` (or equivalent) with `timeout=120`.
2. **Grep random files** for key symbols (e.g. `Dialog`, `onSaved`, `useState`) — confirm subagent's writes actually landed on host filesystem (subagent workdir may differ).
3. **Smoke-test DB-touching changes** with a real query (`docker exec <db> psql` or node script in api container). Schema drift won't surface at typecheck stage.

Anti-pattern: pushing verification back to David ("browser test it and tell me") → wastes a round-trip; parent must verify the key invariant itself.

## 2. Early-stop signals for subagent typecheck loops

Don't wait the full 600s timeout. Kill + take over at ~350s if you see:

- API calls > 50 AND subagent still in `tsc --noEmit` / `bun run build` retry loop
- 3+ distinct `TSxxxx: ...` errors repeating
- Core file changes already complete (`git status` shows 4/4 files modified)

**Root cause** of these loops: subagent hits first type error → adds `as never` / `as any` cast → next type error surfaces → repeat. Subagent can't distinguish "critical fix" vs "nice-to-have cast"; you can.

**Subagent prompt must include** (preventive):

> "typecheck once-fail → report, don't chase连环 cast; use `terminal(timeout=120)`; API calls > 50 self-stop."

## 3. Subagent timeout ≠ 0 output

Partial complete is the norm. Recovery procedure:

1. `find <projects-dir>/<project> -type f` — see what landed
2. Spot-check config files: `package.json` scripts, `vite.config.ts` proxy, `tailwind.config.js`, `tsconfig.json`
3. Start backend + frontend, `curl` health endpoints
4. Quick code spot-check: API routes complete? TypeScript types match? Frontend API call URLs correct?
5. Read + patch (don't rewrite) any issues found

**Don't re-delegate** — same prompt will hit same wall. **Take over** directly.

## 4. Stuck main-agent detection (pre-fail signals)

The agent is stuck (not just slow) when ANY of:

- Search/read loop: 3+ iterations returning no useful state with expanding keyword space
- Tool output totals balloon (1k → 5k → 20k) with 0 files written
- Response > 500 words of explanation with 0 tool calls
- User sent "stop" / single letter / "Zombie?"
- Working tree empty but > 10 tool calls on what should be a simple task
- Two stacked `[CONTEXT COMPACTION]` headers in user message (leading edge of 紅線 29)

## 5. Stuck-recovery procedure (HARD 4-5 call budget)

1. **WRITE STATE** — update `docs/_meta/dev-task-state.md` OR terminal one-liner: "I'm stuck on X. Will commit minimal spec in 3 calls."
2. **WRITE ARTIFACT** — ADR with open questions, spec doc, config. A 50-line ADR with open questions beats a 2000-word explanation.
3. **COMMIT** — `git add` + `git commit`, real file on disk.
4. **EMIT** — one-paragraph response with file path, commit SHA, what user should validate.

**Anti-patterns**:

- More search/read (that IS the loop)
- Ask user A/B (they're frustrated; pick reasonable default and ship)
- "Next session I will..." promises (commit something real NOW)
- Re-attempt the original task (that's why you're stuck)
- `git status` to "understand the situation" (more recon = more loop)

## 6. Pre-`git push` audit (5 minutes saves 30)

Before push, audit uncommitted work — **yours AND prior-session's**:

1. `git status` — classify this-session (you understand) vs prior-session (un-audited)
2. `git diff <file>` for each non-this-session file; >50 lines = grep key imports/exports
3. Trace dependencies: `git grep "from.*<file>"` + `git grep "import.*<file>"` for all consumers
4. Auth/security files MUST run `bun run typecheck`
5. If uncertain: `git checkout -- <file>` to revert, push without it, leave for original session's author

Anti-pattern: `git add .` without audit → push commits someone else's half-done auth fix that breaks every POST 401-rejecting.

## 7. Cross-references

- Full archived source: `archive/skills/autonomous-ai-agents/agent-stuck-recovery/SKILL.md`
- Full archived source: `archive/skills/general/subagent-timeout-recovery/SKILL.md`
- Related: SOUL.md 紅線 54-56 (verification-driven gate)
- Related: `regression-guard` (commit a regression test as recovery artifact)