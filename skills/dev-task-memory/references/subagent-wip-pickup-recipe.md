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

### Step 3: Read the untracked / modified files BEFORE assuming

For each untracked file, read it in full. For each modified file, read
the full `git diff`. Subagents sometimes:
- Create the right file in the right place
- Stop before wiring it up (e.g. component created but consumer
  page not updated)
- Introduce side effects in `.gitignore`, `package.json`, configs

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

## Worked example (2026-06-06, crm-system)

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

## Related

- `dev-task-memory/SKILL.md` — general state file workflow
- `regression-guard/SKILL.md` — for bug fixes, this recipe is the
  feature-work analog
- `SOUL.md` 紅線 24-28 — state file discipline that prevents this
  scenario from happening in the first place
