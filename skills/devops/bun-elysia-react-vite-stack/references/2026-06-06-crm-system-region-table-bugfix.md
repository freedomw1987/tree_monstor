# crm-system Day 9 build log — 2026-06-06

David 報 4 個 issues 喺 Day 8 build 上面:

1. 公司搜尋 / 地區篩選器都唔 work
2. 新增 quotation 失敗
3. Deals 頁面 total value 計錯
4. (新加) Region 應該做獨立 table 而唔係 enum

## 4 個 issues 嘅 root cause 追蹤

### Issue 1: 公司 search / region filter 唔 work
- **Backend 完全 work** — verified 喺 `python3 urllib` 跑 `GET /api/companies?search=Globex` 返 1 個 result
- **Frontend 真兇**:`apps/web/src/lib/api.ts` 個 `companiesApi.list()` 送 `?query=...`,但 backend route 收 `?search=...`。React-query 個 `queryKey` 用 `{ query, regionFilter }` hash change → trigger refetch,但個 HTTP 個 query string 用 `query` 而非 `search`,backend 永遠 silent 落空
- **Fix**:`api.ts` 改用 `search` key 對齊 backend
- **教訓**: 寫新 API client 永遠對齊 backend route handler 個 destructure 嘅 field name,**唔好 frontend 自由 rename**

### Issue 2: 新增 quotation 失敗 (3 層 bug)
- **Layer A (Auth)**:`authContext.derive` 喺 Elysia 1.2 POST handler 內 silently 返 `undefined`(`userId`)。Frontend POST `/api/quotations` 收到 401 Unauthorized。Hermes 加 `console.log('[POST /quotations] userId=', userId)` 入 handler → print `undefined`。加 console log 入 derive → **冇任何 log**(即 derive 完全冇 run)
- **Layer B (Validator)**:Frontend React 個 form state 寫 `productId: string | null`,JSON.stringify 變 `"productId":null`。Elysia `t.Optional(t.String())` 唔接受 `null` literal,只接受 omit 或 `undefined`。422 Validation。David 講「`productId: null` 失敗」就係呢個
- **Layer C (Schema)**:Schema `itemType ItemType @default(PRODUCT)` (enum),但 DB column 係 `text`(Day 7 手動 migration 寫 `ADD COLUMN itemType TEXT` 但 schema 寫 enum)。Prisma client 撞 `42704 type "public.ItemType" does not exist`
- **Fix sequence**:
  1. Schema:改 `enum ItemType` → `String @default("PRODUCT")`
  2. Backend POST handler 改 inline `getUserIdFromRequest(request, jwt)`(避 derive bug)
  3. Backend validator:`t.Optional(t.Union([t.String(), t.Null()]))` 接受 null literal
  4. Host 跑 `bunx prisma generate` + `docker compose build --no-cache api`(stage 1 個 prisma generate 唔 cache 命中)

### Issue 3: Deals total value 計錯
- **Backend 返 `deal.value = "75000"`**(Prisma Decimal 序列化成 string)
- **Frontend** `formatCurrency(amount: number, currency: 'HKD')` signature 期望 number。`Intl.NumberFormat.format("75000")` 喺 V8 撞 NaN 或 silent 返 "HK$0"
- **Day 8 已 patch** 部分:`deals.tsx` 個 `useMemo` 加 `Number(d.value)` 強制 coerce。**但 `formatCurrency` 個 signature 仍係 number,容易漏 coerce**
- **Fix (永久)**:`formatCurrency(amount: number | string, ...)` + inline `Number.isFinite` guard。**任何 Prisma Decimal field call site 自動 safe**

### Issue 4: Region 改獨立 table (migration)
- **Schema**:`enum Region { HK MO CN OTHER }` → `model Region { id, code, name, flag, isActive, sortOrder }` + `Company.regionId` FK
- **DB migration (手動 SQL 因為 Prisma 唔識 produce enum drop)**:
  ```sql
  CREATE TABLE regions (...);
  INSERT INTO regions (id, code, name, flag, ...) VALUES
    ('reg_hk_seed', 'HK', 'Hong Kong 香港', '🇭🇰', ...),
    ...;
  ALTER TABLE companies ADD COLUMN "regionId" TEXT;
  UPDATE companies SET "regionId" = 'reg_hk_seed' WHERE region = 'HK';
  -- ... 其他 3 個
  ALTER TABLE companies ADD CONSTRAINT companies_regionId_fkey
    FOREIGN KEY ("regionId") REFERENCES regions(id) ON DELETE SET NULL;
  ALTER TABLE companies DROP COLUMN region;
  DROP TYPE "Region";
  ```
- **Migration file**:`packages/db/prisma/migrations/20260606000000_day9_region_table_quotation_item_string/migration.sql` — **no-op 因為 SQL 已手動 apply**。註釋解釋 schema 改動同 backfill 邏輯
- **Backend**:
  - 新 `apps/api/src/routes/region.ts`:`GET / POST / PATCH / DELETE /regions`
  - `company.ts`:`region` query param 改用 `prisma.region.findFirst({ code: region })` resolve 到 `regionId`
  - `company.ts` POST/PATCH:接受 `region` (code) 或 `regionId` (cuid) 任一
  - `deal.ts`:`region: { select: { id, code, name, flag } }` include 取代 `region: true`
- **Frontend (planned, partially done)**:
  - `api.ts` 加 `Region` interface + `Company.region` 改 `Region` 物件
  - 仲欠:`regionsApi` module + `companies.tsx` dynamic region list
- **Verification**:`GET /api/regions` 返 4 個 regions,HK 已有 6 個 companies 連住(backfill 成功)

## Backend auth pattern 永久改動 (Day 9 後)

`apps/api/src/lib/context.ts` 改:
```typescript
export const authContext = new Elysia({ name: 'auth-context' });
// No .derive() — Day 9 發現 .derive() 喺 Elysia 1.2 POST handler
// 內 silently 返 undefined。

export async function getUserIdFromRequest(
  request: Request,
  jwt: { verify: (token: string) => Promise<unknown> }
): Promise<string | null> {
  const authHeader = request.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7);
  const payload = await jwt.verify(token);
  if (!payload || typeof payload !== 'object') return null;
  return (payload as { sub?: string }).sub ?? null;
}
```

每個 route handler 改用:
```typescript
.post('/', async ({ body, jwt, set, request }) => {
  const userId = await getUserIdFromRequest(request, jwt);
  if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
  // ...
})
```

**Migration impact**: Day 9 只 patch 咗 `quotation.ts` 一個 file,confirm fix 之後需要 subagent 平行 scan 全部 `({ userId` destructure 嘅 POST handler(可能仲有 `/deals` POST、`/contacts` POST、`/products` POST、`/services` POST、`/roles` POST)。**全部用 `getUserIdFromRequest` 取代 derive**。

## Region 後續 frontend work (Day 9 結束時未做)

1. `apps/web/src/lib/api.ts` 加 `regionsApi = { list, get, create, update, delete }`
2. `apps/web/src/pages/companies.tsx` 刪 static `REGIONS` const,改用 `useQuery(['regions'])` 動態 render filter pills
3. `apps/web/src/pages/company-detail.tsx` 個 region dropdown 改用 dynamic regions
4. `apps/web/src/components/company-form.tsx` (如有) 改用 dynamic regions
5. `apps/web/src/pages/deals.tsx` 個 `c.region` 顯示從 string 改 `c.region?.code + c.region?.flag`
6. Rebuild web image, browser verify, commit + push

## 重要教訓(歸入 SKILL.md pitfall section)

1. **Elysia 1.2 `.derive()` 對 POST silently 返 undefined** — 完全 avoid 用 derive,inline verify
2. **`t.Optional(t.String())` 唔接受 null** — 用 `t.Union([t.String(), t.Null()])`
3. **Prisma schema enum 撞 DB text column** — 統一用 `String @default("LITERAL")`
4. **Schema 改完必須 host + image 都重新 generate** — `prisma generate` + `docker compose build --no-cache`
5. **Container stuck `Status: created` + 空 log** — entry script fail silent,加 `set -x` debug
6. **Prisma Decimal 返 string, frontend `Intl.NumberFormat` 撞 NaN** — `formatCurrency` 改 signature 接受 `number | string` + NaN guard
7. **docker compose up hang 喺 foreground** — 用 `nohup ... & disown` 或 `| head -3` 避免 pipe hang

## Final commit shape (planned)

```
<region-table-fix>:  Day 9 — Region enum → table, fix POST auth & validation
  - apps/api/src/lib/context.ts: drop .derive(), add getUserIdFromRequest helper
  - apps/api/src/routes/quotation.ts: use getUserIdFromRequest + nullable union
  - apps/api/src/routes/company.ts: region code→id resolution + nullable union
  - apps/api/src/routes/deal.ts: include region relation
  - apps/api/src/routes/region.ts: new CRUD /regions endpoints
  - apps/api/src/index.ts: register regionRoutes
  - packages/db/prisma/schema.prisma: Region enum→model, itemType String, FK
  - packages/db/prisma/migrations/20260606000000_day9_.../migration.sql: no-op record
  - apps/web/src/lib/api.ts: Region interface + Company.region relation
  - apps/web/src/lib/utils.ts: formatCurrency accept number|string
```

David 確認 commit + push 之前必須睇 diff。
