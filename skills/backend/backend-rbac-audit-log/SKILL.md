---
name: backend-rbac-audit-log
description: "Add role-based access control (RBAC) + audit log to any backend API (Elysia, Express, Fastify, Hono, NestJS). Pattern: centralized permission map in shared package + middleware `requirePermission()` plugin + `AuditLog` table with action enum + auto-capturing `logEvent()` helper that grabs user/IP/UA without throwing. Use when user says 'user management', 'roles and permissions', 'audit log', 'who did what when', 'activity history', 'compliance log', or wants admin functionality (CRUD users, reset passwords, view who-changed-what). Pairs naturally with `crm-data-model` for CRM/sales tools."
tags: ["rbac", "audit", "permissions", "auth", "admin", "backend", "security", "elysia", "express"]
---


Last-verified: 2026-07-28
# RBAC + Audit Log Backend Pattern (Option 3 — centralized permission map)

## 觸發時機

用戶話:
- 「加 user management」/「管理用戶帳號同密碼」
- 「加角色權限」/ 「admin 唔可以 delete 嘢 / 普通 sales 唔可以睇 audit」
- 「加 audit log」/ 「我想知邊個撳咗咩」/ 「activity history」/ 「compliance log」
- 「最後一個 admin 唔可以刪走」/ 「唔可以停用自己」

呢個 pattern 適合任何 backend (Elysia / Express / Fastify / Hono / NestJS),用 TypeScript + Prisma 示範。SQL database 通用 (Postgres / MySQL / SQLite),enum 部分要 SQLite 改成 string。

## 三個 strategy 比較

| Strategy | 描述 | 何時用 | 維護成本 |
|---|---|---|---|
| **Option 1: Hard-coded role, 寫死喺每個 route** | 3 個 role,每個 route `if (role !== 'ADMIN') 403` | 永遠唔加新 role,團隊得 2-3 人 | **最低** |
| **⭐ Option 3: 集中 permission map** (本 skill 推薦) | 3 個 hard-coded role + `PERMISSIONS` 集中喺 `packages/shared/permissions.ts`,用 `requirePermission('quotation:delete')` middleware 嘅 plugin 喺 route | 想易 read、易 audit、易將來升級 | **低** |
| **Option 2: 完整 database-driven RBAC** | `permissions` + `role_permissions` tables + admin UI 管理 | enterprise / multi-tenant SaaS / compliance 嚴 | **高** (schema、API、UI、cache invalidation) |

**Day 5 經驗 (crm-system 2026-06-05)**: David 揀 Option 3,1 個 file `packages/shared/src/permissions.ts` 控制晒全部,將來想加粒度都唔使重寫。

## 完整架構 (4 個 piece)

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

```typescript
// packages/shared/src/permissions.ts
// SINGLE SOURCE OF TRUTH — used by both backend (for requirePermission)
// and frontend (for hiding nav / disabling buttons).

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

export const PERMISSIONS = [
  'user:read', 'user:create', 'user:update', 'user:delete', 'user:reset_password',
  'audit:read',
  'company:read', 'company:create', 'company:update', 'company:delete',
  'contact:read', 'contact:create', 'contact:update', 'contact:delete',
  'product:read', 'product:create', 'product:update', 'product:delete',
  'quotation:read', 'quotation:create', 'quotation:update', 'quotation:delete', 'quotation:send', 'quotation:accept',
  'deal:read', 'deal:create', 'deal:update', 'deal:delete',
  'chat:use',
] as const;

export type UserRole = 'ADMIN' | 'SALES' | 'VIEWER';

const ROLE_PERMISSIONS: Record<UserRole, Set<Permission>> = {
  ADMIN: new Set<Permission>(PERMISSIONS),   // everything
  SALES: new Set<Permission>([
    'company:read', 'company:create', 'company:update', 'company:delete',
    'contact:read', 'contact:create', 'contact:update', 'contact:delete',
    'product:read',
    'quotation:read', 'quotation:create', 'quotation:update', 'quotation:delete', 'quotation:send', 'quotation:accept',
    'deal:read', 'deal:create', 'deal:update', 'deal:delete',
    'chat:use',
  ]),
  VIEWER: new Set<Permission>([
    'company:read', 'contact:read', 'product:read',
    'quotation:read', 'deal:read',
  ]),
};

export function can(role: UserRole | null | undefined, perm: Permission): boolean {
  if (!role) return false;
  return ROLE_PERMISSIONS[role]?.has(perm) ?? false;
}

export function permissionsFor(role: UserRole): Permission[] {
  return Array.from(ROLE_PERMISSIONS[role] ?? []);
}
```

`packages/shared/src/index.ts`:
```typescript
export * from './permissions';
```

**Frontend** 用同一份 map (`@crm/shared`) 嚟 hide nav / disable button:
```typescript
import { can } from '@crm/shared';
{can(user.role, 'user:create') && <Button>新增用戶</Button>}
```

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

model AuditLog {
  id           String      @id @default(cuid())
  actorId      String?
  actor        User?       @relation(fields: [actorId], references: [id], onDelete: SetNull)
  action       AuditAction
  resourceType String?     // "quotation" | "user" | "company" | etc
  resourceId   String?
  description  String?     // human-readable one-liner
  metadata     Json?       // before/after diff, IP, etc
  ipAddress    String?
  userAgent    String?
  createdAt    DateTime    @default(now())

  @@index([actorId, createdAt])
  @@index([action, createdAt])
  @@index([resourceType, resourceId])
  @@map("audit_logs")
}

// User model — add reverse relation
model User {
  // ... existing fields ...
  auditLogs    AuditLog[]
}
```

> **SQLite 注意**: 冇 enum,用 `String` + Zod/手動 validation。

> **Migration** (Docker local dev 用 container DB): 見下方「Docker 內 postgres 嘅 migration trick」section — 喺 host 跑唔到 `prisma migrate dev` 因為 postgres 冇 expose port,要 `docker exec` 直接行 SQL + manual `_prisma_migrations` row insert。

## Step 3: audit middleware (logEvent helper)

```typescript
// apps/api/src/middleware/audit.ts
import type { Context } from 'elysia';
import { prisma } from '@crm/db';
import type { AuditAction, Prisma } from '@prisma/client';

interface LogEventParams {
  action: AuditAction;
  actorId: string | null;
  resourceType?: string;
  resourceId?: string;
  description?: string;
  metadata?: Prisma.InputJsonValue;
  request?: Request;
}

export async function logEvent(p: LogEventParams): Promise<void> {
  try {
    let ipAddress: string | null = null;
    let userAgent: string | null = null;
    if (p.request) {
      ipAddress = p.request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
        ?? p.request.headers.get('x-real-ip')
        ?? null;
      userAgent = p.request.headers.get('user-agent');
    }
    await prisma.auditLog.create({
      data: {
        action: p.action,
        actorId: p.actorId,
        resourceType: p.resourceType,
        resourceId: p.resourceId,
        description: p.description,
        metadata: p.metadata,
        ipAddress,
        userAgent,
      },
    });
  } catch (err) {
    // ⚠️ NEVER throw from audit — audit failure must not break user request
    console.error('[audit] logEvent failed:', err);
  }
}
```

## Step 4: RBAC middleware (requirePermission plugin)

```typescript
// apps/api/src/middleware/rbac.ts
import { Elysia } from 'elysia';
import { can, type Permission } from '@crm/shared';

export const requirePermission = (perm: Permission) =>
  new Elysia({ name: `perm-${perm}` })
    .onBeforeHandle(({ userId, userRole, set }) => {
      if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
      if (!can(userRole as any, perm)) {
        set.status = 403;
        return { error: `Forbidden: missing permission ${perm}` };
      }
    });

// Convenience: requireAdmin
export const requireAdmin = () => requirePermission('user:create');
```

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
// auth.ts — login endpoint
.post('/login', async ({ body, request, set }) => {
  const u = await prisma.user.findUnique({ where: { email: body.email } });
  if (!u || !u.isActive) {
    await logEvent({ action: 'USER_LOGIN_FAILED', actorId: u?.id, description: `Login failed: ${body.email}`, request });
    set.status = 401; return { error: 'Invalid credentials' };
  }
  const ok = await verify(body.password, u.passwordHash);
  if (!ok) {
    await logEvent({ action: 'USER_LOGIN_FAILED', actorId: u.id, description: 'Bad password', request });
    set.status = 401; return { error: 'Invalid credentials' };
  }
  await prisma.user.update({ where: { id: u.id }, data: { lastLoginAt: new Date() } });
  await logEvent({ action: 'USER_LOGIN', actorId: u.id, description: 'Login successful', request });
  const token = await jwt.sign({ sub: u.id, role: u.role });
  return { token, user: { id: u.id, email: u.email, name: u.name, role: u.role } };
})
```

## Step 7: Audit query endpoint (admin only)

```typescript
// apps/api/src/routes/audit.ts
import { Elysia, t } from 'elysia';
import { prisma } from '@crm/db';
import { authContext } from '../lib/context';
import { requirePermission } from '../middleware/rbac';

export const auditRoutes = new Elysia({ prefix: '/audit' })
  .use(authContext)
  .use(requirePermission('audit:read'))
  .get('/', async ({ query }) => {
    const { actorId, action, resourceType, resourceId, from, to, limit = 100, offset = 0 } = query;
    return prisma.auditLog.findMany({
      where: {
        ...(actorId ? { actorId } : {}),
        ...(action ? { action: action as any } : {}),
        ...(resourceType ? { resourceType } : {}),
        ...(resourceId ? { resourceId } : {}),
        ...(from || to ? { createdAt: {
          ...(from ? { gte: new Date(from) } : {}),
          ...(to   ? { lte: new Date(to)   } : {}),
        }} : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: Number(limit), skip: Number(offset),
      include: { actor: { select: { id: true, name: true, email: true, role: true } } },
    });
  })
  .get('/actions', () => Object.keys(AuditAction));  // for filter dropdown
```

## Frontend (簡)

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

## ⚠️ 重要 pitfalls (Day 5 撞過)

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

**問題**: docker-compose postgres 唔 expose host port (e.g. `5432/tcp` only internal),host 跑 `prisma migrate dev` 撞 `Can't reach database server`。

**解決** (3 steps):

1. **手寫 SQL** 放喺 `packages/db/prisma/migrations/<timestamp>_<name>/migration.sql`,CREATE TYPE + CREATE TABLE + CREATE INDEX + FK。
2. **`docker exec` 跑 SQL**:
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < \
     packages/db/prisma/migrations/20260605000000_add_audit_log/migration.sql
   ```
3. **手動 insert `_prisma_migrations` row** 標記 applied,咁將來 entrypoint 嘅 `prisma migrate deploy` 唔會 complain "drift":
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -c \
     "INSERT INTO \"_prisma_migrations\" (id, checksum, migration_name, finished_at, applied_steps_count) VALUES ('<unique-id>', '', '<timestamp>_<name>', NOW(), 1);"
   ```
   ⚠️ `migration_name` 冇 unique constraint,所以用 `id` 避免 duplicate。

4. **喺 host 行 `bunx prisma generate`** 重新 generate client 識新 model。

呢個 trick **已經 patch 入 `bun-elysia-react-vite-stack` skill**(Day 5 經驗),可以 cross-reference。

## 何時用呢個 skill vs 簡單 auth-only

| 場景 | 用呢個 skill? |
|---|---|
| User 話「加 user management」+「audit log」 | ✅ 用 |
| User 話「加 RBAC」但冇提及 audit | ✅ 用(Option 3 預埋 audit hook) |
| User 話「淨係加密碼改」 | ❌ 唔需要,simple route 就夠 |
| User 用 JWT 第三方 auth (Auth0 / Clerk) | ❌ 唔需要,audit log 喺 provider 已有 |

## Step 8: Instrument CRM CRUD routes (consistency pattern)

After login/user/audit, the **next layer of audit coverage** is the CRM CRUD routes — company, contact, deal, quotation. Apply the same `logEvent()` call in every write endpoint, following this **3-line pattern**:

```typescript
.post('/', async ({ body, set, userId, request }) => {
  const created = await prisma.company.create({ data: body as never });
  set.status = 201;
  await logEvent({                              // ← 3rd line: always after the mutation
    action: 'COMPANY_CREATED',
    actorId: userId ?? null,
    resourceType: 'company',
    resourceId: created.id,
    description: `Created company ${created.name}`,
    metadata: { name: created.name, status: created.status },
    request,                                    // ← real request → IP + UA captured
  });
  return created;
}, { /* body validation */ })
```

**Apply to every write handler**. Same shape for `PATCH` and `DELETE`:

```typescript
.patch('/:id', async ({ params, body, set, userId, request }) => {
  const updated = await prisma.company.update({ where: { id: params.id }, data: body as never });
  await logEvent({
    action: 'COMPANY_UPDATED',
    actorId: userId ?? null,
    resourceType: 'company',
    resourceId: params.id,
    description: `Updated company ${updated.name}`,
    metadata: { name: updated.name, fields: Object.keys(body as object) },
    request,
  });
  return updated;
})

.delete('/:id', async ({ params, set, userId, request }) => {
  const before = await prisma.<model>.findUnique({ where: { id: params.id }, select: { name: true } });  // ← snapshot before delete
  await prisma.<model>.delete({ where: { id: params.id } });
  if (before) {
    await logEvent({
      action: 'COMPANY_DELETED',
      actorId: userId ?? null,
      resourceType: 'company',
      resourceId: params.id,
      description: `Deleted company ${before.name}`,
      metadata: { name: before.name },
      request,
    });
  }
  return { success: true };
})
```

**Always add `userId, request` to the handler signature** — they're injected by `authContext` and `Elysia` core respectively. TypeScript will complain (Elysia d.ts noise, see `elysia-typescript-workarounds`), but `bun run` runtime ignores.

### 8a. Special case: status-change vs general update (quotation PATCH)

A PATCH route often handles BOTH field updates AND status transitions. Log them as **different actions** so the audit page can colour-code properly:

```typescript
.patch('/:id', async ({ params, body, set, userId, request }) => {
  const data = body as { title?: string; notes?: string; status?: string; taxRate?: number; /* etc */ };
  // ... build `update` object, validate, etc ...
  const before = await prisma.quotation.update({ where: { id: params.id }, data: update as never });
  if (data.taxRate !== undefined) await recalcQuotation(params.id);
  const refreshed = await prisma.quotation.findUnique({ where: { id: params.id }, include: { /* ... */ } });

  // Branch: status change vs general field update
  if (data.status && data.status !== before.status) {
    await logEvent({
      action: 'QUOTATION_STATUS_CHANGED',
      actorId: userId ?? null,
      resourceType: 'quotation',
      resourceId: params.id,
      description: `${before.number} status: ${before.status} -> ${data.status}`,
      metadata: { from: before.status, to: data.status, number: before.number },
      request,
    });
  } else {
    await logEvent({
      action: 'QUOTATION_UPDATED',
      actorId: userId ?? null,
      resourceType: 'quotation',
      resourceId: params.id,
      description: `Updated quotation ${before.number} (${before.company?.name ?? ''})`,
      metadata: { number: before.number, fields: Object.keys(data) },
      request,
    });
  }
  return refreshed;
})
```

**Why two actions** (not just `UPDATED`): auditors want to filter "all status changes last week" — collapsing them into generic UPDATES makes that hard. The frontend's badge colour (success for SENT, info for STATUS_CHANGED) is also tied to the action.

### 8b. Helper for the side-effect: status endpoint shortcut

Some apps expose `POST /quotations/:id/status` as a one-shot endpoint. Same pattern: capture before, mutate, log with from/to metadata.

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

```sql
-- Postgres allows in-place enum additions; "ADD VALUE IF NOT EXISTS" is idempotent
-- so re-running the migration during dev won't fail.
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_CREATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_DELETED';
```

And in `schema.prisma`, append the new members to the `enum AuditAction { ... }` block and re-run `bunx prisma generate` so the client picks up the new `AuditAction` literal types. **Drop the `'NEW_VALUE' as never` cast pattern** in `logEvent()` once the schema is updated.

### 8d. Pitfall: `request` parameter on Elysia handlers

Elysia auto-injects `request` (the standard `Request` object) into every handler — just destructure it. **But** TypeScript won't know about it without a cast. Pragmatic fix: just write `async ({ ..., userId, request }) => { ... }` and ignore the LSP squiggle. Bun runtime is happy.

### 8e. Pitfall: Adding a new permission to `PERMISSIONS` map is NOT enough (Lesson 2026-06-07, refined 2026-06-09)

**問題**:新增 `ai-config:read` / `ai-config:update` permission 之後,backend route 用 `requirePermission('ai-config:read')` 仲係返 **403 Forbidden** for admin。**原因**:DB-driven RBAC 入面,permissions 有 3 個 layer 全部要 sync:

1. **`packages/shared/src/permissions.ts` 個 `PERMISSIONS` const** — 個 type / runtime array
2. **`packages/shared/src/permissions.ts` 個 `ROLE_PERMISSIONS` map** — 每個 role 配咩 permission
3. **`role_permissions` 個 DB table** — 真正 runtime check 用嘅 source of truth

**只改 (1) + (2) 唔夠** — backend `userHasPermission` 從 DB table 拎,DB 冇 row 即係 false。

**3 個 fix approach**(揀邊個視乎 situation):

| Approach | 動作 | 適合 |
|---|---|---|
| **A. 改 `seed.ts`** | 加新 permission 入 ADMIN 個 set,`prisma db seed` 覆蓋 | 開發早期 / DB reset OK |
| **B. 直接 DB INSERT** | `INSERT INTO role_permissions ...` 配返 `prisma migrate dev` 嘅 `_prisma_migrations` | DB 有 prod data,**唔可以 reset** — **推薦** |
| **C. 用 admin UI** | 透過 `/admin/roles` 嘅 role edit dialog 加新 permission | 經常有新 permission |

**Quick DB INSERT recipe**(approach B, crm-system 2026-06-07 用過):

```sql
-- 1. 揾 admin role 個 ID
SELECT id FROM roles WHERE name = 'ADMIN';
-- 假設: role_admin_system_001

-- 2. 確認個 permission 唔存在(防 duplicate)
SELECT permission FROM role_permissions
WHERE "roleId" = 'role_admin_system_001' AND permission LIKE 'ai-config%';
-- 0 rows = 可以加

-- 3. INSERT
INSERT INTO role_permissions (id, "roleId", permission, "createdAt")
VALUES (
  'rpx_' || md5(random()::text),  -- 任何 unique cuid-ish
  'role_admin_system_001',
  'ai-config:read',
  NOW()
);
-- 重複做一次 for 'ai-config:update'
```

**Long-term fix**:**`seed.ts` 入面建立 `applyPermissionMap()` helper**,每次 `prisma db seed` 自動 reconcile `ROLE_PERMISSIONS` map 同 `role_permissions` table — DELETE 走 missing,INSERT 新增。咁將來新 permission 自動 apply。

**Smoke 確認 step**(任何 RBAC 改動之後必跑):

```bash
# 1. Login 取 admin token
TOKEN=***" | jq -r .token)

# 2. Hit 個受影響 endpoint
curl -s -X GET http://localhost:3001/ai/config \
  -H "Authorization: Bearer *** 期望: 200(已 add permission)或 403(仍缺) — 用呢個做 binary check
```

**教訓 checklist**(新增 permission 時必做):
- [ ] `PERMISSIONS` const 加咗
- [ ] `ROLE_PERMISSIONS` map 對應 role 加咗(eg. ADMIN set)
- [ ] **`role_permissions` DB table 有 INSERT**(最常漏)
- [ ] Smoke 跑 endpoint 確認 200
- [ ] 寫 `REGRESSION-GUARD.md` entry 紀錄 permission 名 + admin role ID

## See also

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)
- `prisma-sqlite-bun-setup` — SQLite 用 string 取代 enum 嘅 workaround
- `ai-agent-tool-calling` — AI agent 嘅 `audit` permissions (e.g. chat 唔可以 read audit)

---

# Day 7 Upgrade Path: From Option 3 → DB-driven RBAC (Option 2)

If the user later wants **admin-managed roles** (create/edit/delete custom roles beyond the 3 system ones), upgrade the architecture from Option 3 (hard-coded roles) to Option 2 (DB-driven). This is what crm-system did on 2026-06-05.

## When to trigger this upgrade

User says: "可以畀 admin 動態加新 role", "我哋有第 4 個 custom role (e.g. 'Senior Sales')", "權限要可以單獨 toggle 唔係全 set 取代", "RBAC 唔好用 hard-code, 我哋係 SaaS 要 multi-tenant 化".

## What changes (4 pieces)

### 1. Schema additions

```prisma
model Role {
  id          String   @id @default(cuid())
  name        String   @unique           // "ADMIN" | "SALES" | "VIEWER" | custom
  description String?
  isSystem    Boolean  @default(false)   // true for the 3 seed roles (cannot delete)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  permissions RolePermission[]
  users       User[]

  @@index([name])
  @@map("roles")
}

model RolePermission {
  id         String @id @default(cuid())
  roleId     String
  role       Role   @relation(fields: [roleId], references: [id], onDelete: Cascade)
  permission String                       // e.g. "quotation:delete"

  @@unique([roleId, permission])
  @@index([roleId])
  @@map("role_permissions")
}

model User {
  // ... existing fields ...
  // Switch FROM: role UserRole @default(SALES)
  // Switch TO:
  roleId  String?
  role    Role?    @relation(fields: [roleId], references: [id], onDelete: SetNull)
  roleLegacy  UserRole  @default(SALES)  // keep for migration backfill; can drop later
  // ...
}
```

The `UserRole` enum (ADMIN/SALES/VIEWER) is **kept** as a legacy field during migration but should no longer be the source of truth. `roleId` FK is the truth.

### 2. Migration: seed system roles + backfill

In the migration SQL:

```sql
-- 1. Create new tables
CREATE TABLE "roles" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL UNIQUE,
  "description" TEXT,
  "isSystem" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "role_permissions" (
  "id" TEXT PRIMARY KEY,
  "roleId" TEXT NOT NULL REFERENCES "roles"("id") ON DELETE CASCADE,
  "permission" TEXT NOT NULL,
  UNIQUE("roleId", "permission")
);

ALTER TABLE "users" ADD COLUMN "roleId" TEXT REFERENCES "roles"("id") ON DELETE SET NULL;
CREATE INDEX "users_roleId_idx" ON "users"("roleId");

-- 2. Seed 3 system roles from the same PERMISSIONS map in shared/
--    (Use your app's PERMISSIONS const + the 3 ROLE_PERMISSIONS sets.)
--    Example for ADMIN: all 27 permissions.
INSERT INTO "roles" (id, name, description, "isSystem", "createdAt", "updatedAt") VALUES
  ('seed_admin',  'ADMIN',  'System administrator',           true, NOW(), NOW()),
  ('seed_sales',  'SALES',  'Sales person (read+write most)', true, NOW(), NOW()),
  ('seed_viewer', 'VIEWER', 'Read-only access',               true, NOW(), NOW());

-- 3. Seed role_permissions from ROLE_PERMISSIONS map (one INSERT per role)
-- Example for ADMIN: insert 27 rows
INSERT INTO "role_permissions" (id, "roleId", permission)
  SELECT 'rp_' || md5('admin_' || perm), 'seed_admin', unnest(ARRAY[
    'user:read','user:create','user:update','user:delete',  -- ... all 27
  ]);

-- 4. Backfill existing users
UPDATE "users" SET "roleId" = 'seed_admin'  WHERE "role" = 'ADMIN';
UPDATE "users" SET "roleId" = 'seed_sales'  WHERE "role" = 'SALES';
UPDATE "users" SET "roleId" = 'seed_viewer' WHERE "role" = 'VIEWER';
```

After this, **every protected route still works** because the role-by-name map mirrors the seeded data. But the architecture is now ready for admin UI to manage custom roles.

### 3. Backend: `requirePermission` → DB lookup with cache

Replace the hard-coded `can()` call with a DB query. **Critical pattern: cache 5 min, clear on role update.**

```typescript
// apps/api/src/middleware/rbac.ts
import { Elysia } from 'elysia';
import { prisma } from '@crm/db';
import { jwtVerify } from 'jose';                    // see "Elysia 1.2 derive context" below

const CACHE_TTL_MS = 5 * 60 * 1000;
const cache = new Map<string, { perms: Set<string>; expiresAt: number }>();

async function loadRolePermissions(roleId: string): Promise<Set<string>> {
  const cached = cache.get(roleId);
  if (cached && cached.expiresAt > Date.now()) return cached.perms;
  const rows = await prisma.rolePermission.findMany({
    where: { roleId }, select: { permission: true },
  });
  const set = new Set(rows.map((r) => r.permission));
  cache.set(roleId, { perms: set, expiresAt: Date.now() + CACHE_TTL_MS });
  return set;
}

export function clearRoleCache(roleId?: string) {
  if (roleId) cache.delete(roleId);
  else cache.clear();
}

export async function userHasPermission(userId: string, perm: string): Promise<boolean> {
  const u = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, role: true },           // role is the legacy enum for fallback
  });
  if (!u) return false;
  let roleId = u.roleId;
  if (!roleId) {                                    // legacy backfill path
    const r = await prisma.role.findUnique({ where: { name: u.role } });
    if (!r) return false;
    roleId = r.id;
  }
  return (await loadRolePermissions(roleId)).has(perm);
}
```

**Call `clearRoleCache(roleId)` from the role-update endpoint** so admin edits take effect instantly without waiting for TTL. The 5-min TTL is the safety net.

### 4. Admin API: `routes/roles.ts`

| Method | Path | Purpose |
|---|---|---|
| GET | `/roles` | List all roles with permission count |
| GET | `/roles/permissions` | Flattened list of all 27 known permission keys (for matrix UI) |
| GET | `/roles/:id` | Single role with full permission list |
| POST | `/roles` | Create custom role (isSystem: false) — system roles cannot be created via this |
| PATCH | `/roles/:id` | Update name/permissions; call `clearRoleCache(id)` after success |
| DELETE | `/roles/:id` | Only if `isSystem: false`; reassign all users with that roleId to SALES first |

The 27 permission keys come from `packages/shared/src/permissions.ts`. Export a helper for the matrix UI:

```typescript
// packages/shared/src/index.ts
import { PERMISSIONS } from './permissions';
export * from './permissions';

/** Flattened list of all permission keys — used by /api/roles/permissions */
export const ALL_PERMISSIONS: readonly string[] = Object.freeze(
  Object.keys(PERMISSIONS)
);
```

> ⚠️ Bun runtime gotcha (see "Bun export * + same-file const" section below): if a sibling file does `import { PERMISSIONS } from './permissions'` AND `export * from './permissions'` in the same re-export file, **Bun may fail to resolve PERMISSIONS at runtime** with `ReferenceError: PERMISSIONS is not defined`. Always `import { PERMISSIONS } from './permissions'` explicitly in the consuming file, then re-export. Don't rely on the `export *` chain alone.

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

Elysia 1.2 d.ts makes it look like it should work (the type signature is there), but at runtime the derive context is dropped when crossing plugin boundaries. This is **different** from the singleton-mismatch problem in `elysia-jwt-plugin-singleton` (that one is about multiple JWT instances; this is about plugin-boundary derive propagation).

**The fix**: extract `userId` from the raw `Request` headers and re-verify the JWT inside the middleware itself. Don't rely on the upstream derive.

```typescript
// ✅ WORKS — re-verify JWT in-place using the same secret
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

**Why `jose` directly (not `@elysiajs/jwt`)?**

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

**Symptom signature for this gotcha**:
- All routes return 401 (Unauthorized), even admin users with valid tokens
- `/api/products` (or any unprotected route) works fine
- API logs show no error — the middleware silently returns null userId
- Bun logs `[rbac] no auth header` → fixes auth header but still 401 → confirms derive context loss
- This is NOT the same as `elysia-jwt-plugin-singleton` (that one fails with `Bad JWT issued by different instance`)

## Step 10: Bun runtime gotcha — `export *` + same-file const reference

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

## Step 11: Prisma enum + JSON polymorphism — the `as never` cast pattern

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

## Step 12: Pitfall summary (Day 7 additions)

### 8f. Pitfall — Token-claim privilege escalation via DB-vs-token role (TD-011, pm-system 2026-06-08)

**場景**:`backend/src/index.ts` 嘅 derive hook 喺解析 `Authorization: Bearer <userId:role>` token 嗰陣,**用 `role` 從 token 字串攞(非 DB 攞)**。Client 可以隨意 claim role:

```typescript
// ❌ BROKEN — role 從 token 字串攞,client 寫 ':admin' 即 claim admin perms
const [userId, role] = token.split(':')
const permissions = role ? await loadRolePermissionsForRole(role) : []
// → 即使 user 真實係 dev,token 寫 ':admin' 即管到 admin endpoint
```

**症狀**:
- **Fake UUID token**:`Bearer 00000000-0000-0000-0000-000000000000:admin` POST `/api/projects` 過 RBAC check,落到 `prisma.project.create({ createdById: 'fake' })` 撞 FK → 500
- **Token claim privilege escalation**:dev user 攞自己真實 UUID,改 token 寫 `:admin` → claim admin perms,access admin endpoint

**Fix**(derive hook 加 user existence check + role 從 DB 攞):

```typescript
// ✅ CORRECT — dbUser 必須真實存在,role 必須由 DB 攞
try {
  const [userId, tokenRole] = token.split(':')           // tokenRole 只係 fallback hint
  if (!userId) return { user: null }

  const dbUser = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, role: true },
  })
  if (!dbUser) return { user: null }                      // ← fake UUID → graceful null

  const permissions = await loadRolePermissionsForRole(dbUser.role)  // ← DB 真相,never trust client
  return { user: { id: dbUser.id, role: dbUser.role, permissions } }
} catch (e) {
  console.error('[auth] derive failed:', e)
  return { user: null }
}
```

**3 個唔可以 miss 嘅 line**:
- `if (!dbUser) return { user: null }` — 守住 fake UUID
- `loadRolePermissionsForRole(dbUser.role)` 而唔係 `role` — 守住 token claim 提權
- `id: dbUser.id` 而唔係 `id: userId` — 對齊 DB reality

**同 seed coverage pitfall (Step 8e) 嘅關係**:
- **Step 8e**(seed 冇 write RolePermission row)→ 所有 user 包括 admin 收 403
- **呢個 (8f)**(role 從 token 攞)→ 所有 user 可以 claim 任何 role 包括 admin
- 兩個 pitfall 方向**完全相反**,但都係「**DB 真相 vs 來源失控**」嘅變奏

**Lesson**:**derive hook / auth middleware 嘅 role 必須由 DB 攞(never trust client)**。任何 token 字串入面嘅 claim,只可以做 hint,唔可以做 source of truth。

完整 reproduce + RG-006 entry + 全部 patch 見 `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md`。

## Step 9: Elysia 1.2 plugin-boundary derive loss — use `getUserIdFromRequest` re-verifying with `jose` directly, not the `jwt()` factory. Affects EVERY plugin that needs `userId` from another plugin.
2. **Bun `export *` + same-file const** (Step 10): explicit import + re-export. Affects barrel files that derive new exports from re-exported consts.
3. **Prisma `as never` for enum + JSON** (Step 11): the workhorse cast for polymorphic writes.
4. **`@elysiajs/jwt` standalone `.verify` is not a function** (Step 9): use `jose.jwtVerify` instead. Easy to assume the factory returns a usable verifier; it doesn't.
5. **Cache invalidation in RBAC** (Step 3): call `clearRoleCache(roleId)` after every role update. The 5-min TTL is the safety net, not the primary mechanism.

## Step 14: `requirePermission` with `as: 'scoped'` only applies to the NEXT verb (Day 14 lesson, crm-system 2026-06-07)

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

**Expected output for a fully-gated file**: `verbs==perms` (one perms per verb, no top-level gate). **If `perms < verbs`** → suspect public endpoints → read the file and confirm.

**Symptom signature** (how this manifests in production):
- `curl http://api.example.com/deals` returns a JSON list of every deal in the DB
- `curl -X POST http://api.example.com/companies -d '{"name":"X"}'` succeeds with 201 and `actorId=null` in the audit log
- No build error, no test failure — this is a **silent authorization bypass** caught only by manual code review or authz-aware integration tests

**Mitigation options** (pick one when the codebase already has these gaps):

| Option | What it does | Trade-off |
|---|---|---|
| **Per-verb `.use()`** (recommended) | Manual fix per endpoint, no plugin change | Tedious for big files, but explicit and audit-friendly |
| **Switch `as: 'scoped'` → `'global'`** in `requirePermission` | One `.use()` covers all verbs | Easy, but couples the permission choice to the whole file (you can't have `GET /` need `read` and `POST /` need `create` with the same gate) |
| **Route-grouping via sub-Elysia** | `.group('/companies', (app) => app.use(...).get(...).post(...))` | Cleanest for new code, refactor cost for existing |

For a one-time P0 fix-batch on existing code, **per-verb `.use()`** is fastest and most explicit. For new code, **route grouping** is the cleaner pattern.

## Step 15: Boot-time JWT_SECRET hard-fail template (Day 14 P0-4, crm-system 2026-06-07)

**The trap**: Elysia + `@elysiajs/jwt` config usually looks like:

```ts
// ❌ SILENTLY BOOTS WITH A KNOWN-WEAK SECRET
.use(jwt({ name: 'jwt', secret: process.env.JWT_SECRET ?? 'dev-only-secret-please-change' }))
```

If the env var is missing in production, the API starts up with the literal fallback string. Anyone reading the public source repo can forge tokens. **There is no warning.**

**Fix**: hard-fail at the top of `index.ts`, BEFORE the Elysia instance is constructed:

```ts
// apps/api/src/index.ts — top of file, before any import that uses JWT
const JWT_SECRET=proces...
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required. Refusing to boot.');
}
if (JWT_SECRET.length < 32) {
  throw new Error(`JWT_SECRET must be at least 32 characters (got ${JWT_SECRET.length}). Generate one with: openssl rand -hex 32`);
}
if (process.env.NODE_ENV === 'production' && JWT_SECRET=*** 'dev-only-secret-please-change') {
  throw new Error('Refusing to boot: JWT_SECRET is set to the dev-only fallback in production.');
}

// ...later...
.use(jwt({ name: 'jwt', secret: JWT_SECRET }))    // ← no ?? fallback anymore
```

**Why 32 chars**: 32 random hex chars = 128 bits of entropy, which matches `aes-256-gcm` and is the minimum most JWT libraries consider "strong" for HS256. Below that, the secret is brute-forceable offline given any leaked token.

**Smoke verification recipe** (3 cases, must throw):

```bash
# 1. short secret
JWT_SECRET=*** /tmp/test-jwt.ts
# → error: JWT_SECRET must be at least 32 characters (got 5).

# 2. dev fallback in production
JWT_SECRET=dev-on...ange NODE_ENV=production bun /tmp/test-jwt.ts
# → error: JWT_SECRET must be at least 32 characters (got 29).
#    (length check fires first; both checks throw which is fine)

# 3. valid
JWT_SECRET=*** rand -hex 32> bun /tmp/test-jwt.ts
# → OK boot, secret length: 64 env: development
```

**Caveat — Bun `--env-file` shadowing**: if you test with `bun --env-file=.env`, the shell `JWT_SECRET=*** override` does NOT take precedence — Bun loads the .env file values as the floor. To test the failure path, write a temp env file with a short secret, then run `bun --env-file=/tmp/crm-env-weak src/index.ts`. This bit me in crm-system Day 14 — wasted 2-3 smoke attempts before isolating.

**Same pattern for other secrets**: `AI_CONFIG_ENCRYPTION_KEY` (must be 32-byte hex, `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`) and any `*_SECRET` / `*_KEY` env var deserves the same 3-condition check. Encapsulate as a `requireSecret(name, opts)` helper if you have more than 2:

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

**Interpretation**:

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

**This recipe surfaces the entire attack surface in one command.** Save it as `scripts/audit-public-routes.sh` and wire it into pre-deploy smoke.

## See also

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `references/p0-public-routes-audit-recipe.md` — full audit + fix-batch workflow for finding and gating public endpoints (Day 14, crm-system 2026-06-07)
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)
- `templates/require-secret.ts` — Step 15 boot-time secret validator
- `prisma-sqlite-bun-setup` — SQLite 用 string 取代 enum 嘅 workaround
- `ai-agent-tool-calling` — AI agent 嘅 `audit` permissions (e.g. chat 唔可以 read audit)

## Step 13: Role name invariant — UPPERCASE + displayName 分離 (2026-06-06 真實撞牆, smoke test 揭發)

`POST /roles` 嘅 `name` field 喺 crm-system 強制 **UPPERCASE 內部 identifier** (`ADMIN` / `SALES` / `VIEWER` / `SMOKE_TEST_ROLE`),而 `displayName` 先係 user-facing 中文/英文混合。Backend check 喺 `apps/api/src/routes/roles.ts` line 72 附近:

```typescript
if (data.name !== data.name.toUpperCase()) {
  set.status = 400;
  return { error: 'Role name must be UPPERCASE (e.g. SENIOR_SALES)' };
}
```

呢個 invariant 嘅**對應 frontend form 一定要 mirror**,否則 user 填「Senior Sales」會凍住冇 feedback:

```tsx
// apps/web/src/components/role-dialog.tsx — 必須 UPPERCASE 化
<Input
  value={name}
  onChange={(e) => setName(e.target.value.toUpperCase().replace(/\s+/g, '_'))}
  placeholder="e.g. SENIOR_SALES"
/>
// 仲要喺 submit 前:
// if (name !== name.toUpperCase()) setError('內部名稱必須大寫');
```

**Smoke test 揭發嘅 bug sequence** (crm-system 2026-06-06):
1. Click「新增自訂角色」→ dialog 開,counter「0 個已選」
2. 填 `name="Smoke Test Role"`,勾 4 個 permission
3. Click「建立」→ **dialog 凍住**:冇 spinner,冇 error banner,冇 toast,console 乾淨
4. 背後:`POST /roles` 返 400(lowercase reject),`useMutation.onError` **冇 render error state**(debug 細節見 `visual-ui-bug-debugging` skill 嘅「Backend Invariant Silent-Fail」section)
5. **Bypass UI direct API probe 確認 backend 正常**:
   ```bash
   docker exec crm-api sh -c 'cat > /tmp/probe.mjs << "EOF"
   const login = await fetch("http://localhost:3001/auth/login", {
     method: "POST", headers: { "Content-Type": "application/json" },
     body: JSON.stringify({ email: "admin@crm.local", password: "admin123" })
   });
   const { token } = await login.json();
   const r = await fetch("http://localhost:3001/roles", {
     method: "POST",
     headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
     body: JSON.stringify({ name: "SMOKE_TEST_ROLE", displayName: "Smoke Test Role", ... })
   });
   console.log("status:", r.status, "body:", await r.text());
   EOF
   node /tmp/probe.mjs'
   # → 201 + 完整 record
   ```
6. **清理**:`DELETE /roles/:id` 將 smoke test 整出嚟嘅 row 移除,**避免污染 prod DB**

**Lesson 3 條 invariant checklist**(任何 backend 強制嘅 invariant, frontend form 必 mirror):
1. **Format invariant**(`UPPERCASE` / `slug` / `email`) → input `onChange` 即時 transform + Zod schema `.regex()`
2. **Length invariant**(`minLength` / `maxLength`) → input `maxLength` + Zod schema
3. **Enum invariant**(`role: 'ADMIN' | 'SALES'`) → 用 `<Select>` 而唔係 `<Input>`,submit 前 check 個 value 喺 enum 內

**Frontend 必用 toast library**(eg. `sonner` / `react-hot-toast`),`onError` 唔可以淨 render inline `<p>`(太易被 dialog 高度 ignore):
```tsx
const onError = (e: Error) => {
  toast.error(parseApiError(e));      // ← 必 user-visible
  setError(parseApiError(e));          // ← inline 輔助
};
### 8d. Pitfall: `request` parameter on Elysia handlers

Elysia auto-injects `request` (the standard `Request` object) into every handler — just destructure it. **But** TypeScript won't know about it without a cast. Pragmatic fix: just write `async ({ ..., userId, request }) => { ... }` and ignore the LSP squiggle. Bun runtime is happy.

### 8e. Pitfall: Adding a new permission to `PERMISSIONS` map is NOT enough (Lesson 2026-06-07, refined 2026-06-09)

**問題**:新增 `ai-config:read` / `ai-config:update` permission 之後,backend route 用 `requirePermission('ai-config:read')` 仲係返 **403 Forbidden** for admin。**原因**:DB-driven RBAC 入面,permissions 有 3 個 layer 全部要 sync:

1. **`packages/shared/src/permissions.ts` 個 `PERMISSIONS` const** — 個 type / runtime array
2. **`packages/shared/src/permissions.ts` 個 `ROLE_PERMISSIONS` map** — 每個 role 配咩 permission
3. **`role_permissions` 個 DB table** — 真正 runtime check 用嘅 source of truth

**只改 (1) + (2) 唔夠** — backend `userHasPermission` 從 DB table 拎,DB 冇 row 即係 false。

**3 個 fix approach**(揀邊個視乎 situation):

| Approach | 動作 | 適合 |
|---|---|---|
| **A. 改 `seed.ts`** | 加新 permission 入 ADMIN 個 set,`prisma db seed` 覆蓋 | 開發早期 / DB reset OK |
| **B. 直接 DB INSERT** | `INSERT INTO role_permissions ...` 配返 `prisma migrate dev` 嘅 `_prisma_migrations` | DB 有 prod data,**唔可以 reset** — **推薦** |
| **C. 用 admin UI** | 透過 `/admin/roles` 嘅 role edit dialog 加新 permission | 經常有新 permission |

**Quick DB INSERT recipe**(approach B, crm-system 2026-06-07 用過):

```sql
-- 1. 揾 admin role 個 ID
SELECT id FROM roles WHERE name = 'ADMIN';
-- 假設: role_admin_system_001

-- 2. 確認個 permission 唔存在(防 duplicate)
SELECT permission FROM role_permissions
WHERE "roleId" = 'role_admin_system_001' AND permission LIKE 'ai-config%';
-- 0 rows = 可以加

-- 3. INSERT
INSERT INTO role_permissions (id, "roleId", permission, "createdAt")
VALUES (
  'rpx_' || md5(random()::text),  -- 任何 unique cuid-ish
  'role_admin_system_001',
  'ai-config:read',
  NOW()
);
-- 重複做一次 for 'ai-config:update'
```

**Long-term fix**:**`seed.ts` 入面建立 `applyPermissionMap()` helper**,每次 `prisma db seed` 自動 reconcile `ROLE_PERMISSIONS` map 同 `role_permissions` table — DELETE 走 missing,INSERT 新增。咁將來新 permission 自動 apply。

**Smoke 確認 step**(任何 RBAC 改動之後必跑):

```bash
# 1. Login 取 admin token
TOKEN=***" | jq -r .token)

# 2. Hit 個受影響 endpoint
curl -s -X GET http://localhost:3001/ai/config \
  -H "Authorization: Bearer *** 期望: 200(已 add permission)或 403(仍缺) — 用呢個做 binary check
```

**教訓 checklist**(新增 permission 時必做):
- [ ] `PERMISSIONS` const 加咗
- [ ] `ROLE_PERMISSIONS` map 對應 role 加咗(eg. ADMIN set)
- [ ] **`role_permissions` DB table 有 INSERT**(最常漏)
- [ ] Smoke 跑 endpoint 確認 200
- [ ] 寫 `REGRESSION-GUARD.md` entry 紀錄 permission 名 + admin role ID

## See also

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Step 9
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template (Step 9 + Step 3)
