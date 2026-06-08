# Subagent WIP Pickup Recipe

Use when: opening a session / resuming after a subagent ran, and the
working tree has uncommitted changes (untracked files + modified files)
left by the previous agent. The previous agent stopped mid-task — the
file shape on disk is the only source of truth.

## Symptoms

- `git status` shows `Untracked files:` and `Changes not staged for commit:`
- The user says "繼續做" / "continue" / "pick up from where you stopped"
- A previous subagent is in the recent `session_search` results
- The task description references files that don't exist yet (subagent
  was supposed to create them)
- A `git diff <file>` shows changes that DIDN'T come from your last commit
  (e.g. a sibling agent edited a file you already committed)

## Recipe (run in this exact order)

### Step 1: Snapshot the working tree

```bash
cd ~/www/<project>
git status
git diff --stat
ls apps/web/src/<expected-dir>/  # or wherever new files were promised
```

Goal: get a complete inventory of what the previous agent did, modified,
or never touched. **Trust the filesystem, not the session history** —
LLM memory of the previous session is unreliable after compression.

### Step 2: Check commit history for partial progress

```bash
git log --oneline -10
git log --oneline origin/main..HEAD
```

Look for:
- A commit that *looks* like the start of a multi-commit series but
  the rest are missing → the subagent did Phase 1 and stopped
- Commits that touch related files but reference a feature that's
  incomplete in the working tree
- Commits **not** from you but in your working tree (sibling agent
  pushed in parallel) — these need a `git log --author` audit

### Step 3: Read the untracked / modified files BEFORE assuming

For each untracked file, read it in full. For each modified file, read
the full `git diff`. Subagents sometimes:
- Create the right file in the right place
- Stop before wiring it up (e.g. component created but consumer
  page not updated)
- Introduce side effects in `.gitignore`, `package.json`, configs

This is the **only** way to know the actual pickup point. Don't guess
from the task description.

**Strong pickup signal — comment-attributed WIP (2026-06-07 lesson)**:
If a sibling or previous subagent's `git diff` includes code comments
that explicitly reference **your** task or step identifiers (e.g.
`// Day 14.7 Step 12 fix:` or `// crm-system Phase 2:` or `// per
plan A` or `// 2026-06-07 retro:`), treat the WIP as **aligned with
your work** and **pick it up**, don't revert. The author wrote the
WIP with knowledge of your active task; they were filling in a gap
they could see you'd hit. Reverting = you re-discover the same bug
in your own E2E smoke and write the same fix from scratch.

Examples of strong pickup signals (any one is enough):
- Comment contains a step number matching your plan (`Step 7`, `Step 12`)
- Comment contains a date matching the day's work
- Comment references a specific US / ADR / retro that you're shipping
- Comment explains "we need X because Y" where Y matches your plan

Examples of weak / ambiguous signals (default: ask David, don't
auto-pick up):
- Comment is a generic TODO or FIXME
- Comment references an unrelated feature
- The diff has zero comments (pure code change with no rationale —
  could be a sibling session's orthogonal work)
This is the **only** way to know the actual pickup point. Don't guess
from the task description.

### Step 4: Audit for subagent side effects

Subagents often add gitignore entries, install packages, or modify
shared config. Audit:

```bash
git diff .gitignore  # duplicate entries? wrong paths?
git diff package.json apps/web/package.json
```

Common pitfalls:
- Duplicate gitignore entries (e.g. `docs/_meta/` listed twice)
- Packages added to root `package.json` instead of workspace
- Container rebuilds triggered by `docker compose down`
- `.env.local` or similar accidentally created
- **Race condition fixes** (e.g. `useEffect` sync) that the sibling
  left half-done — read them, decide if they're correct, then EITHER
  pick them up (and rebase / commit on top) OR revert (with comment
  why)

Fix the noise *before* committing the real work — otherwise the next
`git status` is confusing.

### Step 5: Resume from the actual pickup point

Based on Steps 1-4, the pickup point is usually one of:

| What you find | What to do |
|---------------|------------|
| Component file exists, consumer page not updated | Wire it up + commit + push |
| File exists but is incomplete (e.g. missing useMutation) | Finish it, build, commit |
| File exists but has TS errors | Fix, build, commit |
| File doesn't exist | The previous subagent lied / died — recreate from scratch |
| **Sibling race fix left in `git status` (e.g. `useEffect` for URL→state sync)** | Read the diff, validate the fix is correct, **pick it up** as part of your next commit (don't revert, don't re-derive it yourself) |
| **Siblings' multi-autocomplete components (untracked) that aren't related to your task** | Leave them untracked. Do NOT `git add` them. David may be in the middle of his own work. |

Always run the project's build command (`npm run build` /
`tsc --noEmit` / `cargo check`) before committing to catch subagent
errors that aren't visible from a quick read.

### Step 6: Verify before declaring done

```bash
git log --oneline origin/main..HEAD  # must be empty (push complete)
git status                          # working tree clean
docker compose ps                    # services still healthy (if applicable)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/  # smoke
```

The first command is the **revert detection** check — if local has
commits origin doesn't, you didn't actually push (or someone reverted
on origin). Don't report "done" until this passes.

## Anti-patterns

- ❌ **Assuming the previous subagent's status report is accurate.**
  The subagent may have reported "completed all 3 tasks" but only
  shipped 1.5. Trust the filesystem.
- ❌ **Skipping the `git status` audit.** "Untracked files" + "modified
  files" both need to be in your mental model of "where I am now".
- ❌ **Batch-fixing the previous agent's mistakes inside your own
  commit.** If the subagent introduced 3 gitignore noise entries,
  clean them up in a *separate* `chore(gitignore):` commit so the
  feature commit is reviewable on its own.
- ❌ **Re-running the subagent.** The WIP on disk is usually
  70-90% correct. Reading + finishing is faster than re-delegating.
- ❌ **Committing `.env`, `dist/`, `docs/_html/`, or `node_modules/`.**
  The subagent may have created these by accident. Always check
  `git status -uall` to see untracked files.
- ❌ **Reverting a sibling's WIP just because it didn't come from your
  last commit.** If the WIP is correct, critical, and on the same
  code path, **pick it up** — re-deriving it from scratch wastes time
  and risks introducing a different bug. Add a "sibling fix picked
  up" note in your commit message.
- ❌ **`git add .` / `git add -A` when there are untracked files you
  didn't create.** Use selective `git add <file>...` to avoid
  committing sibling WIP that may be in flight.

## Worked examples

### Example 1: Subagent on the same task (2026-06-06, crm-system)

Subagent was supposed to do 3 frontend tasks: TASK 2L (CompanyAutocomplete
in 2 files), TASK 2B (man-day role dropdown), TASK 2M (RoleDialog
unification). Subagent reported completion. Working tree on resume:

```
modified:   .gitignore              # duplicate docs/_meta/ entry
modified:   apps/web/src/pages/roles.tsx   # NOT updated to use new component
Untracked:  apps/web/src/components/role-dialog.tsx   # 309 lines, complete
```

Plus 2 prior commits (`fd5d8be`, `1773626`) already pushed.

Recipe followed:
1. `git status` → 2 modified + 1 untracked
2. `git log` → 2 commits already pushed, both legit
3. Read `role-dialog.tsx` in full (309 lines, looks complete)
4. Read `roles.tsx` (413 lines) → confirm old dialogs still there, need to
   remove them and add 2 `<RoleDialog>` usages
5. Audit `.gitignore` → remove duplicate `docs/_meta/`
6. Rewrite `roles.tsx` (413 → 146 lines) using new component
7. `npm run build` → 0 TS error
8. `git add .gitignore role-dialog.tsx roles.tsx` (precise, not `git add .`)
9. Commit + push → `7dc56d0` on origin/main
10. `git log --oneline origin/main..HEAD` → empty (push confirmed)

Time saved vs. re-delegating: ~15 min. The WIP on disk was 95% correct;
only the consumer-page wiring was missing.

### Example 2: Sibling WIP pickup (2026-06-07, crm-system Day 14.7)

Concurrent session — David (or another subagent of the same David) was
working on Day 14.7 Settings tabs at the same time as me. I was
implementing Step 5/6/7 in my session; the sibling session was working
on the same file (`pages/audit.tsx`) for Step 7's `useSearchParams`
filter pre-fill.

**Symptoms that triggered WIP pickup**:
- After committing Step 7 (`bd1d107` — Tax Rate settings page), I ran
  `git status` and saw `M apps/web/src/pages/audit.tsx` (modified, NOT
  staged). My commit had included `audit.tsx` in its diff (`+11 lines`).
  The fact that the file was still showing as modified after commit
  means **someone added more changes after my commit**.
- 3 untracked files appeared: `multi-autocomplete.tsx`,
  `multi-company-autocomplete.tsx`, `multi-user-autocomplete.tsx`.
  None of these were related to my Day 14.7 Settings plan.

**Detection recipe applied**:
```bash
git diff apps/web/src/pages/audit.tsx
# Output: a 25-line diff adding:
#   - import { useEffect, useState } from 'react';
#   - useEffect(() => { setAction(...); setActorId(...); setSearch(...); },
#          [searchParams]);
# Plus comment header: "Step 12 fix: Step 7 used `useState(searchParams.get('action'))`
# which only reads the URL on mount. When the user navigates between audit
# pages via in-app <Link> clicks, react-router v7 reuses the existing
# component (no remount) so the filter state would NOT update from the
# new query string..."
```

**The WIP analysis** (key insight from subagent-wip-pickup-recipe):
- The diff is a **legit fix for a race condition** I'd hit on Step 12
  smoke if I didn't have it. The comment says "Step 12 fix" — same plan
  I was working on.
- The fix is small (25 lines), correct, and exactly the right pattern
  for `useSearchParams` + react-router v7 component reuse.
- Re-deriving it from scratch would have wasted time AND risked
  introducing a different fix.

**Pickup decision**: PICK IT UP. Add a one-line note in the next
commit's body:
```
feat: my new work...

Note: audit.tsx has a useEffect([searchParams]) URL→state sync fix
left in working tree from a sibling session. The fix is correct
(see subagent-wip-pickup-recipe in dev-task-memory). Committed as
part of this change rather than re-deriving it.

Refs: react-router-v7-patterns skill (Pattern 4)
```

**Lesson**: The 3 untracked `multi-autocomplete*.tsx` files were
**not** committed. They may be David's own WIP for an unrelated
multi-select feature. Selective `git add <specific files>` is the
only safe path when working concurrently with other agents.

## Related

- `dev-task-memory/SKILL.md` — general state file workflow
- `regression-guard/SKILL.md` — for bug fixes, this recipe is the
  feature-work analog
- `react-router-v7-patterns/SKILL.md` — Pattern 4 documents the
  `useSearchParams` + component-reuse race that the sibling WIP
  fixed. When you see `useEffect([searchParams])` in working tree
  WIP, this is why.
- `SOUL.md` 紅線 24-28 — state file discipline that prevents this
  scenario from happening in the first place
