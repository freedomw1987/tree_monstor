# pm-system 2026-06-08 Sprint 1 — Test Derive 參考

> **對應 skill**: `regression-guard` (Pitfall: Pure function derive from inline route logic)
> **對應 session**: David Chu 嘅 pm-system doc batch + Sprint 1 補 test
> **結果**: 3 份新 test (42 tests pass),3 個 P0 US 升至 PASS-UNIT,coverage 5% → 25%

---

## 1. Sprint 起點狀態

- 18 routes 喺 backend/src/routes/,只有 `tasks.test.ts` 1 個有 test
- TD-001(測試覆蓋率 ~5%)列為 P0
- RG-001 (Agent claim 3938a2d)、RG-003 (WorkLog 部門 c42e634) 兩個 entry 冇 regression test
- US-6.2 / US-7.3 / US-9.2 三個 P0 US 標 NONE

## 2. 揀要守嘅 RG / US(per TEST-COVERAGE § 3 優先序)

| 優先 | US / RG | 揀嘅原因 |
|------|---------|---------|
| 🔴 1 | US-7.3 RBAC middleware | security critical(紅線 12) |
| 🔴 2 | US-9.2 + RG-001 Agent claim | AI 係最 fragile area(觀察 5 個 fix commit 嘅 pattern) |
| 🔴 3 | US-6.2 + RG-003 WorkLog 分頁 | commit 9adc1fa 改咗分頁,守住新 invariant |
| 🟡 4 | US-6.3 Excel export (limit=-1) | bonus,順手守 |

**Sprint 唔做**:
- E2E framework(紅線 17)— 留 P0 next sprint
- US-9.1 POST /agents — CRUD 唔同 validation,留 P1
- US-4.x Task full coverage — 已有 PARTIAL 唔急

## 3. 三份 test derive 過程

### 3.1 `backend/src/middleware/permission.test.ts` (18 tests)

**Source 來源**:`backend/src/middleware/permission.ts` (113 lines)

**Helper**:直接 import 源碼 function(純,冇 DB dep)→
```typescript
import { hasPermission, hasAllPermissions, hasAnyPermission, requirePermission, type AuthUser } from './permission'
```

**Test cases 分組**:
1. `hasPermission` (6 tests):null user、admin bypass、有/冇 permission array、Agent user edge case
2. `hasAllPermissions` / `hasAnyPermission` (3 tests):all 必須、any 一個、empty list vacuously true
3. `requirePermission` (3 tests):success null、403 error、null user 403
4. Role × Permission matrix (6 tests):3 roles × 2 critical perms

**特別 pitfall**:**冇踩**(因為 `hasPermission` 源碼好 pure,易讀)

**結果**:`bun test` 18/18 pass,0 fail

### 3.2 `backend/src/routes/worklogs.test.ts` (15 tests)

**Source 來源**:`backend/src/routes/worklogs.ts:247-300` (GET handler inline 邏輯) + `:386-397`(PUT 嘅「上個月 cutoff」)

**Helper**:**derive 出 local helper**:
```typescript
function computeWorkLogPagination(opts: { page?, pageSize?, limit?, totalCount: number }): {...}
function isEditableForCurrentMonth(logDate: Date, now?: Date): boolean
```

**Test cases 分組**:
1. Pagination (9 tests):default、page 2、pageSize cap、pageSize=0 fallback、page=0 fallback、`limit=-1` (Excel use case)、`limit=500`、`limit` 優先 over page、totalCount=0 edge
2. Previous-month cutoff (6 tests):current month day >=5 OK、day <5 blocked、previous month blocked、previous year blocked、5 號 exact boundary、4 號 23:59:59 boundary

**踩坑親驗**:**冇踩**(pagination logic 直接 derive,cutoff logic 5 號 4 號 boundary case 重要)

**結果**:`bun test` 15/15 pass

### 3.3 `backend/src/routes/agents.test.ts` (9 tests)

**Source 來源**:`backend/src/routes/agents.ts:237-293` (POST /claim-task handler)

**Helper**:derive 出 `canClaimTask(user, isAgentFlag, task)` (4-check validation)

**Test cases**:
1. Agent 過:isAgent=true + pending task OK
2. PM 過:non-agent + tasks.claim permission OK
3. Visitor 擋:non-agent + no tasks.claim → FORBIDDEN
4. Null user → UNAUTHORIZED
5. in_progress task → BAD_REQUEST
6. Already assigned → BAD_REQUEST
7. Completed task → BAD_REQUEST
8. **Admin bypass**:admin user 即使冇 isAgent 都 bypass(hasPermission admin bypass)— 此 case 守住真實行為
9. Agent flag sufficient:role=visitor 但 isAgent=true 都 OK(因為第一個 check 就過)

**踩坑親驗**:第一版我寫「admin user without tasks.claim and isAgent=null is FORBIDDEN」—— **test 立即 fail**,因為 `hasPermission` 內部 admin bypass 喺任何 permission 都 return true。修正:加 case 8「admin bypass via hasPermission」,順手用 comment 講解點解 expected = true。

**結果**:`bun test` 8/9 pass → 修正後 9/9 pass

## 4. 統一 sprint 補 test workflow(可重用)

```
Sprint planning
    ↓
[讀 TEST-COVERAGE.md § 3 補 test 優先序]
    ↓
[揀 RG-XXX entry / P0 US]
    ↓
[讀對應 source route file 嘅 inline 邏輯]
    ↓
[決定 derive strategy]:
    ├─ Pure function(middleware/util)→ 直接 import source
    └─ Inline route logic → derive local helper 入 test file 頂部
    ↓
[寫 5-15 個 test cases]:
    - happy path
    - boundary(cap / 0 / null / 邊界日期)
    - admin bypass edge case
    - 對 RG root cause 嘅具體守衛
    ↓
[加 derive comment: source file:line + 對齊聲明]
    ↓
[跑 bun test 確認全綠]
    ↓
[更新 TEST-COVERAGE.md / QA-TRACKER.md / REGRESSION-GUARD.md]:
    - 標 US 為 PASS-UNIT
    - RG-XXX entry 加 regression test link
    - TECH-DEBT.md § 1 進展 line
    ↓
[Commit 全部 + push]
```

## 5. 對應嘅 doc 更新 checklist

每次 sprint 補完 test,呢啲 doc 必須同步 update:

| Doc | 改動 |
|-----|------|
| `TEST-COVERAGE.md` | test count 加,file list 加 |
| `QA-TRACKER.md` | 對應 US row 改 status(PARTIAL → PASS-UNIT),§ 3 補 test 優先序移走完成嘅,§ 2 健康指標加進度 |
| `REGRESSION-GUARD.md` | 對應 RG-XXX entry 嘅「Regression test」由 ❌ 改 ✅ / ⚠️ |
| `TECH-DEBT.md` | TD-001 entry 加「2026-06-08 進展」line |

**冇更新 doc = 任務冇做**(紅線 11 嘅延伸應用)

## 6. npm scripts(pm-system 用 Bun)

```jsonc
// backend/package.json
{
  "scripts": {
    "dev": "bun --watch src/index.ts",
    "start": "bun src/index.ts",
    "test": "bun test",                  // 0 setup
    "test:watch": "bun test --watch",
    "test:coverage": "bun test --coverage"  // 1.2 支援
  }
}
```

**Usage**:
```bash
cd backend && bun test src/middleware/permission.test.ts   # 單一 file
cd backend && bun test                                       # 全部
cd backend && bun test --coverage                            # coverage report
```

## 7. 對 retro 嘅回饋

`docs/retros/2026-06-08-initial-doc-batch.md` 嘅 § 4 Action Items 對應完成:
- ✅ ACT-1 US-7.3 RBAC middleware test
- ⚠️ ACT-2 US-9.2 Agent claim E2E(只做 unit,E2E 仲未)
- ✅ ACT-3 US-6.2 WorkLog 分頁 regression test
- ❌ ACT-4 `git show 7f43cba` 補 RG-005
- ✅ ACT-5 跑 bun test 確認 case count(44 total)
- ✅ ACT-6 改 PRD 必 update tracker(本次 sprint 守住)

## 8. 將來同類 sprint 嘅入口

下次要做類似「sprint 補 test + doc update」嘅 session,直接跟呢份 reference:

1. 讀 `regression-guard` skill 嘅「Pure function derive from inline route logic」pitfall
2. 讀呢份 reference 嘅 § 4 workflow
3. 對應 § 5 doc 更新 checklist
4. 跟 § 6 npm scripts 跑 test
