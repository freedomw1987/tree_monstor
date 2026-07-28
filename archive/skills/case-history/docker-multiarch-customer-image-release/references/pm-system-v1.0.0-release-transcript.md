# PM-System v1.0.0 Customer Release — Full Reproduction Transcript

## 背景
2026-06-09, 客戶機 deploy 第一個 release。客戶要求:
- 唔畀 source code(只畀 Docker image)
- 客戶機有 x86 (amd64) 同 arm (arm64) 兩種, 要都行
- 會有後續 update

## 7-round debug 紀錄(逐 round 撞 + 修)

### Round 1: `docker buildx build --platform amd64,arm64 --load` 撞 manifest list export
```
ERROR: failed to build: docker exporter does not currently support exporting manifest lists
```
**修法**: 拆 2 次 build(amd64 / arm64 分開 `--load`)+ 各自 `docker save`。

### Round 2: `docker manifest create` 撞 pull access denied
```
ERROR: pull access denied, repository does not exist or may require authorization
server message: insufficient_scope: authorization failed
```
**修法**: 確認 Docker Desktop 上 multi-arch manifest list 必須靠 registry。**改用 per-arch tarball** (Q1 = B 而唔係 A)。

### Round 3: `docker save` 後 tag 唔 match
`docker save` 嘅 tar 內 manifest 寫住 `:v1.0.0-arm64`, 客戶機 load 完**唔會**自動有 `:v1.0.0` tag, docker-compose 撞 `No such image: pm-system-backend:v1.0.0`。
**修法**: install.sh `docker load` 之後 `docker tag <orig> <target>`, 加 `sleep 1` 防 race condition。

### Round 4: `bun:1-alpine` 冇 `curl`
```
/bin/sh: curl: not found
```
**修法**: 改用 `wget`(alpine busybox 預設有)。

### Round 5: Backend startup 撞 `prisma.role.findMany() — table "public.Role" does not exist`
**根因**: 項目用 `prisma db push` 改 schema, 8 個 model 從未 emit migration。init migration (`20260521053128_init`) 唔包 `Role` / `Permission` / `LLMConfig` / `WikiPage` / `ChatSession` / `ChatMessage` / `Department` / `TokenLog` 嘅 CREATE TABLE。
**修法**: 寫 `20260609000000_sync_schema_to_v2/migration.sql` 補:
- 7 個現有 table 缺 column (users.role/is_agent/agent_config/department_id, projects.start_date/end_date/department_id, requirements.priority/assignee_id, tasks.project_id/parent_task_id/claimed_by_agent_at, bugs.project_id/requirement_id/assignee_id, work_logs.description, attachments.project_id)
- 8 個 missing table 全部 CREATE
- 對應 FK constraints

### Round 6: 新 migration 撞 `column "parent_task_id" of relation "tasks" already exists`
**根因**: subtask migration (`20260601000000_task_participants_subtasks`) 已經 add 過 `parent_task_id` column, 我 audit 漏咗。
**修法**: audit 返所有 migration 入面嘅 `ALTER TABLE ... ADD COLUMN`, 從新 migration 移除 duplicate `parent_task_id` 同相關 FK constraint。

### Round 7: P1000 Authentication failed
**根因**: 客戶機 sim 環境之前嘅 sim 有 pm-system-postgres-data volume 殘留, 第一次啟動已經 init 咗 `pmuser` 用緊舊密碼。改 .env `DB_PASSWORD` 唔會 recreate user(PostgreSQL 15 POSTGRES_PASSWORD 只第一次啟動生效)。
**修法**: sim 重置一定要 `docker volume ls | grep pm-system | xargs docker volume rm`(注意: `docker compose down -v` 因為 `--project-name` override, 只清 `pm-system_postgres_data` 唔清 `pm-system-postgres-data`)。

## Smoke test 通過嘅 verification 步驟

```bash
# 1. Install.sh 跑完, 全部 step pass
==> 5/6 啟動 containers
  Container pm-system-backend  Healthy
==> 6/6 等 backend health
  ✓ backend healthy (用咗 0s)

# 2. Curl frontend + backend
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8888/
# → HTTP 200

curl -s http://localhost:8888/api/projects
# → {"projects":[]} HTTP 200

# 3. Verify seed data
docker exec pm-system-db psql -U pmuser -d pmdb -c "SELECT email, role FROM users;"
# → 6 個 user (5 built-in + 1 agent)

# 4. Verify all 19 models 嘅 table 存在
docker exec pm-system-db psql -U pmuser -d pmdb -c \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
# → 20 (19 models + _prisma_migrations)
```

## 客戶收貨清單(實際 ship 嘅)
```
pm-system-release-v1.0.0/
├── README.md                            # 1 張紙 3 步裝完
├── install.sh                           # 客戶跑呢個 (chmod +x)
├── docker-compose.client.yml            # 客戶 compose (冇 seed by default 改有 seed)
├── .env.client.example                  # 客戶 copy 做 .env, 改 3 個 PLACEHOLDER
├── CHECKSUMS.sha256
├── RELEASE-NOTES.md
├── pm-system-frontend-v1.0.0-amd64.tar   # 63 MB
├── pm-system-frontend-v1.0.0-arm64.tar   # 62 MB
├── pm-system-backend-v1.0.0-amd64.tar    # 642 MB
└── pm-system-backend-v1.0.0-arm64.tar    # 634 MB
```

## 相關 commit (pm-system repo)
```
dd178e0 fix(prisma): add 20260609000000_sync_schema_to_v2 migration
965b742 feat(deploy): PM-System v1.0.0 client release toolchain
```
