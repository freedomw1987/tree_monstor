---
name: dav-developer
description: 在代碼開發SOP「執行」階段使用。負責 TDD 寫測試 → 開發令紅變綠 → 埋探針同回歸（Gate 1/2/3 由本 skill 承載）。寫測試部分取原 regression-guard 的嚴謹性；回歸不需要全項目跑探針。品質審核（Gate 4）＋ 需求對帳（Gate 4.5）係人手觸發嘅 dav-reviewer skill。LLM 語意判斷（Jev Oracle）係同套 dav-jev-oracle skill 嘅可選加深。
---
# Dav Developer

## TL;DR
1. **做什麼**：一條龍做完「**寫測試 → 開發令紅變綠 → 埋探針**」，承載 Gate 1（TDD）／Gate 2（lint）／Gate 3（regression）。
2. **何時觸發**：§2.3 執行階段開始（規劃已完成、實作未開始）。
3. **關鍵紀律**：測試先於實作（TDD）；一次一個問題（V01）／方案必標推薦（V02）；skill 代碼／契約改動必走二審（V03）。
4. **必產出物**：測試檔 ＋ 埋好嘅探針 ＋ Gate 1／2／3 嘅證據貼喺對話。

## 觸發時機
- **§2.3 執行階段開始／規劃完成後、實作代碼前**、**寫測試先行／建立測試覆蓋** → ✅ 必須
- **純提問、不寫測試／已有完整測試（除非用戶要求補）**、**規劃／設計／反省交付** → ❌ 不觸發

## 流程（4 步）
### Step 1：寫測試（TDD，先紅）— 讀 US 嘅 AC → 抽測試點 → 揀框架 → 寫測試檔（Given-When-Then）→ **必須見到紅**
細節 → 同套 `./workflow.md` §1
### Step 2：開發令紅變綠 — dev 領任務（Module 級派工）→ 寫實作 → 重跑測試 → 直到由紅變綠 → 自我校驗
細節 → 同套 `./workflow.md` §2
### Step 3：埋探針 + 回歸（唔使全項目跑）— 為新行為埋**探針** → 跑**改動範圍內**嘅套件 → 對比修改前後
細節 → 同套 `./probes.md` §1
### Step 4：交畀 `dav-reviewer` 做 Gate 4（人手觸發）— 交出「探針已埋好 ＋ 回歸已過 ＋ 證據」；審核 ＋ 需求對帳由用戶叫先做
細節 → 同套 `./probes.md` §2 ＋ 同套 `dav-reviewer` skill

## 規則 / 例外 / 限制
- **測試先於實作（TDD）** — 例外：Bug 修復可後補；限制：新功能必先寫測試
- **每個 AC 至少 1 個測試** — 例外：不可分割的 AC 可多個；限制：不允許「AC 冇測試」
- **Given-When-Then 結構** — 例外：簡單斷言可用 assert；限制：行為測試必用 BDD
- **框架由 Agent 判斷**（唔硬編碼） — 例外：用戶明確指定時可覆蓋；限制：依項目技術棧決定
- **探針要 fail-loud ＋ 帶修復建議** — 例外：無；限制：紅嘅訊息要講得出「點解紅 ＋ 點修」
- **測試指令禁用 interactive／watch 模式** — 例外：無；限制：否則卡住等 stdin、凍結成個 session
- **回歸只跑改動範圍** — 例外：跨 Module 影響或大重構 → 跑全項目；限制：範圍要講得出
- **一次一個問題（V01）／方案必標 ⭐ 推薦（V02）／skill 代碼改動必走二審（V03）** — 例外：確認型問題可一次多個；限制：V02 必為第 1 個選項
- **純文字引用（v2.1）** — 例外：skill 子檔可用 markdown（含 `examples/` 內回指主檔嘅 `../`）；限制：不寫指向 **skill dir 以外** 嘅連結或讀檔引用
- **Gate 4（審核）唔屬本 skill** — 例外：無；限制：Gate 4 ＋ Gate 4.5 由**人手觸發**嘅 `dav-reviewer` skill 承載（2026-10-28 起）

## 交叉引用（純文字）
- Gate 1–3 定義（pass_criteria／required_evidence／fail_action／mandatory_phrase）→ 同套 `./gates.md`
- Step 1／2 細節（TDD 6 步、Dev-Checker loop、backlog 狀態機、Module 取得、jev 整合）→ 同套 `./workflow.md`
- 探針命名／粒度／回歸範圍／Module 互動 → 同套 `./probes.md`
- Gate 4 品質審核 ＋ Gate 4.5 需求對帳（**人手觸發**）→ 見同套 `dav-reviewer` skill
- Runner 對照表（TTY／watch 防線）→ 同套本 skill 子檔（`./runner-cheatsheet.md`）
- 測試方法（9 類對照 ＋ 可抄骨架）→ 同 skill 子檔 `./examples/testing-methods.md`
- TDD 寫測試範例 → 同 skill 子檔 `./tdd-examples.md`；Reviewer 校驗清單範例 → 見同套 `dav-reviewer` skill
- **LLM 語意判斷（Jev Oracle）／修正循環／flaky 整合／多 story 矩陣** → 見同套 `dav-jev-oracle` skill（可選加深；Gate 3 唔強制）
