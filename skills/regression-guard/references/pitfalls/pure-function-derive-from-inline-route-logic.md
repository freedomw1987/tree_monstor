# ⚠️ Pitfall — Pure function derive from inline route logic for unit test (2026-06-08 pm-system Sprint 1)

**場景**:route 邏輯入面晒 inline(`worklogs.ts` 內 `computeWorkLogPagination` / `isEditableForCurrentMonth`、`agents.ts` 內 `canClaimTask`),**冇 extract 出嚟做 exportable helper**。要寫 unit test 守住 RG guard 嗰陣,直接 `import` route file 會 trigger 全部 prisma / elysia / middleware dependency — 根本行唔到。

**症狀**:
- `import { ... } from './worklogs'` → bun test 撞 `Cannot find package 'elysia'`
- Mock 晒 prisma 嘅路太重,test 變 integration test
- 冇 helper function 可以 unit test,RG entry 永遠 ❌ Regression test
- 「冇 test 守住舊 bug」一直係真實狀態

**正確做法 — 3 步 derive pattern**(2026-06-08 pm-system Sprint 1 親驗 OK):

1. **抄源碼 inline logic 入 test file 頂部,做 local helper**:
   ```typescript
   // backend/src/routes/agents.test.ts 頂部
   export function canClaimTask(
     user: AuthUser | null,
     isAgentFlag: boolean | null | undefined,
     task: TaskSnapshot
   ): { ok: true } | { ok: false; code: 'UNAUTHORIZED' | 'FORBIDDEN' | 'BAD_REQUEST'; message: string } {
     // 100% 對齊 routes/agents.ts POST /claim-task 嘅 validation 邏輯
     if (!user) return { ok: false, code: 'UNAUTHORIZED', message: 'Authentication required' }
     if (!isAgentFlag && !hasPermission(user, 'tasks.claim')) {
       return { ok: false, code: 'FORBIDDEN', message: 'Only agents can claim tasks or tasks.claim permission required' }
     }
     if (task.status !== 'pending') return { ok: false, code: 'BAD_REQUEST', message: `Task is not available. Current status: ${task.status}` }
     if (task.assigneeId) return { ok: false, code: 'BAD_REQUEST', message: 'Task is already assigned' }
     return { ok: true }
   }
   ```

2. **用 comment 標明「derive 自 source file:line」**:
   ```typescript
   /**
    * Derive 自 routes/agents.ts:238-293 (claim-task handler) 嘅 pure validation logic。
    * 100% 對齊 source 嘅 4 個 check + 對應 status code。
    * 將來 route 改動要同步 update 呢個 helper + 跑 test。
    */
   ```

3. **Sprint 補 test checklist**(可重用):
   - [ ] 揀要守嘅 RG-XXX entry / P0 US(per TEST-COVERAGE.md § 3)
   - [ ] 讀對應 route file inline 邏輯,derive 出 local helper(同 source 100% 對齊)
   - [ ] Helper 入面寫「derive 自 file:line」comment
   - [ ] 寫 5-15 個 test cases(critical path + boundary + admin bypass edge case)
   - [ ] 跑 `bun test src/<path>/<file>.test.ts` 確認全綠
   - [ ] **後續 refactor 必須同步 update 兩處**,或者正式 extract helper 入 route file

**踩坑親驗**(2026-06-08 pm-system `agents.test.ts`):我第一版寫「admin user without isAgent and without tasks.claim is forbidden」—— **test 立即 fail**,因為 `hasPermission` 對 `role === 'admin'` 會 bypass 任何 permission check。即係話:source 嘅 admin bypass 行為我誤解咗,**冇 test 永遠唔會發現**。修正:加埋「admin user bypasses isAgent check via hasPermission admin bypass」case + comment 解釋點解 expected = true。**呢個就係 test 嘅 value —— 守 source 嘅真實行為,而唔係我以為嘅行為**。

**冇 derive 嘅後果**:
- RG entry 永遠 ❌ Regression test
- Tech debt TD-001(測試覆蓋率)永遠高 priority
- 「fix 完又壞」嘅痛點重現(因為 refactor 冇 invariant guard)
- 紅線 12(P0 US 必有 test)+ 紅線 13(冇 RG entry 嘅 fix 唔可以 merge)兩條齊踩

**Lesson**:**derive pure function for unit test 係 RG guard 嘅救命稻草**。Inline logic 無法直接 test → 抄出嚟做 local helper → 守住 invariant → refactor 時用對齊 comment 提醒自己同步。**Sprint 補 test 嘅 default 模式**。
