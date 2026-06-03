---
name: prisma-sqlite-bun-setup
description: Prisma schema 適配 SQLite 的正確方式 — enum 改 string、Json 改 String、Prisma 5 vs 7 差異、seed 注意事項、Bun 生態環境的常見坑
tags: ["prisma", "sqlite", "bun", "debugging", "backend"]
related_skills: ["elysia-typescript-workarounds", "elysia-aws-lambda-deploy"]
---

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