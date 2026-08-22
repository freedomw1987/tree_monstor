# TD-016 交付摘要 — `mandatory_phrase` 機制讓 SOP 規範真正生效

**日期**：2025-08-22
**Backlog ID**：TD-016（P2，2 SP）
**作者**：Agent
**狀態**：✅ 完成

---

## 摘要

US-008 揭露 SOP 規範形式大於實質（Agent 雖按 Gate 流程做，但未即時引用 gates.json）。
本任務透過**雙層強制**讓規範真正生效：
1. **Schema 層強制**：`mandatory_phrase` 欄位 + pattern 規則 `^依 gates.json 規範`，錯的會被 ajv reject
2. **AGENTS.md 指示**：「進 Gate 必須引用」明確寫入 SOP 文件

---

## 變更清單

| 檔案 | 改動 |
| --- | --- |
| `docs/sop/gates.json` | 4 個 Gate 各加 `mandatory_phrase` 欄位（共 +4 個 string 物件）|
| `docs/sop/gates.schema.json` | `mandatory_phrase` 加入 `required` + 加 `pattern: "^依 gates.json 規範"` |
| `AGENTS.md` §2.3 | 加「⚠️ Agent 必須做的動作」警示塊，引用 gates.json `mandatory_phrase` 規範 |

---

## 驗收證據

### 依 gates.json 規範，Gate 2 (lint) 需要：ajv valid

| 測試 | 結果 |
|---|---|
| `python3 -m json.tool` | 0 error（兩個檔）|
| `ajv validate -s ... -d ...` | `docs/sop/gates.json valid` ✅ |
| Pattern 規則測試（故意用錯的 phrase）| **驗證失敗（returncode=1）**，證明 pattern 規則有效 |

### 依 gates.json 規範，Gate 3 (regression) 需要：完整測試套件跑過

| 階段 | 通過 / 失敗 |
|---|---|
| Baseline（TD-016 改動前）| 42 / 0 |
| After（TD-016 改動後） | 42 / 0 |
| Diff | 0 變動（純文件改動）|

### 依 gates.json 規範，Gate 4 (reviewer) 需要：5 項手工檢查全綠

| 檢查項 | 結果 |
|---|---|
| 4 個 Gate 都含 `mandatory_phrase` | ✅ |
| Schema 含 `pattern: ^依 gates.json 規範` | ✅ |
| AGENTS.md §2.3 含 Agent 動作指示 | ✅ |
| ajv valid | ✅ |
| Schema pattern 確實生效 | ✅ |

### TDD gate 1

TD-016 純文件改動，符合 gates.json Gate 1 `notes` 欄豁免條件。

---

## 已知問題

無

---

## 下一步建議（V20）

- **驗收方式**：
  1. 跑 `python3 -c "import json; print(json.load(open('docs/sop/gates.json'))['gates'][0]['mandatory_phrase'])"` 看 4 個 phrase
  2. 跑 `ajv validate -s docs/sop/gates.schema.json -d docs/sop/gates.json` 仍 valid
  3. 故意用錯的 phrase → ajv 拒絕驗證
- **預估時間**：< 5 分鐘
- **風險提示**：
  - ⚠️ **R1**：Agent 仍可能在對話**不引用** mandatory_phrase — 本任務**只是讓規範可被引用、可被驗證**，但無法強制 Agent 必須引用（需 agent 框架層支持，見 O1）
  - ⚠️ **R2**：未來若有人修改 `mandatory_phrase`，Schema pattern 仍只檢查「依 gates.json 規範」開頭 — 後續內容可自由編輯（設計取捨：避免 pattern 太嚴反而綁死）

---

## 觀察（O1，未來可考慮）

| # | 觀察 | 影響 |
| - | -- | -- |
| O1 | 本任務讓 SOP 規範**可被引用、可被驗證**，但**無法強制 Agent 必須引用**。若要做到框架層強制，需把 gates.json 注入 pi agent 的 system prompt 或 AGENTS.md 開頭的「Agent 上下文」 | P2 — 等下個 sprint 評估是否值得做 |