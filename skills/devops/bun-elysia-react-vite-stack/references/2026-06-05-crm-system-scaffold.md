# 2026-06-05 — crm-system Scaffold Session

## Session 摘要

David 開新項目 `~/www/crm-system`, 重建佢嘅 sales CRM + 報價單系統, 加入 AI Agent. 舊系統喺 `erp.sme-boardpro.com` (SPA 渲染, doc 撈唔到).

## 用戶決策 (Plan 階段問完即時答)

| 決策 | 選擇 |
|---|---|
| Stack | **Bun + Elysia + React + Vite + Tailwind** (跟 `bc-quotation` pattern) |
| DB + ORM | **Postgres + Prisma** (唔係 SQLite, 因為要做 AI agent + CRM) |
| AI Agent scope | **Day 1 全套上** — CRM 核心 + AI 報價助手 + AI 客戶分析 + WhatsApp/Slack + Tool calling + Memory |
| Data model | 放手比我自由設計 (HubSpot/Pipedrive-inspired) |

## 撈舊 CRM doc 撞牆

**嘗試 1**: `web_extract` (Firecrawl) → 504 timeout
**嘗試 2**: `curl -sL` → 4.2KB HTML 殼, 內容 runtime render
**嘗試 3**: `browser_navigate` → timeout (content 慢 load)

**結論**: 唔再嘗試, 改靠 David 嘅 domain knowledge. 已記入 `bun-elysia-react-vite-stack` 「Doc / Web 攞資料嘅限制」section.

## 撈 GitHub repo 確認

```bash
# 確認 repo 存在
git clone --depth 1 git@david-dev-env:freedomw1987/crm-system.git /tmp/check
# → warning: You appear to have cloned an empty repository.
# → 確認: repo ✅ 通, 內容空, 全新項目
```

## 已 create 嘅 skills (呢個 session)

- `crm-data-model` (umbrella) — 11 個 core CRM models 嘅 Prisma schema
- `ai-agent-tool-calling` (umbrella) — Function calling + tool registry + memory + RAG pattern

## 已 patch 嘅 skills (呢個 session)

- `bun-elysia-react-vite-stack`:
  - 加 Postgres path recommendation (CRM/AI 必上 Postgres 嘅原因)
  - 加 Bun workspaces monorepo structure (`apps/api`, `apps/web`, `packages/db`)
  - 加 3 個 doc/web 攞資料嘅撞牆 (SPA doc, GitHub SSH, push verify)

## 待做 (Build 階段)

1. `~/www/crm-system/` scaffold
2. `packages/db` Prisma schema (跟 `crm-data-model` skill 嘅 11 models)
3. `apps/api` Elysia backend (auth, company, contact, quotation, deal, product, conversation)
4. `apps/web` Vite + React + Tailwind (dashboard, quotation builder, AI chat panel)
5. `packages/ai` AI agent core (tool registry, agent loop, RAG, multi-channel)
6. `cdk` deployment stack (照 `cdk-ecs-fargate-deploy` + `cdk-deployment-rules`)
7. Initial commit + push to `git@david-dev-env:freedomw1987/crm-system.git`

## Dev / Prod 環境隔離

- L2 (本機 dev): `~/www/crm-system/`
- L3 (production): 待定 (aws account 646197533509, ap-east-1, 跟 umac-ai-deploy-prod pattern)
- 測試/一次性 script 寫到 `/tmp/`, 唔好入 `~/www/crm-system/`

## Day 2 (2026-06-05) — Frontend + AI Chat 落地

### 已完成

- **apps/web scaffold**: Vite 6 + React 19 + TypeScript + Tailwind v3 (唔係 v4, 見 SKILL pitfall) + shadcn-style UI primitives (Button / Card / Badge / Dialog / Input / Textarea)
- **7 個 pages**: login (預填 admin credentials), dashboard (4 KPI + recent activity), companies (list + detail), quotations (list + AI Draft dialog + detail with AI audit), deals (3-column pipeline), AI chat (full conversation list + send/delete + tool call expand)
- **API client** (`lib/api.ts`): typed wrapper with auto-attach Bearer token, 401 → logout redirect, 兼容 wrapped/array response shape
- **Auth store** (Zustand): bootstrap 自動 verify token, login/logout flow
- **AI chat fix**: chat route 由 Elysia jwt decorator → `jose.jwtVerify` (避開 Elysia 1.2 d.ts bug)
- **Vite proxy**: `/api/*` → `localhost:3001` backend, 兩個 process 同行

### 撞牆 (已 patch 入 SKILL pitfalls)

1. **Elysia 1.2.0 d.ts**: 跨 route file 用 jwt decorator 401 fail, 改用 jose
2. **Prisma @prisma/client model names**: `import { PipelineStage }` runtime crash, 只能 re-export enums
3. **Tailwind v4 + shadcn-style 唔夾**: 顏色 fallback, 改用 v3
4. **Hermes redact**: sed 抽 token 失敗, 改 python3 inline
5. **Backend response shape 不一致**: /companies wrapped, /products array, frontend normalize

### Verifications

- `bun run dev` (Vite) → HTTP 200 on `/`
- `/api/health` (Vite proxy) → 200
- `POST /auth/login` admin@crm.local / admin123 → JWT 205 chars
- All resources (companies/products/quotations/deals/chat) → 200 with auth
- 2 products seeded, 3 companies seeded, 1 quotation seeded

### Git

- Commit `3af2bd4`: feat: Day 2 — Vite + React frontend + chat auth fix
- Pushed to `git@david-dev-env:freedomw1987/crm-system.git` main branch
- 25 new files, 1 fix (chat route)

## Day 3+ (待做)

- [ ] **Quotation builder form** — user 手動 add line items, 計 subtotal/tax/total, 加 AI assistance
- [ ] **AI agent end-to-end test** — 需要真 OPENAI_API_KEY
- [ ] **CDK infrastructure** — ECS Fargate + RDS (跟 `cdk-ecs-fargate-deploy` skill)
- [ ] **CI/CD** — GitHub Actions → ECR → ECS
- [ ] **QA Gate** — Vitest + Playwright E2E coverage
- [ ] **Production hardening** — rate limiting, CORS tightening, error monitoring
