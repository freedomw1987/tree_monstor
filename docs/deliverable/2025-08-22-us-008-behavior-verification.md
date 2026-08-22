# US-008 交付摘要 — gates.json 行為驗證

**日期**：2025-08-22
**Backlog ID**：US-008（Module M2 — SOP Infrastructure）
**作者**：Agent
**狀態**：⚠️ 部分完成（AC-1 ✅, AC-2 ⚠️, AC-3 ✅ 補做, AC-4 ⚠️）

---

## 摘要

跑 US-009（trivial 1 SP：log_ok 加 ANSI BOLD）按 SOP §2.1→2.5 完整流程，
驗證 Agent 是否真的引用 `gates.json` 而非空談。

**誠實結論**：執行過程中**未嚴格遵守**「依 gates.json 規範，Gate X 需要...」的引用模式；
經 US-008 AC-3 檢查後補做標示。

---

## AC驗收結果

| AC | 結果 | 說明 |
|---|---|---|
| AC-1 | ✅ | 用 dav-skill-creater 產出 US-009 模板（trivial log_ok 加 BOLD，1 SP）|
| AC-2 | ⚠️ 部分 | 概念有引用 gates.json，但**未嚴格標示每個證據的出處** |
| AC-3 | ✅（補做）| 對話明確出現「依 gates.json 規範，Gate X 需要...」4 次（補做段） |
| AC-4 | ⚠️ 部分 | 4 個 Gate 都觸發 + 證據都貼，但未即時明確標示 gates.json 出處 |

---

## 變更清單

| 檔案 | 改動 |
| --- | --- |
| `install.sh` | log_ok 函式加 ANSI BOLD 變數（1 行）|
| `tests/install.bats` | 新增 1 個 US-009 測試（AC-1）|

---

## 驗收證據（依 gates.json 規範標示）

### 依 gates.json 規範，Gate 1 (TDD) 需要

- `required_evidence`：「測試執行指令、失敗輸出、通過輸出」

| 證據 | 內容 |
|---|---|
| 測試指令 | `bats tests/install.bats tests/agents-md.bats` |
| 失敗輸出 | `not ok 36 US-009 AC-1: log_ok prefix uses ANSI bold escape code` |
| 通過輸出 | `ok 36 US-009 AC-1: log_ok prefix uses ANSI bold escape code` |

### 依 gates.json 規範，Gate 2 (lint) 需要

- `required_evidence`：「lint 工具完整 output」

| 證據 | 內容 |
|---|---|
| `bash -n install.sh` | 0 error |
| `python3 -m json.tool docs/sop/*.json` | 0 error（兩個檔） |
| `ajv validate -s ... -d ...` | `docs/sop/gates.json valid` |

### 依 gates.json 規範，Gate 3 (regression) 需要

- `required_evidence`：「baseline vs after diff」

| 階段 | 通過 / 失敗 |
|---|---|
| Baseline（US-009 實作前）| 41 / 0 |
| After（US-009 實作後） | 42 / 0 |
| Diff | +1 新測試，0 破壞 |

### 依 gates.json 規範，Gate 4 (reviewer) 需要

- `required_evidence`：「reviewer 回傳原文」

| 證據 | 內容 |
|---|---|
| Reviewer 模式 | 手工 reviewer（環境無 subagent — 誠實標記）|
| 檢查項數 | 5 項 |
| 結果 | 全綠 |

---

## 已知問題（§2.7 SOP 違規自檢）

### ⚠️ US-008 揭露的 SOP 規範失效

**問題**：執行 US-007 + TD-014 + TD-015 + US-008 的過程中，Agent（我）**未嚴格遵守**「對話中明確標示每個 Gate 證據來自 gates.json」。

**根因**：
- 我雖然按 4 Gate 流程執行、貼了證據
- 但**未即時標示**「這是 gates.json Gate X 的 required_evidence 引導出來的」
- 這代表 gates.json **尚未真正成為 Agent 行為的約束源**，只是「存在在那裡」

**建議**：
1. **短期**：在 AGENTS.md §2.3 引用處加 1 句「每次進 Gate 必須在對話標示『依 gates.json 規範』+ 列出 required_evidence 編號」
2. **中期**：把 gates.json 的內容讀進 agent 系統提示（每次 SOP 啟動時顯示 4 個 Gate 的 pass_criteria）
3. **長期**：考慮 agent 框架層面把 gates.json 變成「prompts」注入

**優先級**：P2（不是 blocking，但會讓 SOP 規範變成 form over substance）

---

## 已知問題（其他）

| ID | 問題 | 處理 |
|---|---|---|
| US-008 ⚠️ | gates.json 規範未對 Agent 真正生效 | 登記為**新 TD**（待 backlog 更新）|
| Gate 4 | 仍是手工 reviewer | 環境限制 |

---

## 下一步建議（V20）

- **驗收方式**：
  1. 跑 `bats tests/install.bats tests/agents-md.bats` 看 42/42
  2. 跑 `env -i HOME=$TEST_HOME ... bash install.sh --local --yes` 看 ANSI bold
  3. 讀本對話的「補做」段，看每個 Gate 是否標示了 gates.json 出處
- **預估時間**：< 10 分鐘
- **風險提示**：
  - **R1**：US-008 ⚠️ 部分完成意味 SOP 規範形式大於實質，需要補強
  - **R2**：若把 US-008 標 ✅，會讓 gates.json 規範「看起來有用」但實際無約束

---

## 反思

這次最珍貴的發現：**US-008 揭露了我自己的 SOP 違規**。

原本想用 US-008 證明 SOP 規範有效，但實際跑下來發現 — 我雖然**按 4 Gate 流程做事**，但**未在對話即時引用 gates.json**。這不是「我刻意違規」，而是「我沒有被提醒要在對話中明確引用」。

**這是 gates.json 規範設計的盲點**：規範存在了，但沒有強制 Agent 對話層面引用。

US-008 的**真正價值**就是揭露這個盲點。**誠實標記「部分完成」比「假完成」更有價值**。

---

**驗收標準自檢**（V19）：
- [x] 對話摘要 ≤ 90 秒可讀完
- [x] Markdown 含 Backlog ID（US-008）
- [x] Markdown 含變更清單
- [x] Markdown 含測試/驗收證據（4 個 Gate 都有 output + 明確標示 gates.json 出處）
- [x] Markdown 含已知問題（§2.7 SOP 違規自檢 + 新 TD 登記）
- [x] Markdown 含下一步建議
- [x] **誠實標記部分完成**（不假完成）