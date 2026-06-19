# RG-007 — Day 17 AI tool confirmation migration not applied to prod

> **Why this is in a reference file (not just RG-007 entry):** The full
> failure transcript + the exact 6-step recovery recipe below is the
> canonical "image was never rebuilt" case. Future agents who hit any
> "I added a migration but prod DB doesn't have the new column" symptom
> should find this file via the SKILL.md pointer above and apply the
> same recipe.

## Source of truth
`docs/REGRESSION-GUARD.md` — RG-007 entry. This file is the
**reproduction transcript** that proves the recipe works end-to-end,
not a replacement for the RG entry.

## Failure reproduction (crm-system, 2026-06-08)

### Setup
- `main` HEAD = `178a344 Tech debt scan`
- Day 17 commit `8484b9a` (RG-CHAT-001) + `fcfbc29` (US-C5 tests)
  added a new migration file:
  `packages/db/prisma/migrations/20260609000002_day17_ai_tool_confirmation/migration.sql`
- Running api container was built BEFORE that commit landed.
  Dockerfile bakes `prisma/migrations/` into the image at build time
  (line 34: `COPY apps/api ./apps/api`).
- entrypoint.sh runs `prisma migrate deploy` on container start.
  Image contents are stale → only sees the 11 migrations baked at
  last build.

### Detection — symptoms in `_prisma_migrations`
```bash
docker compose exec -T postgres psql -U crm -d crm_system -c \
  "SELECT migration_name, finished_at FROM _prisma_migrations ORDER BY migration_name;"
# 11 rows, latest is `20260609000001_day9_region_table_actual_ddl`
# Day 17's `20260609000002_day17_ai_tool_confirmation` is MISSING.
```

### Detection — symptoms in DB enum
```bash
docker compose exec -T postgres psql -U crm -d crm_system -c \
  "SELECT enum_range(NULL::\"AuditAction\") ORDER BY 1;"
# 41 values, no AI_TOOL_CONFIRMED, no AI_TOOL_DENIED
```

### Detection — symptoms in container's migrations folder
```bash
docker compose exec -T api sh -c 'ls /app/packages/db/prisma/migrations/'
# 11 dirs, missing `20260609000002_day17_ai_tool_confirmation/`
```

## Recovery — 6 steps

```bash
# Step 1: verify the migration file on the host
cat packages/db/prisma/migrations/20260609000002_day17_ai_tool_confirmation/migration.sql
# Inspect for PascalCase table name issues (see "PascalCase trap" below)

# Step 2: cp the migration folder into the running container
docker cp packages/db/prisma/migrations/20260609000002_day17_ai_tool_confirmation \
  crm-api:/app/packages/db/prisma/migrations/

# Step 3: try deploy (will fail with P3018 due to PascalCase drift)
docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate deploy 2>&1'
# Error: P3018 migration failed to apply, 42P01 relation "ConversationMessage" does not exist

# Step 4: fix the SQL (PascalCase trap), cp again
# Edit migration.sql: ALTER TABLE "ConversationMessage" → "conversation_messages"
docker cp packages/db/prisma/migrations/20260609000002_day17_ai_tool_confirmation/migration.sql \
  crm-api:/app/packages/db/prisma/migrations/20260609000002_day17_ai_tool_confirmation/migration.sql

# Step 5: resolve the failed-migration marker so the next deploy can re-apply
docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate resolve --rolled-back 20260609000002_day17_ai_tool_confirmation'

# Step 6: deploy for real
docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate deploy 2>&1'
# "All migrations have been successfully applied."
```

### Verification after recovery
```bash
# Enum has new values
docker compose exec -T postgres psql -U crm -d crm_system -c \
  "SELECT enum_range(NULL::\"AuditAction\") ORDER BY 1;"
# 43 values now, AI_TOOL_CONFIRMED + AI_TOOL_DENIED are the last two

# Column exists
docker compose exec -T postgres psql -U crm -d crm_system -c "\d conversation_messages"
# Look for `aiToolConfirmationHash | text` row

# Migration recorded
docker compose exec -T postgres psql -U crm -d crm_system -c \
  "SELECT migration_name FROM _prisma_migrations WHERE migration_name LIKE '%day17%';"
# 20260609000002_day17_ai_tool_confirmation
```

## PascalCase trap — the compounding bug

Day 17's migration SQL had:
```sql
ALTER TABLE "ConversationMessage"
  ADD COLUMN IF NOT EXISTS "aiToolConfirmationHash" TEXT;
```

But the init migration (`20260605014842_init/migration.sql`) created
the table as:
```sql
CREATE TABLE "conversation_messages" ( ... );
```

**PostgreSQL rule:** Double-quoted identifiers are case-sensitive
literals. `"ConversationMessage"` is NOT the same identifier as
`"conversation_messages"`. The init migration explicitly
double-quoted the snake_case form, so the on-disk table name is
case-sensitive `"conversation_messages"`. PG would have thrown
`42P01 relation "ConversationMessage" does not exist` on the first
ALTER TABLE attempt.

### Why dev didn't catch this
Dev environments typically run PG with case-folding collation
(`en_US.UTF-8` and similar), so unquoted `"ConversationMessage"` would
fold to `conversationmessage` and the lookup would fail anyway — but
sometimes dev's PG is also case-sensitive and the typo is masked by
`prisma migrate dev` not running the migration at all (it does
shadow-database generation, doesn't apply to actual dev DB unless
explicitly told to).

### How to avoid in future migrations
1. **Always use the on-disk identifier, not the Prisma model name.**
2. Verify on-disk name: `docker exec -i <pg> psql ... -c '\d <table>'`
3. Lint: see `scripts/migration-lint.sh` in this skill.

## Prevention — ship-gate additions

For crm-system's day 18+ ship-gate, the following checks should
block a deploy if they fail:

```bash
# 1. Image-baked migrations match host
HOST_MIGRATIONS=$(ls packages/db/prisma/migrations/ | sort)
CONTAINER_MIGRATIONS=$(docker compose exec -T api sh -c 'ls /app/packages/db/prisma/migrations/' | sort)
[ "$HOST_MIGRATIONS" = "$CONTAINER_MIGRATIONS" ] || { echo "❌ stale image"; exit 1; }

# 2. DB schema enum matches Prisma schema enum
SCHEMA_ENUMS=$(grep -A100 "^enum AuditAction" packages/db/prisma/schema.prisma | grep -E "^  [A-Z_]+$" | sort)
DB_ENUMS=$(docker compose exec -T postgres psql -U crm -d crm_system -tAc \
  "SELECT enum_range(NULL::\"AuditAction\")::text" | tr ',' '\n' | tr -d '{}' | sort)
[ "$SCHEMA_ENUMS" = "$DB_ENUMS" ] || { echo "❌ enum drift"; exit 1; }

# 3. Migration drift is clean
docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate status'
# Output must show "Database schema is up to date" — no "drift detected"
```

## Cross-session search hint

If you grep for "Day 17 migration" / "AI_TOOL_CONFIRMED" / "migrate
resolve --rolled-back" in past sessions, you'll find this same
recovery recipe discussed in the crm-system 2026-06-08 P1 sprint
session — that's where it was first used.
