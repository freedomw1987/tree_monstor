---
name: list-search-box
description: Add a search box to an existing React list page — client-side filter on the visible page (no server roundtrip). Covers the two-layer empty state (raw empty vs filter empty), header flex layout (button + search input), `useMemo` over `[data, query]`, and the 3-step "remove standalone page" checklist when a search box replaces a dedicated list page. Trigger when user says "加 search box" / "搜尋" / "filter list" / "拎走 menu + 加 search" / "list 加 search" / "list page 加 search" on a React/TypeScript frontend, or when a user says "menu 不用有" implying a standalone page should be retired in favor of sub-page search.
applicability: generic-pattern
---


Last-verified: 2026-07-28
# List Search Box (React)

> **The "係咪 list 有就加 search" pattern** — 任何 React list page 加 search box 嘅
> 標準做法。Client-side filter 起步, server-side 升級 path 留定。

## 觸發時機

- 用戶講「list 加 search box」「搜尋 list」「呢個 page 加個 search」
- 用戶拎走 standalone list page 但保留 sub-page list → 後者要加 search
- 任何 React list page (`map()` 渲染 row) 缺 search affordance
- 用戶講「我搵唔到 XXX」但 list 已經有對應 row → 加 search
- 唔適合:server-side filter 已經有 (例如 dropdown filter), 加 search 變 redundant

## 7 個 class-level steps

### Step 1: 確認 scope — client-side 定 server-side

**Default: client-side filter**(用戶冇 specify 就 client-side)。Reason:
- List 一頁 10-50 row, 唔需要 server roundtrip
- Type 即時 filter UX 較好(無 debounce 都需要)
- Backend 唔使改, 風險低

**Server-side 嘅 case**(先 client-side, 之後再升):
- List > 100 row 同 user 想搜「過去一年嘅」
- Search 要 match description / assignee name(超過 title field)
- Multi-field search (title + tags + description)

**推 David 揀 client-side** 嘅話術:「而家 list 細,client-side filter 即時 type 即時 filter,唔撞 backend,最簡單。將來 list 大咗我哋改 server-side,加 Prisma `contains` 同 index,大概 2 個鐘 work。」

### Step 2: 揀 field — 只 match title, 唔 match description

```tsx
// ✅ Default — match primary visual field
const filteredX = useMemo(() => {
  const q = searchX.trim().toLowerCase()
  if (!q) return x
  return x.filter(item => item.title.toLowerCase().includes(q))
}, [x, searchX])
```

**Why title only**:Search result 同 list row display 一致(用戶睇 row 嘅 title,搜尋就係嗰個字)。
**Why not description**:Description 係 long text,「張三」可能 hit 中 description 入面一個字,出嚟嘅結果冇 context 對應。
**Why not assignee / tags**:User 預期「我打咗 keyword 應該見到 title 嗰 row」, 唔 expect 跨 field 搜尋。

**後續升級**:User 投訴「搜『張三』要搵到佢 assignee 嘅 task」, 加 `|| item.assignee?.name.toLowerCase().includes(q)`。Hold 住唔 over-engineer。

### Step 3: `useMemo` over `[data, query]`, 唔好 inline filter

```tsx
// ❌ Inline filter — 每次 re-render 都行, modal toggle 都 trigger
{x.filter(item => item.title.toLowerCase().includes(searchX)).map(...)}

// ✅ useMemo — 只 source data / search string 改先做 work
const filteredX = useMemo(() => {
  const q = searchX.trim().toLowerCase()
  if (!q) return x
  return x.filter(item => item.title.toLowerCase().includes(q))
}, [x, searchX])

// 然後 render 用 filteredX
{filteredX.map(...)}
```

**Why useMemo**:Even 細 list 都有 best practice 嘅 value — toggle modal / hover 都 trigger re-render, inline filter 跑多次浪費。`useMemo` 確保只 source 改先 re-compute。

### Step 4: Header flex layout — button 同 search input 並排

```tsx
<div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
  {hasAnyPermission(user, ['x.create']) && (
    <button onClick={openCreate} className="btn-primary flex items-center gap-2 w-full sm:w-auto justify-center">
      <Plus size={20} /><span>新建 X</span>
    </button>
  )}
  <div className="relative w-full sm:w-72">
    <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
    <input
      type="text"
      value={searchX}
      onChange={(e) => setSearchX(e.target.value)}
      placeholder="搜尋 X..."
      aria-label="搜尋 X"
      className="w-full pl-9 pr-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
    />
  </div>
</div>
```

**規則**:
- **`flex-col sm:flex-row`**: Mobile 直排(button 上, search 下), desktop 並排(button 左, search 右)
- **`sm:w-72`** (18rem ≈ 288px) 喺 desktop 唔好 full-width, 留返位置比將來加其他 filter
- **`Search` icon** 絕對定位喺 input 左邊,`pointer-events-none` 避免 click 穿過
- **`aria-label="搜尋 X"`**: 唔靠 placeholder 嘅唯一 a11y 信號(placeholder 唔係 accessible name)
- **Permission-gated button**: 用 `hasAnyPermission(user, ['x.create'])` 包住,user 冇 create 權限就 button 唔 render,search input 移去右邊
- **RWD verify**: 開 Chrome DevTools mobile view 睇, search input 唔可以同 button 碰撞
- **Header variant**: 唔係所有 list page header 都係 single row。兩欄 layout (list sidebar + content pane) 同 upload/action bar 旁嘅變體寫法見 [`references/<project>-step4b-component-variants.md`](references/<project>-step4b-component-variants.md)

### Step 5: 2 層 empty state — raw empty vs filter empty

**死都唔可以合埋做一個 empty state**。理由:
- 「真係冇 data」vs「搜尋無結果」係兩個完全唔同嘅 UX
- 用戶打錯 keyword 同 個 list 真係空, 提示應該分開

```tsx
{x.length === 0 ? (
  // ① Raw empty: 真係冇 data
  <div className="card p-12 text-center">
    <FileText size={48} className="mx-auto text-gray-400 mb-4" />
    <h3 className="text-lg font-medium text-gray-900 mb-2">暫無 X</h3>
    <p className="text-gray-500">為 XX 添加第一個 X</p>
  </div>
) : filteredX.length === 0 ? (
  // ② Filter empty: 搜尋無結果
  <div className="card p-12 text-center">
    <Search size={48} className="mx-auto text-gray-400 mb-4" />
    <h3 className="text-lg font-medium text-gray-900 mb-2">無符合「{searchX}」嘅 X</h3>
    <p className="text-gray-500">試下其他關鍵字,或清空搜尋框</p>
  </div>
) : (
  // ③ 有 results
  <div className="space-y-3">
    {filteredX.map((item) => (...))}
  </div>
)}
```

**規則**:
- **順序重要**:`x.length === 0` 先 check(原始空),然後 `filteredX.length === 0`(filter 後空)
- **唔好**用同一個 empty state 包兩個 case,UX 訊息會誤導
- **`searchX` echo 入 title**: 用戶見到自己打咗咩 keyword, debug 容易

### Step 6: 拎走 standalone page 嘅 3-step checklist (配套 push back 用)

**情境**:用戶講「menu 不用有」,但 sub-page 仲要 list X。3 步走:

1. **`Layout.tsx` 拎走 nav item** (1 line delete)
2. **`App.tsx` 拎走 route** (`<Route path="x" element={<XPage/>}>` + `import XPage from './pages/XPage'`)
   - **保留** detail page 嘅 route (`<Route path="x/:id" element={<XDetailPage/>}>`) — 從 sub-list / 我的 X 跳過嚟仲要 work
3. **`BugsPage.tsx` 整個 file delete** (死 code 唔留)

**跟住嘅 cross-reference audit**(容易 miss):
- **Back-link grep**: `grep -n "/x\b" pages/XDetailPage.tsx` 拎出所有 back-link, 改去合理 destination
  - Default: 改去「我的 X」(`/my-x`) — 從「我的」click row 入 detail, back 返「我的」最自然
  - User-contextual: 用 `location.state.from` 或者 query string `?from=project` 攞 entry path, render 動態 back link
- **E2E test grep**: `grep -n "/x\b\|XPage" e2e/tests/*.spec.ts` 拎出 reference
  - 拎走 route 會 break test, 用 `test.skip` + deprecation comment 標住
  - **唔好默默 delete test** — 留低審計 trail, 下次 sprint 補 QA-TRACKER `DEPRECATED` 標記
- **TypeScript import cleanup**: `import XPage from './pages/XPage'` 拎走

**Class-level lesson**:
- **用戶 wording 要 parse 多次**: 一句「menu 不用有」嘅 scope 可能包括 nav item + route + page file + back-link + E2E test
- **每收到一條 feedback 即 push back 一次**, 帶 2-3 個 options + 自己推薦, 唔好悶頭做
- **落手前用 5-15 分鐘 grep + audit** confirm 上面 3-step scope checklist, 比做錯 scope 再改省時間
- 真實 session 對話同 push back 記錄見 [`references/<project>-session-lessons.md`](references/<project>-session-lessons.md)

### Step 7: Server-side 升級 path(預備, 唔做)

如果將來 list > 100 row 用戶投訴 lag, 改用 server-side:

```tsx
// Backend — Prisma
const bugs = await prisma.bug.findMany({
  where: {
    title: { contains: query, mode: 'insensitive' },  // PG only
    // SQLite 用 LIKE 替代: title: { contains: query }
  }
})

// Frontend — debounce + server call
const [searchBug, setSearchBug] = useState('')
useEffect(() => {
  const timer = setTimeout(() => loadBugs({ search: searchBug }), 300)
  return () => clearTimeout(timer)
}, [searchBug])
```

**PG vs SQLite 嘅差異**:
- `mode: 'insensitive'` 只 PG 支援
- SQLite 用 `LIKE '%query%'` (case-insensitive by default for ASCII)
- 詳細 pitfall 見 `prisma-sqlite-bun-setup`

**Hold 住唔做嘅 trigger**:
- 用戶投訴「搜尋好慢」/「結果唔啱」/「想搜 description」
- List > 200 row 同 user 想搜「過去 30 日嘅」
- Multi-field search 成為常見 action

## Pitfalls (David 撞過, 後人必讀)

### 🚨 1. Inline filter 唔 useMemo(performance 唔必要咁差)

```tsx
// ❌ 每次 re-render (toggle modal, hover, parent state change) 都重 filter
{x.filter(item => item.title.toLowerCase().includes(searchX)).map(...)}

// ✅ useMemo cache filter result
const filteredX = useMemo(() => {...}, [x, searchX])
{filteredX.map(...)}
```

**Symptom**: 細 list (10 row) 唔覺眼, 大 list (50+ row) 用戶撳 modal 之後有 micro-stutter。
**Fix**: 一律 `useMemo`, 一致 pattern, 唔好按 list size 揀。

### 🚨 2. Empty state 唔分兩層(UX 致命)

```tsx
// ❌ 合埋一個 empty state
{filteredX.length === 0 ? (
  <div>暫無 X</div>  // 唔分 raw empty 同 filter empty
) : ...}

// ✅ 分兩層
{x.length === 0 ? (
  <div>暫無 X</div>  // raw empty
) : filteredX.length === 0 ? (
  <div>無符合「{searchX}」嘅 X</div>  // filter empty
) : ...}
```

**Symptom**: 用戶打錯 keyword 之後, 個 empty state 寫「暫無 X」, 用戶誤以為個 list 真係空, 唔係自己打錯字。
**Fix**: 一律 2 層, 一致 pattern, 唔好省 empty state。

### 🚨 3-4. 拎走 standalone page 之後漏 back-link / 漏 skip E2E test

**Rule (back-link)**: 拎走 route 之後 detail page 嘅 back-link 仲指舊 path, 用戶撳「返回」會落到 blank page (react-router fallback 返 `/`)。一律 `grep -rn "/x\b" frontend/src/pages/XDetailPage.tsx` audit, 改去仍然存在嘅 destination。

**Rule (E2E)**: 引用該 route 嘅 E2E test 要 `test.skip` / `describe.skip` + deprecation comment, 同步更新 QA-TRACKER / PRD 標 DEPRECATED。**唔好默默 delete test** — 留 audit trail。

**<project> `/bugs` 實例**: [`references/<project>-bugs-page-removal-pitfalls.md`](references/<project>-bugs-page-removal-pitfalls.md)

### 🚨 5. Search box 同 create button 撞 layout (RWD mobile)

```tsx
// ❌ Desktop / mobile 都用 flex-row, mobile 撞
<div className="flex items-center justify-between gap-3">
  <button>新建 X</button>
  <input className="w-72" />
</div>

// ✅ flex-col (mobile 直排) + sm:flex-row (desktop 並排)
<div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
  <button>新建 X</button>
  <div className="relative w-full sm:w-72">
    <input className="w-full ..." />
  </div>
</div>
```

**Symptom**: Mobile 開個 page, search input 同「新建 X」掣 side-by-side 撞, 兩個都睇唔晒。
**Fix**: 一律 `flex-col sm:flex-row`, 開 `frontend/rwd-mobile-audit` skill verify。

### 🚨 6. Search 範圍只 title, 用戶投訴要 match 跨 field

**情境**: 用戶打「張三」想搵 `assignee.name = "張三"` 嘅 task, 但 search 只 match title, 結果空白。
**Root cause**: 過早定 scope「只 title」(Step 2)。
**Fix**:
- **預期**用戶會投訴, 唔係 bug, 係 scope 決定
- 投訴出現時, 加 `|| item.assignee?.name.toLowerCase().includes(q)` 一行 code
- **唔好 over-engineer** 開頭做 multi-field search, hold 住 user feedback

### 🚨 7. `aria-label` 唔靠 placeholder

```tsx
// ❌ 冇 aria-label, 純靠 placeholder (placeholder 唔係 accessible name)
<input placeholder="搜尋 X..." />

// ✅ 顯式 aria-label
<input placeholder="搜尋 X..." aria-label="搜尋 X" />
```

**Symptom**: Screen reader 讀唔到「搜尋 X」, 因為 placeholder 唔係 ARIA accessible name 嘅標準來源。
**Fix**: 一律 `aria-label="搜尋 X"`, 唔好慪。

## Code Templates

完整 pattern code 喺:
- `templates/list-search-box-with-empty-states.tsx` — search box + 2 層 empty state + useMemo filter 嘅 full code
- `templates/remove-standalone-page-checklist.md` — 拎走 standalone page 嘅 3-step + cross-reference audit checklist


## Audit Checklist (做完必跑)

| # | 檢查項 | 點 verify |
|---|---|---|
| 1 | `useMemo` over `[data, query]`, 唔 inline filter | `grep "useMemo" page.tsx` |
| 2 | Search box 同 create button 用 `flex-col sm:flex-row` | Visual inspect + RWD mobile |
| 3 | 2 層 empty state 分開 (raw empty vs filter empty) | `grep "x.length === 0" page.tsx` 應該有兩個 branch |
| 4 | Search input 有 `aria-label` | `grep "aria-label" page.tsx` |
| 5 | Search input 有 `Search` icon 喺左 | Visual inspect |
| 6 | Filter 只 match `title` field | `grep "item.title.toLowerCase" page.tsx` |
| 7 | 拎走 standalone page 之後 grep back-link 全部 updated | `grep "/x\b" pages/XDetailPage.tsx` |
| 8 | 拎走 standalone page 之後 E2E test `test.skip` + deprecation comment | `grep "test.skip\|deprecated" e2e/tests/*.spec.ts` |
| 9 | TypeScript 0 error | `bunx tsc --noEmit` |
| 10 | RWD mobile audit 過 | `frontend/rwd-mobile-audit` skill verify |
| 11 | **Component variant**: 兩欄 layout (list sidebar + content) search 喺 sidebar header **下面** own row, 唔同行 justify-between (variant A) | Visual inspect |
| 12 | **Component variant**: Upload/action bar 旁 search 用 `sm:ml-auto` keep right-aligned 即使 canUpload 係 false (variant B) | Visual inspect |

## 配套 skills

- `frontend/related-entity-entry-points` — 任何 sub-list 嘅 parent-child UX
- `frontend/rwd-mobile-audit` — search box 嘅 mobile layout verify
- `frontend/react-router-v7-patterns` — 拎走 route 嘅 back-link handling + sibling route collision check
- `prisma-sqlite-bun-setup` — server-side search upgrade 嘅 Prisma contains 寫法
- `software-development/qa-tracker-us-closure` — 拎走 standalone page 嘅 US DEPRECATION 同步(US row → `❌(DEPRECATED) ⚫` + `test.skip`/`describe.skip` + PRD strikethrough)

## Project case history

Detailed <project> narratives live in `references/` so this skill stays a reusable pattern.

| Topic | Reference |
|---|---|
| 拎走「全部缺陷」menu + 5 個 list 加 search (2026-06-09) | [`<project>-2026-06-09-bugs-menu-remove-and-search-add.md`](references/<project>-2026-06-09-bugs-menu-remove-and-search-add.md) |
| Sprint 11: Wiki/Attachments variant + E2E deprecation (commit `8c99f32`) | [`<project>-2026-06-09-sprint-11-wiki-attachments-and-deprecate.md`](references/<project>-2026-06-09-sprint-11-wiki-attachments-and-deprecate.md) |
| Sprint 14: `/projects` search + RWD header + autocomplete + dashboard | [`<project>-2026-06-10-sprint-14-projects-search-rwd-autocomplete-dashboard.md`](references/<project>-2026-06-10-sprint-14-projects-search-rwd-autocomplete-dashboard.md) |
| Sprint 14+15: 4 個新 pitfall + `?scope=my` pattern | [`<project>-2026-06-10-sprint-14-sprint-15-projects-search-and-dashboard-scope.md`](references/<project>-2026-06-10-sprint-14-sprint-15-projects-search-and-dashboard-scope.md) |
| Step 4b 兩個 component variant (WikiTab / AttachmentsTab) | [`<project>-step4b-component-variants.md`](references/<project>-step4b-component-variants.md) |
| 拎走 `/bugs` page 撞過嘅 back-link / E2E pitfall | [`<project>-bugs-page-removal-pitfalls.md`](references/<project>-bugs-page-removal-pitfalls.md) |
| 過去 session 教訓 (commit hash + David feedback 對話 + retro doc) | [`<project>-session-lessons.md`](references/<project>-session-lessons.md) |

### 配套 references 詳細 note

- `references/<project>-2026-06-09-bugs-menu-remove-and-search-add.md` — 真實 session 入面點解 David 拎走「全部缺陷」+ 點加 search box 喺 5 個 list
- `references/<project>-2026-06-09-sprint-11-wiki-attachments-and-deprecate.md` — Sprint 11 跟進 (commit `8c99f32`):Wiki/Attachments 兩個 component variant + `describe.skip` 6 個 E2E deprecation pattern + QA-TRACKER/PRD DEPRECATED row format
- `references/<project>-2026-06-10-sprint-14-projects-search-rwd-autocomplete-dashboard.md` — Sprint 14 4 個 David UX feedback closure: `/projects` search box + RWD header + WorkLogs/Reports project dropdown 改 `<ProjectAutocomplete>` reusable + Dashboard 重新設計 (Activity Feed + Recent Projects Quick Switch)
- `references/<project>-2026-06-10-sprint-14-sprint-15-projects-search-and-dashboard-scope.md` — Sprint 14+15 增量: 4 個新 pitfall (ProjectAutocomplete reusable spec / `limit: -1` dropdown-only use / `getByText` strict mode / backend query param 同步 frontend api.ts) + Sprint 15 `?scope=my` 通用 pattern (嚴格只 filter 自己 member, 包括 admin)
