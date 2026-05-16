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

## 5. `@elysiajs/jwt` — `jwt.sign()` and `jwt.verify()`, Not `jwt(payload)`

**Error**: `jwt is not a function. (In 'jwt({ id: "admin-1" })', 'jwt' is an instance of Object)`

**Cause**: `@elysiajs/jwt` exports a plugin function that decorates Elysia with `jwt.sign()` and `jwt.verify()` methods — it is NOT a callable function that returns a token directly.

**Solution**: Use the decorated `jwt` object's methods in route handlers:

```typescript
import { Elysia } from 'elysia'
import { jwt } from '@elysiajs/jwt'

const app = new Elysia()
  .use(jwt({
    secret: process.env.JWT_SECRET || 'dev-secret',
    exp: 60 * 60 * 24, // 24 hours
  }))
  .post('/auth/login', async ({ body, jwt }) => {
    const { username, password } = body as { username: string; password: string }

    if (username === 'admin' && password === 'correct-password') {
      // ✅ Use jwt.sign() — jwt is an object with sign/verify, not a function
      const token = await jwt.sign({ id: 'admin-1', username })
      return { token }
    }
    return { error: 'Invalid credentials' }
  })
  .get('/auth/me', async ({ request, jwt }) => {
    const authHeader = request.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return { error: 'Unauthorized' }
    }
    const token = authHeader.slice(7)
    try {
      // ✅ Use jwt.verify() to decode the token
      const payload = await jwt.verify(token)
      return { id: payload.id, username: payload.username }
    } catch {
      return { error: 'Invalid token' }
    }
  })
```

**Common mistake**: Calling `jwt(payload)` like a function — this fails because `jwt` is an object instance, not a callable function.

## 7. `.derive()` with Broken Auth Middleware Causes Intermittent 500 Errors

**Symptom**: Some requests return `500` with `{"success":false,"message":"伺服器錯誤"}`, then subsequent requests succeed. Error log shows nothing in Bun's output.

**Cause**: A `.derive()` hook that calls an `authMiddleware` function which:
1. Imports types from a shared `types.ts` that has a broken import path
2. Tries to extract JWT from `request.headers` in the derive context (where JWT hasn't been decoded yet)
3. Or references middleware code that throws silently

**Diagnosis**: Remove `.derive(({ request }) => ({ user: authMiddleware(request) }))` entirely. If the 500s stop, the derive is the culprit.

**Solution**: Do NOT use `.derive()` for JWT auth. Verify tokens inside individual route handlers instead:

```typescript
// ❌ Bad — derive in index.ts, auth middleware imported from separate file
import { authMiddleware } from './middleware/auth'
app.derive(({ request }) => ({
  user: authMiddleware(request),  // Can throw or return bad data silently
}))

// ✅ Good — verify JWT inside each route handler that needs it
app.get('/auth/me', async ({ request, jwt }) => {
  const authHeader = request.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return { error: 'Unauthorized' }
  }
  const token = authHeader.slice(7)
  try {
    const payload = await jwt.verify(token)
    return { id: payload.id, username: payload.username }
  } catch {
    return { error: 'Invalid token' }
  }
})
```

If you need shared auth logic, put it in a route-level guard or helper function called from inside handlers — NOT in `.derive()`. Keep derive lightweight (e.g., only for parsing request-local data that doesn't depend on JWT decoding).

## 8. Elysia.js + nginx Proxy — Intermittent HTTP 500 (40-60% Failure Rate)

**Symptom**: Backend API (Elysia/Bun) works perfectly via `curl http://localhost:3001/api/status` (100% 200), but through nginx reverse proxy (`https://domain.com/api/status`) returns HTTP 500 on ~40-60% of requests. No errors in Bun's console. No entries in nginx error.log for the domain.

**Root Cause**: Elysia.js (Bun's HTTP framework) uses HTTP/1.1 keepalive connections by default. When nginx proxies to the backend with `proxy_http_version 1.1` (nginx default), Bun holds connections open for reuse. Under high-frequency polling (2-3s intervals from frontend), nginx's upstream connection pool gets confused — sometimes the response from a previous request bleeds into the current one, causing Elysia to throw or nginx to detect a malformed response and return 500.

**Diagnosis**:
1. `curl http://localhost:3001/api/status` → always 200 ✅
2. `curl https://domain.com/api/status` → ~50% 500 ❌
3. Bun console shows no errors even when 500s occur
4. nginx error.log has no entries for the failing domain

**What DOESN'T fix it** (trial-and-error findings):
- `proxy_http_version 1.0` on nginx side alone
- `proxy_buffering off`, `proxy_cache off`
- `chunked_transfer_encoding on`, `tcp_nodelay on`
- Various `proxy_connect_timeout`, `proxy_send_timeout`, `proxy_read_timeout` values
- `proxy_next_upstream error timeout invalid_header http_500`
- Adding/removing specific `proxy_set_header` lines
- Upstream block with `keepalive 0`

**Solution**: Replace Elysia with plain Node.js `http` module. Bun's `http` module does NOT have the same keepalive issues:

```typescript
// ❌ Elysia.js — intermittent 500s through nginx proxy
import { Elysia } from 'elysia'
const app = new Elysia()
app.get('/api/status', () => ({ ok: true }))
app.listen(3001)

// ✅ Plain Node.js http — 100% success through nginx
import http from 'http'
const server = http.createServer((req, res) => {
  if (req.url === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ ok: true }))
    return
  }
  res.writeHead(404)
  res.end()
})
server.listen(3001)
```

**Why this works**: Plain `http` module in Bun closes each connection immediately after the response (`Connection: close` behavior), whereas Elysia reuses connections via HTTP/1.1 keepalive. Nginx's upstream handling handles stateless, short-lived connections more reliably than persistent keepalive connections to Elysia.

**When to use this**: If you need a simple status API behind nginx and reliability > framework features, use plain `http`. If you need Elysia's features (typed routes, schemas, plugins), ensure your nginx config uses `proxy_http_version 1.0` AND `proxy_set_header Connection "close"` — though even this may not be 100% reliable under high polling load.

## 6. Schema Validation — Use `schema` Object or Import `t`, Not Both

**Error**: `ReferenceError: t is not defined` or `t is not a constructor`

**Cause**: In Elysia v1.x, the route handler's second argument uses `.schema` for validation, not inline `t.Object()` destructuring. The `t` type must be imported from `elysia`, not used inline in the route definition.

**Solution**: Choose one approach — prefer `schema` object for clarity:

```typescript
import { Elysia } from 'elysia' // ✅ t NOT imported unless needed elsewhere

export const authRoutes = new Elysia()
  .post('/auth/login', async ({ body, jwt }) => {
    const { username, password } = body as { username: string; password: string }
    // ... handler logic
  }, {
    // ✅ Use schema object for body validation
    schema: {
      body: {
        type: 'object',
        properties: {
          username: { type: 'string' },
          password: { type: 'string' }
        },
        required: ['username', 'password']
      }
    }
  })
```

## 10. Wildcard Path Parameters (`/:key(*)`) Fail Validation — Use Query String

**Symptom**: Route `GET /api/files/:key(*)` with `params: t.Object({ key: t.String({ pattern: ".*" }) })` returns HTTP 422 with validation error:

```json
{
  "type": "validation",
  "on": "params",
  "property": "/key",
  "message": "Expected required property",
  "errors": [{ "type": 45, "path": "/key", "message": "Property 'key' is missing" }]
}
```

**Cause**: Elysia's t.String pattern validator does not work correctly with wildcard path parameters (`*:greedy`). The `.*` regex pattern applied to a required `t.String()` param causes the schema validator to misbehave — it treats the value as missing entirely.

**Solution**: Replace path parameter with query string:

```typescript
// ❌ Bad — wildcard path param with t.String({ pattern: ".*" })
.get("/files/:key(*)", async ({ params }) => {
  const key = decodeURIComponent(params.key)
  // ...
}, {
  params: t.Object({ key: t.String({ pattern: ".*" }) }),
})

// ✅ Good — query string instead of path parameter
.get("/files", async ({ query }) => {
  const key = decodeURIComponent(query.key)
  if (!key) return { error: "Missing key parameter" }
  // ...
}, {
  query: t.Object({ key: t.String() }),
})
```

**Frontend download URL changes from**:
```typescript
// ❌
href={`/api/files/${encodeURIComponent(att.url)}`}

// ✅
href={`/api/files?key=${encodeURIComponent(att.url)}`}
```

**When file key contains slashes** (e.g., S3 object key `attachments/file.pdf`), the path approach breaks because `/` is a path separator — query string cleanly handles any character. This pattern also arises when serving files from S3 private buckets where the backend generates a signed download URL.

## 11. `Optional(t.String())` Does NOT Accept `null` — Only `undefined`

**Symptom**: HTTP 422 Unprocessable Entity when sending `{"videoUrl": null}` from frontend, even though `videoUrl: t.Optional(t.String())` is defined in the route schema.

**Error from Elysia validation**:
```json
{
  "errors": [{
    "type": 54,
    "path": "/videoUrl",
    "value": null,
    "message": "Expected string"
  }]
}
```

**Cause**: Elysia's `t.Optional(t.String())` schema means "property may be absent from the object entirely (`undefined`)" — it does NOT mean "property may be present with value `null`". When the JSON contains `{"videoUrl": null}`, the key IS present (just with `null` value), so validation fails because `null` is not a string.

**Frontend fix** — conditionally add optional fields only when they have a truthy value:

```typescript
// ❌ Bad — sends "videoUrl": null even when empty, causes 422
const payload = {
  title: activeLesson.title,
  videoUrl: activeLesson.videoUrl || null,  // always present
  attachments: activeLesson.attachments || '[]',
}

// ✅ Good — only include field when it has a value
const payload: Record<string, unknown> = {
  title: activeLesson.title,
  attachments: activeLesson.attachments || '[]',
}
if (activeLesson.videoUrl) {
  payload.videoUrl = activeLesson.videoUrl
}
// Now if videoUrl is empty/falsy, the key is simply absent from the JSON
```

**Backend fix** — if you genuinely need to accept both `null` and absent, use a custom schema:

```typescript
// Accept string OR null explicitly
const videoUrlSchema = t.Union([t.String(), t.Null()])

// Or in body schema:
body: t.Object({
  title: t.String(),
  videoUrl: t.Optional(t.Union([t.String(), t.Null()])),  // accepts null or absent
})
```

**Key insight**: In Elysia's typed schema, `Optional(t.String())` ≠ "nullable". It means "omit the key entirely". `null` in JSON is a value, not absence — so it fails validation.

## Key Files (Lemontree V3)

- `~/projects/lemontree_v3/src/middleware/auth.ts` — derive middleware adding `websiteId` to context
- `~/projects/lemontree_v3/src/routes/core/menu.ts` — complete example of all patterns
- `~/projects/lemontree_v3/src/routes/core/permission.ts` — `t.Recursive` workaround example
