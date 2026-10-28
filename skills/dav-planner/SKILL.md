---
name: dav-planner
description: >-
  在 SOP「規劃」階段使用。透過多輪提問釐清「任務的背景、最終目的、驗收條件」，拆成可執行 Backlog（含 Story Point、INVEST AC、跨檔模板）。不用於純提問／純查資料，亦不用於任務已進入交付階段。
---

# Dav Planner

## TL;DR

1. **做什麼**：多輪提問（核心 4 維度必問 ＋ 觸發咗嘅補充維度）→ 需求成熟度評估（3 維度 ≥ 2 分）→ 寫 `docs/backlog.md` User Story ＋ AC ＋ 需求錨點 ＋ 術語表。
2. **何時觸發／SOP 路徑**：新需求／模糊想法／待辦項目／要求任務拆分；Plan Gate（Design 之前）。
3. **關鍵紀律**：V01 一次一題、V02 推薦放第一、V03 改規範自查行數上限（代碼品質把關走同套 `dav-developer` skill）。
4. **必產出物**：`docs/backlog.md` row ＋ 詳細段、`docs/ac/<US-ID>.md`（含 Given-When-Then ＋ DoD）＋
`.html`（列印友好版）、`docs/req/<US-ID>-requirement.md`（需求錨點：原話區唯讀 ＋ R-ID 化）、`docs/glossary_list.md`（條件式：專屬術語 ≥ 3 條）。
5. **唔問對話用戶的個人角色**（PM／開發者／設計師／客戶）—— 嗰啲係產品目標用戶（Persona）嘅事。

## 觸發時機

- **新需求／模糊想法／待辦項目／要求任務拆分** → ✅ 必須
- **複雜開發任務**（多文件／多來源／未來多次更新）→ ⚡ 建議 Step 1.5 來源抽取 → 調用同套 `dav-wiki` skill（需同套安裝）
- **任務已執行、要交付** → ❌ 走同套 `dav-reviewer` skill；**純粹閱讀／查資料／純粹提問（沒要做）** → ❌ 不觸發

## 流程（Step 1-4 ＋ 可選 Step 1.5）

- **Step 1 提問技巧**：一輪一題 ＋ 2-4 個選項（⭐ 推薦放第 1）；參考 `./reference.md` §2
- **Step 2 決策點判斷**：判斷任務升級／是否觸發 SWOT；觸發則出草案 → 用戶驗證；參考 `./reference.md` §2.5／§2.6
- **Step 3 維度展開 ＋ Step 3.5 術語表**：核心 4 維度必問 ＋ 觸發咗嘅補充維度；答案寫落文件；術語表 → `docs/glossary_list.md`；參考 `reference.md` §3
- **Step 4 成熟度評估 ＋ 寫 Backlog**：3 維度 ≥ 2 分先寫；出 backlog row ＋ 詳細段 ＋ AC ＋ 錨點；
  參考 `reference.md` §5／`backlog-rules.md` §4；**Plan Gate 通過條件 → 同套 `./plan-gate.md`**
- **Step 1.5 來源抽取（可選；Step 1 之後、Step 2 之前）**：複雜任務 → 調用同套 `dav-wiki` skill 抽取 → 回 Step 1 加來源清單；細節 → `reference.md` §6

## 規則 / 例外 / 限制

- **一次只問 1 題（V01）＋方案必標 ⭐ 推薦（V02）** — 例外：確認型問題可一次多個／開放式問題無推薦；限制：開放式問題必 1 題、V02 必為第 1 個選項
- **改規範自查行數上限（V03；已取消二審）** — 例外：無；限制：主檔 ≤50 行／子檔 ≤150 行／context ≤400 行；**代碼／契約嘅品質把關走同套 `dav-developer` skill（Gate 1/2/3）**
- **SWOT 不輕易觸發（§2.6）** — 例外：4 觸發條件之一即觸發；限制：不可「為 SWOT 而 SWOT」
- **AC 欄位精簡為「摘要 + 連結」（v1.8）＋AC 範本只含 AC（不重複 US 標題）** — 例外：存量 US 不重寫；限制：新 US 必走新格式；§4.3.2.3 規範
- **反思併進 deliverable.md（v2.0）** — 例外：存量反思檔保留；限制：未來不寫獨立反思
- **3 維度都 ≥ 2 分才寫 Backlog（§5）** — 例外：1 分項加 ⚠️ 註明；限制：0 分項不可寫
- **每個 US 都產 .md + .html（同 turn）** — 例外：存量 US 不補；限制：新 US 必走
- **複雜任務必走 Step 1.5（v2.6）** — 例外：用戶已主動提供結構化 Markdown 來源；限制：推薦 dav-wiki、避免手動抄 PDF；未裝則退回用戶口述 ＋ 提示安裝
- **產 US 必產需求錨點檔（v2.7）** — 例外：存量 US 不補；限制：`docs/req/<US-ID>-requirement.md`；「用戶原話」區唯讀、R-ID 連續唯一
- **專案層術語表（§4.9）** — 例外：專屬術語 < 3 條 → 唔產；限制：專案層 `docs/glossary_list.md`；A-Z、每條一句；各階段統一用入面術語

## 交叉引用（純文字）

- 提問技巧／維度展開／需求成熟度／Step 1.5 來源抽取 → 同套 `reference.md`；Backlog 規則（INVEST／AC／Module 編號／更新規則／錨點檔契約／術語表規格）→ `backlog-rules.md`
- Backlog ＋ AC ＋ 錨點 ＋ 術語表格式範本 → 同套 `templates/backlog-format.md`；Module 生命週期範例 → `examples/backlog.md`
- Plan Gate（規劃 gate）通過條件 ＋ 通過聲明格式 → 同套 `./plan-gate.md`
