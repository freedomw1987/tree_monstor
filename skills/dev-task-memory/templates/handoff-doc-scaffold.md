# YYYY-MM-DD <Task Name> — Handoff

> **Status:** ⏸ Paused for [reason: /new / clean session / 收工 / handoff to David review].
> [1-2 sentences on what's done and what's next.]

---

## TL;DR for Resume

```bash
cd ~/www/<project>
git checkout <branch>     # branch already current
# 1. Load state:  # <historical 2026-07-25 retired: scripts/load_state.py 退役>
#                  # Claude Code 對應：`/resume` slash command
#                  # 或手動 read `docs/_meta/dev-task-state.md`
# 2. Sanity:     git status --short  (expect N untracked files only)
# 3. Env:        export <VAR>=<value>  # <reason: dev server won't boot without>
# 4. Start dev:  bun run dev   (in apps/api + apps/web separately)
# 5. Continue Step N → Step M
```

**Original task:** [1 sentence on what user originally asked for]
**Branch:** [branch name] ([N] commits ahead of <base>, [M] behind)

---

## Branch State (verified at <timestamp>)

```
Branch: <branch>
        N commits ahead of <base>, M behind
Working tree: clean (N untracked — see below)
```

### Commits on this branch (oldest → newest)

| SHA | Type | What |
|-----|------|------|
| `<sha>` | <type(scope)> | [1-line summary] |
| ... | ... | ... |

### `git status` (verbatim)

```
?? <untracked file 1>
?? <untracked file 2>
```

> **These N untracked files are [David's / previous session's], NOT mine.** Next session must
> `git diff` them once to read what changed before touching [relevant files]. They're consumed by
> [later step / page wrap / etc.].

### Diffstat <base>..branch

```
.../<file>                                   |  N +++++
.../<file>                                   |  N +++++
[N] files changed, [N] insertions(+), [N] deletions(-)
```

> *(Excludes a few files I patched but didn't commit — see "Uncommitted Work" below.)*

---

## What's Done ✅

### <Phase N> — <Title> ([commit count] commits, [ready/merged])

- **<ID-1>** <what it does, where]
- **<ID-2>** [<where>][<key rationale>]
- **<ID-3>** [<where>][<key fix / insight>]

<Evidence / retro / smoke doc path>

### <Phase N+1> — <Title> ([commit count] commits, ready for <next phase])

1. **`<sha>` — <area>**
   - <1-2 lines of what + key file paths>
   - <any caveats — e.g. "applied in DEV, not yet in PROD">

2. **`<sha>` — <area>**
   - <what + key file paths>

---

## What's NOT Done (Steps N+1 to M, <phase> + <phase>)

> **Hard requirement before starting Step N+1:** <e.g. ensure DEV DB has new rows / env var set /
> subagent skeleton exists>. Without that, **<the new endpoints will 403 / build will fail / etc.>**.

| Step | Scope | Files | Notes |
|------|-------|-------|-------|
| **N+1** | <phase name> | <file paths> | <1-2 lines of what + caveats> |
| **N+2** | <phase name> | <file paths> | <notes> |
| ... | ... | ... | ... |

---

## Key Decisions (do not relitigate)

1. **<Decision 1> — <short label>**
   - Why: <rationale>
2. **<Decision 2> — <short label>**
   - Why: <rationale>
3. **<Decision 3> — <short label>**
   - Why: <rationale>
4. **<Decision 4> — <short label>**
   - Why: <rationale>
5. **<David's untracked files are sacred>**
   - Do not `git add` them without his review. They likely belong to a different commit/PR.

---

## Uncommitted Work (paused mid-edit)

I started editing <files> for Step N+1 but the session was paused before the patch was finalized.
The next session should:

```bash
git diff <files>
```

If those diffs are empty (i.e. I never saved), start Step N+1 from scratch by reading the current
<structure> and adding <what's needed>.

If the diffs are non-empty, **review the patches, finish them, and commit** before moving on.

---

## Critical Context (carry forward)

### <Env var> (<constraint name>)

`<file>` will <hard-fail / refuse to start> on boot if `<VAR>` is missing or shorter than <N> chars.
The dev `<env file>` has a <placeholder length>-char placeholder. **Before starting the dev server:**

```bash
export <VAR>=<how to generate, e.g. $(openssl rand -hex 32)>
# OR add to .env:  <VAR>=<N>-char value
```

This is **per-session-exported**, not committed. In a new `/new` session it must be re-exported.

### <Latent bug fix> (root cause + symptom)

The `<Table>` table in prod was <broken state> before this branch. The seed file in `<sha>` populates
them from the canonical definitions. **If the dev DB was seeded before the branch was checked out**,
run `<seed command>` once, or the new endpoints will <fail with what error>.

### Doc HTML preview

Both boss + engineering HTML plans for the refactor are at:
- `<path>/boss.html`
- `<path>/engineering.html`

Plus bundled-for-Discord: `<path>.bundled.html` (David's exception case, committed per skill
recipe §8).

### `MANIFEST` for the next session

- **Plan doc:** `<path>`
- **<P0 retro / earlier phase retro>:** `<path>`
- **Tech debt catalog:** `<path>` ([N] findings from review)
- **QA tracker:** `<path>` (must be updated in Step N+5)
- **Branch:** `<branch>`

---

## Next Session — First 3 Commands

```bash
# 1. Reload state
# <historical 2026-07-25 retired: scripts/load_state.py 退役>
# Claude Code 對應：`/resume` slash command
# 或手動 read `docs/_meta/dev-task-state.md`

# 2. Verify branch
cd ~/www/<project> && git status --short && git log --oneline -5

# 3. Set <env> and start dev
export <VAR>=<value>
bun run dev   # in 2 terminals: <api dir> + <web dir>
```

Then continue at Step N+1.
