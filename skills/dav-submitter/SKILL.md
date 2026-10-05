---
name: dav-submitter
description: 在 SOP「提交成果」階段使用。產出交付摘要（對話輸出 + Markdown，含反思末段），讓用戶即時驗收並留下可追溯的交付歷史。v2.0 起僅 Markdown，不產 HTML。
---

# Dav Submitter

## TL;DR

1. **做什麼**：完成單元任務（US / 子任務 / Bug 修復 / 技術債）後，產出交付摘要讓用戶即時知道完成什麼、有什麼價值。
2. **何時觸發**：單元任務完成驗收後。
3. **預設 SOP 路徑**：§2.5 Submit Gate（在 §2.4 Reflection 完成後、commit 前）。
4. **關鍵紀律**：
   - V01：對話摘要 + Markdown 詳錄，一次只談一個任務
   - V02：下一步建議必含「驗收方式 / 預估時間 / 風險提示」
   - v2.0 交付規則：兩層產出物（對話 + Markdown），**不產 HTML**；反思**併進** Markdown 末段「## 反思」
   - **v2.1 為什麼必溝通**：每次交付必明示「為什麼做這個改動 / 為什麼這個設計 / 為什麼放棄其他選項」 — 不是只有「做了什麼」、更是「為什麼這樣做」。讓用戶驗收時不只看「做了什麼」，更理解「為什麼」
5. **必產出物**：
   - 對話摘要（90 秒可讀，含「為什麼」獨立段）
   - `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`（含「為什麼」獨立段 + 反思末段）

## 觸發時機

| 情境 | 觸發 |
|------|------|
| User Story 完成驗收 | ✅ 必須 |
| 子任務完成 | ✅ 必須 |
| Bug 修復完成 | ✅ 必須 |
| 技術債處理完成 | ✅ 必須 |
| Sprint 結束 | ❌ 屬於 dav-reflection 宏觀總結 |
| Module 交付 | ❌ 屬於 dav-reflection 宏觀總結 |
| 純提問、未執行任務 | ❌ 不觸發 |

### v2.2 Module 級交付（新場景）

> v2.2 起：dav-submitter 可交付單個 Module（不只是單個 US）。

| 場景 | 交付單位 | 適合 skill |
| --- | -------- | ----------- |
| **單個 US 交付** | 1 個 AC 套件 | dav-submitter（本 skill）|
| **單個 Module 交付** | Module 內所有 US 集合 | dav-submitter（本 skill）+ dav-reflection 微總結 |
| **多個 Module 交付** | Module 集合 + cross-module integration | dav-reflection 宏觀總結 |
| **整個 repo / sprint 結束** | 整個交付歷史 | dav-reflection 宏觀總結 |

**Module 級交付的差異**：

1. **Backlog ID 格式**：`<MODULE_CODE>-<US_ID>`（如 `M01-US-101`、`M02-US-203`）；多 US 同 Module 交付時在 §2.1-2.3 用 `M01 多 US 集合` 代表
2. **Module 邊界即測試邊界**（v2.8 dev-checker-loop 規則）：探針必含 Module prefix；交付檔必明記 Module
3. **deliverable.md 命名**：`docs/deliverable/<YYYY-MM-DD>-<module>-<slug>.md`（Module 級）或原本
   `<YYYY-MM-DD>-<task-slug>.md`（US 級）
4. **Module 交付有「第 9 段」**：§9 Module 級總結（包含多 US 間的關聯、跨 Module 遺留問題、Module 級技術債）

詳見 `module-delivery.md` 子檔（v2.2 新增）。

## 流程（5 步）

### Step 1：確認交付範圍

- **動作**：確認對應 Backlog item（US / DE / TECH / SPIKE ID）、對應 Sprint / Module、收集變更清單（檔案、測試、文檔）
- **為什麼**：交付必對應 Backlog ID + Module（v2.2 起），避免「不知道交付什麼、屬哪個 Module」
- **產出**：對話中明示「對應 Backlog = X、Module = Y」
- **證據**：對話有 Backlog ID + Module 代碼字樣

### Step 2：在對話中輸出簡單摘要（含「為什麼」獨立段）

- **動作**：用 90 秒內可讀完的長度講「做了什麼 / **為什麼** / 下一步」；「為什麼」獨立一段、不混在「做了什麼」中
- **為什麼**：對話摘要是用戶即時通知，不需過度包裝；但「為什麼」獨立才能讓用戶驗收時快速判斷決策是否對
- **產出**：對話輸出（含 emoji + 表格 + **「為什麼」獨立段**）
- **證據**：對話摘要 ≤ 90 秒可讀 + 含「為什麼」段

### Step 3：寫 Markdown 詳錄（含「為什麼」獨立段 + 反思末段）

- **動作**：套用 `skills/dav-submitter/template.md` 模板（含 `## 1.2 為什麼做這個改動`、`## 2.4 改動背後的理由`、`## 8. 反思` 段），寫入
  `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`
- **為什麼**：v2.0 規則；v2.1 加「為什麼」獨立段；Markdown 詳錄是 audit trail（含反思 + 設計判斷理由）
- **產出**：`docs/deliverable/<...>.md` 完整檔案（含為什麼）
- **證據**：bats 探針驗證檔案存在；包含「為什麼做這個改動」段 + `## 反思` 段

### Step 4：誠實標註問題 + 下一步

- **動作**：第 5 節「已知問題」誠實填寫（含 pre-existing）；第 6 節「下一步建議」必含「驗收方式 / 預估時間 / 風險提示」
- **為什麼**：避免「假完成」、給用戶實際可執行的下一步
- **產出**：deliverable.md §5 + §6 段
- **證據**：§5 有問題標註、§6 有 3 項必含

### Step 5：更新 Backlog + 確認下一步

- **動作**：對應 `docs/backlog.md` 已更新；提示用戶下一步要做什麼、提供具體選項
- **為什麼**：Backlog 同步狀態；引導用戶繼續 SOP 第一步
- **產出**：對話中「下一步建議」段
- **證據**：對話有具體下一步選項

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 兩層交付物（對話 + Markdown）| N/A | v2.0 起**不寫 HTML** |
| Markdown 必含 8 段（含反思末段）| 小任務可精簡次要段 | §1 / §2 / §3 / §5 / §6 / §8 不可少 |
| 反思併進 `## 反思` 段（v2.0）| v1.7.1 / v1.8 / v1.9 獨立反思檔保留 | 未來不寫獨立反思檔 |
| 對話摘要 ≤ 90 秒可讀 | Module 級交付可稍長 | 不超過 200 行對話 |
| 下一步建議必含 3 項（驗收/預估/風險）| 緊急修復可精簡 | 不可只寫「待續」 |
| 必誠實標註已知問題 | N/A | 不可「假完成」 |
| 命名：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md` | N/A | 日期用 ISO、slug 用 kebab-case |
| **「為什麼」必含（v2.1 新增）** | 緊急修復可簡為一句話 | 對話摘要 + Markdown §1.2 + §2.4 都必含 |
| **Module 級交付可觸發（v2.2 新增）** | 預設 US 級交付 | Module 級需在對話明示「Module 級交付」|

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.4 | 2026-09-26 | 合併 v2.3（清存量）+ 本次自包含化：合併理由 — 主檔 4 條已達 v2.4 規範上限，再加會違規；可追溯性由 CHANGELOG.md 補條目保證；V03 Reviewer 二審通過 | 一次性清掉路徑抽象詞（v2.3 動作）+ 搬入 `examples/deliverable-sample.md`（本次動作），避免主檔變 5 條 |
| v2.2 | 2026-09-26 | +Module 級交付：觸發時機 + 命名規則（`<module>-<slug>`）+ §9 Module 級總結 + 拆 `module-delivery.md` 子檔 | 用戶選 4 個後續任務之一；v2.8 dev-checker-loop / regression-guard 鋪好 Module 基礎，本 skill 補完 Module 級交付語法 |
| v2.1 | 2026-09-26 | 每次交付必含「為什麼」獨立段：主檔 Step 2-3 + 規則表加 1 條；template.md §1.2「為什麼做這個改動」+ §2.4「改動背後的理由」+ §6.1「為什麼這個優先」 | 用戶要求交付時也要溝通「為什麼」會做這樣的修改，不只「做了什麼」 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 | TMO-009 階段 2：LLM 注意力優化 |

---
---

**交叉引用**：
- SOP §2.5 詳細內容 → 見 monorepo 對應的提交指南文件（路徑由 monorepo 約定）
- Markdown 詳錄模板（含 `## 反思` 段 + v2.1 為什麼必含）→ 見同套本 skill 子檔（`./template.md`）
- Module 級交付細節 → 見同套本 skill 子檔（`./module-delivery.md`）
- 反思觸發 → 見同套 dav-reflection skill（需同套安裝）
- Module 完整生命週期範例（含 v2.2 Module 級交付樣本）→ 見本 skill 的 `examples/deliverable-sample.md`
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
