---
name: pm-system-deployment
description: PM System deployment and development guide
---

# PM System Deployment Skill

## Project Location
`~/projects/pm-system/`

## Tech Stack
- Frontend: React 19 + Tailwind CSS v4 + Vite + Recharts + react-markdown (for wiki)
- Backend: Elysia.js (Bun) + Prisma + PostgreSQL
- Deployment: Docker Compose with nginx reverse proxy

## Quick Start

### Local Development
```bash
# Backend
cd ~/projects/pm-system/backend
bun run src/index.ts  # Runs on :4000

# Frontend
cd ~/projects/pm-system/frontend
bun run dev  # Runs on :3000
```

### Docker Deployment
```bash
cd ~/projects/pm-system/infra
sudo docker compose up -d --build
```

### ⚠️ Hermes 安全機制攔 `docker compose up` 嘅 workaround(2026-06-08)

`terminal` foreground 會攔 `docker compose up`(佢當 long-lived process)。
**正確做法**:

```bash
# 1. 用 background + notify_on_complete 起 docker
terminal(command="cd ~/www/pm-system && docker compose up -d 2>&1 | tail -5",
         background=true, notify_on_complete=true)
# → 攞 session_id

# 2. process poll 追 readiness
process(action="poll", session_id=..., timeout=90)
# → 等 "Container ... Healthy"

# 3. 後續 terminal 跑 test(eg. curl / npm test)
```

**Anti-pattern**:用 `nohup` / `disown` / trailing `&` 喺 foreground mode
= 個 process 會被 Hermes 殺,測試失敗原因難追。

### Initial Setup (PostgreSQL)
```bash
# 自動由 docker compose 做(seed 自動 run):
# - bunx prisma db push
# - bunx prisma db seed  (createRole + 5 builtInUsers + agentUser)
# - bun src/index.ts
# 唔需要 manual psql / manual insert

# ⚠️ 2026-06-08: 舊嘅「Create Admin User」section 嘅 SQL insert 路徑
# 已過時 — seed 已經處理晒。Initial Setup 只係 docker compose up。
```

## Known Issues

### Tailwind CSS v4 Migration
- Uses `@import "tailwindcss"` instead of `@tailwind` directives
- Uses `@theme {}` block for custom colors instead of `tailwind.config.js`
- PostCSS plugin changed to `@tailwindcss/postcss`

### TypeScript Path References
- tsconfig.json must be JSON format (not TS), with `files: []`
- tsconfig.app.json needs `ignoreDeprecations: "6.0"` to suppress baseUrl deprecation

### Prisma with Connection Pooling
- Uses `@prisma/adapter-pg` with `pg` Pool for connection pooling
- Prisma config in `prisma.config.ts` (not schema `url` field)

### Prisma Schema Changes — Critical Order of Operations
When adding new models to the Prisma schema:
1. Update `schema.prisma` with new model
2. **`npx prisma db push`** — updates the database schema (does NOT regenerate client)
3. **`npx prisma generate`** — regenerates the Prisma client types (MUST run separately!)
4. Rebuild backend: `bun build src/index.ts --outdir=dist --target=bun`
5. Deploy — restart container or copy new files

**Common bug**: After `db push`, if new model fields are `undefined`, it's because `prisma generate` was never run. The error looks like:
```
undefined is not an object (evaluating 'prisma.wikiPage.findMany')
```

**Always verify**: Check `node_modules/@prisma/client/index.d.ts` contains your new model, or inside the container: `grep WikiPage /app/node_modules/@prisma/client/index.d.ts`

### Docker Build Artifacts vs Source
The Dockerfile has `CMD ["bun", "src/index.ts"]`. If you rebuild with `bun build` (outputting to `dist/`), you must either:
- Change Dockerfile CMD to `CMD ["bun", "dist/index.js"]` AND rebuild the image, OR
- Copy the bundled `dist/index.js` into the running container manually

When the container's entrypoint/CMD runs `bun src/index.ts` (TypeScript source) but the Prisma client was generated for the bundled output, you'll get silent failures — the server starts but routes that use new Prisma models return empty/undefined.

### Docker Permission Error
- If "permission denied while trying to connect to the docker API":
  - Add user to docker group: `sudo usermod -aG docker $USER`
  - Or run with sudo: `sudo docker compose up -d --build`

### 🔴 Prisma 7 + `prisma.config.ts` 三層 pitfall(RG-011, 2026-06-09)

升級到 Prisma 7 之後,`schema.prisma` 入面嘅 `url = env("DATABASE_URL")` 已 deprecated,
要搬去 `prisma.config.ts`。呢個 migration 撞 3 層 pitfall,**Dockerfile 漏 COPY
就係其中最 hidden 嘅一條**:

**Pitfall 1 — Dockerfile 漏 COPY `prisma.config.ts`**(blocker)
`prisma.config.ts` 喺 backend 根目錄,**唔喺 `prisma/` sub-folder**。如果 Dockerfile
只 `COPY prisma ./prisma` 唔 COPY backend root 嘅 `prisma.config.ts`,image 入面冇
呢個 file。Container start 跑 `prisma db push` / `prisma migrate deploy` 時 throw:

```
Error: The datasource.url property is required in your Prisma config file
when using prisma db push.
```

Container exit(1),`docker compose up -d` build OK 但 backend 完全起唔到。
Frontend 嗰邊 healthy(只 serve static file)所以容易 miss backend 死咗。

**Fix**:
```dockerfile
# builder stage
COPY prisma.config.ts ./   # ← 必須加
RUN DATABASE_URL=postgresql://build:***@localhost:5432/build bunx prisma generate

# runtime stage
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
```

**Pitfall 2 — `prisma.config.ts` 必須用 `env()` helper**(strict config validation)
Prisma 7 config validator 唔 accept `process.env["DATABASE_URL"]` 嘅 generic
return type。要求用 `prisma/config` 提供嘅 `env()` helper:
```ts
// ❌ 唔 work
import { defineConfig } from "prisma/config";
export default defineConfig({
  datasource: { url: process.env["DATABASE_URL"] },
});

// ✅ Work
import { defineConfig, env } from "prisma/config";
export default defineConfig({
  datasource: { url: env("DATABASE_URL") },
});
```

**Pitfall 3 — `prisma generate` 撞 missing DATABASE_URL 喺 builder stage**
雖然 `prisma generate` 本身唔需要 DATABASE_URL,但 `env("DATABASE_URL")` 喺
config load 時 strict throw 假若 var undefined。所以 builder stage 必須
pass dummy URL 過 strict check:
```dockerfile
RUN DATABASE_URL=postgresql://build:***@localhost:5432/build bunx prisma generate
```
URL 唔需要真實,runtime container 有真實 env from docker-compose `environment:`。

**Verification recipe**(每次升 Prisma 7 / 改 Dockerfile 必跑):
```bash
docker run --rm pm-system-backend ls /app
# 預期:node_modules  prisma  prisma.config.ts  src  tsconfig.json
#     全部 5 個 file 喺度
```
如果 `prisma.config.ts` 唔喺 list,後面 `prisma db push` 100% 會 throw。

**Reference**:
- GitHub issue [#28590](https://github.com/prisma/prisma/issues/28590) — `env()` 行為
- Prisma 7 config docs: https://www.prisma.io/docs/orm/reference/prisma-config-reference

### 🔴 Frontend `onClick` await-in-non-async function(2026-06-09)

`WorkLogsPage.tsx:413` 撞 TypeScript error 阻 Vite build:
```
error TS1308: 'await' expressions are only allowed within async functions
and at the top levels of modules.
```

**Root cause pattern**:
```tsx
<button onClick={() => {
  // ... 好多 code
  const buf = await ws2.xlsx.writeBuffer()  // ❌ await in non-async arrow
  // ...
}}>
```

**Fix**:
```tsx
<button onClick={async () => {
  try {
    // ...
    const buf = await ws2.xlsx.writeBuffer()
    // ...
  } catch (err) {
    console.error('Failed to export:', err)
    alert('導出失敗,請重試')
  }
}}>
```

**Why ESLint 通常 miss**:
- xlsx → exceljs migration 嗰陣,sibling 改 import 但冇重新 wrap callback
- ESLint `no-misused-promises` rule 通常會 catch,但 PM-System `frontend/`
  eslint config 似乎冇 enable
- 唯一 surface:Vite build 嘅 `tsc -p tsconfig.app.json && vite build` 步驟

**Detection recipe**:
```bash
cd frontend
docker build -t pm-system-frontend:test . 2>&1 | grep -E "error TS|ERROR"
# 或者 host 直接跑
bunx tsc -p tsconfig.app.json --noEmit
```

**Audit command**(全 project 掃同類 bug):
```bash
cd frontend
python3 -c "
import re, glob
issues = []
for f in glob.glob('src/**/*.{ts,tsx}', recursive=True):
    src = open(f).read()
    # 找 onClick={...} 入面有 await,但 callback 唔係 async
    for m in re.finditer(r'onClick=\{(\(?[^{]*?\)?\s*=>)\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', src, re.DOTALL):
        body = m.group(2)
        if 'await' in body and 'async' not in m.group(1):
            issues.append(f)
print(f'Found {len(issues)} await-in-sync-onClick issue(s):', issues)
"
```

如果 script 報 `Found 0 issue(s)` 即 clean。

### Backend Permission-System Route Updates
- Permission checks use `hasPermission` from `src/middleware/permission.ts`.
- Route-level permissions follow keys like `requirements.view`, `requirements.create`, `requirements.edit`, `requirements.delete`.
- For incremental route edits, preserve existing backward-compatible role/project-member fallbacks unless the task explicitly asks to remove them. Example for requirements: keep admin/pm role fallback and project `ProjectMember.role` checks while adding `hasPermission(user, 'requirements.*')` checks.
- Add explicit `if (!user)` guards before accessing `user.id`; several legacy routes assume authenticated context and can otherwise throw.
- Full `bunx tsc --noEmit` currently reports broad pre-existing project errors (Elysia `user` context typing and unrelated Prisma types). For a targeted route syntax/bundle verification, use:
  ```bash
  cd ~/projects/pm-system/backend
  bun build src/routes/<route>.ts --outdir /tmp/pm-system-<route>-build --target=bun
  ```

### Role Permissions Cache Bug (Critical)
The `rolePermissionCache` in `src/middleware/permission.ts` is the single source of truth for role permissions. It is loaded at startup via `refreshAllRolePermissions()` in `index.ts` and is **NOT automatically invalidated** after role mutations.

**Symptom**: After creating/updating/deleting a role in AdminPanel, admin users get 403 Forbidden on subsequent API calls that check `user.role !== 'admin'` or permission-based auth — even though they are legitimately admins.

**Fix in `src/routes/roles.ts`**: After every POST (create), PUT (update), and DELETE on roles, call `refreshAllRolePermissions()` to re-sync the cache:
```ts
// At top of roles.ts
import { rolePermissionCache } from '../middleware/permission'

// After role.create / role.update / role.delete in each handler:
// 1. Invalidate the cache entry
rolePermissionCache.delete(roleName)
// 2. Refresh all roles (avoids stale admin permissions)
const { refreshAllRolePermissions } = await import('../index')
await refreshAllRolePermissions()
```
Note: Uses dynamic `await import('../index')` to avoid circular dependency since `roles.ts` is imported by `index.ts`.

### seedRolePermissions Deduplication
`seedRolePermissions()` in `roles.ts` is called on every role route request. It uses a module-level `permissionsSeeded` flag to avoid redundant DB writes after the first call:
```ts
let permissionsSeeded = false

async function seedRolePermissions(prisma: any) {
  if (!permissionsSeeded) {
    // seed permissions and roles...
    permissionsSeeded = true
  }
  // always upsert roles (they may be edited by admin)
  await Promise.all(DEFAULT_ROLES.map(...))
}
```

### Deploying Backend to Docker Container
The production backend runs in a `restart: always` Docker container. When replacing `dist/index.js`:

**Correct sequence** (avoids corrupted file from container restart loop):
```bash
# 1. Stop container (prevents restart loop during write)
sudo docker stop pm-system-backend-1

# 2. Copy new file into container's filesystem
sudo docker cp ~/projects/pm-system/backend/dist/index.js pm-system-backend-1:/app/dist/index.js

# 3. Start container
sudo docker start pm-system-backend-1

# 4. Verify startup logs
sudo docker logs pm-system-backend-1 --tail 5
```

**What NOT to do**: `docker exec <container> tee /app/dist/index.js < dist/index.js` — the `tee` approach causes the container to restart during the write (because `restart: always` policy detects the process death), resulting in a partial/corrupted file.

### Wiki Pages Are Project-Scoped
Wiki pages (`WikiPage` model) are scoped to projects via `projectId` FK. They are **not** a standalone feature:
- Wiki pages require project membership (non-admins must be project members to view/create)
- There is NO `/wiki` standalone route or sidebar link — the WikiPage component is reserved for future embedding inside ProjectDetailPage
- If a standalone Wiki page was previously added to the sidebar nav, remove it from `Layout.tsx` navItems and remove its Route from `App.tsx`

## Test Credentials(2026-06-08 verify 真實 seed)

`backend/prisma/seed.ts` 用 `prisma.upsert` 自動建立以下 user:

| Email | Password | Role |
|-------|----------|------|
| `admin@test.com` | `admin123` | admin |
| `pm@test.com` | `pm123` | pm |
| `techlead@test.com` | `tl123` | tech_lead |
| `dev@test.com` | `dev123` | developer |
| `tester@test.com` | `test123` | tester |
| `agent-dev1@test.com` | `agent123` | developer(isAgent=true) |

**Auth endpoint**:`POST /auth/login`(無 `/api` prefix — `authRoutes` 喺 `index.ts` 嘅 `.group('/api')` 之外)

**Token format**(demo 用):`{userId}:{role}`(簡單 JWT-less,生產要改真 JWT)

```bash
curl -s -X POST http://localhost:4001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"admin123"}' | jq .accessToken
# → "fa3889e7-3445-443d-8f0f-c6cee0813539:admin"
```

## API Endpoints

> **Status** (2026-06-08): 19 routes,12 prisma models。Backend `authRoutes` 喺 `.group('/api')` 之外(`/auth/*`),其他全部喺 `/api/*` 之下。

### Auth (public, no `/api` prefix)
- `POST /auth/login` → `{ accessToken, refreshToken, user }`
- `POST /auth/logout`
- `POST /auth/refresh`

### Projects (protected, `/api`)
- `GET /api/projects` / `POST /api/projects` / `GET /api/projects/:id` / `PUT /api/projects/:id` / `DELETE /api/projects/:id`

### Requirements
- `GET /api/requirements` / `POST /api/requirements` / `GET /api/requirements/:id` / `PUT /api/requirements/:id` / `DELETE /api/requirements/:id`

### Tasks
- `GET /api/tasks` / `POST /api/tasks` / `GET /api/tasks/:id` / `PUT /api/tasks/:id` / `DELETE /api/tasks/:id`

### Bugs
- `GET /api/bugs` / `POST /api/bugs` / `GET /api/bugs/:id` / `PUT /api/bugs/:id` / `DELETE /api/bugs/:id`

### WorkLogs(server-side 分頁,commit 9adc1fa)
- `GET /api/worklogs`(query:`page`, `pageSize`, `limit=-1` for export, `groupBy`)
- `POST /api/worklogs`(驗證 hours 0.01-24)
- `PUT /api/worklogs/:id` / `DELETE /api/worklogs/:id`(cutoff:5 號前嘅 log,non-admin 唔可改)

### Users / Roles / Permissions (Admin only)
- `GET/POST/PUT/DELETE /api/users`
- `GET/POST/PUT/DELETE /api/roles`
- `GET /api/permissions`

### Agents (Admin only create/edit)
- `GET /api/agents` / `POST /api/agents` / `PUT /api/agents/:id` / `DELETE /api/agents/:id`
- `GET /api/agents/:id/stats` / `GET /api/agents/available-tasks`
- `POST /api/agents/claim-task` / `POST /api/agents/release-task`

### Token Logs
- `GET /api/token-logs` / `POST /api/token-logs` / `GET /api/token-logs/stats/by-model` / `GET /api/token-logs/stats/by-agent`

### Wiki (project-scoped, FK WikiPage.projectId)
- `GET/POST/PUT/DELETE /api/wikis`

### Documents / Attachments / LLM Config / Chat / Reports / Departments
- `GET/POST/PUT/DELETE /api/documents`
- `GET/POST /api/attachments`
- `GET/POST /api/llm-config`
- `GET/POST /api/chat`(綁定項目)
- `GET /api/reports/*`
- `GET/POST/PUT/DELETE /api/departments`

### Docker Port Mapping(2026-06-08 verify)

| 服務 | Docker port | Local access |
|------|-------------|--------------|
| Frontend (nginx) | 8080:80 | http://localhost:8080 |
| Backend (Elysia) | 4001:4000 | http://localhost:4001 |
| Postgres | 5433:5432 | postgresql://pmuser:pmpassword@localhost:5433/pmdb |

E2E test 兩個 URL 都 test:Frontend via nginx(:8080),Backend direct(:4001)。

## E2E Testing (2026-06-08 新增)

`e2e/` 目錄有 Playwright config + 2 個 spec file:

```bash
# 1. 確保 docker up
cd ~/www/pm-system
docker compose up -d

# 2. 跑 E2E
cd e2e
npm install
npx playwright install chromium
npx playwright test
# → 13 tests pass(3 critical-path + 10 rbac-negative)
```

### Critical Path(`tests/critical-path.spec.ts`)
- 登入 → 建項目 → 建需求 → 建任務 → 填工時 → UI render
- health check:frontend :8080 + backend :4001 reachable
- UI login flow:form submit → redirect 去 `/`

### RBAC Negative(`tests/rbac-negative.spec.ts`)
- developer / tester 嘗試 POST /projects → 403
- developer 嘗試 DELETE /users → 403
- 冇 token / malformed token → 403
- non-existent UUID → 500(已知 bug TD-011,test 守住等 fix)
- admin 同一 endpoint → 200(positive control)

**⚠️ Rate-limit interaction pitfall (RG-008, 2026-06-09)**
TD-008 嘅 login rate-limit (5 attempts / 60s per IP) 對 rbac-negative spec 嘅
multi-user login 有 interaction。E2E spec 11 次 login attempts 全部 hit 同一個
container IP,撞 5/60s lock 第 6 個開始返 429,而非 200。

**Workaround(短期)**:
```bash
# 跑 E2E 之前 reset rate-limit counter — restart backend
docker compose restart backend
# 等 ~12s 重新跑 seed + API up
sleep 12 && cd e2e && npx playwright test
```

**Long-term fix(E2E 設計)**: spec 應該 stub rate-limit 喺 beforeAll,或者
用 multi-IP 模擬(同一 host 多個 source port)。詳見 TECH-DEBT 嘅 TD-008
進度(待補完整 E2E integration test)。

詳見 `e2e/README.md`。

---

## 🔴 已知 Quirks(2026-06-08 親驗)

1. **Backend port mapping**:`4001:4000`(frontend 8080,postgres 5433)— 唔係文件寫嘅 3000/3001
2. **`/auth/*` 無 `/api` prefix**:`authRoutes` 喺 `index.ts` 嘅 `.group('/api')` 之外
3. **Token format**:`{userId}:{role}`(demo 用,無真 JWT signing)
4. **Backend 將 auth-missing 視為 403** 而非 401(derive hook `return { user: null }` 後,permission check 失敗 → 403)
5. **`prisma.user.findUnique` 撞不存在 UUID throw 500** — 見 TD-011,fix 0.1 日
6. **Prisma Decimal 序列化成 string** over REST — E2E test 要 `Number()` 比較
7. **Login success redirect 去 `/`**(dashboard)— 唔係 `/projects`
8. **pm 有 `projects.create` perm**(我以為冇)— verify seed.ts 知
9. **Docker 服務 healthcheck**:`backend` 個 healthcheck 用 `curl /api/projects`,但 `/api` 需要 auth — 撞 401 仍算 healthy

---

## Sprint 21 — Wiki Improvements (2026-06-16, US-21.1..5, merged 46323bf)

5 個改動一次過 ship(David 揀 A = full package)。Working tree 開工前**已 uncommitted 全部 code + 1 retro doc**(唔係由零寫,係 verify + commit + push),4 個 commit 落到 `feat/wiki-sprint-21` 再 merge --no-ff 入 master。

### 5 個 US 對應

| US | 範圍 | 實作 |
|----|------|------|
| **21.1** (P0) | Wiki 上傳支援 `.doc`/`.xls`/`.txt` | `documents.ts` parser + `SUPPORTED_EXTENSIONS` + Dockerfile `apk add` |
| **21.2** (P1) | AI 分析文件時包含 `fileName` | **早已 include** `${fileName}` in user message(US-21.1 嗰陣 verify 過,冇 hunks 改)|
| **21.3** (P0) | 同項目內同名 Wiki 偵測 + 確認 modal | `utils/wiki-dedup.ts` (new) + `wikis.ts` `replaceId` 邏輯 + `WikiPage.tsx` UI |
| **21.4** (P0) | Wiki 查詢窗口 10 + result metadata | `chat.ts` `MAX_WIKI_PAGES` 5→10 + `WikiSearchResponse` `{requested, matched, returned, totalAvailable, hasMore}` |
| **21.5** (P1) | 跨項目 AI 查詢 | `chat.ts` `executeTool` `search_wiki`: 冇 `effectiveProjectId` → admin 查全項目,non-admin 查 member projects,merge sort |

### 4 個 commit 嘅 split(file 邊界優先,US 順序第二)

| Commit | File(s) | US 覆蓋 |
|--------|---------|---------|
| `e39dcb5` feat(docs) | Dockerfile + documents.ts + documents.test.ts + WikiPage.tsx | US-21.1 (+ 21.2 skip + 21.3 leak 因為 hunks 纏埋)|
| `de53111` feat(wiki) | wiki-dedup.ts (new) + wiki-dedup.test.ts (new) + wikis.ts | US-21.3 |
| `00a1552` feat(chat) | chat.ts + ChatPage.tsx | US-21.4 + US-21.5(hunks 纏埋) |
| `0aaea13` docs(retro) | docs/retros/2026-06-16-sprint-21-wiki-improvements.md (new) | Retro doc |

**Hunk 纏繞嘅 honest 處理**:documents.ts hunks L580+ 包含 US-21.3 嘅 `findExistingWikiPage` import + 409 response,跟 US-21.1 parser hunks 喺同一 file,**拆唔到**。Commit message 明寫「Note: this commit also includes some pre-existing US-21.3 hunks ...」+ 後續 US-21.3 commit 解釋。**唔好 pretend clean atomic 唔 leak**。

### WikiPage schema 入面 `MAX_WIKI_PAGES` + `WikiSearchResponse` 永久 invariant(2026-06-16 起)

```ts
// backend/src/routes/chat.ts
const MAX_WIKI_PAGES = 10          // 2026-06-16 bumped 5 → 10
const MAX_WIKI_TOOL_RESULTS = 10   // unchanged
const DEFAULT_WIKI_TOOL_RESULTS = 5 // unchanged

type WikiSearchResponse = {
  results: WikiSearchResult[]
  requested: number
  matched: number
  returned: number
  totalAvailable: number
  hasMore: boolean
}
```

如果日後要再加 wiki 內容窗口,**`MAX_WIKI_PAGES` 同 `MAX_WIKI_TOOL_RESULTS` 都要同步改** — 前者係 LLM 收到嘅 system prompt 內容,後者係 AI tool call 嘅用戶面 limit。

### `findExistingWikiPage` helper(2026-06-16 新)

`backend/src/utils/wiki-dedup.ts`:
```ts
export function normalizeTitleForCompare(title: string): string {
  return title
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/[。.,，、:;!?]+$/g, '')
}

export async function findExistingWikiPage(projectId: string, title: string) {
  // Prisma can't express normalize in WHERE → pre-filter case-insensitive
  // contains, then post-filter for whitespace/punctuation normalization
  // ...
}
```

**不變量**:同 project 內,標題 normalize 後相同 = 重覆,返回 409 `DUPLICATE_PAGE` + `existingPage` metadata。前端確認後 call `POST /api/wikis` 加 `replaceId: <id>` 做 in-place update(唔 overwrite silently)。

### Alpine `apk add` package 鎖定(2026-06-16)

```dockerfile
RUN apk add --no-cache poppler-utils antiword wv gnumeric
```

| Package | Binary | 用途 |
|---------|--------|------|
| `poppler-utils` | `pdftoppm` `pdfinfo` | PDF 轉 PNG (vision LLM 入口)|
| `antiword` | `antiword` | `.doc` (Word 97-2003) parser |
| `wv` | `wvText` | `.doc` fallback(antiword 失敗時)|
| `gnumeric` | `ssconvert` | `.xls` (Excel 97-2003 BIFF8) parser |

**不要改呢 4 個 package 名**,因為佢哋已經喺 image 入面 verify 過 binary 真係 exist。改咗而又唔重新跑 `docker run --rm pm-system-backend sh -c "which antiword wvText ssconvert"` 嘅話,**下次 `docker build` 隨時爆**。詳見 `docker-mac-arm64-elysia-vite` 嘅 Pitfall 12(verify Alpine package 存在先寫 Dockerfile)。

### 9 個新文件 / 修改文件清單(Sprint 21 scope)

```
M  backend/Dockerfile                                 (apk add line)
M  backend/src/routes/chat.ts                         (MAX_WIKI_PAGES, WikiSearchResponse, cross-project)
M  backend/src/routes/documents.test.ts               (SUPPORTED_EXTENSIONS)
M  backend/src/routes/documents.ts                    (.doc/.xls/.txt parsers + findExistingWikiPage hook)
M  backend/src/routes/wikis.ts                        (replaceId + 409 DUPLICATE_PAGE)
A  backend/src/utils/wiki-dedup.ts                    (NEW)
A  backend/src/utils/wiki-dedup.test.ts               (NEW, 12 cases)
M  frontend/src/pages/ChatPage.tsx                    (🌐 全部項目 option)
M  frontend/src/pages/WikiPage.tsx                    (重覆 modal + 更新此頁 button)
A  docs/retros/2026-06-16-sprint-21-wiki-improvements.md (NEW)
```

### Hotfix US-21.1.1(2026-06-16, post-merge)

Dockerfile 一開始寫 `catdoc` + `xls2csv`,**Alpine v3.22 冇呢兩個 package**。Docker build 第一次失敗(layer 2 `RUN apk add` exit 2)。Hotfix spec:
- `catdoc` → `wv` (provides `wvText`)
- `xls2csv` → 直接用 `ssconvert`(gnumeric 入面),`xls2csv` + ssconvert fallback 兩層變一層
- retro doc 加 `Hotfix US-21.1.1` section 留 audit trail

呢 3 個 file 改動**仲未 commit**(截至 2026-06-16 16:00) — 屬 image re-build hotfix,code change 應該後續追蹤成 1 個 `fix(docs): US-21.1.1 replace unavailable Alpine packages` commit。

### 710 pass / 0 fail(2026-06-16 verify)

```bash
cd backend && bun test
# → 710 pass, 0 fail, 1245 expect() calls, 31 files, [2.08s]
```

---

## 🔴 Client Release / Off-Premise Deployment(2026-06-09)

David 對客戶交付嘅需求:**唔畀 source code、x86 + arm 都要行、會有更新**。
2026-06-09 制定嘅方案 = **多 platform image + tarball handoff + 客戶一鍵 install**。
本機 dev(上面)同客戶交付(呢度)係兩條完全唔同嘅 path,**唔可以混淆**。

### 3 條約束(每次 release 必守)

| 約束 | 落地方法 |
|------|---------|
| **唔畀 source code** | 客戶機冇 Dockerfile,只有 image tar;source folder 唔出 package |
| **x86 + arm 都要行** | `docker buildx` 建 manifest list,`linux/amd64` + `linux/arm64` 同一個 tag |
| **可更新** | 客戶機 `docker load` 新 tar → `docker compose up -d` → 自動跑 `prisma migrate deploy` |

### 產出嘅 5 個 file(都喺 project 內,2026-06-09 已 commit)

```
scripts/build-release.sh          ← 我/CI 跑,build + save tar
deploy/docker-compose.client.yml  ← 客戶用嘅 compose(無 seed)
deploy/.env.client.example       ← 客戶 copy 做 .env 嘅 template
deploy/install.sh                ← 客戶跑嘅 5-step 安裝
deploy/README.md                 ← 客戶 30 秒版手冊
deploy/CHANGELOG.md              ← 每個 release 記低咩改咗
```

詳細內容睇 `templates/client-release/`(可 copy 落新 project 改用)。

### Image 結構(每個 release)

```
pm-system-frontend:v1.0.0          ← 1 tag(nginx platform-neutral,理論上 1 份 binary 行晒兩個 arch)
pm-system-backend:v1.0.0           ← 1 tag + 2 個 arch,做成 manifest list:
                                       ├─ linux/amd64(oven/bun:1-alpine + bun 嘅 native binary)
                                       └─ linux/arm64
```

**Frontend 唔使 multi-arch 都得**(nginx static 已經係 universal binary),
但 2026-06-09 嘅 build script 仍然 build 兩份 load 一次過,保持 image tag 結構一致。

### 客戶 tarball package(寄畀客戶嘅整份 content)

```
pm-system-release-v1.0.0/
├── README.md                              ← 一張紙 3 步裝完
├── docker-compose.client.yml              ← 客戶用
├── .env.client.example                    ← 客戶 copy 做 .env
├── pm-system-frontend-v1.0.0.tar
├── pm-system-backend-v1.0.0-multiarch.tar
├── CHECKSUMS.sha256                       ← 客戶 install.sh 自動 verify
├── RELEASE-NOTES.md                       ← 客戶睇 update
└── install.sh                             ← 一鍵裝
```

### 客戶 install 流程(5 行搞定,3 分鐘)

```bash
# 1. 解壓
tar xzf pm-system-release-v1.0.0.tar.gz && cd pm-system-release-v1.0.0
# 2. 改 .env
cp .env.client.example .env && $EDITOR .env
# 3. 跑
chmod +x install.sh && ./install.sh
# 4. 訪問
open http://localhost/
```

`install.sh` 自動做晒:pre-flight 檢查 docker、.env field 驗證、CHECKSUMS 驗證、
`docker load` 兩個 image、`docker compose up -d`、等 backend health(最長 90s)、
印 access URL。

### 客戶專用 compose 同 dev compose 嘅 7 個關鍵差異

| 項目 | dev compose | 客戶 compose |
|------|------------|------------|
| `db` 密碼 | `pmpassword` hard-coded | `${DB_PASSWORD}` 必填,冇 default |
| `JWT_SECRET` | `dev-secret-key` | `${JWT_SECRET}` 必填,冇 default |
| `prisma db push` | ✅ 跑 | ❌ 改用 `prisma migrate deploy` |
| `prisma db seed` | ✅ 跑 | ❌ **唔跑**(seed 屬 source,不外流) |
| backend port | `4001:4000` 公開 | **只 internal `expose: 4000`**,frontend 經 nginx proxy |
| db port | `5433:5432` 公開 | **只 internal `expose: 5432`** |
| `restart: unless-stopped` | 冇 | ✅ 3 個 service 都有 |
| log driver | default | json-file 10MB × 3 rotation |
| volume name | `postgres_data`(auto) | `pm-system-postgres-data`(named,update 唔會 data loss) |
| image source | `build:` 來源碼 | `image: pm-system-*:${VERSION}`(load 完用 tag) |

### Build script 嘅 3 個決策點(2026-06-09 已 lock)

#### Decision 1:Q1(A) vs Q2(B) — image package 結構
- ✅ **A) Multi-arch single tarball** (David 揀)
- 客戶 `docker load -i` 一個 file,自動揀 arch。簡單過畀 2 個 tar。

#### Decision 2:Build 邊度跑 — Q2
- ✅ **A) 我 pre-build,客戶只 load** (David 揀)
- Mac M-series QEMU 慢 5-10x 但**可接受**(build 不算 release 熱點)
- 真要 scale:改用 GH Action(`docker/build-push-action@v5` 行 multi-arch runner)

#### Decision 3:Seed file 喺 image 入面處理
- ✅ **方案 1**:`prisma/seed.*` 落 `.dockerignore` 排走
- 客戶機 `migrate deploy` 唔會跑 seed(image 都冇 seed file)
- 即使客戶反組譯 image 都見唔到 demo data

### 客戶更新流程(未來 v1.1.0+)

```bash
# 客戶機收到新 tarball 之後
docker load -i pm-system-frontend-v1.1.0.tar
docker load -i pm-system-backend-v1.1.0-multiarch.tar
# 改 .env
sed -i '' 's/^VERSION=v.*/VERSION=v1.1.0/' .env
# 重啟(migration 自動跑,data volume 保留)
docker compose -p pm-system up -d
```

**重要**:data volume 係 named(`pm-system-postgres-data`),`docker compose down`
唔會刪;`docker compose down -v` 先會刪。**客戶 update 唔會 data loss**。

### ⚠️ Pitfall 1 — Backend 唔可以 `bun build`(2026-06-05 crm-system 教訓)

`bun build --minify` 撞 Elysia 1.2 嘅 runtime code gen(`compile?.()`)會
`ReferenceError: vn is not defined`。客戶 backend 嘅 Dockerfile **直接 COPY
source 入 runtime image + `bun run src/index.ts` 啟動**,唔用 bun build。
Image 大 ~200MB,cold start 慢少少,但係**最穩 path**。
詳見 `devops/bun-elysia-react-vite-stack`。

### ⚠️ Pitfall 2 — Prisma 7 + `prisma.config.ts` 三層 pitfall(沿用上面)

客戶 backend Dockerfile 一定要 COPY `prisma.config.ts` 同 builder stage 嘅
`prisma generate` 嗰個 dummy `DATABASE_URL` 否則 image 入面 prisma config
validator throw `datasource.url is required`,container exit(1),backend 完全起唔到。
Frontend healthy 會誤以為 OK,**一定要 curl backend health**。

### QA Gate(每個 release 必跑)

1. ✅ `bash scripts/build-release.sh vX.Y.Z` 跑完冇錯
2. ✅ `shasum -a 256 deploy/dist/*.tar` 同 `CHECKSUMS.sha256` 對得齊
3. ✅ 模擬客戶機:開另一個目錄,`docker load -i *.tar` → `docker compose -f docker-compose.client.yml up -d`
4. ✅ `curl http://localhost/api/projects` = 200(backend healthy)
5. ✅ `curl http://localhost/` = HTML(frontend nginx 起咗)
6. ✅ **冇 seed 跑**(`prisma db seed` 唔喺 client compose command)
7. ✅ `restart: unless-stopped` 設咗(全部 service 都有)
8. ✅ `.env.client.example` 嘅 secret 全部係 `PLACEHOLDER` 字眼
9. ✅ 客戶 install.sh 嘅 placeholder check 對得齊(用 regex `=~ PLACEHOLDER`)

### Decision matrix(下次開新客戶時用)

| 客戶需求 | 用呢個 path |
|---------|------------|
| 唔畀 source、要 image、要 offline | **本 section** ✅ |
| 客戶肯用 Docker Hub / GHCR | 可以改用 `docker push` + `image: registry/...`,可省 tarball step |
| 客戶要 HA / multi-node | 改用 Kubernetes / ECS,呢個 path 唔啱,睇 `cdk-ecs-fargate-deploy` |
| 客戶要 source 自行 build | 違反「唔畀 source」,建議搬去 SaaS offering |
| 客戶要 HTTPS | 加 Caddy reverse proxy,睇 `caddy-spa-api-proxy-deploy` |

---

## 📚 Related references

- `docs/PROJECT-OVERVIEW.md` — 完整 scope / stack
- `docs/PRD.md` — 50+ US
- `docs/QA-TRACKER.md` — US 過 test 狀態
- `docs/TECH-DEBT.md` — TD-001 到 TD-011
- `e2e/README.md` — 點跑 E2E
- `backend/CLAUDE.md` — Bun-specific 規則
- `templates/client-release/` — 客戶交付嘅 5 個 starter file(reproduce with modifications)
- `references/multi-arch-build-decision-matrix.md` — 點解用 A 而唔用 B/C/D