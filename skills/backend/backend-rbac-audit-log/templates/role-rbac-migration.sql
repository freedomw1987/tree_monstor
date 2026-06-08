-- Day 7 RBAC migration: from Option 3 (hard-coded roles) to Option 2 (DB-driven)
-- Apply to your running Postgres container:
--   docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < role-rbac-migration.sql
-- Then mark the migration in _prisma_migrations:
--   docker exec -i crm-postgres psql -U crm -d crm_system -c \
--     "INSERT INTO \"_prisma_migrations\" (id, checksum, migration_name, finished_at, applied_steps_count)
--      VALUES ('<unique>', '', '20260605030000_day7_dynamic_rbac', NOW(), 1);"

-- 1. Create new tables
CREATE TABLE IF NOT EXISTS "roles" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL UNIQUE,
  "description" TEXT,
  "isSystem" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "roles_name_idx" ON "roles"("name");

CREATE TABLE IF NOT EXISTS "role_permissions" (
  "id" TEXT PRIMARY KEY,
  "roleId" TEXT NOT NULL REFERENCES "roles"("id") ON DELETE CASCADE,
  "permission" TEXT NOT NULL,
  UNIQUE("roleId", "permission")
);
CREATE INDEX IF NOT EXISTS "role_permissions_roleId_idx" ON "role_permissions"("roleId");

-- 2. Add roleId FK to users
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "roleId" TEXT
  REFERENCES "roles"("id") ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS "users_roleId_idx" ON "users"("roleId");

-- 3. Seed 3 system roles
INSERT INTO "roles" (id, name, description, "isSystem", "createdAt", "updatedAt")
VALUES
  ('seed_admin',  'ADMIN',  'System administrator',            true, NOW(), NOW()),
  ('seed_sales',  'SALES',  'Sales person (read+write most)', true, NOW(), NOW()),
  ('seed_viewer', 'VIEWER', 'Read-only access',                true, NOW(), NOW())
ON CONFLICT (name) DO NOTHING;

-- 4. Seed role_permissions (one INSERT per role)
-- ADMIN gets all 27 permissions:
INSERT INTO "role_permissions" (id, "roleId", permission)
SELECT 'rp_admin_' || perm, 'seed_admin', perm FROM unnest(ARRAY[
  'user:read','user:create','user:update','user:delete',
  'audit:read',
  'company:read','company:create','company:update','company:delete',
  'contact:read','contact:create','contact:update','contact:delete',
  'product:read','product:create','product:update','product:delete',
  'quotation:read','quotation:create','quotation:update','quotation:delete','quotation:send',
  'deal:read','deal:create','deal:update','deal:delete',
  'chat:use'
]) AS perm
ON CONFLICT ("roleId", permission) DO NOTHING;

-- SALES: read+write most, no user/audit, can send quotations
INSERT INTO "role_permissions" (id, "roleId", permission)
SELECT 'rp_sales_' || perm, 'seed_sales', perm FROM unnest(ARRAY[
  'company:read','company:create','company:update','company:delete',
  'contact:read','contact:create','contact:update','contact:delete',
  'product:read',
  'quotation:read','quotation:create','quotation:update','quotation:delete','quotation:send',
  'deal:read','deal:create','deal:update','deal:delete',
  'chat:use'
]) AS perm
ON CONFLICT ("roleId", permission) DO NOTHING;

-- VIEWER: read-only
INSERT INTO "role_permissions" (id, "roleId", permission)
SELECT 'rp_viewer_' || perm, 'seed_viewer', perm FROM unnest(ARRAY[
  'company:read','contact:read','product:read','quotation:read','deal:read'
]) AS perm
ON CONFLICT ("roleId", permission) DO NOTHING;

-- 5. Backfill existing users
UPDATE "users" SET "roleId" = 'seed_admin'  WHERE "role" = 'ADMIN'  AND "roleId" IS NULL;
UPDATE "users" SET "roleId" = 'seed_sales'  WHERE "role" = 'SALES'  AND "roleId" IS NULL;
UPDATE "users" SET "roleId" = 'seed_viewer' WHERE "role" = 'VIEWER' AND "roleId" IS NULL;
