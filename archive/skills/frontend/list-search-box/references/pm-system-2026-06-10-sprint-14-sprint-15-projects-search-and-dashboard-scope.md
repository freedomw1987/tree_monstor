# PM-System Sprint 14/15 — ProjectsPage search + Autocomplete + Dashboard scope=my

Session 2026-06-10 commit `2d4375d` (Sprint 14) + `afef2a5` (Sprint 15).

## TL;DR — 2 個 sprint 4 個 David feedback 全部 closure

| Sprint | David feedback | Solution | Commit |
|---|---|---|---|
| 14 | `/projects` 加 search box | `useMemo` client-side + 2 層 empty state + RWD header | `2d4375d` |
| 14 | `/projects` RWD mobile 撞 | `flex-col sm:flex-row` header + 4 page iPhone audit | `2d4375d` |
| 14 | WorkLogs/Reports project dropdown 改 Autocomplete + load 全部 | 自建 `<ProjectAutocomplete>` reusable + `limit: -1` | `2d4375d` |
| 14 | Dashboard 由純 list 變有意義首頁 | Activity Feed 4 widget + Recent Projects Quick Switch | `2d4375d` |
| 15 | Dashboard 「所有項目」→ 只 show 自己有份 | Backend `?scope=my` 嚴格 + Dashboard 用 `scope=my` | `afef2a5` |

## 🚨 新 Pitfalls (4 個,Sprint 14/15 揭發)

### 🚨 8. `<ProjectAutocomplete>` reusable component 嘅 spec

**When to extract**: 同一個 entity 要喺 N 個 page 揀(WorkLogs filter + Reports filter + WorkLog form + ...)。

**Spec**:
- type-ahead: `useState(filteredList)` filtered by `name + status + departmentName`
- keyboard nav: ArrowUp/Down highlight, Enter 揀, Esc 關
- show `status badge` (顏色) + `department name` (灰字)
- clear (X) button when value 唔空
- controlled: `value: string (id)`, `onChange(id)`
- loading state skeleton

**Why 自建而唔用 library** (`cmdk` / `downshift`):
- 50 行 React 攪掂
- 唔加依賴
- 鍵盤 nav / accessibility 全部可控

```tsx
<ProjectAutocomplete
  value={formData.projectId}
  onChange={(id) => setFormData({ ...formData, projectId: id })}
  projects={projects}
  placeholder="選擇項目..."
  required
/>
```

### 🚨 9. `limit: -1` 用喺 dropdown 啱用,用喺 list page UX disaster

- **WorkLogs + Reports filter dropdown → `loadProjects({ limit: -1 })`** ✅ (1 個 dropdown 揀)
- **Dashboard / 任何 list page → `limit: -1` 會 render 晒 N 個項目** ❌ (e.g. 196 個 E2E fixture = 91834px tall 截圖, RWD audit 工具 crash)

**Solution**:
- Dropdown / autocomplete: `loadProjects({ limit: -1 })` (後端 `computePagination` 已支援)
- List page: `pageSize: 12` + 「睇更多」link 去 `/projects`

**Detection**: 喺 RWD mobile audit 開 `fullPage: true` 截圖, 圖 > 50k px 就有 list 唔分頁問題。

### 🚨 10. `getByText` strict mode violation — label 喺 widget + section heading 出現 2 次

```tsx
// ❌ E2E 寫 getByText('我參與嘅項目') 撞 — 因為呢個 text 喺 widget + section heading 出現 2 次
test('widget 4 顯示', async ({ page }) => {
  await expect(page.getByText('我參與嘅項目')).toBeVisible()  // ❌ strict mode 報 2 elements
})

// ✅ 用 .first() / .last() / 鎖定 role
await expect(page.getByText('我參與嘅項目').first()).toBeVisible()
// 或
await expect(page.getByRole('heading', { name: '我參與嘅項目' })).toBeVisible()
```

**Lesson**: Search label 同 heading 唔好重用 text, e.g. widget 嗰個 count 用「共 X 個項目」, section heading 用「所有項目」, 兩個 unique string。

### 🚨 11. Backend query param 加咗,frontend `api.ts` type 一定要同步(否則 frontend `bun run build` fail)

**When**: Backend route 加新 query param (e.g. `?scope=my`)

**Lesson**:
- Backend docker container 唔 hot-reload TS source,改咗之後要 `docker compose build backend` + `docker compose up -d --force-recreate --no-deps backend`
- Frontend `api.ts` 個 type signature 一定要更新,例如:
  ```ts
  // Before
  list: (params?: { departmentId?: string; page?: number; pageSize?: number; limit?: number }) =>
  // After
  list: (params?: { departmentId?: string; scope?: 'my' | 'default'; page?: number; pageSize?: number; limit?: number }) =>
  ```
- 否則 `bun run build` 喺 Dockerfile stage 2 fail (`error TS2353: Object literal may only specify known properties, and 'scope' does not exist`)

**Prevention**: Backend 加 query param → 1 個 turn 之後立即去 frontend `api.ts` 同步 type, build verify, 唔好留低。

## Sprint 15 Backend `?scope=my` pattern (David「只 show 自己有份」通用解)

**問題**: Backend 寬鬆 filter「member OR 同部門」對非-admin 過寬,David 想 Dashboard 「只 show 自己參與」嚴格。

**Solution**:
- Backend route 加 `?scope=my` 嚴格只 filter 自己 member(包括 admin 都要守 invariant)
- Default 仍然係「member OR 同部門」寬鬆(向後兼容,唔 break 已有 `/projects` 個 filter UI)
- Frontend Dashboard 用 `scope=my`,`/projects` 唔帶 scope(用 default)
- 5 個 unit test 守住 scope=my invariant

**Generic 用法**(任何 entity 而家都有呢個需求):
- `/api/tasks?scope=my` — 只見自己 assignee
- `/api/bugs?scope=my` — 只見自己 reporter/assignee
- `/api/worklogs?scope=my` — 只見自己 user
- 配合 dashboard widget 嘅 count 用 backend `totalCount` field,真實反映自己數

**Insight 揭發**: Admin 之前能見 198 個 E2E fixture project(全部同部門),改咗之後真係 191 個自己 member — admin 真係 member 191 個項目但唔係全部。嚴格過濾有意義。

## 5 個 unit test 守住 scope=my invariant

```ts
// 1. scope=my, 非 admin 有部門 → 嚴格只見自己 member, 忽略同部門
test('Sprint 15: scope=my, 非 admin 有部門 → 嚴格只見自己 member, 忽略同部門', () => {
  const where = buildProjectListWhereForUser(
    { scope: 'my' },
    { id: 'u-1', role: 'developer' },
    'd-1'
  )
  expect(where.members).toEqual({ some: { userId: 'u-1' } })
  expect(where.OR).toBeUndefined()
})

// 2. scope=my, 非 admin 冇部門 → 仍然嚴格
test('Sprint 15: scope=my, 非 admin 冇部門 → 仍然嚴格只見自己 member', () => {
  const where = buildProjectListWhereForUser(
    { scope: 'my' },
    { id: 'u-1', role: 'developer' },
    null
  )
  expect(where.members).toEqual({ some: { userId: 'u-1' } })
  expect(where.OR).toBeUndefined()
})

// 3. scope=my, admin → 都要守「自己 member」 invariant
test('Sprint 15: scope=my, admin → 都要守「自己 member」 invariant', () => {
  const where = buildProjectListWhereForUser(
    { scope: 'my' },
    { id: 'admin-1', role: 'admin' },
    null
  )
  expect(where.members).toEqual({ some: { userId: 'admin-1' } })
})

// 4. default scope, admin 仍然見晒(向後兼容)
test('Sprint 15: default scope, admin 仍然見晒', () => {
  const where = buildProjectListWhereForUser(
    {},
    { id: 'admin-1', role: 'admin' },
    null
  )
  expect(where.OR).toBeUndefined()
  expect(where.members).toBeUndefined()
})

// 5. scope=my + departmentId filter → 兩者 AND
test('Sprint 15: scope=my + departmentId filter → 兩者 AND', () => {
  const where = buildProjectListWhereForUser(
    { scope: 'my', departmentId: 'd-2' },
    { id: 'u-1', role: 'developer' },
    'd-1'
  )
  expect(where.members).toEqual({ some: { userId: 'u-1' } })
  expect(where.departmentId).toBe('d-2')
})
```

## E2E test pattern (scope=my widget count 一致)

```ts
test('admin + scope=my: Dashboard widget 4 count 與 /api/projects?scope=my totalCount 一致', async ({ page, request }, testInfo) => {
  const token = await loginAs(request, 'admin', testInfo.title)
  
  // 1. API 攞真實 count (避免 race condition)
  const apiRes = await request.get(`${BACKEND}/api/projects?scope=my&pageSize=1`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  const apiCount = (await apiRes.json()).totalCount
  
  // 2. UI 攞 widget 4 嗰個 count
  await loginViaStorage(page, token)
  await page.goto(`${FRONTEND}/`)
  await page.waitForTimeout(800)
  
  // ⚠️ 用 .first() 因為 "我參與嘅項目" 喺 widget + section heading 出現 2 次
  const count = await page.getByText('我參與嘅項目').first().locator('xpath=following-sibling::p[1]').textContent()
  expect(count?.trim()).toBe(String(apiCount))
})
```

## 7 條 follow-up (retro doc 留低)

- [ ] Dashboard widget 加 chart(本週時數 sparkline + 按部門)
- [ ] Mobile RWD 全 project audit(目前只 audit 4 個 page,Layout + 其他 page 未 audit)
- [ ] Backend `scope=team`(將來團隊 filter,例如「我嘅部門 + 我管理嘅部門」)
- [ ] Dashboard 改用 generic `<EntityAutocomplete>` 同 widget layout 抽 `useDashboardData` custom hook
- [ ] `ProjectsPage` 入面都加 `scope=my` toggle filter UI(後端已經 work)
- [ ] 抽 `getSampleProjectId` 共享 helper 入 `_helpers.ts`(避免 3 個 file 各自 re-implement)
- [ ] 把 `rbac-negative.spec.ts:173` 同 `bugs-fix.spec.ts` 同 `project-detail-bug-tab.spec.ts` 嘅 spec helper 統一

## Lesson (跨 session 用)

1. **Backend docker container 唔 hot-reload TS source** — 改咗之後要 `docker compose build backend` + `force-recreate`, 先見效(用 docker inspect 唔夠,真係要 rebuild image)
2. **Backend + frontend type signature 同步** — 加 query param 之後,frontend `api.ts` 一定要更新,否則 build fail
3. **Backend filter 寬鬆 vs 嚴格應該用 query param 區分** — 唔好 backend 直接改,會 break 已有 UI;`?scope=my` 向後兼容 default
4. **`limit: -1` 只用於 dropdown filter** — 用喺 list page 會 render 晒 N 個項目,UX disaster
5. **`getByText` strict mode 一定要 `.first()`** — label 喺 widget + heading 重用 text 係 E2E common pitfall
6. **Component reuse 唔好 over-engineer** — 50 行 React 自建 Autocomplete 已經夠用,唔好即刻加 cmdk/downshift library
7. **RWD mobile audit 嘅 `fullPage: true` 會爆 100k px** 喺無限 scroll 嘅 page,要用 `clip` 或者 pageSize 限制
