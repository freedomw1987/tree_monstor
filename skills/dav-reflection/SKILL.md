---
name: dav-reflection
description: 在 SOP「自我反省」階段使用。分層級（US / Sprint / Module）對執行階段交付物作 6 維度宏觀反思，產出併入 dav-submitter deliverable.md 末段，並更新 docs/backlog.md。
---

# Dav Reflection

## TL;DR

1. **做什麼**：對交付物作 6 維度（UX/UI / RWD / 技術債 / 可維護性 / 測試覆蓋率 / 需求對齊）宏觀反思，把發現的問題轉化為 Backlog item。
2. **何時觸發**：US 完成驗收後 / Sprint 結束 / Module 交付。
3. **預設 SOP 路徑**：§2.4 Reflection Gate（在 §2.3 完成、§2.5 提交前）。
4. **關鍵紀律**：
   - V01：US / Sprint / Module 三級別一次只談一個，避免混亂
   - V02：反省結論必附「動作 + 類型 + 驗收標準 + 預估」
   - v2.0 交付規則：反思併入 `docs/deliverable/<...>.md` 末段「## 反思」（不寫獨立檔）
   - v2.1 可選強化：若 `jev-use` 可用，6 維度逐項用 `jev_judge` 打分 + 反思結果驗證；不可用 → 軟性降級（純 LLM 評分、不中斷）
5. **必產出物**：`docs/deliverable/<YYYY-MM-DD>-<slug>.md` 末段「## 反思」+ `docs/backlog.md` 更新（問題 → Backlog item）

## 觸發時機

| 情境 | 觸發 |
|------|------|
| User Story 完成驗收 | ✅ Agent 自動 |
| Sprint 結束 | ✅ Agent + 用戶 |
| Module 交付 | ✅ Agent + 用戶 |
| 純提問 / 還沒執行任務 | ❌ 不觸發 |
| 任務部分完成 | ❌ 等完成後再觸發 |

## 流程（5 步）

### Step 1：確認反省範圍

- **動作**：判斷 User Story / Sprint / Module 三個層級之一；收集交付物（代碼、文檔、設計稿）
- **v2.1 新增 — jev 可用性偵測**：執行 `which jev-use`；可用則設定 `JEV_AVAILABLE=true`、後續 Step 2 走 jev 嵌入流程；不可用則跳過 jev 步驟、純 LLM 評分、降級為原本流程；對話中明示「jev 模式：on/off」
- **v2.1 內部失敗 fallback**（S3）：jev 內部失敗（API key 缺失 / 網路錯誤 / jev_judge 拋例外）→ 視同 `JEV_AVAILABLE=false`、走軟性降級、不 fail-fast
- **為什麼**：不同層級的反省深度不同（US 輕量、Sprint 標準、Module 深度）
- **產出**：對話中明示「本次反省層級 = X」
- **證據**：對話中有「US / Sprint / Module」字樣

### Step 2：檢查 6 維度

- **動作**：逐維度標記 ✅ 通過 / ⚠️ 有風險 / ❌ 不通過；每個 ❌ 必含「根因 + 建議」
- **v2.1 新增 — jev 逐維度打分**（限 `JEV_AVAILABLE=true`）：每個維度用 `jev_judge`（**僅 score 類型**，三檔 ✅/⚠️/❌）獨立評分；jev 結果與 LLM 自評比對，不一致時以 LLM 為準、但 jev 結果附在反思段備註；**輕量路徑（S2）**：US 級別反省只打關鍵 2 維度（需求對齊 + 測試覆蓋率），避免過重；這只是輔助、不取代 LLM 評分
- **v2.1 新增 — 反思結果驗證**：6 維度結果出來後用 `jev_judge`（noul）驗證「這個反省結論有沒有遺漏風險」；`escalate: true` → 標記 ⚠️ 待確認，列在 deliverable「## 反思」段「⚠️ jev escalate 待確認」清單（**不寫在 checklist.md**），不在對話中自己補
- **v2.1 術語說明**（B2）：本 skill 只用 `score` 類型（6 維度單類打分）；dev-checker-loop 用 `noul / choice / score` 三類混合（聚焦不同風險類型），兩者屬設計選擇、不是錯
- **v2.1 jev 對接模板**：6 維度對應的 jev_judge 問題模板見 `checklist.md` 「## 7. jev_judge 對接表」
- **為什麼**：6 維度是檢驗「交付物是否真的好」的核心
- **產出**：對話中 6 維度檢查表
- **證據**：6 個維度都有標記，每個 ❌ 有根因 + 建議

### Step 3：產出反思段落（v2.0：併進 deliverable）

- **動作**：將反思內容併入 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md` 末段「## 反思」（依 `dav-submitter` 模板 `## 8. 反思`）
- **為什麼**：v2.0 規則（取消獨立反思檔，避免重複記錄）
- **產出**：`docs/deliverable/<...>.md` 含 `## 反思` 段
- **證據**：bats 探針驗證存在；不寫 `docs/reflection/<...>.md`

### Step 4：轉化為 Backlog item

- **動作**：每個發現的問題在 `docs/backlog.md` 新增對應類型的 Backlog item：
  - 技術債 → `TECH-XXX`
  - Bug → `DE-XXX`
  - 缺失功能 → `US-XXX`
  - 需研究 → `SPIKE-XXX`
- **為什麼**：反省的目的不是抱怨，是產出可執行 Action Items
- **產出**：`docs/backlog.md` 新增 row + 對應優先級（P0/P1/P2）
- **證據**：backlog.md 表格新增 row

### Step 5：跟用戶確認 Action Items

- **動作**：列出哪些立即處理、哪些放入下個 Sprint；Sprint / Module 級別必有用戶參與
- **為什麼**：用戶最終決策，避免 Agent 自行決定優先級
- **產出**：對話中明示「待用戶確認 Action Items」
- **證據**：對話有「待確認」字樣

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 反思必含 6 維度檢查 | N/A | 不可跳過維度 |
| 每個 ❌ 必含「根因 + 建議」 | N/A | 不可只標 ❌ 不解釋 |
| 問題必轉化為 Backlog item | 「已知但本 sprint 不修」可記 Action Items 內 | 不留在對話 |
| Sprint / Module 必有用戶參與 | US 級別 Agent 自動 | 不可越權 |
| 反思併入 deliverable.md（v2.0）| v1.7.1 / v1.8 / v1.9 存量獨立反思檔保留 | 未來不寫獨立檔 |
| US 級別反省要輕量 | Sprint / Module 可深度 | US 不做架構層級反省 |
| **jev 軟性降級**（v2.1 新增）| N/A | jev-use 未安裝時跳過 jev 步驟、繼續原本反省、不中斷流程 |
| **jev escalate 降級為人類決策**（v2.1 新增）| N/A | jev 信心不足時標 ⚠️ 待確認、寫進 deliverable.md `## 反思` 段「⚠️ jev escalate 待確認」清單、不自己補（**不寫在 checklist.md**）|
| **jev 不取代 LLM 評分**（v2.1 新增）| N/A | jev 只能輔助；LLM 評分仍必跑、不一致時 LLM 為準 |
| **US 級別 jev 只打 2 維度**（v2.1 新增，輕量路徑 S2）| Sprint / Module 級別打全部 6 維度 | 避免 US 級別過重 |
| **jev 內部失敗 fallback**（v2.1 新增，S3）| N/A | jev 內部錯誤視同不可用、走軟性降級、不 fail-fast |
| **M-Step 3 必跑探針**（v2.1 新增，B3）| 純錯字修正例外 | 改檔後必跑 `bats tests/restruct-dav-reflection.bats` 全綠 |

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段（TL;DR / 觸發 / 流程 / 規則 / 變動歷史）| TMO-009 階段 1 PoC：LLM 注意力優化 |
| v2.0 | 2026-09-26 | 反思併進 deliverable.md 末段（v2.0 規則）| TMO-008 減法：取消獨立反思檔 |

---
---

**交叉引用**：
- SOP §2.4 詳細內容 → 見 monorepo 對應的反省指南文件（路徑由 monorepo 約定）
- 交付物模板（含 `## 反思` 段）→ 見同套 dav-submitter 的子檔（需同套安裝）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
