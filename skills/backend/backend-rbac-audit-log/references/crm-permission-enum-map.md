# CRM-system Permission & Role Enum Map (verbatim)

> **Source**: extracted byte-identical from the previous `backend-rbac-audit-log`
> body. The general RBAC+audit pattern in SKILL.md is framework-agnostic;
> this file is the **project-specific** enum / role mapping for the CRM
> system (crm-system, 2026-06-05). Use it when reproducing the CRM seed
> or reasoning about the 30+ permission keys, not as a general reference.

---

## Permission enum (verbatim, crm-system 2026-06-05)

```typescript
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

---

## AuditAction enum (verbatim, crm-system Prisma schema)

```prisma
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
```

---

## Append-only enum extension (verbatim, crm-system 20260606120000 migration)

```sql
-- Postgres allows in-place enum additions; "ADD VALUE IF NOT EXISTS" is idempotent
-- so re-running the migration during dev won't fail.
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_CREATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MAN_DAY_ROLE_DELETED';
```

---

## Day 5 decision context (verbatim)

**Day 5 經驗 (crm-system 2026-06-05)**: David 揀 Option 3,1 個 file `packages/shared/src/permissions.ts` 控制晒全部,將來想加粒度都唔使重寫。

> **SQLite 注意**: 冇 enum,用 `String` + Zod/手動 validation。