---
name: prisma-sqlite-bun-setup
description: Prisma schema 適配 SQLite 的正確方式 — enum 改 string、Json 改 String、Prisma 5 vs 7 差異、seed 注意事項、Bun 生態環境的常見坑。也涵蓋 Prisma 7 strict validation 嘅 generic pitfalls (適用於 SQLite / PostgreSQL),特別係 `prisma.config.ts` + Dockerfile COPY 嘅 deployment trap。
tags: ["prisma", "sqlite", "bun", "debugging", "backend"]
related_skills: ["elysia-typescript-workarounds", "elysia-aws-lambda-deploy"]
---


Last-verified: 2026-07-28
# Prisma + SQLite 在 Bun 環境的完整攻略

## 常見情境
- 沒有 PostgreSQL，暫時用 SQLite 開發
- Prisma 7 的破壞性變更導致舊程式碼炸掉
- 部署到 AWS Lambda 需要 Prisma adapter

---

## Prisma 7 vs Prisma 5 關鍵差異

> **⚠️ 實戰教訓 (2026-06-04): Prisma 7 嘅 migration 路徑極不順，強烈建議用 Prisma 5 開始新 SQLite 項目。**

### Prisma 5（推薦用呢個做 SQLite 開發）✅

最簡單、最穩定。`schema.prisma` 照常寫 `url = env("DATABASE_URL")`，`prisma migrate dev` 直接 work。

```bash
bun add prisma@5 @prisma/client@5
bunx prisma generate
bunx prisma migrate dev --name init
```

### Prisma 7 — 撞牆實錄 ❌

裝 `prisma@latest` 自動拉到 7.8.0，立即撞：

1. **`prisma generate` 失敗**：
   ```
   error: The datasource property `url` is no longer supported in schema files.
   Move connection URLs for Migrate to `prisma.config.ts` ...
   ```

2. **改用 Prisma 7 規範路徑**，要 `prisma.config.ts` + `prisma-client-js` output：
   ```typescript
   // prisma.config.ts
   import "dotenv/config"
   import { defineConfig } from "prisma/config"
   export default defineConfig({
     schema: "prisma/schema.prisma",
     migrations: { path: "prisma/migrations" },
     datasource: { url: process.env["DATABASE_URL"] },
   })
   ```
   然後 `schema.prisma` 入面 `datasource db { url = env("DATABASE_URL") }` 會繼續撞牆 — 必須用新嘅 `previewFeatures = ["driverAdapters"]` + adapter 模式（極複雜）。

3. **更慘**：`prisma migrate dev --name init` 跑得起，但 `prisma.answer.create()` runtime 因為 SQLite + driver adapter 配合未成熟會有微妙問題。

**結論：Prisma 7 唔啱 SQLite 開發，downgrade 去 Prisma 5.22.0 一次搞掂。**

### Prisma 5 schema 範例（推薦）

```prisma
datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")   # Prisma 5 直接 work
}

generator client {
  provider = "prisma-client-js"
  output   = "../node_modules/.prisma/client"   # default
}
```

---

## SQLite 不支援的功能（必須避開）

| 不支援 | 解決方式 |
|--------|---------|
| Enum | 改用 `String`，程式碼中用 `"STUDENT"` `"TEACHER"` 字串常量 |
| Json type | 改用 `String`，存入時 `JSON.stringify()`，取出時 `JSON.parse()` |
| Array type（部分場景）| 存成 `String`（JSON array） |

**Schema 範例（正確）：**
```prisma
model User {
  id           String   @id @default(cuid())
  email        String   @unique
  passwordHash String
  name         String
  role         String   @default("STUDENT")   # 不是 enum，是 String
  # ...
}

model QuizQuestion {
  id           String @id @default(cuid())
  question     String
  options      String # 存 JSON.stringify(['opt1','opt2','opt3'])
  correctIndex Int
  # ...
}
```

---

## Seed 注意事項

**1. 不用 Prisma enum 型別**
```typescript
# 錯
import { PrismaClient, UserRole } from "@prisma/client"
role: UserRole.STUDENT   # Prisma 7 不再導出這些 enum

# 對
role: "STUDENT"   # 直接用字串
```

**2. 存入 JSON 欄位要用 JSON.stringify**
```typescript
options: JSON.stringify(["A", "B", "C", "D"]),  # 不是 array
```

**3. Bun 的 dotenv 需額外安裝**
```bash
bun add dotenv
```
且 `prisma.config.ts` 必須 `import "dotenv/config"` 否則 `DATABASE_URL` 讀不到。

---

## Bun 環境快速啟動命令

```bash
# 初始化（SQLite）
bunx prisma init
# 手動寫 schema.prisma（避開 enum/Json）

# Generate + migrate + seed
bun run prisma generate
bun run prisma migrate dev --name init
bun run seed

# 啟動 API
bun run src/index.ts   # Elysia 應用
```

---

## Prisma 7 炸掉的徵兆

錯誤訊息包含：
- `Expected 1 arguments, but got 0`（PrismaClient 初始化問題）
- `Export named 'UserRole' not found`（enum 被移除但程式碼還在 import）
- `Options field can't be of type Json`（SQLite 不支援）
- `url is missing in data source block`（Prisma 7 需要明確 url）

---

## 部署到 Lambda 的注意點

Prisma 7 的 client 需要正確的 adapter。若用 `@elysiajs/eden` + Prisma，確認 `.prisma/client` 有被正確 bundle 进 Lambda zip。

若看到 `Cannot find @prisma/client` 在 Lambda 上，先確認：
1. `bun run prisma generate` 有執行
2. `node_modules/@prisma/client` 有被包含在 zip 中（不要设成 external）

---

## Prisma 7 strict validation 嘅 generic pitfalls (適用於 SQLite / PostgreSQL)

> **2026-06-09 pm-system 實戰教訓 (RG-011)** — 即使用 PostgreSQL(非 SQLite),Prisma 7 嘅 strict validation 仲會喺 runtime container 入面炸。

### `datasource.url` 必須用 `env()` helper,唔可以用 `process.env["..."]`

Prisma 7 嘅 `prisma.config.ts` 對 `datasource.url` 做 strict type validation,**只接受 literal string 或 `env()` wrapper**:

```typescript
// ✅ 對:用 env() helper
import { defineConfig, env } from "prisma/config"
export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: { url: env("DATABASE_URL") },   // ← 用 env()
})

// ❌ 錯:用 process.env 直接讀
import { defineConfig } from "prisma/config"
export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: { url: process.env["DATABASE_URL"]! },   // ← 撞 "datasource.url property is required"
})
```

### Dockerfile 漏 COPY `prisma.config.ts` 嘅 silent break

**Symptom**: `docker build` 過,`docker run` 入面 `bunx prisma generate` / `prisma db push` 撞:
```
Prisma config file loaded from prisma.config.ts.
error: The datasource.url property is required in your Prisma config file.
```

**Root cause**: Prisma 7 喺 runtime 重新讀 `prisma.config.ts`,而 Dockerfile 嘅 `COPY` 漏咗呢個 root-level file。

**Fix recipe**(多-stage Dockerfile):

```dockerfile
# Builder stage
FROM oven/bun:1-alpine AS builder
WORKDIR /app
COPY package.json bun.lock ./
COPY prisma ./prisma
COPY src ./src
COPY prisma.config.ts ./          # ← 必須! root-level file 唔會被 COPY prisma/ 帶入
ARG DATABASE_URL=dummy:placeholder@host:5432/db   # ← builder 跑 prisma generate 要
ENV DATABASE_URL=$DATABASE_URL
RUN bun install --frozen-lockfile
RUN bunx prisma generate

# Runtime stage
FROM oven/bun:1-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.prisma ./.prisma
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/src ./src
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts   # ← 同樣要 COPY
COPY --from=builder /app/tsconfig.json ./tsconfig.json
ENV NODE_ENV=production
ENV DATABASE_URL=                 # runtime 由 docker-compose env 注入
CMD ["bun", "run", "src/index.ts"]
```

**Key points**:
1. **builder stage 嘅 `env()` strict check**:`prisma generate` 跑時 Prisma 會 require `DATABASE_URL` set(即使真 value 唔用)。用 `ARG DATABASE_URL=dummy:placeholder@host:5432/db` 過 strict check 即可。
2. **runtime stage 嘅 DATABASE_URL**:唔寫死,`docker-compose.yml` 嘅 `environment` 注入。
3. **`.dockerignore`**:確認 `prisma.config.ts` 唔被 ignore(`!prisma.config.ts` 喺 `.dockerignore` 入面)。

### Verification 步驟

```bash
# 1. 確認 prisma.config.ts 真係入咗 image
docker run --rm <image> ls /app/prisma.config.ts

# 2. 跑一次 entrypoint,睇 log
docker compose up backend
# 期待 log: "Loaded Prisma config from prisma.config.ts." (無 error)

# 3. 確認 migrations 跑得通
docker compose exec backend bunx prisma migrate status
```

### Why 容易 miss 呢個 pitfall

- **本地 dev 唔撞**:`bun run dev` 直接讀 local `prisma.config.ts`。
- **CI build 唔撞**:`prisma generate` 通常喺 CI 跑,但 CI 設咗 dummy `DATABASE_URL` 過 strict check。
- **Production image build 過**:`prisma.config.ts` 唔喺 `prisma/` 入面,build 過唔代表 file 入咗 image。
- **Production runtime 先撞**:`bunx prisma db push`(entrypoint script 跑)撞 "datasource.url required"。

**Lesson**:任何 Prisma 7 嘅 Dockerfile change → 必須 `docker run --rm <image> ls <prisma.config.path>` 確認 + 跑一次 entrypoint 睇 log。CI build 過唔代表 runtime 冇事。