# pm-system v1.0.0 — "db push 冇 emit migration" Customer Deploy Failure

## 背景
2026-06-09, pm-system 第一個客戶 release。項目用 `prisma db push` 改 schema 改咗幾個 sprint,**從未** emit 對應 migration。客戶機 fresh DB 跑 `prisma migrate deploy` 撞 `relation "public.Role" does not exist` 因為 init migration (`20260521053128_init`) 根本冇 CREATE `Role` table。

## 完整 audit
- Schema 19 個 model
- Init migration 只有 10 個 CREATE TABLE(2026-05-21 嗰陣 schema 仲細)
- Subtask migration 加多 1 個 (`task_participants`)
- **缺 8 個 CREATE TABLE**:`departments` / `Role` / `Permission` / `llm_configs` / `wiki_pages` / `chat_sessions` / `chat_messages` / `token_logs`
- 7 個現有 table 缺 column(users.role/is_agent/agent_config/department_id, projects.start_date/end_date/department_id, requirements.priority/assignee_id, tasks.project_id/parent_task_id/claimed_by_agent_at, bugs.project_id/requirement_id/assignee_id, work_logs.description, attachments.project_id)

## 修法
1. 跑 `bunx prisma migrate diff --from-migrations ./prisma/migrations --to-schema-datamodel ./prisma/schema.prisma --script` 拿到 212 行 audit SQL
2. 寫 `backend/prisma/migrations/20260609000000_sync_schema_to_v2/migration.sql`(timestamp 晚過 init + subtask)
3. Audit duplicate column — 第一次撞 `column "parent_task_id" of relation "tasks" already exists` 因為 subtask migration 已經 add 過
4. 移除 duplicate `parent_task_id` ADD COLUMN + `tasks_parent_task_id_fkey` ADD CONSTRAINT 從新 migration
5. Rebuild image, customer retry install, pass

## 教訓(寫入 prevention SOP)
- 任何 schema 改完即 `bunx prisma migrate dev --create-only --name X` 睇 SQL
- 唔好用 `bunx prisma db push`
- CI lint 強制: 改 `prisma/schema.prisma` 必須同時改 `prisma/migrations/<新>/migration.sql`
- `migrate diff --from-migrations --to-schema-datamodel --script` 一句過 emit 全部差異, 比人手 audit schema.prisma + migrations file 可靠

## Symptoms 識別 checklist
客戶 deploy 撞以下任一,即係呢個 case:
- `column "X" of relation "Y" already exists` (P3009)
- `relation "X" does not exist` (42P01)
- `_prisma_migrations` table 入面有 failed migration record 停滯
- 客戶 fresh DB 撞, dev DB 冇事(因為 dev 用 db push 已 sync)
