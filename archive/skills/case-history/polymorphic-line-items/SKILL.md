---
name: polymorphic-line-items
description: "Design and implement polymorphic line items in a sales/quoting system — single parent (Quotation/Invoice) with mixed child item types (Product vs Service with different field shapes). Use when a quotation/invoice/order can have line items of more than one domain type (e.g. physical products + consultancy services), or when item fields don't fit a flat single-table model. Covers Option A (separate tables + discriminator + dual FK), STI trade-offs, snapshot pricing for accounting immutability, and Prisma enum/JSON write casts. Pairs with `crm-data-model` and `backend-rbac-audit-log`."
tags: ["polymorphism", "quotation", "invoice", "prisma", "schema-design", "crm", "sales", "elysia"]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# Polymorphic line items in a sales/quoting system

## 觸發時機

User says:
- "報價單要可以加 product 同埋 service"
- "Quotation item 唔同 type 唔同 fields (product 有 SKU, service 有 man-day)"
- "個 product catalogue 同 service catalogue 唔同, 但 quotation 兩者都加得到"
- "我哋有 hardware 同埋 consulting service, 兩種 line item 唔同 schema"
- "Invoice / Order line item 有多過一個 type"

## 三個 strategy 比較

| Strategy | Schema | 適合場景 | Trade-off |
|---|---|---|---|
| **Option A: 分開 tables + discriminator** (本 skill 推薦) | `Product`, `Service`, `ServiceManDay` 分開。`QuotationItem` 有 `itemType` enum + `productId` / `serviceId` FK + snapshot fields | Product 同 Service 嘅 domain fields 真係好唔同,e.g. product 有 SKU/stock, service 有 SOW/man-day | 報價時要 polymorphic reference (1 個 union field + 1 個 optional FK) |
| Option B: Unified `Item` table + `kind` discriminator + nullable type-specific fields | 1 個 `Item` table, kind column + 全部 type fields nullable | 想少 join,read-heavy 簡單 | 好多 nullable fields,easy 撞 dirty data |
| Option C: Prisma STI (Single Table Inheritance) | 兩 sub-model `extends Item` via `@@delegate` | 中庸 | Prisma 5.x STI 仲 experimental,production 唔建議 |

**crm-system 2026-06-05 (Day 7) 揀 Option A**: 11 model CRM 入面 Product 同 Service 嘅 fields 真係唔同 (Product 有 `sku`/`stockQuantity`, Service 有 `sow`/`manDaysTotal`),Option B 會撞到 nullable spam。

## Schema 設計 (Option A)

```prisma
// 1. The 2 separate catalogue models
model Product {
  id              String   @id @default(cuid())
  sku             String   @unique
  name            String
  description     String?
  category        String?
  unitPrice       Decimal  @db.Decimal(12, 2)
  currency        String   @default("HKD")
  trackInventory  Boolean  @default(false)
  stockQuantity   Int?
  // ...
  quotationItems  QuotationItem[]
  @@map("products")
}

model Service {
  id          String   @id @default(cuid())
  name        String
  description String?   @db.Text    // the SOW
  unitPrice   Decimal  @db.Decimal(12, 2)   // total fixed price
  currency    String   @default("HKD")
  isActive    Boolean  @default(true)
  sortOrder   Int      @default(0)
  // ...
  manDayLines ServiceManDay[]      // breakdown (documentation only)
  quotationItems QuotationItem[]
  @@map("services")
}

model ServiceManDay {
  id        String  @id @default(cuid())
  serviceId String
  service   Service @relation(fields: [serviceId], references: [id], onDelete: Cascade)
  role      String                              // "Senior Consultant", "Junior Engineer", etc
  dayRate   Decimal @db.Decimal(12, 2)
  days      Int
  subtotal  Decimal @db.Decimal(12, 2)         // dayRate * days
  sortOrder Int     @default(0)
  @@index([serviceId])
  @@map("service_man_days")
}

// 2. The discriminator — Day 9 change: use plain String, not Prisma enum.
// See "ItemType discriminator: String vs Prisma enum" pitfall below.
// Original (Day 7) recommendation was `enum ItemType { PRODUCT SERVICE }`,
// but in Day 9 we hit `42704: type "public.ItemType" does not exist` on
// Prisma.quotationItem.create() because the original Day-7 migration
// declared the column as TEXT (no enum type) but the schema was later
// synced to use the enum. Schema/DB drift = silent bug. Stick with String.
const PRODUCT = "PRODUCT"
const SERVICE = "SERVICE"

// 3. The polymorphic line item
model QuotationItem {
  id              String   @id @default(cuid())
  quotationId     String
  quotation       Quotation @relation(fields: [quotationId], references: [id], onDelete: Cascade)
  itemType        String   @default(PRODUCT)
  productId       String?
  product         Product?  @relation(fields: [productId], references: [id], onDelete: SetNull)
  serviceId       String?
  service         Service?  @relation(fields: [serviceId], references: [id], onDelete: SetNull)
  // Snapshot fields — frozen at quotation creation time
  sku             String?
  name            String
  description     String?
  quantity        Float
  unitPrice       Decimal  @db.Decimal(12, 2)
  discount        Float    @default(0)
  lineTotal       Decimal  @db.Decimal(12, 2)
  manDaySnapshot  Json?     // for SERVICE items: copy of service.manDayLines at creation
  position        Int
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  @@index([quotationId])
  @@index([productId])
  @@index([serviceId])
  @@index([itemType])
  @@map("quotation_items")
}
```

**關鍵 invariant**:
- `itemType` 必須 match `productId XOR serviceId` 嗰個有值嗰個
- 唔可以兩個 FK 都有 (否則 ambiguous),亦唔可以兩個都冇 (否則 orphaned line item)
- 報價創建時 snapshot 晒所有 pricing field,**將來 product/service 改價唔影響舊報價**

### ItemType discriminator: String vs Prisma enum (Day 9 lesson)

**Original Day 7 schema** used `enum ItemType { PRODUCT SERVICE }` because
Postgres enums are type-safe and prevent typos. **In Day 9 we hit a silent
trap** when the original Day-7 migration (`20260605030000_day7_dynamic_rbac_services`)
created the column as `TEXT NOT NULL DEFAULT 'PRODUCT'` (no enum type), but
later schema regeneration switched the field to `itemType ItemType` (with
enum). Prisma client accepted the new schema, `migrate dev` reported
"0 pending migrations", but the first `prisma.quotationItem.create({ data:
{ itemType: 'PRODUCT' } })` failed with:

```
PostgresError { code: "42704", message: "type \"public.ItemType\" does not exist" }
```

**Why the drift happens**:
1. Day 7 migration wrote `ADD COLUMN "itemType" TEXT NOT NULL DEFAULT 'PRODUCT'`
   to avoid the DDL overhead of `CREATE TYPE`
2. The schema was sync'd to `enum ItemType` later
3. `bunx prisma generate` regenerated client with enum expectations
4. Postgres still has TEXT column
5. The error only surfaces at the first `INSERT`, not at `prisma migrate status`

**Day 9 fix**: drop the `enum ItemType` declaration and use plain
`itemType String @default("PRODUCT")`. Application code uses hard-coded
strings (`if (it.serviceId) 'SERVICE' else 'PRODUCT'`) as the discriminator.
This:
- Adds new item types (`SUBSCRIPTION`, `USAGE`, `LICENSE`) without a DDL migration
- Avoids the enum/column-type drift
- Loses schema-level typo protection (mitigate via TS string literal types
  `'PRODUCT' | 'SERVICE'` in the application code)

```prisma
// ✅ Recommended (Day 9+)
itemType    String   @default("PRODUCT")

// ❌ Original Day 7 — risky if your migration history used TEXT for the column
enum ItemType { PRODUCT SERVICE }
itemType    ItemType
```

## Migration considerations

### 1. `ItemType` enum 加落 Postgres

如果由 `QuotationItem` 開始冇 enum 變成有 enum,migration 步驟:

```sql
-- 1. Create the enum
CREATE TYPE "ItemType" AS ENUM ('PRODUCT', 'SERVICE');

-- 2. Add the column with default to backfill existing rows
ALTER TABLE "quotation_items" ADD COLUMN "itemType" "ItemType" NOT NULL DEFAULT 'PRODUCT';

-- 3. Add the new FKs (all existing rows are PRODUCT)
ALTER TABLE "quotation_items" ADD COLUMN "serviceId" TEXT REFERENCES "services"("id") ON DELETE SET NULL;
CREATE INDEX "quotation_items_serviceId_idx" ON "quotation_items"("serviceId");

-- 4. Add the JSON snapshot column
ALTER TABLE "quotation_items" ADD COLUMN "manDaySnapshot" JSONB;

-- 5. Drop the default (no longer needed for new rows)
ALTER TABLE "quotation_items" ALTER COLUMN "itemType" DROP DEFAULT;
```

**Why default to PRODUCT**: assume existing line items are product-based (the most common case). If you have a mix, you need to inspect data first and split migrations.

### 2. Apply via Docker container (no host port)

```bash
docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < migration.sql
docker exec -i crm-postgres psql -U crm -d crm_system -c \
  "INSERT INTO \"_prisma_migrations\" (id, checksum, migration_name, finished_at, applied_steps_count)
   VALUES ('<unique>', '', '<timestamp>_<name>', NOW(), 1);"
```

(Pattern from `prisma-sqlite-bun-setup` and `bun-elysia-react-vite-stack` — local dev Postgres in container has no host port.)

## Backend route pattern (Elysia)

### Create a quotation with mixed line items

```typescript
.post('/', async ({ body, userId, request, set }) => {
  const data = body as {
    companyId: string;
    title: string;
    items: Array<{
      itemType?: string;             // optional: server derives from productId/serviceId
      productId?: string;
      serviceId?: string;
      sku?: string;
      name: string;
      description?: string;
      quantity: number;
      unitPrice: number;
      discount?: number;
      manDaySnapshot?: unknown;      // for SERVICE items
    }>;
  };

  const number = await nextQuotationNumber();
  let subtotal = 0;
  const items = (data.items ?? []).map((it, idx) => {
    const qty = Number(it.quantity);
    const price = Number(it.unitPrice);
    const disc = Number(it.discount ?? 0);
    const lineTotal = +(qty * price * (1 - disc / 100)).toFixed(2);
    subtotal += lineTotal;
    // Derive itemType from which FK is present (don't trust client)
    const itemType: string = it.serviceId ? 'SERVICE' : 'PRODUCT';
    return {
      itemType: itemType as never,                                            // string → ItemType
      productId: itemType === 'PRODUCT' ? it.productId : null,
      serviceId: itemType === 'SERVICE' ? it.serviceId : null,
      sku: it.sku,
      name: it.name,
      description: it.description,
      quantity: qty,
      unitPrice: price,
      discount: disc,
      lineTotal,
      manDaySnapshot: (it.manDaySnapshot ?? undefined) as never,               // unknown → InputJsonValue
      position: idx,
    };
  });

  const created = await prisma.quotation.create({
    data: {
      number,
      companyId: data.companyId,
      title: data.title,
      subtotal: +subtotal.toFixed(2),
      total: +subtotal.toFixed(2),
      items: { create: items },
    },
    include: { items: true, company: true },
  });

  await logEvent({
    action: 'QUOTATION_CREATED',
    actorId: userId ?? null,
    resourceType: 'quotation',
    resourceId: created.id,
    description: `Created quotation ${created.number}`,
    metadata: { number: created.number, itemCount: items.length, itemTypes: items.map(i => i.itemType) },
    request,
  });

  return created;
}, { /* body validation */ })
```

**Two key `as never` casts**:
1. `itemType: itemType as never` — string variable → Prisma's `ItemType` enum
2. `manDaySnapshot: (... ?? undefined) as never` — `unknown` from request body → Prisma's `InputJsonValue | NullableJsonNullValueInput`

Without these, the LSP screams even though Bun runtime would accept it. With them, the type system is bypassed cleanly. See `backend-rbac-audit-log` Step 11 for the full pattern.

### Add a single line item later

```typescript
.post('/:id/items', async ({ params, body, set, userId, request }) => {
  const data = body as {
    productId?: string;
    serviceId?: string;
    sku?: string;
    name: string;
    description?: string;
    quantity: number;
    unitPrice: number;
    discount?: number;
    manDaySnapshot?: unknown;
  };
  const last = await prisma.quotationItem.findFirst({
    where: { quotationId: params.id },
    orderBy: { position: 'desc' },
  });
  const position = (last?.position ?? -1) + 1;
  const lineTotal = lineTotalOf(Number(data.quantity), Number(data.unitPrice), Number(data.discount ?? 0));
  const itemType: string = data.serviceId ? 'SERVICE' : 'PRODUCT';
  const item = await prisma.quotationItem.create({
    data: {
      quotationId: params.id,
      itemType: itemType as never,
      productId: itemType === 'PRODUCT' ? data.productId : null,
      serviceId: itemType === 'SERVICE' ? data.serviceId : null,
      sku: data.sku,
      name: data.name,
      description: data.description,
      quantity: Number(data.quantity),
      unitPrice: Number(data.unitPrice),
      discount: Number(data.discount ?? 0),
      lineTotal,
      manDaySnapshot: (data.manDaySnapshot ?? undefined) as never,
      position,
    },
  });
  await logEvent({
    action: 'QUOTATION_UPDATED',
    actorId: userId ?? null,
    resourceType: 'quotation',
    resourceId: params.id,
    description: 'Added line item',
    metadata: { itemId: item.id, itemType, name: data.name },
    request,
  });
  return item;
})
```

## Service catalogue pricing — the design decision

**Three options** (from `crm-system` Day 7 negotiation):

| Option | Description | When to use |
|---|---|---|
| **A. Service has fixed `unitPrice` + man-day structure for display** | Service has 1 total `unitPrice`. `ServiceManDay` lines exist but are documentation only (SOW-style breakdown). Quotation picks service → unit price auto-fills. Man-day lines display in detail view but don't change unit price. | ⭐ Most CRM / service-business cases |
| B. Quotation expands man-day at pick time | Service has default man-day structure. Quotation can override individual man-day lines (e.g. swap Senior for Junior). | When projects have heavy pricing flexibility |
| C. Hybrid | Service has default, quotation can override per-line | Edge case, add only if A is too rigid |

**Recommendation**: **Option A**. The man-day lines give the customer visibility (e.g. "1× Senior @ 5 days = $25K, 2× Junior @ 10 days = $30K, total $55K") without complicating the quote builder. Quotation builder just shows the breakdown as read-only detail.

## Pricing snapshot pattern (accounting immutability)

**Why snapshot**: when a product's `unitPrice` changes (e.g. annual price update), all existing quotations should keep the old price. The audit trail is "this is what the customer agreed to on 2026-06-05."

```typescript
// At quotation create time, COPY the current price into the line item:
const item = {
  unitPrice: product.unitPrice,          // ← snapshot, not a reference
  name: product.name,                    // ← snapshot
  description: product.description,      // ← snapshot
  // productId is still kept so we can render "this came from Product X" later
  productId: product.id,
};
```

**When to NOT snapshot**: rare. If your business is "live-priced" (e.g. crypto, commodities), keep `unitPrice` as a reference and re-evaluate at invoice time. In that case the design is different — you probably want a price-as-of date column on the item.

## GP (Gross Profit) snapshot + SENT lock (2026-06-06 crm-system)

David Day-N 2-layer 需求:每條 line item 要 show 毛利金額 + 毛利率,quotation SENT 之後要 lock(因為 admin 改咗 service 嘅成本 / 售價唔可以再影響已發出嘅報價)。呢個係 polymorphic-line-items "snapshot pricing" 嘅 **增強** 概念 — 唔單止 snapshot price,仲要 snapshot cost + lock 喺 SENT 之後。

### 3 個新 columns 喺 `QuotationItem`

```prisma
model QuotationItem {
  // ... existing polymorphic + snapshot fields ...
  costSnapshot    Decimal  @default(0)  @db.Decimal(12, 2)   // per-line cost (man-day × costRate)
  lineGp          Decimal  @default(0)  @db.Decimal(12, 2)   // lineTotal - costSnapshot
  lineGpPercent   Decimal  @default(100) @db.Decimal(5, 2)   // lineGp / lineTotal × 100
}
```

### GP formula

| Item type | costSnapshot | lineGp | lineGpPercent |
|---|---|---|---|
| **PRODUCT** | 0 | `lineTotal` | 100 |
| **SERVICE** | `Σ(manDayLine.costRate × days)` per line | `lineTotal - costSnapshot` | `lineGp / lineTotal × 100` |

Example: Senior Engineer 1000 售 / 600 成本 × 5 days:
- lineTotal = 1000 × 5 = 5000
- costSnapshot = 600 × 5 = 3000
- lineGp = 5000 - 3000 = 2000
- lineGpPercent = 40%

### Backend helpers (Elysia route)

```typescript
// apps/api/src/lib/quotation-gp.ts  ← Day 17 extracted (2026-06-08)
//
// Why extracted: originally gpOf + costPerManDayFromSnapshot lived
// as private functions in apps/api/src/routes/quotation.ts.
// Importing the route file to test them would have spun up the
// Elysia app, Prisma, and the DB connection — too heavy for a unit
// test. Extracting to apps/api/src/lib/quotation-gp.ts lets the
// helpers be unit-tested in isolation (14 tests in
// apps/api/src/__tests__/quotation-gp.test.ts), and the route
// file imports them back. No behaviour change.

// Snapshot cost from a service line's man-day breakdown JSON.
// The manDaySnapshot shape is { lines: [{ role, dayRate, days, costRate, subtotal }] }
export function costPerManDayFromSnapshot(snap: unknown): number {
  const lines = (snap as { lines?: unknown[] })?.lines;
  if (!Array.isArray(lines) || lines.length === 0) return 0;
  let totalCost = 0, totalDays = 0;
  for (const l of lines) {
    totalCost += Number((l as { costRate?: number }).costRate ?? 0) * Number((l as { days?: number }).days ?? 0);
    totalDays  += Number((l as { days?: number }).days ?? 0);
  }
  return totalDays > 0 ? totalCost / totalDays : 0;
}

export function gpOf(itemType: string, lineTotal: number, costSnapshot: number) {
  if (itemType === 'PRODUCT') return { lineGp: lineTotal, lineGpPercent: 100 };
  const gp = lineTotal - costSnapshot;
  return { lineGp: gp, lineGpPercent: lineTotal > 0 ? (gp / lineTotal) * 100 : 0 };
}
```

**Helper extraction pattern** (Day 17 2026-06-08, applies to ANY
pure function buried inside a route file):
1. Identify pure functions inside `apps/api/src/routes/<thing>.ts`
   (no DB calls, no `request` arg, no side effects).
2. Move them to `apps/api/src/lib/<thing>-<helper>.ts` and `export`.
3. The route file imports them back. Behaviour is bit-for-bit
   identical — only relocation.
4. Add `apps/api/src/__tests__/<thing>-<helper>.test.ts` with
   `bun test`. Use `bun:test` (zero-install, ships with Bun).
5. Run `bun build src/index.ts --target=bun --outdir=/tmp/x` to
   confirm the route file still resolves and bundles (catches
   import-cycle / typo bugs that `tsc --noResolve` would miss).
6. Register RG entry (see REGRESSION-GUARD.md pattern) pinning
   the formulas so a future refactor can't silently change them.

**Why this matters**: GP% drives totals on the Quotation detail
page AND the Excel export (US-A5). Wrong GP% is a deal-killer —
sales would lose trust in the system. The 14 tests are the
contract.

### Recalc strategy: DRAFT refreshes from live, SENT freezes

```typescript
async function recalcQuotationAndItems(quotationId: string, opts: { liveCostRefresh?: boolean }) {
  const items = await prisma.quotationItem.findMany({ where: { quotationId } });
  const q = await prisma.quotation.findUnique({ where: { id: quotationId } });

  for (const it of items) {
    let costPerManDay = 0;
    if (it.itemType === 'SERVICE') {
      if (opts.liveCostRefresh && it.serviceId) {
        // DRAFT: pull the current ServiceManDay lines to recompute cost
        const live = await prisma.serviceManDay.findMany({ where: { serviceId: it.serviceId } });
        if (live.length > 0) {
          const totalCost = live.reduce((s, l) => s + Number(l.costRate) * Number(l.days), 0);
          const totalDays = live.reduce((s, l) => s + Number(l.days), 0);
          costPerManDay = totalDays > 0 ? totalCost / totalDays : 0;
        } else {
          costPerManDay = costPerManDayFromSnapshot(it.manDaySnapshot);
        }
      } else {
        // SENT: read from the snapshotted JSON, never from live
        costPerManDay = costPerManDayFromSnapshot(it.manDaySnapshot);
      }
    }
    const costSnapshot = costPerManDay * Number(it.quantity);
    const { lineGp, lineGpPercent } = gpOf(it.itemType, Number(it.lineTotal), costSnapshot);
    await prisma.quotationItem.update({ where: { id: it.id }, data: { costSnapshot, lineGp, lineGpPercent } });
  }
  // Refresh header totals
  const updated = await prisma.quotationItem.findMany({ where: { quotationId } });
  const subtotal = updated.reduce((s, it) => s + Number(it.lineTotal), 0);
  const taxAmount = subtotal * (Number(q.taxRate) / 100);
  await prisma.quotation.update({ where: { id: quotationId }, data: { subtotal, taxAmount, total: subtotal + taxAmount } });
}
```

### SENT transition: zero-cost guard + lock

```typescript
.post('/:id/status', async ({ params, body, set, userId, request }) => {
  const { status } = body as { status: string };
  if (status === 'SENT') {
    // 1. Last-chance GP refresh from live ManDayRole costs (DRAFT only)
    await recalcQuotationAndItems(params.id, { liveCostRefresh: true });
    // 2. Reject if any SERVICE line still has cost=0 (would fake 100% GP)
    const svcLines = await prisma.quotationItem.findMany({
      where: { quotationId: params.id, itemType: 'SERVICE' },
      select: { id: true, name: true, costSnapshot: true, lineTotal: true },
    });
    const zeroCost = svcLines.filter((l) => Number(l.costSnapshot) === 0 && Number(l.lineTotal) > 0);
    if (zeroCost.length > 0) {
      set.status = 422;
      return { error: 'Cannot send: service lines have zero cost configured. Set a man-day role cost first.', lines: zeroCost };
    }
  }
  // 3. Apply status
  await prisma.quotation.update({ where: { id: params.id }, data: { status, sentAt: status === 'SENT' ? new Date() : undefined } });
});
```

### PATCH / items: reject after SENT

After the status leaves DRAFT, every mutation endpoint (PATCH `/quotations`, POST `/quotations/:id/items`, PATCH `/quotations/:id/items/:itemId`, DELETE `/quotations/:id/items/:itemId`) must early-return 409:

```typescript
const q = await prisma.quotation.findUnique({ where: { id: params.id }, select: { status: true } });
if (q.status !== 'DRAFT') {
  set.status = 409;
  return { error: `Quotation is ${q.status} and cannot be modified. Create a revision instead.` };
}
```

### 2 個關鍵 invariant

1. **DRAFT = live, SENT = frozen**. Admin 改咗 `ManDayRole.price` / `ManDayRole.cost` 之後,所有 DRAFT 報價嘅 lineTotal / costSnapshot / lineGp 喺 next edit 自動 re-derive。SENT 之後個 quotation 永久鎖,即使 admin 再改 cost,已 SENT 嘅報價唔變。

2. **Zero-cost service line = blocking error at SENT time**. 如果 admin 漏咗 set 個 man-day role 個 cost,條 SERVICE line 嘅 `costSnapshot = 0`,lineGp 變 100%(假象)。SENT transition 要 reject,並 list 出邊幾條 line 有問題,等 admin 補完 cost 先再 send。

### 點解唔用 trigger / DB-level check

Postgres `CHECK (cost_snapshot >= 0)` 同 enum extension 做唔到「DRAFT vs SENT 唔同 cost-refresh 邏輯」呢個 runtime 行為。Application-layer recalc + SENT-time guard 係最直接嘅表達,而且測試容易(每個 endpoint 一個 `if (status !== 'DRAFT') return 409` 即可)。

## Frontend pattern (React / Vite / shadcn)

The quotation builder needs a polymorphic item editor. Key UI decisions:

```tsx
// In the line item editor:
const [itemType, setItemType] = useState<'PRODUCT' | 'SERVICE'>('PRODUCT');

// Switch between product picker and service picker
return (
  <div>
    <RadioGroup value={itemType} onValueChange={(v) => setItemType(v as any)}>
      <RadioGroupItem value="PRODUCT">📦 Product</RadioGroupItem>
      <RadioGroupItem value="SERVICE">🛠 Service</RadioGroupItem>
    </RadioGroup>

    {itemType === 'PRODUCT' ? (
      <ProductPicker
        products={products}
        onSelect={(p) => {
          // Snapshot pricing from product
          updateLineItem({ productId: p.id, name: p.name, unitPrice: p.unitPrice, description: p.description, sku: p.sku });
        }}
      />
    ) : (
      <ServicePicker
        services={services}
        onSelect={(s) => {
          // Snapshot pricing + man-day breakdown from service
          updateLineItem({
            serviceId: s.id,
            name: s.name,
            unitPrice: s.unitPrice,
            description: s.description,  // SOW
            manDaySnapshot: s.manDayLines,
          });
        }}
      />
    )}

    {/* Man-day breakdown display (read-only) for SERVICE items */}
    {itemType === 'SERVICE' && item.manDaySnapshot && (
      <ManDayBreakdown lines={item.manDaySnapshot} />
    )}
  </div>
);
```

**Key UI rules**:
1. **Server derives `itemType` from which FK is set** — never trust client's `itemType` field
2. **When user picks a Product, snapshot ALL fields immediately** (name, price, description, sku) — don't hold a reference
3. **When user picks a Service, also snapshot the man-day breakdown** as `manDaySnapshot` JSON
4. **Show the man-day breakdown in the line item detail view** but don't allow editing (per Option A design)
5. **Display the source**: "📦 27\" 4K Monitor (from Products)" or "🛠 Consulting Service (from Services)"

### Quick-create modal in picker — must be FULL form, not minimal (2026-06-06 crm-system 真實撞牆)

**症狀**: 寫 `ProductAutocomplete` / `ServiceAutocomplete` 嘅「新增 Product/Service『...』」inline modal 時, 只攞 `name` + `unitPrice` 兩個 field 就 submit。User 喺 quotation builder 開新單 → autocomplete 揀「新增」→ modal 出 → 入完個名就 close → **個新 product/service 冇 description / category / SKU / SOW / man-day breakdown** → 要跳去 `/products` 或 `/services` page 再編輯補完。User 投訴:「想加新完之後就不用去 Service 頁再入 man day」。

**根因**: 設計 quick-create modal 時, 開發者貪方便只攞 required fields 就 ship。但 user 嘅 mental model 係「我喺度搞掂晒呢條 line item」, 佢哋唔想因為 quick-create 太弱就要 navigate 兩次。**Quick-create 嘅 full feature set 必須等於 catalogue page 嘅 create form**, 唔可以打折扣。

**Fix (推薦) — 抽出共用 component**:

```
apps/web/src/components/quick-create-service-dialog.tsx
apps/web/src/components/quick-create-product-dialog.tsx
```

呢兩個 component 喺**兩個地方用**:
1. Quotation Builder 嘅 autocomplete dropdown (點「新增 Service/Product『...』」)
2. `/services` / `/products` page 嘅「新增服務/新增產品」掣

Form 對齊 catalogue page:
- **Service**: name (defaultName pre-fill 從 query) + description (SOW textarea) + currency (HKD/USD/...) + **man-day rows (add/remove, role + dayRate + days)** + unitPrice auto = Σ(dayRate × days) + category + status (ACTIVE/ARCHIVED/DRAFT)
- **Product**: name (defaultName pre-fill) + SKU (auto-uppercase) + description + category + status (ACTIVE/ARCHIVED/OUT_OF_STOCK) + currency + unitPrice + costPrice + trackInventory toggle + stockQuantity + lowStockThreshold

**Day 11 教訓 — Quick-create 都應該做 "full form parity"**: 之前以為 "full form = 全部 fields 塞入 quick-create" 會 overkill 影響 UX。**錯**。David 嘅 mental model 係「我喺度搞掂晒呢條 line item」,佢寧願 quick-create 嘅 modal 比較大, 都不想兩次 navigation。Day 11 將 trackInventory / lowStockThreshold 都塞入 quick-create 之後 David 反而滿意,冇投訴 modal 太大。**Rule of thumb**: Quick-create 嘅 full feature set 必須等於 catalogue page 嘅 create form, **唔可以打折扣**。Inventory / lowStockThreshold 唔係高級設定,係 base feature。

**Quick-create 嘅 file 命名 convention (Day 11 統一)**:
- Product dialog 改名做 `product-dialog.tsx`(唔再叫 `quick-create-product-dialog.tsx`)+ props `product?` 支援 create + edit 兩種 mode
- Service dialog 維持 `quick-create-service-dialog.tsx` 因為唔需要 edit 模式(由 `/services/:id` 頁面負責)
- 兩個 dialog 都 support `defaultName?: string` prop 俾 quotation builder autocomplete pre-fill

**抽出共用嘅 step-by-step**:
1. 寫新 `components/<thing>-dialog.tsx` 入面放原本 `pages/<thing>.tsx` 入面嘅 local dialog function
2. 個 dialog 接受 `product?` / `defaultName?` optional props
3. 原本 `pages/<thing>.tsx` 改 import,移除 local function
4. `quotation-builder.tsx` 嘅 autocomplete 都 import 同一個 component
5. `bun run typecheck` 確認 prop signature 一致(特別是 onSaved 接收 created 個 object, 唔好只收 `void`)

**Type signature warning (Day 11 撞過)**: 共用 dialog 嘅 `onSaved` callback 一定要 receive created entity, 因為 quotation builder 需要即時 append 入本地 state 而唔係 refetch:
```typescript
// ❌ 唔好
onSaved: () => void;

// ✅ 改
onSaved: (entity: Product | Service) => void;
```
Caller (`quotation-builder.tsx` 嘅 `<ProductDialog onSaved={...}>`) 用 callback append state + 揀返出嚟:
```typescript
<ProductDialog
  defaultName={query}
  onSaved={(created) => {
    onCreate(created);          // append 入 QuotationBuilder 嘅 catalogue state
    onChange(created.id);       // 即刻揀返個新 item
    setCreateOpen(false);
  }}
/>
```

**Service type normalisation 陷阱 (Backend 返 `manDayLines`, Frontend type 用 `manDays`)**:
```typescript
// apps/api/src/routes/service.ts 嘅 Prisma include 係 `manDayLines`
// 但 apps/web/src/lib/api.ts 嘅 Service type 用 `manDays`
// 兩者 mismatch 要喺 dialog 出口 normalize:
const manDaysFromResponse = (created as Service & { manDayLines?: ServiceManDay[] }).manDayLines;
const normalised: Service = {
  ...created,
  manDays: created.manDays ?? manDaysFromResponse ?? [],
};
onCreated(normalised);
```
唔然 `applyService` 嘅 `service.manDays` 係 `undefined` → `manDaySnapshot` 變空 JSON, quotation detail 個 SOW breakdown 唔顯示。

**🚨 Critical 衍生 pitfall: Elysia strict `t.Object` body validator 會 throw 502 (2026-06-06 crm-system Day 11 真實撞牆)**

**症狀**: Submit `POST /services` 個 modal(不論 Quotation Builder autocomplete 抑或 Services page)→ backend 返 **502**。Backend log 顯示 Elysia 撞 `Validation failed` 但**唔** throw 422 / 400,反而 nginx / 反向代理見到 upstream error 返 502。**前端 4 個 submission path(quick-create-dialog + services page 共享 component)都中招**。

**根因 — wire-format 命名錯配 (silent, no TS error)**:
- Backend `apps/api/src/routes/service.ts` 嘅 `t.Object({ ... manDayLines: t.Array(t.Object({ role, dayRate, days })) })` 用 **Prisma relation name** `manDayLines` 做 JSON payload key
- Frontend `apps/web/src/lib/api.ts` `servicesApi.create({ manDays: [...] })` 個 typed signature 用 **business / frontend field name** `manDays`
- Result: backend strict `t.Object` validator 見到 `{manDays: [...]}` 個 `manDays` 唔喺 schema, reject 個 body → 502 上游 → client 收 502
- 仲有 `category` 同 `status` 兩 field:backend schema 接受但 frontend 冇 send → 啱啱 OK 因為佢哋 `t.Optional`;但 `manDayLines` 唔 optional(就係成個 create 嘅 point),所以撞親

**Fix (1 個改動, 2 個 effect)**:
```typescript
// apps/web/src/components/quick-create-service-dialog.tsx (或者共用 component)
// 1. 落 wire format 時用 Prisma 嘅 relation name
const created = await servicesApi.create({
  name: name.trim(),
  description: description.trim() || undefined,
  category: category.trim() || undefined,
  status,                                       // 'ACTIVE' | 'ARCHIVED' | 'DRAFT'
  currency,
  unitPrice: total,
  manDayLines: manDays,                         // ← KEY 唔係 manDays
} as never);                                    // bypass TS signature 嘅 `manDays` 約束

// 2. 收到 response 嘅 field 叫 manDayLines, normalize 入 Service type
const manDaysFromResponse = (created as Service & { manDayLines?: ServiceManDay[] }).manDayLines;
const normalised: Service = {
  ...created,
  manDays: created.manDays ?? manDaysFromResponse ?? [],
};
onCreated(normalised);
```

**點解 TS typecheck 唔 catch 呢個錯**:
- `servicesApi.create` 入面 `data: { ...; manDays?: ... }` 完全 typing-pass 因為 `manDayLines` 唔存在於 type,strict 模式 TS 會 silently extend(因為 `as never` cast 喺前面)
- 解決方法有 2:(a) `servicesApi.create` signature 改用 `manDayLines` 對齊 backend(推薦, single source of truth);(b) dialog 入面 `as never` 兩個 cast
- 選 (a) 即係改 `lib/api.ts`:
  ```typescript
  create: (data: { name; description?; unitPrice?; currency?; isActive?; sortOrder?; manDayLines?: Array<{role; dayRate; days; sortOrder?}> }) =>
    request<Service>('/services', { method: 'POST', body: JSON.stringify(data) }),
  ```
  咁 `manDayLines` 同 `manDays` 兩邊都過 typecheck, frontend 唔需要 normalize response 因為 type 一致。
- 警告: 改 (a) 之後所有 `servicesApi.create` caller 要 update, 但成個 codebase 呢個 modal 之前只有一處用, 改 signature 影響有限

**Detection (撞牆必做)**:
```python
# 唔好靠 fetch 同 DevTools — 502 嘅 root cause 喺 backend log
import urllib.request, json, urllib.error
data = json.dumps({
  "name": "Test", "unitPrice": 100, "manDays": [{"role":"PM","dayRate":5000,"days":5}]
}).encode()
try:
  resp = urllib.request.urlopen(urllib.request.Request(
    "http://localhost:3001/services", data=data, method="POST",
    headers={"Content-Type": "application/json"}), timeout=5)
  print("OK:", resp.status)
except urllib.error.HTTPError as e:
  print("HTTP", e.code, e.read().decode()[:300])
  # If 502: nginx upstream error → 真係 backend 5xx (validation throw)
  # If 422: Elysia validation 直接返 (代表 backend 直接 reachable, 個 throw 係 expected)
  # Backend log 一定要 check, 因為 Elysia 個 validation error 唔一定有 stack trace
```

**Generic rule (套用到所有 Elysia POST/PATCH 帶 `t.Object` body validator 嘅 endpoint)**:
- Backend 個 schema 嘅 field name 係 source of truth (Prisma relation name)
- Frontend type signature 唔可以擅自用 business / camelCase alias
- wire-format key 一定要跟 backend schema, **唔可以跟 frontend interface**
- Code review 點 check: `rg "servicesApi\.|productsApi\.|quotationsApi\." apps/web/src` 對比 backend `t.Object` validator 嘅 keys,差集 = silent bug

**Reference (完整 session log)**: `bun-elysia-react-vite-stack/references/2026-06-06-crm-system-quotation-builder-enhancements.md`

**Send 個 wire key 要 match validator, 唔係 match local type (2026-06-06 真實撞牆 → 502)**:
個 normalisation 步驟只解決 response 嗰邊。**Request 嗰邊更危險**: 因為 Elysia `t.Object` body validator 會**靜悄悄 strip 走任何唔喺 schema 嘅 key**, 所以如果你嘅 API client type 用 `manDays` 但 validator 寫 `manDayLines`, Elysia 收到 `manDays` 之後當冇呢個 field, Prisma `service.create` 嗰個 `manDayLines: { create: ... }` 就攞 `undefined`, 結果親 line 都冇 create 到。視乎下游 typed consumer 點 assert, 呢個可能係 silent data loss 或者 HTTP 502 拋出嚟。**Wire key 一定要 match validator 嗰個 key** (即係 Prisma relation 嗰個名), 唔好 match 本地 type field 嗰個名。詳見 `patch-route-field-silently-dropped` 嘅 "When the Dropped Field Is a Prisma Relation" section 入面個 crm-system 2026-06-06 case study (連 fix pattern 都有)。

**Delivery checklist for 呢個 enhancement**:
- [ ] 新建 2 個 shared component (Service + Product)
- [ ] 改 `quotation-builder.tsx`: 移除 local `QuickCreate*Dialog` function, import 新共用
- [ ] 改 `pages/services.tsx`: 移除本地 `CreateServiceDialog` function, import 新共用
- [ ] typecheck pass
- [ ] Browser smoke: 喺 quotation builder → 加 Service → 開 quick-create → 入 man-day → submit → 條 line item 嘅 SOW breakdown 即刻顯示

## ⚠️ Pitfalls (Day 7 crm-system)

1. **Never set both `productId` and `serviceId`** — keep one as `null` explicitly, not undefined, in the Prisma write
2. **The `as never` cast is required for enum + JSON fields** when the value comes from a string variable or unknown type. See `backend-rbac-audit-log` Step 11
3. **Server must derive `itemType` from FK presence**, not trust the client. If client sends `itemType: 'SERVICE'` with `productId: 'abc'`, server should correct to `PRODUCT` based on which FK is set
4. **Snapshot pricing at create time** — see the "Pricing snapshot" section
5. **Man-day breakdown is documentation only** when using Option A. Don't let the user edit it in the quotation builder; let them edit it on the Service detail page if needed
6. **Index the FKs** (`productId`, `serviceId`, `itemType`) for fast filtering by item type in reports

## ⚠️ Backend-only polymorphic refactor = invisible to user (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: 完成 Day 7 嘅 schema migration + 2 個新 routes (`/api/services`, `/api/roles`) + polymorphic QuotationItem backend 之後, **所有 API smoke test 200**, commit + push 都成功, 但 David 試完一次即問「**我見不到有這些功能**」。問題: backend 改咗但**冇 surface 出嚟俾 user 用**。冇 `/services` page, 冇 `/roles` page, Quotation builder 仍係 product-only 揀唔到 service, 個 admin nav 都冇 link 去新 page。

**根因**: Polymorphic refactor 涉及 4 個 layer (schema, backend, frontend, UX) 但我做咗 1-3 layer 就 commit, 以為 "backend work done = feature done"。對 user 嚟講, **佢只睇得到 frontend**, 個 backend 喺 container 入面做咗咩佢唔 care。

**教訓 — Polymorphic refactor 嘅 delivery checklist 必須 4 個 layer 一齊 ship**:

| Layer | 改咩 | Backend-only delivery 嘅 user 觀感 |
|---|---|---|
| 1. Schema | `Service` table, `ItemType` enum, polymorphic FK | 完全 invisible |
| 2. Backend routes | `servicesApi`, `rolesApi`, polymorphic quotation endpoint | 完全 invisible (除非 user 開 DevTools) |
| 3. Frontend `api.ts` | 對應 typed client + types | 完全 invisible |
| 4. Frontend pages | `/services` page, `/roles` page, Quotation builder 嘅 product/service radio, App.tsx routes, nav | **唯一 user 見到嘅 layer** |

**硬性 rule** (2026-06-05 之後): **同一個 commit series 入面, polymorphic 嘅 schema + backend + frontend 必須全部 done**。如果 frontend 太大要 split commit, 至少要出 demo screenshot / E2E 證明 user 見到。

**冇 demo / 冇 UI = 等於冇做**。當你 commit 完之後諗 "下一步 David 會用邊度試呢個 feature?", 答唔到 = 冇完。

**Frontend layer 嘅 verify step (2026-06-06 crm-system Day 11+ 真實撞牆)**:

將 Layer 4 進一步拆:
- **4a. Shared component 共用** (e.g. `QuickCreateServiceDialog` 同時被 Quotation builder + `/services` page 用) — 抽出嚟 + import 入兩個地方
- **4b. Page wire** (e.g. `/services` page 用 `QuickCreateServiceDialog` + `servicesApi`)
- **4c. Nav + route** (e.g. `<Route path="/services" />` + `app-layout.tsx` 嘅 nav link)

完成上述任何一個 sub-step,**必須 run `docker compose build web`** 確認冇 TS error 先 commit。**LSP diagnostics 喺連續 patch 之下係 stale 嘅**(見 `bun-elysia-react-vite-stack` 嘅 "LSP stale" pitfall),唔好信 LSP 報嘅 error,**信 `docker compose build web` exit code 0**。

Anti-pattern:
- 寫完 page 唔 build 就 commit → 推到 GitHub 個 page 完全 fail render
- 信 LSP 報嘅 error 一路 chase 改到 file 越來越亂,最後先 build 發現 LSP 全部 stale
- Subagent 完成 page 後 report "done" 但冇 build → 推到 production 個 page 空白

Correct pattern:
```bash
# 改完 frontend file 跑 build 永遠係下一步 — 唔好 skip
cd ~/www/<project>
docker compose build web 2>&1 | grep -E 'error TS|failed|exit code' | head -10
# 0 個 error TS = OK to commit
```

**Delivery checklist for 呢個 enhancement** (擴充):

**3 個 Elysia/Ecosystem spec 同時撞** (Day 7 同 session 內一次過出):
- Elysia 1.2 `onBeforeHandle` derive context bug (見 `bun-elysia-react-vite-stack` §衍生)
- Bun `export *` 唔 re-export named consts
- npm/package manager difference: backend 用 `bun add`, frontend 用 `npm install --include=optional` 避 arm64 binary issue

呢 3 個 ecosystem 細節令一個本來 4 小時嘅 polymorphic refactor 變成 8 小時。**下次 polymorphic refactor 要 budget 額外 50% 時間俾 ecosystem 撞牆**。

## Verification checklist

After implementing:
- [ ] Can create a quotation with mixed items (1 product + 1 service)
- [ ] Quotation detail shows the right source for each item (📦 vs 🛠)
- [ ] Service item shows man-day breakdown in detail view
- [ ] Changing `Product.unitPrice` after the quotation is created does NOT change the line item's `unitPrice`
- [ ] Changing `Service.unitPrice` after the quotation is created does NOT change the line item's `unitPrice`
- [ ] Deleting a product/service that has a quotation item either:
  - Keeps the snapshot (if `onDelete: SetNull`) — line item becomes orphaned but still quoted
  - Cascades the delete (if `onDelete: Cascade`) — destructive but clean
  - The recommendation is `SetNull` + keep the snapshot fields, so historical quotations are never broken
- [ ] Audit log records `QUOTATION_CREATED` with item count + types in metadata
- [ ] Permissions: SALES can create quotations with both types; VIEWER can read; ADMIN can delete

## Related skills

- `crm-data-model` — Product / Service / Quotation / QuotationItem base schemas
- `backend-rbac-audit-log` — the `as never` cast pattern, `requirePermission` plugin, audit logging
- `prisma-sqlite-bun-setup` — SQLite adaptation (replace enum with string, Json with String)
- `prisma-migrate-private-rds` — applying migrations when DB is in a private VPC
- `bun-elysia-react-vite-stack` — `references/2026-06-06-crm-system-quotation-builder-enhancements.md` 集中咗 polymorphic reference UX 嘅 quick-create modal full-form pattern (Day 10 真實撞牆)

## Reference implementations

- `references/polymorphic-quotation-item-design.md` — full design rationale + alternatives considered
- `templates/polymorphic-quotation-item-migration.sql` — ready-to-run Postgres migration adding `ItemType` enum + dual FKs + JSON snapshot
