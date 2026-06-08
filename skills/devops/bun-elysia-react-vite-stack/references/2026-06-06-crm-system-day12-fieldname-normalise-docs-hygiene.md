# 2026-06-06 crm-system — Field-name drift, `isActive`→`status` cleanup, service detail 502, docs hygiene (Day 12)

David 四個連續議題, 每個都係 silent drift / 文檔 hygiene, 撞牆位全部 runtime 唔報:

1. `bg-popover` Day 11 揀咗 quick fix 嗰個 component, 但 David 重新請求 systemic config fix → 加 `popover` token
2. `Service.isActive` legacy field schema drift (schema 改用 enum, frontend type 仲用 `isActive`)
3. Service 詳情頁 502 + `service.manDays.map` throw undefined — 真正 root cause 係 wire `manDayLines` vs type `manDays` drift
4. README + PROGRESS.md 嚴重 out-of-date (Day 1 state), David 請整理

## Issue A: Field-name drift `manDayLines` (wire) vs `manDays` (frontend type) — 真正 root cause

**症狀 verbatim**: David 喺 browser 喺 Service 列表 (`pages/services.tsx`) → 個 list 顯示 "0 個 man-day role" (即係 list 入面 `s.manDays` 永遠 undefined); David click 入去 Service detail → `service-detail.tsx:38` 撞 `Cannot read properties of undefined (reading 'map')`.

**根因 (Day 11 surface-level fix 唔完整嘅真正原因)**:

| Layer | Field name | Note |
|---|---|---|
| Backend Prisma model | `manDayLines ServiceManDay[]` | Prisma camelCase 保留 relation name |
| Backend Prisma `include` | `include: { manDayLines: { orderBy: { sortOrder: 'asc' } } }` | Response JSON 個 key = `manDayLines` |
| Backend wire format | `manDayLines` (POST validator 用 `t.Array(t.Object(...))` 對 `manDayLines`) | Day 11 fix 過 send 嗰邊 |
| Frontend TypeScript `Service` type | `manDays: ServiceManDay[]` | ❌ Mismatch backend wire |
| Frontend `request<T>` generic | Pure typecast, **冇 normalize** | ❌ 冇 runtime bridge |
| Frontend `servicesApi.get/list/create/update` | 個 return value 嘅 field 真係叫 `manDayLines`, 唔叫 `manDays` | ❌ type 騙 runtime |

`request<T>` generic 純 typecast — `request<Service>(...)` 個 return object 嘅 field 仍然叫 `manDayLines` (Prisma 個 relation name), `Service` type 寫住 `manDays` 純粹係 TypeScript layer 嘅 alias. `obj.manDays` 永遠 undefined 即係 runtime 撞:

```typescript
// service-detail.tsx:38
setManDays(service.manDays.map((m) => ({ role: m.role, dayRate: m.dayRate, days: m.days })));
//              ^^^^^^^^^^ undefined
//              ^^^^^^^ .map throw TypeError
```

**List page 表面睇冇事嘅原因**: Day 11 加咗 defensive `s.manDays?.length ?? 0`, 救返, 但渲染 "0 個 man-day role" — 用戶睇到嘅唔係 crash 而係 silent data loss. **即係 defensive code 救咗表面, 但冇救到根本**.

**Day 12 真正 fix (API wrapper boundary normalize)**:

`apps/web/src/lib/api.ts` 加 `normaliseService` helper, 喺 `servicesApi.{list, get, create, update}` 4 個 entry point 統一 pipe:

```typescript
// Backend's Prisma client returns the man-day relation under the
// camelCased key `manDayLines` (preserved from the Prisma model name).
// The frontend's `Service` type uses `manDays` to match the URL slug
// and the wire-format key for the POST/PATCH validators' payload.
// All API entry points that read a Service from the response normalise
// `manDayLines` → `manDays` so the rest of the frontend can rely on a
// single field name.
function normaliseService<T extends { manDays?: unknown; manDayLines?: unknown }>(s: T): T {
  const manDaysFromWire = (s as { manDayLines?: ServiceManDay[] }).manDayLines;
  if (manDaysFromWire !== undefined) {
    return { ...s, manDays: manDaysFromWire as ServiceManDay[] };
  }
  return s;
}

export const servicesApi = {
  list: (params) =>
    request<...>('/services?...').then((r) => {
      const items = Array.isArray(r) ? r : r.items;
      return items.map(normaliseService);  // ← 每個 item normalize
    }),
  get: (id) => request<Service>(`/services/${id}`).then(normaliseService),
  create: (data) => request<Service>('/services', { ... }).then(normaliseService),
  update: (id, data) => request<Service>(`/services/${id}`, { ... }).then(normaliseService),
};
```

**Defensive code 喺 component 入面仍保留** (belt-and-suspenders):
```typescript
// service-detail.tsx:38 (after Day 12 fix)
setManDays((service.manDays ?? []).map((m) => ({ role: m.role, dayRate: m.dayRate, days: m.days })));
//              ^^^^^^^^^^^^^^^ 即使 normalize 將來 regress 都唔會 crash
```

**刪走舊 normalize 喺 `quick-create-service-dialog.tsx`** (subagent Day 11 加嘅 normalization, 而家 redundant 因為 boundary 統一做):
```typescript
// ❌ 之前 (Day 11 subagent 寫嘅):
const created = await servicesApi.create({...});
const manDaysFromResponse = (created as Service & { manDayLines?: ServiceManDay[] }).manDayLines;
const normalised: Service = { ...created, manDays: created.manDays ?? manDaysFromResponse ?? [] };
onCreated(normalised);

// ✅ 之後 (Day 12):
const created = await servicesApi.create({...});
onCreated(created);  // already normalised by servicesApi.create wrapper
```

**Generic rule (套用到所有 Prisma relation field name != frontend type field name)**:

| Backend Prisma | Frontend type | 命名衝突源 |
|---|---|---|
| `manDayLines` (relation) | `manDays` (URL slug / business) | camelCase vs abbreviation |
| `quotationItems` (relation) | `items` (business 簡稱) | Prisma 自動加 entity suffix |
| `serviceManDays` (model) | `manDays` (singular) | 將來寫呢個 relation 要小心 |

**Boundary normalize 一律喺 `lib/api.ts` 個 wrapper 做, 唔好喺每個 component 重複**。原因:
- Single source of truth,將來 backend 改 relation name 淨改 1 個 file
- Component 寫 `s.manDays` 永遠 work,後來人唔使知道 backend 嗰邊係 `manDayLines`
- 將來加 `manDayLines` → `manDays` migration / deprecation 都淨改 1 個 file

**Detection 工具 (撞牆必做)**:
```bash
# 1. Backend response keys check
docker exec crm-postgres psql -U crm -d crm_system -c "\d services" | grep manDay
# 確認 column 存在

# 2. Frontend type field check
rg "manDays:|manDayLines:|manDayLines\?" apps/web/src/lib/api.ts
# 對比 backend 嘅 wire format (Prisma relation name)

# 3. Component 訪問 field 嘅 pattern grep
rg "\.manDays\.|\.manDayLines\." apps/web/src
# 統一用 `manDays`, 有 `manDayLines` 嘅地方 = boundary normalize 漏咗
```

**Hermes redacted JWT 嘅 smoke workaround 仍然適用** (Day 6 教訓):
```python
# Backend response 攞到直接 print, 唔用 shell pipeline 避免 `***` redact
import json, urllib.request
# 唔好 hardcode token, 改用 execute_code 入面做 login
```

## Issue B: `Service.isActive` → `status` (legacy field drift)

**症狀**: Day 11 改咗 `services.tsx` line 33 嘅 toggle 掣:
```typescript
const toggleActive = useMutation({
  mutationFn: (s: Service) => servicesApi.update(s.id, { isActive: !s.isActive }),
  //                                                              ^^^^^^^^ Prisma throws "Unknown arg isActive"
});
```
David 撳 toggle 掣會 throw `PrismaClientUnknownArgError: Unknown argument isActive` 因為 `Service` schema (line 323) 用 `status ServiceStatus` enum, **冇** `isActive` column。

**根因 (Day 7 嘅 drift)**: Day 7 整 service 嗰陣 schema 寫 `isActive: Boolean`, Day 9 之後有人改做 `status ServiceStatus` enum (連同 `category` field), 但 **frontend `Service` type 冇跟住改**, 殘留 `isActive: boolean` 寫咗幾個月。

**Day 12 fix 範圍**:
| File | 改動 |
|---|---|
| `apps/web/src/lib/api.ts` | `Service` interface 移除 `isActive: boolean`; `servicesApi.update` 移除 `isActive: boolean`; `servicesApi.update` partial 內嘅 `manDays` wire key 改 `manDayLines` 對齊 POST |
| `apps/web/src/pages/services.tsx` | list call 移除 `isActive: ''`; toggle mutation 改用 `status: s.status === 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE'`; Badge tri-state ACTIVE/ARCHIVED/DRAFT; button icon 跟 status |
| `apps/web/src/pages/service-detail.tsx` | subagent 主動清埋, state 改用 `status` enum; save payload 用 `manDayLines` wire key |

**Detection (drift pattern grep)**:
```bash
# 1. 對比 schema 同 frontend type 嘅 column / field 名
rg "isActive" packages/db/prisma/schema.prisma
rg "isActive" apps/web/src/lib/api.ts
# 差集 = drift

# 2. Toggle mutation 嘅典型 dead code pattern
rg "servicesApi\.update\(.*isActive|productsApi\.update\(.*isActive|companiesApi\.update\(.*isActive" apps/web/src
# 通常一 hit 即係 dead code drift

# 3. 證明真正 Prisma column
docker exec crm-postgres psql -U crm -d crm_system -c "\d services"
# Expected: 冇 isActive column, 得 status ServiceStatus
```

**保留 vs 清嘅 rule**:
- `User.isActive` (schema line 40) → **保留**, 真 column
- `Region.isActive` (schema line 111) → **保留**, 真 column
- `Service.isActive` (frontend type only) → **清**, drift
- `Company.status` (schema line 134) + `Company.isActive`? → grep 確認

**Frontend Backend drift 嘅 3 個信號** (David 撞過 2 次, crm-system):
1. **Toggle mutation 永遠 100% crash 喺 Prisma**: `{ isActive: !x.isActive }` 個 wire key backend 唔識, throw `Unknown arg`
2. **TypeScript type 寫 field 但 Prisma schema 冇**: `Service.isActive: boolean` 寫喺 `lib/api.ts` line 524, 對比 schema line 323 證明 drift
3. **Default value drift**: 寫 `isActive: !!product.isActive` 但 product schema 已經用 `status: ProductStatus`, 直接寫 `status: 'ACTIVE'` 對齊

**改 schema 嘅鐵律 (Day 7 嗰個遺留)**:
- Schema 改 enum / field 之後, **同日**必須 grep frontend type 對應 fields, 逐個改 / 刪
- 唔可以 schema 改咗幾個 day 然後 frontend type 仲行緊舊 world
- 自動化 check: 寫個 script `rg -E "\\bisActive\\b" apps/web/src/lib/api.ts packages/db/prisma/schema.prisma` 對比兩邊 column list

## Issue C: 502 root cause 確認 — wire format mismatch

**症狀 verbatim**: David 喺 Service 列表 / Service detail / Quotation Builder autocomplete 三個地方撳「新增服務」, 全部 502。

**Backend log (Day 12 重新 trace 確認)**:
```
[POST /services] Validation failed
"on":"body"
"body":{"name":"X","unitPrice":0,"currency":"HKD","manDays":[{"role":"PM","dayRate":5000,"days":5}]}
"expected":"name,description?,category?,unitPrice,currency?,status?,sortOrder?,manDayLines?"
"received_extras":"manDays"
"missing":"manDayLines"
```

**Day 11 fix 範圍 (確認齊全)**: `servicesApi.create` 嘅 wire payload 改用 `manDayLines: manDays`, response normalize 用 `manDayLines` → `manDays` 然後 `onCreated`. **Day 12 加 `lib/api.ts` boundary normalize 統一** 將來其他 caller (`service-detail.tsx` PATCH 同 `quick-create-service-dialog.tsx` POST) 自動 work.

**Day 12 改咗嘅 wire-format-related files**:
| File | Change |
|---|---|
| `apps/web/src/lib/api.ts` | `servicesApi.create/update` 個 type signature `manDayLines` (wire key) + response normalize `manDayLines → manDays` boundary 一致; `servicesApi.update` 嘅 PATCH 之前用 `manDays` silently no-op, 而家用 `manDayLines` 真係 replace man-day lines |
| `apps/web/src/components/quick-create-service-dialog.tsx` | 刪走 subagent 寫嘅舊 normalize (boundary 統一做); 改用 `onCreated(created)` 直行 (created 已經 normalized) |
| `apps/web/src/pages/service-detail.tsx` | Save payload 改用 `manDayLines: manDays` 對齊 wire (之前用 `manDays` silently no-op, 個 SOW breakdown 寫入失敗) |

**Generic rule for Elysia strict `t.Object` validator**:
- Backend `t.Object` schema field = source of truth
- Frontend type signature 可以用 alias (manDays 對齊 URL slug), 但 wire key 必須 match backend
- Boundary normalize 喺 `lib/api.ts` 統一做, 唔好喺每個 component 重複
- 502 嘅 detection: 個 backend log 一定會有 `Validation failed` 字眼, 唔好淨睇 HTTP status code

**Verification 流程**:
```bash
# 1. 撞 502 嘅時候
docker logs crm-api --tail 30 | grep -A 5 "Validation"
# 應該見 "expected" + "received" / "missing" 嘅 field list

# 2. Smoke 一個 minimal POST
docker exec -i crm-api node /tmp/smoke.js
# 用 prisma client 直接 service.create, 唔經 HTTP, 證明 Prisma layer OK
# 然後走 HTTP layer, 證明 wire format OK
```

## Issue D: README + PROGRESS 文檔 hygiene

**症狀**: David 撳 `整理您項目文檔`, 我 scan 發現:
- `README.md` 174 行, 寫到 Phase 1 day 1 (frontend 仲未寫)
- `docs/PROGRESS.md` 40 行, 淨係 Day 1 checkpoint
- 兩個 doc 嚴重 out-of-date, 跟 project 現實 (Day 9+, 12+ route, 15+ page) 落差大

**David 嘅 implicit rule (從 SOUL.md 同 memory 推測)**:
> "冇 user-visible UI = 冇做" 鐵律延伸 → "文檔 out-of-date = 冇做" 對 development context 都應該成立

文檔係 user 對 codebase 嘅 first impression, 過時 README / PROGRESS 等於 misrepresent 個 project 嘅 scope 同狀態, 影響 onboarding, 影響 day-by-day continuity。

**Day 12 整理範圍 (default "core" scope)**:
- `README.md` 從 174 → 287 行, 加咗 12 route groups + 15 frontend pages + 8 AI tools + DB model 列表 + Quality gates section
- `docs/PROGRESS.md` 從 40 → 142 行, Day 1 → Day 9+ 完整 milestone log, 加 "Pending / known gaps" + "Known issues / workarounds" section

**文檔 hygiene 嘅 maintain rule (新)**:

1. **每個 phase / day 結束, 同步更新 PROGRESS.md**:
   - 新 shipped feature
   - 新 pitfall + workaround
   - Migration list (新 migration 加埋)
   - Known issues 清單 (解決咗嘅 issue 標 `[DONE]` 唔刪, 留低 audit trail)
2. **README 嘅 route / page / tools table 對齊實際 filesystem**:
   ```bash
   # Recon 嘅 truth source
   ls apps/api/src/routes/        # backend routes
   ls apps/web/src/pages/         # frontend pages
   rg "^\\s*name:" packages/ai/src/tools.ts | head -10  # AI tools
   ls packages/db/prisma/migrations/  # DB migrations
   ```
3. **Env vars table 對齊 `.env.example`**:
   - 用 `rg -E "^[A-Z_]+=" .env.example` 拎所有 vars
   - README table 跟住 `.env.example` 而非 memory
4. **Known issues section 用 imperative voice** (e.g. "Use `--skipLibCheck` in `typecheck`") 而非 passive ("It is known that...")
5. **Migration 表格嘅 timestamp 要對齊 filesystem**, 唔好憑記憶寫:

```bash
ls packages/db/prisma/migrations/ | grep -v lock | sort
# 對齊 README / PROGRESS 入面個 table
```

**Scope 選項 (David 揀)**:
- **Core** (Day 12 揀): README + PROGRESS 對齊到 Day 9 狀態 — 解決 readme out-of-date
- **Core + API**: 加 API endpoint reference table (path/method/params/responses)
- **Core + API + DB**: 加 Prisma schema 詳細 reference (model 對齊 column)
- **Full**: 加 architecture diagram + AI tools 完整 list + Frontend 結構 + Contributing guide

David 冇回覆 10 分鐘, 跟 SOP 揀 default **Core**, 解決最 critical 嘅 "readme out-of-date" 問題。

**冇做嘅 (將來 David 想加)**:
- API endpoint 詳細 reference (path + method + params + responses)
- Prisma schema 詳細 reference (model 對齊 column)
- Contributing guide
- Architecture decision records (ADRs)
- Test plan / coverage report
- Deployment runbook (production deploy step-by-step)

## Issue E: `bg-popover` Day 11 揀咗 component-local 嘅處理 (David 重新請求 systemic fix)

**症狀**: Day 11 嘅 quick fix 用 `bg-white border border-border` 喺 `quotation-builder.tsx` line 753 / 770 兩個 autocomplete dropdown。David 喺 Day 12 開頭要求 "**最好加一個 bg-white**" — 即係想 systemic 加 `popover` token 入 Tailwind config, **將來其他 component 用 `bg-popover` 直接 work**。

**Day 12 fix**:
```js
// apps/web/tailwind.config.js
colors: {
  // ... 已經有 border, input, ring, background, foreground, primary, secondary, muted, accent, destructive, card ...
  // Day 12 加:
  popover: {
    DEFAULT: 'hsl(0 0% 100%)',
    foreground: 'hsl(222.2 84% 4.9%)',
  },
}
```

**保留之前 `bg-white` hard-coded 改動 (唔 revert)**:
- Day 11 嘅 `bg-white border border-border` 同 future 嘅 `bg-popover` 視覺一致 (popover token default = `hsl(0 0% 100%)` = 白色)
- Revert 改 `bg-popover` 反而增加 PR noise, 留 `bg-white` 都 OK
- **但**將來其他 component 用 `bg-popover` 已經 work (Tailwind JIT 識個 token), 唔再 silently omit

**Tailwind token set 嘅 audit** (Day 12 grep 出嚟, 將來做):

```bash
# 1. 用緊嘅 utility class
USED=$(rg -oN "bg-(popover|card|accent|secondary|muted|primary|secondary-foreground|popover-foreground|card-foreground|muted-foreground|accent-foreground|destructive-foreground)" apps/web/src | sed 's/.*\(bg-[a-z-]*\).*/\1/' | sort -u)

# 2. config 入面有嘅 token
DEFINED=$(node -e "console.log('bg-' + Object.keys(require('./tailwind.config.js').theme.extend.colors).join('\nbg-'))" | sort -u)

# 3. 差集 = 缺嘅 token
MISSING=$(comm -23 <(echo "$USED") <(echo "$DEFINED"))
if [ -n "$MISSING" ]; then
  echo "❌ Missing tailwind tokens: $MISSING"
  exit 1
fi
```

**完整 shadcn-ui HSL token set 對照** (crm-system 用緊 `hsl()`, 唔好用 `oklch()` 混):

| Token | HSL | 用途 |
|---|---|---|
| `background` / `foreground` | `0 0% 100%` / `222.2 84% 4.9%` | body bg + text |
| `card` / `card-foreground` | `0 0% 100%` / `222.2 84% 4.9%` | Card |
| `popover` / `popover-foreground` | `0 0% 100%` / `222.2 84% 4.9%` | Popover / dropdown / modal |
| `primary` / `primary-foreground` | `222.2 47.4% 11.2%` / `210 40% 98%` | 主 button |
| `secondary` / `secondary-foreground` | `210 40% 96.1%` / `222.2 47.4% 11.2%` | 次 button |
| `muted` / `muted-foreground` | `210 40% 96.1%` / `215.4 16.3% 46.9%` | Skeleton / hint |
| `accent` / `accent-foreground` | `210 40% 96.1%` / `222.2 47.4% 11.2%` | Hover |
| `destructive` / `destructive-foreground` | `0 84.2% 60.2%` / `210 40% 98%` | Delete / error |
| `border` / `input` | `214.3 31.8% 91.4%` / same | Default border |
| `ring` | `222.2 84% 4.9%` | Focus ring |

crm-system 之前漏咗 `popover`, Day 12 補返。其他 (`card-foreground` / `popover-foreground` / `destructive-foreground` / `accent-foreground` / `secondary-foreground`) 仲未補, **長遠全部補齊**。但**不要一次過 patch 6 個** 因為容易撞 visual regression — 補一個驗一個, David 確認冇 regression 先補下一個。

## 整合 Day 12 教訓 (高層 abstract)

1. **Wire-format 跟 backend schema 嘅 field name, 唔跟 frontend type alias** (crm-system: backend `manDayLines`, frontend `manDays` 純係 type-level alias)
2. **Boundary normalize 喺 `lib/api.ts` 統一做, 唔好喺每個 component 重複** (single source of truth)
3. **Schema 改 field 嘅同日必須 grep frontend type 對應 field, 刪走 drift** (`isActive` → `status` 漏咗幾個月)
4. **Defensive code (`?? []`) 救表面但唔救根本**, 真正 root cause 喺 API boundary
5. **文檔 hygiene = 持續維護, 唔係 one-off 大整理** — README / PROGRESS 每 day 都要 update
6. **Tailwind 嘅 missing token silently omit**, 必須用 `rg` 對比 config 唔可以信 build pass

## Verification (Day 12)

- `bun run typecheck` → **exit 0** ✅ (apps/web)
- Prisma direct smoke: `prisma.service.create({ data: { ... } })` 成功, 冇 42704
- `GET /services` HTTP response (via curl) → 200 with `manDayLines` array populated
- `docker logs crm-api --tail 10` 顯示 "No pending migrations to apply" (sync 成功)
- Backend 唔使 restart (純 frontend code 改動, HMR 自動 reload)
- David browser smoke: 試 Service 列表 / 詳情 / Quotation Builder 新增服務三條路徑, 全部應該 work
