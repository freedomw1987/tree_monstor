---
version: alpha
name: prisma-relation-debugging
description: "Debug Prisma schema vs code mismatches: explicit @relation fields need { connect: { id } } syntax, not shorthand. Also covers the UncheckedCreateInput vs CreateInput split (flat FK columns can't mix with nested connect — need explicit cast or `as never` traps) and `prisma generate` validation failures for named-relation fields when adding a 2nd+ relation to an existing model."
trigger: "Any Prisma error involving: Unknown argument 'X' on a model create/update, Argument 'X' is missing, Invalid `X` invocation, `prisma generate` validation error 'relation field X on model Y is missing an opposite relation field on model Z', a field defined as a relation in schema but code uses it as a scalar (or vice versa), or `data: body as never` cast hiding a real Prisma relation-mapping error."
---

# Prisma Explicit Relation — Schema/Code Mismatch Debugging

## Trigger

Any Prisma error involving:
- `Unknown argument 'X'` on a model create/update
- `Argument 'X' is missing` on a model create/update
- `Error: Invalid `X` invocation` on relation fields
- **`prisma generate` validation error: `relation field X on model Y is missing an opposite relation field on model Z`** ← schema-time, not runtime (crm-system 2026-06-07)
- A field defined as a relation in schema but code uses it as a scalar (or vice versa)

## Pitfall 1 — `Prisma.XxxUncheckedCreateInput` vs `XxxCreateInput` (crm-system 2026-06-07)

**Symptom** (runtime, even when `prisma generate` succeeds):

```
Argument `company` is missing.
```

on a `prisma.deal.create({ data: { companyId: "...", stageId: "...", ... } })` call where the model has:

```prisma
company Company @relation(fields: [companyId], references: [id])
stage   PipelineStage @relation(fields: [stageId], references: [id])
```

**Why it happens**: Prisma generates TWO input types per model:
- `DealCreateInput` — requires the nested relation shape (`company: { connect: { id } }`)
- `DealUncheckedCreateInput` — accepts flat FK columns (`companyId: "..."`)

When the model has **both** the FK column AND a `@relation` field, the two
input types are **mutually exclusive**: you cannot specify `companyId`
AND `company: { connect: { id } }` in the same `data` object. The
"checked" type disallows the flat FK column (it's stripped from the
type), and the "unchecked" type disallows the relation wrapper.

**Trap**: `data: body as never` (the crm-system Day 8 deal pattern)
suppresses the TypeScript error and silently lands on the WRONG input
type. The runtime 500s with `Argument company is missing` because
the body is missing the relation wrapper. This bug can sit in
production for months — it only surfaces when someone actually calls
`POST /deals` from the frontend.

**Fix**: Cast the data to `Prisma.<Model>UncheckedCreateInput` explicitly
when you're sending a flat-FK payload (typical for API request bodies
designed to be JSON-friendly):

```typescript
import { Prisma } from '@crm/db';

const created = await prisma.deal.create({
  data: {
    title: incoming.title,
    companyId: incoming.companyId,
    stageId: incoming.stageId,
    pipelineId,
    ownerId,
    value: new Prisma.Decimal(Number(incoming.value)),
  } as Prisma.DealUncheckedCreateInput,  // ← cast is REQUIRED
});
```

**Or** send the nested connect shape (when you're in code, not JSON):

```typescript
const created = await prisma.deal.create({
  data: {
    title: 'X',
    company: { connect: { id: companyId } },
    stage: { connect: { id: stageId } },
    pipeline: { connect: { id: pipelineId } },
    owner: { connect: { id: ownerId } },
  },  // ← no cast, fully checked
});
```

**Detection signal**: grep for `data: body as never` or `data: req.body as never`
in `apps/api/src/routes/*.ts` — every match is a latent P1. Replace
with `as Prisma.<Model>UncheckedCreateInput` AND add a `t.Object({...})`
body schema at the Elysia route level so the flat shape is
validated at the boundary, not at the Prisma layer.

## Pitfall 2 — Adding a 2nd+ relation to a model that already has explicit named relations (crm-system 2026-06-07)

**Symptom** (in `prisma generate` output, NOT at runtime):

```
error: Error validating field `systemConfigUpdates` in model `User`:
The relation field `systemConfigUpdates` on model `User` is missing an
opposite relation field on the model `SystemConfig`. Either run
`prisma format` or add it manually.
  -->  prisma/schema.prisma:58

error: Error validating field `updatedBy` in model `SystemConfig`:
The relation field `updatedBy` on model `SystemConfig` is missing an
opposite relation field on the model `User`.
  -->  prisma/schema.prisma:880

Validation Error Count: 2
```

**Trap**: The error says "missing opposite relation" — but you DID add it on both sides. The error message is misleading: the issue is that **the new relation on `User` was added WITHOUT a named `@relation("X")` argument**, while the existing `aiConfigUpdates` relation on the same `User` model IS named `@relation("AiConfigUpdater")`. Once a model has ANY explicit named relation, ALL its relation fields (new and old) must use named relations consistently.

**Schema that FAILS:**

```prisma
// User — already has one named relation
model User {
  // ...
  aiConfigUpdates AiConfig[] @relation("AiConfigUpdater")  // ← named
  systemConfigUpdates SystemConfig[] @relation("SystemConfigUpdater")  // ← named ✓ on this side
}

model SystemConfig {
  // ...
  updatedBy User? @relation(fields: [updatedById], references: [id])  // ← NO name → mismatch
  //                ^^^^^^^^^^ ERROR: must match the name on User side
}
```

**Schema that PASSES:**

```prisma
model User {
  aiConfigUpdates     AiConfig[]     @relation("AiConfigUpdater")
  systemConfigUpdates SystemConfig[] @relation("SystemConfigUpdater")
}

model SystemConfig {
  updatedBy User? @relation("SystemConfigUpdater", fields: [updatedById], references: [id])
  //               ^^^^^^^^^^^^^^^^^^^^^^^^ name matches
}
```

**Rule**: Once any relation field on a model uses a named `@relation("X")`, **all relation fields between those two models must use the same named pattern**. Prisma's "missing opposite relation" error message is a lie when you actually have the opposite — it's complaining about the name mismatch.

**Why this happens in practice** (crm-system 2026-06-07): I added `systemConfigUpdates SystemConfig[] @relation("SystemConfigUpdater")` on `User` (named), but on the `SystemConfig` side I wrote just `@relation(fields: [updatedById], references: [id])` (no name). Prisma treats the named and unnamed as different relations and reports both as "missing the opposite".

**Detection signal**: Whenever you add a new relation to a model that already has explicit named relations, audit BOTH sides for matching `@relation("X")` names.

**Fix recipe**:

```bash
# 1. Find all existing named relations on the model
rg "@relation\(\"" packages/db/prisma/schema.prisma -n | head -20

# 2. For each new relation, add the matching name on BOTH sides
#    User side:        @relation("MyRelationName")
#    Target side:      @relation("MyRelationName", fields: [...], references: [...])

# 3. Re-run
cd packages/db && bunx prisma generate
```

**Production impact if not fixed**: `prisma generate` fails → `prisma.systemConfig` is not in generated client → runtime hits to `/api/settings/tax` 500 with "Cannot read property of undefined" → silent 5xx for every user → `logEvent` doesn't fire → no observability that this is broken.

## Root Cause Pattern (runtime)

When Prisma schema uses **explicit `@relation` names** (e.g., `@relation("UnitsRelation")`), the generated client requires **explicit relation connect syntax**, not shorthand:

```typescript
// WRONG — fails with explicit @relation
data: { unitId, batchId: batch.id }

// CORRECT — explicit connect required
data: {
  unit: { connect: { id: unitId } },
  batch: { connect: { id: batch.id } },  // or omit if genuinely null
}
```

When `@relation` is **implicit** (no name), shorthand `fieldId` often works.

## Diagnostic Steps

1. **Find the field type in schema.prisma:**
   ```
   unit ProductUnit @relation("UnitsRelation", fields: [unitId], references: [id])
   ```
   This is a RELATION field, not scalar. Must use nested connect.

2. **Search all create/update calls for that field:**
   ```bash
   rg "unitId" src/plugins/
   rg "batchId" src/plugins/
   ```

3. **Every relation field must use `{ connect: { id } }`:**
   ```typescript
   // Relation field in schema → must be:
   unit: { connect: { id: unitId } }

   // Scalar field (no @relation) → can be:
   unitId  // or just unitId: value
   ```

## Common Relation → Fix Pairs

| Schema Definition | Correct Code |
|---|---|
| `unit ProductUnit @relation(...)` | `unit: { connect: { id: unitId } }` |
| `batch Batch @relation(...)` | `batch: { connect: { id: batchId } }` or remove |
| `product Product @relation(...)` | `product: { connect: { id: productId } }` |
| `store Store @relation(...)` | `store: { connect: { id: storeId } }` |

## Auto-Fix Patterns

```typescript
// Pattern: field is relation but code uses shorthand
// Replace:
unitId,
// With:
unit: { connect: { id: unitId } },

// Replace:
batchId: batch.id,
// With:
batch: { connect: { id: batch.id } },

// For optional batch that may be null, just remove the line:
// batchId: batch?.id ?? null,  ← delete this line
```

## Verification

After fixing, restart backend and run QA. All relation errors will resolve.

## Lemontree POS Case (2026-05)

Full list of fixes applied:
- `sale.ts:391` — SaleOrderItem.unit: shorthand → explicit connect
- `sale.ts:173,231` — InventoryLog.batch: shorthand → explicit connect
- `purchase.ts:106` — PurchaseOrderItem.unit: shorthand → explicit connect
- `purchase.ts:206` — StocktakeItem.unit: shorthand → explicit connect
- `purchase.ts:305` — InventoryLog.batchId: removed (null is valid for stocktake)

## crm-system Case (2026-06-07) — named relation on multi-relation model

Adding `SystemConfig.updatedBy` relation to `User` (which already had `aiConfigUpdates AiConfig[] @relation("AiConfigUpdater")`):
- **Schema error**: `prisma generate` reports "missing opposite relation" on BOTH sides
- **Real issue**: User side had `@relation("SystemConfigUpdater")` (named), SystemConfig side had bare `@relation` (unnamed)
- **Fix**: add `"SystemConfigUpdater"` name to SystemConfig side
- **Lesson**: when extending a model that already uses named relations, audit BOTH sides of the new relation for matching names; don't trust Prisma's "missing opposite" message — it can be a name mismatch, not an absent field.
