# ⚠️ Pitfall — RBAC seed coverage gap: rbac.ts reads from a table the seed never writes (crm-system 2026-06-07, CRITICAL)

**場景**: `apps/api/src/middleware/rbac.ts:50-66` 嘅 `userHasPermission(userId, permission)` 真係 query DB:

```typescript
export async function userHasPermission(userId: string, permission: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, role: true },
  });
  if (!user) return false;

  let roleId = user.roleId;
  if (!roleId) {
    const role = await prisma.role.findUnique({ where: { name: user.role } });
    if (!role) return false;
    roleId = role.id;
  }

  const perms = await loadRolePermissions(roleId);   // ← 讀 RolePermission table
  return perms.has(permission);
}
```

但 `packages/db/prisma/seed.ts` **完全冇 seed 過 `Role` / `RolePermission` row** = 個 table 永遠空 = `loadRolePermissions` 永遠 return empty Set = **`userHasPermission` 永遠 return false** = **任何 `requirePermission(...)` gate 都會 silently 403 所有 user**(包括 ADMIN)。

**症狀**:
- 冇 admin 任何人可以 hit requirePermission-gated endpoint
- 公開 endpoint(`GET /companies` etc.)OK 因為冇 gate
- `rbac.ts:84` 嘅 `getUserIdFromRequest` 真係 verify JWT,所以 userId 唔係 null
- 403 response 看似正常(permission denied),但其實 ALL users 都 fail,包括 ADMIN
- 開發人員如果用 ADMIN token 跑 smoke test,會 403 → 誤以為自己嘅 perm 唔啱 → 走去 debug role / permission 名 → 浪費幾個鐘
- 已知存在 comment: `apps/api/src/routes/man-day-role.ts:29` 直接寫 `"because the seed script doesn't currently write RolePermission rows"` — 即係個 project 知道呢個 bug 但冇 RG entry,冇 red-line 跟進

**Root cause(為何會壞)**:
1. `rbac.ts` 設計上 read DB table (RolePermission) — 正確
2. 開發人員 `roles.ts:131-138` 有 `tx.rolePermission.createMany()` — 即係 UI 可以寫入
3. 但 seed 從來冇做呢步
4. Production 環境 ADMIN 由 UI 改自己嘅 role 之前,冇辦法 access 任何 requirePermission-gated endpoint
5. 冇 integration test 撞「fresh DB + new user + 任何 perm check」

**3 個 prevention 措施**(必須一齊做):

1. **Seed `Role` + `RolePermission` rows** from `packages/shared/src/permissions.ts` source of truth:
   ```typescript
   // packages/db/prisma/seed.ts
   const { PERMISSIONS } = await import('@crm/shared/permissions');
   const allKeys = Object.keys(PERMISSIONS) as Permission[];
   const ROLE_PERMS: Record<string, string[]> = {
     ADMIN:  allKeys,
     SALES:  ['company:read', ...],   // match shared/permissions.ts
     VIEWER: ['company:read', ...],
   };
   for (const roleName of ['ADMIN', 'SALES', 'VIEWER'] as const) {
     await prisma.role.create({
       data: {
         name: roleName,
         displayName: '...',
         isSystem: true,
         permissions: { create: ROLE_PERMS[roleName].map((p) => ({ permission: p })) } },
       },
     });
   }
   // User FK → Role, 所以一定要喺 user.create() 之前
   ```

2. **Wire `User.roleId`** 喺 seed,fallback 邏輯仍然 work 但 cache 更穩:
   ```typescript
   const adminRole = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
   await prisma.user.create({
     data: { email: 'admin@crm.local', ..., roleId: adminRole?.id, role: 'ADMIN' },
   });
   ```

3. **Integration smoke 撞 fresh DB + ADMIN access**:
   ```bash
   # 跑完 `bun run db:reset` 後:
   bun run db:seed
   TOKEN=*** -X POST localhost:3001/auth/login -d '{"email":"admin@crm.local","password":"admin123"}' | jq -r .token)
   curl -H "Authorization: Bearer *** localhost:3001/users
   # 預期 200, 唔係 403
   ```

**Detection signal**(出現以下即 audit RBAC seed coverage):
- 任何 `rbac.ts` 嘅 `userHasPermission` / `loadRolePermissions` function
- 任何 `requirePermission(...)` middleware call
- 對照 `packages/db/prisma/seed.ts` — 有冇 create `Role` + `RolePermission`?
- 對照 `packages/shared/src/permissions.ts` — 每個 permission 有冇對應 Role 嘅 seed entry?
- `rg "rolePermission.createMany" --type ts` 撈 seed 入面有冇用
- `rg "from '@crm/shared/permissions'" seed.ts` 撈 seed 有冇 import 個 shared source of truth

**Pre-existing bug class in crm-system** (2026-06-07 audit):
- `man-day-role.ts:29` 嘅 comment 直接 acknowledge: "because the seed script doesn't currently write RolePermission rows" → **known-bug-without-RG-entry**(紅線 13 違規)
- 任何 commit series 加 `requirePermission(...)` 喺 P0 security review 嗰陣,冇配套 seed 改動 = production 死
- 2026-06-07 P0-2 (companies/contacts/deals routes 公開) 修補加入 RBAC **silently 封死咗所有 user** 對呢啲 endpoint 嘅 access,因為冇 seed 配套

**Lesson**:**任何 RBAC middleware 嘅 read path 必須有對應 seed 嘅 write path**,否則係 100% production 死。**Audit checklist**:
- [ ] `rbac.ts` / `permission.ts` 嘅 read path list(全部)
- [ ] `seed.ts` 嘅 write path list(全部)
- [ ] 對齊:每個 read 都有對應 write
- [ ] 對齊:每個 `requirePermission` string literal 喺 seed 嘅 `ROLE_PERMS[role]` 入面
- [ ] Integration smoke: fresh DB → seed → login → 撞每個 requirePermission endpoint
- [ ] Staging 環境 deploy 後做一次 same smoke(prod mirror)
