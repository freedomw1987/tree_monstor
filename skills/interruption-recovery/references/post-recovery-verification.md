# Post-recovery verification recipes

Two class-level checks that **don't surface in `git status`, state files, or
standard smoke output**, but bite you at prod deploy time. Run them after a
`Recover` cue and before any "Step 12 passed / ready to merge / PR ready" claim.

A third check (Recipe C) was added 2026-06-07 crm-system Day 15 — stale
stash detection. See end of file.

A fourth check (Recipe D) was added 2026-06-16 PM-System Sprint 21 —
**pre-existing uncommitted sprint detection**. See end of file. This
catches the case where the user's "do X" cue is actually a re-prompt of
work that was already coded in the working tree but never committed.
**Run Recipe D FIRST, before any other recovery recipe, whenever the
user says "做 X" / "fix X" / "ship Y" and the topic sounds like a
recent sprint scope.**

---

## Recipe A — HEAD self-consistency check (untracked providers)

**Symptom** (Day 14.7 crm-system, 2026-06-07): a commit titled
`feat(db): Day 14 SystemConfig table ...` (`603745e`) silently also modified
`apps/web/src/pages/deals.tsx` + `quotations.tsx` to add
`import { MultiCompanyAutocomplete } from '@/components/multi-company-autocomplete'`.
The 3 component files (`multi-autocomplete.tsx`,
`multi-company-autocomplete.tsx`, `multi-user-autocomplete.tsx`) were **never
committed**. Dev rebuild succeeded because Vite's docker build reads the
working tree (untracked files included). Prod `git pull` lost the untracked
files → `Rollup failed to resolve import "@/components/multi-company-autocomplete"`
during stage-1 build → BUILD FAIL.

**Why it hides from existing tools**:
- `git status` shows `??` for the providers, but the consumer code shows
  `import` as a normal tracked-tree symbol — easy to mentally group as
  "untracked WIP, not my problem yet"
- `git log` of the consumer file shows the import was added in `603745e`
  (under an unrelated commit title) — no obvious red flag
- Dev bundle works → smoke claims "verified"
- `git show --stat 603745e` does list `deals.tsx` in `name-only`, but the
  commit body only mentions backend work, so reviewers skim past it

**Detection recipe** (run on dev host, after recovery, before any PR claim):

```bash
# 1. Collect every @/-relative import from tracked TS/TSX files
git ls-files 'apps/**/*.ts' 'apps/**/*.tsx' | \
  xargs grep -hE "from ['\"]@/" | \
  grep -oE "['\"]@/[^'\"]+['\"]" | \
  tr -dead_char" | sort -u > /tmp/imports.txt

# 2. For each import, resolve to a real file on disk and check it's tracked
while read import_path; do
  # strip leading @/ and resolve under apps/web/src (or other workspace root)
  rel="${import_path#@/}"
  for root in apps/web/src packages/shared/src; do
    candidate="$root/$rel"
    for ext in "" ".ts" ".tsx" ".js" ".jsx" "/index.ts" "/index.tsx"; do
      if [ -f "$candidate$ext" ]; then
        if ! git ls-files --error-unmatch "$candidate$ext" >/dev/null 2>&1; then
          echo "⚠️ UNTRACKED-PROVIDER: $candidate$ext"
          echo "   (imported by tracked code as: $import_path)"
        fi
        break 2
      fi
    done
  done
done < /tmp/imports.txt
```

**Expected output**: nothing. Any `⚠️ UNTRACKED-PROVIDER` line = prod build will
fail after `git pull`.

**Fix** (commit the providers):

```bash
git add apps/web/src/components/multi-*.tsx   # or whatever the path is
git commit -m "feat(web): <feature> — commit providers shipped in <original-commit>"
```

**Re-run** the recipe after the commit. Should print nothing.

**Lesson**: HEAD should be **self-consistent** — every import in a tracked
file should resolve to a tracked file. Untracked providers break prod
deploys even when dev rebuild + smoke pass.

---

## Recipe B — Stale Docker image bundle detection

**Symptom** (Day 14.7 crm-system, 2026-06-07): the `crm-web` container
showed `Up 1 hour (healthy)` and reverse-proxied 200 OK, but the served
Vite bundle was `index-YQbA86LV.js` built at `Jun 7 11:42` — 8 hours
before commit `0119a9f` (Deal Autocomplete + Quick-Create) was pushed.
The UI for SettingsLayout 7 tabs, Tax UI, and Deal Autocomplete was
**silently absent**: SettingsLayout existed in the source tree, but
the bundle didn't include it because the image was baked before
Step 6's commit landed. Vite tree-shakes symbols it doesn't use at
build time, so the bundle still produced a valid JS file with no
error — just no new features.

**Why it hides from existing tools**:
- `docker ps` shows the container is `Up` and `healthy` (nginx responds
  200 to the root URL)
- The API works (Tax GET/PUT, audit log, all backend) — but the API is
  built from a separate `crm-api` image, not the same image as the SPA
- `git log` shows the source is at the new commit — but it doesn't
  reach inside the running image
- The Vite bundle is minified; no source map is shipped to nginx, so
  a quick `curl /` only returns the HTML shell

**Detection recipe** (3 checks, do all 3):

```bash
# 1. Image age vs most recent commit age
echo "Image created: $(docker inspect crm-web --format '{{.Created}}')"
echo "Last commit:   $(git log -1 --format='%ai')"
# If image_created < last_commit → image is stale

# 2. Bundle file mtime inside the running image
docker exec crm-web sh -c "ls -la /usr/share/nginx/html/assets/*.js"
# Compare against the image_created timestamp from step 1

# 3. NEW feature string-grep on the served bundle
docker exec crm-web sh -c "grep -c 'YOUR_NEW_FEATURE_STRING' /usr/share/nginx/html/assets/*.js"
# Expected: ≥1 (proves the bundle includes the post-image source)
# Actual 0 → stale image, must rebuild
```

The `YOUR_NEW_FEATURE_STRING` is **anything that uniquely identifies a new
feature** in the most recent commit(s) — for crm-system 2026-06-07 it was
`搜尋 deal 名` (Deal Autocomplete's placeholder). For other stacks:
- a new error message key
- a new API endpoint path string
- a new component name (if not minified out)

**Fix** (local dev, force re-bake + restart):

```bash
docker compose build web
docker rm -f crm-web
docker compose up -d web
sleep 3
# Re-run the string-grep. Should now return ≥1.
```

**Fix** (prod, after merge to main):

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build web
```

**Lesson**: A `docker ps` showing `Up` and `(healthy)` is **not enough** to
claim the service works. Always string-grep the served bundle for a feature
added in the most recent commit, and confirm the grep returns ≥1 before
signing off on smoke.

---

## Recipe C — Stale stash detection (avoid duplicate-definition landmines)

**Symptom** (Day 15 crm-system, 2026-06-07): a `Recover` cue led to `git stash pop` of
`stash@{0}` containing 4 modified + 3 untracked files from the pre-Day-14.5 review
dump. The stash's `apps/api/src/routes/deal.ts` contained a *new* `toIdArray` function.
The main branch's `deal.ts` (after merge `43a0462` + 14.5 P0-2) **already had the
same `toIdArray`** because David's working changes had landed via merge. Pop result:
**two `function toIdArray` declarations in the same file** — TS would have errored
on a strict build, but with `@ts-nocheck` on the sibling route files the duplicate
slipped through and would have shipped as broken runtime behaviour.

**Symptom #2** (same session): stash's 3 untracked multi-autocomplete components
(`apps/web/src/components/multi-*.tsx`) collided with the tracked-tree copies that
Day 14.7 merge `43a0462` had committed. `git stash pop` printed
`already exists, no checkout` and **bailed out partway through the pop** — only 1 of
the 4 modified files was restored, the rest sat half-popped in working tree. The
agent had to revert the partial pop manually.

**Why it hides from existing tools**:
- `git stash list` shows the stash exists; the agent assumes "good, pop it"
- `git stash show -p` shows real diffs; nothing in the diff hints that the same
  change is already in `git show main:<file>`
- The `Recover` cue usually means "go", not "verify"
- Stash age (`stash@{N}`) is a weak signal — a 1-day-old stash can be fresh
  (mid-flight WIP) OR 100% stale (already merged)

**Detection recipe** (run BEFORE `git stash pop`, every time after a Recover cue):

```bash
# 1. List the stash contents
git stash show --name-only stash@{0}
# → e.g. "apps/api/src/routes/deal.ts", "apps/web/src/components/multi-*.tsx", ...

# 2. For each modified file in the stash, check if main already has the
#    same code path. Fastest check: does the function/symbol the stash
#    INTRODUCES already exist in main?
#
#    Pattern: stash diff added `function foo` → grep main for `function foo`
#    If hit-count > 0 in main's file → that file's addition is 100% stale.
git stash show -p stash@{0} -- <file> | grep -E '^\+function |^\+const ' | \
  while read sym; do
    sym_name=$(echo "$sym" | sed -E 's/.*(function|const) ([A-Za-z_][A-Za-z0-9_]*).*/\2/')
    if [ -n "$sym_name" ] && git show main:<file> | grep -q "$sym_name"; then
      echo "⚠️ STALE-STASH-SYMBOL: $sym_name in <file> already exists in main"
    fi
  done

# 3. For each untracked file in the stash, check if a tracked copy already
#    exists on the same path
git stash show -p stash@{0} 2>&1 | grep -E '^.. untracked' | \
  while read line; do
    path=$(echo "$line" | awk '{print $NF}')
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
      echo "⚠️ STALE-STASH-UNTRACKED: $path already tracked in main (merge landed it)"
    fi
  done

# 4. Optional but fast: diff stat between main and stash@{0}'s parent
#    (the commit the stash was created from). If 0 file difference, stash
#    is 100% stale → drop it.
git diff --stat stash@{0}^ stash@{0} 2>/dev/null
# 0 lines changed → drop. Any meaningful diff → still worth per-file check.
```

**Expected output**:
- Trivial case: nothing printed → stash has unique WIP, safe to `git stash pop`
- Stale case: `⚠️ STALE-STASH-SYMBOL` / `⚠️ STALE-STASH-UNTRACKED` lines
  → **per-file `git checkout` the diff and re-apply on top of main, OR
  drop the stash** if the entire work is already in main

**Fix** (3 options, pick by staleness extent):

```bash
# Option 1 — entire stash is stale (all symbols + untracked already in main)
git stash drop stash@{0}

# Option 2 — partial staleness (some files stale, some have unique WIP)
# Per file, checkout the stash's version and patch on top of main:
git checkout stash@{0} -- <stale-file>
git checkout stash@{0}^3 -- <unique-wip-file>   # (or whichever parent has the WIP)
# Better: use `git stash show -p stash@{0} -- <file> | git apply` so you
# get a proper merge attempt instead of a blind overwrite.

# Option 3 — stash pop, then resolve the duplicates that surface
# (works when only 1-2 files have duplicate definitions)
git stash pop
# Then for each duplicate:
#   - `grep -c 'function toIdArray' <file>` → 2 means duplicate
#   - Delete the duplicate block (keep the main version, usually the older one
#     at the top of the file)
```

**Lesson**: A stash is **only as fresh as the diff between `stash@{0}^` and
`main`**. After any merge that subsumed the stash's WIP, the stash is a
**landmine**, not a save-state. Always per-file diff against `main` before
`git stash pop`, and never trust a stash that survived > 1 merge boundary
without verification.

**Telltale signs you have a stale stash** (any 1 of these is enough to run the recipe):
- Stash label includes "pre-review" / "pre-merge" / "pre-sprint" / "WIP"
- The last merge that landed in main was **after** the stash was created
- `git stash show --stat` shows the same files that a recent merge commit also touched
- The stash's "new symbols" are all already in `git show main:<file>`'s first 50 lines

---

## When to run

| Moment | Why |
|--------|-----|
| After `bash resume.sh <project>` (post-Recover) | The reconstructed context may describe a branch that no longer builds |
| Before claiming "Step X passed / E2E verified" | Standard smoke (curl + UI nav) misses stale-bundle issues |
| Before opening a PR with "all N commits ahead" | Catch untracked providers before reviewer has to |
| Before saying "ready to merge to main" | Catch the prod-build-fail class of issues pre-merge, not post-deploy |
| **Before `git stash pop` after a Recover cue** | Recipe C — detect a 100% stale stash before it dumps duplicates into your working tree |

---

## Related

- `interruption-recovery/SKILL.md` — the recovery flow that produces the
  state file (which Recipes A/B/C complement)
- `interruption-recovery/SKILL.md` § "Day 15 Lesson" — reconstruction
  recipe when state file is generic template (the 4-source sequence
  that runs *before* Recipes A/B/C)
- `interruption-recovery/references/reconstruct-context-from-git-and-sessions.md` —
  detailed reconstruction recipe + worked example
- `dev-task-memory/SKILL.md` Day 11 lesson — the state-file template
  limitation that Recipes A/B are the **workaround** for
- `caddy-spa-api-proxy-deploy` — Docker deploy patterns; Recipes A/B
  are the **verification** counterpart (deploy != verified)
- `feature-plan-alignment` — the "Stash 狀態" section in every plan
  should cross-reference Recipe C
- `crm-system` `docs/retros/2026-06-07-system-settings.md` — the
  real-world finding that prompted Recipes A & B
- `crm-system` Day 15 sprint plan (`8cdcd8a`) — Recipe C's source case

---

## Recipe D — Pre-existing uncommitted sprint detection (the "code is already done" trap)

**Symptom** (2026-06-16 PM-System Sprint 21): David sent "做以下必要性的修正: 1. Wiki 上傳可以支援到 doc, xls, txt 檔案; ..." (5 items, all matching Sprint 21 scope). The agent started surveying source code and found `Sprint 21 US-21.4` / `US-21.1` / `US-21.3` / `US-21.5` comments in `chat.ts`, `documents.ts`, `wikis.ts` and a 51-line retro doc already drafted at `docs/retros/2026-06-16-sprint-21-wiki-improvements.md`. Initial reaction: "almost done, just need to commit and push" — but `git status` showed **7 files modified + 3 untracked, zero commits ahead of master**. The working tree contained the full implementation of all 5 US, but every bit of it was uncommitted WIP from a previous session.

**Why it hides from existing tools**:
- `git status` shows modified/untracked files but no obvious flag that says "this is a complete sprint you should ship, not WIP"
- `git log --all --oneline --grep="Sprint 21"` returns nothing — the work is uncommitted, not lost
- Reading the source code reveals `Sprint 21 US-XX.Y` comments but a fresh agent treats those as "future planned scope" rather than "already implemented"
- Retro doc with the matching title and `## Implementation plan` section exists in `docs/retros/` — but uncommitted
- `bun test` will pass (710/710 in PM-System case) because the code is functional, not broken — easy to mistake "tests pass" for "work is shipped"

**Why it matters**: If you start writing fresh US-21.1 code on top of this working tree, you'll either (a) duplicate existing work, (b) get confused by interleaved hunks between US, or (c) blow away existing logic with a "from scratch" implementation. The correct move is **verify → commit → push**, not "re-implement".

**Detection recipe** (run BEFORE writing any code for a "do X" cue that sounds like sprint scope):

```bash
# 1. Working tree state — modified/untracked count tells you if work is in flight
cd ~/www/<project>
git status --short | wc -l         # > 0 = work in progress
git diff --stat | tail -1          # "+X -Y" total change footprint
git status                         # (no args) the "On branch / working tree" 2 lines = truth

# 2. Check if the uncommitted changes match the user's request
#    a. If the request mentions US numbers (e.g. "US-21.3") or feature names
#       that match a recent sprint, search the working tree for those markers:
git diff | grep -E "^\+.*Sprint [0-9]+ US-|^\+.*US-[0-9]+\.[0-9]+"
#    b. If those markers are present in +lines (not -lines), the work is being
#       added, not removed → likely a half-done or in-progress sprint

# 3. Check for an in-flight retro doc that matches the sprint topic
ls docs/retros/$(date +%Y-%m-%d)-*.md 2>/dev/null
# If a retro doc exists with "Implementation plan" + commit-style "Backend/Frontend"
# section AND is untracked, it's a draft from a previous session

# 4. Run the test suite to confirm the code is functional (not half-broken WIP)
cd backend && bun test 2>&1 | tail -3   # PM-System case: "710 pass 0 fail"
# If tests pass + working tree has changes + retro doc exists + comments match
# request → this is a "ship a pre-existing uncommitted sprint" case, NOT a
# "implement from scratch" case

# 5. Cross-check against all branches (the work might be on a feature branch
#    that wasn't merged)
git branch -a | grep -iE "sprint|wiki|feat"
git log --all --oneline --grep="<sprint-name>"   # e.g. "Sprint 21"
# If a branch like `feat/sprint-21-*` exists with the same work, the agent
# likely checked out an empty branch and the actual commits are elsewhere
```

**Decision matrix after running Recipe D**:

| Detection result | Correct action |
|------------------|----------------|
| Working tree has changes + `Sprint NN US-X.Y` comments in +lines + retro doc drafted + tests pass | **Verify each file's diff is correct → split into per-US commits → push**. This is "ship a pre-existing sprint", not "implement". |
| Working tree has changes + tests fail | **Diagnose failures first**. Likely a half-broken WIP. Don't push until green. |
| Working tree clean + branch `feat/sprint-NN-*` exists with commits | **Merge the feature branch** instead of re-implementing. |
| Working tree clean + no matching branch + no uncommitted work | **Implement from scratch** as the user expects. |

**Fix pattern** (PM-System Sprint 21 worked example, 2026-06-16):

```bash
# 1. Working tree had 7 modified + 3 untracked files = pre-existing sprint WIP
git checkout -b feat/sprint-21-wiki-improvements   # or use existing branch

# 2. Run full test suite to verify code is functional
cd backend && bun test    # 710 pass / 0 fail

# 3. Split the monolithic working-tree diff into per-US commits.
#    IMPORTANT: hunks for different US are often interleaved within a single
#    file (US-21.1 parser + US-21.3 dup-check call in the same documents.ts).
#    When hunks can't be cleanly separated with `git add -p`, fall back to
#    file-level commit boundaries and document the cross-US scope leak in
#    the commit message body. The honest commit message:
#
#    "feat(docs): wiki upload supports .doc/.xls/.txt (US-21.1)
#     Note: this commit also includes some pre-existing US-21.3 hunks in
#     documents.ts (findExistingWikiPage call) and WikiPage.tsx
#     (handleReplace function) because hunks are interleaved. US-21.3
#     commit will add the wiki-dedup util + wikis.ts route changes."
#
#    is much better than hiding the leak or forcing impossible splits.

# 4. Commit each US + retro doc separately
git add backend/Dockerfile backend/src/routes/documents.ts ...   # C1: US-21.1
git commit -m "feat(docs): ..."
git add backend/src/utils/wiki-dedup.ts backend/src/routes/wikis.ts   # C2: US-21.3
git commit -m "feat(wiki): ..."
git add backend/src/routes/chat.ts frontend/src/pages/ChatPage.tsx   # C3: US-21.4+21.5
git commit -m "feat(chat): ..."
git add docs/retros/<date>-sprint-NN-*.md   # C4: retro
git commit -m "docs(retro): Sprint NN closure ..."

# 5. Verify, push, merge
git log --oneline -5        # confirm N commits
cd backend && bun test      # still 710 pass
git push -u origin feat/sprint-NN-...
git checkout master
git merge --no-ff feat/sprint-NN-... -m "merge: Sprint NN — <one-line summary>"
git push origin master
```

**Lesson**: When the user sends a "do X" cue, **the first 30 seconds of investigation should be
"is X already done in the working tree?"** — not "how do I implement X?". A `git status` showing
non-zero changes + `Sprint NN US-X.Y` markers in `git diff` output + a matching retro doc is
the universal signature of "this is a re-prompt of a half-shipped sprint". Recognize it,
verify the work, and ship it as a series of per-US commits.

**Tell-tale signs of a pre-existing uncommitted sprint** (any 2 of these = almost certainly WIP):
- `git status --short` shows > 5 files modified OR > 2 untracked
- `git diff | grep "Sprint NN US-"` returns > 0 hits in `+` lines
- `docs/retros/<recent-date>-<sprint-topic>.md` exists and is untracked
- The user's cue mentions the same feature names that appear in the `+` lines
- `bun test` / `npm test` passes despite the changes
- A `feat/sprint-NN-*` branch already exists (but is empty / 0 commits ahead of master)

**Anti-patterns to avoid**:
- ❌ Starting fresh implementation when `git status` shows the work is in flight
- ❌ Writing the retro doc from scratch when an uncommitted draft exists
- ❌ Forcing `git add -p` to split per-US hunks when the file has interleaved US (use file boundaries + honest commit message)
- ❌ Skipping the test suite check ("I'll trust the working tree compiles") — half-done sprints sometimes have partial-test failures
- ❌ Asking the user "is this work already done?" — the working tree IS the answer, just verify it

---

## When to run (updated to include Recipe D)

| Moment | Why |
|--------|-----|
| **First action on a "do X" / "fix Y" / "ship Z" cue** | Recipe D — check if work is already in the working tree before starting fresh |
| After `bash resume.sh <project>` (post-Recover) | The reconstructed context may describe a branch that no longer builds |
| Before claiming "Step X passed / E2E verified" | Standard smoke (curl + UI nav) misses stale-bundle issues |
| Before opening a PR with "all N commits ahead" | Catch untracked providers before reviewer has to |
| Before saying "ready to merge to main" | Catch the prod-build-fail class of issues pre-merge, not post-deploy |
| **Before `git stash pop` after a Recover cue** | Recipe C — detect a 100% stale stash before it dumps duplicates into your working tree |
