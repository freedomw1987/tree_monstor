---
name: prisma-migrate-private-rds
description: Run Prisma migrations on private RDS via ECS one-off task when CodeBuild can't reach the database
category: devops
---

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
  --network-configuration "awsvpcConfiguration={subnets=[subnet-01255018d4a3a1b1f,subnet-0c5ce99b7d83c693b],securityGroups=[sg-01d213a5c6e416f40],assignPublicIp=DISABLED}" \
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