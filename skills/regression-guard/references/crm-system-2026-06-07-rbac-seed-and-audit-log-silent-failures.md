# crm-system Day 14 — RBAC seed coverage gap + audit log silent failure (TWO PRE-EXISTING CRITICAL BUGS, no RG entries)

**Date**: 2026-06-07
**Project**: `~/www/crm-system`
**Context**: Building Day 14 System Settings feature (SystemConfig table + /api/settings/tax). Discovered TWO class-level pre-existing bugs while writing the seed script for the new permissions.

## Bug 1 — RBAC seed coverage gap (CRITICAL, 100% production impact)

### What is broken

`apps/api/src/middleware/rbac.ts:50-66` `userHasPermission` 真係 query `RolePermission` table。但 `packages/db/prisma/seed.ts` 從來冇 seed 過 `Role` / `RolePermission` rows。**Production 上任何 `requirePermission(...)` gate 都會 silently 403 所有 user**(包括 ADMIN),因為 `loadRolePermissions(roleId)` 永遠 return empty Set。

### Why it wasn't caught earlier

- 2026-06-07 P0-2 security patch 加 `requirePermission('company:read')` 喺 5 個新 route → **本來要封公開 endpoint,但實際封死所有 user**
- 開發人員冇 production-grade smoke test
- `man-day-role.ts:29` comment 直接 acknowledge: *"because the seed script doesn't currently write RolePermission rows"* — 個 project 知道呢個 bug 但冇 RG entry
- **紅線 13 (bug fix 必有 RG entry) 違規** — known bug 冇 entry

### Fix (in commit `818c29f`)

```typescript
// packages/db/prisma/seed.ts — add to main() BEFORE user.create()

const { PERMISSIONS } = await import('@crm/shared/permissions');
const allKeys = Object.keys(PERMISSIONS) as Permission[];
const ROLE_PERMS: Record<string, string[]> = {
  ADMIN:  allKeys,
  SALES:  ['company:read','company:create', ...],  // mirror shared/permissions.ts
  VIEWER: ['company:read','contact:read', ...],
};
for (const roleName of ['ADMIN','SALES','VIEWER'] as const) {
  await prisma.role.create({
    data: {
      name: roleName,
      displayName: '...',
      isSystem: true,
      permissions: { create: ROLE_PERMS[roleName].map((p) => ({ permission: p })) },
    },
  });
}

// Cleanup chain update (FK ordering):
// rolePermission → systemConfig → role → user
```

```typescript
// Then wire User.roleId (optional, but stabilises rbac.ts cache)
const adminRole = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
await prisma.user.create({
  data: { ..., roleId: adminRole?.id, role: 'ADMIN' },
});
```

### Prevention class (must encode in 紅線 11 audit)

For ANY project using rbac.ts / permissions.ts:
1. `rbac.ts` 嘅 read paths → list all
2. `seed.ts` 嘅 write paths → list all
3. 对齐:每条 read 有 write
4. Integration smoke: `bun run db:reset && bun run db:seed && curl ... -H "Authorization: Bearer <admin token>"`
5. CI gate: fail if `rg "prisma.role.create" seed.ts` returns 0 AND project has rbac.ts

## Bug 2 — logEvent API field-name drift (HIGH, every audit log silently fails)

### What is broken

`apps/api/src/middleware/audit.ts:12-20` 嘅 `AuditEvent` interface 係:

```typescript
{ actorId, action: AuditAction, resourceType?, resourceId?, description?, metadata?, request? }
```

但 `apps/api/src/routes/settings.ts:88-95, 166-173, 221-228` 嘅 caller 寫住:

```typescript
await logEvent({
  userId,             // ❌ 應係 actorId
  action: 'CREATE',   // ❌ 應係 AuditAction enum value
  entity: 'PipelineStage',  // ❌ 應係 resourceType
  entityId: stage.id,       // ❌ 應係 resourceId
  description: `...`,
  request,
});
```

每次 audit write → Prisma throw `TypeError: Invalid value` for `action` (since `'CREATE'` is not a valid `AuditAction` enum value) → `try/catch` 喺 `logEvent` 內 swallow 咗 → **audit log 永遠唔 write**。

### Why it wasn't caught

- `@ts-nocheck` 喺 caller 失去 type-check 防線
- 冇 integration test grep `prisma.auditLog.count()` 之後 trigger mutation
- Audit 冇冇 100% write rate 嘅 metric 監控
- `try/catch` 喺 helper 入面 = silent failure by design (good intent, bad observability)

### Detection recipe (10 lines)

```bash
# 1. Find all logEvent call sites
rg "logEvent\({" apps/api/src/routes/

# 2. For each, check field names match AuditEvent interface
#    Expected: actorId, action (typed), resourceType, resourceId
#    Found bugs: userId, action: 'CREATE'/'UPDATE'/'DELETE', entity, entityId
rg "userId.*action.*['\"](CREATE|UPDATE|DELETE)['\"]" apps/api/src/routes/

# 3. If any match → fix to AuditEvent shape, re-test with:
PGPASSWORD=*** -h localhost -U crm -d crm -c \
  "SELECT action, resource_type, actor_id FROM audit_logs ORDER BY created_at DESC LIMIT 5;"
# Expected: action 唔 NULL, actor_id 唔 NULL
```

### Fix in crm-system (still TODO, not in Day 14 commits)

Need to patch `settings.ts:88-95, 166-173, 221-228` to use correct field names AND typed `AuditAction` enum values:

```typescript
// 88-95 should become:
await logEvent({
  actorId: userId,
  action: 'PIPELINE_STAGE_CREATED',  // actual AuditAction value
  resourceType: 'pipeline_stage',
  resourceId: stage.id,
  description: `Created stage "${name}" in pipeline "${pipeline.name}" (position ${nextPosition})`,
  metadata: { name, position: nextPosition, pipelineId: pipeline.id },
  request,
});
```

But wait — `PIPELINE_STAGE_CREATED` 唔喺現有 AuditAction enum! 需 add 入 schema 同 sync 到 `apps/web/src/lib/api.ts` 嘅 `AuditAction` type union(per regression-guard 嘅 Record<EnumType, ...> pitfall)。

## Take-aways for future sessions

1. **Whenever you see `rbac.ts` + a seed script, audit the seed for `Role.create` / `RolePermission.createMany`** — if missing, 100% RBAC broken in production.
2. **Whenever you see `@ts-nocheck` + `logEvent` callers, audit field names** — try/catch swallows errors silently.
3. **Whenever you see a TODO comment in production code** (like `man-day-role.ts:29`), that's a known-bug-without-RG-entry → 紅線 13 違規 → must be tracked.
4. **Pre-existing bugs class:** if a comment in code says "doesn't currently do X" — that's a bug report inline. Search for `currently `, `TODO`, `FIXME`, `XXX` in `apps/api/src/routes/`.
5. **Add a CI check** that greps every `requirePermission(...)` literal and asserts each appears in seed's `ROLE_PERMS` map.

## Related files

- `SKILL.md` §"Pitfall — logEvent API field-name drift" — new pitfall added 2026-06-07
- `SKILL.md` §"Pitfall — RBAC seed coverage gap" — new pitfall added 2026-06-07
- `docs/TECH-DEBT.md` (crm-system) — P1-1 entry now resolved
- `apps/api/src/middleware/audit.ts` — AuditEvent interface (source of truth for logEvent shape)
- `apps/api/src/middleware/rbac.ts:50-66` — userHasPermission / loadRolePermissions
- `packages/db/prisma/seed.ts` — seed source of truth
- `packages/shared/src/permissions.ts` — PERMISSIONS map (source of truth for role→permission mapping)
