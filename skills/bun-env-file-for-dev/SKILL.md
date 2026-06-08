---
name: bun-env-file-for-dev
description: Bun dev server requires --env-file flag to load .env; AWS SDK needs region env vars
tags: ["bun", "env", "dotenv", "aws-sdk"]
---
# Bun .env File Loading — Dev Server

## Problem
Bun runtime does NOT automatically load `.env` files. Unlike Node.js (which needs `dotenv` or similar), Bun has built-in support via `--env-file` flag. Without it, `process.env.VARIABLE` will be undefined even if the variable exists in `.env`.

## Symptoms
- `process.env.SES_REGION` is `undefined` in Bun dev server despite `SES_REGION=us-east-1` in `.env`
- SDK/API calls fail silently or with obscure errors because credentials/region env vars are missing
- Node.js works fine with same `.env` file (uses local AWS credentials chain)

## Correct Startup Command
```bash
bun --env-file=.env src/index.ts
```

**NOT** just `bun src/index.ts` — that loads no `.env`.

## Why This Matters for AWS SDK
- AWS SDK v3 (`@aws-sdk/client-ses`, etc.) reads `process.env.AWS_REGION` or `process.env.SES_REGION` to know which region to use
- Without the env file loaded, these are undefined and SDK calls fail
- Local dev credentials come from `~/.aws/credentials` (AWS CLI config), not ECS task role

## Verification
After starting with correct flags:
```bash
curl -s http://localhost:3000/health
curl -s -X POST "http://localhost:3000/api/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
# Should return {"ok":true,...} not 500
```

Check logs for `[SES] Email sent: <MessageId>` — if you see `[SES] Error:` followed by region/credential error, the `.env` was likely not loaded.

## 補充：path 陷阱 (2026-06 撞過)

`bun --env-file=.env` 喺 backend 入面 load 個 `.env` 喺 cwd。如果 backend 結構係 `~/www/<project>/backend/`，`.env` 喺 backend root，**`cd backend && bun --env-file=.env src/index.ts` 先 work**。如果用 IDE 嘅 run config / PM2 唔識 cwd，就壞。

**進階**：`--env-file` 喺 Elysia multi-file 項目，最好用 `import "dotenv/config"` 喺 entry script 頂部，或者用 `--env-file=.env --watch src/index.ts` 加埋 watch。`bun-runtime` 1.2.x 唔自動 load `.env`。

**Cross-reference**：成個 stack 嘅 bootstrap 見 `bun-elysia-react-vite-stack` skill。

## 補充：`bunx prisma db seed` 唔 load `.env` (2026-06-05 crm-system)

`prisma db seed` 透過 `package.json` `"prisma": { "seed": "..." }` 啟動子進程。**個子進程唔繼承 `bun --env-file`**，所以 Prisma 拎唔到 `DATABASE_URL`，`prisma.user.create()` 會 silent fail 入 `error: Environment variable not found: DATABASE_URL.`

兩個 fix，二揀一：

1. **Seed script 自己 load .env**（推薦，唔靠 caller flag）：
   ```ts
   // prisma/seed.ts top
   import { config } from 'dotenv';
   config({ path: '../../.env' });  // adjust path to your project root
   ```
   加 `dotenv` 入 devDeps。

2. **Caller 顯式 override env**：
   ```bash
   DATABASE_URL='postgresql://...' bunx prisma db seed
   ```
   但係 Hermes redact 機制會將 password 部分 mask 變 `***`，command 唔可靠。用 Python `os.environ['DATABASE_URL']` script 一次性跑就 OK。

**Day 1 用方案 1**（`import 'dotenv/config'` 加 top-level await + `dotenv` package）— 對 `prisma db seed` 同 entry 一致。

## ⚠️ `--env-file` 喺 boot-time hard-fail 嘅 testing 陷阱 (2026-06-07 crm-system Day 14)

`bun --env-file=.env` 嘅 env values **會做 floor** — 即使 shell `export JWT_SECRET=*** weak_value` 都唔會 override 個 file 入面嘅 value。

Concretely,寫完 boot-time `requireSecret('JWT_SECRET', { minLength: 32 })` 嘅 hard-fail 之後想 smoke test「missing secret」case 會撞牆:

```bash
# 期望: throw 因為 short secret
# 實際: throw 因為 .env file 嘅 value 先 load,根本見唔到 shell override
JWT_SECRET=*** src/index.ts
```

**2 個 fix 二揀一**:

1. **寫 temp env file**(推薦,clean):
   ```bash
   cp .env /tmp/crm-env-weak
   sed -i '' 's/JWT_SECRET=.*/JWT_SECRET=*** .2 weak' /tmp/crm-env-weak
   bun --env-file=/tmp/crm-env-weak src/index.ts
   # → 期望 throw
   ```

2. **入 hermes redact 嘅 masking** — `JWT_SECRET=*** 喺 shell 都會 redact,唔可靠。**唔好用。**

**`bunx prisma db seed` 嘅同類陷阱**:子進程唔繼承 `bun --env-file`,見上面「seed 唔 load .env」section。

**Smoke 4 個 case 必跑** 任何 boot-time secret check 之後:

| Case | 期望 | 設定方法 |
|---|---|---|
| Short secret | throw | temp env file |
| Dev fallback in production | throw | temp env file + `NODE_ENV=production` |
| Missing | throw | temp env file 刪走個 var |
| Valid | boot OK | 真嘅 `.env`(或者 shell export 喺冇 `--env-file` 嘅情況) |

詳見 `backend-rbac-audit-log` skill 嘅 Step 15。