# CRM System Day 5 — User Management + RBAC + Audit Log (2026-06-05)

## 用戶決策 (David 揀咩)

| 問題 | 揀 |
|---|---|
| RBAC 方案 | **Option 3: 集中 permission map** 喺 `packages/shared/src/permissions.ts`,3 個 hard-coded role (ADMIN/SALES/VIEWER),25 個 permission 用 string literal。理由:易 read、易 audit、將來升級唔使重寫。Skip 咗 Option 2 (database-driven RBAC tables),over-engineered for 3 users system。 |
| 用戶管理範圍 | A: Create / Edit / Toggle active / Reset password / Delete。冇 email invitation,冇自己 signup 流程。 |
| Audit log 方案 | A: 新 `AuditLog` table,23 個 action enum 覆蓋 auth/user/CRM 全部,query endpoint 加 filter (actor/action/resource/date)。 |

## Backend SOP

**RBAC + audit pattern** 詳見 `backend/backend-rbac-audit-log` skill — 4-piece architecture: `permissions.ts` shared → `requirePermission()` plugin → `logEvent()` helper → `AuditLog` table。

**Self-protection + last-admin invariant** 寫喺 route handler 入面:
- `if (params.id === userId) return 400 'Cannot delete yourself'`
- `if (target.role === 'ADMIN') { count admins; if <= 1 return 400 'Cannot demote the last admin' }`
- 唔可以用 JS logic, 要 count DB 否則 race condition 撞到 (s兩個 admin 同時 demote 對方)。

**Login audit instrumentation** 喺 `/auth/login` 加 `logEvent({ action: 'USER_LOGIN' | 'USER_LOGIN_FAILED', actorId, request })` 同時 update `lastLoginAt`。

## ⚠️ Docker local dev 嘅 migration 撞牆 + 解決

**問題**: docker-compose `postgres` service 唔 expose host port (只 internal `5432/tcp`):
```
$ docker ps --format '{{.Ports}}'
crm-postgres: 5432/tcp   # no host port mapping
```

host 跑 `prisma migrate dev` 撞:
```
Error: P1001
Can't reach database server at `localhost:5432`
```

**解決** (3 steps):

1. **手寫 SQL** 放喺 `packages/db/prisma/migrations/<timestamp>_<name>/migration.sql` (CREATE TYPE + TABLE + INDEX + FK):
   ```sql
   -- packages/db/prisma/migrations/20260605000000_add_audit_log/migration.sql
   DO $$ BEGIN
     CREATE TYPE "AuditAction" AS ENUM ('USER_LOGIN', 'USER_LOGIN_FAILED', /* ... */);
   EXCEPTION WHEN duplicate_object THEN null; END $$;
   
   CREATE TABLE "audit_logs" (
     "id" TEXT PRIMARY KEY,
     "actorId" TEXT,
     "action" "AuditAction" NOT NULL,
     -- ...
     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
   );
   CREATE INDEX "audit_logs_actorId_createdAt_idx" ON "audit_logs"("actorId", "createdAt");
   ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actorId_fkey" 
     FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE SET NULL;
   ```

2. **`docker exec` 跑 SQL**:
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < \
     packages/db/prisma/migrations/20260605000000_add_audit_log/migration.sql
   # Output: DO / CREATE TABLE / CREATE INDEX (每行一個 confirmation)
   ```

3. **手動 insert `_prisma_migrations` row** (mark as applied), 否則 entrypoint 嘅 `prisma migrate deploy` 將來會 complain "drift detected":
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -c \
     "INSERT INTO \"_prisma_migrations\" (id, checksum, migration_name, finished_at, applied_steps_count) VALUES ('audit-2026-06-05-manual', '', '20260605000000_add_audit_log', NOW(), 1);"
   ```
   ⚠️ `migration_name` 冇 unique constraint,所以要 unique `id` column (`INSERT ... ON CONFLICT (id)` 都得)。

4. **Host 行 `bunx prisma generate`** 重新 generate client 識新 model:
   ```bash
   env $(grep -v '^#' .env | xargs) bunx prisma generate
   ```

**驗證**:
```bash
docker logs crm-api --tail 20
# Expected: "No pending migrations to apply" + "🦊 CRM API running at 0.0.0.0:3001"
```

呢個 trick 適用於: docker-compose postgres 冇 expose host port (本地 dev 為 security + 避免 port conflicts) 但你想 host 跑 Prisma。

**Alternative** (更麻煩): 暫時 uncomment 個 ports mapping `5432:5432`, 跑 migration, comment 返。但如果用 `docker compose down` 之後 `docker compose up`,個 port 又會 expose 住。

## Frontend (3 個新 page + Admin nav)

- `pages/users.tsx` — list + search + role filter + inline activate/deactivate + create dialog
- `pages/user-detail.tsx` — edit name/role/isActive + reset password dialog + delete (self-protection 喺 UI 都做: 自己 disable 停用 + 刪除 button)
- `pages/audit.tsx` — filter by action/actor/resource ID, color-coded badges (success/destructive/info/warning)

**Admin nav section** 加喺 sidebar: `{user?.role === 'ADMIN' && <div>Admin</div> + 2 nav links}`。

**Frontend API client** (`lib/api.ts`) 加 `usersApi` + `auditApi` + `authApiExtra.changePassword()`,仲要 extend `AuthUser` type 唔使變(本來已有 role field)。

## Elysia 1.2 d.ts noise 預期

Day 5 backend code 引入咗 `use(authContext)` + `use(requirePermission(...))` chain → trigger Elysia 1.2 MacroContext d.ts 嘅 >100 個 type errors。`bun run` runtime 唔 care, container 啟動 OK。

**Critical**: Dockerfile API stage 用 `bun run apps/api/src/index.ts` 直接 execute TS,**唔行 `tsc --noEmit` 喺 build step**。如果加咗 `RUN bun run typecheck` build 會 fail。

## Files modified/created Day 5

**Backend** (5 files, +562 / -43):
- `packages/shared/src/permissions.ts` (NEW, 105 lines)
- `packages/shared/src/index.ts` (1 line re-export)
- `apps/api/src/middleware/audit.ts` (NEW, 46 lines)
- `apps/api/src/middleware/rbac.ts` (NEW, 28 lines)
- `apps/api/src/routes/users.ts` (NEW, 208 lines)
- `apps/api/src/routes/audit.ts` (NEW, 57 lines)
- `apps/api/src/routes/auth.ts` (modified, +change-password + login audit)
- `apps/api/src/index.ts` (modified, +userRoutes + auditRoutes)

**DB** (1 model, 1 enum, 1 migration):
- `packages/db/prisma/schema.prisma` (+AuditLog + AuditAction + User.auditLogs relation)
- `packages/db/prisma/migrations/20260605000000_add_audit_log/migration.sql` (NEW, 63 lines)

**Frontend** (5 files, +534):
- `apps/web/src/pages/users.tsx` (NEW, 9098 bytes)
- `apps/web/src/pages/user-detail.tsx` (NEW, 7253 bytes)
- `apps/web/src/pages/audit.tsx` (NEW, 6940 bytes)
- `apps/web/src/lib/api.ts` (+usersApi, +auditApi, +authApiExtra, ~70 lines)
- `apps/web/src/App.tsx` (+3 routes: /users, /users/:id, /audit)
- `apps/web/src/components/layout/app-layout.tsx` (+Admin nav section, conditional on role)

## Verify stack 結果

```
$ docker compose ps
NAME           IMAGE                STATUS                       PORTS
crm-api        crm-system-api       Up (healthy)                 3001/tcp
crm-postgres   postgres:16-alpine   Up (healthy)                 5432/tcp
crm-web        crm-system-web       Up (healthy)                 0.0.0.0:80->80/tcp

$ curl -s -o /dev/null -w "API: %{http_code}\nWeb: %{http_code}\n" http://localhost/api/health http://localhost/
API: 200
Web: 200

$ docker logs crm-api --tail 10
==> [entrypoint] Running database migrations...
2 migrations found in prisma/migrations
No pending migrations to apply.
==> [entrypoint] Starting API server...
🦊 CRM API running at 0.0.0.0:3001
```

🟢 Migration history 認得手動加嘅 migration,冇 drift detected。Audit table 初始 empty (冇人 login 過),login 一次之後應該有 1 row USER_LOGIN。

## 仲未做嘅嘢(下個 iteration)
- 將 audit instrumentation 應用到 quotation/company/contact/deal routes(目前只 instrument 咗 login/user/password change)
- 2FA / TOTP for admin
- Email invitation (signup token) — David 揀 A 範圍
- Audit log retention policy (e.g. 90 日之後 archive)
