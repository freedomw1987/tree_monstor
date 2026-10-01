---
name: dav-planner
description: 在 SOP「規劃」階段使用。透過多輪提問釐清「任務的背景、最終目的、驗收標準」，拆成可執行 Backlog（含 Story Point、INVEST AC、跨檔模板）。不問對話用戶的個人角色。
---

# Dav Planner

## TL;DR

1. **做什麼**：把用戶的模糊需求，透過多輪提問 → SWOT（如需要）→ 7 個維度展開 → 寫成可執行的 `docs/backlog.md` User Story（含 AC 範本）。
2. **何時觸發**：用戶提出新需求 / 模糊想法 / 待辦項目 / 任務拆分。
3. **預設 SOP 路徑**：§2.1 Plan Gate（在 §2.0 啟動後、§2.2 Design 前）。
4. **關鍵紀律**：
   - **V01**：一次一個問題（不一次問 4 個）
   - **V02**：方案必標推薦（⭐ 必為第一個）
   - **V03**：SOP 修改必走 Reviewer 二審
5. **必產出物**：
   - `docs/backlog.md` 新增 row + 詳細段
   - `docs/ac/<US-ID>.md`（含 Given-When-Then + DoD）
   - `docs/ac/<US-ID>.html`（列印友好版）

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 用戶提出新需求 | ✅ 必須 |
| 用戶提出模糊想法 | ✅ 必須 |
| 用戶列出待辦項目 | ✅ 必須 |
| 用戶要求任務拆分 | ✅ 必須 |
| 任務已執行（要交付）| ❌ 走 dav-submitter |
| **複雜開發任務（多文件 / 多來源 / 未來多次更新）** | **⚡ 建議 Step 1.5 來源抽取 → 調用 dav-wiki（需同套安裝）** |
| 純粹閱讀 / 查資料 | ❌ 不觸發 |
| 純粹提問（沒要做）| ❌ 不觸發 |

## 流程（Step 1-5 + Step 1.5 可選）

> **dav-planner 的核心定位**：釐清「任務的背景、最終目的、驗收標準」。**不問對話用戶的個人角色**（PM / 開發者 / 設計師 / 客戶），那是 §3 Persona（產品目標用戶）的事。

### Step 1：提問技巧（V01 / V02 / §2）

- **動作**：依 §2.1 問題類型 / §2.2 選項設計 / §2.3 追問節奏；V01 一次一題、V02 推薦放第一
- **為什麼**：避免一次問太多、用戶選擇困難
- **產出**：對話中每輪 1 題 + 2-4 個選項
- **證據**：對話格式符合 V01/V02
- **參考**：`reference.md` §2

### Step 2：決策點判斷（§2.5 / §2.6）

- **動作**：判斷是否任務升級（§2.5）、是否觸發 SWOT（§2.6）；如觸發則 Agent 草案 → 用戶驗證
- **為什麼**：避免「為分析而分析」、減少用戶決策負擔
- **產出**：對話中明示「是否升級 / 是否 SWOT」
- **證據**：對話有決策說明
- **參考**：`reference.md` §2.5 / §2.6

### Step 3：7 個維度展開（§3）

- **動作**：核心 4 維度（必問）+ 補充 5 維度（視情境展開）
- **為什麼**：7 維度是「真實需求」完整性檢驗
- **產出**：對話中 4+ 維度都有對話
- **證據**：對話覆蓋核心 4 維度
- **參考**：`reference.md` §3

### Step 4：成熟度評估 + 寫 Backlog（§5 / §4）

- **動作**：跑成熟度評估（涵蓋率 / 清晰度 / 可行性），3 維度都 ≥ 2 分才寫 Backlog
- **為什麼**：避免「需求不明就寫 US」
- **產出**：`docs/backlog.md` 新 row + 對應 `docs/ac/<US-ID>.md` + `.html`
- **證據**：成熟度評估表 + 3 檔都建立
- **參考**：`reference.md` §5 + `backlog-rules.md` §4

### Step 1.5：來源抽取（複雜開發任務可選）

> **位置**：Step 1.5 在 Step 1（背景收集）之後、Step 2（最終目的）之前觸發

**觸發條件**（以下任一即符合「複雜任務」）：
- 既有文件分散在 monorepo `docs/` 多份檔案（需求、決策、設變記錄）
- 來源檔案格式非 Markdown（PDF / DOCX / PPTX / 網頁 URL）
- 需求來源跨多個工具（Obsidian / Notion / Confluence / GitHub Issues）
- 你預期未來會**多次更新需求**（每次都要回到來源重新對照）
- 既有 dav-wiki 知識庫已收錄相關概念（先 grep `docs/concepts/` + `docs/wiki/_index.json`，命中 ≥ 1 條 → 直接讀、不需重新抽取）

**動作**：
1. 列出來源候選清單（檔案路徑 / URL / Obsidian Vault 位置）
2. 調用 **dav-wiki** skill（需同套安裝）：
   - 統一文件資料提取與 Markdown 化
   - 自動轉成結構化 Markdown 知識庫（含 frontmatter / tag / 概念 / 交叉引用）
3. 抽取完成後，**回到 Step 1**，**附加** Step 1 來源清單（既有口述 + 結構化 Markdown 並存、不取代口述）

**為什麼要這個步驟**：
- 規劃階段直接讀 PDF / DOCX 易遺漏關鍵段落
- dav-wiki 產出的結構化 Markdown 可被 dav-designer / dev-checker-loop / regression-guard 後續階段直接讀
- **未來需求更新時**：重新調用 dav-wiki 對照 → 自動標記「哪幾個 US 受影響」

**何時跳過**：
- 用戶已提供結構化 Markdown 來源
- 簡單單檔任務（單一 README.md / 單一 issue）
- 探索性原型（PoC）

**dav-wiki 未裝時的 fallback**：
- 退回「用戶口述」模式（同 Step 1 原有行為）
- 提示用戶「若本任務複雜、建議執行 install.sh 安裝 dav-wiki」
- 不報錯、只警告（軟引用精神）

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 一次只問 1 題（V01）| 確認型問題可一次多個 | 開放式問題必 1 題 |
| 方案必標 ⭐ 推薦（V02）| 開放式問題無推薦 | 必為第 1 個選項 |
| SOP 修改走 Reviewer 二審（V03）| 小型文字修正可跳 | 新增章節必走 |
| SWOT 不輕易觸發（§2.6）| 4 觸發條件之一即觸發 | 不可「為 SWOT 而 SWOT」 |
| AC 欄位精簡為「摘要 + 連結」（v1.8）| 存量 US 不重寫 | 新 US 必走新格式 |
| 反思併進 deliverable.md（v2.0）| 存量反思檔保留 | 未來不寫獨立反思 |
| 3 維度都 ≥ 2 分才寫 Backlog（§5）| 1 分項加 ⚠️ 註明 | 0 分項不可寫 |
| 每個 US 都產 .md + .html（同 turn）| 存量 US 不補 | 新 US 必走 |
| AC 範本只含 AC（不重複 US 標題）| N/A | §4.3.2.3 規範 |
| **複雜任務必走 Step 1.5（v2.6）** | **用戶已主動提供結構化 Markdown 來源** | **推薦 dav-wiki、避免手動抄 PDF；dav-wiki 未裝則退回用戶口述 + 提示安裝** |

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.6 | 2026-09-26 | +Step 1.5「來源抽取（複雜任務可選）」：位於 Step 1 後 Step 2 前；觸發條件 + 推薦調用 dav-wiki + 何時跳過 + dav-wiki 未裝 fallback | 用戶決策：複雜任務需求會多次更新、需要回原始來源；dav-wiki 已是 monorepo skill、軟引用而非強制耦合；V03 Reviewer 二審通過（verdict-3）；依賴 dav-wiki skill 需同套安裝 |
| v2.5 | 2026-09-26 | 自包含化：搬入 `examples/backlog.md`（原 monorepo 範例總目錄內的 docs 子目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/backlog.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.4 | 2026-09-26 | 清「具體 Module 完整生命週期範例的 path 引用」 → 抽象詞「見 monorepo 對應的 X」 | 修 v2.2 跨目錄讀檔引用零容忍存量；V03 Reviewer 二審通過 |

---
---

**交叉引用（純文字）**：
- 提問技巧 / 7 維度 / 成熟度 → 同套 `reference.md`
- Backlog 規則（含 Module 欄位範本 + Module 級 sprint）→ 同套 `backlog-rules.md`
- SOP §2.1 詳細內容 → 見 monorepo 對應的規劃文件（路徑由 monorepo 約定）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
- AC 範本格式範例 → 見 monorepo 對應的 AC 範本文件（路徑由 monorepo 約定）
- Module 完整生命週期範例 → 見本 skill 的 `examples/backlog.md`
