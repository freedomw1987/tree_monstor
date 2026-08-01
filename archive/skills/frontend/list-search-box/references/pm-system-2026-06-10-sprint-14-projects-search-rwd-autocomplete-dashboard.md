# Sprint 14 (2026-06-10) — `/projects` search + RWD + Autocomplete + Dashboard redesign

> **David 4 個 UX feedback 全部 closure 嘅 session 紀錄**。
> 跟 `list-search-box` skill default client-side pattern + `rwd-mobile-audit` skill 4 page iPhone 14 audit + `<ProjectAutocomplete>` reusable component + Dashboard Activity Feed 重設計。

## David feedback 4 個項目

1. `/projects` 頁面要有 search box
2. `/projects` 頁面手機 RWD 有問題
3. 「工作時數」和「報表」頁面中,項目下拉框轉為 Autocomplete,另外佢而家冇辦法出到全部項目
4. 而家嘅儀表版只係一個項目清單,但呢個好奇怪,可以畀我一個建議嗎?

## Plan 階段互動(跟 SOUL.md Think/Plan 規範)

每個項目畀 2-4 個 options + 自己推薦,David 0-1 turn 答晒:

| # | Question | David 揀 | Rationale |
|---|---|---|---|
| 1 | `/projects` search 點做? | **A) Client-side useMemo filter (skill default)** | Simple, backend 唔改, list 細 (12-50 row per page) |
| 2 | `/projects` RWD 點 fix? | **A) flex-col sm:flex-row + audit 個 page** | Layout 嗰度之前 sprint 已經 audit 過,只 fix 呢個 page |
| 3 | Autocomplete 點做? | **A) `limit: -1` + 自建 `<ProjectAutocomplete>` reusable** | Backend 已有 `limit: -1` support,自建 component 比 library 簡單 |
| 4 | Dashboard 重新設計方向? | **A) Activity Feed + Project Quick Switch** | Linear/Asana 標準 pattern, user 0-config 有 context |

## 4 個項目實作

### #1 `/projects` search box

跟 `list-search-box` skill default pattern:

```tsx
const [searchProject, setSearchProject] = useState('')
const filteredProjects = useMemo(() => {
  const q = searchProject.trim().toLowerCase()
  if (!q) return projects
  return projects.filter((p) => {
    if (p.name.toLowerCase().includes(q)) return true
    const dept = (p as any).department?.name
    if (dept && dept.toLowerCase().includes(q)) return true
    return false
  })
}, [projects, searchProject])
```

**Multi-field(名字 + 部門名) — 唔算 over-engineering** 因為 ProjectsPage 嘅 row 顯示 `name + department badge`,用戶 search 會想 match 嗰 row display,等 UX 直覺。

### #2 RWD header

`flex items-center gap-4` → `flex flex-col sm:flex-row sm:items-center gap-3`:

```tsx
<div className="flex flex-col sm:flex-row sm:items-center gap-3 mb-6 lg:mb-8">
  <div className="flex items-center gap-2 sm:gap-4 flex-1 min-w-0">
    <Link to="/" className="p-2 ... flex-shrink-0">
      <ArrowLeft size={24} />
    </Link>
    <h1 className="text-2xl lg:text-3xl font-bold text-gray-900 truncate">項目列表</h1>
  </div>
  {user?.role === 'admin' && (
    <select ... className="input-field w-full sm:w-48">  {/* 唔再係 w-48 fixed */}
      ...
    </select>
  )}
  <div className="relative w-full sm:w-72">
    <Search size={16} ... />
    <input ... aria-label="搜尋項目" ... />
  </div>
  <button ... className="btn-primary flex items-center gap-2 w-full sm:w-auto justify-center">
    <Plus size={20} /> 新建項目
  </button>
</div>
```

### #3 `<ProjectAutocomplete>` reusable component

**冇依賴 library**(冇 `cmdk` / `downshift` / `headlessui`)。自建 250 行 React:

**Props**:
```ts
interface ProjectAutocompleteProps {
  value: string                                  // 揀咗嘅 project id
  onChange: (id: string) => void
  projects: ProjectOption[]                      // 全部項目 (parent 傳入)
  placeholder?: string
  required?: boolean
  ariaLabel?: string
  className?: string
}
```

**5 個 sub-feature**:
1. **Type-ahead filter**: `useState` query + filtered list 自動 recompute
2. **Keyboard nav**:`ArrowUp` / `ArrowDown` / `Enter` / `Escape` 處理
3. **Click outside 收埋** + 自動 reset mismatch 嘅 query
4. **Clear button** (X icon) — 唔出現 if `required`
5. **Status badge + department 顯示** — 用戶見到 context

**3 個 instance 整合**:
- `WorkLogsPage` filter dropdown (L545-557)
- `WorkLogsPage` form `projectId` selector (L942-957)
- `ReportsPage` `selectedProjectId` selector (L62-77)

**Backend 配合**:3 個 page 嘅 `loadProjects()` 加 `{ limit: -1 }` 載全部項目(後端 `computePagination` 已支援 `limit: -1` sentinel,WorkLogs export Excel 已用緊)。

### #4 Dashboard 重新設計

**舊版**:`/` 純係項目卡 list,冇任何 metric / quick action / recent activity。

**新結構**:
- **Activity Feed 4 widget grid**:
  - 「進行中任務」(taskApi.list + status: 'in_progress', pageSize 5)
  - 「未解決缺陷」(bugApi.list + status: 'open', pageSize 5)
  - 「本週時數」(workLogApi.list + groupBy: 'day' + 本週一 ~ today, sum groupedData.totalHours)
  - 「項目總數」(projectApi.list + 讀 backend `totalCount` field)
- **Recent Projects Quick Switch**:`localStorage` `pm-system:recent-project-ids` track 最近 5 個訪問嘅 project id
- **所有項目 grid**:`pageSize: 12` + 「睇更多 (N+)」link 去 `/projects`

## 災難:`limit: -1` 嘅 dashboard 副作用

Sprint 14 開始時,我手滑喺 `DashboardPage.tsx` 嘅 `loadProjects` 都加咗 `limit: -1`(原本淨係修 WorkLogs + Reports)。結果:

- Dashboard 攞晒 196 個項目
- 全部 render 喺「所有項目」grid
- **RWD mobile audit 嘅 fullPage screenshot → 91834px tall PNG**
- **PIL 完全開唔到**,vision analyze 死
- 整個 audit verify 流程冇 feedback,**靠 user(我自己)逐個 page check body 寬度先發現**

**Lesson**:`limit: -1` 嘅 3 個合法 use case + 1 個反 pattern,**patch 入 `pagination-with-preserved-aggregates` skill**:

✅ 合法:
- 真正 dropdown filter (`<ProjectAutocomplete>` 揀項目)
- Excel/CSV export
- Server-side 嘅 full-dataset aggregate (stats card)

❌ 反 pattern:
- Dashboard 嘅 widget list
- 任何 page 嘅「render N 個 card 嘅 grid」
- Search 結果 list (unless type-ahead dropdown)

**Symptom of 誤用**:`document.body.scrollHeight > 5000px` 喺 dashboard/list render page,或者 fullPage screenshot 報 PNG 解碼失敗。

**修法**:`{ page: 1, pageSize: 12 }` + 顯示 `totalCount` 喺 widget + 加「睇更多 (N+)」link。

## 災難 2:E2E spec `/api/auth/me` 404

寫 Sprint 14 spec 嘅 helper `getAdminUserIdAndName` 撞 backend mount path:

```ts
// ❌ 寫咗呢個
const res = await req.get(`${BACKEND}/api/auth/me`, { headers: { Authorization: ... } })
// 返 404 (backend auth route 喺 /auth/*, 唔喺 /api/auth/*)
```

**Lesson**:**直接 grep `backend/src/index.ts` 嘅 `.use(authRoutes)` / `.group('/api', ...)` 確認 mount path**。**Patch 入 `playwright-e2e-design-patterns` skill 嘅 Pattern 10** — 唔好 hit backend 拎 user,**用 static fixture** 過 frontend AuthContext 因為 frontend 唔 server-side verify user object。

## 災難 3:Node Playwright audit script template literal 陷阱

第一次寫 audit script 用 template literal 版 `evaluate`:

```js
// ❌ ESM mode 返 undefined
const loginResult = await page.evaluate(`async () => {
  const res = await fetch('http://localhost:4001/auth/login', {...})
  return await res.json()
}`)
```

**修法**:函數 literal `await page.evaluate(async () => {...})`。**Patch 入 `rwd-mobile-audit` skill pitfall 8** + 寫成 template `templates/rwd_audit_mobile.py` Node 變體(Sprint 14 用 `e2e/node_modules` 嘅 `chromium-1223`,Python system pip 撞 1155 衝突)。

## E2E Sprint 14 spec

**`e2e/tests/sprint14-projects-search-and-dashboard.spec.ts`** — 6 個 test:

| Test | Pattern 來源 |
|---|---|
| search input 存在 + type 即時 filter | `list-search-box` skill default |
| filter empty state 有「清空搜尋」button | `list-search-box` skill Step 5 |
| WorkLogs filter ProjectAutocomplete type-ahead | `<ProjectAutocomplete>` reusable |
| ProjectAutocomplete 喺 Reports page 都 work | Reusability verify |
| Dashboard 4 個 widget 全部 render | Activity Feed |
| Dashboard widget 點擊導航去對應 page | Quick Switch |

**Verification**:
- `bun test` → 601/601 pass (0 backend 改)
- `npx playwright test` → 61/61 pass + 8 skipped (Sprint 13: 55 → 61, +6)
- RWD mobile audit → 4 page body=390=viewport, overflow=0

## Commit + push

```
2d4375d feat(frontend): Sprint 14 — /projects search + RWD + Autocomplete + Dashboard redesign
```

8 files / +904 / -106 / `c2cae56..2d4375d master -> master`

## Out of scope(下個 sprint)

- `<EntityAutocomplete>` generic 化 (Pick<id, name, type> 適用 user / task / bug)
- Dashboard widget 加 chart (本週時數 sparkline)
- 全 project RWD audit (Layout + 其他 page)
- 抽 `getSampleProjectId` 共享 helper 入 `_helpers.ts`
- Wiki full-text search (US-10.3) — HOLD 等下個 epic

## 4 個重要 lessons (全部 patch 入 skill library)

1. **`limit: -1` dashboard 反 pattern** → `pagination-with-preserved-aggregates` skill
2. **E2E spec `/api/auth/me` 404 因為 mount path 唔同** → `playwright-e2e-design-patterns` Pattern 10
3. **RWD mobile `fullPage: true` 對無限 render 嘅 page 爆 100k px** → `rwd-mobile-audit` pitfall 6
4. **Node Playwright `page.evaluate` 唔用 template literal** → `rwd-mobile-audit` pitfall 8
