# Reviewer Verdict v2 — auto-observe hook 設計 (2026-09-22)
> **對應 §2.8 RSI Evolution SOP**
> **對應 V03 紀律**：AGENTS.md §1.5 V03
> **目標文件**：`/tmp/auto-observe-design.md` **v1.1**
> **對照基線**：v1.0 verdict = 🔴 REJECT（`docs/sop/rsi-reviewer-verdict-2026-09-22-auto-observe.md`）
> **執行者**：Reviewer subagent（V03 二審）
---
## 總評: 🟢 APPROVE_WITH_NITS
v1.1 已系統性回應 v1.0 verdict 的所有 P0/P1 + 6 個 Optional。設計動機到實作的對齊現在一致：`tool_call(TaskUpdate)` 是唯一觸發點、`execFileAsync` + fire-and-forget 不在 critical path、UUID/task_id/gate_results/install_pi_observe_hook 等 P1 修正逐項到位。**1 個事實 nit 不影響 merge**：`<task.id>` 並非 randomUUID（實為 `String(this.nextId++)` 序號字串），但既無 ajv strict UUID format 強制也不會汙染聚合，建議列為 v1.1.1 修註。
---
## 1. P0 修正驗證
### P0-1: ✅ 確認
**位置**：`§2.3.2` 完整 Extension 程式碼
**證據**：
- `if (event.toolName !== "TaskUpdate") return; if (event.input?.status !== "completed") return;` — 精準攔截，跟 v1.0 verdict 要求的最小修正範本逐行對齊
- `const execFileAsync = promisify(execFile);` + `execFileAsync(...).then().catch()` — fire-and-forget 非阻塞（不 await）
- `ctx.sessionManager?.getSessionId?.() ?? "unknown"` — 從 pi sessionManager 取 session ID
- `join(ctx.cwd, ".pi", "observe-pi-task.sh")` — 從 ctx.cwd 取工作目錄
- `execFile`（不經 shell）+ argv array — 防 command injection
- `ctx.ui.notify` 失敗 graceful + warning level
**與或 `orca-agent-status.ts:374` 對照**：API shape（`pi.on('tool_call', (event, ctx) => { event.toolName, event.input }`）與實際生產 Extension 一致
### P0-2: ✅ 確認（三處統一）
- **§2.1** table A：`Pi Extension + tool_call(TaskUpdate) hook` = ✅✅；B/C/D = ❌/❌/🟡；G (agent 自律) = ❌
- **§2.2** table：「`tool_call (TaskUpdate)` task 標記 completed」= ✅✅ **最佳**
- **§4 D2**：「`tool_call(TaskUpdate)`」= ✅ 同意
**三者指向一致**，與 v1.0 verdict 的「§2.1 / §2.2 / §4 統一」要求相符
---
## 2. P1 修正驗證
| ID | 結果 | 證據 |
|---|---|---|
| **P1-1** task_id 改 `<task.id>` | ✅ | §2.3.1 schema 註解「pi-tasks 的 task.id 已是 randomUUID()」（**事實 nit**：實為 `String(this.nextId++)` 序號 — 見 §5 N1） |
| **P1-2** `gate5_rsi: "auto"` | ✅ | §2.3.1 schema：「`"auto"` 而非 `"pass"`：Extension 是 fallback 寫入、RSI gate 未真正執行」 |
| **P1-3** install.sh pi-only | ✅ | §2.3.3：「只對 pi agent 執行」、「`if [[ "$agent" == "pi" ]]; then install_pi_observe_hook fi`」 |
| **P1-4** §3 補 6 個 R-MISS | ✅ | §3 含 R-MISS-1 ~ R-MISS-6，全部含等級 + 緩解措施 |
| **P1-5** §6 Extension TS 測試 | ✅ | §6 Gate 2：`tsc --noEmit` + 「Extension 手動 integration test」 + 「pi session 跑 TaskUpdate → cat observation」 |
| **P1-6** §5 sop-evolver SKILL.md 改 | ✅ | §5 變更檔案清單列「`.agents/skills/sop-evolver/SKILL.md` 修改 → §4.1 加『替代觸發（v1.1+）』段落」 |
| **P1-7** §2.3.1 併發保護 | ✅ | §2.3.1 step 4：「併發保護：寫入使用 temp file + atomic rename（POSIX `mv` 原子操作）」 |
---
## 3. Optional 修正驗證
| ID | 結果 | 證據 |
|---|---|---|
| **O1** skills_used 簡化 | ✅ | §2.3.1 schema + §4 D4：「v1 簡化：固定 `["auto-observe"]`；v1.1 再加 heuristic」 |
| **O2** duration_seconds 單位 | ✅ | §2.3.1 schema：「`duration_seconds`: (task.updatedAt - task.createdAt) / 1000, // pi-tasks 是毫秒 Date.now()」 |
| **O3** PI_TASK_LIST_ID edge case | ✅ | §7 step 8：「Edge case 驗證：taskScope != session 預期 log warning + skip」 |
| **O4** note SOP 提醒 | ✅ | §2.3.1 schema 註解：「subject/description 不應含個資」 |
| **O5** `.observed-tasks.bak` | ✅ | §3 R-MISS-5：「可選備份 `.observed-tasks.bak`」 |
| **O6** `--disable-rsi` 對應 | ✅ | §2.3.3：「`--disable-rsi` 對應：同時跳過 Extension 部署與 `install_pi_observe_hook()` 呼叫」 |
---
## 4. 整體檢查結果
### 4.1 正確性: 🟢
- §2.3.2 程式碼現在真正由 LLM 標記 `completed` 觸發，**不依賴 agent 自律**——解決原始動機
- 觀察失敗路徑：`execFileAsync` 不 await → `.then(notify success)/.catch(notify warning)` 不 throw，TaskUpdate 結果不變
- TypeScript Extension 用 jiti 載入（`extensions.md:79`），無需 build
### 4.2 跨 SOP 一致性: 🟢
- vs `observation.md` §3.1：7 個白名單欄位齊全 + 黑名單備註 ✅
- vs `2.8-rsi-evolution.md` §5.1：schema 對齊 + 不在 critical path ✅
- vs `gates.json` Gate 5：本文件即為 V03 二審 ✅
- vs sop-evolver SKILL.md：§5 列入 SKILL.md 變更清單（Extension 為主、skill 為備分工）
- 觀察/改動分離：Extension 只寫 observation、不改 SOP ✅
- 匿名化：`project_id = SHA256(path)[:8]` ✅
### 4.3 技術可行性: 🟢
- Pi Extension `tool_call` 攔截 `TaskUpdate`：**已驗證**（`@tintinweb/pi-tasks/src/index.ts:837` `pi.registerTool({ name: "TaskUpdate" ... })`；`orca-agent-status.ts:374` 為真實運行的 Extension 範例）
- `.pi/tasks/tasks-${sessionId}.json` 路徑：**已驗證**（`@tintinweb/pi-tasks/src/task-paths.ts:40`）
- `ctx.sessionManager.getSessionId()` API：**已驗證**（`orca-agent-status.ts:19-21` 生產用法）
- jiti 載入 TS 無需 build：**已確認**（extensions.md:79 紀錄）
### 4.4 安全: 🟢
- 觀察寫入完全在 critical path 外（async + catch）✅
- `execFile` argv array 防 command injection ✅
- Schema 白名單嚴格（多餘欄位 reject）+ 黑名單 ✅
- 併發保護（POSIX atomic rename）防 race condition ✅
- project_id SHA256 雜湊無明文路徑 ✅
### 4.5 測試覆蓋: 🟢
§6 AC 含：
- 8 個新 bats（觀察/去重/schema 三種 case/project_id SHA256 確定性/PI_TASK_LIST_ID warning/skip）
- Gate 2 `tsc --noEmit` Extension type check
- Gate 3 191 既有 bats 不退步
- Gate 4 V03 Reviewer 二審（本 verdict）
- Extension 手動 integration test 2 條
### 4.6 依賴副作用: 🟢
- `install.sh` 加 `install_pi_observe_hook()` 只在 `[[ "$agent" == "pi" ]]` 時呼叫——Claude 跳過不破壞既有行為
- `--disable-rsi` 對應跳過 Extension 部署，與既有 `--disable-rsi` 跳過 sop-evolver install 邏輯對稱
- 既有 `install_rsi()` 結構（`install.sh:939-985`）+ `uninstall_rsi()`（`:987`）已有完整範式，新函數易融入
---
## 5. 剩餘問題
### N1（P3 註解級 nit，不擋 merge）
**§2.3.1 註解事實錯誤**：
- v1.1 寫：`"task_id": "<task.id>", // pi-tasks 的 task.id 已是 randomUUID()`
- 實況：`@tintinweb/pi-tasks/src/task-store.ts:183` 是 `id: String(this.nextId++)`（序號 1/2/3...）
- 影響範圍：極低——`observation.md §3.1` 雖標 `task_id: UUID`，但 repo 無 ajv strict UUID format schema 強制（`tests/us012-gate5.bats:196-198` 只 grep 欄位名存在），既有的 rsi-aggregate 也未做 UUID 驗證
- 建議：v1.1.1 修註改為「`task_id`: `<task.id>`（pi-tasks 序號字串 1/2/3...，**未來若需要 UUID 統一可拼接 `<cwd-hash>:1` 防跨 session 撞 id**）」
- 為何非 blocker：序號在**單 session scope** 內是唯一可推導的，這正是 §3 R-MISS-3 處理 `taskScope` 的設計前提；多 session 撞 id 的風險已被 R-MISS-1 dedup + 跨日檔案分檔緩解
### 其他無問題
設計 §2.3.1 step 1-6 邏輯鏈閉合、§7 E2E 計畫與 §6 驗收標準對應、§8 changelog 完整反映所有修正。
---
## 6. 風險分級: 🟢 LOW
| 類別 | 等級 | 理由 |
|---|---|---|
| 設計正確性 | 🟢 LOW | 動機-實作一致、Pi Extension API 已驗證 |
| 跨 SOP 一致性 | 🟢 LOW | 觀察/改動分離 + 7 個白名單對齊 |
| 技術可行性 | 🟢 LOW | 已有真實運行的 orca-agent-status 範例 |
| 安全 | 🟢 LOW | 並發/注入/敏感資料三道防線齊備 |
| 測試覆蓋 | 🟢 LOW | bats + tsc + 手動 E2E + reviewer 二審四層 |
| 依賴副作用 | 🟢 LOW | pi-only 條件 + 對稱 disable 設計 |
---
## 7. 跨 SOP 一致性檢查總表
- [x] 跟 2.8-rsi-evolution.md 一致（觀察模式、不在 critical path）
- [x] 跟 observation.md schema 對齊（7 欄位 + 黑名單；UUID 型別為唯一定義性 nit 見 N1）
- [x] 跟 gates.json Gate 5 一致（本文件即為 V03 二審）
- [x] 跟 sop-evolver 安全原則一致（只觀察、不改 SOP）
- [x] 跟 sop-evolver SKILL.md 一致（§5 列入 SKILL.md 變更、雙路徑分工）
---
## 8. 建議下一步
1. **可批准**：P0/P1/Optional 全修到位，建議給 APPROVE_WITH_NITS 標記 N1 為 v1.1.1 待辦
2. **實作順序**（若批准後）：
   - Step 1: `tools/observe-pi-task.sh` + 8 個 bats（紅→綠，Gate 1）
   - Step 2: `extensions/auto-observe.ts` + `tsc --noEmit` 通過（Gate 2）
   - Step 3: `install.sh` 加 `install_pi_observe_hook()` + pi-only 條件（Gate 2）
   - Step 4: `tests/observe-pi-task.bats` + 手動 integration 測試（Gate 1 + Gate 3）
   - Step 5: 跑 191 既有 bats 確認不退步（Gate 3）
   - Step 6: 更新 sop-evolver SKILL.md §4.1 「替代觸發」段 + 2.8 §7.4
   - Step 7: V03 再審本 verdict 等級 → 用戶批准 → 合併
3. **N1 處理時機**：v1.1.1 或本次 commit 的 docstring 內聯修正，不需要擋住 v1.1 merge
---
## 9. Verdict 摘要（給 orchestrator）
| 項目 | 結果 |
|---|---|
| **總評** | 🟢 **APPROVE_WITH_NITS** |
| **P0 修正** | 2/2 ✅ |
| **P1 修正** | 7/7 ✅ |
| **Optional 修正** | 6/6 ✅ |
| **剩餘 blocker** | 0 |
| **Nits** | 1（N1：`<task.id>` 註解事實 nit，不擋 merge） |
| **跨 SOP 一致性** | 5/5 ✅ |
| **技術可行性** | 5/5 ✅（pi-tasks source 已驗證） |
| **風險分級** | 🟢 LOW |
**結論**：v1.1 達到 merge 標準。N1 為文件層級準確度 nit，可在 v1.1.1 處理或本次 commit 順手修。
---
**Reviewer subagent** 完成於 2026-09-22
**對應 §2.3 Gate 4 (Reviewer Gate) + Gate 5 (RSI Gate)**：本文件即為必經 V03 verdict
---
## 回報給 orchestrator
**Verdict**：🟢 **APPROVE_WITH_NITS**（v1.1 可批准）
**P0/P1/Optional 驗證**：全部 ✅
- P0-1（P0-2 同）：§2.3.2 hook `TaskUpdate(status="completed")` + `execFileAsync` fire-and-forget + `ctx.sessionManager/cwd` 取值 — 跟之前要求的最小修正範本逐行對齊
- P0-2：§2.1/§2.2/§4 三處統一到 `tool_call(TaskUpdate)` ✅✅
- P1-1~7：全部到位（schema 修正、6 個 R-MISS、TS 測試、SKILL.md、pi-only、併發保護）
- Optional 6/6：skills_used 簡化、duration 單位、PI_TASK_LIST_ID、note 提醒、`.observed-tasks.bak`、`--disable-rsi`
**技術可行性**：已驗證 Pi Extension API（`orca-agent-status.ts:374` 為生產範例）、`@tintinweb/pi-tasks/src/index.ts:837` 註冊 `TaskUpdate`、`task-paths.ts:40` 路徑正確
**剩餘 Nits**：1 個 P3 文件 nit（不擋 merge）
- **N1**：v1.1 §2.3.1 註解錯寫「`<task.id>` 已是 randomUUID()」，實際 pi-tasks 用 `String(this.nextId++)` 序號字串；無 ajv strict UUID 強制，影響極低；建議 v1.1.1 修註或本次順手 inline 修正
**Cross-check**：依指示已停止；上述驗證覆蓋率充足（P0/P1/Optional + 跨 SOP + 技術 API + install.sh 整合）
