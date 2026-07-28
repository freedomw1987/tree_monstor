---
name: pagination-with-preserved-aggregates
description: Add server-side pagination to an admin list page WITHOUT breaking summary stats (count/sum/avg) or full-dataset exports (Excel/CSV). The core invariant — stats cards and exports always read from a server aggregate over the FULL filtered set, while the table view is paged. Trigger when the user says "the list page is slow, add pagination", "the page loads thousands of rows", "stats are wrong after I added pagination", "Excel export must include everything even when I paginate", or "total count drops as I change pages". Class-level — applies to any admin/data-table page (orders, users, audit logs, transactions, work logs, time entries) on any ORM (Prisma/Drizzle/Sequelize) and any backend framework (Elysia/Express/Fastify/Hono/NestJS).
trigger: "adding pagination to a list page / list page is slow with many rows / need Excel export that includes all data even when paginated / stats cards disagree with the table / total count changes as I click next page / 'slow list page' / 'add pagination'"
category: software-development
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Pagination With Preserved Aggregates

The recurring failure mode: someone adds `findMany({skip, take})` to fix slow list pages, and then **summary stats, page count, and Excel exports silently break** — because the same `findMany` was the only place computing totals, and now it only sees the current page.

The fix is a **two-query design**: `findMany` returns the page, `aggregate` returns the full-dataset stats. The two share the same `where` filter. The frontend reads totals from the aggregate, not from `pagedRows.length`.

## When This Pattern Applies

Use this pattern when **all** of these are true:

- A list page renders N rows (orders, logs, users, etc.)
- The same page shows **summary cards** (總計 / 記錄筆數 / 平均) computed from those rows
- The same page (or a sibling) has an **Excel/CSV export** that should include all matching rows, not just the visible page
- A filter UI lets the user narrow the dataset (project, date range, status, user)
- The dataset is large enough that loading all rows is slow

If the page has none of stats / export / filters, plain pagination is fine. If the page has no pagination yet but the dataset is growing, **proactively** use this pattern.

## Backend: Two-Query Design

```ts
// In your list route handler (Elysia / Express / Fastify example)
.get('/', async ({ query, user }) => {
  // 1. Build the SHARED where filter ONCE.
  //    This is the single source of truth for "what rows are in scope."
  const where: any = { /* projectId, date range, status, etc. */ }
  applyAuthScope(where, user)  // optional: restrict to user's own records

  // 2. Parse pagination params. Default page=1, pageSize=50, max=200.
  //    `limit=-1` is a sentinel meaning "no limit" (used by Excel export).
  const DEFAULT_PAGE_SIZE = 50
  const MAX_PAGE_SIZE = 200
  const rawLimit = query.limit !== undefined ? Number(query.limit) : NaN
  const wantsAll = !Number.isNaN(rawLimit) && rawLimit === -1
  const hasExplicitLimit = !Number.isNaN(rawLimit) && rawLimit > 0

  const pageSize = Math.min(
    Math.max(Number(query.pageSize) || DEFAULT_PAGE_SIZE, 1),
    MAX_PAGE_SIZE
  )
  const page = Math.max(Number(query.page) || 1, 1)
  const skip = (wantsAll || hasExplicitLimit) ? 0 : (page - 1) * pageSize
  const take = wantsAll ? undefined : hasExplicitLimit ? rawLimit : pageSize

  // 3. Server-side aggregate over the FULL filtered set.
  //    This is what stats cards + Excel totals read from.
  //    CRITICAL: it uses the SAME `where` as findMany. Never page the aggregate.
  const aggregate = await prisma.workLog.aggregate({
    where,                                      // <-- shared where
    _sum: { hours: true },
    _count: { _all: true }
  })
  const totalCount = aggregate._count._all
  const totalHours = Number(aggregate._sum.hours || 0)

  // 4. Paged findMany for the table view.
  const rows = await prisma.workLog.findMany({
    where,                                      // <-- same where
    include: { /* relations */ },
    orderBy: { date: 'desc' },
    ...(skip ? { skip } : {}),
    ...(take !== undefined ? { take } : {})
  })

  // 5. Return BOTH the page and the full-dataset stats.
  return {
    workLogs: rows.map(serialize),
    totalCount,                                 // <-- full set count
    totalHours: round2(totalHours),             // <-- full set sum
    page: wantsAll || hasExplicitLimit ? 1 : page,
    pageSize: wantsAll ? totalCount : hasExplicitLimit ? rawLimit : pageSize,
    totalPages: wantsAll || hasExplicitLimit
      ? 1
      : Math.max(Math.ceil(totalCount / pageSize), 1)
  }
})
```

### Why `limit=-1` instead of a separate `/export` route

- Single endpoint, single set of auth/permission/filter logic to maintain
- Excel export's filter context is always identical to the table's (they share `where`)
- Easy to test: same assertions cover both code paths
- When the export grows to 100K+ rows, *then* consider a streaming endpoint

### ORM-specific notes

| ORM | Aggregate call | Full-dataset count |
|-----|----------------|-------------------|
| **Prisma** | `prisma.model.aggregate({ where, _sum, _count: { _all: true } })` | `_count._all` |
| **Drizzle** | `db.select({ sum: sql\`SUM(${col})\`, count: sql\`COUNT(*)\` }).from(table).where(where)` | `count` |
| **Sequelize** | `Model.findAll({ where, attributes: [[fn('SUM', col), 'sum'], [fn('COUNT', col), 'count']], raw: true })` | `count` |
| **Raw SQL** | `SELECT COUNT(*), SUM(col) FROM table WHERE <same where>` | always available |

The principle is identical: same `WHERE` clause, two queries, one paged, one not.

## Frontend: State Machine + UI

```tsx
// WorkLogsPage.tsx — the key pieces

// 1. Two pieces of state, not one
const [currentPage, setCurrentPage] = useState(1)
const [pageSize, setPageSize] = useState(50)
const [totalPages, setTotalPages] = useState(1)

// 2. Server-side stats — SEPARATE state from the row data
const [serverTotalCount, setServerTotalCount] = useState(0)
const [serverTotalHours, setServerTotalHours] = useState(0)

// 3. The load function — always pass page + pageSize, ALWAYS read totals from response
const loadData = async () => {
  const params = { ...filterParams, page: currentPage, pageSize }
  const res = await workLogApi.list(params)
  setRows(res.data.rows || [])
  // CRITICAL: read totals from response, NOT from rows.length / rows.reduce
  setServerTotalCount(res.data.totalCount ?? 0)
  setServerTotalHours(res.data.totalHours ?? 0)
  setTotalPages(res.data.totalPages ?? 1)
}

// 4. Two useEffects — page triggers refetch, filter change resets page.
//    Combining them causes double-fetches (page reset → re-fires loadData →
//    then the original change fires loadData again).
useEffect(() => { loadData() }, [filters, currentPage, pageSize])
useEffect(() => { setCurrentPage(1) }, [filters])  // filter change → page 1

// 5. Stats cards read from serverTotalCount, NOT from rows.length
<p>總計時數：{serverTotalHours.toFixed(1)}h</p>
<p>記錄筆數：{serverTotalCount} 筆</p>

// 6. Excel export uses limit=-1 to get the full set in one call
const exportExcel = async () => {
  const res = await workLogApi.list({ ...filterParams, limit: -1 })
  const allRows = res.data.rows || []
  // ... build xlsx from allRows (NOT from the paged state)
}

// 7. Pagination controls — visible only when there are rows to page
{rows.length > 0 && (
  <div>
    第 {(currentPage-1)*pageSize + 1}–{Math.min(currentPage*pageSize, serverTotalCount)} 筆，
    共 {serverTotalCount} 筆
    <select value={pageSize} onChange={e => setPageSize(Number(e.target.value))}>
      <option value={20}>20</option><option value={50}>50</option>
      <option value={100}>100</option><option value={200}>200</option>
    </select>
    <button onClick={() => setCurrentPage(1)} disabled={currentPage <= 1}>«</button>
    <button onClick={() => setCurrentPage(p => Math.max(1, p-1))}>上一頁</button>
    第 {currentPage} / {totalPages} 頁
    <button onClick={() => setCurrentPage(p => Math.min(totalPages, p+1))}>下一頁</button>
    <button onClick={() => setCurrentPage(totalPages)} disabled={currentPage >= totalPages}>»</button>
  </div>
)}
```

### The Double-Fetch Trap

If you put the page-reset inside the same `useEffect` as `loadData`:

```tsx
// ❌ WRONG — runs loadData on filter change, then resets page, then runs loadData AGAIN
useEffect(() => {
  setCurrentPage(1)        // triggers second render → second loadData
  loadData()
}, [filters])
```

Two effects with separate dependency arrays is the fix:

```tsx
// ✅ RIGHT — filter change resets page, both changes trigger exactly one loadData
useEffect(() => { loadData() }, [filters, currentPage, pageSize])
useEffect(() => { setCurrentPage(1) }, [filters])
```

## Pitfalls

- **Forgetting the aggregate** — A junior dev adds `skip`/`take` to `findMany` and the totals "shrink" to the current page. The fix is the second query. *Symptom*: 「總計」 card value depends on which page is loaded.
- **Page-out-of-range returning wrong total** — `page=999&pageSize=50` on a 137-row dataset should return `[]` AND `totalCount=137`. Test this — the aggregate must run regardless of `skip`/`take`.
- **Excel export reads from paged state** — Frontend `exportExcel()` uses `filteredLogs.map(...)` but `filteredLogs` is now just the current page. Switch to a second `workLogApi.list({...filters, limit: -1})` call. *Symptom*: 「導出Excel 只得 50 行,但我見到有 300 行」.
- **Aggregate is not paged but its result is per-page by mistake** — Some ORMs/patterns compute totals from `rows.reduce(...)` on the client. This computes page totals, not full-set totals. The aggregate is the source of truth.
- **Filter changes don't reset to page 1** — User narrows date range to a single day, current page is 8, totalPages is 28, page 8 is now empty. Symptom: 「點解第 8 頁空白?」 Fix: separate `useEffect` resets `currentPage=1` on filter change.
- **Default page size too large or too small** — 1000 is still slow on big datasets (still transfers all of page 1); 10 is annoying for users. **50 is a sensible default**, with 20/50/100/200 as user options.
- **Group-by / aggregate view shouldn't paginate** — If the same endpoint supports `?groupBy=day` for chart-style aggregation, that mode returns N groups (one per day/week/month). It's already a small full-dataset result, **don't apply `skip`/`take` to it**. Branch: `if (groupBy) { /* aggregate, no pagination */ } else { /* paginated list */ }`.
- **Out-of-range page returns 200 with empty array** — Don't 404 on `page > totalPages`. Return `{rows: [], totalCount, totalPages}` and let the UI render the "no rows" state. A 404 would force the frontend to handle error cases that aren't really errors.
- **`limit=0` vs `limit=-1` confusion** — Pick a clear convention. Recommended: `limit=-1` = "give me everything" (sentinel for export); `limit=undefined` = "use page/pageSize defaults". A `limit=0` should probably return `[]` (the user's literal request).
- **Total pages rounded to 0** — `Math.ceil(0 / 50) = 0`. Show 1 page minimum so the "第 1 / 0 頁" UI never happens. Use `Math.max(Math.ceil(totalCount / pageSize), 1)`.
- **`limit: -1` 唔好用喺 dashboard / list render page — 用途只係 dropdown filter 同 export (2026-06-10 pm-system Sprint 14)**:有人喺 `DashboardPage.tsx` 寫 `projectApi.list({ limit: -1 })` 想「載晒全部項目顯示喺 dashboard」,結果 196 個項目 card 全部 render → 截圖 91834px tall (fullPage screenshot tool 爆),PIL 都開唔到,RWD audit 完全冇 feedback。**Rule**:
  - **`limit: -1` 三個合法 use case**: ① 真正 dropdown filter(WorkLogs / Reports 嘅 `<ProjectAutocomplete>` 揀項目,type-ahead 需要全部); ② Excel/CSV export; ③ Server-side 嘅 full-dataset aggregate (stats card)
  - **`limit: -1` 唔可以用喺**: ① Dashboard 嘅 widget list; ② 任何 page 嘅「render N 個 card 嘅 grid」; ③ Search 結果 list(unless 用 type-ahead dropdown)
  - **冇辦法要 render 全 list 嘅正確做法**: `{ page: 1, pageSize: 12 }` + 顯示 `totalCount` 喺 widget + 加「睇更多 (184+)」link 去 `/projects` 完整 list
  - **Symptom of 誤用**:`document.body.scrollHeight > 5000px` 喺 dashboard/list render page,或者 fullPage screenshot 報 PNG 解碼失敗
  - **同 `pagination-with-preserved-aggregates` pattern 嘅關係**:呢個 pitfall 講 `limit: -1` **frontend 邊**嘅正確用途 (`pagination-with-preserved-aggregates` 入面講 `limit: -1` **backend 點 implement + export 用法**)— 兩個 skill 守同一個 sentinel 嘅兩端

## Smoke Test (Required)

Every pagination refactor should ship with a smoke test that asserts the **invariant** holds:

```python
# /tmp/pagination_smoke.py — write to /tmp, NOT to project repo
import urllib.request, json

# Login
token = login("admin@test.com", "admin123")

# 1. Page 1 and page 2 return disjoint rows
p1 = get(f"/api/things?page=1&pageSize=5", token)
p2 = get(f"/api/things?page=2&pageSize=5", token)
assert p1["totalCount"] == p2["totalCount"],  "totals differ between pages"
assert p1["totalHours"] == p2["totalHours"],  "sums differ between pages"
assert set(p1["rows"]) & set(p2["rows"]) == set(), "page overlap"

# 2. limit=-1 returns the full set
all = get(f"/api/things?limit=-1", token)
assert len(all["rows"]) == all["totalCount"]

# 3. Default pageSize is what you documented
default = get(f"/api/things", token)
assert len(default["rows"]) == min(50, default["totalCount"])

# 4. Out-of-range page returns empty + correct total
oob = get(f"/api/things?page=999&pageSize=50", token)
assert oob["rows"] == []
assert oob["totalCount"] == default["totalCount"]

# 5. Group-by mode is unaffected (still returns full aggregate, no pagination)
g = get(f"/api/things?groupBy=day", token)
assert "groupedData" in g
assert g["grandTotal"] == default["totalHours"]   # sum is preserved
```

Write this to `/tmp/<feature>_pagination_smoke.py` and run it after the backend rebuild. Don't put it in the project repo unless you're adding it to the actual test suite (`bun test`, `pytest`).

## When NOT to Use This Pattern

- **Read-only pages with no summary stats and no export** — Just paginate. No aggregate needed.
- **Single-row-of-detail pages** — Not a list, no pagination.
- **Server already returns totals in a separate `/stats` endpoint** — Just consume that. Don't add a second aggregate.
- **Dataset is bounded and small (≤200 rows)** — No pagination needed. Loading all rows is faster than the round-trip cost of paginating.
- **Real-time feeds / activity streams** — Use cursor pagination (after-ID, before-timestamp). Page numbers are wrong for append-only data.

## Related Skills

- `frontend-backend-integration` — verify wire shape against backend source before writing the API client wrapper (includes the typed client request/response shape discipline)
- `archive/skills/case-history/prisma-relation-debugging` (archived) — Prisma relation field issues (e.g. `manDayLines` vs `manDays` name drift)
- `regression-guard` — record this as RG-XXX if a wrong-pagination bug regresses
- `docker-mac-arm64-elysia-vite` — full-stack dev loop on Mac arm64 (rebuild + smoke test pattern)
