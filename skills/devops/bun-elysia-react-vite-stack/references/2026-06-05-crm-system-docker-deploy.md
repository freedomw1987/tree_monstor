# 2026-06-05 — crm-system Day 3 (Docker pivot)

## Session 摘要

承接 Day 1-2 scaffold session, Day 3 原本 plan 係用 CDK (跟 `cdk-ecs-fargate-deploy`)。**用戶中途 pivot**: "另外我不想用CDK, 因為這個系統是本地部署的,您給我計劃用docker 就可以了"。改用 Docker Compose 取代 CDK。

## 用戶關鍵偏好 (要 encoded 入 SKILL)

**David 對 deployment 嘅偏好**: 系統係本地部署 (NAS / NUC / 內部 server) → Docker Compose, 唔好 default CDK/IaC。

呢個係 workflow / approach 偏好, **已經 patch 入 `bun-elysia-react-vite-stack` SKILL.md 嘅「部署目標」section**。下次 Plan 階段要主動問用戶要 deploy 喺邊, 唔好假設。

## Day 3 實際做咗

- `docker-compose.yml` (base): postgres + api (Bun) + web (nginx) + opt-in adminer (`--profile with-adminer`)
- `docker-compose.prod.yml` override: stricter restart, no adminer, `docker compose -f ... -f ... up -d --build`
- `apps/api/Dockerfile`: multi-stage oven/bun:1.2, libssl install for Prisma, dumb-init for signal handling
- `apps/api/docker-entrypoint.sh`: 自動 `prisma migrate deploy`, opt-in `SEED_DB=true` 觸發 seed
- `apps/web/Dockerfile`: Vite build → nginx 1.27-alpine
- `apps/web/nginx.conf`: SPA + /api reverse proxy (見 `docker-mac-arm64-elysia-vite` skill 嘅 Pitfall 7-8)
- `scripts/docker-dev.sh` (one-shot launcher) + `scripts/docker-reset.sh` (safe reset)
- README.md 重寫做 full Docker deployment guide

## 沿途撞牆 (全部已 patch 入 `docker-mac-arm64-elysia-vite` skill)

1. **`bun build --minify` 撞 Elysia 1.2 runtime codegen** → `ReferenceError: vn is not defined`. **不要 bun build**, 直接 COPY source + `bun run apps/api/src/index.ts` 啟動. (Pitfall 7)
2. **`--external @prisma/client` flag 撞 bundled output 引用 `client` symbol 不存在** → `ReferenceError: client is not defined`. 同上 workaround. (Pitfall 7)
3. **`USER bun` + entrypoint file permission 衝突** → `cannot open /usr/local/bin/entrypoint: Permission denied`. Local deploy 直接 root 行, comment for hardening. (Pitfall 8)
4. **nginx SPA fallback rewrite cycle** → `try_files $uri $uri/ /index.html` 喺 `location /` 入面 cycle. 改用 named `@spa` location. (skill section 「Frontend nginx + Elysia reverse proxy」)
5. **Web build script `tsc -b --skipLibCheck` flag conflict** → 改 `tsc --noEmit --skipLibCheck`
6. **Web tsconfig 缺 `esModuleInterop`** → 影響 `vite.config.ts` 嘅 `import path from 'node:path'`. 加 `esModuleInterop: true, allowSyntheticDefaultImports: true`
7. **Prisma client 喺 Bun workspaces hoist 落 root `/app/node_modules`**, Dockerfile 唔好指 `packages/db/node_modules/.prisma`, 改指 `node_modules/.prisma`

## 最終 Dockerfile 嘅決定

**`--minify` + `--external @prisma/client` 兩個 flag 全部唔用**。直接 COPY source + bun runtime 處理 TS。Image 大 200MB, cold start 慢少少, 但係 Elysia 1.2.x 唯一穩陣 path。**全部 pitfall 都入咗 `docker-mac-arm64-elysia-vite` skill 嘅 Pitfall 7**。

## Verification 結果

- `docker compose build`: 兩個 image 成功
- `docker compose up -d`: 3 個 container healthy
- `curl http://localhost/api/health` → 200 (`{"status":"ok","db":"connected"}`)
- `curl http://localhost/health` → 200 (nginx)
- `curl http://localhost/` → 200 (index.html 532 bytes)
- `curl http://localhost/dashboard` → 200 (SPA fallback)
- Python `urllib` 一次性 login + list companies → 3 個 seeded company OK
- `SEED_DB=true` first-run → 自動 seed admin/sales

## Git

- Commit `5d3a94b`: feat: Day 3 — Docker Compose stack for local deployment
- 13 new files, 2 small fixes (web build script + tsconfig)
- Pushed to `git@david-dev-env:freedomw1987/crm-system.git` main

## 改咗嘅 User Profile (要記)

- David 唔鍾意 CDK/IaC 喺本地部署 project, 偏好 Docker Compose
- 部署目標偏好要喺 Plan 階段 (Think) 主動問, 唔好 default 推 IaC

## 待做 (Day 4+)

- [ ] **Quotation builder form** — user 手動 add line items, 計 subtotal/tax/total, 加 AI assistance
- [ ] **AI agent end-to-end test** — 需要真 OPENAI_API_KEY 喺 `.env`
- [ ] **Playwright E2E test** — 視乎需要
- [ ] **Backup/restore script** — `pg_dump` cron + 簡單 restore command
- [ ] **HTTPS** — 如果要 expose 出去, 需要 Caddy / nginx + certbot
