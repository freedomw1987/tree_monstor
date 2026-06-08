# Elysia 1.2 plugin-boundary derive context — reproduction recipe

## Symptoms (match all of these)

1. All `requirePermission`-protected routes return **401 Unauthorized** even with a valid token
2. Unprotected routes (e.g. `GET /api/products`) work fine
3. Bun API logs show **no error** — the middleware silently returns `null` for userId
4. After adding a `console.error('[rbac] no auth header')` debug line: that line fires, but
   even with a valid `Authorization: Bearer <token>` header, `getUserIdFromRequest` still
   returns null further down
5. The handler that does `({ userId, set })` in **the same plugin** (e.g. the routes that
   use `use(authContext)` directly) **does** see `userId` correctly — only the
   `requirePermission` plugin sees null

## Root cause

In Elysia 1.2, when you define a plugin with `.onBeforeHandle({ as: 'scoped' })`, the
`ctx` argument you receive is **scoped to the plugin's own state** and does **not**
include values derived by other plugins (like the JWT plugin's `userId` via
`derive( async ({ jwt, request }) => ({ userId: await verify(jwt, request) }))`).

The Elysia 1.2 d.ts *types* `ctx.userId` as available (because the union of all
derives is in the global MacroContext), but at runtime the cross-plugin propagation
doesn't actually happen for scoped hooks.

This is a **different bug** from the `elysia-jwt-plugin-singleton` issue (which is
about accidentally creating two JWT instances with different secrets and getting
"Bad JWT issued by different instance" errors). Here, the same JWT instance is
used everywhere, but the derive value is lost across the plugin boundary.

## Reproduction (minimal)

```typescript
// apps/api/src/lib/context.ts
import { Elysia } from 'elysia';
export const authContext = new Elysia({ name: 'auth-ctx' })
  .derive(async ({ request }) => {
    const auth = request.headers.get('authorization');
    if (!auth?.startsWith('Bearer ')) return { userId: null as string | null };
    // ... verify JWT, return { userId: 'abc123' }
    return { userId: 'abc123' };
  });

// apps/api/src/middleware/rbac.ts
export const requirePermission = (perm: string) =>
  new Elysia({ name: `perm-${perm}` })
    .onBeforeHandle(async ({ userId, set }) => {
      // userId is ALWAYS undefined here, even though
      // authContext.derive just set it to 'abc123'
      if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
      // ...
    });

// apps/api/src/index.ts
app
  .use(authContext)                 // sets userId via derive
  .use(requirePermission('user:read'))   // can't see userId
  .get('/protected', async ({ userId }) => {
    // userId IS 'abc123' here — because we're a route handler
    // in the same scope as the derive, not in a plugin's onBeforeHandle
    return { userId };
  });
```

## Fix

Re-verify the JWT inside the middleware itself by reading the raw `Request` headers.
Don't rely on the upstream derive.

```typescript
import { jwtVerify } from 'jose';

async function getUserIdFromRequest(request: Request): Promise<string | null> {
  const auth = request.headers.get('authorization');
  if (!auth?.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret) return null;
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret));
    if (!payload || typeof payload !== 'object') return null;
    return (payload as { userId?: string; sub?: string }).userId
      ?? (payload as { sub?: string }).sub
      ?? null;
  } catch {
    return null;
  }
}

export const requirePermission = (perm: string) =>
  new Elysia({ name: `perm-${perm}` })
    .onBeforeHandle(async ({ request, set }) => {
      const userId = await getUserIdFromRequest(request);
      if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
      if (!(await userHasPermission(userId, perm))) {
        set.status = 403;
        return { error: `Forbidden: missing permission '${perm}'` };
      }
    });
```

## Why `jose` directly?

`@elysiajs/jwt`'s `jwt()` factory returns an Elysia plugin instance whose
`.verify()` method is only available as a context decorator inside Elysia
handlers. Calling it standalone gives:

```
jwtPlugin({ name: "rbac-verify", secret }).verify is not a function
```

`jose` is the underlying JWT library and ships a clean `jwtVerify(token, key)`
function. It's already a transitive dep of `@elysiajs/jwt` so no new install
needed.

## Trace log from crm-system Day 7 (2026-06-05)

```
1 | export * from './permissions';
2 | export const ALL_PERMISSIONS: readonly string[] = Object.freeze(
3 |   Object.values(PERMISSIONS).flatMap((group) => Object.values(group))
                               ^
ReferenceError: PERMISSIONS is not defined
      at /app/packages/shared/src/index.ts:3:28
      at loadAndEvaluateModule (2:1)

Bun v1.2.23 (Linux arm64)
==> [entrypoint] Running database migrations...
```

After fix:

```
🦊 CRM API running at 0.0.0.0:3001
   CORS: http://localhost:5173
   Health: http://0.0.0.0:3001/health
API: 200
```

All protected routes 200 after switching to jose-direct verify.

## When this matters

- Every project using Elysia 1.2 with a separate `requirePermission` (or similar)
  plugin that needs to see `userId` from the auth derive
- Doesn't matter if all your route handlers are in the same plugin scope as the
  auth derive (then `ctx.userId` works)
- Will be **fixed in Elysia 1.3** (per the Elysia changelog) when derive
  propagation is unified across scoped hooks
