# Reviewer Verdict — auto-observe hook 設計 (2026-09-22)

> **對應 §2.8 RSI Evolution SOP**
> **對應 V03 紀律**：AGENTS.md §1.5 V03
> **目標文件**：`/tmp/auto-observe-design.md` v1.0
> **設計目標**：讓 `tree_monstor --enable-rsi` 安裝 = 每個任務自動寫 observation（不依賴 agent 自律）
> **執行者**：Reviewer subagent（V03 二審）

---

## 總評: 🔴 REJECT

設計動機正確、跨 SOP 大方向對齊（觀察/改動分離、4 條安全規則、Reviewer 二審），但**核心設計自相矛盾**——§2.1 選 `agent_end`、§2.2/D2 選 `tool_call(TaskUpdate)`、§2.3.2 範例程式碼實際 hook 的是 `bash` 呼叫 `observe-pi-task.sh`。這個實作**無法解決「agent 自律不可靠」的原始問題**，因為它仍然需要 agent 自己記得跑 bash 命令。

**REJECT 理由**：P0 等級 2 個 blocker + P1 等級 7 個 must-fix。修正 §2.3.2 範例程式碼至 hook `TaskUpdate(status="completed")` 後，可重新送審。

---

## 1. 檢查結果

### 1.1 正確性: 🔴 FAIL

**致命矛盾**：設計動機是「不依賴 agent 自律」，但 §2.3.2 範例程式碼實際 hook 的是：

```typescript
if (!isToolCallEventType("bash", event)) return;
if (!event.input.command.includes("observe-pi-task")) return;
```

這表示 Extension **只在 agent 自己呼叫 `observe-pi-task.sh` 的 bash 命令時才介入**。如果 agent 不記得跑這個 bash 命令，Extension 完全不會觸發——**「agent 自律不可靠」這個原始失敗模式完全沒解決**。

**正確做法**應為 hook `TaskUpdate` 直接攔截 LLM 標記任務為 completed 的事件（這就是 D2 與 §2.2 表格決定的方向）。`TaskUpdate` 是 pi-tasks 透過 `pi.registerTool()` 註冊的工具（見 `/Users/davidchu/.pi/agent/npm/node_modules/@tintinweb/pi-tasks/src/index.ts:836`），可被 `tool_call` 攔截（見 `extensions.md:864-887` 的 `event.toolName === "TaskUpdate"` 範例）。

### 1.2 風險評估: 🟡 MEDIUM

7 個風險中 R1-R7 評級合理（🟢×5、🟡×2），但**遺漏至少 6 個關鍵風險**：

| 遺漏風險 | 等級 | 說明 |
|---|---|---|
| **R-MISS-1**: 併發寫入 race condition | 🟡 MED | Extension `tool_call` handlers 循序執行，但 `execSync` 同步阻塞；多 task 連續完成時可能撞同一 observation 檔，需 `flock` 或 atomic write |
| **R-MISS-2**: `.pi/extensions/` 需 project trust | 🟡 MED | 見 `extensions.md:24` "Project-local `.pi/extensions` entries load only after the project is trusted"——未 trust 的專案會靜默失敗 |
| **R-MISS-3**: `PI_TASK_LIST_ID` / `taskScope: "project"` 不支援 | 🟡 MED | pi-tasks 預設 scope=`session`（見 `tasks-config.ts:18`），但用戶可設 `taskScope: "project"` 改用 `<cwd>/.pi/tasks.json`；D5 只排除 `session-global`，沒處理 `project`/`memory` |
| **R-MISS-4**: Claude Code 使用者無 auto-observe | 🟡 MED | §1 案例提到「你目前主要用 pi」，但 install.sh 同時部署給 Claude——Claude 不支援 Extension，自動觀察只對 pi 有效，需在 SOP 明示「Claude 用戶仍須 agent 自律」 |
| **R-MISS-5**: `.observed-tasks` dedup 檔 SPOF | 🟢 LOW | 該檔被刪除/損壞 →全部 task 重新觀察（資料重複）；應定期 backup 或用 git 追蹤 |
| **R-MISS-6**: Extension 全權限執行 | 🟡 MED | `extensions.md:23` 明示「Extensions run with your full system permissions」——Extension 一旦被 commit 進 repo 所有人都會執行，supply chain 風險 |

### 1.3 跨 SOP 一致性: 🟡 NEEDS_FIX

| 檢查項 | 結果 | 證據 |
|---|---|---|
| 跟 2.8-rsi-evolution.md §5（觀察規範）一致 | 🟡 | 觀察位置/失敗處理對齊，但 `task_id` 格式不符 |
| 跟 observation.md schema 白名單一致 | 🟡 | 7 欄位匹配；但 `task_id` 設計為 `<task.id>-<sessionId prefix>` **不是 UUID**，違反 observation.md §3.1「`task_id: UUID`」欄位型別 |
| 跟 observation.md schema 黑名單一致 | 🟢 | `note` 欄位含 `subject: description`（task metadata，非 raw conversation）暫可接受 |
| 跟 gates.json Gate 5 一致 | 🟢 | 本文件即為 Gate 5 必經的 Reviewer verdict |
| 跟 sop-evolver SKILL.md 一致 | 🟡 | sop-evolver SKILL.md §4.1 說「Gate 5 自動觸發 → 寫 observation」——本設計**繞過 sop-evolver skill**，直接由 Extension 觸發。SKILL.md 需同步更新，否則兩條平行路徑（skill vs Extension）會產生文檔漂移 |
| 跟 sop-evolver「觀察/改動分離」安全原則 | 🟢 | Extension 只寫 observation、不改 SOP，符合 |
| 跟「匿名化」規則（2.8 §6.2） | 🟢 | `project_id = SHA256(path)[:8]`、無明文路徑 |
| 跟「一鍵回滾」（2.8 §6.4） | 🟢 | 不影響 git tag 流程 |
| 跟「Reviewer 二審」（2.8 §6.3） | 🟢 | 本文件即為 V03 二審 |

### 1.4 設計決策點 (D1-D5): 🟡 NEEDS_REVIEW

| 決策 | 同意? | 理由 |
|---|---|---|
| **D1**: Commit Extension 進 repo | ✅ 同意 | 跟 sop-evolver 模式對齊、跨機器可移植；但要補 `.gitignore` 排除 `node_modules/`（如果有） |
| **D2**: `tool_call(TaskUpdate)` 觸發 | ✅ 同意 | 精準、不需 agent 記得——但**§2.3.2 程式碼必須改**，見 P0-1 |
| **D3**: 失敗用 `ctx.ui.notify("warning")` | ✅ 同意 | 但加註「建議聚合（每 session 只顯示一次）避免噪音」 |
| **D4**: skills_used 從 subject/description 抽 | 🟡 有保留 | heuristic 不可靠，v1 建議降級為 `["auto-observe"]` 或 `[]`，等 v1.1 再加 NLP |
| **D5**: 不支援 session-global | ✅ 同意 | v1 scope 縮小合理；但須**同時**標註 `project` / `memory` scope 也不支援 |

### 1.5 技術可行性: 🟢 FEASIBLE

| 檢查項 | 結果 | 證據 |
|---|---|---|
| Pi Extension `tool_call` 攔截 `TaskUpdate` 可行 | ✅ | `extensions.md:864-887` 範例；`pi-tasks/src/index.ts:836` 透過 `pi.registerTool({ name: "TaskUpdate" })` 註冊 |
| pi-tasks 任務檔位置 `.pi/tasks/tasks-{sessionId}.json` 正確（預設 scope） | ✅ | `pi-tasks/src/task-paths.ts:39` `workspaceSessionTaskFile()` |
| Extension 自動載入 `~/.pi/agent/extensions/*.ts` + `.pi/extensions/*.ts` | ✅ | `extensions.md:39-44` |
| TypeScript 需 build | ❌ | `extensions.md:79` "Extensions are loaded via jiti, so TypeScript works without compilation" |
| `ctx.sessionManager.getSessionId()` 可用 | ✅ | `extensions.md:763`、`1088-1099` |
| `ctx.cwd` 可用 | ✅ | `extensions.md:172-180` |

### 1.6 依賴與副作用: 🟡

| 檢查項 | 結果 | 證據 |
|---|---|---|
| 不破壞 install.sh 既有行為 | 🟡 | 新增 `install_pi_observe_hook()` 應只在 `pi` agent 時跑；install_rsi() 對 Claude 也跑，需加 `if [[ "$agent" == "pi" ]]` 條件 |
| 不跟 sop-evolver skill 重複 | 🟡 | 兩者**並存**，skill 寫觀察 vs Extension 寫觀察——需明確分工（建議：Extension 為主、skill 為備；skill觸發時檢查「Extension 已在 hook chain」可跳過） |
| 不破壞現有 191 個 bats 測試 | 🟢 | 新增檔案、新增函數，無修改既有測試的風險 |

### 1.7 安全: 🟡

| 檢查項 | 結果 |
|---|---|
| 觀察寫入失敗不阻塞任務 | ✅ try/catch + 不 throw |
| 觀察寫入失敗不洩漏敏感資料 | ✅ 失敗只 log warning，無堆疊/內容外洩 |
| 觀察**內容**不洩漏敏感資料 | 🟡 `note` 含 subject/description 全文——若用戶在 subject 寫機敏資訊會被記錄。建議加「subject/description 不應含機敏字串」SOP 提醒 |
| Schema 嚴格白名單 | ✅ ajv 驗證 + 多餘欄位 reject |
| 寫入原子性 | 🟡 未指定——建議 `write to temp + rename` 或 `flock` |

### 1.8 測試覆蓋: 🟡

5 個 bats 測試覆蓋 bash script 本體是 OK，但**遺漏 Extension TypeScript 程式碼的測試**：

| 測試類型 | 狀態 |
|---|---|
| bats 測試 `tools/observe-pi-task.sh` 邏輯 | ✅ 已列 5 個 |
| 端到端（pi session 跑 TaskUpdate → observation 寫入） | 🟡 §7 有規劃但偏 manual |
| Extension TypeScript 編譯/型別檢查 | 🟡 規劃 Gate 2 但需 `tsc --noEmit` |
| Extension 載入測試（pi啟動時不 crash） | ❌ 未列 |
| ajv schema 邊界 case（剛好 7 欄位 / 多 1 欄位 / 少 1 欄位） | 🟡 只列「多餘欄位 reject」 |
| 併發寫入 race condition | ❌ 未列 |
| `PI_TASK_LIST_ID` / `taskScope: "project"` edge case | ❌ 未列（v1 不支援也要列） |

**建議至少加 3 個測試**：schema 完整 7 欄位測試、PI_TASK_LIST_ID 警告測試、project_id SHA256 計算確定性測試。

### 1.9 替代方案評估: 🟢

設計 §2.1 評估的 4 個方案合理，但 §2.2 又加進 `tool_call(TaskUpdate)` 作為決策——**這是隱藏的第 5 個方案**，且 §2.1 表格未更新。建議補一個修正版對照表。

**其他可考慮但設計未提的方案**：

| 方案 | 優點 | 缺點 | 結論 |
|---|---|---|---|
| Pi Extension `tool_call` (TaskUpdate) — **最終選擇** | 精準、不依賴 agent | 需 pi | ✅最佳 |
| `before_agent_start` + `tool_result` 計算 gate_results | 可算真實 gate 結果 | 複雜度高、難驗證 | v2 再說 |
| 修改 sop-evolver skill 加 mandatory bash 呼叫 | 簡單 | 還是 agent 自律 | ❌ 不解決問題 |
| watch `.pi/tasks/*.json` filesystem watcher | 全自動、無 hook | 寫太多 noise、partial write | ❌ |

### 1.10 安裝方式: 🟡

設計 §2.3.3 提到「整合進 `install_rsi()`」，但未明示**只對 pi agent 安裝**。`install_rsi()` 對 Claude 和 Pi 都會跑（見 `install.sh:824-846`），但 Claude 沒有 Pi Extension 機制——需要：

```bash
install_rsi() {
  #既有：deploy sop-evolver skill + init ~/.tree-monstor/
  ...

  # 新增：only for pi agent
  if [[ "$agent" == "pi" ]]; then
    install_pi_observe_hook  # deploy .ts + .sh
  fi
}
```

或加獨立函數 `install_pi_observe_hook()` 並在 `install_pi()` 結尾呼叫。

---

## 2. Required Changes (必須改才能 merge)

### P0-1: 修正 §2.3.2 範例程式碼 — hook `TaskUpdate` 而非 `bash`

**位置**：`/tmp/auto-observe-design.md` §2.3.2
**問題**：範例程式碼 hook bash 命令含 "observe-pi-task"——這需要 agent 主動跑 bash 命令，無法解決「agent 自律不可靠」的原始動機
**最小修正**：

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";

const execFileAsync = promisify(execFile);

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // 只攔截 TaskUpdate 標記 completed
    if (event.toolName !== "TaskUpdate") return;
    if (event.input?.status !== "completed") return;

    const sessionId = ctx.sessionManager?.getSessionId?.() ?? "unknown";
    const taskId = String(event.input.taskId);
    const scriptPath = join(ctx.cwd, ".pi", "observe-pi-task.sh");

    // fire-and-forget（非阻塞、觀察失敗不影響 TaskUpdate 結果）
    execFileAsync(scriptPath, ["--task-id", taskId, "--session-id", sessionId], {
      cwd: ctx.cwd,
    })
      .then(() => ctx.ui.notify("RSI observation written", "info"))
      .catch((e) => ctx.ui.notify(`RSI observation failed: ${e.message?.slice(0, 200)}`, "warning"));
  });
}
```

**為何這樣改**：
- 攔截 `TaskUpdate` 直接由 LLM 觸發，**不需要 agent 記得**
- `execFileAsync` + 不用 await = 真正非阻塞
- 拿 `ctx.sessionManager.getSessionId()` 直接拿到 session ID
- `ctx.cwd` 直接是專案 cwd，不需要 `--cwd` 參數

### P0-2: 統一 §2.1 / §2.2 / §4 D2 的觸發決策

**位置**：`/tmp/auto-observe-design.md` §2.1 表格
**問題**：§2.1 選 `agent_end` ✅，§2.2 表格標 `tool_call(TaskUpdate)` ✅✅、§4 D2 選 `tool_call(TaskUpdate)`——三處矛盾
**最小修正**：§2.1 表格把 `agent_end` ✅ 改為 ❌，新增 `tool_call(TaskUpdate)` 為 ✅。

### P1-1: 修正 `task_id` 格式符合 UUID

**位置**：`/tmp/auto-observe-design.md` §2.3.1 observation schema
**問題**：`task_id: "<task.id>-<sessionId prefix>"` 不是 UUID（observation.md §3.1 規定 UUID）
**最小修正**：改為 `task_id: <task.id>`（pi-tasks 的 `task.id` 已是 `randomUUID()`，見 `task-store.ts` import）。

### P1-2: 修正 `gate_results.gate5_rsi: "pass"` 誤導值

**位置**：`/tmp/auto-observe-design.md` §2.3.1 observation schema
**問題**：Extension 是 fallback 寫入，RSI gate 並非真的「通過」——標 `pass` 會汙染聚合統計
**最小修正**：改為 `"auto"` 或 `"fallback"`，並在 observation.md §3.1 補一個 enum 值說明。

### P1-3: 修正 §2.3.3 install.sh 整合說明

**位置**：`/tmp/auto-observe-design.md` §2.3.3
**問題**：未明示只在 pi agent 安裝
**最小修正**：明文加「**只對 pi agent 跑**（Claude Code 不支援 Pi Extension）」。

### P1-4: 加 missing risks

**位置**：`/tmp/auto-observe-design.md` §3
**最小修正**：補 6 個 R-MISS（見 §1.2 表格）。

### P1-5: 加 Extension TypeScript 測試

**位置**：`/tmp/auto-observe-design.md` §6
**最小修正**：
- 加 `tsc --noEmit` 至 Gate 2 證據
- 加「手動 integration test」說明：啟動 pi session → 跑 TaskUpdate → `cat ~/.tree-monstor/observations/.../$(date).json` 確認有寫入
- 加「Extension 不 crash」測試：`pi -e ./extensions/auto-observe.ts` 能進入 prompt

### P1-6: 更新 sop-evolver SKILL.md 雙路徑說明

**位置**：`/tmp/auto-observe-design.md` §5 變更清單 + `.agents/skills/sop-evolver/SKILL.md`
**問題**：Extension 觸發 vs skill 觸發是兩條平行路徑，SKILL.md 完全沒提
**最小修正**：在 SKILL.md §4.1 加「**替代觸發**（v1.1+）：Pi Extension auto-observe hook，安裝後無需 agent 自律」段落。

### P1-7: 補 §2.3.1 的併發與原子寫入

**位置**：`/tmp/auto-observe-design.md` §2.3.1 step 4
**問題**：未說明多 task 連續完成時的併發保護
**最小修正**：加 `flock` 或「write to temp + rename」說明。

---

## 3. Optional Improvements (建議改但不擋 merge)

1. **skills_used v1 簡化**：D4 改為「v1 寫死 `["auto-observe"]`，v1.1 再加 heuristic」
2. **duration_seconds 單位明示**：pi-tasks 的 `createdAt`/`updatedAt` 是 `Date.now()`（毫秒），§2.3.1 要明示除以 1000
3. **§7 E2E 補 PI_TASK_LIST_ID edge case**：說明 v1 不支援時的預期行為（log warning + skip）
4. **note 欄位加 SOP 提醒**：「subject/description 不應含個資/原始碼片段」
5. **加 `.observed-tasks` 備援機制**：可選備份至 `~/.tree-monstor/observations/{project_id}/.observed-tasks.bak`
6. **加 `--disable-rsi` 對應說明**：`--disable-rsi` 應同時跳過 Extension 部署（設計未提）

---

## 4. 對 D1-D5 決策點的回應

| 決策 | 我方回應 | 建議調整 |
|---|---|---|
| **D1**: Commit Extension 進 repo | ✅ 同意 | 補 `.gitignore` 說明（如有 node_modules） |
| **D2**: `tool_call(TaskUpdate)` 觸發 | ✅ 同意 | **§2.3.2 程式碼必須改**（見 P0-1）|
| **D3**: `ctx.ui.notify("warning")` | ✅ 同意 | 加「每 session 只 notify 一次避免噪音」 |
| **D4**: skills_used heuristic | 🟡 有保留 | v1 降級為固定值，v1.1 再加 heuristic |
| **D5**: 不支援 session-global | ✅ 同意 | 同時標註 project/memory scope 也不支援 |

---

## 5. 風險分級: 🔴 HIGH

| 類別 | 等級 | 理由 |
|---|---|---|
| **設計正確性** | 🔴 HIGH | §2.3.2 程式碼與設計動機矛盾，無法達成「不依賴 agent 自律」 |
| **跨 SOP 一致性** | 🟡 MED | 主要 schema 一致，但 task_id 格式不符 |
| **技術可行性** | 🟢 LOW | Pi Extension + TaskUpdate 攔截技術完全可行 |
| **安全** | 🟡 MED | 觀察內容含 subject/description，需 SOP 提醒 |
| **測試覆蓋** | 🟡 MED | 5 個 bats 測試合理，但缺 Extension TypeScript 測試 |
| **依賴副作用** | 🟡 MED | install.sh 整合需明確 pi-only |

**總體**：HIGH（因 P0 blocker 修正前不可 merge）。

---

## 6. 跨 SOP 一致性檢查

- [x] 跟 2.8-rsi-evolution.md 一致（觀察/改動分離、4 條安全規則）
- [ ] 跟 observation.md schema **完全一致**（task_id UUID 格式不符，需 P1-1 修正）
- [x] 跟 gates.json Gate 5 一致（本文件即為 Gate 5 必經 verdict）
- [x] 跟 sop-evolver 安全原則一致（只觀察、不改 SOP）
- [ ] 跟 sop-evolver SKILL.md 一致（需補 Extension 觸發說明，P1-6）

---

## 7. 建議的下一步

1. **修正 P0-1**：改寫 §2.3.2 範例程式碼至 hook `TaskUpdate(status="completed")`
2. **修正 P0-2**：統一 §2.1 / §2.2 / §4 觸發決策
3. **修正 P1-1 ~ P1-7**：完成後重新送 V03 review
4. **修正後預期 verdict**：APPROVE 或 APPROVE_WITH_NITS（取決於 P1 修正完整度）
5. **審核後實作順序**（建議）：
   - Step 1: 寫 `tools/observe-pi-task.sh` + 5+ bats 測試（紅→綠，符合 Gate 1）
   - Step 2: 寫 `extensions/auto-observe.ts`（含 tsc --noEmit 通過）
   - Step 3: 改 install.sh 加 `install_pi_observe_hook()`（只 pi agent）
   - Step 4: 手動 integration test（pi session 跑 TaskUpdate → observation 寫入）
   - Step 5: 改 sop-evolver SKILL.md + 2.8 §7.4 加 auto-observe 說明
   - Step 6: 跑完整 bats suite（Gate 3 regression 確認不退步）

---

**Reviewer subagent** 完成於 2026-09-22
**對應 §2.3 Gate 4 (Reviewer Gate) + Gate 5 (RSI Gate)**：本文件即為必經 verdict
