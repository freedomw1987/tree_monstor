---
name: dav-developer
description: >-
  在 代碼開發SOP「執行」階段使用。負責 TDD 寫測試 → 開發令紅變綠 → 埋探針同回歸 → Reviewer 二審（Gate 1/2/3/4 全部由本 skill 承載）。寫測試部分取原 regression-guard 的嚴謹性；回歸不需要全項目跑探針（Reviewer agent 已覆蓋）。LLM 語意判斷（Jev Oracle）係同套 dav-jev-oracle skill 嘅可選加深。dav-developer 的嚴謹性；回歸不需要全項目跑探針（Reviewer agent 已覆蓋）。
---

# Dav Developer

## TL;DR

1. **做什麼**：一條龍做完「**寫測試 → 開發令紅變綠 → 埋探針 → Reviewer 二審**」，
   承載 Gate 1（TDD）／Gate 2（lint）／Gate 3（regression）／Gate 4（reviewer）。
2. **何時觸發**：§2.3 執行階段開始時（規劃已完成、實作未開始）。
3. **預設 SOP 路徑**：§2.3 Execution（Gate 1 → 2 → 3 → 4）。
4. **關鍵紀律**：
   - **測試先於實作**：先紅後綠（TDD 核心）；寫測試要帶原 regression-guard 嘅**嚴謹性**
     （fail-loud、帶修復建議、禁用 watch/interactive）
   - **一次一個問題**（V01）、**方案必標推薦**（V02）、**SOP／skill 修改必走二審**（V03）
   - **回歸唔使全項目跑**：改動範圍內嘅探針 + Reviewer agent 覆蓋（見 Step 3）
5. **必產出物**：測試檔（框架由 Agent 判斷）＋ 埋好嘅探針 ＋ Gate 1/3/4 嘅證據貼喺對話。

## 觸發時機

- **§2.3 執行階段開始／規劃完成後、實作代碼前**、**為新功能編寫測試先行／建立測試覆蓋** → ✅ 必須
- **純提問、不寫測試／已有完整測試（除非用戶要求補）**、**規劃（§2.1）／設計（§2.2）／反省交付（§2.4-2.5）** → ❌ 不觸發

## 流程（4 步）

### Step 1：寫測試（TDD，先紅）

- **動作**：讀目標 US 嘅 AC → 逐個 AC 抽出測試點 → 判斷項目類型（Frontend／Backend／Full-stack）
  → 揀框架 → 寫測試檔（Given-When-Then）→ 跑一次，**必須見到紅**
- **為什麼**：測試先紅，之後嘅綠先有意義；冇紅過 = 測試冇驗到嘢
- **產出**：測試檔（`*.test.*`／`*_test.*`／`*.spec.*`）＋ 紅嘅失敗輸出
- **證據**：對話貼「測試執行指令 ＋ 失敗輸出」（Gate 1 證據）
- **參考**：同套本 skill 子檔（`./tdd.md`）

### Step 2：開發令紅變綠

- **動作**：dev 領任務（Module 級派工）→ 寫實作 → 重跑測試 → 直到由紅變綠 → 自我校驗
- **為什麼**：綠嘅過程要留痕（紅→綠 = Gate 1 嘅核心證據）
- **產出**：實作碼 ＋ 綠嘅測試輸出
- **證據**：對話貼「修改前紅 ＋ 修改後綠」
- **參考**：同套本 skill 子檔（`./develop.md`）

### Step 3：埋探針 + 回歸（唔使全項目跑）

- **動作**：為新行為埋**探針**（記錄關鍵 state／行為／boundary）→ 跑**改動範圍內**嘅測試套件
  → 對比修改前後結果
- **為什麼**：探針係「防復發」嘅最小單位；回歸只需要覆蓋**改動範圍**，
  全項目跑探針嘅成本遠高過收益（而且 Reviewer agent 下一-step 會再覆蓋一次）
- **產出**：探針檔 ＋ 範圍內測試輸出（baseline ＋ 修改後）＋ Diff 對比
- **證據**：對話貼「修改前 baseline ＋ 修改後 output ＋ Diff 對比」（Gate 3 證據）
- **範圍點決定**：改咗邊個 Module／邊啲檔 → 就跑邊啲（Module 級派工時用 `REGRESSION_MODULE=<M>`；
  唔涉及跨 Module 影響時唔需要全項目跑）
- **參考**：同套本 skill 子檔（`./probe-naming.md`、`./runner-cheatsheet.md`）；PoC API contract → 同套 `dav-jev-oracle` skill

### Step 4：Reviewer 二審（Gate 4）

- **動作**：開獨立 checker subagent 做全面校驗 → 有問題就返 Step 2 修 → 直至「沒找到更多問題」
  → UI 任務要跑 playwright-cli E2E（連截圖證據）
- **為什麼**：自己睇自己寫嘅碼會有盲點；獨立 reviewer 先捉到「自查看不到」嘅嘢
- **產出**：checker 原文回傳 ＋ E2E 報告／截圖路徑
- **證據**：對話貼 checker 原文回傳（Gate 4 證據）
- **參考**：同套本 skill 子檔（`./review.md`、`./reviewer-checklist.md`、`./module-rules.md`）

## 規則 / 例外 / 限制

- **測試先於實作（TDD）** — 例外：Bug 修復可後補；限制：新功能必先寫測試
- **每個 AC 至少 1 個測試** — 例外：不可分割的 AC 可多個；限制：不允許「AC 冇測試」
- **Given-When-Then 結構** — 例外：簡單斷言可用 assert；限制：行為測試必用 BDD
- **框架由 Agent 判斷**（唔硬編碼）— 例外：用戶明確指定時可覆蓋；限制：依項目技術棧決定
- **探針要 fail-loud ＋ 帶修復建議** — 例外：無；限制：紅嘅訊息要講得出「點解紅 ＋ 點修」
- **測試指令禁用 interactive／watch 模式** — 例外：無；限制：否則卡住等 stdin、凍結成個 session
- **回歸只跑改動範圍** — 例外：跨 Module 影響或大重構 → 跑全項目；限制：範圍要講得出（邊個 Module／邊啲檔）
- **一次一個問題（V01）／方案必標 ⭐ 推薦（V02）／SOP 修改必走二審（V03）** — 例外：確認型問題可一次多個；限制：V02 必為第 1 個選項

## Gate 定義（本節是 single source 之一；機器可讀副本 `docs/sop/gates.json`）

> 本節涵蓋 `name`／`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 五欄
> （`notes` 與 `remediation` 仍在 `gates.json` 與 handbook 2.3）。
> **進本 Gate 時必須在對話引用對應嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」）。
> 2026-10-26 起 Gate 定義改由**承載它的 skill** 負責，讓 skill 自足；
> 鎖兩份一致嘅探針已於 2026-10-27 減法刪走 → 兩份要人手同步。

### Gate 1 TDD gate

- **pass_criteria**：① 測試可運行　② 看到「先紅後綠」（失敗 → 通過）
- **required_evidence**：① 測試執行指令（如 pytest／bats／npm test）② 失敗輸出（改實作前嘅失敗訊息截錄）
  ③ 通過輸出（改實作後嘅通過訊息截錄）
- **fail_action**：不可寫實作 code
- **mandatory_phrase**：依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，
  並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。

> 純文件／配置改動可豁免，但須在交付摘要註明「無 TDD 需求」。

### Gate 2 lint / syntax gate

- **pass_criteria**：對應語言的 linter 0 error / 0 warning
- **required_evidence**：linter 完整 output（不可只說「過了」）
- **fail_action**：不可繼續寫更多 code
- **mandatory_phrase**：
  依 gates.json 規範，Gate 2 (lint / syntax) 需要：對應語言的 linter 0 error / 0 warning，並在對話貼出 linter 完整 output。

> bash/sh → shellcheck；python → ruff check 或 `python -m py_compile`；其他語言用對應工具。

### Gate 3 regression gate

- **pass_criteria**：① 探針埋好（記錄關鍵 state／行為／boundary）② **改動範圍內**測試套件跑過
- **required_evidence**：① 修改前 baseline（範圍內測試 output，含 pass/fail 計數）② 修改後 output ③ Diff 對比（既有測試結果一致 + 新探針如預期觸發）
- **fail_action**：不可聲稱「做完了」
- **mandatory_phrase**：依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 改動範圍內測試套件跑過，
  並在對話貼出「修改前 baseline + 修改後 output + Diff 對比」。

> 機器可讀副本：`docs/sop/gates.json`（鎖兩邊一致嘅探針已於 2026-10-27 減法刪走 → 兩邊要人手同步）。
>
> 測試指令必須禁用 interactive / watch 模式（詳見 `./runner-cheatsheet.md`）。

### Gate 4 reviewer gate

- **pass_criteria**：① checker subagent 回傳「沒找到更多問題」② playwright-cli E2E 全綠（含截圖證據，UI 任務必跑）
- **required_evidence**：① checker subagent 原文回傳 ② playwright test 報告路徑 + 截圖路徑（若有 UI）
- **fail_action**：不可進入 §2.4 反省
- **mandatory_phrase**：依 gates.json 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」
  - playwright-cli E2E 全綠（含截圖），並在對話貼出 checker subagent 原文回傳。

> 純後端／CLI／腳本任務可跳過 playwright-cli，但要在對話明示「無 UI 故不適用」及理由。

## 交叉引用（純文字）

- 寫測試流程 ＋ 框架選擇 → 同套本 skill 子檔（`./tdd.md`）／範例（`./tdd-examples.md`）
- 開發流程（紅 → 綠、Module 派工）→ 同套本 skill 子檔（`./develop.md`）
- Reviewer 二審細節 → 同套本 skill 子檔（`./review.md`、`./reviewer-checklist.md`、`./module-rules.md`）
- API contract ＋ 環境變量 ＋ 輸出格式 → 同套 `dav-jev-oracle` skill
- 探針命名 ＋ 粒度 → 同套本 skill 子檔（`./probe-naming.md`）
- Runner 對照表（TTY／watch 防線）→ 同套本 skill 子檔（`./runner-cheatsheet.md`）
- 測試方法指南 → 同套本 skill 子檔（`./testing-methods.md`）
- **LLM 語意判斷（Jev Oracle）／修正循環／flaky 整合／多 story 矩陣** → 同套 `dav-jev-oracle` skill（可選加深；Gate 3 唔強制）
- Module 完整生命週期範例（含 Module prefix 探針）→ 見本 skill 的 `examples/probes/`
