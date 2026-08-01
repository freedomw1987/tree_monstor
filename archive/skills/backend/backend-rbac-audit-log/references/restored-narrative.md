# Restored narrative — content moved out of SKILL.md by the distill, preserved here for git-log retrievability.

*See [SKILL.md](../../SKILL.md) for the active pattern. This file collects the project-specific blocks that were compressed during the 2026-07-28 distill so the detail survives.*

```
┌─────────────────────────────────────────────────────┐
│ packages/shared/src/permissions.ts  ←  single source of truth │
│   - 25 permissions 個 string literal                │
│   - 3 roles (ADMIN/SALES/VIEWER)  map 到 permission set  │
│   - can(role, 'quotation:delete')  helper            │
└──────────────┬──────────────────────────────────────┘
               │ import (backend + frontend 共用)
               ▼
┌──────────────────────┐    ┌────────────────────────┐
│ middleware/rbac.ts   │    │ middleware/audit.ts    │
│ requirePermission()  │    │ logEvent({...})        │
│ Elysia plugin        │    │ 攞 userId/IP/UA       │
│ .use(perm) 在 route  │    │ catch & swallow errors │
└──────────┬───────────┘    └────────┬───────────────┘
           │                         │
           ▼                         ▼
    ┌──────────────────────────┐
    │ routes/users.ts, auth.ts, │
    │ quotation.ts, audit.ts   │
    │ .use(requirePermission()) │
    │ logEvent(USER_CREATED,...)│
    └──────────┬───────────────┘
               ▼
       ┌──────────────────┐
       │ AuditLog table   │  ← Prisma schema + migration
       │ + AuditAction enum
       └──────────────────┘
```

## Step 1: Permission map (packages/shared/src/permissions.ts)

export type Permission =
  // User & audit management (admin only)
  | 'user:read' | 'user:create' | 'user:update' | 'user:delete' | 'user:reset_password'
  | 'audit:read'
  // CRM core
  | 'company:read' | 'company:create' | 'company:update' | 'company:delete'
  | 'contact:read' | 'contact:create' | 'contact:update' | 'contact:delete'
  | 'product:read' | 'product:create' | 'product:update' | 'product:delete'
  | 'quotation:read' | 'quotation:create' | 'quotation:update' | 'quotation:delete' | 'quotation:send' | 'quotation:accept'
  | 'deal:read' | 'deal:create' | 'deal:update' | 'deal:delete'
  // AI
  | 'chat:use';

## Step 2: Prisma schema (AuditLog + AuditAction enum)

```prisma
// packages/db/prisma/schema.prisma
enum AuditAction {
  // Auth
  USER_LOGIN USER_LOGIN_FAILED USER_LOGOUT PASSWORD_CHANGED
  // User mgmt
  USER_CREATED USER_UPDATED USER_DEACTIVATED USER_REACTIVATED USER_DELETED PASSWORD_RESET
  // CRM
  QUOTATION_CREATED QUOTATION_UPDATED QUOTATION_DELETED QUOTATION_STATUS_CHANGED
  COMPANY_CREATED COMPANY_UPDATED COMPANY_DELETED
  CONTACT_CREATED CONTACT_UPDATED CONTACT_DELETED
  DEAL_CREATED DEAL_UPDATED DEAL_DELETED
}

> **SQLite 注意**: 冇 enum,用 `String` + Zod/手動 validation。

```typescript
// apps/api/src/middleware/audit.ts
import type { Context } from 'elysia';
import { prisma } from '@crm/db';
import type { AuditAction, Prisma } from '@prisma/client';

```typescript
// apps/api/src/middleware/rbac.ts
import { Elysia } from 'elysia';
import { can, type Permission } from '@crm/shared';

> 預設 `userId` / `userRole` 由 `authContext` derive 提供 (見 `elysia-typescript-workarounds` skill #15)。

## Step 5: User routes (admin only, with self/last-admin protection)

```typescript
// apps/api/src/routes/users.ts
import { Elysia, t } from 'elysia';
import { prisma } from '@crm/db';
import { requirePermission } from '../middleware/rbac';
import { logEvent } from '../middleware/audit';
import { authContext } from '../lib/context';
import { hash } from 'bun';  // or bcrypt

export const userRoutes = new Elysia({ prefix: '/users' })
  .use(authContext)
  .use(requirePermission('user:read'))
  .get('/', async ({ query }) => {
    const { search, role, isActive, limit = 50 } = query;
    return prisma.user.findMany({
      where: {
        ...(search ? { OR: [
          { email: { contains: search, mode: 'insensitive' } },
          { name:  { contains: search, mode: 'insensitive' } },
        ]} : {}),
        ...(role ? { role: role as any } : {}),
        ...(isActive !== undefined ? { isActive: isActive === 'true' } : {}),
      },
      take: Number(limit),
      orderBy: { createdAt: 'desc' },
      select: { id: true, email: true, name: true, role: true, isActive: true, lastLoginAt: true, createdAt: true },
    });
  })
  .get('/:id', async ({ params, set }) => {
    const u = await prisma.user.findUnique({ where: { id: params.id }, select: {
      id: true, email: true, name: true, role: true, isActive: true, lastLoginAt: true, createdAt: true, updatedAt: true,
    }});
    if (!u) { set.status = 404; return { error: 'Not found' }; }
    return u;
  }, { params: t.Object({ id: t.String() }) })
  .post('/', async ({ body, userId, request, set }) => {
    const exists = await prisma.user.findUnique({ where: { email: body.email } });
    if (exists) { set.status = 409; return { error: 'Email already taken' }; }
    const created = await prisma.user.create({
      data: {
        email: body.email,
        name: body.name,
        role: body.role,
        passwordHash: await hash(body.password, 'bcrypt'),  // or use Bun.password
      },
    });
    await logEvent({
      action: 'USER_CREATED',
      actorId: userId,
      resourceType: 'user',
      resourceId: created.id,
      description: `Created user ${created.email} (${created.role})`,
      request,
    });
    return { id: created.id, email: created.email, name: created.name, role: created.role, isActive: created.isActive, createdAt: created.createdAt };
  }, {
    body: t.Object({
      email: t.String({ format: 'email' }),
      name: t.String({ minLength: 1 }),
      role: t.Union([t.Literal('ADMIN'), t.Literal('SALES'), t.Literal('VIEWER')]),
      password: t.String({ minLength: 8 }),
    }),
  })
  .patch('/:id', async ({ params, body, userId, request, set }) => {
    // ⚠️ Last-admin protection
    if (body.role && body.role !== 'ADMIN') {
      const target = await prisma.user.findUnique({ where: { id: params.id }, select: { role: true } });
      if (target?.role === 'ADMIN') {
        const adminCount = await prisma.user.count({ where: { role: 'ADMIN', isActive: true } });
        if (adminCount <= 1) { set.status = 400; return { error: 'Cannot demote the last admin' }; }
      }
    }
    if (body.isActive === false) {
      const target = await prisma.user.findUnique({ where: { id: params.id }, select: { id: true, role: true, isActive: true } });
      if (target?.id === userId) { set.status = 400; return { error: 'Cannot deactivate yourself' }; }
      if (target?.role === 'ADMIN' && target.isActive) {
        const adminCount = await prisma.user.count({ where: { role: 'ADMIN', isActive: true } });
        if (adminCount <= 1) { set.status = 400; return { error: 'Cannot deactivate the last admin' }; }
      }
    }
    const updated = await prisma.user.update({ where: { id: params.id }, data: body });
    await logEvent({
      action: body.isActive === false ? 'USER_DEACTIVATED' : body.isActive === true ? 'USER_REACTIVATED' : 'USER_UPDATED',
      actorId: userId, resourceType: 'user', resourceId: updated.id,
      description: `Updated user ${updated.email}`, metadata: body as any, request,
    });
    return updated;
  }, { params: t.Object({ id: t.String() }) })
  .delete('/:id', async ({ params, userId, request, set }) => {
    if (params.id === userId) { set.status = 400; return { error: 'Cannot delete yourself' }; }
    const target = await prisma.user.findUnique({ where: { id: params.id }, select: { role: true, email: true } });
    if (target?.role === 'ADMIN') {
      const adminCount = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (adminCount <= 1) { set.status = 400; return { error: 'Cannot delete the last admin' }; }
    }
    await prisma.user.delete({ where: { id: params.id } });
    await logEvent({
      action: 'USER_DELETED', actorId: userId, resourceType: 'user', resourceId: params.id,
      description: `Deleted user ${target?.email}`, request,
    });
    return { success: true };
  })
  .post('/:id/reset-password', async ({ params, body, userId, request }) => {
    await prisma.user.update({ where: { id: params.id }, data: { passwordHash: await hash(body.newPassword, 'bcrypt') } });
    await logEvent({
      action: 'PASSWORD_RESET', actorId: userId, resourceType: 'user', resourceId: params.id,
      description: 'Password reset by admin', request,
    });
    return { success: true };
  }, {
    params: t.Object({ id: t.String() }),
    body: t.Object({ newPassword: t.String({ minLength: 8 }) }),
  });
```

**Register** in `index.ts`:
```typescript
app.use(userRoutes).use(auditRoutes).use(quotationRoutes /* etc */);
```

## Step 6: Instrument login / change-password (唔需要 requirePermission 因為已經 public/auth)

```typescript
// apps/api/src/routes/audit.ts
import { Elysia, t } from 'elysia';
import { prisma } from '@crm/db';
import { authContext } from '../lib/context';
import { requirePermission } from '../middleware/rbac';

```typescript
// apps/web/src/lib/api.ts — add usersApi, auditApi
export const usersApi = {
  list: (params = {}) => {
    const qs = new URLSearchParams();
    if (params.search) qs.set('search', params.search);
    if (params.role) qs.set('role', params.role);
    if (params.isActive) qs.set('isActive', params.isActive);
    return request<{ items: UserSummary[]; total: number }>(`/users${qs}`);
  },
  get: (id: string) => request<UserSummary>(`/users/${id}`),
  create: (data) => request<UserSummary>('/users', { method: 'POST', body: JSON.stringify(data) }),
  update: (id, data) => request(`/users/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  remove: (id) => request(`/users/${id}`, { method: 'DELETE' }),
  resetPassword: (id, newPassword) => request(`/users/${id}/reset-password`, { method: 'POST', body: JSON.stringify({ newPassword }) }),
};
export const auditApi = {
  list: (params = {}) => { /* build qs */ return request<{ items: AuditLog[]; total: number }>(`/audit${qs}`); },
};
```

```tsx
// pages/users.tsx — list + search + role filter + inline activate/deactivate + create dialog
// pages/user-detail.tsx — edit name/role/active + reset password + delete (with confirm)
// pages/audit.tsx — filterable table with color-coded action badges
```

Sidebar: 加 `Admin` section,**只係 `user.role === 'ADMIN'` 時 render**,items 放 `/users` + `/audit`。

## Frontend route protection (RWD bonus)

`/users` 個 page 入面 useEffect check `user.role`, 唔係 ADMIN 就 navigate 去 `/dashboard`。Backend 已經用 `requirePermission` reject, frontend 純粹係 UX improvement 避免空白 page。

### 1. **Elysia d.ts noise 預期**
用 `requirePermission` + `authContext` chain 會 trigger Elysia 1.2 MacroContext d.ts 嘅 >100 個 type errors(known issue, `bun run` runtime 唔 care)。Dockerfile API stage 用 `bun run src/index.ts` 唔行 `tsc --noEmit` 就 OK。詳見 `elysia-typescript-workarounds` skill #12。

### 2. **authContext derive userId 唔跨 module 自動 type-infer**
喺 handler 入面 `({ userId, ... })` 解構後,TypeScript 會 complain `userId does not exist on type ...`。用 `as` cast 處理:
```typescript
async ({ params, body, userId, set }) => {
  const ctx = { params, body, userId, set } as typeof arguments[0] & { userId: string | null; params: { id: string } };
  // ...
}
```
詳見 `elysia-typescript-workarounds` #15。

### 3. **Audit failure 唔可以 break user request**
`logEvent()` 一定要 try/catch 內部吞 error。Audit log 唔係 critical path,如果 DB query fail 唔應該 reject login。

### 4. **Password reset 唔可以 reuse current password(可選 UX improvement)**
可以加 `WHERE passwordHash != currentHash` check,但 Day 5 範圍冇做。

### 5. **Last-admin / self-protection 係 RBAC 嘅必要 invariant**
唔可以用 `if (userId === targetUserId && targetUserId.role === 'ADMIN')` 之類嘅 JS 邏輯,**要 count actual admins in DB**。否則 race condition 會撞到(s兩個 admin 同時 demote 對方)。

### 6. **Frontend 唔好用 localStorage cache role**
每次 navigate 用 `useAuth()` 即時攞最新 user。否則 promote 完 user 仲見到舊 role。

## Docker local dev 嘅 migration trick (2026-06-05 crm-system Day 5)

呢個 trick **已經 patch 入 `bun-elysia-react-vite-stack` skill**(Day 5 經驗),可以 cross-reference。

## Step 8: Instrument CRM CRUD routes (consistency pattern)

After login/user/audit, the **next layer of audit coverage** is the CRM CRUD routes — company, contact, deal, quotation. Apply the same `logEvent()` call in every write endpoint, following this **3-line pattern**:

### 8a. Special case: status-change vs general update (quotation PATCH)

A PATCH route often handles BOTH field updates AND status transitions. Log them as **different actions** so the audit page can colour-code properly:

### 8c. Audit coverage checklist (for any CRM with the patterns above)

| Endpoint | Action enum members |
|---|---|
| `POST /companies`, `PATCH /:id`, `DELETE /:id` | `COMPANY_CREATED`, `COMPANY_UPDATED`, `COMPANY_DELETED` |
| `POST /contacts`, `PATCH /:id`, `DELETE /:id` | `CONTACT_CREATED`, `CONTACT_UPDATED`, `CONTACT_DELETED` |
| `POST /deals`, `PATCH /:id`, `DELETE /:id` | `DEAL_CREATED`, `DEAL_UPDATED`, `DEAL_DELETED` |
| `POST /quotations`, `PATCH /:id`, `DELETE /:id` | `QUOTATION_CREATED`, `QUOTATION_UPDATED`, `QUOTATION_DELETED` |
| `POST /quotations/:id/status` (or branch in PATCH) | `QUOTATION_STATUS_CHANGED` |
| `POST /quotations/:id/items` (and PATCH/DELETE on items) | (optional: `QUOTATION_UPDATED` with `metadata: { lineItemChange: true }` if granular tracking matters) |

**Pre-declare all the obvious ones** in the original migration so the first build is clean. **But** it's fine (and common) to add new enum members in a later migration when a new feature ships — Postgres supports `ALTER TYPE ... ADD VALUE` in place, and Prisma's `@default` doesn't break if you only append values. The `crm-system` `20260606120000_*` migration added 7 new actions (`MAN_DAY_ROLE_*`, `ACTIVITY_*`, `ATTACHMENT_*`) with the pattern below.

**Append-only enum extension in a Prisma migration SQL**:

And in `schema.prisma`, append the new members to the `enum AuditAction { ... }` block and re-run `bunx prisma generate` so the client picks up the new `AuditAction` literal types. **Drop the `'NEW_VALUE' as never` cast pattern** in `logEvent()` once the schema is updated.

### 8d. Pitfall: `request` parameter on Elysia handlers

### 8e. Pitfall: Adding a new permission to `PERMISSIONS` map is NOT enough (Lesson 2026-06-07, refined 2026-06-09)

**問題**:新增 `ai-config:read` / `ai-config:update` permission 之後,backend route 用 `requirePermission('ai-config:read')` 仲係返 **403 Forbidden** for admin。**原因**:DB-driven RBAC 入面,permissions 有 3 個 layer 全部要 sync:

1. **`packages/shared/src/permissions.ts` 個 `PERMISSIONS` const** — 個 type / runtime array
2. **`packages/shared/src/permissions.ts` 個 `ROLE_PERMISSIONS` map** — 每個 role 配咩 permission
3. **`role_permissions` 個 DB table** — 真正 runtime check 用嘅 source of truth

**教訓 checklist**(新增 permission 時必做):
- [ ] `PERMISSIONS` const 加咗
- [ ] `ROLE_PERMISSIONS` map 對應 role 加咗(eg. ADMIN set)
- [ ] **`role_permissions` DB table 有 INSERT**(最常漏)
- [ ] Smoke 跑 endpoint 確認 200
- [ ] 寫 `REGRESSION-GUARD.md` entry 紀錄 permission 名 + admin role ID

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)
- `archive/skills/case-history/prisma-sqlite-bun-setup` (archived) — SQLite 用 string 取代 enum 嘅 workaround
- `ai-agent-tool-calling` — AI agent 嘅 `audit` permissions (e.g. chat 唔可以 read audit)

# Day 7 Upgrade Path: From Option 3 → DB-driven RBAC (Option 2)

## Step 9: Elysia 1.2 plugin boundary — derive context is lost (the big Day 7 gotcha)

**The problem**: in `requirePermission` defined as an Elysia plugin with `.onBeforeHandle()`, the `ctx` you receive does **NOT** include values derived by other plugins (like the JWT plugin's `userId` derive). This means:

```typescript
// ❌ BROKEN — ctx.userId is always undefined inside onBeforeHandle
export const requirePermission = (perm: string) =>
  new Elysia({ name: `perm-${perm}` })
    .onBeforeHandle(async (ctx) => {
      if (!ctx.userId) { /* always 401 */ }
    });
```

Elysia 1.2 d.ts makes it look like it should work (the type signature is there), but at runtime the derive context is dropped when crossing plugin boundaries. This is **different** from the singleton-mismatch problem in `archive/skills/case-history/elysia-jwt-plugin-singleton` (archived) (that one is about multiple JWT instances; this is about plugin-boundary derive propagation).

**The fix**: extract `userId` from the raw `Request` headers and re-verify the JWT inside the middleware itself. Don't rely on the upstream derive.

```typescript
// ✅ WORKS — re-verify JWT in-place using the same secret
import { jwtVerify } from 'jose';

**Why `jose` directly (not `@elysiajs/jwt`)?**

**Symptom signature for this gotcha**:
- All routes return 401 (Unauthorized), even admin users with valid tokens
- `/api/products` (or any unprotected route) works fine
- API logs show no error — the middleware silently returns null userId
- Bun logs `[rbac] no auth header` → fixes auth header but still 401 → confirms derive context loss
- This is NOT the same as `archive/skills/case-history/elysia-jwt-plugin-singleton` (archived) (that one fails with `Bad JWT issued by different instance`)

## Step 10: Bun runtime gotcha — `export *` + same-file const reference

## Step 11: Prisma enum + JSON polymorphism — the `as never` cast pattern

**Audit the following when applying this pattern**:
1. The `itemType` discriminator is set correctly based on which FK is present (e.g. `data.serviceId ? 'SERVICE' : 'PRODUCT'`)
2. The opposite FK is explicitly set to `null` (not omitted), so Prisma doesn't try to write undefined and the column is unambiguous
3. The `manDaySnapshot` is `null` (not `undefined`) for non-service items — Prisma treats them differently

## Step 12: Pitfall summary (Day 7 additions)

### 8f. Pitfall — Token-claim privilege escalation via DB-vs-token role (TD-011, pm-system 2026-06-08)

**Lesson**:**derive hook / auth middleware 嘅 role 必須由 DB 攞(never trust client)**。任何 token 字串入面嘅 claim,只可以做 hint,唔可以做 source of truth。

完整 reproduce + RG-006 entry + 全部 patch 見 `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md`。

## Step 9: Elysia 1.2 plugin-boundary derive loss — use `getUserIdFromRequest` re-verifying with `jose` directly, not the `jwt()` factory. Affects EVERY plugin that needs `userId` from another plugin.
2. **Bun `export *` + same-file const** (Step 10): explicit import + re-export. Affects barrel files that derive new exports from re-exported consts.
3. **Prisma `as never` for enum + JSON** (Step 11): the workhorse cast for polymorphic writes.
4. **`@elysiajs/jwt` standalone `.verify` is not a function** (Step 9): use `jose.jwtVerify` instead. Easy to assume the factory returns a usable verifier; it doesn't.
5. **Cache invalidation in RBAC** (Step 3): call `clearRoleCache(roleId)` after every role update. The 5-min TTL is the safety net, not the primary mechanism.

## Step 14: `requirePermission` with `as: 'scoped'` only applies to the NEXT verb (Day 14 lesson, crm-system 2026-06-07)

**Audit recipe to find these** (run from `apps/api/src/routes/`):

```bash
# For each route file, count: number of verbs vs number of .use(requirePermission(...))
for f in *.ts; do
  verbs=$(grep -cE "^\s*\.(get|post|patch|delete)\(" "$f")
  perms=$(grep -c "requirePermission" "$f")
  echo "$f  verbs=$verbs  requirePerms=$perms"
done
# If verbs > perms (after subtracting 1 for the top-level gate), the file has public endpoints.
```

**Mitigation options** (pick one when the codebase already has these gaps):

## Step 15: Boot-time JWT_SECRET hard-fail template (Day 14 P0-4, crm-system 2026-06-07)

```ts
function requireSecret(name: string, opts: { minLength?: number; forbidden?: string[] } = {}) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} environment variable is required.`);
  if (opts.minLength && value.length < opts.minLength) {
    throw new Error(`${name} must be at least ${opts.minLength} characters (got ${value.length}).`);
  }
  if (opts.forbidden?.includes(value) && process.env.NODE_ENV === 'production') {
    throw new Error(`${name} is set to a forbidden fallback in production.`);
  }
  return value;
}
```

## Step 16: Finding public routes — the 60-second audit recipe

When joining a new project (or before shipping a security patch), the fastest way to find unauthorized endpoints is a 1-liner over the routes directory:

| Condition | Means |
|---|---|
| `authContext=0 requirePerm=0` | **PUBLIC** — every endpoint in this file is anonymous-reachable. Top priority to fix. |
| `authContext>0 requirePerm=0` | Logged-in users can hit everything; no per-action check. Usually OK for self-service endpoints, but audit each. |
| `authContext>0 requirePerm>0` | Gated, but verify `perms >= verbs` (one per verb, since `as: 'scoped'` only covers the next verb — see Step 14). |
| `authContext=0 requirePerm>0` | Gated by permission but no `userId` derive — `logEvent` will record `actorId=null`. Fix `authContext` first, then check `getUserIdFromRequest` works for `requirePermission`. |

**Expected output for a fully-gated file** (e.g. `users.ts`):
```
users                verbs= 7  requirePerm= 7  authContext= 2
```

**This recipe surfaces the entire attack surface in one command.** Save it as `scripts/audit-public-routes.sh` and wire it into pre-deploy smoke.

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `references/p0-public-routes-audit-recipe.md` — full audit + fix-batch workflow for finding and gating public endpoints (Day 14, crm-system 2026-06-07)
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)
- `templates/require-secret.ts` — Step 15 boot-time secret validator
- `archive/skills/case-history/prisma-sqlite-bun-setup` (archived) — SQLite 用 string 取代 enum 嘅 workaround
- `ai-agent-tool-calling` — AI agent 嘅 `audit` permissions (e.g. chat 唔可以 read audit)

## Step 13: Role name invariant — UPPERCASE + displayName 分離 (2026-06-06 真實撞牆, smoke test 揭發)

**Frontend 必用 toast library**(eg. `sonner` / `react-hot-toast`),`onError` 唔可以淨 render inline `<p>`(太易被 dialog 高度 ignore):
```tsx
const onError = (e: Error) => {
  toast.error(parseApiError(e));      // ← 必 user-visible
  setError(parseApiError(e));          // ← inline 輔助
};
### 8d. Pitfall: `request` parameter on Elysia handlers

### 8e. Pitfall: Adding a new permission to `PERMISSIONS` map is NOT enough (Lesson 2026-06-07, refined 2026-06-09)

**問題**:新增 `ai-config:read` / `ai-config:update` permission 之後,backend route 用 `requirePermission('ai-config:read')` 仲係返 **403 Forbidden** for admin。**原因**:DB-driven RBAC 入面,permissions 有 3 個 layer 全部要 sync:

1. **`packages/shared/src/permissions.ts` 個 `PERMISSIONS` const** — 個 type / runtime array
2. **`packages/shared/src/permissions.ts` 個 `ROLE_PERMISSIONS` map** — 每個 role 配咩 permission
3. **`role_permissions` 個 DB table** — 真正 runtime check 用嘅 source of truth

**教訓 checklist**(新增 permission 時必做):
- [ ] `PERMISSIONS` const 加咗
- [ ] `ROLE_PERMISSIONS` map 對應 role 加咗(eg. ADMIN set)
- [ ] **`role_permissions` DB table 有 INSERT**(最常漏)
- [ ] Smoke 跑 endpoint 確認 200
- [ ] 寫 `REGRESSION-GUARD.md` entry 紀錄 permission 名 + admin role ID

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)

