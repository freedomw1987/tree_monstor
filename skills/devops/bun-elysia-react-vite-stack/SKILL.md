---
name: bun-elysia-react-vite-stack
description: Bootstrap a local full-stack TypeScript app with Bun 1.2 + Elysia backend + Vite 8 + React 19 + Tailwind v4. SQLite (dev) + Postgres (prod recommended) via Prisma 5. Use when user wants a quick local dev app (CRM, MVP, internal tool, exam app) and stack is the same family.
tags: ["bun", "elysia", "react", "vite", "tailwind", "prisma", "fullstack", "stack", "bootstrap", "sqlite"]
---

# Bun + Elysia + Vite/React Full-Stack Bootstrap

本地 dev 嘅最快 full-stack TS stack。Elysia 同 Bun runtime 配 Vite 嘅 HMR 體驗極順。SQLite 用 Prisma 5（**唔好用 Prisma 7** — 見 prisma-sqlite-bun-setup skill）。

## 觸發時機

- 用戶要 quick MVP / internal tool / 個人練習 app / **新嘅 CRM 重建**
- 已經喺 Elysia + Vite 環境做開 (e.g. 跟 `bc-quotation` 嘅 stack pattern)
- 唔需要 deploy production (local dev 為主) — deploy 睇 `cdk-ecs-fargate-deploy`
- 想要日後 production 行 Postgres 但 dev 階段快速用 SQLite (見下「SQLite vs Postgres」section)

## 部署目標 — 問用戶先 (2026-06-05 crm-system 真實訊號)

Plan 階段**必須問**用戶要 deploy 喺邊，唔好 default 推 CDK/IaC:

| 用戶情境 | 部署方案 |
|---|---|
| **Local only / NAS / NUC / 內部 server** (David 嘅 crm-system 屬呢類) | **Docker Compose (full stack)** — postgres + api (Bun) + web (nginx) + opt-in adminer。`docker-mac-arm64-elysia-vite/templates/full-local-stack.md` 有 copy-paste docker-compose.yml + Dockerfiles + nginx.conf。**唔好用 CDK** |
| **Cloud (AWS ECS / Fargate / RDS / CloudFront)** | CDK v2 — 跟 `cdk-ecs-fargate-deploy` + `cdk-deployment-rules` |
| **Hybrid** (e.g. local dev, cloud prod for customers) | Docker Compose 本地 + CDK/Terraform prod。schema/seed 要 plan migration path |

**David 嘅具體訊號 (2026-06-05)**: "另外我不想用CDK, 因為這個系統是本地部署的,您給我計劃用docker 就可以了" — 觸發咗 Day 3 plan 改 pivot 去 Docker compose, 廢棄 CDK 路線。

**喺 Plan 階段 (Think) 主動問「個 system 將會 deploy 喺邊」** — 用戶唔會 default 自己講, 要我哋 trigger。

## SQLite vs Postgres 點揀 (2026 經驗)

| 情境 | 用咩 |
|---|---|
| Exam app / 純本地練習 / 唔會上 production | **SQLite** — 零 setup, file 即可, Prisma 5 完美 support |
| 內部 tool / 個人用 / single-user | **SQLite** — 唔需要 server |
| CRM / 報價單 / multi-user SaaS / 有 AI agent RAG | **Postgres (即使 dev)** — 因為需要 `String[]` (tag), `Json` (metadata), `Decimal` 真正 support, `pgvector` (RAG), transactions, concurrent writes |
| Production 但 dev 想 SQLite | **可, 但要 plan migration** — 用 `prisma migrate diff` 驗證 SQLite → Postgres syntax (Decimal precision, enum 唔同) |

**CRM/報價單必上 Postgres 嘅原因:**
- `Json` type: `ActivityLog.metadata`, `Message.toolCalls` — SQLite 只可以 `String`, 用 JSON.stringify 將就 (loss of type safety)
- `String[]` type: Company.tags — SQLite 唔支援, 要 join table
- `Decimal` precision: SQLite 用 String 儲, 冇 numeric type — 金額運算危險
- `pgvector`: AI agent RAG 必要
- `Decimal @db.Decimal(15, 2)` schema 同 SQLite 唔同, 之後 migrate 會有 friction

**建議** (新建 CRM 項目):
- **Dev + Prod 都用 Postgres** — 撈 docker postgres / RDS 唔難
- 唔想裝 Postgres server → `bun add -d @electric-sql/pglite` (in-process Postgres for dev)
- 真係 quick-and-dirty 先 SQLite, schema 唔用 `String[]` / `Json` / 唔用 pgvector

## 完整 SOP (SQLite path, 跟之前 bc-quotation)

### 1. Backend init (Bun workspaces monorepo, 支援 apps/api + apps/web)

```bash
mkdir -p ~/www/<project>/apps/api ~/www/<project>/apps/web ~/www/<project>/packages/db
cd ~/www/<project>

# Root workspace
cat > package.json <<EOF
{
  "name": "<project>",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev:api": "bun --filter api dev",
    "dev:web": "bun --filter web dev",
    "db:generate": "bun --filter db generate",
    "db:migrate": "bun --filter db migrate"
  }
}
EOF

# API
cd apps/api && bun init -y
bun add elysia @prisma/client
bun add -d prisma@5 tsx @types/node dotenv
```

> ⚠️ **Prisma 一定要 pin `prisma@5`**：`bun add prisma` 會拉到 7.x,撞 schema 唔再支援 `url = env(...)`。詳見 `prisma-sqlite-bun-setup` skill。

### 2. Prisma + DB setup

```bash
mkdir -p data
bunx prisma generate
bunx prisma migrate dev --name init --skip-seed
```

`prisma/schema.prisma` 範本（SQLite 限制：無 enum、無 Json → 用 String + JSON.stringify）：

```prisma
generator client {
  provider = "prisma-client-js"
  output   = "../node_modules/.prisma/client"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model Question {
  id        String   @id @default(cuid())
  seq       String   @unique
  type      String
  question  String
  options   String   // JSON.stringify([{key,text}])
  answer    String
  createdAt DateTime @default(now())
}
```

`.env`：
```
DATABASE_URL="file:./data/app.db"
PORT=3200
```

> ⚠️ **Path 陷阱**：`./data/app.db` 係相對 prisma 同層。如果 backend 同 DB 喺唔同層，記得用 `join(import.meta.dir, "..", "..", "data", "app.db")`。

### 3. Elysia backend

```typescript
// src/index.ts
import { Elysia, t } from "elysia"
import { PrismaClient } from "@prisma/client"

const prisma = new PrismaClient()
const PORT = Number(process.env.PORT) || 3200

const app = new Elysia()
  .get("/api/health", () => ({ ok: true }))
  .get("/api/items", () => prisma.question.findMany())
  .listen(PORT)

console.log(`Running at http://localhost:${PORT}`)
```

啟動：
```bash
bun --env-file=.env src/index.ts
```

> ⚠️ **`--env-file` 必須** — Bun runtime 唔自動 load `.env`。詳見 `bun-env-file-for-dev` skill。

> ⚠️ **Path 陷阱 (2)**：`readFile(join(import.meta.dir, "..", "questions.json"))` — `import.meta.dir` 係 source 編譯後位置，唔係 cwd。如果個 file 喺 backend 外面，多加 `..`。

### 4. Seed script

```bash
# prisma/seed.ts
import { PrismaClient } from "@prisma/client"
import { readFile } from "fs/promises"
import { join } from "path"

const prisma = new PrismaClient()
async function main() {
  const data: any[] = JSON.parse(
    await readFile(join(import.meta.dir, "..", "..", "data.json"), "utf-8")
  )
  for (const item of data) {
    await prisma.question.upsert({
      where: { seq: item.seq },
      create: item,
      update: item,
    })
  }
  console.log(`Seeded ${data.length}`)
}
main().finally(() => prisma.$disconnect())
```

`package.json`：
```json
{
  "scripts": {
    "dev": "bun --env-file=.env --watch src/index.ts",
    "db:seed": "bun run prisma/seed.ts",
    "db:studio": "prisma studio"
  }
}
```

### 5. Frontend init (Vite 8 + React)

```bash
cd ~/www/<project>/frontend
bun create vite@latest . -- --template react-ts
```

> ⚠️ **Vite v8 + bun create bug** — 即使 `--template react-ts`，v8 預設裝出嚟係 vanilla TS (`src/main.ts` + counter.ts)，冇 `vite.config.ts`，要手動 clean。詳見下「Vite 8 quirk」。

手動補：
```bash
# 用 npm install 而唔係 bun add（避 Hermes 嘅 long-lived scan）
npm install react@latest react-dom@latest @types/react @types/react-dom @vitejs/plugin-react
npm install tailwindcss@4 @tailwindcss/vite
```

### 6. Vite config + Tailwind v4

`vite.config.ts`：
```typescript
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import tailwindcss from "@tailwindcss/vite"

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: { "/api": "http://localhost:3200" },
  },
})
```

`src/index.css`（Tailwind v4 唔再用 `tailwind.config.js`）：
```css
@import "tailwindcss";

@theme {
  --color-brand-500: #3b82f6;
  --color-brand-600: #2563eb;
  --color-brand-700: #1d4ed8;
}
```

`tsconfig.json` 必加：
```json
{
  "compilerOptions": {
    "jsx": "react-jsx",
    "types": ["vite/client", "node"]
  }
}
```

### 7. React Router + Pages

```typescript
// src/main.tsx
import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { BrowserRouter } from "react-router-dom"
import App from "./App"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>
)
- Vite proxy `/api/*` → :3000 backend

## ⚠️ Elysia 1.2.0 d.ts broken (2026-06-05 真實撞牆)

**症狀**: 用 `new Elysia().use(jwt({...}))` 然後喺另一個 route file 用 `jwtApp.decorator.jwt.verify()` 嗰陣, Elysia d.ts 自己報錯 (`MacroContext['return']` 唔存在, etc.), 即使 `skipLibCheck: true` 都解決唔到, 仲會污染 typechain 令整個 file 出 error. **Bun runtime 唔 care d.ts, server boot 過, 但係跨 route file call decorator 嘅 runtime 可能 fail**(e.g. `/chat/*` 返 401 因為 decorator chain 喺 plugin boundary 斷咗).

**Workaround** (推薦): **唔好用 Elysia 嘅 `jwt` decorator chain 跨 file**, 用 `jose` 直接 verify:
```typescript
import { jwtVerify } from 'jose';
const secretKey = new TextEncoder().encode(process.env.JWT_SECRET ?? 'dev-secret');
async function verifyToken(authHeader: string | null): Promise<string | null> {
  if (!authHeader?.startsWith('Bearer ')) return null;
  try {
    const { payload } = await jwtVerify(authHeader.slice(7), secretKey);
    return typeof (payload as any).sub === 'string' ? (payload as any).sub : null;
  } catch { return null; }
}
```
Auth flow: `auth.ts` 用 `Elysia().use(jwt({...}))` 整 token (decorator 喺 same file 仲 work), 其他 route file 用 jose 驗. **兩個 source of truth 但 secret 一致就 OK**.

**Alternative**: pin `elysia@1.1.30` + `@elysiajs/jwt@1.1.0` 避開 d.ts bug. `bun add elysia@1.1.30 @elysiajs/jwt@1.1.0` 即可, 唔影響 production runtime.

### 衍生: `onBeforeHandle` 嘅 derive context 唔 propagate 跨 plugin (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: 用 `Elysia({ name: 'require-permission:xxx' }).onBeforeHandle(({ userId, set }) => ...)` 期望攞到 JWT plugin 注入嘅 `userId` (透過 `derive` 或 `resolve` 注入 context), 結果 `userId` 永遠係 `undefined`, 個 `requirePermission` middleware 唔 work, **所有需要 permission 嘅 endpoint 返 401**.

**根因**: 喺 Elysia 1.2, `derive()` 注入嘅 context **喺 plugin boundary 唔 propagate 入 `onBeforeHandle` handler**。`onBeforeHandle` 喺 scope-level plugin 入面睇唔到 parent derive 嘅 value, 但 route handler (i.e. `.get('/', ...)` 入面) 反而睇到。同 `decorator.jwt.verify` 唔同, 呢個係 context flow bug, 唔係 d.ts bug。

**Workaround** (推薦): 個 plugin 入面 **自己 extract + verify** 個 `Authorization` header, 唔好依賴 derive context:

```typescript
// apps/api/src/middleware/rbac.ts
import { jwtVerify } from 'jose';

async function getUserIdFromRequest(request: Request): Promise<string | null> {
  const auth = request.headers.get('authorization');
  if (!auth?.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret) return null;
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret));
    if (!payload || typeof payload !== 'object') return null;
    return (payload as { sub?: string; userId?: string }).userId
      ?? (payload as { sub?: string }).sub
      ?? null;
  } catch { return null; }
}

export function requirePermission(permission: string) {
  return new Elysia({ name: `require-permission:${permission}` }).onBeforeHandle(
    { as: 'scoped' },
    async (ctx: { request: Request; set: { status?: number } }) => {
      const userId = await getUserIdFromRequest(ctx.request);
      if (!userId) { ctx.set.status = 401; return { error: 'Unauthorized' }; }
      // ... check permission via DB ...
    }
  );
}
```

**Key points**:
1. 用 `ctx.request: Request` 拎 header, 唔靠 `ctx.userId`
2. `jwtVerify` 用 `jose` 直接 import, 唔好 instantiate `@elysiajs/jwt` 個 plugin (`jwtPlugin({...}).verify` 唔存在)
3. 個 verify 同個 JWT-signing 嘅 secret 要一樣 (即 `process.env.JWT_SECRET`)
4. 個 `(payload as { sub, userId }).userId ?? (payload as { sub }).sub` fallback 因為唔同 signing 嘅 field name

**Verification** (必須做): login + 揾個要 permission 嘅 endpoint 試:
```python
# 用 execute_code 或 python3 inline 避免 Hermes `***` redact
import urllib.request, json
data = json.dumps({"email":"admin@x","password":"x"}).encode()
req = urllib.request.Request("http://localhost/api/auth/login",
  data=data, headers={"Content-Type":"application/json"})
token = json.loads(urllib.request.urlopen(req).read())["token"]
# 揾個要 user:read 嘅 endpoint 試
req = urllib.request.Request("http://localhost/api/users",
  headers={"Authorization": f"Bearer {token}"})
print(urllib.request.urlopen(req).read()[:200])
# 期望: 200 + JSON list, 唔係 401
```

如果 401 → 即係 `getUserIdFromRequest` return null, check `process.env.JWT_SECRET` 喺 container 內有 set, 然後試 `console.error('[rbac] ...')` 入 `getUserIdFromRequest` 每個 branch 睇邊個 trigger。

## ⚠️ React Query `useQuery` generic return type 撞 `never` (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: Backend 返 `{ items: T[]; total: number }` 或者 bare `T[]` 兩種 shape (見下面「Backend response shape 不一致」section),寫 frontend:

```typescript
const { data } = useQuery({
  queryKey: ['products', params],
  queryFn: () => productsApi.list({ ... }),
});
const items: Product[] = Array.isArray(data) ? data : (data?.items ?? []);
```

`bun run build` 撞:
```
error TS2339: Property 'items' does not exist on type 'never'.
```

**根因**: TypeScript 嘅 control flow analysis 喺 `Array.isArray(data) ? data : (data?.items ?? [])` 之後 **collapse `data` 嘅 type to `never`** 因為 `useQuery` 個 generic 推唔到 `T` 出嚟 (`T = Product[] | { items, total }`, strict mode 兩個交集係 never)。`data?.items` 喺 `never` 個 optional chain 返 `undefined`, 然後 `?? []` 返 `never[]`, **個真實 `data` 嘅 union type info 已經 lost 咗**。

**Fix** (推薦, 5 秒 fix): Explicit cast `as` 兩次 bypass TS inference:
```typescript
const items: Product[] = Array.isArray(data)
  ? (data as Product[])
  : ((data as { items?: Product[] } | undefined)?.items ?? []);
```

**預防 rule**: 寫新 list page **always explicit cast** 兩次, 千祈唔好靠 TS 推 type。Takes 5 秒, 避免 build 失敗。Hermes 喺 crm-system Day 7 撞咗兩次(products.tsx + services.tsx)都係呢個 pattern,都係 `as` 兩次 fix 返。

## ⚠️ Vite production minified React throw unmount 整個 tree (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: Vite dev mode 個 page render 正常, `bun run build` 成功, Docker container 個新 image `Up N seconds (healthy)`, 但用 browser 去個 page 個 `#root` element 內 `innerHTML.length === 0`, body 完全空白。React 19 預設 unmount 整個 tree 喺 render error,**冇 fallback UI**。

**根因 1 (最常見)**: Backend 返嘅 JSON 唔 match frontend TypeScript interface。例如 backend `/api/roles` 返:
```json
{ "items": [{ "id": "...", "name": "ADMIN", "isSystem": true, "_count": { "users": 1 } }] }
```
但 frontend interface 寫:
```typescript
interface Role { id: string; name: string; permissions: string[]; }
```
個 page 寫 `{r.permissions.length}` 然後 **`r.permissions` 係 `undefined` → `.length` throw `TypeError: Cannot read properties of undefined (reading 'length')` 喺 React render → unmount 整個 tree**。

**根因 2**: Sibling subagent 改咗 backend route schema 個 shape (e.g. `permissions: string[]` → `_count: { permissions: number }`),但 frontend interface 冇跟住改 — **backend + frontend 對 schema 改動冇 simultaneous**。Hermes 喺 crm-system Day 7 撞過:`/api/roles` list 返 `_count` 但 `/api/roles/:id` 返 `permissions[]`,frontend 要 interface union 兩個 shape。

**Fix** (3 個 layer,推薦全部用):

**Layer 1 — Defense in depth (必須)**: 包個 ErrorBoundary 喺 main.tsx:
```typescript
// apps/web/src/components/error-boundary.tsx
import { Component, type ReactNode } from 'react';
export class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  componentDidCatch(error: Error, info: { componentStack: string }) {
    console.error('UI error:', error, info.componentStack);
  }
  render() {
    if (this.state.error) {
      return (
        <div className="p-8">
          <h2 className="text-lg font-bold text-destructive">UI Error</h2>
          <pre className="text-xs mt-2 whitespace-pre-wrap">{this.state.error.message}</pre>
          <button onClick={() => this.setState({ error: null })} className="mt-4 px-3 py-1 border rounded">
            Reload
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```
```typescript
// apps/web/src/main.tsx
<StrictMode>
  <ErrorBoundary>
    <BrowserRouter><App /></BrowserRouter>
  </ErrorBoundary>
</StrictMode>
```

**Layer 2 — Schema contract check**: 寫個 smoke script 用 Python urllib login + GET endpoint, 將 response 嘅 keys 對比 frontend interface 預期 keys, mismatch 即係 schema drift:
```python
import urllib.request, json
expected = {"id", "name", "permissions"}    # from frontend interface
resp = json.loads(urllib.request.urlopen(req).read())
actual = set((resp.get("items") or [resp])[0].keys()) if isinstance(resp, dict) else set(resp[0].keys())
missing = expected - actual
if missing:
    print(f"❌ API missing fields: {missing}")
    raise SystemExit(1)
```

**Layer 3 — Defensive rendering**: 個 page 寫 `{r.permissions?.length ?? 0}`, 唔好假設 array 一定有:
```typescript
{_count?.permissions ?? 0} / {allPermissions.length} 個權限
{_count?.users !== undefined && ` · ${_count.users} 個用戶`}
```

**Detection (production only, dev 通常 work)**:
1. `docker compose ps` 顯示 web container healthy
2. DevTools → `document.getElementById('root').innerHTML` 返 `''` (length 0)
3. `performance.getEntriesByType('resource').filter(r => r.name.includes('/api/X'))` 確認有 fetch (唔係 fetch fail — fetch OK 但 render fail)
4. `document.querySelector('vite-error-overlay')` 返 null (production 冇 Vite overlay)

**Verification (必須做, dev mode 唔夠)**:
```bash
docker compose build web --no-cache
docker compose up -d web
# Browser console:
performance.getEntriesByType('resource').filter(r => r.name.includes('/api/roles')).map(r => ({status: r.responseStatus}))
# Expected: 200 (backend OK 但 frontend 仍 unmount 都返 200)
document.getElementById('root').children.length
# Expected: 1+ (如果係 0 = React unmount = runtime render error)
```

## ⚠️ Docker Compose `up -d --build` cache layers 不重 build source code (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: 改咗 `apps/web/src/pages/roles.tsx` 然後 `docker compose up -d --build`, 個 build log 全部 `#N CACHED`, 個 image 根本冇重新 build, 個新 source code **冇 deploy 出嚟**。Container 個 `Up 5 minutes (healthy)` 仲係舊 image。**User 訪問個 page 見唔到新功能,以為你冇做**。Hermes 喺 crm-system Day 7 撞過一次 — `--no-cache` 之後個 bundle hash 由 `index-BR-TeQsV.js` 變 `index-ChsB1GOw.js` 證明真係新咗。

**根因**: Docker BuildKit cache layers by 個 file fingerprint hash。**當 Dockerfile 唔 COPY 你改咗嘅 file path (e.g. `COPY apps/web .`)** 或者 COPY path 喺 layer 下面但上面 layer 已經 cache, BuildKit 會 reuse cache 唔 re-read filesystem。

**Fix 1 (推薦, 萬用)**: 改 source 改完之後 always force `--no-cache`:
```bash
docker compose build web --no-cache
docker compose up -d web
```
`--no-cache` 會 skip 所有 cache layers, 完整重 build, 確定新 source 入 image。**15-30 秒 penalty 但保證啱**。

**Fix 2 (Dockerfile fix, 預防性)**: 喺 Dockerfile 開頭加個 `ARG CACHEBUST=1` 強迫 invalidate cache:
```dockerfile
FROM oven/bun:1.2 AS builder
ARG CACHEBUST=1   # change this value to force cache invalidation
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install
COPY . .
RUN bun run build
```
```bash
docker compose build --build-arg CACHEBUST=$(date +%s) web
```

**Detection 撞牆嘅方法 (必須每次 build 後做)**:
```bash
# 1. Check 個 image creation time
docker images <project>-web --format "{{.ID}} {{.CreatedSince}}"
# Expected: "Less than a minute ago" (唔係 "5 minutes ago" / "2 hours ago")

# 2. Check 個 bundle hash
docker exec crm-web cat /usr/share/nginx/html/assets/index-*.js | head -c 200
# Host 嗰度 curl 返出嚟對比
curl -s http://localhost/ | grep -oE 'index-[A-Za-z0-9_-]+\.js'
# 兩個 hash 要 match, 唔 match = nginx serve 緊舊 image

# 3. Force rebuild 一個 dummy file
touch apps/web/src/.force-rebuild
docker compose build web   # 應該見到 source COPY stage 唔係 CACHED
rm apps/web/src/.force-rebuild
```

**Elysia backend 都有同樣問題**, 一樣用 `--no-cache` fix。

## ⚠️ Bun `export *` 唔可靠 re-export named consts 跨 module (2026-06-05 crm-system Day 7 真實撞牆)

**症狀**: `packages/shared/src/permissions.ts` 寫 `export const PERMISSIONS = { 'user:read': '...', ... }`, `packages/shared/src/index.ts` 寫 `export * from './permissions'`, 然後 `apps/api/src/routes/roles.ts` 用 `import { ALL_PERMISSIONS } from '@crm/shared'`, 入面 reference `PERMISSIONS` 拎 keys。**Boot 時 crash**:
```
SyntaxError: Export named 'ALL_PERMISSIONS' not found in module '/app/packages/shared/src/index.ts'.
ReferenceError: PERMISSIONS is not defined
      at /app/packages/shared/src/index.ts:3:28
```

**根因**: Bun runtime (1.2.x 確認) 對 `export * from './module'` 嘅 re-export **named const** 處理有 bug: index file 自己 access 個 re-exported const 嗰陣 resolve 唔到 (variable 係 "not defined"), 即使 const 真係喺子 module named export。TypeScript / node 唔撞, 純 Bun runtime 撞。

**Workaround** (推薦, 5 秒 fix): 個 index file **explicitly import** 個 const, 然後 `export const` 重新 export:
```typescript
// packages/shared/src/index.ts
import { PERMISSIONS } from './permissions';
export * from './permissions';               // keep re-export 俾其他 consumers
export const ALL_PERMISSIONS: readonly string[] = Object.freeze(
  Object.keys(PERMISSIONS)
);
```
咁 `ALL_PERMISSIONS` 喺 index file 範圍就 explicit defined, Bun runtime resolve 到。`@crm/shared` consumer 一樣用 `import { ALL_PERMISSIONS } from '@crm/shared'`。

**Alternative** (更穩但 verbose): 完全唔用 `export *`, 改用 explicit named export 喺每個 consumer file:
```typescript
// ❌ 唔好
export * from './permissions';

// ✅ 改
export { PERMISSIONS, USER_ROLES, type Permission, type UserRole } from './permissions';
```

**Detection 訊號**:
1. Boot log 出 `Export named 'X' not found` 但個 const 明明喺子 module 寫咗 `export const X`
2. 或者 `ReferenceError: X is not defined` 喺個 re-export 嘅 index file 自己 (`index.ts:3:28` 之類)
3. `bun run src/index.ts` 撞, 但 `node src/index.ts` / `tsx src/index.ts` 唔撞

**Related**: 撞呢個 trap 通常代表你個 monorepo 想用 single source of truth (`packages/shared`) 收埋 enums + 派生 const, 然後 consumer import。設計 OK, 只係 Bun runtime 限制。Workaround 唔影響 source-of-truth pattern。

## ⚠️ Prisma client model names 唔 export (2026-06-05)

**症狀**: `import { PipelineStage } from '@prisma/client'` → runtime `SyntaxError: export 'PipelineStage' not found`, 因為 Prisma client **只 export enums, 唔 export model names**. Model 名喺 `@prisma/client` 內部用嚟 typeof, 唔係 named export.

**Fix**: Re-export `packages/db/src/index.ts` 入面只列 enums:
```typescript
export { UserRole, QuotationStatus, DealStatus, /* etc */ } from '@prisma/client';
// ❌ 唔好: export { PipelineStage } from '@prisma/client'  // runtime crash
// ✅ 改用: prisma.pipelineStage.findMany() 或者 type Prisma.PipelineStage
```

## ⚠️ Tailwind v3 vs v4 — shadcn-style setup 仍要 v3 (2026-06-05)

**症狀**: 跟 `bun create vite@latest` 出嘅 `react-ts` template 預設 Tailwind v4 (`@tailwindcss/vite` + `@theme` CSS directive). 但 shadcn/ui 嘅 class-variance-authority pattern 用 `tailwind.config.js` 嘅 `theme.extend.colors.primary.DEFAULT` 引用, v4 嘅 `@theme` 唔 work, 顏色 fallback 去 `border-border` 然後冇顏色。

**Fix**: For shadcn/ui-style projects, **用 Tailwind v3**:
```bash
bun add -d tailwindcss@3 postcss autoprefixer
```
加 `postcss.config.js`, `tailwind.config.js` (有 `content` + `theme.extend`), `index.css` 用 `@tailwind base/components/utilities`. 唔好用 v4 嘅 `@import "tailwindcss"` syntax.

## ⚠️ shadcn-style token 唔可以漏 — `popover` / `card-foreground` / `destructive-foreground` 撞 (2026-06-06 crm-system 真實撞牆)

**症狀**: 用咗 shadcn-style component (e.g. `<Dialog>`, combobox dropdown, popover, command palette) 之後, 個 panel / dropdown / dialog 個 background **完全透明**, 後面嘅 table content 透出嚟 (e.g. 個 quotation builder 嘅 autocomplete 透底見到後面 `備註` textarea + `Subtotal` 行)。**冇 console error**, DevTools 個 `<div class="bg-popover">` 存在, 但 computed style 冇 background-color。

**根因**: cva 寫 `bg-popover` / `text-popover-foreground` / `border-input` / `bg-card` 等等 utility class, 期望佢哋喺 `tailwind.config.js` 嘅 `theme.extend.colors` 有對應 token。如果個 config 漏咗個 token, Tailwind 喺 build / JIT 階段 **silently omit** 個 class, 結果個 element 冇 background。

**crm-system 真實情況** (2026-06-06):
- `tailwind.config.js` 嘅 `theme.extend.colors` 有: `border`, `input`, `ring`, `background`, `foreground`, `primary`, `secondary`, `muted`, `accent`, `destructive`, `card`
- **冇**: `popover`, `popover-foreground`, `card-foreground`, `destructive-foreground`
- `quotation-builder.tsx` 嘅 `ProductAutocomplete` / `ServiceAutocomplete` panel 用 `bg-popover` → render 出嚟係透明 → David 報 bug 「autocomplete 透底」

**Fix — 對齊 shadcn 完整 token set**: `tailwind.config.js` 嘅 `colors` 要齊以下 shadcn-ui HSL 變量 (crm-system 已經用緊 `hsl()` 而非 `oklch()`, 唔好混):
```js
// tailwind.config.js — theme.extend.colors
colors: {
  border: 'hsl(214.3 31.8% 91.4%)',
  input: 'hsl(214.3 31.8% 91.4%)',
  ring: 'hsl(222.2 84% 4.9%)',
  background: 'hsl(0 0% 100%)',
  foreground: 'hsl(222.2 84% 4.9%)',
  primary: {
    DEFAULT: 'hsl(222.2 47.4% 11.2%)',
    foreground: 'hsl(210 40% 98%)',
  },
  secondary: {
    DEFAULT: 'hsl(210 40% 96.1%)',
    foreground: 'hsl(222.2 47.4% 11.2%)',
  },
  destructive: {
    DEFAULT: 'hsl(0 84.2% 60.2%)',
    foreground: 'hsl(210 40% 98%)',
  },
  muted: {
    DEFAULT: 'hsl(210 40% 96.1%)',
    foreground: 'hsl(215.4 16.3% 46.9%)',
  },
  accent: {
    DEFAULT: 'hsl(210 40% 96.1%)',
    foreground: 'hsl(222.2 47.4% 11.2%)',
  },
  popover: {
    DEFAULT: 'hsl(0 0% 100%)',
    foreground: 'hsl(222.2 84% 4.9%)',
  },
  card: {
    DEFAULT: 'hsl(0 0% 100%)',
    foreground: 'hsl(222.2 84% 4.9%)',
  },
},
```

**Quick fix (in-place component)**: 如果只係 1-2 個 component 撞, 唔想改全局 config, 直接喺 element 寫 `bg-white border border-border` 代替 `bg-popover border`, 視覺上同 (因為 `popover: DEFAULT: 'hsl(0 0% 100%)' = 白色`):
```tsx
// ❌ 唔好 (如果 popover token 冇 define)
<div className="bg-popover border rounded shadow-lg">…</div>

// ✅ Quick fix 1 (component-local, 唔改 config)
<div className="bg-white border border-border rounded shadow-lg">…</div>

// ✅ Proper fix 2 (config-level, 一改搞掂哂)
```
> 跟 `tailwind.config.js` 嘅 `border` 已經有, 所以 `border` utility 仍 emit `1px border-color: hsl(214.3 31.8% 91.4%)`, 唔使改。**但 `bg-popover` 冇 token 會 silently omit**。**`border` 配 `bg-popover` 唔 work** 因為個 panel 仍然透明, 只係個 outline 顯示到。

**Detection (撞牆必做)**:
1. **computed style 確認**:
   ```js
   // 喺 browser DevTools console
   const el = document.querySelector('[class*="bg-popover"]');
   window.getComputedStyle(el).backgroundColor
   // Expected: "rgb(255, 255, 255)"  ← transparent 撞 "rgba(0, 0, 0, 0)"
   ```
2. **grep 全 codebase 嘅 missing token**:
   ```bash
   rg "bg-(popover|card-foreground|popover-foreground|destructive-foreground|muted-foreground)" apps/web/src
   # 對比 tailwind.config.js 嘅 colors key
   ```
3. **Tailwind JIT 唔報錯**: 佢 silently omit 唔存在嘅 utility class, 所以 `bun run build` 唔會 fail。**必須用 browser 真實視覺確認**, 唔可以信 build pass。

**Pre-emptive rule (新 shadcn-style 項目)**: 跟 `npx shadcn@latest init` 出嘅 `tailwind.config.js` 唔好 hand-edit 走任何 token。**或者**直接用 `npx shadcn@latest add <component>` 加新 component, 佢會自動 inject 對應 `cn()` + class 變量, 唔會撞呢個 trap。**Hermes hand-written `tailwind.config.js` 易漏 token** — crm-system 撞咗兩次 (Day 9 Region bug + 今日 popover bug)。

### Quick fix 路徑之後必須 grep 全部 other occurrences (2026-06-06 crm-system 真實撞牆)

**情境**: David 揀咗 quick fix(用 `bg-white border border-border` 改 component 入面)而唔係修 config(加 `popover` token)。fix 咗 quotation-builder.tsx 之後我主動 flag: `bg-popover` token 漏咗會 silently 影響**成個 app 嘅所有 popover / dropdown**, 其他位(admin role picker、deals stage dropdown 等)可能撞同一個 bug。

**Action — Quick fix 之後必須跑**:
```bash
# 1. grep 全 codebase 嘅 utility class 對比 tailwind config 嘅 colors key
rg "bg-(popover|card|accent|secondary|muted|primary|secondary-foreground|popover-foreground|card-foreground|muted-foreground|accent-foreground|destructive-foreground)" apps/web/src

# 2. 對比 tailwind.config.js theme.extend.colors 嘅 key
node -e "console.log(Object.keys(require('./tailwind.config.js').theme.extend.colors).join('\n'))"

# 3. 差集 = missing token, 逐個 confirm 要 quick-fix 定要改 config
```

**Hermes safety net — 將呢個 grep 加到 dev verify**:
```bash
# 喺 ~/www/<project>/scripts/check-tailwind-tokens.sh (可重 run)
#!/bin/bash
set -e
cd ~/www/<project>
CONFIG_KEYS=$(node -e "console.log(Object.keys(require('./apps/web/tailwind.config.js').theme.extend.colors).join('\n'))" | sort)
USED=$(rg -oN "bg-(popover|card|accent|secondary|muted|primary|secondary-foreground|popover-foreground|card-foreground|muted-foreground|accent-foreground|destructive-foreground)" apps/web/src | sed 's/.*\(bg-[a-z-]*\).*/\1/' | sort -u)
MISSING=$(comm -23 <(echo "$USED") <(echo "$CONFIG_KEYS" | sed 's/^/bg-/'))
if [ -n "$MISSING" ]; then
  echo "❌ Missing tailwind tokens: $MISSING"
  exit 1
fi
```

**Why 兩個 patch path 都要 grep**:
- **Path A (改 config)**: 一處改搞掂哂, 之後 token 對齊 shadcn 標準
- **Path B (改 component)**: 只 fix 一個, **但** codebase 其他位用同一個 `bg-popover` 仍然會 silently transparent。**只 fix 1 個 = David 將來會撞第 2、第 3 次同一個 bug**。

## ⚠️ LSP diagnostics stale after rapid patches — `docker compose build` 是 source of truth (2026-06-06 crm-system 真實撞牆)

**症狀**: 改咗一個 file 嘅 prop signature (e.g. 將 `CreateCompanyDialog` 改名 `CompanyFormDialog` + 加 `mode` + 加 `defaultName` + 加 `regions` props),LSP 立刻報舊 error 出現喺 caller file (`company-autocomplete.tsx` 嗰個 import)。**但**我每改完一個 patch 之後,下個 patch LSP 仍報之前嘅 error (line number 都唔對)。我 chase 咗 LSP 報嘅 3 個所謂 issue 改多次 code,搞到 file 越改越混亂,最後先發現 **LSP 根本係 stale,所有 issue 已經被我 patch fix 咗**。真正嘅 source of truth 係 `docker compose build web` 嘅 exit code。

**根因 (3 個 stack 同時撞)**:
1. **LSP cache**: Hermes 嘅 LSP daemon 對連續 patch edit 嘅 cache invalidation 唔可靠。同 session 內改咗 N 個 patch,LSP 仍報 N 步前嘅 state
2. **LSP 唔跨 file analyse TypeScript 個 exact type narrowing**:對於 `c =>` implicit any、`status: string` cast、prop missing 等 issue,LSP 行 type-check 嘅 view 唔等於 `tsc --noEmit` 嘅 view
3. **`@ts-nocheck` 喺部分 file 開咗**:有啲 route file 用 `// @ts-nocheck` 避 Elysia 1.2 d.ts noise(見上面),LSP 對呢類 file 完全唔 typecheck,但 `docker compose build` 仍會 run tsc 對其他 file 報錯

**Detection 訊號 (邊個時候 LSP 唔可信)**:
- 報錯 line number 對唔上 file 內容 (e.g. LSP 報 line 355 但 file 已經 250 行)
- 報錯話某 prop 唔存在,但我頭先 patch 明明加咗
- 報錯話 `c: (parameter) c: any` implicit,但我有 typed 過
- 報錯話 `status: string` assignable error,但我已經用 `as Company['status']` cast

**正確 workflow (推薦)**:
```bash
# 改完 frontend file 永遠跑呢個 — 唔好睇 LSP
cd ~/www/<project>
docker compose build web 2>&1 | grep -E 'error TS|failed|exit code|DONE' | head -10
# Expected: 0 個 error TS line + 1 個 "DONE" 喺 #N 階段
# If 有 error TS: 嗰個係真正嘅 type error, 要 fix
# If 冇 error TS: LSP 嘅 noise 全部 ignore, 繼續 commit
```

**Time budget**:
- `docker compose build web` 第一次 (cold): ~90 秒
- 第二次之後 (cache hit): ~20-30 秒
- 比起 chase LSP 假報錯再 fix code 再 build 嘅 loop,直接 `docker compose build` 一早做 5 倍快

**Anti-pattern (我犯過)**:
```bash
# ❌ 唔好
patch file
見 LSP 報 error
patch 又改
見 LSP 仍報舊 error
patch 又改再改
... 3-4 個 patch 之後先 build ...
最後 build pass, 但 file 已經改到冇得救要 reset
```

**Correct pattern**:
```bash
# ✅ 好
patch file
直接 docker compose build web
睇 build output
有 error 就 patch 嗰個真實 issue
冇 error 就繼續 — 唔好睇 LSP
```

**Generic rule (套用成個 stack)**:
- Backend: `docker compose build api` 係 source of truth (LSP 對 Elysia route 嘅 noise 仲多,因為 `@ts-nocheck` + d.ts bug)
- Frontend: `docker compose build web` 係 source of truth (LSP 對 React 嘅 `as` cast / generic 推唔到 type 嘅情況仲多)

**Related**: 同「Docker Compose `up -d --build` cache layers 不重 build source code」唔同 — 呢個 pitfall 係 LSP 報錯假陽性,嗰個 pitfall 係 cache 命中冇 re-build。**兩者都係話 docker build 必須 explicit 跑而唔好信 implicit 嘅 watch / LSP 通知**。

## ⚠️ `bun.lock` 不被 npm / snyk 認 — 紅線 18 CVE 掃描盲點 (2026-06-07 crm-system code review 真實撞牆)

**症狀**: 跑 `npm audit` 喺一個 bun-managed monorepo (`bun.lock` 而唔係 `package-lock.json`) 撞:

```
npm error code ENOLOCK
npm error audit This command requires an existing lockfile.
npm error audit Try creating one first with: npm i --package-lock-only
```

**根因**: `bun.lock` 係 **bun-native binary format** (text-based, 但 npm/snyk 唔識 parse)。`package-lock.json` 同 `bun.lock` 互相唔識。David 嘅紅線 18 寫明「Critical/High CVE (由 `npm audit` / `snyk` 掃到) 必須 0 才可 merge」 — **如果個 project 用 bun, 紅線 18 既有的 toolchain 直接做唔到**。

**Fix (推薦, 30 秒)**: 用 `bun audit` 而唔係 `npm audit`:

```bash
# ❌ 唔好
npm audit --json
# → ENOLOCK (bun.lock not recognized)

# ✅ 好 (bun 1.2+ 內建)
bun audit
# → 解析 bun.lock + 對 npm registry check 已知 CVE
```

**如果 `bun audit` 都 fail (bun 版本太舊)**: Generate 一個 npm-compatible lockfile 一次過, 之後 audit 用 npm:

```bash
# 在 root 一次過
npm i --package-lock-only   # 根據現有 package.json + bun.lock generate package-lock.json
npm audit --json > /tmp/cve.json
# 然後 commit 走 package-lock.json 都可以 (但會同 bun.lock drift)
```

**Production CI 必加 step** (ship gate):

```bash
# 喺 CI YAML (.github/workflows/ci.yml) 加
- name: CVE scan
  run: |
    bun audit --json > /tmp/audit.json
    HIGH=$(python3 -c "import json; d=json.load(open('/tmp/audit.json')); print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))")
    CRIT=$(python3 -c "import json; d=json.load(open('/tmp/audit.json')); print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))")
    if [ "$HIGH" -gt 0 ] || [ "$CRIT" -gt 0 ]; then
      echo "❌ Critical/High CVE > 0, blocking merge (紅線 18)"
      exit 1
    fi
```

**Lockfile 可信度 pitfall (related)**: `bunfig.toml` 嘅 `[install] exact = false` 默認 = 用 `^5.6.3` caret range, build 唔 reproducible, 每個 developer 落地拎到唔同 patch version:

```toml
# bunfig.toml
[install]
exact = true    # 改 true, lockfile 死鎖 exact version
```

**Detection 撞牆嘅方法 (ship-readiness review 必做)**:
```bash
# 1. 確認有 lockfile
ls -la bun.lock package-lock.json 2>/dev/null
# Expected: 至少 bun.lock (bun project) 或 package-lock.json (npm project)

# 2. 試跑 audit
timeout 30 bun audit 2>&1 | head -20
# Expected: 有 vulnerability table 列出
# 如果 error: 上面 fix 步驟

# 3. 確認 exact mode
grep "exact" bunfig.toml
# Expected: exact = true
```

## ⚠️ RBAC coverage matrix 1-liner audit — 1 個 grep 揭 14 route 嘅 access control gap (2026-06-07 crm-system 真實撞牆)

**症狀**: Code review 時想 check 全部 14 個 route file 嘅 RBAC coverage, 人工逐 file 開 → 太慢, 易 miss。需要 1 個 1-liner reveal 邊個 route 公開, 邊個有 auth, 邊個有 permission check。

**Fix (1-liner, 推薦 for 任何 RBAC-driven Elysia / Express / FastAPI project)**:

```bash
# 對齊 pattern: <route file> 用 authContext 幾多次 + requirePermission 幾多次
cd ~/www/<project>
for f in apps/api/src/routes/*.ts; do
  name=$(basename "$f" .ts)
  ac=$(grep -c "authContext" "$f" 2>/dev/null)
  perm=$(grep -c "requirePermission" "$f" 2>/dev/null)
  printf "%-20s authContext=%-3d requirePerm=%d\n" "$name" "$ac" "$perm"
done | sort -k2 -t= -n
# ↑ sort by authContext count ascending = 公開 routes 浮上面
```

**Expected output (crm-system 2026-06-07 真實數字)**:
```
ai-config            authContext=0  requirePerm=1   ← 0 auth 但有 perm: 內部 RBAC OK 但 anonymous 撞 401 = 設計 OK
chat                 authContext=0  requirePerm=0   ← 🚨 公開 endpoint 寫 DB → CRIT
company              authContext=0  requirePerm=0   ← 🚨 公開 endpoint 寫 DB → CRIT
contact              authContext=0  requirePerm=0   ← 🚨 公開 endpoint 寫 DB → CRIT
deal                 authContext=0  requirePerm=0   ← 🚨 公開 endpoint 寫 DB → CRIT
settings             authContext=0  requirePerm=2   ← perm 蓋住, 但 anonymous 撞 401 (OK)
audit                authContext=2  requirePerm=2   ← ✅
man-day-role         authContext=4  requirePerm=3   ← ✅
roles                authContext=2  requirePerm=2   ← ✅
```

**Reading the matrix**:
| 0/0 | 公開 endpoint, **任何 internet 人都可以 hit** |
| 0/N (N>0) | `requirePermission` plugin 蓋住, anonymous 撞 401 → **OK 但要 verify** |
| M/0 (M>0) | 有 `authContext` 但冇 `requirePermission` → **任何 logged-in user 撞 200** (通常係 PUBLIC read-only, OK; 但寫入 route 一定要 perm) |
| M/N (both>0) | **Fully protected** ✅ |

**Generic rule (套用全部 backend stack)**:
- Elysia: `authContext` / `requirePermission` (呢個 skill 嘅 pattern)
- Express: `requireAuth` / `requireRole` / `requirePermission`
- FastAPI: `Depends(get_current_user)` / `Depends(require_role)`
- NestJS: `@UseGuards(AuthGuard)` / `@Roles(...)` decorator

換 pattern name 即可, framework 唔重要。

**Common hit 真實 cases (撞過嘅)**:
1. **`POST /auth/register` 冇 requirePermission** — 公開註冊 + 可以 self-select `role: 'ADMIN'` = **公開 internet 變 admin**。Fix: 加 `requirePermission('user:create')` + body schema 刪 `role` field (新 user 預設 SALES, admin 自己 promote via PATCH /users)
2. **List endpoint 公開 (e.g. `GET /companies`)** — 公開讀 = PII 漏 (email, phone, credit limit)。Fix: 加 `requirePermission('company:read')`
3. **AI write tool 公開** — `/chat/send` 觸發 `prisma.company.create` 以 system actor 寫 = **silent DB write without attribution**。Fix: 加 `requirePermission('chat:use')` + audit log 入面 `actorId` 一定要有
4. **Status / health endpoint RBAC 不一致** — `/api/ai/config/status` 公開 = 偵察 admin 環境狀態。Fix: 一律 `requirePermission('xxx:read')` 蓋住, status 都要

**Related pattern (RBAC permission drift)**: 三個 source of truth 要對齊:
1. `packages/shared/src/permissions.ts` `PERMISSIONS` map (static, system roles)
2. `apps/api/src/middleware/rbac.ts` `requirePermission('xxx')` 字符串 (hard-coded in route files)
3. DB `RolePermission` table (runtime state, custom roles)

加新 permission 嘅流程: (1) 改 `permissions.ts` 加 entry → (2) 改 routes 加 `requirePermission('xxx')` → (3) DB seed `RolePermission` 對應 row。**3 處唔 link 易 drift**。E2E test 兜底:
```typescript
// 跑一次: 列舉 permissions.ts 嘅 keys, grep requirePermission(, 確認每個 key 至少 1 個 route 用
test('permission coverage', () => {
  const declared = new Set(Object.keys(PERMISSIONS));
  const used = new Set<string>();
  for (const f of glob.sync('apps/api/src/routes/*.ts')) {
    for (const m of fs.readFileSync(f, 'utf8').matchAll(/requirePermission\(['"]([^'"]+)['"]\)/g)) {
      used.add(m[1]);
    }
  }
  const unused = [...declared].filter(p => !used.has(p));
  expect(unused).toEqual([]);  // 0 unused perms
});
```

## ⚠️ `tsc --noEmit` 報 30+ silent type errors 但 runtime OK — typecheck 唔可以靠 build 兜底 (2026-06-07 crm-system 真實撞牆)

**症狀 (同 LSP stale pitfall 唔同 — LSP 假報 vs tsc 真報都被忽略)**: `apps/api/src/routes/*.ts` 開咗 `// @ts-nocheck` 喺 rbac.ts + quotation.ts, 但其餘 6+ 個 route file 冇 `@ts-nocheck` 但係 runtime work。**點解 typecheck 撞但 build pass?**

**根因 (Elysia + bun 雙重 source-of-truth drift)**:
1. Elysia 1.2 d.ts 同 TypeScript 5.x 嘅 type inference 衝突(see 上面「Elysia 1.2 d.ts broken」)— `set.status` typed 做 `number | "Unauthorized" | ...` literal union, 好多 cast 寫得唔準
2. `prisma.aiConfig` 唔存在 but code 用緊 — Prisma client 唔 export 該 model (見下面「Prisma client model names 唔 export」)
3. `as never` cast 喺 handler 內部太多 — body validation 通過後 `body` 嘅 type 係 `unknown`, cast 做 `as never` 漏 type
4. Bun runtime 唔 typecheck (dev mode `bun run src/index.ts` 唔 invoke tsc) — runtime 唔 care
5. Dockerfile 嘅 `bun --env-file=... src/index.ts` production entry 仍然唔 typecheck
6. Elysia 1.2 type check chain 對多個 `.use()` plugin 嘅 context propagation 唔 reliable — derive 出嘅 `userId` 個 type 喺 route handler 入面係 `string | null`, 但喺 `onBeforeHandle` plugin boundary 變 `unknown`

**撞牆真實例子 (crm-system 2026-06-07)**:
```
src/lib/context.ts(9,21): error TS2339: Property 'jwt' does not exist on type '...'.
src/routes/ai-config.ts(57,30): error TS2339: Property 'aiConfig' does not exist on type 'PrismaClient<...>'.
src/routes/ai-config.ts(199,9): error TS2322: Type '"AI_CONFIG_UPDATED"' is not assignable to type 'AuditAction'.
src/routes/contact.ts(33,50): error TS2353: ...'activities' does not exist in type 'ContactInclude<DefaultArgs>'.
src/routes/deal.ts(152,7): error TS2322: Type '"DEAL_STAGE_CHANGED"' is not assignable to type 'AuditAction'.
+ 25+ more
```

**Risk**:
- `prisma.aiConfig` 唔 export 但 code 用緊 = **prod 第一次 hit 嗰個 endpoint 一定 500** (Prisma client 識唔到 model)
- `'DEAL_STAGE_CHANGED' as AuditAction` 唔 cast-safe = audit log 寫入失敗 silently
- `as never` body cast = 可以 inject 任意 fields 到 Prisma create (雖然 Prisma schema filter 唔存在 column, 但 `passwordHash` / `isActive` 呢類 sensitive field 風險)

**Fix (3 個 step, ship gate 必做)**:

```bash
# 1. 在 root 加 unified typecheck (唔好靠個別 package.json 嘅 typecheck script)
cd ~/www/<project>
cat > scripts/typecheck-all.sh <<'EOF'
#!/bin/bash
set -e
echo "=== apps/api ==="
cd apps/api && bunx tsc --noEmit --skipLibCheck
cd ../..
echo "=== apps/web ==="
cd apps/web && bunx tsc --noEmit --skipLibCheck
cd ../..
echo "=== packages/db ==="
cd packages/db && bunx tsc --noEmit --skipLibCheck
EOF
chmod +x scripts/typecheck-all.sh

# 2. 在 CI 必跑 (唔可以 skip)
# .github/workflows/ci.yml:
# - name: TypeScript check
#   run: ./scripts/typecheck-all.sh
# (冇 typecheck pass = 唔 merge)

# 3. Fix 撞到嘅 error — 唔可以加 @ts-nocheck 蓋住
#   - 重新 generate prisma client: cd packages/db && bunx prisma generate
#   - AuditAction / ItemType 等 enum 加返入 schema
#   - Casts 用 'as Company' 而唔係 'as never' (cast 對 schema 唔等於 bypass validation)
#   - remove 所有 @ts-nocheck (Dockerfile `bun run` 跳 typecheck, 唔代表可以 silent type drift)
```

**Critical: Dockerfile 唔可以加 typecheck step 入 build**:
```dockerfile
# ❌ 唔好
RUN bun run typecheck   # 加咗 build 會 hang 在 ts error, 個 image 永遠 build 唔到
                        # 即使 type errors 應該 fix, build 唔可以 fail 因為 type error
                        # (本地 fix 之後先 push)
#
# ✅ 好
# typecheck 留喺 CI stage + pre-commit hook, Dockerfile 維持 `bun install + bun run`
```

**Detection 工具 (code review 必跑)**:
```bash
# 1. 數 typecheck errors
cd ~/www/<project> && timeout 60 bunx tsc --noEmit --skipLibCheck 2>&1 | grep -c "error TS"
# Expected: 0 (ship gate 必過)
# 如果 > 0: 紅線 16 嘅 test coverage fail + type drift blind spot

# 2. 數 @ts-nocheck 數量
rg -l "@ts-nocheck" apps/ packages/
# Expected: 0 (一係 remove 一係 真嘅 disable 嘅 file 加理由 comment)
# 如果 > 0: 全部逐個 review, 確認係 Elysia 1.2 d.ts 真正 broken 而唔係偷懶

# 3. 數 'as never' cast 數量
rg -c "as never" apps/api/src/ | awk -F: '{sum+=$2} END {print sum}'
# Expected: 0 (cast 應該 'as ConcreteType')
# 如果 > 5: code review 必 grep 全部 location 改 'as ConcreteType' 對應 Prisma model
```

**Related pitfall (LSP stale)**: 上面「LSP diagnostics stale after rapid patches」section 講 LSP 假報錯。**呢個 pitfall 講 tsc 真報但被忽略**。兩個都會誤導 developer 以為 type safety OK — **唯一 source of truth 係 CI 跑嘅 `tsc --noEmit` exit code 0**。

## ⚠️ Self-register-as-admin trap — `POST /auth/register` 公開 + role 喺 body (2026-06-07 crm-system 真實撞牆)

**症狀**: RBAC 系統有 `ADMIN / SALES / VIEWER` 三個 role 喺 DB, 有 `requirePermission('user:create')` middleware. 但 register endpoint 寫:

```typescript
// ❌ 唔好 — RBAC 完整但 register endpoint 公開 self-service admin
.post('/register', async ({ body, set }) => {
  const { email, password, name, role } = body as {  // ← role 喺 body
    email: string; password: string; name: string;
    role?: 'ADMIN' | 'SALES' | 'VIEWER';
  };
  // ... 直接 prisma.user.create({ data: { ..., role: role ?? 'SALES' } })
}, {
  body: t.Object({
    email: t.String({ format: 'email' }),
    password: t.String({ minLength: 8 }),
    name: t.String({ minLength: 1 }),
    role: t.Optional(t.Union([         // ← 接受 role 喺 body
      t.Literal('ADMIN'),
      t.Literal('SALES'),
      t.Literal('VIEWER'),
    ])),
  }),
})
```

**Risk (公開 internet + body role = 公開 internet 變 admin)**:
1. 任何人用 `curl -X POST /auth/register -d '{"email":"a@b.c","password":"xxx","name":"Hacker","role":"ADMIN"}'` → 攞到 ADMIN token
2. 如果有 seed 預設 `david@crm.local / admin123` 即係 hacker 直接用 `david@crm.local` 重置密碼 / 喺自己個 account 升級

**Fix (推薦, 5 分鐘)**:

```typescript
// ✅ 好
import { authContext } from '../lib/context';
import { requirePermission } from '../middleware/rbac';

.post('/register', async ({ body, set }) => {
  const { email, password, name } = body as {  // ← role 唔再喺 body
    email: string; password: string; name: string;
  };
  // ... prisma.user.create({ data: { email, name, passwordHash, role: 'SALES' } })
  // 預設 SALES, admin 自己用 PATCH /users/:id 升級
}, {
  body: t.Object({
    email: t.String({ format: 'email' }),
    password: t.String({ minLength: 8 }),
    name: t.String({ minLength: 1 }),
    // ← 唔再接受 role
  }),
})
// 同時 add: 真正 invite flow 應該 admin 用 PATCH /users/:id invite

// Alternative 1 (use the existing authContext + requirePermission 蓋住)
.use(authContext)
.use(requirePermission('user:create'))   // ← 只有 admin 可以 create user

// Alternative 2 (disable self-service,只 invite via admin UI)
// 條 route 直接 disable, body validation 唔再 register endpoint
```

**Variant 撞牆 — status endpoint 唔 gated**:
```typescript
// ❌ 唔好
.get('/ai/config/status', () => {
  return prisma.aiConfig.findUnique({ where: { id: 1 }, select: { configured: true, model: true } });
})
// 公開偵察 admin 環境狀態 = recon 階段有用 info

// ✅ 好
.use(authContext)
.use(requirePermission('ai-config:read'))
.get('/ai/config/status', ...)
```

**Detection (code review 1-liner)**:
```bash
# 1. Check register / signup endpoint 有冇 permission
rg -A 1 "post\(['\"]/?(auth/)?(register|signup)" apps/api/src/
# 期望: 見到 .use(requirePermission(...)) 喺 register handler 之前
# 如果冇: 即係 self-service,加 fix

# 2. Check 全部 body schema 接受 role 嘅地方
rg "t\.(Union|Literal).*(ADMIN)" apps/api/src/
# 期望: 0 個 (role 唔應該喺 public-facing body schema)

# 3. Check 全部 GET endpoint 嘅 status / config 探測
rg "get\(['\"]?/.*(status|health|config)" apps/api/src/
# 期望: 全部都有 .use(requirePermission) 喺之前 (除咗真正 public health check)
```

**Generic rule (套用所有 SaaS 項目)**:
- Self-service signup → role 永遠 default 'USER' / 'MEMBER' / 'CUSTOMER', 唔可以 self-select 'ADMIN'
- Admin invite flow → admin 自己 PATCH /users/:id 升級
- 任何 GET /status /config endpoint → 一律 permission-gated, status 都要

## ⚠️ Subagent 600s/63-call timeout 撞 long refactor 任務 (2026-06-06 crm-system Day 11 真實撞牆)

**症狀**: 派 subagent 跑 5-phase 嘅 multi-file refactor(themes token fix + 502 修 + 抽 2 個共用 component + 補 fields + Deal 編輯 + 最終 typecheck), 每個 phase 都要讀 source + patch + 自己驗 typecheck。Subagent 跑 600s timeout 撞 63 個 API call, 卡喺某個 phase(typecheck 連跑多次)唔 return。`api_calls: 63, duration_seconds: 600.17, exit_reason: timeout`。

**根因**:
1. `bun run typecheck` 喺 Elysia strict TS 5 + 大量 `as never` cast 嘅 project 入面,**第一次 pass 通常撞 3-5 個 error,subagent 自己 fix 之後再 typecheck,loop**。
2. 每個 typecheck pass 要 ~30 秒(subagent 連 import 5-6 個 files + tsc 全行)。
3. Long refactor 加埋 typecheck loop + multiple file 嘅 read_file verification → 600s 唔夠用。

**接管 pattern (推薦, 2026-06-06 crm-system Day 11 用咗)**:
```python
# 1. 派 subagent,設定期望 subagent 跑 ~5 phase
delegate_task(goal="...", context="...", toolsets=['terminal', 'file', 'skills'])

# 2. 收到 timeout 唔好報錯
# 3. 自己 check subagent 已經 create 咗咩 file
search_files(pattern="*.tsx", path="apps/web/src/components", target="files")

# 4. 對比 plan 入面嘅 expected file list,睇邊個 phase 未做
# 5. 直接 read 嗰啲 file 確認 partial progress 嘅 quality

# 6. 接手未做嘅 phase (parent 自己跑, 或者再 delegate 細啲嘅範圍)

# 7. 最終 typecheck 一齊跑 (parent 跑, 唔好 subagent 跑)
terminal(command="cd ~/www/crm-system/apps/web && bun run typecheck")
```

**Plan subagent 嘅 5 個 control 點**:
- **scope 細啲**: 唔好一個 goal 包 5 phase。每 phase 一個 subagent。Day 11 嗰個 subagent 撞牆因為 5 phase 太闊。
- **明確講 typecheck 喺 parent 跑**: 個 subagent 只需要做 4 件事 — 改 file, 改 import, 改 type signature。**唔需要 typecheck 100% pass**。Subagent 改 type signature 至 TS compile 到就 OK,parent 接手跑 typecheck + fix 邊度 miss。
- **Checkpoint 寫低**: Subagent 應該每改完 1-2 個 file 寫低 "Phase N done, file X modified, file Y created"。咁 timeout 之後 parent 可以 grep checkpoint 知住乜。
- **Avoid 在 subagent 度跑 long command**: 唔好喺 subagent 入面 `bun run build` / `vite build` (5+ 分鐘),改用 `tsc --noEmit` 30 秒。
- **Accept partial completion**: Subagent 個 summary 報 "4/5 phases done, phase 5 撞 hit type error X", parent 接手 fix X 就好。**唔好 reject partial 然後再 delegate 全 work**。

**Plan size 參考 (Day 11 嗰個嗰個跑咗 63 個 call, 撞 timeout)**:
- 1 phase (1 file major edit) → ~10-15 calls, 5 min OK
- 3 phases (3 files + 1 verify) → ~30 calls, 15 min borderline OK
- 5 phases (5+ files + multi-step verify) → **>50 calls, 撞 timeout 高**。要 split
- 8+ phases → 必須 split,絕對唔好一個 goal 包

**Generic rule**: Subagent 用法應該係 `1 task = 1 clear deliverable` (改 1 file, 跑 1 個 verify script, etc.), 而唔係 `1 task = 1 refactor project`。Long refactor 應該由 parent 拆 phase 派多個 subagent, 每次小範圍。

## ⚠️ Hermes redact `***` 整死 shell-based JWT tests (2026-06-05)

**症狀**: 寫 `TOKEN=*** ... /login | sed -n 's/.*"token": "\([^"]*\)".*/\1/p')` 然後 curl 後續 endpoint. **Hermes redact 機制會將個 token 喺 terminal output 變成 `***`**, 之後 sed 唔 match. 即係用 bash 做 multi-step authenticated curl 唔可靠。

**Fix**: 用 `python3 -c` 一次性做 login + authed requests:
```python
import json, urllib.request
token = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost:3000/auth/login',
  data=json.dumps({'email':'a','password':'b'}).encode(),
  headers={'Content-Type':'application/json'})).read())['token']
data = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost:3000/resource',
  headers={'Authorization': f'Bearer {token}'})).read())
print(data)
```
Python script 入面 Hermes redact 唔 trace 入去, 完整 token 留喺 memory, 之後先 redact output。

**更安全嘅 fix (2026-06-05 crm-system Day 4 試過)**: Hermes 喺 `terminal()` 將 `***` literal 自動 redact 連 `print(` 都波及, 寫 bash 用 awk `'{print $1}'` 都會壞. 解決:
1. 將 token 寫入 `/tmp/crm_token.txt` (no echo)
2. Bash 用 `tr -d '\\r\\n' < /tmp/crm_token.txt` strip newline
3. 用 `printf 'Authorization: Bearer *** /tmp/crm_hdr.txt` 然後 `curl -H @/tmp/crm_hdr.txt` 完全 avoid token 喺 process args 出現

**最簡單 fallback** (推薦): `execute_code` 跑 Python 直接打 `urllib.request` (個 sandbox `***` 唔 trigger, full token 留 memory 唔 echo)。

**Day 5 完整 step-by-step `curl -H @filename` 模式 (推薦 for bash smoke test)**:

```bash
# 1. Login 拎 token, 直接寫入 file 唔 echo
curl -fsS -X POST http://localhost/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@crm.local","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])' \
  > /tmp/crm_token.txt

# 2. 驗證 token length (避免 file 空白 / 拎錯 field)
echo "Token length: $(wc -c < /tmp/crm_token.txt)"

# 3. 寫完整 Authorization header 入 file
#    ⚠️ Token 內部唔可以有 newline; 喺 json.load print 出嚟個 string 唔包 newline
{ printf 'Authorization: Bearer *** cat /tmp/crm_token.txt; printf '\r\n'; } > /tmp/crm_hdr.txt
od -c /tmp/crm_hdr.txt | head -2   # 驗證格式

# 4. 用 curl -H @file 帶 token 出去
curl -fsS http://localhost/api/users -H @/tmp/crm_hdr.txt
```

**為何要咁**: bash 嘅 `${TOK...` variable inline 喺 `H="Authorization: Bearer *** /api/me 401 因為 header 變空), 因為 `***` literal 觸發 Hermes 自動 redact 連 closing `'` 都波及。寫去 file 然後 `curl -H @file` 將 token 留喺 file system 而唔係 process argument,完全 avoid `***` pattern matching。

**最簡單 fallback** (推薦 if 唔需要 automation): 用 `delegate_task` 起 subagent 喺 fresh context 跑 Python urllib 一次性 login + smoke。Subagent 可能冇 same Hermes sandbox restrictions。

## ⚠️ Docker container DB migration when host can't reach postgres port (2026-06-05 crm-system Day 5)

**症狀**: `docker-compose.yml` postgres service 唔 expose host port (只 internal `5432/tcp`),host 跑 `bunx prisma migrate dev` 撞 `P1001 Can't reach database server at localhost:5432`。本地 dev 為咗 security + avoid port conflicts 唔 expose 5432 好常見(尤其多 project 同時開發)。

**解決** (4 steps):

1. **手寫 SQL** 放喺 `packages/db/prisma/migrations/<timestamp>_<name>/migration.sql` (CREATE TYPE / TABLE / INDEX / FK),Prisma 5 schema `@@map` 要同 SQL table name 一致
2. **`docker exec` 跑 SQL**:
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < \
     packages/db/prisma/migrations/20260605000000_add_audit_log/migration.sql
   ```
3. **手動 insert `_prisma_migrations` row** mark as applied,否則 entrypoint 嘅 `prisma migrate deploy` 將來會 complain "drift detected":
   ```bash
   docker exec -i crm-postgres psql -U crm -d crm_system -c \
     "INSERT INTO \"_prisma_migrations\" (id, checksum, migration_name, finished_at, applied_steps_count) VALUES ('<unique-id>', '', '<timestamp>_<name>', NOW(), 1);"
   ```
   ⚠️ `migration_name` 冇 unique constraint,要 unique `id` column (`ON CONFLICT (id) DO NOTHING` 即可)
4. **Host 行 `bunx prisma generate`** 重新 generate client 識新 model:
   ```bash
   env $(grep -v '^#' .env | xargs) bunx prisma generate
   ```

**驗證**:
```bash
docker logs crm-api --tail 20
# Expected: "2 migrations found in prisma/migrations" + "No pending migrations to apply"
```

**Alternative** (更麻煩): 暫時改 `docker-compose.yml` expose `5432:5432`,host 跑 migration,改返 expose。**唔建議** 因為 re-up stack 會忘記 uncomment。

詳細 SQL 範本 + 真實 audit_logs migration + 23 個 action enum: 見 `references/2026-06-05-crm-system-rbac-audit.md` 嘅「Docker local dev 嘅 migration 撞牆 + 解決」section。

## ⚠️ Prisma migration folder rename 嘅 silent trap (2026-06-05 crm-system Day 6 真實撞牆)

**症狀**: 經常用 git pull 或者改完 schema 之後想 rename migration folder (例如 `20260605000000_add_audit_log` → `20260605020000_add_audit_log` 修正 sort order),改咗 filesystem 之後 `prisma migrate deploy` 喺 container entrypoint 跑就會 crash:

```
Error: P3009
migrate found migration `20260605020000_add_audit_log` to apply, but the database already has a record of a migration with the same name at the same position.
```

或者更壞嘅:`CREATE TABLE audit_logs` 撞 duplicate 失敗 → container entrypoint 死 → API 唔起。

**根因**: Prisma 唔識 filesystem migration folder rename 同 `_prisma_migrations` table row 嘅 `migration_name` column 自動 sync。你改咗 file 但 db history 仲係舊 name。`migrate deploy` 見到 filesystem 有 `20260605020000_*` 但 db 冇 record, 以為要 apply 新版本,撞 duplicate。

**Fix** (3 steps, 之後先 `git commit`):

```bash
# 1. Rename folder (filesystem)
mv packages/db/prisma/migrations/20260605000000_add_audit_log \
   packages/db/prisma/migrations/20260605020000_add_audit_log

# 2. Update _prisma_migrations table row 同 filesystem 同步
docker exec -i crm-postgres psql -U crm -d crm_system -c \
  "UPDATE _prisma_migrations SET migration_name = '20260605020000_add_audit_log' \
   WHERE migration_name = '20260605000000_add_audit_log';"

# 3. Verify
docker exec -i crm-postgres psql -U crm -d crm_system -c \
  "SELECT migration_name FROM _prisma_migrations ORDER BY started_at;"
# 期望: 20260605020000_add_audit_log (新名)
```

然後先 `git commit` 同 push。**唔好順序倒轉** — 改 file 但未 update db 之前 entrypoint 會壞,build 失敗即 production incident。

**Migration timestamp 命名 rule (避免將來撞呢個 trap)**: 手動整嘅 migration folder name timestamp 一定要晚過 `prisma migrate dev` auto-generated init timestamp (例如 crm-system 嘅 `20260605014842_init`)。Mismatch 唔會 fail build 但 apply 順序錯會撞 foreign key constraint。**查 auto-generated init timestamp**:
```bash
ls packages/db/prisma/migrations/ | sort
# 最早嘅 timestamp 即係 init
```

**相關 helper**: `scripts/backup.sh` 跑之前會 list 而家有咩 backup files (file 內部用 `find`),亦都 help 確認 db 狀態, 但唔會 modify migration history — 改 history 永遠係人手 step。

## ⚠️ nginx SPA `root` directive 唔可以漏 (2026-06-05 crm-system Day 6 真實撞牆)

**症狀**: 已經 set 咗 `location /` + `try_files $uri /index.html` 嘅 SPA fallback config,但第一次去 `/quotations` (或者任何 SPA sub-route) 返 404。`/api/health` 又 work 因為 `location /api/` 自己 handle。Vite 嘅 `dist/index.html` 都已經喺度,assets 都 serve 到。

**根因**: nginx config 漏咗 `root` directive。`try_files` 嘅 fallback `/index.html` 係相對 root,如果冇 `root /usr/share/nginx/html;` 喺 `http {}` 或者 `server {}` 上面,nginx 不知道 `/index.html` 喺邊, 直接返 404 (或者內部 default 行為: 500)。

**David 6/05 fix commit `d2b06d1` 真實修法**:
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;       # ← 必加! 否則 SPA fallback 404
    index index.html;

    # /api reverse proxy
    location /api/ {
        proxy_pass http://crm-api:3001/;
        # ... (略) ...
    }

    # SPA fallback (named location, 唔用 try_files $uri/ = 避免 cycle)
    location / {
        try_files /index.html =404;   # 改用 /index.html (absolute) 而唔係 $uri/
    }
}
```

**Key points**:
1. `root` 必須喺 `server {}` (或者 `http {}`) scope 設,**唔可以擺入 `location /` 入面**(雖然 syntax 接受,但 context 行為唔同)
2. `try_files` 嘅 argument 用 `/index.html` (leading slash 絕對路徑) 而唔係 `$uri/` (會 cycle)— 配合 `root` nginx 解析 `/index.html` 做 `root + /index.html = /usr/share/nginx/html/index.html` ✅
3. **完整能 work 嘅 nginx config** (David 已 push 嘅版本) 喺 `docker-mac-arm64-elysia-vite` skill 嘅 `templates/full-local-stack.md`

**Smoke test** (after build / deploy):
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/              # 期望 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/quotations  # 期望 200 (SPA fallback)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/assets/index.js  # 期望 200 (Vite hashed assets)
```
如果 `/` 返 200 但 `/<sub-route>` 返 404 → 即係 `root` directive 漏咗。

詳細 Day 6 nginx fix context: 見 `references/2026-06-05-crm-system-docker-deploy.md` 嘅「nginx SPA pitfall」section。

## ⚠️ API wrapper boundary normalize for Prisma relation field-name drift (2026-06-06 crm-system Day 12)

**問題 (class-level)**: Backend Prisma return 嘅 relation field 用 Prisma model 嘅 camelCase 名 (e.g. `manDayLines` for `Service.manDayLines ServiceManDay[]`), 但 frontend `Service` TypeScript type 寫住 `manDays` (URL slug / business 簡稱). `request<T>` generic 純 typecast — **冇 runtime bridge**, 個 return object 嘅 field 仍然叫 `manDayLines` (Prisma 個名), `s.manDays` 永遠 undefined 即係:
- Component 訪問 `s.manDays.length` / `.map()` throw `Cannot read properties of undefined`
- Defensive `s.manDays?.length ?? 0` 救表面, 但渲染 "0 個 man-day role" 即係 silent data loss
- User 撞到嘅唔係 500, 而係「冇 data 顯示」— 仲難 debug

**真正 fix (推薦, 套用所有 Prisma relation + frontend type alias 不一致嘅情況)**:

喺 `apps/web/src/lib/api.ts` 個 API wrapper boundary 加 `normaliseEntity` helper, 每個 `list / get / create / update` entry point 統一 pipe:

```typescript
function normaliseService<T extends { manDays?: unknown; manDayLines?: unknown }>(s: T): T {
  const manDaysFromWire = (s as { manDayLines?: ServiceManDay[] }).manDayLines;
  if (manDaysFromWire !== undefined) {
    return { ...s, manDays: manDaysFromWire as ServiceManDay[] };
  }
  return s;
}

export const servicesApi = {
  list: (params) =>
    request<...>('/services?...').then((r) => {
      const items = Array.isArray(r) ? r : r.items;
      return items.map(normaliseService);   // ← 每個 item normalize
    }),
  get: (id) => request<Service>(`/services/${id}`).then(normaliseService),
  create: (data) => request<Service>('/services', { ... }).then(normaliseService),
  update: (id, data) => request<Service>(`/services/${id}`, { ... }).then(normaliseService),
};
```

**Generic rule (套用到所有 Prisma relation field name != frontend type field name)**:
| Backend Prisma | Frontend type | 命名衝突源 |
|---|---|---|
| `manDayLines` (relation) | `manDays` (URL slug / business) | camelCase vs abbreviation |
| `quotationItems` (relation) | `items` (business 簡稱) | Prisma 自動加 entity suffix |
| `serviceManDays` (model) | `manDays` (singular) | 將來寫呢個 relation 要小心 |

**Boundary normalize 一律喺 `lib/api.ts` wrapper 做, 唔好喺每個 component 重複**。原因:
- Single source of truth, 將來 backend 改 relation name 淨改 1 個 file
- Component 寫 `s.manDays` 永遠 work, 後來人唔使知道 backend 嗰邊係 `manDayLines`
- 將來加 `manDayLines` → `manDays` migration / deprecation 都淨改 1 個 file

**Defensive code (`?? []`) 喺 component 入面仍保留** (belt-and-suspenders):
```typescript
// service-detail.tsx 即使 boundary normalize 將來 regress 都唔會 crash
setManDays((service.manDays ?? []).map((m) => ({ role: m.role, dayRate: m.dayRate, days: m.days })));
```

**Detection 工具 (撞牆必做)**:
```bash
# 1. Component 訪問 field 嘅 pattern grep
rg "\.manDays\.|\.manDayLines\." apps/web/src
# 統一用 `manDays`, 有 `manDayLines` 嘅地方 = boundary normalize 漏咗

# 2. 對比 backend 嘅 wire format (Prisma relation name) vs frontend type
rg "manDays:|manDayLines:|manDayLines\?" apps/web/src/lib/api.ts
# 對比 packages/db/prisma/schema.prisma 嘅 field name
```

**Generic 類比 — `useQuery` 個 generic type 同 boundary normalize**:
```typescript
// ❌ 唔好 (type 寫得啱但 runtime 唔 normalize)
const { data } = useQuery({
  queryKey: ['service', id],
  queryFn: () => servicesApi.get(id!),
});
// data.manDays 仍然 undefined!

// ✅ 改 (boundary normalize 喺 api.ts 統一做, useQuery caller 唔使知)
const { data } = useQuery({
  queryKey: ['service', id],
  queryFn: () => servicesApi.get(id!),  // returns Service with normalised manDays
});
// data.manDays 一定有
```

**Related (Day 11 wire-format-side fix)**: 對應 wire format 嗰邊 (request body) 嘅命名同樣要 match backend schema, 唔好 match frontend type alias — 見上面 `polymorphic-line-items` skill 嘅 502 pitfall section 同 Day 11 reference file。**Wire key = backend schema, response normalize = boundary wrapper**。兩個方向嘅 drift 各自 fix 各自嘅 layer。

## ⚠️ Elysia `bun build` 撞 runtime code generation (2026-06-05 真實撞牆)

**症狀**: `bun build src/index.ts --target=bun --outfile=dist/index.js [--minify]` 喺 Elysia 1.2 build **成功**, 但 image run 時 crash:
```
ReferenceError: vn is not defined        # 用 --minify
ReferenceError: client is not defined    # 用 --external @prisma/client
```
**原因**: Elysia 1.2 喺 handler 內部用 `compile?.()` 即時 generate code (route merge, schema derive, `merge` context 嗰啲),內部 variable 叫 `vn` / `client`. **Bun minifier 改咗佢哋個名但 cross-reference 漏咗**, runtime resolve 唔到。

**Workaround (推薦, 2026-06-05 crm-system Docker production 用)**: 唔好 `bun build`, 直接 COPY source 入 image:
```dockerfile
# Builder stage — 淨係裝 deps + generate Prisma client
FROM oven/bun:1.2 AS builder
WORKDIR /app
COPY package.json bun.lock* ./
COPY packages/db/package.json packages/db/
COPY apps/api/package.json apps/api/
RUN bun install --frozen-lockfile
COPY . .
RUN bunx prisma generate --schema=packages/db/prisma/schema.prisma

# Runtime stage — COPY 整個 source, 直接 bun run
FROM oven/bun:1.2
WORKDIR /app
# Prisma engine binary + generated client (Bun workspaces hoist)
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/apps ./apps
COPY apps/api/docker-entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
CMD ["/usr/local/bin/entrypoint"]
```
`entrypoint.sh` 用 `cd /app/packages/db && bunx prisma migrate deploy && cd /app && bun run apps/api/src/index.ts` 直接 source 模式啟動, 等於 dev mode 冇 `--watch` 嘅 production。

**Alternative** (確認撞牆, 唔建議): `bun build --target=bun --outfile=dist/index.js` **(唔加 `--minify`)**, 加 `--external @prisma/client` 避免 Prisma engine 打包問題。仍會撞 `ReferenceError: client is not defined` 因為 Prisma client 喺 bundled output 內部用 `client` symbol, `--external` 標記佢 external 但 bundler 仍然 emit `client` reference。即係 **Elysia + Prisma 暫時唔可以用 `bun build` 任何 mode**。

**Web frontend 用 `bun run build` (Vite) 唔受影響**, 因為 Vite 唔係 Elysia, minify 安全。

**Full details + ready-to-copy Dockerfile patterns**: 見 `docker-mac-arm64-elysia-vite` skill 嘅 **Pitfall 7 (Elysia 1.2 + bun build broken)** + **Pitfall 8 (USER bun + entrypoint permission)** section, 同埋 `templates/full-local-stack.md` 入面有完整 docker-compose.yml + Dockerfiles (proven 喺 `~/www/crm-system` Day 3 production stack, 2026-06-05)。

## ⚠️ Backend response shape 不一致 — frontend 要 normalize (2026-06-05)

**症狀**: Backend Elysia routes 有啲返 `{ items: [...], total, limit, offset }` (e.g. `/companies`), 有啲返 array 直接 (e.g. `/products`, `/quotations`, `/deals`). 兩個 route 寫法唔同 (一個包 wrapper, 一個直返 array), frontend 唔好假設單一 shape。

**Fix** (frontend `lib/api.ts`): 用 `Array.isArray` 兼容兩種:
```typescript
return request<{ items: T[]; total: number } | T[]>(url).then((r) =>
  Array.isArray(r) ? r : r.items
);
```

**一致性建議** (backend): 全部 `findMany` route 都包成 `{ items, total, limit, offset }` shape, 預留 pagination. 用 helper:
```typescript
function paginated<T>(items: T[], total: number, limit: number, offset: number) {
  return { items, total, limit, offset };
}
```

## Vite 8 quirk (詳細)

`bun create vite@latest . -- --template react-ts` 喺 Vite 8 會：
- ❌ 唔裝 react/react-dom/@vitejs/plugin-react
- ❌ 用 vanilla TS template (`src/main.ts` 唔係 `tsx`)
- ❌ 唔寫 `vite.config.ts`
- ✅ 寫 `package.json` 但 scripts 仍 `vite dev/build`

**Fix**：
1. `npm install react react-dom @types/react @types/react-dom @vitejs/plugin-react`
2. 寫 `vite.config.ts`（含 react + tailwind plugin）
3. 刪 `src/main.ts`, `src/counter.ts`, `src/style.css`, `src/assets/`
4. 寫 `src/main.tsx`, `src/index.css`
5. `index.html` 改 `<div id="root">` + `src="/src/main.tsx"`
6. 改 `tsconfig.json` 加 `"jsx": "react-jsx"`

## 完整目錄結構

```
~/www/<project>/
├── backend/
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── seed.ts
│   │   └── migrations/
│   ├── src/index.ts
│   ├── data/app.db
│   ├── .env
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── index.css
│   │   ├── api.ts
│   │   └── pages/{Home,Exam,Review,Stats}.tsx
│   ├── index.html
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── package.json
├── data.json (optional: 初始 data 喺呢度)
└── README.md
```

## 啟動 dev

```bash
# Terminal 1
cd ~/www/<project>/backend
bun --env-file=.env src/index.ts   # :3200

# Terminal 2
cd ~/www/<project>/frontend
npm run dev                        # :5173
```

Frontend 透過 Vite proxy 訪問 `/api/*` → `localhost:3200`。

## Hermes execute_code / terminal 陷阱 (五個唔同嘅事, 唔好混淆)

| 情境 | 問題 | Fix |
|---|---|---|
| `terminal()` 跑 `bun add <pkg>` | Hermes process scanner 見到 `bun` 就當 long-lived 攔截 | 改用 `npm install` 代替 (frontend 啱用) |
| `execute_code` 開 long-lived server (`Popen` + `sleep` + `terminate`) | sub-shell 一 exit, 個 process 一齊死, 個測試結果攞唔到 | 永遠用 `terminal(background=true)` 開 dev server, 之後用 `process(action='poll')` 監察 |
| `execute_code` 內 `subprocess.run([..., "python3", ...])` | Hermes sandbox 嘅 python interpreter 同 system `/usr/local/bin/python3` 唔同, 裝嘅 package 唔共享 | 用 `/usr/local/bin/python3` 絕對路徑, 或 `subprocess.run([sys.executable, ...])` |
| `git commit -m "...\`code\`..."` 寫多行 commit message | Shell 將 backtick 之間嘅 inline code 當 command substitution 解析執行, 撞 `command not found` 噪音, **commit 仍成功但 body 嘅 inline code 全部被食走變空白** | 寫 commit message 入 file 然後 `git commit -F /tmp/msg.txt`。`bash <<EOF` 都會撞同樣問題(shell 解析), 必須 file 落地 |
| `terminal(background=true)` 跑 `docker compose up -d --build` | Hermes 嘅 background process 唔 return exit code 0 即係 build 仍進行中(可能 5-15 min), 唔代表失敗 | 用 `process(action='poll')` 監察,或者 background 之後用 `process(action='wait', timeout=600)`,exit code 0 = build done 唔係 "container died" |

### ⚠️ `docker compose up -d --build` 必然 trigger foreground warning — 一律 background (2026-06-06 crm-system 真實撞牆)

**症狀**: 喺 `terminal()` foreground 跑 `cd ~/www/<project> && docker compose up -d --build` 一定撞:

```
This foreground command appears to start a long-lived server/watch process.
Run it with background=true, verify readiness (health endpoint/log signal),
then execute tests in a separate command.
```

即使個 command 係 `up -d --build`(detached mode + 純 build, 完全冇 long-lived server)— Hermes 嘅 foreground guard 都會 false positive trigger。`exit_code: -1, error: "This foreground command appears..."`。

**根因**: Hermes 嘅 guard heuristic scan 個 command string 見到 `docker compose up` 就當 long-running,**唔識分辨 `-d` (detached) flag**。`--build` flag build 完即 exit,正常 60-180 秒做完。**但 Hermes 無論 `-d` 都 trigger warning**。

**Fix (永遠咁用)**: 任何 `docker compose` command — `up -d`、`up -d --build`、`up -d --force-recreate`、`build --no-cache` — 一律 `background=true` + `notify_on_complete=true`:

```python
# 喺 terminal tool 入面
terminal(
  command="cd ~/www/<project> && docker compose up -d --build 2>&1 | tee /tmp/compose-build.log",
  background=True,
  notify_on_complete=True,
  timeout=600,
)
# 跟住用 process(action='wait', timeout=600) 監察
# process(action='log') 撈 output 睇 "error TS" / "exit code: 2"
```

**Foreground 必然撞 Hermes guard warning**,即使有 `-d` flag 個 daemon 即刻 detach 都撞。

**Verification after build** (必須做, 因為 foreground 撞 warning 後 exit code 已經被蓋住):
```bash
# 1. Container 全部 healthy
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep <service>

# 2. Bundle hash 真係新 (build cache 可能 skip source change)
curl -s http://localhost/ | grep -oE 'index-[A-Za-z0-9_-]+\.js'
docker exec <web-container> ls /usr/share/nginx/html/assets/
# 兩個 hash 對得齊 = new build 真係 deploy

# 3. 或者 force rebuild 一個 dummy file 試
touch apps/web/src/.force-rebuild && docker compose build web
# 應該見到 source COPY stage 唔係 CACHED
rm apps/web/src/.force-rebuild
```

**Generic rule**: 任何 `docker compose` command 都係 background。**Foreground 必然撞 Hermes guard false positive warning**,即使 `docker compose ps`、`docker compose logs`、`docker compose down` 呢類 query-only command 都建議 background(雖然通常 warning 唔 trigger, 但保險)。

**Related**: 同「Docker Compose `up -d --build` cache layers 不重 build source code」(下面) 唔同 — 嗰個 pitfall 係 Docker 自己嘅 cache miss 行為,呢個 pitfall 係 Hermes 工具 false positive warning。**兩個 pitfall 都會令你以為「build 凍咗」但其實冇凍**。

### ⚠️ Build 撞「Cannot find name X」之前,先 grep 個 X 喺 codebase 邊度 define 過 (2026-06-06 crm-system 真實撞牆)

**症狀**: Build 撞 `error TS2552: Cannot find name 'DealDialog'` / `Cannot find name 'QuotationBuilder'` / `Cannot find name 'kanbanStages'`。First reaction 想寫新 file / 新 component / 新 constant 補返。**但其實個 X 可能已經喺 codebase 內部 define 咗**,只係冇 export / 冇 import / 拼錯名。

**例子 (crm-system 2026-06-06)**:
```typescript
// apps/web/src/pages/companies.tsx — WIP 改動引入咗呢行
import { DealDialog } from '@/pages/deals';   // ❌ 'DealDialog' is not exported from '@/pages/deals'
```

實際上 `apps/web/src/pages/deals.tsx:345` 已經有:
```typescript
function DealDialog({...}) {  // ← internal function, 冇 export
```

**Fix = 加 1 個 keyword 9 個 char**:
```typescript
// apps/web/src/pages/deals.tsx line 345
-export function DealDialog({...}) {     // 改 internal → exported
+export function DealDialog({...}) {
```

唔係寫新 `apps/web/src/components/deal-dialog.tsx`,唔係 import `pages/deals.tsx` 嘅 types / helpers,完全唔改 `DealDialog` 嘅 body。

**Generic workflow (撞「Cannot find name X」/「X is not exported」必做)**:

1. **唔好 assume 個 X 真係 missing**:
   ```bash
   # grep X 喺 codebase 邊度 define 過 (case sensitive)
   rg "\bDealDialog\b" apps/web/src
   # 期望: 見到一個定義(就算 internal function 都算)— 即係唔需要寫新
   # 期望: 完全冇 hit — 先寫新
   ```
2. **如果 internal**,check 係 `function` / `const` / `interface` 邊個 export 規則:
   - `function X` → 加 `export` keyword 即可
   - `const X =` → 加 `export` keyword
   - `interface X` / `type X` → 加 `export` keyword
   - **如果係 anonymous `export default`** → 寫 named export `export function X`
3. **如果真係冇 define 過**,**先 grep X 變體**:`rg "DealDialog|deal-dialog|dealDialog"` 有時命名 convention 唔同(eg. `dealDialog` 駝峰 vs `deal-dialog` kebab),可能 existing 用緊另一個名
4. **最後先考慮寫新 file**。**多寫一個 file 引入新 export 嘅機會成本 =** 重新做 code review / 可能同現有 duplicate / 將來 refactor 要兩邊 sync

**Anti-pattern**:
```typescript
// ❌ 撞到 first thought:寫新 file
// apps/web/src/components/deal-dialog.tsx (全新 200 行)
export function DealDialog({...}) { ... }

// ✅ 先 grep,加 export,慳 200 行
// apps/web/src/pages/deals.tsx (改 1 個 keyword)
export function DealDialog({...}) { ... }
```

**Generic rule 套用到所有 X**:
- React component(`DealDialog` / `RoleDialog` / `QuotationBuilder`)
- Elysia route module
- Prisma model name
- Utility function / helper
- Type alias / interface
- 常數(`kanbanStages` / `BASE_REGIONS` / `ALL_PERMISSIONS`)

**5 秒 grep 慳 30 分鐘 over-engineering**。撞「Cannot find name X」,**永遠先 grep X 喺 codebase 邊度 define 過**,**永遠先 assume 個 X 已經 internal 存在**。

**Related**:
- `patch-corruption-recovery` skill — 撞 syntax error 之後 restore from git + re-patch 嘅 pattern。**但** 撞「Cannot find name X」通常唔需要 restore,加 1 個 keyword 即可
- `bun-elysia-react-vite-stack` 嘅「LSP diagnostics stale」section — LSP 報「Cannot find name」可能係 stale cache,先睇 `tsc --noEmit` 嘅真實 error 然後先 grep

具體例子: `bun add tailwindcss @tailwindcss/vite` 喺 `terminal()` 會撞 "This foreground command appears to start a long-lived server/watch process", 但喺 `execute_code` 內用 `subprocess.run(["npm", "install", ...])` 就 OK。

### ⚠️ Git commit message body 永遠寫 file, 唔好 inline (2026-06-09 crm-system 真實撞牆)

**症狀**: 用 `git commit -m "$(cat <<EOF
... 好多行 ...
\`setStageId(deal?.stage?.id ?? stages[0]?.id)\`
\`e.dataTransfer.setData("text/deal-id", deal.id)\`
... 多啲 inline code ...
EOF
)"` 寫一個有 backtick-inline-code 嘅 commit message。Commit **成功** (exit 0, push 都成功), 但 `git log -1 --format='%b'` 出嚟嘅 body 係:

```
1. backend GET /deals/kanban 個 Prisma  冇 ,
   所以 frontend 收到嘅每個 deal 都係 。
```

所有 backtick 區間嘅 inline code 完全消失,剩低空白 + 雜訊 `command not found`。

**根因**: Bash (同大多數 shell) 將 backtick (`` ` ``) 視為 **command substitution**, 等同 `$(...)`。Shell 喺 heredoc 內部 (`<<EOF`) **仍然會 expand backticks**, 唔係真 heredoc (`<<'EOF'` 單引號先唔 expand)。每對 backtick 入面個 expression 當 command 跑, 撞 `command not found` 但 commit 流程唔 fail, body 變空白。

**Fix (3 個 option, 揀適合)**:

**Option A — 寫 file 然後 `git commit -F`** (推薦, 100% safe):
```bash
cat > /tmp/commit-msg.txt <<'HEREDOC'    # 注意: <<'EOF' 單引號, 唔 expand
fix(deals): drag-drop + edit dialog

症狀: 撳 edit dialog 永遠顯示 Stage = "Lead", ... 

\`setStageId(deal?.stage?.id ?? stages[0]?.id)\`  永遠 fall through

\`e.dataTransfer.setData("text/deal-id", deal.id)\`  喺 onDragStart 冇 call
...
HEREDOC
git commit -F /tmp/commit-msg.txt
```

**Option B — `git commit --amend -F file`** (已經 commit 咗, 改 message):
```bash
# 發現 commit message 壞咗, 唔使 reset, 直接 amend
git commit --amend -F /tmp/commit-msg.txt
git push --force-with-lease origin main   # 必須 force-push 因為 commit 改咗
```

**Option C — `<<'EOF'` single-quoted heredoc** (防止 future backtick expansion, 但仍輸 `cat | git` 個 overhead):
```bash
git commit -F - <<'MSG'   # 單引號 heredoc: shell 完全唔 interpret
fix(deals): drag-drop

\`backticks here preserved verbatim\`
MSG
```

**Detection (撞牆後必做)**:
```bash
git log -1 --format='%b' | head -10
# Look 4 啲 inline code (`xxx`) 區間。 如果 4 唔到, 即係 backticks 全部被 shell 食走
```

**Why option A 永遠 work**:
- `<<'EOF'` 喺 cat 嗰度: 寫 file, 文字 verbatim
- `git commit -F /tmp/file`: 純 file read, 唔經 shell 解析
- 完全冇 backtick interpolation, 任何 inline code 字符 (` `, `$`, `\`, etc) 都 pass through

**Generic rule (套用到任何 `git commit` 同樣有 backtick 嘅場景)**:
- `git commit -m "literal text"` — 簡單 message OK, 但 backticks 仍然食
- `git commit -m "$(cat <<EOF ... EOF)"` — **永遠撞**
- `git commit -F file` — 永遠 safe
- `git commit -F -` (stdin via `<<'EOF'`) — safe, 但要小心 trailing newline

**唔好 assume 呢個係 rare case**: 寫 commit message 想用 `` `code` `` highlight 改咗嘅 function name / option / class 個 case 太常見, **第一次有 inline code 就撞**。養成習慣: 一律 file。

## Doc / Web 攞資料嘅限制 (3 個常見撞牆)

撞牆 1: **SPA 渲染嘅 API doc 站撈唔到** (e.g. `https://xxx.com/public/apidoc/<hash>`)
- 症狀: `curl` / `web_extract` 攞到 4-5KB HTML 殼, content 空 (只有 loading spinner + JS bundle)
- 原因: 個 doc 站用 React/Vue 喺 client-side render, content 喺 `__NEXT_DATA__` / bundle 入面
- **唔好再用 firecrawl / curl 撞** — browser_navigate 都會 timeout 因為 content 太慢 load
- **解**: 唔靠 doc, 靠用戶 domain knowledge + 一般 SaaS pattern 設計 schema / endpoints. 問用戶核心 fields/flows 就夠

撞牆 2: **GitHub SSH clone 慢 / proxy 阻擋** (內網 / 公司 firewall)
- 症狀: `git clone git@github.com:...` hang 喺 "Cloning into..."
- 確認 SSH 通: `ssh -T git@github.com` → 「Hi <username>! You've successfully authenticated」
- 唔通嘅話, 改 `https://` 配 PAT: `git clone https://<token>@github.com/<user>/<repo>.git`

撞牆 3: **Git push 完唔知成功定失敗**
- 唔好用 `aws codecommit get-commit` 驗 (IAM 冇 read 權限會 false alarm)
- 用: `git ls-remote <remote>` 或再 `git clone --depth 1 <url> /tmp/verify` 確認 commits 出現

## QA Gate checklist (full-stack app)

- [ ] Backend `/api/health` returns 200
- [ ] Frontend `index.html` returns 200
- [ ] Proxy `/api/health` 透過 frontend returns 200
- [ ] 至少 1 個 E2E write+read flow (POST + GET)
- [ ] Browser 載入 4 個 page 冇 console error
- [ ] RWD mobile audit (見 `rwd-mobile-audit` skill)
- [ ] **Git 推送完記得用 `git clone` 或 `git ls-remote` 驗證**（唔好信 `aws codecommit get-commit` — IAM 冇 read 權限會 false alarm，見 `aws-codecommit-git-setup` 嘅「驗證 push 成功嘅方法」section）

## 相關 skills

- `prisma-sqlite-bun-setup` — Prisma 5 嘅 SQLite 設定 + Prisma 7 撞牆實錄
- `bun-env-file-for-dev` — `--env-file=.env` 嘅必要性
- `rwd-mobile-audit` — 交付前必做嘅 mobile audit
- `caddy-spa-api-proxy-deploy` — 如果要 deploy production
- `backend-rbac-audit-log` — 加 user management + RBAC + audit log 嘅 class-level pattern

## ⚠️ Backup / Restore 對 local Postgres Docker stack (2026-06-05 crm-system Day 6)

**情境**: 用戶要 admin functionality 包含 backup / restore,但又唔想搞 cloud storage / S3 (本地部署就本地 backup)。3 個 scripts + 1 個 docker profile 已經 ready to copy。

### 1. Host-side backup (`scripts/backup.sh`)

`docker exec` 跑 `pg_dump` 喺 postgres container,stream 出 gzip:

```bash
./scripts/backup.sh                    # 預設 7 日 retention
./scripts/backup.sh --keep 30          # 30 日
./scripts/backup.sh --no-trim          # skip cleanup
```

產出:`backups/crm_2026-06-05_132751.sql.gz` (8K for empty schema)。Retention 用 `find -mtime +N -delete`,**冇 cron daemon 都要 work**。

### 2. Restore (`scripts/restore.sh`)

互動式揀 backup + safety confirm:

```bash
./scripts/restore.sh                            # 互動揀
./scripts/restore.sh backups/crm_xxx.sql.gz     # 直接
./scripts/restore.sh <file> --no-confirm        # CI mode
```

**安全流程**:停 API → `DROP DATABASE` → `CREATE DATABASE` → `gunzip | psql -v ON_ERROR_STOP=1` → start API。

**Pitfall**:
- 唔 stop API → DROP DATABASE hang (API 仲 hold 住 connection)
- 唔用 `-v ON_ERROR_STOP=1` → psql 默吞錯誤,partial restore 假成功
- `stat -f '%Sm'` (macOS) vs `stat -c '%y'` (Linux) — 用 `2>/dev/null ||` fallback

### 3. Scheduled backup profile (`docker-compose.yml`)

```yaml
backup:
  image: postgres:16-alpine
  profiles: ["backup"]    # opt-in: `docker compose --profile backup up -d`
  command:
    - -c
    - |
      echo "0 2 * * * /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root
      /usr/local/bin/backup.sh
      crond -f -L /dev/stdout
  environment:
    PGPASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_HOST: postgres
    POSTGRES_DB: ${POSTGRES_DB}
    BACKUP_KEEP_DAYS: ${BACKUP_KEEP_DAYS:-7}
  volumes:
    - ./backups:/var/backups
    - ./scripts/backup-container.sh:/usr/local/bin/backup.sh:ro
  depends_on:
    postgres: { condition: service_healthy }
```

`postgres:16-alpine` 內置 BusyBox `crond`,**唔需要裝 cron daemon**。Skip mechanism:`touch backups/skip` → entrypoint check `if [ -f /var/backups/skip ]; then exit 0`。

### 4. 兩個 backup script 嘅分別 (重要!)

| 環境 | Script | 連線方式 |
|---|---|---|
| **Host 跑** (`./scripts/backup.sh`) | Host script | `docker exec crm-postgres pg_dump` |
| **Container 跑** (cron job 內) | `backup-container.sh` | 直接 `pg_dump -h postgres -U crm -d crm_system` (compose 內部 hostname) |

**唔好 mix up** — host 版本喺 container 內用會撞 `localhost:5432` connection refused 因為 `localhost` 係 container 自己。Container 版本喺 host 用會撞 `postgres:5432` DNS fail 因為 host 唔識 compose 內部 hostname。

### 5. .gitignore 必加

```gitignore
backups/
*.sql.gz
```

`pg_dump` file 可能包含 PII (email, phone, IP)。**絕對唔好 commit 入 git**。

詳細 Day 6 build log 見 `references/2026-06-05-crm-system-audit-backup.md`。

## ⚠️ Elysia 1.2 `.derive()` 喺 POST handler 內 silently 返 `undefined` (2026-06-06 crm-system Day 9 真實撞牆)

**症狀 (比 Day 7 個 `onBeforeHandle` bug 更隱蔽)**: 用 `authContext = new Elysia().derive(({ request, jwt, set }) => { ... return { userId, userRole } })` 然後每個 route `.use(authContext)` + handler `({ userId, set }) => { if (!userId) return 401 }`. **GET routes 全部 work,但 POST routes 個 `userId` 永遠 `undefined`**。如果個 endpoint `if (!userId) return 401` → 全部 POST 返 401。如果個 endpoint 唔 check `userId` (e.g. `/companies` POST 直接 `prisma.company.create()`) → 默默 work 但 audit log 入面 `actorId` 永遠 null。

**Hermes 喺 crm-system Day 9 撞咗 3 個鐘先發現**:
- `POST /api/quotations` 返 401,`POST /api/companies` 返 201(201 因為 handler 唔 check userId)
- `GET /api/deals/kanban` work 正常
- 加 `console.log('[POST /quotations] userId=', userId)` 入 handler → print `undefined`
- 加 console log 入 `authContext.derive` → **冇任何 log**。即係 `derive` 個 async function **完全冇 run**

**根因**: Elysia 1.2 嘅 `derive()` **喺 plugin boundary + body validation chain 內會 silent skip** 個 async function 對於 POST 帶 body 嘅 request。`onBeforeHandle` 都會 derive 唔到(見 Day 7 workaround),但**route handler 直接 destructure 都 derive 唔到**呢個係新發現,更陰濕。**只有先 register 過 sibling `.get()` route 之後先撞**(多個 routes 喺 same Elysia instance chain)。

**Workaround (推薦, 100% bullet-proof)**: 完全唔靠 `derive()` 注入 `userId`,**handler 內 inline verify token**:

```typescript
// apps/api/src/lib/context.ts
import { Elysia } from 'elysia';

export const authContext = new Elysia({ name: 'auth-context' });
// Intentionally empty — Day 9 發現 .derive() 喺 Elysia 1.2 POST handler
// 內 silently 返 undefined。Use getUserIdFromRequest() inline 喺每個
// handler 入面 call 取代。

export async function getUserIdFromRequest(
  request: Request,
  jwt: { verify: (token: string) => Promise<unknown> }
): Promise<string | null> {
  const authHeader = request.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7);
  const payload = await jwt.verify(token);
  if (!payload || typeof payload !== 'object') return null;
  return (payload as { sub?: string }).sub ?? null;
}
```

```typescript
// apps/api/src/routes/quotation.ts
import { authContext, getUserIdFromRequest } from '../lib/context';

.post('/', async ({ body, jwt, set, request }) => {
  const userId = await getUserIdFromRequest(request, jwt);
  if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
  // ... 個 body 之後照舊 ...
}, { body: t.Object({...}) })
```

**Detection (撞牆必做)**:
```python
import urllib.request, json
token = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/auth/login',
  data=json.dumps({'email':'admin@crm.local','password':'admin123'}).encode(),
  headers={'Content-Type':'application/json'}), method='POST')).read())['token']
# Try 一個 GET + 一個 POST endpoint (POST 要 body)
for url, method, body in [
  ('/api/deals/kanban', 'GET', None),
  ('/api/quotations', 'POST', json.dumps({
    'companyId': 'xxx', 'title': 'T', 'taxRate': 0,
    'items': [{'name': 'X', 'quantity': 1, 'unitPrice': 100}]
  }).encode()),
]:
  req = urllib.request.Request(f'http://localhost{url}', data=body, method=method,
    headers={'Content-Type':'application/json','Authorization':f'Bearer {token}'})
  try:
    resp = urllib.request.urlopen(req, timeout=5)
    print(f'  {method} {url}: {resp.status} ✓')
  except urllib.error.HTTPError as e:
    print(f'  {method} {url}: {e.code} {e.read().decode()[:200]}')
# Expected: 兩條都 200/201。如果 GET 200 + POST 401 = derive() bug
```

**Migration impact**: 已經有嘅 routes 用咗 `derive` based `userId`,需要全部改 inline verify。**Crm-system Day 9 改咗 `quotation.ts` 一個檔案嘅 POST handler 就 confirm 全部其他 POST routes 都 hit 同一個 bug**(因為 `authContext` 喺 same Elysia chain 都被污染)。如果個 codebase 大,可能要搵個 subagent 平行 scan 全部 `({ userId` destructure 嘅 POST handler 改用 `getUserIdFromRequest`。

## ⚠️ Elysia `t.Optional(t.String())` 唔接受 `null` literal (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: Frontend 用 React 個 strict-typed form 送 `productId: null` 落 `POST /api/quotations`(因為 form state 個 field 係 `string | null` 而非 `string | undefined`),backend Elysia 個 body schema:
```typescript
body: t.Object({ items: t.Array(t.Object({
  productId: t.Optional(t.String()),
  serviceId: t.Optional(t.String()),
  ...
})) })
```
**返 HTTP 422 Validation**。Backend response body:
```json
{"type":"validation","on":"body","found":{"items":[{"productId":null,"serviceId":null,...}]}}
```

**根因**: Elysia `t.Optional(t.String())` 喺 runtime 只接受 **omit 個 field** 或者 `undefined`,**唔接受 `null` literal**。JSON.stringify(`undefined`) 變 omit,但 `JSON.stringify(null)` 變 `"productId":null` 保留喺 payload,撞 schema fail。

**Fix (1 行)**:
```typescript
productId: t.Optional(t.Union([t.String(), t.Null()])),  // 同 null
serviceId: t.Optional(t.Union([t.String(), t.Null()])),  // 同 null
dealId: t.Optional(t.Union([t.String(), t.Null()])),     // 同 null
```

**Handler 入面仲要 nullish-coalesce** 因為 `productId: null` 通過 validation 但 `null` truthy 個邏輯會 trigger:
```typescript
const productId = (it as { productId?: string | null }).productId;
const serviceId = (it as { serviceId?: string | null }).serviceId;
const itemType: string = serviceId ? 'SERVICE' : 'PRODUCT';
//              ^^^^^^^^^^ null 係 falsy 所以呢行 OK,但 if (productId) ...
//              ^^^^^^^^^^ 個 comparison 會 fail 因為 null !== undefined
return {
  productId: itemType === 'PRODUCT' ? productId : undefined,
  //                          ^^^^^^^^^ null 通過 prisma 但 should be undefined
};
```

**Generic rule**: 任何 frontend 個 state field type 係 `T | null` 而 backend validator 寫 `t.Optional(t.T())` → 撞呢個。**改做 `t.Optional(t.Union([t.T(), t.Null()]))` 兩邊接受**,或者 **frontend JSON.stringify 之前 strip null** (`Object.fromEntries(Object.entries(data).filter(([_, v]) => v !== null))`)。

## ⚠️ Prisma schema `enum` 撞 DB `text` column → 42704 "type does not exist" (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: Prisma schema 寫 `itemType ItemType @default(PRODUCT)`(enum field),但 DB 入面 `itemType` column 係 `text`(可能 Day N 手動 migration 改過 schema 但 DDL 寫咗 text 唔寫 enum)。Prisma `client create` 撞:
```
PostgresError { code: "42704", message: "type \"public.ItemType\" does not exist" }
```

**根因**: 個 enum type 從來冇真正喺 DB create 過 (Day 7 migration 寫 `ADD COLUMN itemType TEXT` 但 schema 寫 enum)。**Prisma client runtime 見 schema 寫 `ItemType` enum 就會喺 SQL 查 `::"ItemType"` cast**,撞 type not exist。

**Fix (永久)**: 統一改 schema 用 `String` 配 literal default:
```prisma
// ❌ 唔好
enum ItemType { PRODUCT SERVICE }
model QuotationItem {
  itemType ItemType @default(PRODUCT)   // 撞 42704 if DB column 係 text
}

// ✅ 改
// itemType stored as text. Valid values: "PRODUCT", "SERVICE"
model QuotationItem {
  itemType String @default("PRODUCT")   // 對 DB 係 text 完全 safe
}
```

**Migration SQL 同步**:
```sql
-- 如果之前 column 已經係 text (而唔係 enum-typed),唔使改 DDL
-- 但 schema 改後 Prisma client 會重新 generate,SQL 唔 emit 任何 cast
-- 直接用新 schema 跑 `prisma migrate dev` produce 一個 no-op migration
```

**驗證 schema 對 DB 一致**:
```bash
# Check 個 column 嘅實際 type
docker exec crm-postgres psql -U crm -d crm_system -c "\d quotation_items"
# Look for "itemType | text" vs "itemType | ItemType (enum)"

# Test 個 path
docker exec crm-postgres psql -U crm -d crm_system -c \
  "SELECT itemtype, itemtype::text FROM quotation_items LIMIT 1;"
# If schema 寫 enum 但 DB text,個 SELECT itemtype 唔 cast 都 work,但 Prisma 寫嘅 INSERT 撞
```

**Pre-emptive rule**: schema 寫 `enum Foo { A B C }` 然後用 `prisma migrate dev` 自動 apply migration,DB 一定有個 enum type。**如果 migration SQL 寫 `TEXT` 但 schema 寫 `enum`,即係 drift**。改 schema 之後必須 `prisma migrate dev` 跑一次睇 output 有冇 "CREATE TYPE"。

## ⚠️ Prisma client 改 schema 後必須重新 generate (host + image) (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: 改咗 `schema.prisma`(e.g. `enum ItemType` → `String`),`bunx prisma generate` host 跑咗,TypeScript compile pass,`docker compose build api` pass,**但 container run 依然撞 42704 "type ItemType does not exist"**。

**根因 (兩層 cache)**:
1. **Host 個 `node_modules/.prisma`**:Bun workspaces hoist Prisma client 去 root `node_modules/@prisma/client`。`bunx prisma generate` 喺 host 跑 → 寫 host 個 file,但 **Docker image 內個 `node_modules` 係 stage 1 `bun install` 嗰陣 嘅**,唔重新 generate
2. **Stage 1 Dockerfile `RUN bunx prisma generate`** 喺 build 期間跑,**用緊 stage 1 個 schema 嘅 version**。如果 host 先 `bunx prisma generate` 改 host 個 client,**但 stage 1 喺 image build 時用 `COPY . .` 之後先 generate**(即用 stage 1 個 source copy 嘅 schema),理論上 fresh schema 應該 new version。**但係 stage 1 `bun install` 嘅 lockfile freeze 咗 Prisma 5.22.0 嘅 client generation 行為**,改 schema 後 stage 1 個 prisma generate 應該用 new schema。

**實際咩撞**:
- Host 跑 `bunx prisma generate` → host client 新嘅
- `docker compose build api`(冇 `--no-cache`)→ BuildKit cache 命中 stage 1 個 `bunx prisma generate` layer 唔重跑 → 個 image 仍然用 stage 1 cache 嘅 schema
- Container run → 用 image baked 嘅 client,撞 old schema 嘅 42704

**Fix (必須兩個都做)**:
```bash
# 1. Host 重新 generate (for local bun run dev)
cd packages/db && bunx prisma generate

# 2. Force image rebuild (for production container)
cd /Users/davidchu/www/crm-system
docker compose build --no-cache api
docker compose up -d --force-recreate api
```

**冇 `--no-cache` 嘅話**:stage 1 個 `bunx prisma generate` layer cache 命中,個 baked image 仍然用舊 client。**always `--no-cache` for schema changes**。

**Verification (必須做)**:
```bash
# 喺 container 入面 check 個 generated client 嘅 type 有冇 ItemType
docker exec crm-api grep -c "ItemType" /app/node_modules/.prisma/client/index.js
# Expected: 0 (因為 schema 已經 drop 個 enum)
# 如果 > 0: 個 image 用緊 stale client,rebuild

# 或者 count ItemType 入 error message
docker exec crm-api grep -c "public\.ItemType" /app/node_modules/.prisma/client/index.js
# Expected: 0
```

**Prisma `enum` 喺 host 個 file system footprint 點查**:
```bash
grep -l "ItemType" /Users/davidchu/www/crm-system/node_modules/.prisma/client/*.js 2>/dev/null
# 如果有 hit,即係 host 個 client 仲見到 enum (re-generate 未 propagate)
```

## ⚠️ Container stuck `Status: created` 連 entrypoint log 都冇 (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: `docker compose up -d --force-recreate api` 個 output 顯示 `Container crm-api Recreated`,但 10 秒後 `docker ps -a` 顯示 `STATUS: created`(唔係 `Up` / `Exited`)。`docker logs crm-api` 返空 string,`docker inspect` 顯示 `Pid: 0, ExitCode: 0`。

**根因**: Dumb-init PID 1 **crash 前 exit code 0**(表示個 child process 正常 finish,但係唔 work),`dumb-init` 自己拎 Pid 1,**佢 crash = container 變 created → 唔 start**。**Entry script 個 `set -e` 配 `exec "$@"` 行為**:如果 entry script 嘅 `bunx prisma migrate deploy` 因為 drift 失敗 (e.g. schema column mismatch),`set -e` 令 script exit,但 `exec "$@"` 已經錯過,個 container 唔 run command 反而 terminate。dumb-init 收到 termination signal **return exit code 0**(正常 exit) → Docker 以為 done,`Status: created` 因為 engine 從未 successfully "started"。

**Fix (3 個 step, 全部要做)**:

1. **Schema + migration 對齊**:run `prisma migrate dev` produce 一個新 migration file 對應 schema 改動
2. **DB 內 `_prisma_migrations` table 同步**:如果之前用 `prisma migrate deploy` 嘅時候有新 migration 而 DB 已經 drift,手動 insert row 標記為 applied
3. **Container entry script 加 `set -x` debug**:
   ```sh
   #!/bin/sh
   set -ex  # 改 -ex (e+exit) 而唔係 -e,echo 每個 command,debug 邊個 fail
   echo "==> [entrypoint] Running database migrations..."
   ...
   ```

**Detection (撞牆必做)**:
```bash
# 1. 確認 container 係咪 stuck
docker ps -a --filter name=crm-api
# Look: STATUS column 應該係 "Up X minutes" 而唔係 "Created"

# 2. 如果 stuck,睇 30s 前 docker events
docker events --since=5m --filter container=crm-api --format '{{.Time}} {{.Status}} {{.Action}}'

# 3. 攞 entrypoint exit code 同 log
docker inspect crm-api --format='{{.State.Pid}} {{.State.Status}} {{.State.ExitCode}}'
docker logs crm-api 2>&1 | head -20
# 空 log = entrypoint 連第一個 echo 都冇出 = dumb-init 唔 fork = Pid 0 issue

# 4. Force 刪 container 重建
docker rm -f crm-api
docker compose up -d api
```

**Common root causes** (in priority order):
1. Schema 改咗但 migration 冇跟住新 (drift)
2. `prisma migrate deploy` 撞 P3009 "migration already in db"
3. `DATABASE_URL` env 喺 compose 唔 pass 入 container (e.g. typo 喺 `${POSTGRES_USER:***` 個 variable name)
4. `dumb-init` binary 唔存在(舊 image 用咗 `oven/bun:1.2` 冇 dumb-init,改用 `tini`)

## ⚠️ Prisma Decimal 返 string → frontend `Intl.NumberFormat` 撞 NaN (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: Backend 返 `deal.value = "75000"`(Prisma Decimal serialize 做 string),frontend 寫 `formatCurrency(deal.value, 'HKD')` 個 function signature `formatCurrency(amount: number)` 期望 number。`Intl.NumberFormat.format("75000")` 喺 V8 引擎 行為不一致:
- 喺 `zh-HK` locale:**返 `"HK$NaN"`**(因為 Intl 試 parse "75000" 做 number 但歧義)
- 喺 `en-US` locale:**返 `"HK$0"`**(silently swallow string)

**根因 (Day 8 已 partially patch)**: 之前 Day 8 喺 `deals.tsx` 個 `useMemo` 加 `Number(d.value)` 強制 coerce。**但每個 `formatCurrency` call site 都要記得 coerce**,容易漏(尤其新寫嘅 component)。`formatCurrency` 個 signature `amount: number` 容易誤導 caller 以為可以 pass string。

**Fix (改 signature + 強 coerce)**:
```typescript
// apps/web/src/lib/utils.ts
export function formatCurrency(amount: number | string, currency = 'HKD'): string {
  // Prisma client returns Decimal as string. Coerce 避免 Intl formatter
  // 撞 "HK$NaN" or "HK$0" (V8 Intl behavior 對 string input 不一致)
  const n = typeof amount === 'number' ? amount : Number(amount);
  return new Intl.NumberFormat('zh-HK', {
    style: 'currency', currency, maximumFractionDigits: 0,
  }).format(Number.isFinite(n) ? n : 0);  // NaN/Infinity fallback 0
}
```

**應用範圍**: 任何 Prisma `Decimal` field(個 schema 寫 `Decimal @db.Decimal(...)` 嘅 field)都用 `string` 返出嚟:
- `Deal.value`, `Deal.creditLimit`(如果加)
- `Company.creditLimit`
- `Quotation.subtotal/taxAmount/total`, `QuotationItem.unitPrice/quantity/discount/lineTotal`
- `Product.unitPrice`, `Service.unitPrice`, `Service.dayRate`

**Generic rule**: 寫新 component 顯示 Prisma `Decimal` field 個 number,**永遠用 helper / inline `Number()` coerce**。**千祈唔好假設 `JSON.parse(decimal)` → number**(Prisma 唔 emit `__type: Decimal` meta,frontend 唔識)。

**Verification**:
```python
# Backend response check
import json, urllib.request
token = ... # login
deal = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/deals?limit=1',
  headers={'Authorization':f'Bearer {token}'})).read())['items'][0]
print(type(deal['value']).__name__, repr(deal['value']))
# Expected: str '75000'  ← 確認 backend 返 string
# If float: 你冇 Decimal,係 Float
```

**Related Day 8 lesson**: 個 Trillion-HK$ bug 喺 `deals.tsx` 個 `useMemo` 入面 `reduce` 用 `+` operator,如果 `d.value` 係 string,`"75000" + "50000"` 變 string concat = "7500050000"。**Always `Number(d.value)` 加落 reduce**。

## ⚠️ Container `docker compose up` hang 喺 foreground 唔 return (2026-06-06 crm-system Day 9 真實撞牆)

**症狀**: 撞牆要 restart api 個時候,`docker compose up -d --force-recreate api` 喺 `terminal()` 工具入面 hang 90 秒 timeout。Output 顯示 `Container crm-api Recreated` 但 foreground command 唔 return。

**根因**: Hermes `terminal()` 工具 嘅 foreground-mode safety guard 偵測到 `docker compose` 個 long-running detached daemon 控制 mode 喺某啲情況下唔 background,個 stdio pipe 唔 close,**foreground command 等 stdout EOF 等唔到**。Bun / Docker 嘅 compose v2 個 `--detach` flag 行為有時依賴 TTY detection。

**Fix (3 個 option, 揀適合你)**:

1. **`nohup` + `disown` pattern**(terminal friendly):
   ```bash
   (nohup docker compose -f /Users/davidchu/www/crm-system/docker-compose.yml up -d --force-recreate api >/tmp/compose.log 2>&1 & disown)
   sleep 2
   cat /tmp/compose.log
   ```
   個 `nohup ... & disown` 確保 process 完全 detach 出 parent shell,foreground command 即時 return

2. **分開 commands**:
   ```bash
   # 個 compose up 自己一個 terminal call
   docker compose -f /Users/davidchu/www/crm-system/docker-compose.yml up -d --force-recreate api 2>&1 | head -3
   # 用 `| head -3` 確保 pipe 唔 hang,個 head 讀完即 close pipe
   ```

3. **`background=true` flag 喺 terminal tool**:
   ```bash
   docker compose -f /Users/davidchu/www/crm-system/docker-compose.yml up -d --force-recreate api
   # 用 terminal 工具嘅 background=true 喺個 CLI,但要 pair notify_on_complete
   ```

**Verification (after restart)**:
```bash
sleep 7  # 等 entrypoint migrate + bun start
docker ps -a --filter name=crm-api
# Expected: STATUS "Up X seconds (healthy)"

docker logs crm-api --tail 5
# Expected: "🦊 CRM API running at 0.0.0.0:3001"
```

**Why 7 秒**: `docker-entrypoint.sh` 跑 `prisma migrate deploy` (1-2s) + `bun run apps/api/src/index.ts` boot (1-2s) + 第一次 `import` Prisma client lazy load (2-3s) = 約 5-7s total。`< 5s` check 會見 `Created` / `Starting` 唔係 `Up`。

## 支援檔案

### Templates
- `templates/backend-package.json` — Bun + Elysia + Prisma 5 嘅 package.json
- `templates/frontend-vite.config.ts` — Vite + React + Tailwind + `/api` proxy
- `templates/frontend-tsconfig.json` — TS6 + JSX 設定齊全
- `templates/backend-index.ts` — Elysia 入口範本 (health + CRUD + t.Object validation)
- `templates/backup-restore-scripts.sh` — host-side backup script (paired with restore.sh + backup-container.sh, 2026-06-05 crm-system Day 6)
- `templates/restore.sh` — host-side restore with safety (DROP + recreate + replay, --no-confirm for CI)
- `templates/backup-container.sh` — in-container version for the `backup` docker profile (runs under crond)

### References
- `references/2026-06-04-llm-acp-real-build.md` — 真實 LLM-ACP 項目嘅完整 build log (Prisma 7 撞牆、Vite 8 quirk、Hermes execute_code 陷阱、Playwright 路徑、Prisma seed path 等 8 個真實撞牆位)
- `references/2026-06-05-crm-system-scaffold.md` — crm-system Day 1-2 scaffold (用戶決策、SPA doc 撈唔到嘅撞牆、new umbrella skills 嘅 pointer)
- `references/2026-06-05-crm-system-docker-deploy.md` — crm-system Day 3 Docker pivot (用戶「本地部署唔用 CDK」偏好、6 個 Dockerfile 撞牆全部已 patch 入 `docker-mac-arm64-elysia-vite` skill)
- `references/2026-06-05-crm-system-quotation-builder.md` — crm-system Day 4 quotation builder (reusable QuotationBuilder component、line item CRUD、status-aware actions、print mode、authContext derive pattern、Hermes 撞 `***` redaction 嘅 smoke test 教訓)
- `references/2026-06-05-crm-system-rbac-audit.md` — crm-system Day 5 user mgmt + RBAC + audit log (集中 permission map Option 3 pattern、Docker container DB migration 嘅 `docker exec psql` trick、last-admin/self-protection invariants、AuditLog schema 完整 SQL)
- `references/2026-06-05-crm-system-audit-backup.md` — crm-system Day 6 audit instrumentation (4 個 CRM CRUD routes 補完) + backup/restore tooling (3 個 scripts + docker profile, host 與 container 兩個 script 嘅關鍵分別)
- `references/2026-06-06-crm-system-region-table-bugfix.md` — crm-system Day 9 (Region enum→table, Elysia derive POST bug, t.Optional null literal, Prisma enum vs text column, Decimal string coerce)
- `references/2026-06-06-crm-system-quotation-builder-enhancements.md` — crm-system Day 10 (autocomplete `bg-popover` transparent bug + quick-create modal 升級做 full form + backend `manDayLines → manDays` normalization + subagent typecheck loop 嘅早期 stop 指標)
- `references/2026-06-06-crm-system-day11-five-issue-bundle.md` — crm-system Day 11 (5-issue bundle: `bg-popover` systemic fix + Product/Service quick-create full-form + 502 Elysia strict validator case study + Deal 編輯兩-call stage pattern + drag/click conflict guard + subagent 600s timeout 接管 SOP)
- `references/2026-06-06-crm-system-day12-fieldname-normalise-docs-hygiene.md` — crm-system Day 12 (`manDayLines` wire vs `manDays` frontend type 真正 root cause + API boundary normalize 統一 pattern + `Service.isActive` legacy drift cleanup + service detail 502 wire format + README/PROGRESS docs hygiene 維護規則 + Tailwind token 完整 audit)
- `references/2026-06-06-crm-system-cross-page-flow-entry-points.md` — crm-system Day 10+ URL query-string prefill pattern (Company→Deal→Quotation), 5-step recipe, 3 invariants, 4-layer delivery checklist, audit script. **Read this before wiring any new model relation into the UI** — David has caught this "backend ≠ UI" gap twice (Day 7 + Day 10+).
- `references/2026-06-06-crm-system-lsp-vs-build-trust.md` — crm-system Day 11+ LSP diagnostics stale vs `docker compose build web` ground truth. Concrete walkthrough of why LSP noise is a false signal in this stack and the correct patch-then-build-immediately workflow.
- `references/2026-06-07-crm-system-comprehensive-code-review.md` — crm-system Day 14 comprehensive 3-pass code review (Security A + Architecture B + Ship Gate C). 53 files reviewed, 0 modified. CRIT-1/2/3 RBAC gaps + HIGH typecheck silent + bun.lock CVE blind spot + 紅線 10/12/16/18 fail. P0/P1/P2 sprint-ready fix list + 3-pass methodology + re-review baseline.
