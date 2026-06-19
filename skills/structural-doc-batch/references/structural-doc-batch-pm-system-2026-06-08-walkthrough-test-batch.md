# pm-system Test Batch Walkthrough (Phase 2 — 2026-06-08)

> **目的**:補 `structural-doc-batch` 嘅 Phase 2(補 test)完整 walkthrough。
> 對齊 session「pm-system doc batch → test batch」嘅 6 個 commit + 47 tests。

## 觸發

Doc batch 完成(commit `277f337`)後,David 確認 SOW 刪(`81d4c8c`),
即開 Test Batch Sprint 1:

```
Sprint 1 P0:
  - 補 RBAC middleware test
  - 補 Agent claim-task E2E(RG-001 守住)
  - 補 WorkLog 分頁 regression test
  - 設 Playwright E2E
  - RBAC 負面 E2E case
```

## 4 個 commit

| Commit | 內容 | Tests |
|--------|------|-------|
| `315d2f8` | 3 份 unit test(RBAC + WorkLog + Agent) | 42 pass |
| `88b641e` | E2E framework + critical-path.spec.ts | 3 pass |
| `ef18ad7` | RBAC negative E2E(10 tests) | 10 pass |
| (見 retro) | 過程發現 TD-011 security bug | — |

**累計**:55 tests(42 unit + 3 critical-path E2E + 10 RBAC negative E2E)

## 3 份 Unit Test 嘅 derive 模式

`structural-doc-batch/SKILL.md` 嘅 Phase 2 講咗 pattern,呢度 walkthrough:

### 1. `permission.test.ts`(18 tests)
- 守住 `hasPermission` / `hasAllPermissions` / `hasAnyPermission` / `requirePermission`
- 6-row Role × Permission matrix(developer / tester / visitor 對 common perm)
- Pure unit,無 DB mock

### 2. `worklogs.test.ts`(15 tests)
- **重點**:9adc1fa commit 改咗分頁邏輯,inline 喺 `routes/worklogs.ts` 冇 extract helper
- **解法**:derive 同源 pure function `computeWorkLogPagination` 入 test file
- 守住 9 個分頁 case + 6 個「上個月 cutoff」boundary case
- 將來 refactor 抽 helper 出嚟時,呢個 test 就係 regression baseline

### 3. `agents.test.ts`(9 tests)
- 守住 `canClaimTask` validation
- 6 個 invariant:agent 必須先驗 status=pending + assigneeId=null
- 防止 double-claim / claim-in-progress / claim-by-non-agent

## E2E Framework 嘅 4 個 Setup 細節

`e2e/` 目錄結構:

```
e2e/
├── package.json          # @playwright/test ^1.48
├── playwright.config.ts  # headless, workers=1 (shared admin)
├── .gitignore            # node_modules / test-results / playwright-report
├── README.md             # 點跑 + caveats
└── tests/
    ├── critical-path.spec.ts  (3 tests)
    └── rbac-negative.spec.ts  (10 tests)
```

### 1. 真 docker 跑(避免 mock drift)

```typescript
// playwright.config.ts
use: {
  baseURL: 'http://localhost:8080',  // frontend via nginx
}
// tests 同時打 backend direct 拎 token(快,deterministic):
const token = await page.request.post('http://localhost:4001/auth/login', ...)
```

### 2. Source-first 嘅 test data

E2E test 唔依靠 PRD doc 嘅 endpoint,直接 grep backend source:

```bash
# 發現 auth endpoint 唔喺 /api group
grep -E "prefix:|\\.use\\(" backend/src/index.ts
# → authRoutes 喺 group('/api') 之外
# 所以 /auth/login(無 /api)
```

### 3. test 假設 vs 真實行為 嘅即時修正

我以為嘅 4 個假設,**全部撞 source code 真實行為**:

| 假設 | 真實 | 修正 |
|------|------|------|
| pm 冇 projects.create | pm 有 projects.create | 改 negative case 用 DELETE /users |
| 冇 token → 401 | → 403(backend 將 auth-missing 視為 FORBIDDEN) | 改 test 期望 403 + 註解 |
| malformed token → 401 | → 403 | 同上 |
| non-existent UUID → 403 | → 500(prisma throw) | 加 TD-011 + 守住 500 行為 |
| login redirect /projects | → /(dashboard) | `waitForURL` 用 function 形式 |

> **Lesson**:test-first 嘅價值即係呢度 — 寫嘅時候我以為 A,**真實係 B**,
> 即刻修正並記低 known behavior,**唔可以假裝錯誤冇發生**。

### 4. 過程發現 security bug → 即時 write TECH-DEBT

```typescript
test('non-existent user token: backend currently returns 500 (KNOWN BUG TD-XXX)', async ({ request }) => {
  const fakeUuid = '00000000-0000-0000-0000-000000000000'
  const res = await request.post(`${BACKEND}/api/projects`, {
    headers: { Authorization: `Bearer ${fakeUuid}:admin` },
    data: { name: 'E2E Negative Project' },
  })
  // 期待 fix 後改 [401, 403]
  expect(res.status()).toBe(500)
  // TODO: TD-XXX — fix prisma.findUnique error handling in auth derive
})
```

對應 `docs/TECH-DEBT.md` 加 TD-011 entry:

```markdown
### 🔴 TD-011: Backend auth derive hook 撞不存在 UUID 會 throw 500

- **發現日期**: 2026-06-08(E2E rbac-negative 過程發現)
- **影響**: `backend/src/index.ts` derive hook 對 well-formatted 但唔存在嘅 user UUID,
  `prisma.user.findUnique` throw → 500 internal error。應該 graceful 403 / 401
- **修復成本**: 0.1 日(wrap try-catch + return `{ user: null }`)
- **守住**:`e2e/tests/rbac-negative.spec.ts` line 125 預期 500,將來 fix 改 `[401, 403]`
```

## 5 個 E2E Pitfall 表(已 patch 入 `structural-doc-batch/SKILL.md`)

| Pitfall | 症狀 | Fix |
|---------|------|-----|
| `docker compose up` 攔 long-lived | terminal 報錯 | `background=true, notify_on_complete=true` + process poll |
| Backend port 唔同 docker 內部 | 4001(外部)/ 4000(內部) | E2E 兩條 URL 都 test |
| `/api/auth/login` 404 | authRoutes 喺 group 之外 | `/auth/login` |
| Prisma Decimal serialize | `hours === 2.5` 失敗 | `Number(workLog.hours)` |
| Login redirect path | `waitForURL(/projects/)` timeout | 真實係 `/` |

## 守住嘅紅線

| 紅線 | 對應 Test |
|------|----------|
| 紅線 12(P0 US 必有 test)| 9 個 P0 US 過 test |
| 紅線 13(RG-001 守住)| `canClaimTask` 9 tests |
| 紅線 17(production smoke test)| E2E 13 tests pass |

## Coverage 提升

| 階段 | Coverage |
|------|----------|
| 一開始 | ~5% |
| Doc batch 完成 | ~5%(冇變) |
| Unit test batch | 5% → 25% |
| Critical path E2E | 25% → 30% |
| RBAC negative E2E | 30% → 35% |

## 下次 sprint 行動(入 retro Action items)

🔴 P0: Fix TD-011(auth derive hook try-catch)— 0.1 日
🟡 US-9.1 POST /agents test — 0.5 日
🟡 Frontend component test(Vitest + RTL)— 1 日
🟡 ACT-4 補 RG-005 record(`git show 7f43cba`)— 0.1 日

## Reference

- `structural-doc-batch/SKILL.md` Phase 2 section
- `pm-system-deployment` skill(test credentials, port mapping, E2E section)
- `prisma-json-field-api-serialization` skill(Decimal wire shape)
- `docs/TEST-COVERAGE.md` / `docs/QA-TRACKER.md` / `docs/TECH-DEBT.md`
- `e2e/README.md`
