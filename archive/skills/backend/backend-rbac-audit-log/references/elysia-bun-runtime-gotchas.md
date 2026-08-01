# Elysia 1.2 + Bun runtime gotchas (crm-system Day 5 / Day 7 / Day 14)

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body (Steps 9, 10, 11 and the d.ts-noise
> / `request`-parameter pitfalls). These gotchas are framework-specific
> (Elysia 1.2 + Bun) but project-agnostic — useful to any Elysia 1.2
> codebase doing RBAC + audit. They were originally fragmented across
> Steps 1-11 of the skill; consolidated here for one-stop reference.

## 1. Elysia d.ts noise (the >100 type errors)

用 `requirePermission` + `authContext` chain 會 trigger Elysia 1.2 MacroContext d.ts 嘅 >100 個 type errors(known issue, `bun run` runtime 唔 care)。Dockerfile API stage 用 `bun run src/index.ts` 唔行 `tsc --noEmit` 就 OK。詳見 `elysia-typescript-workarounds` skill #12。

## 2. `authContext` derive userId 唔跨 module 自動 type-infer

喺 handler 入面 `({ userId, ... })` 解構後,TypeScript 會 complain `userId does not exist on type ...`。用 `as` cast 處理:

```typescript
async ({ params, body, userId, set }) => {
  const ctx = { params, body, userId, set } as typeof arguments[0] & { userId: string | null; params: { id: string } };
  // ...
}
```

詳見 `elysia-typescript-workarounds` #15。

## 3. `request` parameter on Elysia handlers

Elysia auto-injects `request` (the standard `Request` object) into every handler — just destructure it. **But** TypeScript won't know about it without a cast. Pragmatic fix: just write `async ({ ..., userId, request }) => { ... }` and ignore the LSP squiggle. Bun runtime is happy.

## 4. Bun `export *` + same-file const reference

In a barrel file like `packages/shared/src/index.ts`:

```typescript
// ❌ BREAKS at runtime with: ReferenceError: PERMISSIONS is not defined
export * from './permissions';
export const ALL_PERMISSIONS = Object.values(PERMISSIONS).flatMap(...);
```

**Why**: when `permissions.ts` is re-exported via `export *`, the symbol `PERMISSIONS` exists in the module's namespace but is **not directly referenceable by name** in the same file's scope. Bun's CJS/ESM interop at the moment of evaluation may execute the file's top-level statements in an order that hits the `Object.values(PERMISSIONS)` call before the re-export has been bound. TypeScript sees no error, but runtime throws.

**Fix**: explicitly import + re-export:

```typescript
// ✅ WORKS
import { PERMISSIONS } from './permissions';
export * from './permissions';
export const ALL_PERMISSIONS = Object.freeze(Object.keys(PERMISSIONS));
```

**Symptom signature**:
- Bun runtime: `ReferenceError: PERMISSIONS is not defined` at module top
- TypeScript + Node: usually works fine
- This is Bun-specific behaviour — keep the pattern in mind whenever a barrel file uses a re-exported const in another export

## 5. `@elysiajs/jwt` standalone `.verify` is not a function

`@elysiajs/jwt` is built on top of `jose`, but the way to use it cross-plugin is:

```typescript
import { jwt } from '@elysiajs/jwt';
const verifier = jwt({ name: 'foo', secret });
const payload = await verifier.verify(token);    // ← but `verifier.verify` is not a function!
```

The `jwt()` factory returns an Elysia instance whose `verify` method is only available as a context decorator inside Elysia handlers. **You cannot call it standalone** — `verifier.verify` is undefined at runtime. Error:

```
jwtPlugin({ name: "rbac-verify", secret }).verify is not a function
```

**`jose` is already a transitive dep** of `@elysiajs/jwt` (check `node_modules/jose`), so no new install needed. Just `import { jwtVerify } from 'jose'` and you have a clean verify function.

## 6. Prisma enum + JSON polymorphism — the `as never` cast pattern

When a model has a discriminator enum (e.g. `QuotationItem.itemType: 'PRODUCT' | 'SERVICE'`) AND a JSON snapshot field (`manDaySnapshot Json?`), and the value comes from a request body that's loosely typed, you need two cast tricks:

```typescript
// In a route handler with body typed as { itemType?: string; serviceId?: string; manDaySnapshot?: unknown }
const itemType: string = body.serviceId ? 'SERVICE' : 'PRODUCT';
const item = await prisma.quotationItem.create({
  data: {
    itemType: itemType as never,                                  // ← string → ItemType enum
    productId: itemType === 'PRODUCT' ? body.productId : null,
    serviceId: itemType === 'SERVICE' ? body.serviceId : null,
    manDaySnapshot: (body.manDaySnapshot ?? undefined) as never,  // ← unknown → InputJsonValue | null
    // ...
  },
});
```

**Why `as never`**:
- `ItemType` is a Prisma string-literal enum; assigning a `string` variable directly triggers `Type 'string' is not assignable to type 'ItemType'`
- `manDaySnapshot` is `Json?` in Prisma, which maps to `InputJsonValue | NullableJsonNullValueInput` for writes; assigning `unknown` doesn't satisfy that
- `as never` is the conventional escape hatch that says "I know the runtime value is correct; the type system just can't prove it from a string variable"
- This is the same cast pattern that was used in `elysia-typescript-workarounds` for the `set.status` overload

**Audit the following when applying this pattern**:
1. The `itemType` discriminator is set correctly based on which FK is present (e.g. `data.serviceId ? 'SERVICE' : 'PRODUCT'`)
2. The opposite FK is explicitly set to `null` (not omitted), so Prisma doesn't try to write undefined and the column is unambiguous
3. The `manDaySnapshot` is `null` (not `undefined`) for non-service items — Prisma treats them differently