---
name: dav-submitter
description: 在 SOP「提交成果」階段使用。產出交付摘要（對話輸出 ＋ Markdown，含反思末段），讓用戶即時驗收並留下可追溯的交付歷史。不用於未執行任務、純提問；v2.0 起僅 Markdown，不產 HTML。
---
# Dav Submitter

## TL;DR
1. **做什麼**：完成單元任務（US／子任務／Bug 修復／技術債）後產交付摘要，等用戶即時驗收 ＋ 留可追溯交付歷史。
2. **何時觸發／SOP 路徑**：單元任務完成驗收後；§2.5 Submit Gate（§2.4 Reflection 完成後、commit 前）。
3. **關鍵紀律**：V01 對話一次只談一個任務；V02 下一步建議必含「驗收方式／預估時間／風險提示」；v2.0 兩層產出物（對話 ＋ Markdown）、**不產 HTML**；反思**併進** Markdown 末段「##
反思」；v2.1 每次交付必明示「為什麼做這個改動／為什麼這個設計／為什麼放棄其他選項」。
4. **v2.5 需求對帳硬門檻**：本次 US 有需求錨點時，交付摘要必含「需求對帳」段；對帳未全數對上 → 狀態**不得**標「✅ 完成」，只能「⚠️ 部分完成」＋ 待補清單。
5. **必產出物**：對話摘要（90 秒可讀，含「為什麼」獨立段）＋ `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`（含「為什麼」獨立段 ＋ 反思末段 ＋ 需求對帳段；只留最近一次 →
`./retention.md`）。

## 觸發時機
- **US／子任務／Bug 修復／技術債完成驗收、Sprint 結束、Module 交付** → ✅ 必須（Sprint／Module 級別 Step 3.5 反省做全 6 維度；Module 級交付細節見同套
`./module-delivery.md`）
- **純提問、未執行任務** → ❌ 不觸發

## 流程（5 步）
- **Step 1 確認交付範圍**：確認對應 Backlog item（US／DE／TECH／SPIKE ID）、Sprint／Module、收集變更清單（檔案、測試、文檔）；對話明示「Backlog = X、Module = Y」
- **Step 2 對話摘要**：90 秒內可讀，讲「做了什麼／**為什麼**／下一步」，「為什麼」獨立一段、唔混喺「做了什麼」；對話輸出含 emoji 標記 ＋ **「為什麼」獨立段**
- **Step 3 寫 Markdown 詳錄**：套用同套 `./template.md` 模板（含 `## 1.2 為什麼做這個改動`、`## 2.4 改動背後的理由`、`## 8. 反思` 段）→
`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`；詳錄係 audit trail（反思 ＋ 判斷理由）
- **Step 3.5 反省**：判斷層級（US／Sprint／Module）→ 逐項檢查 **6 維度**（UX/UI 一致性／RWD／技術債／可維護性／測試覆蓋率／需求對齊）→ 每個 ❌ 必含「根因 ＋ 建議」→ 產出 Action
Items（動作 ＋ 類型 ＋ 驗收條件 ＋ 預估）；US 級只檢查關鍵 2 維度（需求對齊 ＋ 測試覆蓋率），Sprint／Module 級做全 6 維度
- **Step 4 誠實標註問題 ＋ 下一步**：第 5 節「已知問題」誠實填寫（含 pre-existing）；第 6 節「下一步建議」必含「驗收方式／預估時間／風險提示」
- **Step 4.5 需求對帳結論**：本次 US 有需求錨點 → 取 §2.3 尾段對帳（同套 `dav-reconciler` skill）嘅對帳表，填入交付摘要 §3.1「需求對帳」段（需求 ID／狀態／實作位置／證據／覆蓋率）；對帳有
  「部分實作／未實作」、缺對帳段、R-ID 未覆蓋、降級未標註 → 狀態**不得**標「✅ 完成」，只能「⚠️ 部分完成」＋ 待補清單（無對帳段 = 用戶睇到嘅係「執行者自述」而非「第三方判定」）
- **Step 5 更新 Backlog ＋ 確認下一步**：更新 `docs/backlog.md` 狀態 → **完成（done）嘅 row 要移出**（記錄去交付摘要 ＋ 需求錨點 ＋ git history），backlog
只剩未完成（todo／doing／⏸️）row；對話提示用戶下一步做什麼 ＋ 具體選項（保留策略見同套 `./retention.md`；backlog 細節見同套 `dav-planner` skill）

## 規則 / 例外 / 限制
- **兩層交付物（對話 ＋ Markdown，v2.0 起不寫 HTML）＋ Markdown 必含 8 段（含反思末段）** — 例外：小任務可精簡次要段；限制：§1 / §2 / §3 / §5 / §6 / §8 不可少
- **反思併進 `## 反思` 段（v2.0）** — 例外：v1.7.1 / v1.8 / v1.9 獨立反思檔保留；限制：未來不寫獨立反思檔
- **對話摘要 ≤ 90 秒可讀 ＋「為什麼」必含（v2.1）** — 例外：Module 級交付可稍長／緊急修復可簡為一句話；限制：不超過 200 行對話；對話摘要 ＋ Markdown §1.2 ＋ §2.4 都必含
- **下一步建議必含 3 項（驗收／預估／風險）** — 例外：緊急修復可精簡；限制：不可只寫「待續」
- **必誠實標註已知問題** — 例外：N/A；限制：不可「假完成」
- **命名：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`** — 例外：N/A；限制：日期用 ISO、slug 用 kebab-case
- **Module 級交付可觸發（v2.2 新增）** — 例外：預設 US 級交付；限制：Module 級需在對話明示「Module 級交付」
- **需求對帳硬門檻（v2.5 新增）** — 例外：本次 US 無需求錨點（存量任務）；限制：對帳未全數對上 → 不得標「✅ 完成」；缺對帳段 → 視同未對帳
- **Backlog 只留未完成 ＋ 交付摘要只留最近一次（`./retention.md`）** — 例外：`⏸️` 暫停要留；引用鏈要留低；限制：移出前先 commit
- **術語一致（跟專案層術語表）** — 例外：專案層冇術語表 → 照常用詞；限制：專案層有 `docs/glossary_list.md` → 交付摘要同對話一律用入面嘅術語（術語表規格見同套 `dav-planner` skill）

## 交叉引用（純文字）
- Markdown 詳錄模板（含 `## 反思` 段 ＋ v2.1 為什麼必含）→ 同套 `./template.md`；Module 級交付細節 → 同套 `./module-delivery.md`；保留 vs 歸檔策略 → 同套
`./retention.md`
- 反省流程（6 維度 ＋ 三級別模板）→ 同套 `./reflection-checklist.md` ＋ `./reflection-templates.md`；交付摘要 ＋ Module 交付樣本 → 同套
`./examples/deliverable-sample.md`；SOP §2.5 詳細內容 → 見 monorepo 對應的提交指南文件（路徑由 monorepo 約定）
