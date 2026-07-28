# CRM-system Day 14 (2026-06-07) — Public-routes audit results

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body (Step 16 "Day 14 crm-system audit
> results" + Step 14 lesson narrative). The general per-verb
> `.use(requirePermission(...))` rule lives in SKILL.md; this file
> is the exact crm-system Day 14 audit run output + the `as: 'scoped'`
> trap explanation that surfaced 16 silent-public endpoints.

## Why this exists

**Day 14 crm-system audit results** (verbatim, before the fix):
```
activity             verbs= ?  requirePerm= 0  authContext= 3
ai-config            verbs= ?  requirePerm= 1  authContext= 0
audit                verbs= 2  requirePerm= 2  authContext= 2
auth                 verbs= 4  requirePerm= 0  authContext= 2     ← OK (login/register/me/change-password are auth endpoints)
chat                 verbs= 4  requirePerm= 0  authContext= 0     ← PUBLIC
company              verbs= 4  requirePerm= 0  authContext= 0     ← PUBLIC
contact              verbs= 4  requirePerm= 0  authContext= 0     ← PUBLIC
deal                 verbs= 5  requirePerm= 0  authContext= 0     ← PUBLIC
product              verbs= 4  requirePerm= 0  authContext= 2
quotation            verbs= 4  requirePerm= 0  authContext= 2
... (the rest gated)
```

The 16 silent-public endpoints (`company` 4 + `contact` 4 + `deal` 5 + `chat` 3 partial) were all caught by the same root cause: `requirePermission` was defined with `{ as: 'scoped' }`, so `.use(requirePermission('X'))` at the top of a route file only gates the **next** verb, not the whole file.

## The `as: 'scoped'` trap (verbatim, Day 14 lesson)

**The trap**: Elysia 1.2's `onBeforeHandle` is plugin-boundary, but **per-verb scope is the other half of the puzzle**. The skill's own `requirePermission` helper uses `{ as: 'scoped' }` (see `templates/require-permission-rbac.ts`), which means:

```ts
export function requirePermission(perm: string) {
  return new Elysia({ name: `require-permission:${perm}` }).onBeforeHandle(
    { as: 'scoped' },                        // ← scoped, not global
    async (ctx) => { ... }
  );
}
```

**`.use(requirePermission('X'))` at the TOP of a route file gates ONLY the very next `.get/.post/.patch/.delete`**. Subsequent verbs need their own `.use()` call.

```ts
// ❌ BROKEN — only the first .get('/') is gated
export const dealRoutes = new Elysia({ prefix: '/deals' })
  .use(authContext)
  .use(requirePermission('deal:read'))         // ← applies to next .get only
  .get('/', ...)                               // ✅ gated
  .get('/:id', ...)                            // ❌ PUBLIC
  .post('/', ...)                              // ❌ PUBLIC
  .patch('/:id', ...)                          // ❌ PUBLIC
  .delete('/:id', ...)                         // ❌ PUBLIC

// ✅ CORRECT — one .use() per verb
export const dealRoutes = new Elysia({ prefix: '/deals' })
  .use(authContext)
  .use(requirePermission('deal:read'))
  .get('/', ...)
  .use(requirePermission('deal:read'))
  .get('/:id', ...)
  .use(requirePermission('deal:create'))
  .post('/', ...)
  .use(requirePermission('deal:update'))
  .patch('/:id', ...)
  .use(requirePermission('deal:delete'))
  .delete('/:id', ...)
```

**Why this matters for security audits**: when a route file has 5-7 verbs and only the first `.use()` covers the first one, the other 4-6 endpoints are silently public. The Day 14 crm-system review caught this exact pattern in `company.ts`, `contact.ts`, `deal.ts` — 16 endpoints total were public, all because the original author assumed `.use()` was file-scoped.

## Audit recipe (verbatim, Day 14)

```bash
# From apps/api/src/routes/, count per-file: how many verbs vs how many requirePermission gates
for f in *.ts; do
  name=$(basename "$f" .ts)
  verbs=$(grep -cE "\.(get|post|patch|delete)\(" "$f")
  perms=$(grep -c "requirePermission" "$f")
  authctx=$(grep -c "authContext" "$f")
  printf "%-20s verbs=%2d  requirePerm=%2d  authContext=%2d\n" "$name" "$verbs" "$perms" "$authctx"
done
```

**Expected output for a fully-gated file**: `verbs==perms` (one perms per verb, no top-level gate). **If `perms < verbs`** → suspect public endpoints → read the file and confirm.

**Symptom signature** (how this manifests in production):
- `curl http://api.example.com/deals` returns a JSON list of every deal in the DB
- `curl -X POST http://api.example.com/companies -d '{"name":"X"}'` succeeds with 201 and `actorId=null` in the audit log
- No build error, no test failure — this is a **silent authorization bypass** caught only by manual code review or authz-aware integration tests

## Mitigation options (verbatim)

| Option | What it does | Trade-off |
|---|---|---|
| **Per-verb `.use()`** (recommended) | Manual fix per endpoint, no plugin change | Tedious for big files, but explicit and audit-friendly |
| **Switch `as: 'scoped'` → `'global'`** in `requirePermission` | One `.use()` covers all verbs | Easy, but couples the permission choice to the whole file (you can't have `GET /` need `read` and `POST /` need `create` with the same gate) |
| **Route-grouping via sub-Elysia** | `.group('/companies', (app) => app.use(...).get(...).post(...))` | Cleanest for new code, refactor cost for existing |

For a one-time P0 fix-batch on existing code, **per-verb `.use()`** is fastest and most explicit. For new code, **route grouping** is the cleaner pattern.