---
name: prisma-migrate-private-rds
description: Run Prisma migrations on private RDS via ECS one-off task when CodeBuild can't reach the database
category: devops
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Prisma Migration on Private RDS via ECS One-Off Task

## Problem
CodeBuild (no VPC) cannot reach RDS in private subnet. `prisma migrate deploy` in buildspec fails with:
```
Can't reach database server at `xxx.rds.amazonaws.com`
```

## Solution
Use ECS run-task to run migration inside the VPC, since the backend container IS in the private subnet and has access to RDS.

## Step-by-Step

1. Find the latest active task definition for the backend service:
```bash
aws ecs describe-services --cluster umac-ai-cluster --services umac-ai-backend --region ap-east-1
# Note: taskDefinition arn like UMacAiEcsStackBackendTaskDefEF56D88D:4
```

2. Run one-off ECS task with migration command:
```bash
aws ecs run-task \
  --cluster umac-ai-cluster \
  --task-definition UMacAiEcsStackBackendTaskDefEF56D88D:4 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-01255018d4a3a1b1f,subnet-0c5ce99b7d83c693b],securityGroups=[sg-01d213a5c6e416f40],assignPublicIp=DISABLED]}" \
  --overrides '{"containerOverrides":[{"name":"umac-ai-backend","command":["sh","-c","cd /app && bunx prisma migrate deploy --schema prisma/schema.prisma"]}]}' \
  --region ap-east-1 \
  --query 'tasks[0].taskArn' \
  --output text
```

3. Wait for task to complete (~30-40s):
```bash
sleep 30 && aws ecs describe-tasks --cluster umac-ai-cluster --tasks <task-arn> --region ap-east-1
# Look for lastStatus=STOPPED and exitCode=0
```

## Key Insight
- CodeBuild builds Docker image and pushes to ECR — no VPC needed
- Migration MUST run from within VPC — use ECS task container
- `npx` doesn't work inside Bun container — use `bunx` instead
- Working directory in ECS task is `/app` (matches Dockerfile WORKDIR)
- ECS task needs ~30-40s to start + run Prisma

## Gotchas
- Exit code 127 = command not found (use `bunx` not `npx`)
- Exit code 2 = wrong path (try `cd /app &&` prefix)
- Exit code 1 = migration error (check logs)
- `assignPublicIp=DISABLED` required for private subnet tasks

## ⚠️ Schema drift 同 enum → table migration 嘅 production recipe (2026-06-06 crm-system Day 9)

**情境**: 你做了一個 structural schema 改動 (e.g. `enum Foo` → `model Foo { id, code, name }` + FK columns in other tables),但 `prisma migrate dev` 唔識 produce 呢個 migration (因為 enum→model 唔係 Prisma express 得到的)。或者你之前手動喺 dev DB 跑咗 SQL 改 schema,**但 filesystem migration history 仲係舊嘅**。

**Workflow** (同樣適用於 local docker-compose dev 同 ECS RDS prod):

1. **手動寫 SQL** 放喺 `packages/db/prisma/migrations/<timestamp>_<name>/migration.sql` — 真實 DDL (CREATE TABLE, ADD COLUMN, backfill, FK, DROP TYPE)
2. **喺 running DB apply SQL**:
   - Local docker: `docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < migration.sql`
   - ECS RDS: `aws ecs run-task` + `command=["sh","-c","cd /app && psql $DATABASE_URL -f /app/path/to/migration.sql"]`
3. **Insert `_prisma_migrations` row** 標記為 applied,否則下次 entrypoint 嘅 `prisma migrate deploy` 會 detect drift:
   ```sql
   INSERT INTO _prisma_migrations
     (id, checksum, migration_name, finished_at, applied_steps_count)
     VALUES ('<unique-cuid>', '', '<timestamp>_<name>', NOW(), 1);
   ```
   **`migration_name` 唔係 unique constraint** — 用 `id` (cuid) 做 unique key
4. **Schema.prisma 改** 對應 DDL (e.g. `enum Region` → `model Region`)
5. **Host 跑 `bunx prisma generate`** 重新 generate Prisma client
6. **Force image rebuild**:`docker compose build --no-cache api` / `cdk deploy` 新 image push ECR
7. **Verification**:
   - 個 column 實際 type 對 schema 講:`docker exec crm-postgres psql -c "\\d <table>"` 睇 column type
   - 個 Prisma client 識新 type: `docker exec crm-api grep -c "newType" /app/node_modules/.prisma/client/index.js`
   - 個 endpoint work: `curl /api/<endpoint>` 唔撞 42704 / P3009

**教訓**: `prisma migrate dev` 唔識 produce 任何 structural change (e.g. enum→table, table→enum, column type switch, FK cycle breaking)。**手動 SQL + 手動 migration record 係唯一可靠 path**。詳細 SQL 範本 (Region enum → table backfill): 見 `bun-elysia-react-vite-stack` skill 嘅 "⚠️ Prisma `enum` field — schema/DB drift" pitfall section。

**同類變體: TEXT column → enum (crm-system Day 9)** (2026-06-06)

**情境**: Schema 將某 column 由 `String @default("ACTIVE")` 改成 typed enum `Foo @default(ACTIVE)` 但出 migration 前已經跑緊 dev DB,DB column 仍然係 plain TEXT。Prisma client emit `INSERT INTO ... VALUES ('ACTIVE'::"Foo")` 但 PG type 不存在, throw `42704 type "public.Foo" does not exist`。

**Symptoms**:
- Prisma create/update throw `42704 type "public.X" does not exist` 
- 502 喺 reverse proxy 後面 (nginx return 502 when upstream returns 5xx)

**Recipe** (同樣適用 local docker postgres 同 ECS RDS):

1. **手寫 migration SQL** 放喺 `packages/db/prisma/migrations/<ts>_<name>/migration.sql`:
   ```sql
   CREATE TYPE "Foo" AS ENUM ('A', 'B', 'C');
   ALTER TABLE "<table>" ALTER COLUMN "<col>" DROP DEFAULT;
   ALTER TABLE "<table>" ALTER COLUMN "<col>" TYPE "Foo" USING "<col>"::"Foo";
   ALTER TABLE "<table>" ALTER COLUMN "<col>" SET DEFAULT 'A'::"Foo";
   ```
   ⚠️ 3 個 ALTER COLUMN 順序:先 DROP DEFAULT,改 TYPE,然後再 SET DEFAULT — 因為 ALTER TYPE 會 clear default。
2. **Apply SQL**:
   - Local docker: `docker exec -i crm-postgres psql -U crm -d crm_system -v ON_ERROR_STOP=1 < migration.sql`
   - ECS RDS: `aws ecs run-task` + `command=["sh","-c","cd /app && psql $DATABASE_URL -f /app/packages/db/prisma/migrations/<ts>_<name>/migration.sql"]`
3. **Insert `_prisma_migrations` row** (用 file 嘅 SHA-256 做 checksum):
   ```bash
   CHECKSUM=$(sha256sum migration.sql | awk '{print $1}')
   docker exec crm-postgres psql -U crm -d crm_system -c \
     "INSERT INTO _prisma_migrations (id, checksum, migration_name, finished_at, applied_steps_count, started_at) VALUES ('<cuid>', '$CHECKSUM', '<ts>_<name>', NOW(), 1, NOW());"
   ```
4. **`bunx prisma generate`** 重新 emit Prisma client。
5. **喺 running docker image 同步** (local dev): 因為 `docker-compose.yml` 嘅 api service 用 Dockerfile baked-in filesystem,而唔係 host volume mount,**新 migration file 唔會自動出現喺 container 入面**。要 `docker cp` 入 container:
   ```bash
   docker cp packages/db/prisma/migrations/<ts>_<name> crm-api:/app/packages/db/prisma/migrations/
   docker restart crm-api
   ```
   然後 entrypoint 跑 `prisma migrate deploy` 會見 "N migrations found ... No pending migrations to apply" = sync 成功。
6. **Smoke test**: 用 Prisma 直接 insert 一個 record 試,如果冇 42704 = 修好。

**Root cause 同 prevention**: David 成日講「唔好淨係改 schema,跟住要 emit migration」。但呢類 case 比較 subtle(改一個 enum definition 而唔係加新 enum),`prisma migrate dev` 喺 dev DB 跑緊時,只會 emit 一個 `ALTER TABLE` 而唔識重整 `CREATE TYPE`(因為 type 已經「存在」喺 prisma 嘅 perspective)。一律建議:schema 改完即刻 `bunx prisma migrate dev --create-only --name X`,然後睇 SQL 再 `migrate deploy`。

---

## ⚠️ Migration file in `main` 但 container 從未 rebuild 過 → prod 永遠見唔到(2026-06-08 crm-system)

**情境**: 你 commit 咗一個新 migration file 落 `main`,Dockerfile baked 咗 `prisma/migrations/` 入 image。`git log` 顯示新 file 喺度,**但** running container 入面 `ls /app/packages/db/prisma/migrations/` 唔見個新 file → entrypoint 跑 `prisma migrate deploy` 只睇到 11 個 file(舊嘅),「No pending migrations to apply」,**冇任何錯誤訊息**。Prod DB 永久 drift。

**Symptoms**:
- DB schema 缺新 column / 新 enum values
- `_prisma_migrations` 缺少新 row
- Application code 寫新 column / 新 enum value 時先 throw error(可能 PG `42704`、可能 column does not exist)
- 可能**幾日 / 幾星期後**先被 catch 到(睇 code path 觸發頻率)
- **冇 build error,冇 deploy error,只有「試嗰陣先撞」**

**Recipe (適用 local docker-compose 環境, NOT RDS via ECS — 嗰個用上面 AWS ECS run-task recipe)**:

1. **Diagnose 確認** — 喺 running container 入面 list migrations:
   ```bash
   docker compose exec -T api sh -c 'ls /app/packages/db/prisma/migrations/'
   # 對比 host
   ls packages/db/prisma/migrations/
   # Mismatch = confirmed stale
   ```

2. **Diagnose 確認 #2** — DB schema 對比 Prisma model:
   ```bash
   docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma db pull --print 2>&1 | grep -A50 "enum AuditAction"'
   # 對比 packages/db/prisma/schema.prisma 入面個 enum
   ```

3. **Fix recipe (重要: docker cp + resolve + deploy, 唔係 restart)**:
   ```bash
   # a. Copy 整個 migration folder 入 container
   docker cp packages/db/prisma/migrations/<timestamp>_<name> crm-api:/app/packages/db/prisma/migrations/

   # b. Try deploy — 第一次通常失敗因為 schema mismatch (見下面 PascalCase 警告)
   docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate deploy 2>&1'
   # 失敗訊息會係 P3018 (migration 失敗) 或 P3009 (有 failed migration)

   # c. 標記 failed migration 為 rolled back
   docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate resolve --rolled-back <timestamp>_<name>'

   # d. Re-deploy
   docker compose exec -T api sh -c 'cd /app/packages/db && bunx prisma migrate deploy 2>&1'

   # e. Verify — 應該見 "All migrations have been successfully applied"
   ```

4. **Critical 配套(2026-06-08 crm-system 親驗)**:**亦都要 force image rebuild** 將來 deploy 用,否則下次 `docker compose up -d` 個新 image 唔存在於 registry / named tag:
   ```bash
   docker compose build --no-cache api
   docker compose up -d api
   ```

5. **Prevention(寫入 CI / pre-deploy check)**:
   - 加個 ship-gate smoke test:比較 `ls prisma/migrations/` host vs container。Mismatch = block deploy。
   - Schema change SOP:任何 PR 加 migration file MUST 同步 update 一個 build-time marker(例如 `docker-compose.yml` comment 或 `Dockerfile` 的 `LABEL migrations_baked_at=$(date)`)— rebuild 嘅時候會見到 stale marker。
   - 部署 checklist:**migration commit → rebuild image → restart container,順序唔可以亂**。`docker compose up -d` 冇 `--build` 喺 image 唔變時係 silent no-op(見 `docker-build-cache-debug` skill)。

**Root cause summary**:
- `docker-compose.yml` 嘅 api service 用 Dockerfile baked-in filesystem,唔係 host volume mount
- entrypoint 跑 `prisma migrate deploy` 永遠睇 image 內 baked 嘅 migrations,唔睇 host
- 你 commit migration file → `git push` → 冇 `docker compose build` → image 唔變 → 個 migration 永遠唔跑
- 個最危險嘅係 **silently fail**:`migrate deploy` 對 stale image 嘅 response 係「No pending migrations」(0 個 exit code,正常 success log),唔似 `npm install` 會 warn

---

## ⚠️ PascalCase model name 撞 snake_case on-disk table name (2026-06-08 crm-system RG-007)

**情境**: Prisma model 叫 `ConversationMessage`(PascalCase),但 init migration 寫嘅 SQL 用 `CREATE TABLE "conversation_messages"`(snake_case 加 explicit double-quotes)。**PG 嘅 double-quoted identifier 係 case-sensitive literal**,所以 DB 入面真係有 `conversation_messages` 唔係 `ConversationMessage`。Prisma client 喺 query 時 emit 嘅 `"conversation_messages"` 喺 PG 識認,**但**你手寫 raw SQL 喺 migration file 入面如果用 `"ConversationMessage"`,**PG 會 throw `42P01 relation "ConversationMessage" does not exist`**,即使 `prisma migrate dev` 喺 dev 跑冇問題(dev 嘅 PG 通常係 case-folding,lower-case 都 OK;**prod PG 開 `lower_case_insensitive = off` 之後會撞**)。

**Symptoms**:
- `prisma migrate deploy` 報 `P3018: migration failed to apply`
- DB error code 42P01, message `relation "X" does not exist`
- Dev 環境可能冇事(prod-only)
- David 嘅 init migration(2026-06-05 入面)用咗 snake_case `"conversation_messages"`,所以呢個 pattern 喺 crm-system 全 codebase 都用緊 snake_case with explicit quotes

**Recipe (avoiding the drift 喺新 migration 入面)**:

1. **寫 migration SQL 之前**,check on-disk name:
   ```bash
   docker compose exec -T postgres psql -U crm -d crm_system -c "\d <table>"
   # 個 output header 嘅 Table name 嗰行 = 真實 on-disk name
   ```
   或者:
   ```bash
   docker compose exec -T postgres psql -U crm -d crm_system -c \
     "SELECT t.relname FROM pg_class t WHERE t.relname ILIKE '%message%';"
   ```

2. **新 migration 嘅 raw SQL 一律用 on-disk name**:
   ```sql
   -- ❌ 用 model 名(PascalCase)— 撞
   ALTER TABLE "ConversationMessage" ADD COLUMN "foo" TEXT;

   -- ✅ 用 on-disk name(蛇形 + quotes)— 啱
   ALTER TABLE "conversation_messages" ADD COLUMN "foo" TEXT;
   ```

3. **Init migration 嘅 pattern grep**:
   ```bash
   grep -E 'CREATE TABLE "(.+)"|ALTER TABLE "(.+)"' packages/db/prisma/migrations/20260605014842_init/migration.sql
   # 全部用 snake_case + quotes,新 migration 跟同一個 convention
   ```

4. **Lint rule 防 drift(US-OPS-1 backlog task)**:
   ```bash
   #!/bin/bash
   # migration-lint.sh — fail build if PascalCase used where init is snake_case
   for f in packages/db/prisma/migrations/*/migration.sql; do
     if [ "$f" = "packages/db/prisma/migrations/20260605014842_init/migration.sql" ]; then continue; fi
     if grep -E 'ALTER TABLE "[A-Z]' "$f" >/dev/null; then
       echo "❌ $f uses PascalCase ALTER TABLE — should be snake_case with explicit quotes"
       exit 1
     fi
   done
   ```
   Hook 入 `bun run lint` 嘅 pre-commit 階段。

   Pre-built script: `bash skills/prisma-migrate-private-rds/scripts/migration-lint.sh [migrations-dir]`.

**Cross-reference**:`docker-build-cache-debug` 嘅 case study #1 講 image stale 嘅 detection(grep bundle / 對比 image Created time),呢個 skill 講 migration 層嘅 stale detection(`ls` migration folder in container vs host)。兩個加埋就 cover 咗 "source 改咗但 prod 唔知" 嘅兩個最常見 path。

---

## ⚠️ 客戶機 first boot 撞 P3009 — 項目用 `prisma db push` 改 schema 冇 emit migration (2026-06-09 pm-system v1.0.0)

**情境**: 項目 init migration 之後, developer 用 `prisma db push` 改 schema (加咗 N 個 model + 改咗 M 個 column),**冇 fold back 落 migration**。客戶機 fresh DB 跑 `prisma migrate deploy` 撞:
- `column "X" of relation "Y" already exists` (P3009, 因為 `db push` 已經改咗 dev DB 但 filesystem migration 唔知)
- 或者 `relation "X" does not exist` (因為 init 嗰陣 schema 仲未包新 model)
- **冇 build error, 冇 deploy error, 只有「試嗰陣先撞」** — 同上面"image never rebuilt"嘅 silent failure 屬同一類 family

**呢個 case 同上面 3 個唔同嘅係**: 上面 3 個都係"做咗 migration 但 deploy 唔到";呢個係"**根本冇做 migration**"。**Dev 環境照常 work**(因為 db push 已經 sync 咗),**只有 customer 嘅 fresh DB 撞**。

**Recipe — 一句過 audit 補 migration(2026-06-09 pm-system 親驗,emit 212 行 SQL 一次過)**:

1. **用 `prisma migrate diff` 一句過 emit 全部差異**(唔好手寫 SQL — 太易漏 audit):
   ```bash
   cd backend
   bunx prisma migrate diff \
     --from-migrations ./prisma/migrations \
     --to-schema-datamodel ./prisma/schema.prisma \
     --script > /tmp/audit.sql
   ```
   呢個會 print 出**所有 init migration 之後**改過嘅 DDL:
   - 缺嘅 `CREATE TABLE`
   - 缺嘅 `ADD COLUMN`
   - 缺嘅 FK constraint
   - 缺嘅 index / unique

2. **Audit output 嘅 duplicate**(呢個係 `migrate diff` 唔會做嘅 human check — 我親驗撞 `column "parent_task_id" already exists`):
   ```bash
   # 揾齊現有 migration 入面所有 ALTER TABLE ... ADD COLUMN
   grep -hE 'ALTER TABLE "\w+" ADD COLUMN' backend/prisma/migrations/*/migration.sql | sort -u
   # 比對 /tmp/audit.sql, 將 duplicate column / constraint 從新 migration 移除
   ```
   **最常撞 duplicate 嘅 column**:subtask migration 已經加咗但 init 嘅 audit 冇 cover(e.g. `parent_task_id` 加過但寫新 migration 冇查)。

3. **將 step 1 嘅 output (audit 完冇 duplicate) save 做新 migration file**:
   ```bash
   mkdir -p backend/prisma/migrations/20260609000000_sync_schema_to_v2
   # 將 step 1 嘅 output 寫入 migration.sql
   # 命名規則: YYYYMMDDhhmmss_sync_schema_to_v2 (timestamp 一定晚過 init + subtask)
   ```

4. **Rebuild image** 因為 Dockerfile baked-in migration file:
   ```bash
   bash scripts/build-release.sh v1.0.0   # 重新 build + save tar
   ```

5. **客戶機 retry install**:
   ```bash
   docker compose -p myapp down -v           # 清舊 volume(小心 named volume override, 見 docker-multiarch-customer-image-release skill)
   docker load -i myapp-backend-v1.0.0-amd64.tar  # 載入新 image
   docker compose -p myapp up -d             # 跑新 migration
   ```

**Prevention SOP(寫入項目 README, dev workflow 必做)**:
- **任何 schema 改完即 `bunx prisma migrate dev --create-only --name X` 睇 SQL**, 確認 DDL 有出。
- **唔好用 `bunx prisma db push`**(除非真係 dev hotfix 唔介意 drift)。
- **CI lint**: 任何 PR 改 `prisma/schema.prisma` 都必須**同時**改 `prisma/migrations/<新 timestamp>/migration.sql`, 否則 build fail。可以用 `scripts/migration-lint.sh` 加 pre-commit hook。

**Cross-reference**:
- `docker-multiarch-customer-image-release` 嘅 "客戶機 first boot 嘅 schema migration 陷阱" section 講 3 個 migration-related pitfall 嘅完整 diagnosis flow(1) db push 冇 emit, 2) duplicate column, 3) seed script 撞時序)。
- 上面 "Migration file in `main` 但 container 從未 rebuild 過" 講 dev-side stale 嘅 detection, 呢度講 customer-side fresh DB 嘅 drift 問題。兩個互補: 一個係 "改咗 source 但冇 rebuild", 一個係 "source 改咗但 migration 漏 emit"。

## References
- `references/rg-007-day17-migration-stale.md` — full reproduction
  transcript of the crm-system Day 17 "image never rebuilt" failure
  + 6-step recovery recipe (canonical example of this whole skill's
  class of bug)
- `references/pm-system-v1.0.0-db-push-drift.md` — full reproduction
  transcript of the pm-system v1.0.0 "db push never emit migration"
  customer-deploy failure + audit-recovery recipe
- `scripts/migration-lint.sh` — pre-commit lint for PascalCase
  identifier drift in new migrations (US-OPS-1)