---
name: bun-elysia-react-vite-stack
description: Bootstrap a local full-stack TypeScript app with Bun 1.2 + Elysia backend + Vite 8 + React 19 + Tailwind v4. SQLite via Prisma 5. Use when user wants a quick local dev app (exam app, MVP, internal tool, learning app) and stack is the same family.
tags: ["bun", "elysia", "react", "vite", "tailwind", "prisma", "fullstack", "stack", "bootstrap", "sqlite"]
---

# Bun + Elysia + Vite/React Full-Stack Bootstrap

本地 dev 嘅最快 full-stack TS stack。Elysia 同 Bun runtime 配 Vite 嘅 HMR 體驗極順。SQLite 用 Prisma 5（**唔好用 Prisma 7** — 見 prisma-sqlite-bun-setup skill）。

## 觸發時機

- 用戶要 quick MVP / internal tool / 個人練習 app
- 已經喺 Elysia + Vite 環境做開
- 唔需要 deploy production（local dev 為主）

## 完整 SOP

### 1. Backend init

```bash
mkdir -p ~/www/<project>/backend && cd ~/www/<project>/backend
bun init -y
bun add elysia @prisma/client
bun add -d prisma@5 tsx @types/node dotenv
```

> ⚠️ **Prisma 一定要 pin `prisma@5`**：`bun add prisma` 會拉到 7.x，撞 schema 唔再支援 `url = env(...)`。詳見 `prisma-sqlite-bun-setup` skill。

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

## Hermes execute_code / terminal 陷阱 (三個唔同嘅事, 唔好混淆)

| 情境 | 問題 | Fix |
|---|---|---|
| `terminal()` 跑 `bun add <pkg>` | Hermes process scanner 見到 `bun` 就當 long-lived 攔截 | 改用 `npm install` 代替 (frontend 啱用) |
| `execute_code` 開 long-lived server (`Popen` + `sleep` + `terminate`) | sub-shell 一 exit, 個 process 一齊死, 個測試結果攞唔到 | 永遠用 `terminal(background=true)` 開 dev server, 之後用 `process(action='poll')` 監察 |
| `execute_code` 內 `subprocess.run([..., "python3", ...])` | Hermes sandbox 嘅 python interpreter 同 system `/usr/local/bin/python3` 唔同, 裝嘅 package 唔共享 | 用 `/usr/local/bin/python3` 絕對路徑, 或 `subprocess.run([sys.executable, ...])` |

具體例子: `bun add tailwindcss @tailwindcss/vite` 喺 `terminal()` 會撞 "This foreground command appears to start a long-lived server/watch process", 但喺 `execute_code` 內用 `subprocess.run(["npm", "install", ...])` 就 OK。

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

## 支援檔案

### Templates
- `templates/backend-package.json` — Bun + Elysia + Prisma 5 嘅 package.json
- `templates/frontend-vite.config.ts` — Vite + React + Tailwind + `/api` proxy
- `templates/frontend-tsconfig.json` — TS6 + JSX 設定齊全
- `templates/backend-index.ts` — Elysia 入口範本 (health + CRUD + t.Object validation)

### References
- `references/2026-06-04-llm-acp-real-build.md` — 真實 LLM-ACP 項目嘅完整 build log (Prisma 7 撞牆、Vite 8 quirk、Hermes execute_code 陷阱、Playwright 路徑、Prisma seed path 等 8 個真實撞牆位)
