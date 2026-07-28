# DB-driven RBAC upgrade path (Option 2) — crm-system Day 7

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body, the "Day 7 Upgrade Path" section
> (schema, migration, backend cache, admin API). The general pattern
> (cache role permissions for ~5min, clear on role update) lives in
> SKILL.md; this file is the full schema + migration SQL + cache
> implementation that crm-system used on 2026-06-05.

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

## Step 9: Elysia 1.2 plugin-boundary derive context — full reproduction

In `requirePermission` defined as an Elysia plugin with `.onBeforeHandle()`, the `ctx` you receive does **NOT** include values derived by other plugins (like the JWT plugin's `userId` derive). The fix is to extract `userId` from the raw `Request` headers and re-verify the JWT inside the middleware itself using `jose.jwtVerify` directly. Full reproduction recipe and trace logs: [`elysia-plugin-boundary-derive.md`](elysia-plugin-boundary-derive.md).

## Cross-layer permission-sync invariant

**3 個 layer 全部要 sync**:
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