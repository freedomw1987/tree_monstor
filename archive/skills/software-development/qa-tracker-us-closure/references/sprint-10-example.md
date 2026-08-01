# PM-System Sprint 10 — Worked Example (2026-06-10)

Three P0 US closures from a single session, all per-US commit cadence. This is what the rhythm looks like when it goes well.

## Starting state

Tracker showed 16 US with `NONE`. David asked "逐個" (one by one), then default plan was 1 sprint (5-7 US, P0 first). Three of those US are documented here.

## Pre-work

```bash
cd ~/www/pm-system && git pull
# Audit NONE list:
awk -F'|' 'NR>=15 && /US-/' docs/QA-TRACKER.md | \
  awk -F'|' '{gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$7); \
    if ($7=="NONE") print $2}' | head -20
# → 16 US including US-2.3/2.4/3.5/4.4/4.5/6.4
```

Sprint 10 scope locked to 6 P0 remaining US. Order chosen by S/M/L estimate: 6.4 → 3.5 → 4.4 → 2.4 → 2.3 → 4.5.

## Commit #1 — US-6.4 worklogs filter + RBAC (df8c4dd)

**Audit findings**:
- `worklogs.ts:24-62` — GET endpoint with inline where-clause composition
- No exported helper, all logic inline in `.get('/', ...)` handler
- `worklogs.test.ts` already had pagination + cutoff tests using a derive pattern

**Decision**: derive `buildWorkLogFilterWhere(query, currentUser, canViewAll)` in `worklogs.test.ts`, mirroring the inline source.

**Test categories** (9 cases total):
- RBAC gate (3): non-admin 強制 userId, non-admin 忽略 query.userId, non-admin 忽略 query.departmentId
- Admin filter (2): query.userId 過濾, query.departmentId 過濾
- Composition (2): projectId OR 跨 task+bug, date range 23:59:59.999
- Combination (1): departmentId + userId 並存
- Edge (1): empty filter 返 `{}`

**Tracker sync (4 spots)**:
1. US-6.4 row: `NONE` → `**PASS-UNIT** 🟢 (Sprint 10: 9 tests — RBAC gate non-admin 強制 userId + admin departmentId + OR projectId + date range 23:59:59.999)`
2. Metrics: `P0 US PASS-UNIT only: 22 → 23`
3. Metrics: `Unit tests 總數: 549 → 558`
4. Sprint history: new row for 2026-06-10

**Result**: 558/558 pass, push `67707ea..df8c4dd`, revert check ✅.

## Commit #2 — US-3.5 requirement rich-text (e45626b)

**Audit findings**:
- `requirements.ts:81, 113, 136, 177` — `description: t.Optional(t.String())` only, no backend validation
- `RichTextEditor.tsx:75-78` — frontend onChange has `<p></p>` → `''` normalize
- The invariant lives in the FRONTEND; backend just stores string

**Decision**: derive `normalizeRichTextDescription` + `isMeaningfulDescription` in `requirements.test.ts`, document the source (Tiptap behavior) in a comment.

**Test categories** (11 cases total):
- normalize: undefined → '', null → '', `<p></p>` → '', `<p>   </p>` preserved, `<p>hello</p>` preserved, complex HTML with `<strong>` + `<img>` preserved
- isMeaningful: null/undefined → false, empty/whitespace → false, `<p></p>` → false, `<p>  </p>` → false, any content → true

**Lesson**: when the US is "support rich text", the test boundary is at the **frontend/backend seam** — what does the round-trip look like, and what edge cases (Tiptap empty wrapper) leak through?

**Tracker sync (4 spots)** — same pattern as commit 1, US-3.5 row + metrics 23→24, 558→569.

**Result**: 569/569 pass, push `df8c4dd..e45626b`, revert check ✅.

## Commit #3 — US-4.4 task ↔ requirement link (3b93dba)

**Audit findings**:
- `tasks.ts:50-66` — `export const resolveTaskProjectId` already exported!
- `tasks.ts:68-84` — `export const buildTaskListWhere` already exported!
- `tasks.test.ts` already has 2 test cases using the exports

**Decision**: source-import the helpers, NOT derive. This is more stable and signals "this is the real implementation under test" rather than "this is a copy of the logic".

**Test categories** (6 cases total):
- buildTaskListWhere (3): requirementId filter, requirementId + projectId, 冇 requirementId → 唔加 filter
- resolveTaskProjectId (3): cross-project error, same-project OK, empty → `{ projectId: undefined }`

**Lesson**: **always check `export` first** before deciding derive vs source-import. Deriving when source is exported wastes effort and creates drift risk.

**Tracker sync (4 spots)** — same pattern, US-4.4 row + metrics 24→25, 569→575.

**Result**: 575/575 pass, push `e45626b..3b93dba`, revert check ✅.

## Cumulative Sprint 10 (so far)

| Commit | US | Pattern | Tests added |
|--------|-----|---------|-------------|
| df8c4dd | US-6.4 | derive | 9 |
| e45626b | US-3.5 | derive (frontend invariant) | 11 |
| 3b93dba | US-4.4 | source-import | 6 |
| **Total** | 3 US | — | **+26 tests** |

Suite: 549 → 575 pass (+26). P0 US PASS-UNIT: 22 → 25.

## Pattern observations

- **2 of 3 commits used derive** (logic was inline), **1 used source-import** (logic was already exported). This is a 67/33 split, which is roughly the expected distribution in a typical codebase (most route logic is inline).
- **Tracker sync touch count is constant** (4 spots) regardless of US complexity. The 4th spot (sprint history row at bottom of file) is the easiest to forget — verify by reading the file end after patch.
- **Revert check is 2 commands** (`git log origin/master..HEAD` + `git log -3 origin/master`), takes 3 seconds, has caught real issues in past projects.
