# 2026-06-06 crm-system — LSP diagnostics stale vs `docker compose build` ground truth

**Session**: crm-system Day 11+ (Man-day Roles page + Companies edit dialog)
**Lesson type**: Process gap, not code bug

## What happened

I was wiring `CompanyAutocomplete` into `quotation-builder.tsx` (replacing an inline `<select>`). I wrote 4 patches to:
1. Add `mode` + `defaultName` + `regions` props to `CompanyFormDialog`
2. Export `CompanyFormDialog` from `pages/companies.tsx` (it was internal)
3. Update `companiesApi.create/update` signature to accept new fields (`legalName`, `taxId`, `website`, `status` union)
4. Add `regions` to `CompanyFormDialog` props inside `CompanyAutocomplete`

After each patch, LSP reported the **same 3 errors** (line numbers pointing to old code that had already been patched):
- `CompanyFormDialog` missing `mode` and `regions` props → I had already added both
- `c: (parameter) c: any` → I had already typed it
- `status: string` not assignable to union → I had already cast

I patched 3 more times chasing the LSP ghost, making the file worse each time. I never ran `docker compose build web` because LSP was "telling me there are issues."

When I finally ran the build (because of `b39a87d` commit preparation), the build **passed cleanly**. All 3 LSP errors were stale. The file was already correct 3 patches ago.

## The right workflow

```bash
# 1. Patch the file
patch mode=replace path=apps/web/src/components/company-autocomplete.tsx ...

# 2. Immediately run the build (NOT just trust LSP)
cd ~/www/crm-system
docker compose build web 2>&1 | grep -E 'error TS|failed|exit code|DONE' | head -10
```

Expected output for healthy build:
```
#1 DONE 0.0s
#2 DONE 0.1s
...
#20 DONE 0.0s
```

If you see `error TS####` in the output → real type error, fix it.
If you see no `error TS` lines → LSP noise, ignore it, move on.

## Why LSP is unreliable in this stack

1. **Hermes LSP daemon cache invalidation is not 100% on rapid consecutive patches.** After 4-5 patches in the same session, LSP reports errors that match the file state 2-3 patches ago.
2. **LSP runs a different typecheck view than `tsc --noEmit`.** For things like `as` casts narrowing against union types, or destructured inferred generics, LSP's view can be stricter OR more lenient than the actual build.
3. **Many route files have `// @ts-nocheck`** (Elysia 1.2 d.ts workaround — see `elysia-typescript-workarounds` #12). LSP won't typecheck those, but `tsc` will still typecheck the rest of the project, so the build is the only thing that catches real type drift.

## Time saved

- Wrong way: 4 LSP-noise patches + 3 wrong-fix patches = ~7 patches, ~5 minutes of chasing
- Right way: 1 patch + 1 `docker compose build web` (~30s) = 30 seconds total

5× speedup on a single file change. On a multi-file refactor, this compounds.

## What to put in commit messages

When shipping a frontend change, the commit message should explicitly mention the build verification:

```
feat(frontend): <change>

Built with `docker compose build web` — exit 0, no TS errors.
LSP diagnostics during development were stale (see SKILL.md
"⚠️ LSP diagnostics stale" pitfall) but the Docker build was clean.
```

This documents the verification step for the next agent who reads the commit history.

## What NOT to do

```bash
# ❌ Don't trust LSP's errors
patch file
LSP says "error TS" → patch again
LSP still says "error TS" → patch again
... 4-5 times ...
# Eventually you either revert the whole thing or ship broken code

# ❌ Don't skip the build
patch file
"Looks good to me, commit!"
# Push to GitHub → CI fails OR user sees blank page

# ❌ Don't use `tsc --noEmit` standalone as a substitute
cd apps/web && bunx tsc --noEmit
# This works for plain TS but misses the Vite bundler pipeline errors
# (e.g. environment variable usage, dynamic imports, CSS module typing)
# Only `docker compose build web` exercises the actual build path
```
