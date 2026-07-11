# Skills Catalog

> **Status:** Catalog. Local skills index; each skill's source of truth is its own `SKILL.md`.

This catalog lists **local Tree Monstor skills** stored as immediate child directories of `skills/` with a `SKILL.md` file.

Each skill’s canonical source is its own `skills/<name>/SKILL.md`. This catalog is a navigation aid, not a replacement for reading the skill itself.

---

## Maintenance rule

When adding, removing, or renaming a local skill:

1. Update this catalog in the same change.
2. Do **not** add skill counts to `README.md`, `SOUL.md`, `MEMORY.md`, `AGENTS.md`, or `docs/00-index.md`.
3. If a count is needed for release notes or verification, compute it from `skills/*/SKILL.md` at verification time.
4. Keep descriptions short enough to scan; detailed instructions belong in each skill’s own `SKILL.md`.
5. After catalog changes, run `python3 scripts/docs_consistency_check.py` from the repository root.

---

## Claude Code routing note

These are local Tree Monstor markdown skills. They are not automatically Claude Code slash commands unless separately registered in the active Claude Code runtime.

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

## Bundled / external manifest note

`skills/.bundled_manifest` may list bundled or external entries available in other environments. It is **not** the canonical catalog for this profile’s immediate local skills. For local Tree Monstor skills, use this file plus `skills/<name>/SKILL.md`.

---

## Related docs

- [Documentation index](../docs/00-index.md)
- [README](../README.md)
- [Core identity](../SOUL.md)
- [Cross-platform usage](../docs/cross-platform-usage.md)
