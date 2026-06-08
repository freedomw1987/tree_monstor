# crm-system Comprehensive Code Review (Security A + Architecture B + Ship Gate C) — 2026-06-07

> **Mode**: Read-only static review. David 進行中嘅 4 modified + 3 untracked files (deals.tsx, quotations.tsx, deal.ts, quotation.ts, multi-autocomplete.tsx 等) 完全冇郁.
>
> **Scope**: 53 files reviewed, 0 modified. Findings 集中喺 backend 14 routes + Prisma schema + RBAC + Docker + docs 8 份 + 1 個 typecheck pass.

---

## 1. Pre-flight findings

- **Git status**: 1 local commit ahead (`6bdaa5f` audit log retention ADR), 4 modified + 3 untracked files (David WIP)
- **Docs 8 份 audit (紅線 10)**: ✅ 6 份有 (PROJECT-OVERVIEW / PRD / DESIGN / TEST-COVERAGE / QA-TRACKER / REGRESSION-GUARD), ❌ **TECH-DEBT.md 缺**, ⚠️ `docs/api.md` 細楷 (spec 寫 `API.md`), 2 個 ADR ✅
- **Lockfile**: `bun.lock` ✅ 存在, `bunfig.toml exact = false` (漂移風險)
- **Typecheck**: `bunx tsc --noEmit` 報 **30+ silent type errors** (見下面 [B-1])

---

## 2. [A] Security findings (3 CRITICAL + 7 HIGH + 12 MEDIUM)

### CRITICAL
| # | Finding | File:Line | Fix |
|---|---------|-----------|-----|
| CRIT-1 | `POST /auth/register` 公開 + body 接受 `role: 'ADMIN'` = 公開 internet 變 admin | `apps/api/src/routes/auth.ts:69-105` | 加 `requirePermission('user:create')` + 刪 `role` 喺 body |
| CRIT-2 | `companies / contacts / deals` routes 全部 `authContext=0 requirePerm=0` = 公開 internet 可寫 DB | `company.ts`, `contact.ts`, `deal.ts` | 每個 file 開頭加 `.use(authContext)` + 個別 route 加 `requirePermission` |
| CRIT-3 | `chat / chat/send` 0 auth, AI 寫 tool (create_quotation / update_deal / create_company) 以 system actor 寫 DB = silent DB write 無 attribution | `chat.ts` | 加 `requirePermission('chat:use')` + 全部 AI 寫 tool 都要 audit |

### HIGH
| # | Finding | File:Line | Fix |
|---|---------|-----------|-----|
| HIGH-1 | JWT secret 兜底 string + `AI_CONFIG_ENCRYPTION_KEY` 唔驗長度 | `index.ts:46`, `rbac.ts:80` | Boot hard check `JWT_SECRET.length >= 32` |
| HIGH-2 | AI Config status endpoint 公開 = recon info leak | `ai-config.ts` | 一律 `requirePermission('ai-config:read')` |
| HIGH-3 | `tsc --noEmit` 報 30+ silent type errors, runtime OK = blind spot | 全部 route files | CI 必跑 `tsc --noEmit` exit code 0 |
| HIGH-4 | `Bun.password.verify` 默認 argon2id 但 `password minLength: 6` 過弱 | `auth.ts:23,82,142,144` | minLength 12 + complexity rule |
| HIGH-5 | `bun.lock` 不被 `npm audit` 認 = 紅線 18 status unknown | root | 用 `bun audit` + CI step |

### MEDIUM (12 個) — 略, 全部 P1 內 fix

---

## 3. [B] Architecture findings

### ✅ 做好嘅地方
- RBAC 兩層 source of truth 對得齊 (`packages/shared/src/permissions.ts` + DB `Role` / `RolePermission`)
- Region table 取代 enum (Day 9) — 正確方向
- Polymorphic line items (Product vs Service GP%) — 整潔
- Audit log 完整 (login / logout / password change / mutation 全部有)
- Nginx security headers 齊 (X-Frame-Options / X-Content-Type-Options / Referrer-Policy)
- Dockerfile hardened (oven/bun + libssl + ca-certificates + dumb-init + `--frozen-lockfile`)

### 🔴 HIGH 架構
- **HIGH-B1**: Permission source-of-truth drift — `permissions.ts` + `requirePermission()` strings + DB `RolePermission` 3 處唔 link
- **HIGH-B2**: Prisma client `aiConfig` model 唔 export 但 code 用緊 (typecheck fail)
- **HIGH-B3**: 每個 route file 重複 `logEvent` 模板 (`findUnique → delete → logEvent → return success`) → 應該抽 `withAudit(action, resourceType, fn)` helper

### 🟡 MEDIUM 架構
- 3 個 untracked multi-autocomplete components (David WIP)
- 4 個 modified files 對應 Day 14 deal/quotation 多選 filter, 加咗 query helper 但 **2 處 duplicate** (`deal.ts:11-15` 同 `quotation.ts:12-16`) → 應該抽 `apps/api/src/lib/query-helpers.ts`
- Frontend `apps/web/src/lib/api.ts` 冇 Zod runtime validation
- 冇 frontend error boundary

---

## 4. [C] Ship Gate — 紅線 10-18 audit

| 紅線 | 要求 | Status | Evidence |
|------|------|--------|----------|
| **10** | 8 份 docs commit | 🟡 PARTIAL | ❌ TECH-DEBT.md 缺, ⚠️ `api.md` 細楷 |
| **11** | 改 PRD 必更新 QA-TRACKER | ✅ PASS | Day 10/10.1/11 全部 update |
| **12** | P0/P1 US 有 test tasks | 🔴 FAIL | TEST-COVERAGE **全部 🟨 planned** — 0/19 P0 US 有 Unit/Integration/E2E |
| **13** | Bug fix 必有 RG-XXX | ✅ PASS | REGRESSION-GUARD.md 5 entries |
| **14** | root cause + prevention | ✅ PASS | RG-001 至 005 全部跟 template |
| **15** | Refactor RG-code confirm invariant | N/A | 冇呢類 refactor |
| **16** | P0 US Unit + Integration + E2E 三層 | 🔴 FAIL | 同 #12 |
| **17** | Production deploy smoke test | 🟡 NEEDS-VERIFY | 有 ops SOP 未 read |
| **18** | Critical/High CVE = 0 | 🔴 FAIL | `npm audit` 因 bun.lock 唔 work → status unknown |

**Ship gate verdict: 🔴 NO-GO** — 紅線 12/16/18 fail.

---

## 5. Priority fix list (sprint-ready)

### P0 (本週, 紅線 blocking)
1. 加 `authContext` + `requirePermission` 喺 `company.ts` / `contact.ts` / `deal.ts` / `chat.ts` (2-3 hr)
2. 修 `register` endpoint (`requirePermission('user:create')` + 刪 `role` 喺 body) (1 hr)
3. `bunx prisma generate` + fix 30+ type errors (2-4 hr)
4. JWT secret hard check 喺 boot (15 min)
5. 加 `docs/TECH-DEBT.md` + commit (30 min)
6. `bun audit` 跑 + 0 high/critical (5 min)

### P1 (下個 sprint)
7. 加 `bun test` 至少 5 個 P0 US smoke
8. 抽 `withAudit` helper
9. 抽 `query-helpers.ts` (去 dup `toIdArray`)
10. 補 audit log enum (`DEAL_STAGE_CHANGED` 等)
11. Password minLength 12 + complexity rule
12. Frontend Zod runtime validation 喺 `api.ts` boundary

### P2 (tech debt)
- bunfig `exact = true`
- 移除 `@ts-nocheck`
- Elysia 1.3 升級
- Frontend error boundary
- 抽 `normaliseService` helper (`manDayLines` → `manDays`)

---

## 6. Methodology — 3-pass code review pattern

### Pass A (Security) — 90 min
1. **Pre-flight** (`git status` + `git log --oneline origin/main..HEAD`) — 3 min
2. **Lockfile + docs check** (`ls bun.lock package-lock.json` + `ls docs/`) — 5 min
3. **Auth / RBAC core files read** (`auth.ts`, `rbac.ts`, `context.ts`, `index.ts`) — 15 min
4. **RBAC coverage matrix 1-liner** (上面 pitfall section 嘅 bash) — 1 min
5. **Per-route RBAC gap analyze** (cross-reference 0/0 / 0/N / M/0 / M/N) — 10 min
6. **Input validation spot check** (5 routes 揾 5 個) — 15 min
7. **SQL injection scan** (`rg '$queryRaw|$executeRaw'`) — 5 min
8. **CVE scan attempt** (`bun audit` 或 `npm audit`) — 5 min
9. **出 security findings table** — 15 min

### Pass B (Architecture) — 60 min
1. **Schema audit** (`schema.prisma` line 1-200 同 line 200-400) — 10 min
2. **Route patterns review** (route files 1-by-1, focus 重複 patterns) — 20 min
3. **Frontend modularity** (`lib/api.ts` + `hooks/` + `pages/`) — 10 min
4. **Docker / nginx / env isolation** — 10 min
5. **Typecheck run** (`bunx tsc --noEmit`) — 5 min
6. **出 architecture findings** — 5 min

### Pass C (Ship Gate) — 30 min
1. **紅線 10-18 一條條 audit** (對 `docs/qa-gate.md` + `SOUL.md`) — 15 min
2. **QA-TRACKER + REGRESSION-GUARD cross-check** — 5 min
3. **出 ship readiness report (go / no-go)** — 10 min

**Total**: 3 hours for 50+ files, 53 files reviewed, 0 modified (read-only).

### 工具搭配清單
- `search_files` (rg) — 1-liner RBAC matrix, 1-liner CVE, 1-liner typecheck
- `read_file` (offset/limit) — 100-line chunks 唔讀晒, focus 邏輯部分
- `terminal` (bunx tsc, bun audit, git status) — read-only verification
- `todo` (12 步計劃 + status update) — 進度追蹤
- Output 結構: table-format findings (CRIT / HIGH / MED) + 紅線 audit table + P0/P1/P2 priority list

### Anti-pattern (避免)
- ❌ 悶頭逐 file 讀晒 → 漏 big picture
- ❌ 寫 patch 試 fix → review 變 implementation
- ❌ 淨 audit docs → miss code-level issues
- ❌ 淨 audit code → miss ship gate
- ❌ 唔做 pre-flight git check → 撞 revert (David 6/6 教訓)

---

## 7. 將來 re-review 嘅 baseline

呢份 reference file 係 crm-system 喺 2026-06-07 嘅 ship-readiness snapshot。下次再 review 應該:
1. Diff 對比呢份 file 嘅 P0/P1/P2 status — 邊啲 P0 fix 咗, 邊啲仲有
2. 重新跑 RBAC matrix — 應該見到 `authContext=0 requirePerm=0` 嘅 file 全部消失
3. 重新跑 `bunx tsc` — 應該 0 errors
4. 重新跑 `bun audit` — 應該 0 high/critical
5. Check 紅線 12/16 嘅 test coverage — 應該見到實際 `bun test` files 唔再係 "planned"

如果 6 個月後 crm-system 入 production, 呢份 reference 係 14-route RBAC baseline。
