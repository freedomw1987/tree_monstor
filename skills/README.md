# Skills Catalog

> **Status:** Catalog. Local skills index; each skill's source of truth is its own `SKILL.md`.

This catalog lists **local Tree Monstor skills** at two levels:

1. **Top-level skills** — immediate child directories of `skills/` with a `SKILL.md` file, hand-curated in the tables below.
2. **Nested skills** — `skills/<category>/<skill>/SKILL.md` entries, auto-generated into the「Nested skills by category」section by `scripts/generate_skills_catalog.py`.

Each skill’s canonical source is its own `SKILL.md`. This catalog is a navigation aid, not a replacement for reading the skill itself.

---

## Maintenance rule

When adding, removing, or renaming a local skill:

1. Top-level skill → update the hand-curated tables in the same change. Nested skill → run `python3 scripts/generate_skills_catalog.py` to regenerate the nested section（不要手改生成段）。
2. Do **not** add skill counts to `README.md`, `SOUL.md`, `MEMORY.md`, `AGENTS.md`, or `docs/00-index.md`.
3. If a count is needed for release notes or verification, compute it from `skills/**/SKILL.md` at verification time.
4. Keep descriptions short enough to scan; detailed instructions belong in each skill’s own `SKILL.md`.
5. After catalog changes, run `python3 scripts/docs_consistency_check.py` from the repository root（it verifies both levels' coverage）.

---

## Claude Code routing note

These are local Tree Monstor markdown skills. They are not automatically Claude Code slash commands unless separately registered in the active Claude Code runtime. Currently registered: `regression-guard`, `existing-project-intake`, `dev-checker-loop` — via wrappers in `adapters/claude-code/skills/` symlinked from `~/.claude/skills/`; the canonical source remains each skill's `SKILL.md` here.

In Claude Code:

1. Use this catalog to choose the matching local skill.
2. Read `skills/<name>/SKILL.md` before acting.
3. If Claude Code exposes a matching runtime slash / harness skill, prefer invoking that runtime skill and use the local skill docs as Tree Monstor-specific supplement.
4. Keep this catalog as navigation only; each `SKILL.md` remains canonical.

---

## Core orchestration / memory / resilience

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`orchestrator`](orchestrator/SKILL.md) | Coordinates subagents, task board, dependencies, progress, and failures. | Long multi-phase tasks, parallel subagent work, dependency tracking. |
| [`dev-checker-loop`](dev-checker-loop/SKILL.md) | Dev-agent / checker-agent collaboration loop coordinated through a downstream project's `<project>/docs/STATE.md`, with evidence-based verification and escalation limits. | Multi-item development needing a built-in quality gate; "dev-loop" / checker-agent requests. |
| [`context-summarizer`](context-summarizer/SKILL.md) | Compresses long-task context into `docs/context-summary.md`. | Context pressure, resume preparation, long sessions, loop detection. |
| [`dev-task-memory`](dev-task-memory/SKILL.md) | Persistent memory for in-progress dev tasks across compression, `/new`, and restarts. | Long implementation tasks that must survive interruption. |
| [`interruption-recovery`](interruption-recovery/SKILL.md) | Interruption and recovery mechanism layered on top of dev-task-memory. | Crash / interruption / gateway restart recovery. |

---

## Documentation / QA / project hygiene

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`auto-doc-gen`](auto-doc-gen/SKILL.md) | Generates API docs from code comments/docstrings and keeps docs aligned with code. | API/doc generation or docs drift cleanup. |
| [`doc-html-preview`](doc-html-preview/SKILL.md) | Syncs `docs/*.md` into standalone HTML previews for engineering and decision review. | After docs updates that need David/user confirmation. |
| [`docs-sync`](docs-sync/SKILL.md) | Synchronizes review feedback, QA findings, and code-review suggestions into durable project docs. | After Review/Test/QA/user feedback changes requirements, design, API, architecture, tests, regression behavior, or tech debt. |
| [`existing-project-intake`](existing-project-intake/SKILL.md) | Intake workflow for existing projects before continuing development. | Existing/inherited projects with incomplete docs, unknown current state, or missing QA/regression hooks. |
| [`regression-guard`](regression-guard/SKILL.md) | Records regression guards for bug fixes. | Every bug fix or regression-prone change. |
| [`structural-doc-batch`](structural-doc-batch/SKILL.md) | Batch documentation organization and structural cleanup. | Large documentation cleanup or re-indexing work. |
| [`tech-debt-register`](tech-debt-register/SKILL.md) | Tracks technical debt with priority, cost, and business impact. | Known debt, refactor tradeoffs, deferred cleanup. |
| [`patch-corruption-recovery`](patch-corruption-recovery/SKILL.md) | Recovers from corrupted patch/edit states by restoring and re-patching cleanly. | Syntax corruption, mismatched braces, broken patch attempts. |
| [`mac-apfs-case-insensitive-git-tracking`](mac-apfs-case-insensitive-git-tracking/SKILL.md) | Handles macOS APFS case-insensitive Git path/casing issues. | File casing drift between macOS dev host and Linux/container runtime. |

---

## Frontend / React / Vite / UI

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`ai-image-display-handling`](ai-image-display-handling/SKILL.md) | Handles AI-generated images arriving as base64/data URLs in text fields. | Generated images do not appear in chat/UI despite model response data. |
| [`chat-frontend-backend-debug`](chat-frontend-backend-debug/SKILL.md) | Debugs chat UI/API mismatch, missing dispatch, React state, and mobile layout issues. | WhatsApp-style chat UI does not respond or render correctly. |
| [`debug-ai-image-generation`](debug-ai-image-generation/SKILL.md) | Finds the correct image data path in OpenRouter/Gemini SSE responses. | AI image generation succeeds but display path is unknown/wrong. |
| [`multimodal-image-chat`](multimodal-image-chat/SKILL.md) | Builds chat frontends with image attachment/base64 support for multimodal LLM APIs. | Adding image upload or multimodal chat support. |
| [`react-browser-automation-gotchas`](react-browser-automation-gotchas/SKILL.md) | Debugs React synthetic-event/state issues during browser automation. | Browser clicks/fills do not trigger React state updates. |
| [`react-router-sibling-route-conflict`](react-router-sibling-route-conflict/SKILL.md) | Diagnoses sibling route shadowing in React Router v6/v7. | `/settings` vs `/settings/*`-style route conflicts. |
| [`react-router-tab-subroute-refactor`](react-router-tab-subroute-refactor/SKILL.md) | Refactors top-level pages into shared tabbed subroutes. | Consolidating page clusters into tab navigation. |
| [`tailwindcss-typography-v4-vite-plugin`](tailwindcss-typography-v4-vite-plugin/SKILL.md) | Fixes Tailwind CSS v4 + Vite typography plugin issues. | `@tailwindcss/typography` styles are not applying. |
| [`vite-spa-nginx-deployment`](vite-spa-nginx-deployment/SKILL.md) | Deploys Vite React SPA behind nginx with SPA routing and permissions. | Static Vite SPA deployment / nginx route fallback. |
| [`vite-static-asset-proxy-debug`](vite-static-asset-proxy-debug/SKILL.md) | Debugs Vite dev server static asset proxy issues. | Assets work in production but return HTML or fail locally. |

---

## Backend / database / API

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`bun-env-file-for-dev`](bun-env-file-for-dev/SKILL.md) | Documents Bun dev server `.env` loading via `--env-file` and AWS env pitfalls. | Bun dev server cannot see `.env` / AWS SDK region variables. |
| [`elysia-nginx-500-debug`](elysia-nginx-500-debug/SKILL.md) | Debugs intermittent HTTP 500 from Elysia.js behind nginx. | Elysia/Bun backend fails through nginx proxy. |
| [`elysia-typescript-workarounds`](elysia-typescript-workarounds/SKILL.md) | Handles common Elysia TypeScript route/context typing issues. | Route param conflicts, derive typing, recursive schemas, typed handlers. |
| [`prisma-add-column-existing-db`](prisma-add-column-existing-db/SKILL.md) | Adds columns to existing Prisma production DBs safely. | Cannot use `prisma migrate reset`; production data exists. |
| [`prisma-circular-relation-debug`](prisma-circular-relation-debug/SKILL.md) | Debugs Prisma circular relation/schema cycle errors. | Relation cycle errors such as User/ChatSession/ChatMessage. |
| [`prisma-migrate-private-rds`](prisma-migrate-private-rds/SKILL.md) | Runs Prisma migrations on private RDS via ECS one-off tasks. | CI/CodeBuild cannot directly reach private RDS. |

---

## DevOps / infrastructure / deployment

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`cdk-v2-deployment-patterns`](cdk-v2-deployment-patterns/SKILL.md) | AWS CDK v2 deployment patterns and common setup issues. | Setting up or debugging CDK v2 infrastructure. |
| [`cloudflare-named-tunnel-route53`](cloudflare-named-tunnel-route53/SKILL.md) | Creates stable HTTPS test URLs with Cloudflare Named Tunnel + Route53. | Need HTTPS access to NAT/private/non-public test instances. |
| [`docker-mac-arm64-elysia-vite`](docker-mac-arm64-elysia-vite/SKILL.md) | Docker pitfalls for Mac ARM64 + Elysia/Bun + Vite projects. | Native bindings, package-lock, libssl, healthcheck, nginx proxy issues. |

---

## Domain / integrations / specialized workflows

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`llm-acp-discord`](llm-acp-discord/SKILL.md) | Discord-based LLM-ACP quiz practice flow. | David uses Discord `acp` quiz workflow. |
| [`yuanbao`](yuanbao/SKILL.md) | Yuanbao groups: @mention users, query info/members. | Yuanbao group/member operations. |

---

<!-- BEGIN GENERATED: nested-skills-catalog (scripts/generate_skills_catalog.py) -->

## Nested skills by category（自動生成）

> 本段由 `scripts/generate_skills_catalog.py` 生成，**不要手改**；新增 / 刪除嵌套技能後重跑該腳本。每個技能的 canonical source 仍是其 `SKILL.md`。

### `apple/`

Apple/macOS-specific skills — iMessage, Reminders, Notes, FindMy, and macOS automation. These skills only load on macOS systems.

| Skill | Description |
|-------|-------------|
| [`macos-computer-use`](apple/macos-computer-use/SKILL.md) | Drive the macOS desktop in the background — screenshots, mouse, keyboard, scroll, drag — without stealing the user's cursor, keyboard focus, or Space. Works wi… |

### `autonomous-ai-agents/`

Skills for spawning and orchestrating autonomous AI coding agents and multi-agent workflows — running independent agent processes, delegating tasks, and coordinating parallel workstreams.

| Skill | Description |
|-------|-------------|
| [`agent-stuck-recovery`](autonomous-ai-agents/agent-stuck-recovery/SKILL.md) | Recover when the main agent is stuck mid-task. Search or read_file loops expanding without progress, response is explanation-only, or user sends "stop" / singl… |
| [`ultrawork`](autonomous-ai-agents/ultrawork/SKILL.md) | Enable Claude Code harness mode — use Workflow/parallel/pipeline for complex multi-agent tasks. Spawns concurrent subagents, handles fan-out/fan-in patterns, a… |

### `backend/`

| Skill | Description |
|-------|-------------|
| [`ai-agent-tool-calling`](backend/ai-agent-tool-calling/SKILL.md) | Build a tool-calling AI agent (function calling + tool registry + conversation memory + RAG over app data) for any product — CRM, support, internal tools. Use… |
| [`assignment-quiz-work-submission`](backend/assignment-quiz-work-submission/SKILL.md) | Student assignment (作品題) upload + teacher download flow for UMAC AI — S3 presigned URLs, answers JSON storage, filename metadata pattern, nullable score |
| [`backend-rbac-audit-log`](backend/backend-rbac-audit-log/SKILL.md) | Add role-based access control (RBAC) + audit log to any backend API (Elysia, Express, Fastify, Hono, NestJS). Pattern: centralized permission map in shared pac… |
| [`crm-data-model`](backend/crm-data-model/SKILL.md) | Design a modern CRM data model (HubSpot / Pipedrive inspired) — Company, Contact, Product, Quotation, Deal, Pipeline, ActivityLog, Tag, Conversation. Use when… |
| [`elysia-file-upload-multer`](backend/elysia-file-upload-multer/SKILL.md) | Add file upload to Elysia.js (Bun) backend — hand-rolled multipart parser (RECOMMENDED for Elysia 1.2) OR Multer with static file serving. Use when the user sa… |
| [`elysia-llm-graceful-fallback`](backend/elysia-llm-graceful-fallback/SKILL.md) | Elysia.js route pattern for graceful LLM/API fallback — return result objects instead of throwing, letting route handlers decide HTTP status and format. |
| [`polymorphic-line-items`](backend/polymorphic-line-items/SKILL.md) | Design and implement polymorphic line items in a sales/quoting system — single parent (Quotation/Invoice) with mixed child item types (Product vs Service with… |

### `creative/`

Creative content generation — ASCII art, hand-drawn style diagrams, and visual design tools.

| Skill | Description |
|-------|-------------|
| [`architecture-diagram`](creative/architecture-diagram/SKILL.md) | Dark-themed SVG architecture/cloud/infra diagrams as HTML. |
| [`baoyu-article-illustrator`](creative/baoyu-article-illustrator/SKILL.md) | Article illustrations: type × style × palette consistency. |
| [`baoyu-comic`](creative/baoyu-comic/SKILL.md) | Knowledge comics (知识漫画): educational, biography, tutorial. |
| [`baoyu-infographic`](creative/baoyu-infographic/SKILL.md) | Infographics: 21 layouts x 21 styles (信息图, 可视化). |
| [`claude-design`](creative/claude-design/SKILL.md) | Design one-off HTML artifacts (landing, deck, prototype). |
| [`comfyui`](creative/comfyui/SKILL.md) | Generate images, video, and audio with ComfyUI — install, launch, manage nodes/models, run workflows with parameter injection. Uses the official comfy-cli for… |
| [`design-md`](creative/design-md/SKILL.md) | Author/validate/export Google's DESIGN.md token spec files. |
| [`humanizer`](creative/humanizer/SKILL.md) | Humanize text: strip AI-isms and add real voice. |
| [`pixel-art`](creative/pixel-art/SKILL.md) | Pixel art w/ era palettes (NES, Game Boy, PICO-8). |
| [`pixel-art-preview-workflow`](creative/pixel-art-preview-workflow/SKILL.md) | Generate pixel art characters using Python PIL and preview via Discord. Use when creating game-like visualizations, character sprites, or any pixel art that ne… |
| [`pretext`](creative/pretext/SKILL.md) | Use when building creative browser demos with @chenglou/pretext — DOM-free text layout for ASCII art, typographic flow around obstacles, text-as-geometry games… |
| [`sketch`](creative/sketch/SKILL.md) | Throwaway HTML mockups: 2-3 design variants to compare. |
| [`touchdesigner-mcp`](creative/touchdesigner-mcp/SKILL.md) | Control a running TouchDesigner instance via twozero MCP — create operators, set parameters, wire connections, execute Python, build real-time visuals. 36 nati… |

### `debugging/`

| Skill | Description |
|-------|-------------|
| [`api-download-401-pdf-body`](debugging/api-download-401-pdf-body/SKILL.md) | Debug why file downloads via fetch+blob return HTML/incorrect content instead of the actual file — specific pattern where auth middleware on a download endpoin… |
| [`chatbot-file-attachment-debug`](debugging/chatbot-file-attachment-debug/SKILL.md) | Debug and fix WhatsApp-style AI chatbot where PDF attachments show as broken image icons instead of file icons. Multi-layer fix across frontend, backend schema… |
| [`cloudfront-apigateway-s3-debug`](debugging/cloudfront-apigateway-s3-debug/SKILL.md) | Debug CloudFront returning S3 HTML instead of API Gateway responses for /api/* routes. CloudFront misroutes API calls to S3 static content. |
| [`docker-port-forward-shadow-debug`](debugging/docker-port-forward-shadow-debug/SKILL.md) | Diagnose when Docker containers shadow host services on well-known ports (80/443), causing reverse-proxy traffic to be intercepted by the wrong process. |
| [`elysia-jwt-plugin-singleton`](debugging/elysia-jwt-plugin-singleton/SKILL.md) | Fix "401 Unauthorized" in Elysia.js when JWT tokens signed by auth routes are rejected by protected routes — caused by multiple JWT plugin instances. |
| [`elysia-lambda-response-body-debug`](debugging/elysia-lambda-response-body-debug/SKILL.md) | Debug and fix empty response body when deploying Elysia.js to AWS Lambda |
| [`elysia-route-conflict-debug`](debugging/elysia-route-conflict-debug/SKILL.md) | Debug Elysia.js route conflicts — server fails to start with "different parameter name" error, or requests hit wrong handler. |
| [`patch-route-field-silently-dropped`](debugging/patch-route-field-silently-dropped/SKILL.md) | Diagnose HTTP routes where a field appears to save but disappears after refresh, OR the request returns 502/500 because a Prisma relation key is silently strip… |
| [`pdf-parse-v2-bun-fix`](debugging/pdf-parse-v2-bun-fix/SKILL.md) | Fix pdf-parse v2 "not a function" error in Bun — breaking API change from v1 |
| [`prisma-json-field-api-serialization`](debugging/prisma-json-field-api-serialization/SKILL.md) | Fix runtime errors caused by Prisma field types that serialize as strings over REST (Json / Decimal / BigInt / Date / Bytes) instead of their JS-typed equivale… |
| [`prisma-relation-debugging`](debugging/prisma-relation-debugging/SKILL.md) | Debug Prisma schema vs code mismatches: explicit @relation fields need { connect: { id } } syntax, not shorthand. Also covers the UncheckedCreateInput vs Creat… |
| [`prisma-sqlite-bun-setup`](debugging/prisma-sqlite-bun-setup/SKILL.md) | Prisma schema 適配 SQLite 的正確方式 — enum 改 string、Json 改 String、Prisma 5 vs 7 差異、seed 注意事項、Bun 生態環境的常見坑。也涵蓋 Prisma 7 strict validation 嘅 generic pitfalls (適用於 SQLi… |
| [`sse-chunk-boundary-debug`](debugging/sse-chunk-boundary-debug/SKILL.md) | Diagnose and fix SSE JSON parse errors caused by HTTP chunked transfer encoding splitting SSE lines mid-JSON |
| [`visual-ui-bug-debugging`](debugging/visual-ui-bug-debugging/SKILL.md) | Debug visual UI bugs where user reports something doesn't work but API/terminal checks pass. Use browser + vision analysis instead of just terminal tools. |
| [`vite-nginx-stale-cache-debug`](debugging/vite-nginx-stale-cache-debug/SKILL.md) | Debug why Vite React app changes are not reflected after rebuild - Nginx serving stale cached JS. Key signal is immutable cache headers and JS file content unc… |
| [`whatsapp-chatbot-debug`](debugging/whatsapp-chatbot-debug/SKILL.md) | Debug image generation in the WhatsApp-style chatbot where AI-generated images don't appear in the browser even though the backend SSE stream is correct. |

### `devops/`

| Skill | Description |
|-------|-------------|
| [`aws-codecommit-git-setup`](devops/aws-codecommit-git-setup/SKILL.md) | AWS CodeCommit SSH 設定與常見錯誤排除 |
| [`aws-ses-email-setup-route53`](devops/aws-ses-email-setup-route53/SKILL.md) | Set up AWS SES for transactional email — verify domain with DKIM, add Route53 DNS records, configure credentials for SDK use |
| [`bun-elysia-react-vite-stack`](devops/bun-elysia-react-vite-stack/SKILL.md) | Bootstrap a local full-stack TypeScript app with Bun 1.2 + Elysia backend + Vite 8 + React 19 + Tailwind v4. SQLite (dev) + Postgres (prod recommended) via Pri… |
| [`bun-frontend-deploy-sudo-path`](devops/bun-frontend-deploy-sudo-path/SKILL.md) | Bun frontend build + sudo deploy path resolution issue |
| [`caddy-spa-api-proxy-deploy`](devops/caddy-spa-api-proxy-deploy/SKILL.md) | Deploy Vite SPA + Bun API backend behind Caddy reverse proxy in Docker with host networking |
| [`cdk-deployment-rules`](devops/cdk-deployment-rules/SKILL.md) | AWS CDK 部署規則 — 只對 CDK 修改，嚴禁 CLI 手動建立生產資源。所有資源必須由 CDK 管理。 |
| [`cdk-ecs-fargate-deploy`](devops/cdk-ecs-fargate-deploy/SKILL.md) | CDK v2 ECS Fargate deployment pattern — single consolidated stack to avoid circular dependencies between Route53, ALB, ECS, and RDS |
| [`cdk-ecs-rollback-cleanup`](devops/cdk-ecs-rollback-cleanup/SKILL.md) | CDK ECS Fargate stack rollback cleanup when BackendSg deletion fails with DependencyViolation |
| [`cdk-ecs-stacked-environment-isolation`](devops/cdk-ecs-stacked-environment-isolation/SKILL.md) | CDK ECS Fargate 部署時保護開發環境的注意事項 — CDK rollback 會把現有服務的 desiredCount 重置為 0，導致服務中斷。 |
| [`cdk-route53-apigateway-alias`](devops/cdk-route53-apigateway-alias/SKILL.md) | CDK v2 Route53 ARecord alias to API Gateway custom domain — workaround for missing IAliasRecordTarget bind() method |
| [`cloudflare-tunnel-vite-dev`](devops/cloudflare-tunnel-vite-dev/SKILL.md) | Workaround for Vite dev server HMR WebSocket 403 errors when using Cloudflare Tunnel |
| [`cross-role-subagent`](devops/cross-role-subagent/SKILL.md) | QA Feedback Loop — 持續循環直至 QA 通過，用戶只看到最終好結果。 |
| [`dependency-cve-audit`](devops/dependency-cve-audit/SKILL.md) | Audit project dependencies for known CVEs — fulfills 紅線 18 (Critical/High CVE must be 0 to merge). Class-level skill that covers BOTH npm + bun projects, lockf… |
| [`docker-build-cache-debug`](devops/docker-build-cache-debug/SKILL.md) | Docker build cache causes stale code to run in containers despite source changes |
| [`docker-caddy-elysia-deploy`](devops/docker-caddy-elysia-deploy/SKILL.md) | Docker + Caddy reverse proxy + Elysia.js (Bun) SPA 部署攻略 |
| [`docker-multi-stage-dist-overwrite`](devops/docker-multi-stage-dist-overwrite/SKILL.md) | Fix Docker multi-stage build where COPY . . overwrites fresh dist/ with stale host files due to missing .dockerignore |
| [`docker-multiarch-customer-image-release`](devops/docker-multiarch-customer-image-release/SKILL.md) | Build Docker images for shipping to customer servers (no source code, multi-arch amd64+arm64, tarball + load + install.sh workflow) |
| [`docker-multiarch-offline-handoff`](devops/docker-multiarch-offline-handoff/SKILL.md) | Build multi-arch (linux/amd64 + linux/arm64) Docker images and hand them to a customer as tarball(s) without a registry. Use when the user needs x86+arm suppor… |
| [`ecs-health-check-debug`](devops/ecs-health-check-debug/SKILL.md) | Debug ECS Fargate CDK deployment failures due to health check curl not found in Docker image |
| [`elysia-aws-lambda-deploy`](devops/elysia-aws-lambda-deploy/SKILL.md) | Deploy Elysia.js (Bun-first framework) to AWS Lambda Node.js runtime — bundler config, handler resolution, CDK runtime mismatches, crypto polyfill, API Gateway… |
| [`kanban-orchestrator`](devops/kanban-orchestrator/SKILL.md) | Decomposition playbook + anti-temptation rules for an orchestrator profile routing work through Kanban. The "don't do the work yourself" rule and the basic lif… |
| [`kanban-worker`](devops/kanban-worker/SKILL.md) | Pitfalls, examples, and edge cases for Hermes Kanban workers. The lifecycle itself is auto-injected into every worker's system prompt as KANBAN_GUIDANCE (from… |
| [`nginx-sse-streaming-fix`](devops/nginx-sse-streaming-fix/SKILL.md) | Fix nginx reverse proxy buffering SSE responses so streaming works correctly |
| [`node-static-proxy-cloudflare`](devops/node-static-proxy-cloudflare/SKILL.md) | Start a Node.js static+proxy server and Cloudflare tunnel in the correct sequence with proper process management |
| [`patch-replace-all-pitfalls`](devops/patch-replace-all-pitfalls/SKILL.md) | Avoid syntax errors when using patch replace_all on source code — regex token replacement can corrupt parentheses and expressions. |
| [`pm-system-deployment`](devops/pm-system-deployment/SKILL.md) | PM System deployment and development guide |
| [`prisma-seed-reset-pattern`](devops/prisma-seed-reset-pattern/SKILL.md) | Prisma seed 一定要每次重設 role 關聯，否則 AdminPanel 自訂角色會失效 |
| [`route53-nginx-https`](devops/route53-nginx-https/SKILL.md) | 使用 AWS Route53 + nginx + Let's Encrypt 為測試網域建立穩定 HTTPS URL。適用於需要在 AWS 管理的網域上對外暴露測試服務，取代 Cloudflare Tunnel。 |
| [`umac-ai-deploy-prod`](devops/umac-ai-deploy-prod/SKILL.md) | UMAC AI 生產部署 SOP — backend + frontend + CDK + ECS 全流程 |
| [`umac-ai-ecs-migration`](devops/umac-ai-ecs-migration/SKILL.md) | 在 UMAC AI production RDS 無法從本地直接訪問時，用 ECS run-task 執行 Prisma migration 的流程 |

### `frontend/`

| Skill | Description |
|-------|-------------|
| [`ai-assistant-streaming-rendering`](frontend/ai-assistant-streaming-rendering/SKILL.md) | When building a chat / AI assistant UI that streams tokens from an LLM, render the reply with full Markdown + chart.js + data-fence support, and treat the agen… |
| [`ios-safari-scroll-fixed-elements`](frontend/ios-safari-scroll-fixed-elements/SKILL.md) | Fix iOS Safari scrolling issues for elements using position:fixed inside overflow:hidden bodies. For React apps where a page (Login, Settings, etc.) uses a fix… |
| [`list-search-box`](frontend/list-search-box/SKILL.md) | Add a search box to an existing React list page — client-side filter on the visible page (no server roundtrip). Covers the two-layer empty state (raw empty vs… |
| [`mobile-chat-layout-css`](frontend/mobile-chat-layout-css/SKILL.md) | Fix WhatsApp-style mobile chat layout with fixed input bar — missing CSS classes and padding issues |
| [`quiz-attempt-result-display`](frontend/quiz-attempt-result-display/SKILL.md) | Teacher quiz/assignment results page — score null display, fileName parsing, CSV export, download button logic. UMAC AI project. |
| [`react-context-auth-user-switch`](frontend/react-context-auth-user-switch/SKILL.md) | Detect user login/logout within same tab using React Context + localStorage — fixes stale user data when switching accounts without full page reload |
| [`react-html5-drag-drop-pitfalls`](frontend/react-html5-drag-drop-pitfalls/SKILL.md) | Build correct HTML5 drag-and-drop in React (Kanban, sortable lists, file drop zones). Covers the most common silent-failure mode — forgetting `e.dataTransfer.s… |
| [`react-quiz-form-state-debug`](frontend/react-quiz-form-state-debug/SKILL.md) | Debug React quiz forms where submit button stays disabled for mixed question types (choice/text/assignment) |
| [`react-router-v7-params-debug`](frontend/react-router-v7-params-debug/SKILL.md) | Debug route params not being passed in react-router-dom v7 components |
| [`react-router-v7-patterns`](frontend/react-router-v7-patterns/SKILL.md) | React Router v7 patterns and pitfalls for nested-route SPA refactors. Class-level lessons from 2026-06-07 crm-system Day 14.7 (Settings tabs): URL as source of… |
| [`related-entity-entry-points`](frontend/related-entity-entry-points/SKILL.md) | Build the full UI flow that lets users navigate from a parent entity (Company, Deal, Order, Project) to a child entity (Deal, Quotation, LineItem, Task) and cr… |
| [`rwd-mobile-audit`](frontend/rwd-mobile-audit/SKILL.md) | Audit and fix a web app for mobile RWD (responsive web design) using Playwright at iPhone viewport (390x844). Use when user says 'RWD', '手機兼容', 'mobile compati… |
| [`tailwindcss-v4-plugin-typography`](frontend/tailwindcss-v4-plugin-typography/SKILL.md) | Fix Tailwind CSS v4 plugin registration for @tailwindcss/typography and prose classes |
| [`whatsapp-chatbot-landing-page`](frontend/whatsapp-chatbot-landing-page/SKILL.md) | WhatsApp-style landing page for empty state — model selector, auto-create conversation and send first message, jump to chat |

### `general/`

| Skill | Description |
|-------|-------------|
| [`client-api-wire-shape-verification`](general/client-api-wire-shape-verification/SKILL.md) | Verify client-side API wrapper shapes (TypeScript request types, request bodies, response parsing) against the BACKEND SOURCE before committing — not against p… |
| [`feature-plan-alignment`](general/feature-plan-alignment/SKILL.md) | Plan-stage alignment workflow for non-trivial feature work where David wants to review direction BEFORE code is written. Produces a structured plan doc (MD + b… |
| [`subagent-timeout-recovery`](general/subagent-timeout-recovery/SKILL.md) | 1) Subagent 執行超時後嘅接管流程 (搶救 partial outputs 而唔係重新 delegation)。 2) Subagent 準時 return `completed` 之後 parent 必須做嘅 trust-but-verify 步驟 (subagent summary 係 self-rep… |

### `media/`

Skills for working with media content — YouTube transcripts, GIF search, music generation, and audio visualization.

| Skill | Description |
|-------|-------------|
| [`spotify`](media/spotify/SKILL.md) | Spotify: play, search, queue, manage playlists and devices. |

### `productivity/`

Skills for document creation, presentations, spreadsheets, and other productivity workflows.

| Skill | Description |
|-------|-------------|
| [`airtable`](productivity/airtable/SKILL.md) | Airtable REST API via curl. Records CRUD, filters, upserts. |
| [`maps`](productivity/maps/SKILL.md) | Geocode, POIs, routes, timezones via OpenStreetMap/OSRM. |
| [`teams-meeting-pipeline`](productivity/teams-meeting-pipeline/SKILL.md) | Operate the Teams meeting summary pipeline via Hermes CLI — summarize meetings, inspect pipeline status, replay jobs, manage Microsoft Graph subscriptions. |

### `social-media/`

Skills for interacting with social platforms and social-media workflows — posting, reading, monitoring, and account operations.

| Skill | Description |
|-------|-------------|
| [`xurl`](social-media/xurl/SKILL.md) | X/Twitter via xurl CLI: post, search, DM, media, v2 API. |

### `software-development/`

| Skill | Description |
|-------|-------------|
| [`code-review-pipeline`](software-development/code-review-pipeline/SKILL.md) | Three-axis code review → TECH-DEBT.md catalog → P0 patch sprint → evidence retro → merge pipeline. Use when user asks for "code review", "security audit", "arc… |
| [`debugging-hermes-tui-commands`](software-development/debugging-hermes-tui-commands/SKILL.md) | Debug Hermes TUI slash commands: Python, gateway, Ink UI. |
| [`frontend-backend-integration`](software-development/frontend-backend-integration/SKILL.md) | Discipline for writing frontend code that wraps backend endpoints — verify wire shape against backend source (not plan/spec doc), handle prefill races, refacto… |
| [`hermes-agent-skill-authoring`](software-development/hermes-agent-skill-authoring/SKILL.md) | Author in-repo SKILL.md: frontmatter, validator, structure. |
| [`hermes-s6-container-supervision`](software-development/hermes-s6-container-supervision/SKILL.md) | Modify, debug, or extend the s6-overlay supervision tree inside the Hermes Agent Docker image — adding new services, debugging profile gateways, understanding… |
| [`node-inspect-debugger`](software-development/node-inspect-debugger/SKILL.md) | Debug Node.js via --inspect + Chrome DevTools Protocol CLI. |
| [`pagination-with-preserved-aggregates`](software-development/pagination-with-preserved-aggregates/SKILL.md) | Add server-side pagination to an admin list page WITHOUT breaking summary stats (count/sum/avg) or full-dataset exports (Excel/CSV). The core invariant — stats… |
| [`python-debugpy`](software-development/python-debugpy/SKILL.md) | Debug Python: pdb REPL + debugpy remote (DAP). |
| [`qa-tracker-us-closure`](software-development/qa-tracker-us-closure/SKILL.md) | Per-US test closure cadence for closing out NONE/PARTIAL P0 user stories in a project's QA-TRACKER.md. Class-level, applies to any project that uses the US ↔ T… |
| [`spike`](software-development/spike/SKILL.md) | Throwaway experiments to validate an idea before build. |

### `testing/`

| Skill | Description |
|-------|-------------|
| [`playwright-e2e-design-patterns`](testing/playwright-e2e-design-patterns/SKILL.md) | E2E test design patterns for Playwright + full-stack (Docker) apps — caller IP isolation vs backend rate limit (RG-008/RG-012 invariant), per-test setup hooks,… |
| [`playwright-node-api-container`](testing/playwright-node-api-container/SKILL.md) | 使用 Node.js Playwright API 在 container/VM 環境中截圖和自動化測試。 適用於需要登入後才能截圖的頁面（CLI screenshot 無法做到）。 |
| [`unit-test-coverage-push`](testing/unit-test-coverage-push/SKILL.md) | Systematically add unit test coverage to a project's P0 US with NONE/PARTIAL/PASS-E2E-only test status. Trigger when user says "test 未做的都要做", "補 unit test", "P… |

<!-- END GENERATED: nested-skills-catalog -->

---

## Related docs

- [Documentation index](../docs/00-index.md)
- [README](../README.md)
- [Core identity](../SOUL.md)
- [Cross-platform usage](../docs/cross-platform-usage.md)
