# Polymorphic QuotationItem — design rationale

## The problem

A modern CRM / quoting system often needs to quote **mixed** line items:

- Physical products (e.g. "27\" 4K Monitor @ $4500 each × 2")
- Services with man-day pricing (e.g. "Consulting @ $25,000 (Senior x 5 days + Junior x 10 days)")

These have **very different fields**:
- Product: `sku`, `stockQuantity`, `unitPrice`, `category`
- Service: `sow` (description), `manDaysTotal`, `manDayLines[]` (role + dayRate + days)
- Shared: `name`, `description`, `quantity`, `unitPrice`, `discount`, `lineTotal`

Trying to fit both in one table leads to either:
- **Sprawl** (nullable type-specific fields everywhere)
- **Coupling** (Product-specific rules bleeding into Service items)

## The design (crm-system Day 7, 2026-06-05)

### Two separate catalogue models

```
Product (sku, name, unitPrice, stockQuantity, ...)
   │
   │  0..*
   │
Service (name, unitPrice, sow, manDayLines[])
   │
   │  0..*
   │
   ▼
QuotationItem (polymorphic)
   - itemType: enum
   - productId | serviceId   (one of, never both)
   - snapshot: name, unitPrice, description, manDaySnapshot
   - pricing: quantity, discount, lineTotal
```

### The discriminator + dual-FK pattern

```prisma
enum ItemType { PRODUCT SERVICE }

model QuotationItem {
  itemType        ItemType
  productId       String?
  product         Product? @relation(fields: [productId], references: [id], onDelete: SetNull)
  serviceId       String?
  service         Service? @relation(fields: [serviceId], references: [id], onDelete: SetNull)
  // ... snapshot + pricing fields
}
```

**Invariant**: `(itemType == 'PRODUCT') <=> (productId != null)`. Server derives `itemType` from which FK is set, never trusts client.

### Why two FKs (not one polymorphic FK + a `kind` column)?

Some designs use a single `itemId` + `itemKind` column instead of two FKs. Rejected because:
- Loses Prisma's referential integrity
- Can't use `include: { product: {...} }` cleanly
- Need a discriminator + type guard on every read

Two FKs + enum = referential integrity + type safety + Prisma's full tooling works.

## Alternatives considered (and rejected)

### STI (Single Table Inheritance) via Prisma `@@delegate`

```prisma
model QuotationItemBase {
  id String @id
  // common fields
}
model ProductItem extends QuotationItemBase {
  // product-specific
}
model ServiceItem extends QuotationItemBase {
  // service-specific
}
```

**Rejected** because:
- Prisma 5.x STI is still experimental
- QuotationDetail queries need 3 separate `findMany` + manual union
- Migration tooling is rougher

### Unified `Item` table with `kind` discriminator + nullable type fields

```prisma
model Item {
  kind           ItemType
  // product fields
  sku            String?
  stockQuantity  Int?
  // service fields
  sow            String?
  manDayLines    Json?
  // shared
  unitPrice      Decimal
}
```

**Rejected** because:
- Lots of nullable fields (8+ for the service case alone)
- Easy to put a `sku` on a Service by mistake (no DB-level constraint)
- Per-tenant or per-region validation gets messier

### JSON `payload` column (no schema)

```prisma
model QuotationItem {
  itemType ItemType
  payload  Json   // entire row is JSON
}
```

**Rejected** because:
- No indexes, no Prisma client, no migrations
- Loses all the benefits of a relational DB

## Why Option A (separate tables + dual FK) is the right choice for crm-system

1. **The 2 catalogues have different lifecycles**:
   - Product: SKU updates, stock changes, supplier negotiations
   - Service: SOW revisions, day-rate updates, role mix changes
   - Keeping them in different tables means the entity managers (CRUD pages) can have different UX
2. **Referential integrity matters**:
   - The product's `category`, `lowStockThreshold` etc. are validated by Prisma
   - The service's `manDayLines` are constrained to belong to it via FK
3. **Query patterns are clear**:
   - "Show me all quotations that include Service X" → `where: { serviceId: x }` (indexed)
   - "Show me all services that haven't been quoted this month" → `where: { quotationItems: { none: { ... } } }`
4. **Snapshot fields preserve accounting immutability** without giving up the FK reference

## Migration story (crm-system Day 7)

Before Day 7, `QuotationItem` had only `productId` and was a flat table. The migration to polymorphic:

1. Create `ItemType` enum in Postgres
2. Add `itemType` column with `DEFAULT 'PRODUCT'` to backfill existing rows
3. Add `serviceId` FK with `ON DELETE SET NULL`
4. Add `manDaySnapshot JSONB` column
5. Add indexes on `serviceId`, `itemType`
6. Drop the `DEFAULT 'PRODUCT'` so future writes must set it explicitly

After this, all existing line items are `itemType='PRODUCT'` with `productId` set, no serviceId. New line items can be either type. Old `productId` queries still work unchanged.

## Snapshot vs reference — the pricing decision

| Approach | Pros | Cons |
|---|---|---|
| **Snapshot** (store unitPrice at quote time) | Quotation price is immutable; product price changes don't break history | If customer asks "what's our original quote?" 3 years later, the product's current price is wrong in the catalogue but the quotation still shows the original |
| **Reference** (store productId, re-derive unitPrice on read) | Always shows current product price | "We agreed on $4500 in March; why does the re-print show $5000 in September?" — accounting/audit nightmare |

For B2B sales, **snapshot is the only sensible choice**. The quotation is a contract; the catalogue is a marketing artefact. Mixing them is a recipe for disputes.

`manDaySnapshot` follows the same pattern: when the user picks Service "Consulting" with 5 man-days, the quotation captures the 5 man-days as a JSON snapshot. The service can later be edited to "3 man-days" but the original quotation still says 5.

## The frontend implications

- The "Add line item" form has a **type radio** (📦 Product / 🛠 Service)
- Each type has its own **catalogue picker**
- When picking, **immediately copy all pricing fields** into the line item
- For Service items, **show the man-day breakdown in read-only mode** in the detail view
- The detail view shows the source: "from Products" or "from Services" with a link
- Editing an existing line item: you can change quantity, discount, name (free text override), but the unit price is "frozen" once the item is in a SENT quotation

## Real-world example (crm-system Day 7)

```
Quotation Q-2026-0001 for "ACME Corp"
  📦 27" 4K Monitor       × 2 @ $4,500 = $9,000     (from Products, SKU HW-MON-001)
  📦 USB-C Cable 2m      × 5 @ $150   = $750       (from Products, SKU ACC-CBL-001)
  🛠 Implementation Service × 1 @ $45,000            (from Services)
       - Senior Engineer x 3 days @ $5,000 = $15,000
       - Junior Engineer x 10 days @ $3,000 = $30,000
  Subtotal: $54,750
  Tax (HKD 0%): $0
  Total: HKD $54,750
```

Notice:
- Mixed types in one quotation
- Man-day breakdown shown in detail (read-only) for the service
- All pricing is the snapshot — if "Senior Engineer" day rate changes to $6,000 tomorrow, this quote still shows $5,000

## When this design DOESN'T fit

- **E-commerce retail** (every line item is a product, no services): use a flat line item table, no need for polymorphism
- **Pure services business** (e.g. an agency that only sells consulting): use a flat line item table with man-day structure, no need for product table
- **Highly dynamic pricing** (e.g. crypto, commodities, per-second billing): use a reference pattern with price-as-of dates, not snapshots

## See also

- `templates/polymorphic-quotation-item-migration.sql` — concrete Postgres migration
- `backend-rbac-audit-log` Step 11 — the `as never` cast pattern for Prisma enum + JSON writes
- `crm-data-model` — base schemas for Product, Service, Quotation, QuotationItem
