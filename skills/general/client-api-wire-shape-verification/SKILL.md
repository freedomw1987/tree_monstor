---
name: client-api-wire-shape-verification
description: Verify client-side API wrapper shapes (TypeScript request types, request bodies, response parsing) against the BACKEND SOURCE before committing — not against plan docs, design notes, or schema guesses. Catches field-name drift (e.g. `defaultTaxRate` vs `rate`), type drift (string vs object for nested fields), nullability drift, and the general "client wrapper written from plan doc wording but backend uses different names" class of bugs. Trigger when writing or modifying a typed API client wrapper (typed `request<T>()` call, Prisma model ↔ TS type mapping, zod schema ↔ DTO), or when "tsc passes but the endpoint 400s on the first real call".
version: 1
category: general
---

# Client API Wire-Shape Verification

## The Class of Bug

You write a typed client wrapper for a backend endpoint. TypeScript compiles
clean. The wrapper looks right. You commit it. First real call → `400 Zod
validation failed` or a missing field at runtime. The bug is **field-name or
type drift between what the client wrapper assumes and what the backend
actually returns/accepts**.

### Concrete cases (all seen in crm-system 2026-06)

| Step | Client wrapper assumed | Backend actually used | Symptom |
|------|------------------------|------------------------|---------|
| Day 14.7 Step 5 | `TaxConfig.defaultTaxRate` (Plan doc wording) | `rate` (route handler return) | `PUT /settings/tax` 400 |
| Day 9 | Frontend type `s.manDays` | Prisma relation `manDayLines` | "0 個 man-day role" silent crash |
| Day 9 | `String @default("ACTIVE")` column | typed enum `status ServiceStatus` | Prisma client emits `'X'::"EnumName"` cast → 42704 |
| (general) | `updatedBy: string` (admin id) | full user object `{id,name,email} \| null` | field accesses `.name` on undefined |

## Why It Happens

- **Plan doc is not the source of truth.** A plan doc says "default tax rate"
  and you write `defaultTaxRate`. The backend dev reads the plan and renames
  it to `rate` because that's shorter. The plan is stale by 5 minutes.
- **Schema is not the source of truth.** Prisma model says `value Json`, you
  infer the field will be `{ rate: number }`. The route handler
  wraps it as `{ rate, key, description, updatedAt, updatedBy }` before
  sending.
- **Source-of-truth rule (per David 2026-06-04)**: when a backend exists,
  the **backend source** (the route handler file, the actual
  `prisma.systemConfig.upsert({...})` return) is the truth. Plan doc,
  schema, and frontend types all derive from it.
- **TypeScript lies at the boundary.** `tsc --noEmit` validates that the
  client *calls* the function with the right shape, but it cannot validate
  that the function *returns* the shape you think it does. The wrapper is
  `request<TaxConfig>(...)` with a generic — the runtime response is opaque
  to TS.

## Verification Recipe (REQUIRED before committing any API wrapper)

For every new or modified `request<T>()` call in a typed client:

### 1. Locate the actual backend route handler

```bash
# Find the route that serves this path
rg -n "method.*['\"]/settings/tax['\"]|'/tax'" apps/api/src/routes/
```

### 2. Read the handler's return value

Look for either:
- `return { ... }` at the end of the handler
- `set.status = N; return { ... }`
- The shape passed to `reply.send(...)` if it's an Elysia-onResponse hook

### 3. For PUT/POST: read the body validator

```bash
rg -n "body: t\.|t\.Object\(" apps/api/src/routes/settings.ts
```

The validator tells you **exact** field names the backend expects. If client
sends `defaultTaxRate` and validator says `rate`, you have a 400.

### 4. Check the Prisma include/select

If the handler does `prisma.foo.findUnique({ include: { updatedBy: { select: {...} } } })`,
the response has the **selected** shape, not the full model. Common drift:
`updatedBy` is a user object, not a string id.

### 5. Cross-check nullability

The handler may return `updatedBy: null` if the row was created without an
actor (seed, migration, first-run). Mark as `T | null` not `T`.

### 6. Write the verification block in the commit

When the wrapper is non-trivial, add a comment block in `api.ts`:

```ts
// **Day 14.7 Step 5 fix (caught in Step 7)**: Backend (/api/settings/tax)
// uses `rate` (not `defaultTaxRate`) for the JSON field on BOTH the GET
// response and the PUT body. The first client wrapper I wrote in Step 5
// assumed `defaultTaxRate` based on the Plan doc wording, but per "backend
// is source of truth" (user feedback 2026-06-04) we follow the wire format
// that `prisma.systemConfig.upsert({ data: { value: rate } })` actually
// returns. See routes/settings.ts GET + PUT.
export interface TaxConfig {
  key: string;
  rate: number;
  // ...
}
```

## Diagnosis Steps (when "tsc passes but endpoint 400s")

1. **Run the actual backend** in dev mode (e.g. `bun run dev` in apps/api)
2. **Curl the endpoint** with a real auth token (use `python3 -c` to avoid
   Hermes secret-redaction shell pipeline trap — see MEMORY 2026-06-05):
   ```python
   import urllib.request, json
   req = urllib.request.Request(
       "http://localhost:3000/api/settings/tax",
       headers={"Authorization": f"Bearer {token}"},
   )
   print(json.dumps(json.loads(urllib.request.urlopen(req).read()), indent=2))
   ```
3. **Diff the JSON keys** against the TS type. Every missing/extra/null
   field is a drift.
4. **For PUT**: send the client's payload and read the Zod error message —
   it tells you exactly which field name the backend expected.

## Pitfalls

- **Don't trust the plan doc's field names.** Plans are written before the
  backend is, and field names change during implementation. Read the
  handler, not the plan.
- **Don't trust the Prisma model's JSON columns.** A Prisma `value Json`
  field can hold anything; the route handler decides what shape to send.
- **Don't trust your own `tsc --noEmit`.** TS only checks call-site
  argument shape against the generic, not runtime response shape.
- **Don't trust `as Type` casts.** If the wrapper does `as TaxConfig`, the
  runtime is still whatever the backend sent. The cast is a lie.
- **`useEffect(() => setQueryData(...))` masks wire drift**: optimistically
  setting the query cache can hide a `defaultTaxRate` ↔ `rate` mismatch for
  one round-trip before the truth comes back. Always test a full read →
  write → re-read cycle in dev.
- **Backend renames happen silently.** When the backend merges a
  `field-rename` PR, no client-side TS error fires. The next agent that
  calls the endpoint discovers it. Be the agent that discovers it BEFORE
  committing the wrapper, not the one who ships the lie.

## Verification Recipe: Automated (optional)

For endpoints you control end-to-end, add a wire-shape test that round-trips
the full request/response and asserts the TypeScript types match:

```ts
// apps/web/src/lib/api.shape-test.ts
import { settingsApi, type TaxConfig } from './api';

const t: TaxConfig = await settingsApi.getTax();
type AssertString = TaxConfig['rate'] extends number ? true : false;
const _check: AssertString = true;
```

The compile error tells you the runtime type doesn't match. This catches
"backend drifted, client wrapper didn't update" cases.

## Related

- `prisma-relation-debugging`: relation-field name drift (subset of this class)
- `patch-route-field-silently-dropped`: silent field drops at the API boundary
- `prisma-migrate-private-rds`: schema migrations that change wire shape
- `bun-elysia-react-vite-stack`: full-stack template where this class of
  bug is most common (one agent writes both ends and the plan/doc gets stale)
