---
name: elysia-typescript-workarounds
description: Common TypeScript issues when building Elysia.js (Bun) APIs with typed routes — route parameter conflicts, derive context typing, t.Recursive, and inline handler patterns.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [elysia, bun, typescript, backend, api]
    related_skills: [systematic-debugging]
---

# Elysia.js TypeScript Workarounds

Common TypeScript issues encountered when building Elysia.js (Bun) APIs with typed routes, and how to resolve them.

## 1. Route Parameter Name Conflict

**Error**: `Cannot create route "/api/menus/:id" with parameter "id" because a route already exists with a different parameter name ("menuId") in the same location`

**Cause**: Elysia uses memoirist router, which does not allow different parameter names at the same path position. Using `.group('/menus/:menuId')` then later `.get('/menus/:id')` causes this conflict.

**Solution**: Do not use `.group()` with path parameters that will conflict with other routes at the same path. Define routes individually with explicit paths instead:

```typescript
// ❌ Bad — conflicts at /api/menus/:id vs /api/menus/:menuId
app.group('/menus/:menuId', (app) => app.get('/items', ...))
app.get('/menus/:id', ...)

// ✅ Good — define each route explicitly with consistent param names
app.get('/menus', ...)
app.post('/menus', ...)
app.get('/menus/:id', ...)
app.get('/menus/:id/items', ...)
app.get('/menus/:id/items/:itemId', ...)
```

## 2. `websiteId` Not Found on Context in Route Handlers

**Error**: `Property 'websiteId' does not exist on type '{ body: ...; params: ... }'`

**Cause**: `authMiddleware` uses `.derive()` to add `websiteId` to context, but Elysia's TypeScript inference does not automatically propagate derive properties into route handler types.

**Solution**: Use type assertion at the start of every route handler that needs the derived context:

```typescript
// ✅ Consistent workaround used across all route files
app.get('/resources', (context) => {
  const { websiteId } = context as typeof context & { websiteId: number }
  // ...
})

// Also needed for routes that use set.status
app.get('/resources/:id', (context) => {
  const { params, websiteId, set } = context as typeof context & { websiteId: number; params: { id: string } }
  // ...
})
```

## 3. `t.Recursive` Schema + `t.Optional(t.Array(Self))` Returns `never[]`

**Error**: `Type 'PermissionNode[]' is not assignable to type '{ children?: never[] | undefined; ... }[]'`

**Cause**: Elysia's `t.Recursive` with `t.Optional(t.Array(Self))` causes TypeScript to incorrectly infer the recursive children type as `never[]`.

**Solution**: Cast the return value and use `t.Any()` for the response schema:

```typescript
// ❌ Bad
const permissionTreeNodeSchema = t.Recursive((Self) =>
  t.Object({
    id: t.Number(),
    children: t.Optional(t.Array(Self))
  })
)
app.get('/permissions', () => ({ data: buildPermissionTree(items) }), {
  response: { 200: t.Object({ data: t.Array(permissionTreeNodeSchema) }) }
})

// ✅ Good — cast return value, use t.Any() for recursive schemas
app.get('/permissions', () => ({
  data: buildPermissionTree(items) as unknown as Array<Record<string, unknown>>
}), {
  response: { 200: t.Object({ data: t.Array(t.Any()) }) }
})
```

## 4. Handler `set.status` Is `SelectiveStatus`, Not `number`

The `set` parameter in route handlers has type `SelectiveStatus<number>` (optional, includes string literal status values), not `{ status: number }`. Direct assignment `set.status = 404` works fine because the broader `SelectiveStatus` type is assignable to the narrower form. The `context as typeof context & { ... }` pattern covers this automatically.

## Standard Route Pattern

```typescript
import { Elysia, t } from 'elysia'

app.get('/resources/:id', (context) => {
  const { params, body, websiteId, set } = context as typeof context & {
    websiteId: number
    params: { id: string }
    body: { name: string }
  }
  // ...
}, {
  params: t.Object({ id: t.Numeric() }),
  body: t.Object({ name: t.String() }),
  response: {
    200: t.Object({ ... }),
    401: errorSchema,
    404: errorSchema
  },
  detail: {
    tags: ['Resource'],
    summary: 'Get resource',
    description: '...'
  }
})
```

## Key Files (Lemontree V3)

- `~/projects/lemontree_v3/src/middleware/auth.ts` — derive middleware adding `websiteId` to context
- `~/projects/lemontree_v3/src/routes/core/menu.ts` — complete example of all patterns
- `~/projects/lemontree_v3/src/routes/core/permission.ts` — `t.Recursive` workaround example
