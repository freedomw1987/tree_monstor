---
version: alpha
name: prisma-relation-debugging
description: "Debug Prisma schema vs code mismatches: explicit @relation fields need { connect: { id } } syntax, not shorthand"
---

# Prisma Explicit Relation — Schema/Code Mismatch Debugging

## Trigger

Any Prisma error involving:
- `Unknown argument 'X'` on a model create/update
- `Argument 'X' is missing` on a model create/update
- `Error: Invalid `X` invocation` on relation fields
- A field defined as a relation in schema but code uses it as a scalar (or vice versa)

## Root Cause Pattern

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
