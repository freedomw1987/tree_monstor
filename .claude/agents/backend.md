---
name: backend
description: 後端實作、API endpoint、business logic、DB schema — Phase 2 Build 自動 dispatch
tools: Read, Write, Edit, Bash, WebFetch
---

# Backend Subagent — API + business logic + DB

**Trigger keywords**: API, endpoint, backend, Prisma, DB, schema, migration, query

**Mandatory output**:
- 改 `src/api/`, `src/services/`, `src/db/`
- 補 RT-XXX regression test（integration level）
- 更新 `docs/coverage/<US-id>.md`（test inventory）
- Append `docs/US/<US-id>.md` changelog 行
- 同步 `docs/endpoints/<resource>.md`（request/response/error code）

**Constraints**:
- 對照 `docs/endpoints/<resource>.md` contract 寫實作
- API contract breaking change 必先新 ADR
- Regression test 必須跑真 DB（testcontainers / SQLite-in-memory）
- 不可以 fabricate endpoint contract — 先寫 spec 再寫 code

**Workflow**:
1. 讀 `docs/US/<US-id>.md` + `docs/endpoints/<resource>.md`
2. 寫 code + DB migration（如有）+ RT-XXX
3. 跑 integration test
4. DEV_DONE 後 spawn fresh checker

**Standards** (per `skills/orchestrator/SKILL.md` § Agent standards by phase — Build-phase):
- 對齊 `docs/endpoints/<resource>.md` contract（request/response/error code）— 不自行改
- API contract breaking change 必先開新 ADR
- RT-XXX integration test 必須跑真 DB（testcontainers / SQLite-in-memory）
- 改 code 同 commit 更新 `docs/coverage/<US-id>.md` + 同步 `docs/endpoints/<resource>.md`
- Append changelog 到 `docs/US/<US-id>.md`

See: `skills/orchestrator/SKILL.md` § Inner loop + § Agent standards by phase — Build-phase

## Auto-execute mode

當 trigger table 命中（「API / Prisma / DB / endpoint」），Backend 必須 auto-execute：

**Auto-execute**（唔使問）：
- 改 `src/api/` / `src/services/` / `src/db/`
- 寫 Prisma migration（如有 schema 改）
- 寫 RT-XXX integration test（用 testcontainers / SQLite-in-memory）
- 同步 `docs/coverage/<US-id>.md` + `docs/endpoints/<resource>.md`（如 endpoint contract 變）
- Append `docs/US/<US-id>.md` changelog
- 自動 commit

**Worktree 隔離**：如平行 dispatch，自動用 `isolation="worktree"`。

**需要 David**：
- API contract breaking change（必先新 ADR + David 確認）
- Schema 改動涉及 data migration（要 David 知情）

See: `skills/orchestrator/SKILL.md` § Auto-execute Gate + § Worktree isolation