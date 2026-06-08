# PR: <short title — what + scope>

**Branch:** `<branch-name>` → `main`
**Commits:** N ahead, 0 behind
**Outcome:** ✅ <one-line outcome, e.g. "US-X BACKLOG → PASS. Steps 1-12 complete.">
**Smoke (just verified):** <1-line summary of E2E verify — e.g. "admin login → /settings 7 tabs → tax 13→17 → save → audit row → logout → re-login → 17">

---

## TL;DR

<2-4 sentences: what changed and why. Match the style of the existing project's PRs / retro doc (e.g. crm-system 統一用 Cantonese-flavored 繁中 if David prefer). 5 個 admin page + new Tax Rate 統一喺 /settings/* URL prefix 之類.

## Commits (N total)

### <Batch 1 name> (M commits, K files changed)

| SHA | Type | What |
|---|---|---|
| `<sha>` | feat(db) | <one-liner> |
| `<sha>` | feat(api) | <one-liner> |
| `<sha>` | feat(web) | <one-liner> |
| `<sha>` | fix(web) | <one-liner — "Step N" if numbered sprint> |
| `<sha>` | docs | <one-liner — ADR / retro / API / QA-TRACKER> |

### <Batch 2 name — sister batch / follow-up> (L commits)

| SHA | What |
|---|---|
| `<sha>` | <one-liner> |

<One-paragraph context for the most important commit — e.g. what it replaces, what it fixes (with RG-XXX id), any non-obvious decisions.>

## Plan vs actual

<1 line per plan decision. Numbered list. For each: ✅ <actual outcome>。如果 plan 同 actual 有 deviation, 寫 explicitly (e.g. "Plan said 保留 /settings 舊 direct route 唔動 → actually 5 backward-compat <Navigate> redirects added")。>

1. ✅ <decision 1>
2. ✅ <decision 2>
3. ✅ <decision 3>
4. ✅ <decision 4>
5. ✅ <decision 5>
6. ✅ <deliberately out-of-scope — e.g. "3 untracked multi-autocomplete files (David's WIP) NOT touched">

## E2E smoke results (just ran, YYYY-MM-DD HH:MM TZ)

<Numbered list of concrete verify steps. Include exact API responses and UI snapshots — not vague claims. 12-14 steps for a major feature. 4-6 for a small one.>

1. ✅ `curl /api/health` → `{status:ok, db:connected}`
2. ✅ `POST /api/auth/login admin@x/x` → 200 + JWT
3. ✅ Browser login → <what renders>
4. ✅ <navigate> → <what shows>
5. ✅ <API call> → <response>
6. ✅ <refresh / reload> → <persistence behavior>
7. ✅ <logout / re-login> → <persistence check>
8. ✅ <audit log entry> → <exact text>
9. ✅ <URL direct access> → <status>
10. ✅ <related feature smoke>

## Known minor issues (not blockers)

- **<issue>**: <one-paragraph: symptom, impact, fix plan>. No RG- entry needed if cosmetic.

## Files changed (X files, +YYYY/-ZZZ)

<For each touched file, one-line description. Group by category: api / web / db / docs / config.>

- `apps/api/src/routes/<x>.ts` (<one-line>)
- `apps/web/src/components/<x>.tsx` (new)
- `apps/web/src/components/<x>.tsx` (new shadcn wrapper)
- `apps/web/src/pages/<x>.tsx` (new)
- `apps/web/src/components/<x>.tsx` (new)
- `apps/web/src/components/<parent>.tsx` (<one-line>)
- `packages/db/prisma/schema.prisma` (<one-line>)
- `packages/db/prisma/migrations/<timestamp>_<name>/*` (new)
- `packages/db/prisma/seed.ts` (<one-line>)
- `docs/architecture/<NNNN>-<adr-name>.md` (new ADR)
- `docs/retros/<YYYY-MM-DD>-<retro-name>.md` (new retro)
- `docs/retros/<YYYY-MM-DD>-<p0-evidence>.md` (new)
- `docs/API.md` (+<section>)
- `docs/QA-TRACKER.md` (+<batch>)
- `docs/DESIGN.md` (+<§> architecture)
- `docs/TEST-COVERAGE.md` (+smoke checklist)
- `docs/REGRESSION-GUARD.md` (RG-...)

## Verification commands

```bash
# Health
curl -sS http://localhost:<port>/api/health
# {"status":"ok","db":"connected",...}

# <Endpoint 1> (any authed user)
curl -sS -b cookies.txt http://localhost:<port>/api/<x>

# <Endpoint 2> (admin only)
curl -sS -X PUT -b cookies.txt -H "Content-Type: application/json" \
     -d '{"<key>": <value>}' http://localhost:<port>/api/<x>
```

## Merge plan

<Most important section — David will execute this. Explicitly call out NON-OBVIOUS steps.>

1. ✅ Smoke (this PR's verifier already done, see above)
2. ⏭️ **<non-obvious step, e.g. "Web container re-build">** — IMPORTANT: <one-paragraph why + exact command>. If merge-bot / CI / David 唔做呢步,<concrete consequence — e.g. "production 會行 stale Step 5 嘅 bundle,SettingsLayout 7 tabs / Tax UI 全部唔見">。
3. ⏭️ `git checkout main && git merge --no-ff <branch>`
4. ⏭️ `git push origin main` (or open PR via <custom git server's UI>)
5. ⏭️ Run `<migration / seed / smoke>` once on prod — <why required — e.g. "latent-bug fix requires fresh Role/RolePermission rows; existing prod DB was seeded before this branch">

## Out of scope (deliberately)

- <file 1> (<reason — e.g. "David's WIP, sacred, do not `git add` here">)
- <file 2> (<reason — e.g. "scratch doc, not part of the ship">)
- <known issue> (filed as future polish)

---

🤖 Generated with [Hermes Agent](https://hermes.nousresearch.com) + smoke verified
