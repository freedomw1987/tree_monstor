# Stack health diagnostic when E2E stack fails to start

## 點解呢個 reference 重要

Docker stack (`docker compose up -d --build`) 起唔到 → E2E 完全跑唔到。**Backend 連 health check 都 fail** → 必須 fix 至 stack health 100% 至可以跑 E2E。

呢個 reference 講 4 個最常見嘅 stack 起唔到 root cause,每個都有 E2E-impact 嘅 fix path。

## Pattern 1: Frontend Vite build silent fail on `await in sync function`

### 案例 (pm-system 2026-06-09)

`frontend/src/pages/WorkLogsPage.tsx:413`:
```typescript
// ❌ Bug: onClick callback 唔係 async 但有 await
<Button
  onClick={() => {
    // ... synchronous code
    const buffer = await ws2.xlsx.writeBuffer()   // ← ReferenceError
    saveAs(new Blob([buffer]), 'worklogs.xlsx')
  }}
>
  Export
</Button>
```

**Migration 引入 sibling bug**:
- 之前用 `xlsx` 套件(舊,unmaintained,有 CVE — RG-018 觸發)
- 換成 `exceljs`(新,async/await based)
- 換嘅過程漏咗 `onClick` callback 加 `async` keyword
- 個 callback 仍然 sync(`() => { ... }` 而非 `async () => { ... }`)
- Vite build 撞 `ReferenceError: await is only valid in async functions` → build fail → docker image build fail → container exit

### 點樣 detect

```bash
# 1. docker compose up 失敗
docker compose up -d --build
# Frontend container exit 1

# 2. 睇 container log
docker compose logs frontend
# "ReferenceError: await is only valid in async functions"
# OR
# "[vite:build] Transform failed with 1 error"
```

### 點樣 fix

```typescript
// ✅ Fix: callback 加 async + try/catch
<Button
  onClick={async () => {
    try {
      const buffer = await ws2.xlsx.writeBuffer()
      saveAs(new Blob([buffer]), 'worklogs.xlsx')
    } catch (err) {
      console.error('Export failed:', err)
    }
  }}
>
  Export
</Button>
```

### 防呆 pattern

任何時候 migrate async lib(`xlsx` → `exceljs`, `request` → `fetch`, callback → Promise)嘅 PR:

1. **Grep 全 project 所有 `await` 嘅 callback context**:
   ```bash
   rg -B 2 'await ' frontend/src --type ts --type tsx
   # 對每個 await,check 上 2 行係咪 async 函數 / async arrow
   ```

2. **Build verification before ship**:
   ```bash
   cd frontend && bun run build
   # 必須 pass
   ```

3. **Container verification**:
   ```bash
   docker compose up -d --build frontend
   docker compose ps frontend
   # STATUS 必須 Up(唔可以 Exit 1)
   ```

### Lesson 對 E2E 嘅 impact

- Frontend build fail → frontend container exit → E2E stack 唔齊 → Playwright `page.goto('http://localhost:8080/')` 失敗
- 即使 backend 100% healthy,frontend 起唔到 → 整個 E2E 跑唔到
- **Stack health 必須 100%(backend + frontend + db)至可以宣稱 E2E pass**

## Pattern 2: Prisma 7 strict validation at runtime (not build time)

### 案例 (pm-system 2026-06-09)

`backend/prisma.config.ts`:
```typescript
// ❌ 第一次寫
import { defineConfig } from "prisma/config"
export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: { url: process.env["DATABASE_URL"]! },   // ← 撞 strict validation
})
```

`backend/Dockerfile`:
```dockerfile
# ❌ 漏 COPY
COPY prisma ./prisma
COPY src ./src
# 冇 COPY prisma.config.ts → image 入面冇呢個 file
```

**Symptom**:
- 本地 `bun run dev` 正常 (讀 local `prisma.config.ts`)
- `docker build` 過
- `docker compose up` 失敗,bun 撞:
  ```
  Prisma config file loaded from prisma.config.ts.
  error: The datasource.url property is required in your Prisma config file.
  ```
- Backend container exit 1

### 點樣 detect

```bash
docker compose logs backend
# 1. "datasource.url property is required" → prisma.config.ts strict validation fail
# 2. "Cannot find module 'prisma.config'" → file 唔存在(image 漏 COPY)
```

### 點樣 fix

兩個 fix 都要做:

**Fix 1: prisma.config.ts 用 `env()` helper**:
```typescript
import { defineConfig, env } from "prisma/config"
export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: { url: env("DATABASE_URL") },
})
```

**Fix 2: Dockerfile builder + runtime stage COPY**:
```dockerfile
# Builder
COPY prisma.config.ts ./
ARG DATABASE_URL=dummy:placeholder@host:5432/db
ENV DATABASE_URL=$DATABASE_URL

# Runtime
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
```

### 防呆 pattern

Prisma 7 + Docker 嘅 PR:
1. **`docker run --rm <image> ls <prisma.config.path>` 確認 file 入咗**
2. **`docker compose up backend` 跑一次睇 log**
3. **CI 跑完整 `docker compose up -d --build` 然後 E2E**

詳細 pitfall 見 `prisma-sqlite-bun-setup` skill 嘅 "Prisma 7 strict validation 嘅 generic pitfalls" section。

## Pattern 3: Docker volume mount 漏 migration

有時 migration 喺 host 加咗,但 container 嘅 entrypoint 跑 baked-in 嘅 migrate,見唔到。

### 點樣 detect
```bash
docker compose logs backend
# "P3009 migrate found drift" 或 "no migration found"
```

### 點樣 fix
```bash
# Option A: 重新 bake image
docker compose build --no-cache backend

# Option B: 直接 cp 落 container
docker cp packages/db/prisma/migrations/ <container>:/app/packages/db/prisma/migrations/
docker compose restart backend
```

## Pattern 4: Redis / external dep miss 喺 startup

### 點樣 detect
```bash
docker compose logs backend
# "ECONNREFUSED 127.0.0.1:6379" 或 "Redis connection failed"
```

### 點樣 fix
- 加 `depends_on: redis:` 喺 docker-compose.yml
- 加 healthcheck 確保 redis healthy 至啟動 backend

## Stack health 100% checklist

```bash
# 1. 全部 container Up
docker compose ps
# 期待: 全 Up, 0 Exit, 0 Restarting

# 2. Backend health
curl http://localhost:4001/api/agent-health/
# 期待: {"status":"ok","connectedAgents":N}

# 3. Frontend health
curl -I http://localhost:8080/
# 期待: HTTP/1.1 200

# 4. DB 連通
docker compose exec db psql -U user -d db -c "SELECT 1"

# 5. Login flow
curl -X POST http://localhost:4001/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.42" \
  -d '{"email":"admin@test.com","password":"admin123"}'
# 期待: 200 + accessToken

# 6. 跑 E2E
cd e2e && npx playwright test
# 期待: 全 pass
```

**任何一步 fail → 必須 fix 至 100% green 至算 sprint done**。
