# P0 Public Routes Audit + Fix-Batch Recipe

> **Day 14, crm-system 2026-06-07**. The 60-second recipe to find
> every public endpoint in an Elysia/Express/etc. backend, then
> batch-fix with the per-verb `.use(requirePermission(...))` pattern.
> Pairs with `backend-rbac-audit-log` Step 14 + Step 16.

---

## Why this exists

A typical CRM-style Elysia project ends Day 5-N with 12-20 route files.
The pattern is:

```ts
// routes/company.ts
export const companyRoutes = new Elysia({ prefix: '/companies' })
  .get('/', ...)         // ← author assumes .use(authContext) is in main.ts
  .get('/:id', ...)
  .post('/', ...)
  .patch('/:id', ...)
  .delete('/:id', ...)
```

But the author **forgot** to add `.use(authContext)` + `.use(requirePermission(...))`
at the top of the file. Result: 5 endpoints publicly reachable. The
frontend has the JWT, so it "feels secure" in dev, but anyone with
`curl` gets the whole DB.

This recipe finds those 5 endpoints in 60 seconds.

---

## Recipe (3 steps)

### Step 1: Audit (60 seconds)

```bash
cd apps/api/src/routes

# Header
printf "%-25s %-6s %-12s %-12s\n" "FILE" "verbs" "requirePerm" "authContext"
printf "%-25s %-6s %-12s %-12s\n" "----" "-----" "-----------" "----------"

# Per-file
for f in *.ts; do
  name=$(basename "$f" .ts)
  verbs=$(grep -cE "\.(get|post|patch|delete)\(" "$f")
  perms=$(grep -c "requirePermission" "$f")
  authctx=$(grep -c "authContext" "$f")
  printf "%-25s %-6s %-12s %-12s\n" "$name" "$verbs" "$perms" "$authctx"
done
```

### Step 2: Triage (5 minutes)

For each file, read the result and apply this decision tree:

| `authContext` | `requirePerm` | Verdict | Action |
|---|---|---|---|
| 0 | 0 | **PUBLIC** (catastrophic) | Add `.use(authContext)` + per-verb `.use(requirePermission(...))` for every verb |
| 0 | >0 | Weird — gated but no `userId` derive. `logEvent` will record `actorId=null`. | Add `.use(authContext)` first; verify the `requirePermission` plugin can read `userId` |
| >0 | 0 | Logged-in but un-gated. OK for self-service, suspicious for admin/CUD. | Audit each endpoint manually; add `.use(requirePermission(...))` where appropriate |
| >0 | < `verbs` | **PARTIAL PUBLIC** — `as: 'scoped'` means only the verb after each `.use()` is gated. | Add per-verb `.use()` for the missing ones (see Step 14 of `backend-rbac-audit-log`) |
| >0 | >= `verbs` | Gated. | Spot-check that each `.use()` precedes the right verb |

### Step 3: Fix (10-30 minutes per file)

For each "PUBLIC" or "PARTIAL PUBLIC" file, apply the per-verb pattern:

**Before**:
```ts
import { Elysia, t } from 'elysia';
import { prisma } from '@crm/db';
import { logEvent } from '../middleware/audit';

export const companyRoutes = new Elysia({ prefix: '/companies' })
  .get('/', async ({ query }) => { ... })
  .get('/:id', async ({ params, set }) => { ... })
  .post('/', async ({ body, set, userId, request }) => { ... })
  .patch('/:id', async ({ params, body, set, userId, request }) => { ... })
  .delete('/:id', async ({ params, set, userId, request }) => { ... });
```

**After**:
```ts
import { Elysia, t } from 'elysia';
import { prisma } from '@crm/db';
import { logEvent } from '../middleware/audit';
import { authContext } from '../lib/context';
import { requirePermission } from '../middleware/rbac';

// 2026-06-07 review: every verb is gated with the corresponding
// permission from docs/rbac.md. Per-verb pattern because
// `requirePermission` is `{ as: 'scoped' }` and only applies to
// the immediately-following .get/.post/.patch/.delete.
export const companyRoutes = new Elysia({ prefix: '/companies' })
  .use(authContext)
  .use(requirePermission('company:read'))
  .get('/', async ({ query }) => { ... })
  .use(requirePermission('company:read'))
  .get('/:id', async ({ params, set }) => { ... })
  .use(requirePermission('company:create'))
  .post('/', async ({ body, set, userId, request }) => { ... })
  .use(requirePermission('company:update'))
  .patch('/:id', async ({ params, body, set, userId, request }) => { ... })
  .use(requirePermission('company:delete'))
  .delete('/:id', async ({ params, set, userId, request }) => { ... });
```

### Step 4: Commit (1 commit per route file)

```bash
git add apps/api/src/routes/company.ts apps/api/src/routes/contact.ts apps/api/src/routes/deal.ts
git commit -m "fix(security): gate /companies / /contacts / /deals with RBAC

- company.ts: 5 verbs gated (read/.../delete)
- contact.ts: 5 verbs gated
- deal.ts: 7 verbs gated (incl. /kanban and /:id/stage)

Pre-patch, all 17 endpoints were anonymous-reachable."
```

---

## Pitfalls during the fix

### Pitfall 1: Forgetting the per-verb `.use()` after the first one

Elysia 1.2 `as: 'scoped'` only applies to the next verb. After 1 hour
of fixing you'll reflexively add `.use(requirePermission('X'))` before
each verb — but **the very first time you do it** (e.g. file 1 of 3)
you might forget. The audit recipe re-run will catch it:

```bash
# Re-run the audit; should show perms >= verbs for every fixed file
for f in apps/api/src/routes/*.ts; do
  verbs=$(grep -cE "\.(get|post|patch|delete)\(" "$f")
  perms=$(grep -c "requirePermission" "$f")
  [ "$perms" -lt "$verbs" ] && echo "STILL PUBLIC: $f ($perms/$verbs)"
done
```

### Pitfall 2: TypeScript errors from Elysia d.ts noise

After the fix, `bunx tsc --noEmit --skipLibCheck` will flag
`Property 'userId' does not exist on type ...` for the handlers that
use `userId` (because TypeScript can't prove `authContext` +
`requirePermission` derive it). **This is the pre-existing Elysia 1.2
typecheck gap** (see Step 12 #1 of the main skill). `bun run` runtime
is fine; ignore the LSP squiggle or `@ts-nocheck` the file.

**Don't conflate**: the LSP errors are NOT caused by the P0 fix — they
existed before. The P0 fix doesn't add new errors, only re-arranges
existing ones. Track in P1-1, not in the P0 commit.

### Pitfall 3: `requirePermission` is plugin-boundary, not file-boundary

`requirePermission('X')` checks the user's permission **at request
time** by calling `getUserIdFromRequest` and `userHasPermission`
internally. It does NOT export the `userId` to the handler. If a
handler needs `userId` for audit logging, the handler must:

1. Destructure `userId` from the Elysia context (TypeScript will
   complain — see Pitfall 2), OR
2. Re-derive from the request: `const userId = await getUserIdFromRequest(request)`

For Day 14 crm-system, all the PATCH/DELETE handlers already
destructure `userId` and rely on Elysia's runtime to populate it from
`authContext`. This works at runtime; the LSP complaint is a typecheck
artifact.

### Pitfall 4: `logEvent` audit log writes `actorId: null` if `userId` is null

If a request somehow bypasses `authContext` (e.g. an internal call
from a sub-route), `userId` will be `null` and `logEvent({ actorId:
userId ?? null, ... })` will record a null actor. This makes the
mutation **untraceable** in the audit log.

For routes that already have `.use(authContext)`, this is safe. For
routes that don't (e.g. a `/health` endpoint), it's expected. **Audit
your audit log periodically**:

```sql
SELECT COUNT(*) FROM audit_logs WHERE "actorId" IS NULL AND "action" NOT IN ('USER_LOGIN_FAILED', 'HEALTH_CHECK');
-- Any non-zero count = bug: a mutation happened without an actor
```

---

## What this recipe does NOT cover

- **Frontend auth gating** — this is a server-side audit. The SPA
  may still display public data; that's a separate problem.
- **Authorization at the row level** (e.g. SALES can only edit their
  own deals, not other reps'). The `requirePermission` plugin only
  checks role-level permissions, not ownership. For row-level, add
  an `if (record.ownerId !== userId) 403` check inside the handler.
- **API key / service-to-service auth** — `requirePermission` assumes
  a user JWT. If you have machine clients, add a separate
  `requireApiKey` plugin.
- **Rate limiting** — see `crm-data-model` for per-endpoint rate
  limits (separate concern, often paired with auth).

---

## Day 14 crm-system batch — what was actually shipped

| File | Endpoints gated | Verdict pre-fix | Commit |
|---|---|---|---|
| `auth.ts` (register endpoint) | 1 | PUBLIC with admin-pickable role | `f6821ea` |
| `company.ts` | 5 | PUBLIC | `7b84f47` |
| `contact.ts` | 5 | PUBLIC | `7b84f47` |
| `deal.ts` | 7 | PUBLIC | `7b84f47` |
| `chat.ts` | 4 | PUBLIC | `3c67387` |

**Total: 22 endpoints, 4 commits, ~1.5 hours including the smoke
verification.** Per-endpoint average = 4 minutes, of which 1 minute is
typing and 3 minutes is reading the existing handler to confirm the
permission choice.

For larger codebases (50+ endpoints), consider writing a subagent to
do Steps 1-3 in parallel across multiple route files. Pass this recipe
+ the permission matrix + the working `.use()` pattern as context.
