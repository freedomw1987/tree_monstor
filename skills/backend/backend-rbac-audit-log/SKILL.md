---
name: backend-rbac-audit-log
description: "Add role-based access control (RBAC) + audit log to any backend API (Elysia, Express, Fastify, Hono, NestJS). Pattern: centralized permission map in shared package + middleware `requirePermission()` plugin + `AuditLog` table with action enum + auto-capturing `logEvent()` helper that grabs user/IP/UA without throwing. Use when user says 'user management', 'roles and permissions', 'audit log', 'who did what when', 'activity history', 'compliance log', or wants admin functionality (CRUD users, reset passwords, view who-changed-what). Pairs naturally with `crm-data-model` for CRM/sales tools."
tags: ["rbac", "audit", "permissions", "auth", "admin", "backend", "security", "elysia", "express"]
applicability: generic-pattern
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

> Project-specific 選 Option 3 嘅 crm-system Day 5 (2026-06-05) 重現細節:見 [`references/crm-permission-enum-map.md`](references/crm-permission-enum-map.md)。

## 完整架構 (4 個 piece)

```
┌─────────────────────────────────────────────────────┐
│ packages/shared/src/permissions.ts  ←  single source of truth │
│   - N permission string literals (依 use case 加)    │
│   - M roles  map 到 permission set                    │
│   - can(role, 'resource:action')  helper              │
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
    │ routes/<resource>.ts     │
    │ .use(requirePermission()) │
    │ logEvent(ACTION,...)     │
    └──────────┬───────────────┘
               ▼
       ┌──────────────────┐
       │ AuditLog table   │  ← Prisma schema + migration
       │ + AuditAction enum │
       └──────────────────┘
```

## Step 1: Permission map (general shape)

```typescript
// packages/shared/src/permissions.ts
// SINGLE SOURCE OF TRUTH — used by both backend (for requirePermission)
// and frontend (for hiding nav / disabling buttons).

export type Permission =
  | 'user:read' | 'user:create' | 'user:update' | 'user:delete' | 'user:reset_password'
  | 'audit:read'
  // add resource-specific perms: '<resource>:<action>' strings
  ;

export const PERMISSIONS = [
  'user:read', 'user:create', 'user:update', 'user:delete', 'user:reset_password',
  'audit:read',
  // mirror the type literal above as a runtime array
] as const;

export type UserRole = 'ADMIN' | 'MEMBER' | 'VIEWER'; // pick role names for your domain

const ROLE_PERMISSIONS: Record<UserRole, Set<Permission>> = {
  ADMIN: new Set<Permission>(PERMISSIONS),   // everything
  MEMBER: new Set<Permission>([/* role-specific subset */]),
  VIEWER: new Set<Permission>([/* read-only subset */]),
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

**Frontend** 用同一份 map 嚟 hide nav / disable button:
```typescript
import { can } from '<your-shared-package>';
{can(user.role, 'user:create') && <Button>新增用戶</Button>}
```

> 完整 crm-system 30+ permission 嘅 verbatim example 見 [`references/crm-permission-enum-map.md`](references/crm-permission-enum-map.md)。

## Step 2: AuditLog table (general shape)

```prisma
// packages/db/prisma/schema.prisma
enum AuditAction {
  // Auth lifecycle
  USER_LOGIN USER_LOGIN_FAILED USER_LOGOUT PASSWORD_CHANGED
  // User mgmt (admin)
  USER_CREATED USER_UPDATED USER_DEACTIVATED USER_REACTIVATED USER_DELETED PASSWORD_RESET
  // + your resource actions: <RESOURCE>_CREATED / _UPDATED / _DELETED / _STATUS_CHANGED
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
> **Migrations behind Docker**: 當 Postgres 唔 expose host port,host 跑 `prisma migrate dev` 撞 `Can't reach database server` — 解決方法見 [`references/docker-postgres-migration-trick.md`](references/docker-postgres-migration-trick.md)。

## Step 3: audit middleware (logEvent helper)

```typescript
// apps/api/src/middleware/audit.ts
import type { Context } from 'elysia';
import { prisma } from '<your-db-package>';
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
import { can, type Permission } from '<your-shared-package>';

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

> 預設 `userId` / `userRole` 由 `authContext` derive 提供。Elysia 1.2 d.ts noise 同 `request` parameter cast 等 framework 細節:見 [`references/elysia-bun-runtime-gotchas.md`](references/elysia-bun-runtime-gotchas.md)。

## Step 5: Apply requirePermission + logEvent in resource routes

The pattern: every write handler ends with a `logEvent()` call after the mutation, with `request` for IP/UA capture.

```typescript
.post('/', async ({ body, set, userId, request }) => {
  const created = await prisma.<resource>.create({ data: body as never });
  set.status = 201;
  await logEvent({                              // ← always after the mutation
    action: '<RESOURCE>_CREATED',
    actorId: userId ?? null,
    resourceType: '<resource>',
    resourceId: created.id,
    description: `Created <resource> ${created.name}`,
    metadata: { /* key fields */ },
    request,                                    // ← real request → IP + UA captured
  });
  return created;
}, { /* body validation */ })
```

Same shape for `PATCH` and `DELETE`. For status-change vs general update (e.g. quotation status), branch on the changed field and log as **different actions** so the audit page can colour-code properly.

完整 crm-system CRUD 嘅 3-line pattern + `as never` cast 細節:見 [`references/crm-audit-log-implementation.md`](references/crm-audit-log-implementation.md)。

## Step 6: Instrument login / change-password

Auth lifecycle endpoints don't go through `requirePermission` (they ARE the auth surface), but they should still emit audit events:

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
import { prisma } from '<your-db-package>';
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

## ⚠️ General pitfalls (cross-stack)

### 1. **Audit failure 唔可以 break user request**

`logEvent()` 一定要 try/catch 內部吞 error。Audit log 唔係 critical path,如果 DB query fail 唔應該 reject login。

### 2. **Last-admin / self-protection 係 RBAC 嘅必要 invariant**

唔可以用 `if (userId === targetUserId && targetUserId.role === 'ADMIN')` 之類嘅 JS 邏輯,**要 count actual admins in DB**。否則 race condition 會撞到(s兩個 admin 同時 demote 對方)。Mirror block: admin cannot deactivate self; cannot demote/deactivate/delete the last admin.

### 3. **Frontend 唔好用 localStorage cache role**

每次 navigate 用 `useAuth()` 即時攞最新 user。否則 promote 完 user 仲見到舊 role。

### 4. **Backend invariants must mirror in the frontend form**

If the backend rejects lowercase role names (or any format invariant), the form's `onChange` must transform input **and** the submit handler must show errors via a toast (not inline `<p>` — too easy to hide behind dialog chrome). The crm-system Day 14 incident where `POST /roles` returned 400 and the dialog froze silently: see [`references/crm-role-name-invariant-2026-06-06.md`](references/crm-role-name-invariant-2026-06-06.md).

### 5. **Cross-layer permission sync (DB-driven RBAC)**

Once you upgrade from Option 3 to Option 2 (DB-driven), `PERMISSIONS` + `ROLE_PERMISSIONS` map + `role_permissions` DB table are 3 layers that all need to be in sync. Adding a permission to the map without inserting the row in the DB gives every admin 403. Full upgrade path + INSERT recipe: see [`references/db-driven-rbac-upgrade-path.md`](references/db-driven-rbac-upgrade-path.md).

### 6. **Auth role must come from DB, never trust client claim**

If your derive hook / auth middleware reads role from a token string (`<userId>:<role>`), the client can claim admin. Always look up `dbUser.role` and reject if `dbUser` doesn't exist. Full reproduction: [`references/pm-system-2026-06-08-td-011.md`](references/pm-system-2026-06-08-td-011.md).

### 7. **`requirePermission` per-verb scope (Elysia 1.2)**

When `requirePermission` is `{ as: 'scoped' }`, `.use(requirePermission('X'))` gates **only the immediately following verb**, not the whole file. For 5-7-verb route files this leaves 4-6 endpoints silently public. Use per-verb `.use()` or route grouping. Full recipe: [`references/crm-day-14-audit-results.md`](references/crm-day-14-audit-results.md) + [`references/p0-public-routes-audit-recipe.md`](references/p0-public-routes-audit-recipe.md).

## Audit-coverage checklist (for any backend)

| Endpoint | Action enum members |
|---|---|
| `POST /auth/login` (failed + success) | `USER_LOGIN`, `USER_LOGIN_FAILED` |
| `POST /users`, `PATCH /:id`, `DELETE /:id` | `USER_CREATED`, `USER_UPDATED`, `USER_DEACTIVATED`, `USER_REACTIVATED`, `USER_DELETED` |
| `POST /users/:id/reset-password` | `PASSWORD_RESET` |
| `POST /users/:id/change-password` (self) | `PASSWORD_CHANGED` |
| `POST /auth/logout` | `USER_LOGOUT` |
| For each `<resource>` CRUD: `POST`, `PATCH`, `DELETE` | `<RESOURCE>_CREATED`, `<RESOURCE>_UPDATED`, `<RESOURCE>_DELETED` |
| For each status-transition (PATCH or one-shot endpoint) | `<RESOURCE>_STATUS_CHANGED` |

**Pre-declare all the obvious ones** in the original migration so the first build is clean. **But** it's fine (and common) to add new enum members in a later migration when a new feature ships — Postgres supports `ALTER TYPE ... ADD VALUE` in place, and Prisma's `@default` doesn't break if you only append values. Use `ADD VALUE IF NOT EXISTS` for idempotent dev reruns.

## 何時用呢個 skill vs 簡單 auth-only

| 場景 | 用呢個 skill? |
|---|---|
| User 話「加 user management」+「audit log」 | ✅ 用 |
| User 話「加 RBAC」但冇提及 audit | ✅ 用(Option 3 預埋 audit hook) |
| User 話「淨係加密碼改」 | ❌ 唔需要,simple route 就夠 |
| User 用 JWT 第三方 auth (Auth0 / Clerk) | ❌ 唔需要,audit log 喺 provider 已有 |

## Upgrade path: Option 3 → Option 2 (DB-driven RBAC)

When the user asks for admin-managed roles ("可以畀 admin 動態加新 role", "我哋有第 4 個 custom role", "RBAC 唔好用 hard-code, 我哋係 SaaS 要 multi-tenant 化"):

1. Add `Role` + `RolePermission` Prisma models + `roleId` FK on `User` (keep `role` enum as `roleLegacy` for backfill).
2. Migration: create tables, seed 3 system roles + permissions from the existing `PERMISSIONS` map, backfill `users.roleId` from `users.role`.
3. Replace `can()` with `userHasPermission()` that loads from DB with a 5-min `Map<roleId, Set<perm>>` cache. Call `clearRoleCache(roleId)` from the role-update endpoint — TTL is the safety net, not the primary mechanism.
4. Add `routes/roles.ts` admin API (GET/POST/PATCH/DELETE with `isSystem` protection on the 3 seed roles).

Full schema + migration SQL + cache implementation + INSERT recipe: [`references/db-driven-rbac-upgrade-path.md`](references/db-driven-rbac-upgrade-path.md).

## See also

- `references/elysia-plugin-boundary-derive.md` — full reproduction recipe and trace logs for Elysia 1.2 plugin-boundary derive context loss
- `references/p0-public-routes-audit-recipe.md` — full audit + fix-batch workflow for finding and gating public endpoints (the `as: 'scoped'` trap)
- `references/crm-permission-enum-map.md` — crm-system 30+ permission enum + 3 roles (verbatim)
- `references/crm-audit-log-implementation.md` — crm-system AuditLog model + CRUD `logEvent()` examples (verbatim)
- `references/crm-day-14-audit-results.md` — Day 14 (2026-06-07) audit run + `as: 'scoped'` lesson
- `references/crm-role-name-invariant-2026-06-06.md` — Day 6 role-name UPPERCASE invariant + frontend mirror pitfall
- `references/pm-system-2026-06-08-td-011.md` — pm-system token-claim privilege escalation P0
- `references/db-driven-rbac-upgrade-path.md` — Option 2 (DB-driven RBAC) schema, migration, cache
- `references/docker-postgres-migration-trick.md` — `docker exec` + manual `_prisma_migrations` insert recipe
- `references/elysia-bun-runtime-gotchas.md` — Elysia 1.2 + Bun: d.ts noise, `export *`, `as never`, `request` parameter
- `references/jwt-secret-boot-validation.md` — `requireSecret()` boot-time hard-fail template
- `templates/role-rbac-migration.sql` — ready-to-run migration for Step 2
- `templates/require-permission-rbac.ts` — the working Elysia plugin template
- `templates/require-secret.ts` — boot-time secret validator
- `scripts/audit-public-routes.sh` — 60-second recipe to find unauthenticated endpoints
- `prisma-sqlite-bun-setup` — SQLite 用 string 取代 enum 嘅 workaround
- `elysia-jwt-plugin-singleton` — multi-instance JWT 嘅 "Bad JWT issued by different instance" 嘅案例
- `crm-data-model` — CRM 數據模型 (use with this skill for CRM-style products)
- `visual-ui-bug-debugging` — backend invariant silent-fail UI debug 方法

---

## Project case history

| Topic | Reference |
|---|---|
| Elysia 1.2 plugin-boundary derive context loss | [`references/elysia-plugin-boundary-derive.md`](references/elysia-plugin-boundary-derive.md) |
| 60-second P0 public-routes audit + per-verb fix | [`references/p0-public-routes-audit-recipe.md`](references/p0-public-routes-audit-recipe.md) |
| CRM-system 30+ permission enum + 3 roles | [`references/crm-permission-enum-map.md`](references/crm-permission-enum-map.md) |
| CRM-system AuditLog + CRUD `logEvent()` examples | [`references/crm-audit-log-implementation.md`](references/crm-audit-log-implementation.md) |
| CRM-system Day 14 public-routes audit run + `as: 'scoped'` trap | [`references/crm-day-14-audit-results.md`](references/crm-day-14-audit-results.md) |
| CRM-system Day 6 role-name UPPERCASE + frontend mirror | [`references/crm-role-name-invariant-2026-06-06.md`](references/crm-role-name-invariant-2026-06-06.md) |
| PM-system 2026-06-08 P0 token-claim privilege escalation | [`references/pm-system-2026-06-08-td-011.md`](references/pm-system-2026-06-08-td-011.md) |
| Option 2 (DB-driven RBAC) schema + migration + cache | [`references/db-driven-rbac-upgrade-path.md`](references/db-driven-rbac-upgrade-path.md) |
| Docker-local Postgres Prisma migration trick | [`references/docker-postgres-migration-trick.md`](references/docker-postgres-migration-trick.md) |
| Elysia 1.2 + Bun runtime gotchas (d.ts, `export *`, `as never`) | [`references/elysia-bun-runtime-gotchas.md`](references/elysia-bun-runtime-gotchas.md) |
| Boot-time JWT_SECRET hard-fail template | [`references/jwt-secret-boot-validation.md`](references/jwt-secret-boot-validation.md) |
| Compressed-out detail (the 16-step path + extra code examples) | [`references/restored-narrative.md`](references/restored-narrative.md) |