# Docker-local Postgres Prisma migration trick (crm-system Day 5)

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body. The general rule "use docker exec
> for migrations when the DB isn't exposed to the host" applies to
> any Docker Compose stack, but the crm-system timestamps + the
> exact `psql` + `_prisma_migrations` INSERT recipe are project-specific
> and preserved here for exact reproduction.

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