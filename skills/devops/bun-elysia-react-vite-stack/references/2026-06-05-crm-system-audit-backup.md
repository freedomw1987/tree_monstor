# CRM System Day 6 — Audit 補完 + Backup/Restore Tooling (2026-06-05)

## 用戶選擇 (David 揀咗咩)

Day 6 係延續 Day 5 嘅 admin functionality — 用戶冇明確「要做 audit 補完」嘅 trigger,**我自己 default 行咗 A+C 兩個 scope** (audit instrumentation + backup/restore),直接開工。

## 1. Audit instrumentation 模式 (Step 8 of `backend-rbac-audit-log` skill)

**Day 5 instrument 咗** auth (login / login failed / password change) + user mgmt (created / updated / deactivated / deleted / password reset)。**Day 6 補完** CRM CRUD — 4 個 route files (quotation, company, contact, deal),每個 3 個 write endpoints (POST / PATCH / DELETE) 全部 instrumented。

### 一致 pattern (3 line)

```typescript
.post('/', async ({ body, set, userId, request }) => {
  const created = await prisma.<model>.create({ data: body as never });
  set.status = 201;
  await logEvent({                  // ← 第 3 line: 一致 pattern
    action: '<MODEL>_CREATED',
    actorId: userId ?? null,
    resourceType: '<model>',
    resourceId: created.id,
    description: `Created <model> ${<display field>}`,
    metadata: { <display fields> },
    request,                        // ← IP + UA 自動 capture
  });
  return created;
})
```

### Quotation 嘅特殊情況 (Step 8a)

`PATCH /quotations/:id` 同時處理 field update + status transition,要用 **branching log**:
- status 改咗 → `QUOTATION_STATUS_CHANGED` with `metadata: { from, to, number }`
- 其他 field → `QUOTATION_UPDATED` with `metadata: { number, fields: [...] }`

**Why separate actions**: audit page filter 要 "status changes last week", collapsing 入 UPDATES 會破壞 filtering UX;badge colour 都係跟 action 區分。

### Delete 嘅特殊情況

Delete 之前要 **snapshot the resource** 拎顯示 field (name / title / number),delete 之後 log 個 name 出嚟:
```typescript
const before = await prisma.<model>.findUnique({ where: { id: params.id }, select: { name: true } });
await prisma.<model>.delete({ where: { id: params.id } });
if (before) await logEvent({ action: '<MODEL>_DELETED', ..., description: `Deleted <model> ${before.name}`, metadata: { name: before.name }, request });
```

唔 snapshot → 個 description 只能講 "Deleted X" (冇 name),查 audit log 嘅時候好難 trace。

## 2. Backup / Restore 系統 (新領域)

**3 個 scripts + 1 個 docker-compose profile** — 全部新嘅,day 5 冇 cover。

### A. Host-side backup (`scripts/backup.sh`)

`docker exec` 跑 `pg_dump` 喺 postgres container,stream 出 gzip file:
```bash
./scripts/backup.sh                  # 預設 7 日 retention
./scripts/backup.sh --keep 30        # 30 日
./scripts/backup.sh --no-trim        # skip cleanup
```

**輸出**:
```
📦 Backing up crm_system@crm-postgres → /backups/crm_2026-06-05_132751.sql.gz
✅ Backup complete: .../crm_2026-06-05_132751.sql.gz (8.0K)
🧹 Trimming backups older than 7 days from /backups
   deleted 0 old backup(s)
📂 1 backup(s) in /backups (8.0K total)
```

**SQL dump 包含**:`--no-owner --clean --if-exists` flags → restore 唔撞 owner conflict,自動 drop + recreate objects。8K compressed (empty schema) 證明 dump 成功。

### B. Restore (`scripts/restore.sh`)

互動式揀 backup + safety confirm:
```bash
./scripts/restore.sh                                # interactive picker
./scripts/restore.sh backups/crm_xxx.sql.gz         # 直接
./scripts/restore.sh <file> --no-confirm            # CI mode
```

**Restore 流程** (重要 safety 細節):
1. **`docker compose stop api`** — 停 API service (避免 live connection 撞 psql DROP DATABASE)
2. **`DROP DATABASE IF EXISTS "crm_system"`** — 喺 postgres container 跑
3. **`CREATE DATABASE "crm_system" OWNER "crm"`** — recreate empty DB
4. **`gunzip -c <file> | docker exec psql -U crm -d crm_system -v ON_ERROR_STOP=1`** — 帶 `-v ON_ERROR_STOP=1` 撞錯就 stop,避免 partial restore
5. **`docker compose start api`** — restart API

**Pitfall 1**: 唔 stop API 就 restore → 個 API 仲 hold 住 connection,DROP DATABASE 會 hang 或 fail。

**Pitfall 2**: 唔用 `-v ON_ERROR_STOP=1` → 個 psql 默吞錯誤,部分 table 寫入失敗但 exit 0,restore 假成功但 data corrupted。

**Pitfall 3**: stat command 跨 OS: macOS `stat -f '%Sm'`,Linux `stat -c '%y'`,用 `2>/dev/null ||` fallback 兩邊都 work。

### C. Docker profile scheduled backup (`docker-compose.yml`)

**Profile** 設計模式 — opt-in:
```yaml
backup:
  profiles: ["backup"]    # 預設 off,要用 `docker compose --profile backup up -d` 先啟動
```

**Container 設計**: 用 `postgres:16-alpine` 入面已經有 BusyBox `crond`,mount 個 `backup-container.sh` 落 `/usr/local/bin/`:

```yaml
backup:
  image: postgres:16-alpine
  profiles: ["backup"]
  command:
    - -c
    - |
      echo "0 2 * * * /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root
      /usr/local/bin/backup.sh    # first run immediately
      crond -f -L /dev/stdout     # keep alive serving cron
  environment:
    PGPASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_HOST: postgres
    POSTGRES_DB: ${POSTGRES_DB}
    BACKUP_KEEP_DAYS: ${BACKUP_KEEP_DAYS:-7}
  volumes:
    - ./backups:/var/backups
    - ./scripts/backup-container.sh:/usr/local/bin/backup.sh:ro
```

**Skip mechanism**: `touch backups/skip` → container entrypoint check `if [ -f /var/backups/skip ]; then exit 0`,disables backups without removing the service。

### D. 兩個 backup script 嘅分別 (重要!)

| 環境 | Script | 連線方式 |
|---|---|---|
| **Host 跑** (`./scripts/backup.sh`) | Host script | `docker exec crm-postgres pg_dump` (要 host 有 docker + 識 container name) |
| **Container 跑** (cron job 內) | `backup-container.sh` | 直接 `pg_dump -h postgres -U crm -d crm_system` (compose 內部 hostname) |

**唔好用同一份 script** — host 版本要 `docker exec` 個 crm-postgres 容器,container 版本要 `pg_dump` 直接打 `postgres:5432`。**Mix up 會撞 `localhost:5432` connection refused 因為喺 container 內 `localhost` 係 container 自己**。

### E. .gitignore

```gitignore
backups/
*.sql.gz
```

**`backups/` 一定要 ignore** — `pg_dump` file 入面可能包含 PII (email, phone, audit log 入面 IP, password hash 冇但 reset token 可能有)。

## 3. Elysia 1.2 d.ts noise 確認

Day 6 加 `request` parameter 到 ~12 個 handler → 每個 handler 都有「`request: Request` type 唔 inferred」嘅 LSP squiggle,但 `bun run` runtime 唔 care。`write_file` lint 預設 `tsc --noEmit --skipLibCheck` 仲未啱用,error 噪音 100% pre-existing。

## Files modified/created Day 6

**Backend** (4 files modified, +~80 lines total):
- `apps/api/src/routes/quotation.ts` (+logEvent in 5 endpoints)
- `apps/api/src/routes/company.ts` (+logEvent in 3 endpoints)
- `apps/api/src/routes/contact.ts` (+logEvent in 3 endpoints)
- `apps/api/src/routes/deal.ts` (+logEvent in 3 endpoints)

**Scripts** (3 NEW files):
- `scripts/backup.sh` (host-side, 79 lines, chmod +x)
- `scripts/restore.sh` (interactive restore, 119 lines, chmod +x)
- `scripts/backup-container.sh` (in-container version, 32 lines, chmod +x)

**Infra** (2 files):
- `docker-compose.yml` (+backup profile, 36 lines)
- `.gitignore` (+backups/, +*.sql.gz)

## Verify 結果

```bash
$ ./scripts/backup.sh
📦 Backing up crm_system@crm-postgres → backups/crm_2026-06-05_132751.sql.gz
✅ Backup complete: .../crm_2026-06-05_132751.sql.gz (8.0K)
📂 1 backup(s) in backups/ (8.0K total)

$ gunzip -c backups/*.sql.gz | head -5
--
-- PostgreSQL database dump
--
\restrict xCMcRRBTnqPD98BZXuHXuswV0VWzcO68ypqdYtf95xMgB4OoOYsY2OEfBpAwE4e
-- Dumped from database version 16.14

$ docker compose ps
crm-api         Up (healthy)
crm-postgres    Up (healthy)
crm-web         Up (healthy)
```

🟢 Backup file 8K (empty schema),但 SQL 內容齊全 (CREATE TYPE / TABLE / INDEX / FK + ALTER TABLE DROP CONSTRAINT for --clean --if-exists restore)。API 改完 audit instrumentation 仲 boot 過。

## 下個 iteration 候選
- Backup container 嘅 first-run 即刻跑,亦有可能失敗 (race condition vs postgres init),可加 retry 機制
- Restore.sh 嘅 dry-run mode (check 個 SQL file valid 唔跑 restore)
- Backup encryption (gpg + age)
- Off-host backup destination (S3 / Backblaze B2) for disaster recovery
- Audit log retention policy (90 days 之後 archive 到 cold storage)
