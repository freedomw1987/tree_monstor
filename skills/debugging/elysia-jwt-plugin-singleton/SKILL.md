---
name: elysia-jwt-plugin-singleton
description: Fix "401 Unauthorized" in Elysia.js when JWT tokens signed by auth routes are rejected by protected routes — caused by multiple JWT plugin instances.
version: 1.0.0
author: Hermes Agent
tags: [debugging, elysia, jwt, bun, auth]
metadata:
  hermes:
    tags: [debugging, elysia, jwt, auth, bun]
    related_skills: [elysia-route-conflict-debug, elysia-typescript-workarounds, systematic-debugging]
---

# Elysia.js JWT Plugin Singleton Bug

## Symptom

Login works (auth route returns a JWT token), but subsequent requests to protected routes fail with **401 Unauthorized**, even with a valid token. The token was just signed — it shouldn't be expired or invalid.

**Classic pattern:**
- `routes/auth.ts` signs tokens with its own `jwt()` instance → success
- `routes/courses.ts` (and other protected routes) verify tokens with a DIFFERENT `jwt()` instance → 401

## Root Cause

In Elysia.js, **each `app.use(jwt(...))` call creates a NEW plugin instance**, even if the options are identical. Instances do NOT share state. A token signed by instance A's `.sign()` method cannot be verified by instance B's `.verify()` — they have different internal keys derived from the same secret.

```
app.use(jwt({ secret: "same-secret" }))  // Instance A
app.use(jwt({ secret: "same-secret" }))  // Instance B — DIFFERENT instance!

token = A.sign({ sub: "1" })   // Signed by A
ctx.jwt.verify(token)          // Verified by B — FAILS silently → 401
```

## Diagnosis

1. Search for multiple `jwt(` calls across your codebase:
```bash
grep -rn "jwt(" src/
```

2. Look for patterns where auth.ts creates its own JWT while other route files also create their own:
```ts
// In routes/auth.ts — BAD pattern
const jwt = new Elysia()
  .use(jwt({ secret: process.env.JWT_SECRET, ... }))
  .resolve(...)
```
```ts
// In routes/courses.ts — ANOTHER BAD pattern (different instance!)
const auth = new Elysia()
  .use(jwt({ secret: process.env.JWT_SECRET, ... }))
```

3. If you see `jwt()` called in more than one file, you have the bug.

## Fix: Shared Singleton Plugin

**Step 1:** Create a single JWT plugin in `src/middleware/auth.ts`:

```ts
import { Elysia, jwt } from "elysia";
import { ELYSIA_JWT_SECRET } from "../config";

export const jwtPlugin = jwt({
  secret: ELYSIA_JWT_SECRET,
  // other options: expiresIn, etc.
});

// Auth middleware: verifies token AND sets ctx.user
export const auth = new Elysia()
  .use(jwtPlugin)
  .derive(({ jwt, headers }) => {
    const authHeader = headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) return { user: undefined };
    return jwt.verify(authHeader.slice(7)).then(user => ({ user }));
  });
```

**Step 2:** In `routes/auth.ts` — use `jwtPlugin` to sign, use `auth` to guard:

```ts
import { Elysia } from "elysia";
import { auth, jwtPlugin } from "../middleware/auth";

export const authRoutes = new Elysia({ prefix: "/auth" })
  .use(auth)                          // ← verifies tokens via shared jwtPlugin
  .post("/login", async ({ jwt, set, body }) => {
    // Sign with the SAME jwtPlugin instance
    const token = await jwt.sign({ sub: user.id, role: user.role, email: user.email });
    return { success: true, token, user: { id, name, email, role, mustChangePassword } };
  }, ...)
  .post("/change-password", async ({ jwt, user, set, body }) => {
    // jwt from context IS the shared jwtPlugin's sign function
    const newToken = await jwt.sign({ ...updatedPayload });
    return { success: true, token: newToken };
  }, ...)
```

**Step 3:** In protected route files — import and use the SAME `auth`:

```ts
import { auth } from "../middleware/auth";

export const courseRoutes = new Elysia({ prefix: "/api/courses" })
  .use(auth)                          // ← same jwtPlugin, same verification
  .get("/", async ({ user }) => {
    // user is set by auth.derive() — works because jwt is the SAME instance
    return db.courses.findMany();
  }, ...)
```

**Key invariant:** `jwtPlugin` is created ONCE in `middleware/auth.ts` and imported everywhere. Both signing (`jwt.sign()`) and verifying (`auth` middleware) use the identical instance.

## Gotcha: Getting `jwt` from Context in Handlers

When you call `.use(auth)`, the `ctx.jwt` is the `jwtPlugin` instance's sign function. Use it like this:

```ts
.post("/change-password", async ({ jwt, set, body }) => {
  // ctx.jwt === jwtPlugin.sign()
  const newToken = await jwt.sign({ sub: user.id, ... });
  return { token: newToken };
})
```

Do NOT destructure `jwt` from `auth` directly in the handler signature — it's only available via `ctx.jwt` after `.use(auth)` runs.

## Stale Server / Old Process Masking the Fix

If you fixed the code but still get 401:
1. Multiple Bun processes may be running on different ports
2. The old process with the bug still serves traffic
3. Always verify which PID is actually serving:

```bash
lsof -i :3000
ps aux | grep bun
```

Kill ALL bun processes and restart clean:
```bash
pkill -f "bun.*index"
sleep 1
lsof -i :3000  # should be empty
cd ~/projects/umac_ai/backend && bun run src/index.ts
```

## Verification Test

```bash
# 1. Login → get token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"teacher@umac.ai","password":"Teacher@123"}' \
  | jq -r '.token')

# 2. Use token on a protected route
curl -s http://localhost:3000/api/courses \
  -H "Authorization: Bearer $TOKEN"

# Should return 200 with course data, NOT 401
```

## Related
- `elysia-route-conflict-debug`: route parameter name conflicts
- `elysia-typescript-workarounds`: TypeScript issues with Elysia
- `systematic-debugging`: general debugging methodology

---

## ⚠️ Day 9: Different 401 — `.derive()` silently returns undefined on POST

The singleton bug above is one source of 401s. There is a SECOND Elysia 1.2
401 trap that looks identical from the outside (`userId: undefined`,
handler responds 401) but has a totally different root cause: **`derive`
hooks are not run for POST handlers when a sibling `.get()` route is also
registered on the same Elysia instance and uses a body schema.** Elysia
caches the validator and skips re-evaluating the `derive` chain on POST
even though `userId` is destructured in the handler signature.

**Symptom** (Day 9, crm-system):
- `GET /auth/me` and `GET /quotations` (no body) → 200 OK
- `POST /quotations` → 401 "Unauthorized" even with a valid bearer token
- `console.log` inside the `derive` callback never fires on POST
- Other routes' `POST` handlers return 500/401 depending on whether they
  gate on `if (!userId) return 401`

**Root cause**: Elysia 1.2's `derive` cache. When a route previously
validated with a body schema (the `.get('/')` sibling), the validator
re-uses the cached `derive` result for the chain's POST children. The
`async derive` is never re-evaluated. The destructure `userId` works
in TypeScript (the type is set) but at runtime it's `undefined`.

**Fix (recommended — bulletproof)**: drop `derive` for auth entirely
and inline-verify inside each protected handler. Costs one extra
`await jwt.verify(token)` per request but bypasses the cache.

```ts
// lib/context.ts
import { Elysia } from 'elysia';
export const authContext = new Elysia({ name: 'auth-context' });

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

```ts
// In each protected route handler
.post('/', async ({ body, jwt, set, request }) => {
  const userId = await getUserIdFromRequest(request, jwt);
  if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
  // ... rest of handler
})
```

**How to detect** (5-min diagnostic):
1. `console.log` inside your `derive` callback
2. Hit any POST → log never appears
3. `userId` in the handler is `undefined` despite a valid token
4. GET routes on the same instance work fine

If you see this pattern, you have the derive-cache bug — switch to
`getUserIdFromRequest` inline verification.

---

## ⚠️ 2026-06-07: Same symptom, slightly different trigger — POST handler chained after `.use(requirePermission(...))`

The Day 9 case above triggers when a POST handler sits next to a
sibling `.get()` route. There is a SECOND configuration that produces
the identical `userId: undefined` symptom but has a different
trigger: **the route is `.use(requirePermission(...))` followed by
`.post('/...', handler, { body: t.Object({...}) })`** where the
schema-validated body somehow narrows the context such that
`authContext`'s derived `userId` is no longer visible in the handler
destructure.

**Symptom** (crm-system 2026-06-07 `POST /deals`):
- `GET /deals`, `GET /deals/kanban`, `GET /deals/:id` → 200 OK (userId present)
- `POST /deals` with body schema → handler sees `userId: undefined`
  even though `requirePermission('deal:create')` already proved the
  user is authenticated
- `logEvent({ actorId: userId ?? null })` writes `actorId: null` in
  the audit log row even though the create succeeded
- The same exact pattern (`requirePermission` + `body: t.Object({...})`)
  on `PATCH /deals/:id/stage` and `PATCH /deals/:id` works fine on
  its own — so this is an intermittent/context-dependent bug, not a
  deterministic one

**Detection signal**: any handler that does ALL of:
1. Is declared on a route that calls `.use(requirePermission(...))`
2. Defines a `body: t.Object({...})` schema
3. Destructures `userId` from the handler arg
4. Sees `userId === undefined` despite an authenticated request

**Workaround** (crm-system's adopted fix, see
`apps/api/src/routes/deal.ts` POST handler):

```ts
import { getUserIdFromRequest } from '../middleware/rbac';

.post('/', async ({ body, set, userId, request }) => {
  // Try the (possibly missing) derived userId, then fall back to
  // re-decoding the JWT from the request headers. Same helper RBAC
  // uses internally, so the result is identical to a working derive.
  const ownerId = incoming.ownerId ?? userId ?? await getUserIdFromRequest(request);
  // ... rest of handler
}, {
  body: t.Object({ ... }),
})
```

Apply the same fallback in `logEvent({ actorId: userId ?? await
getUserIdFromRequest(request) ?? null })` so audit rows carry the
real user.

**Root cause** (workaround, not yet root-caused): Elysia 1.2's
typed-context schema for `body: t.Object({...})` appears to drop the
`userId` field from the `Context` type passed into the handler.
TypeScript stays silent because the destructure is allowed, but at
runtime the value is `undefined`. The crm-system repo has not yet
upgraded to Elysia 1.3+ where this is reportedly fixed. Until then,
**always use the `getUserIdFromRequest(request)` fallback** in any
`body: t.Object({...})` route that needs the calling user's id.

**Rule of thumb for crm-system Elysia 1.2 routes**:
- `body: t.Object({...})` route that needs `userId` → always include
  `?? await getUserIdFromRequest(request)` fallback
- `body: t.Object({...})` route that needs `actorId` for `logEvent` →
  same fallback
- `logEvent({ actorId: userId ?? null })` is suspect — verify the
  `userId` is actually populated before relying on it for audit
