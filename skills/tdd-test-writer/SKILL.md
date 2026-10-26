---
name: tdd-test-writer
description: 在執行階段開始時，根據目標項目的 docs/backlog.md 編寫測試用例，為 Test-Driven Development 打好基礎。涵蓋 Frontend / Backend / Full-stack 框架選擇。
---

# TDD Test Writer

## TL;DR

1. **做什麼**：依 `docs/backlog.md` 中任務的 AC，自動識別項目類型（Frontend / Backend / Full-stack）、選用對應測試框架、產出測試文件（單元 / 集成 / E2E 三層）。
2. **何時觸發**：§2.3 執行階段開始時；dav-planner 完成 §2.1 規劃後、實作代碼前。
3. **預設 SOP 路徑**：§2.3 Gate 1 TDD gate（在 Gate 2 lint / Gate 3 regression / Gate 4 reviewer 之前）。
4. **關鍵紀律**：
   - **測試先於實作**：先寫測試、後寫代碼（TDD 核心）
   - **每個 AC 一個測試**：不可多 AC 共用一個測試
   - **Given-When-Then 結構**：所有測試必遵循
   - **框架由 Agent 判斷**：不硬編碼，根據項目技術棧決定
   - **純文字引用**：skill 內不放跨檔 markdown 連結
5. **必產出物**：測試文件（按項目類型放對應目錄）+ `docs/backlog.md` 標記「測試已編寫」

## 觸發時機

| 情境 | 觸發 |
|------|------|
| §2.3 執行階段開始／dav-planner 完成後、實作代碼前 | ✅ 必須 |
| 為新功能編寫測試先行／建立項目測試覆蓋率 | ✅ 必須 |
| 純提問、不寫測試／已有完整測試（除非用戶要求補） | ❌ 不觸發 |

## 流程（6 步）

| Step | 動作 | 為什麼 | 產出 | 證據 |
|------|------|--------|------|------|
| 1 定位 backlog | 讀 monorepo 對應的 backlog 檔（路徑由 monorepo 約定），找目標任務（PENDING／in_progress） | 測試必對應 backlog item，避免「不知道測什麼」 | 目標 US／DE／TECH ID | 對話有「目標 = X」 |
| 2 分析 AC | 讀每個任務的 AC（含 monorepo 對應的 AC 範本檔） | AC 是驗收標準，測試必對應 AC | AC 清單（含 Given／When／Then） | 每個 AC 都有對應測試用例 |
| 3 識別測試點 | 從 AC 提取可測試的功能點 | 避免測試過粗或漏 AC | 測試點清單（每個 AC ≥ 1） | AC 數 ≤ 測試點數 |
| 4 選擇框架 | Agent 判斷項目類型（Frontend／Backend／Full-stack）並選對應框架 | 不同類型有最佳框架；硬編碼會誤導 | 選定框架清單（單元／集成／E2E） | 對話有「項目類型 = X／框架 = Y」 |
| 5 編寫測試 | 建測試檔，遵循 Given-When-Then | 結構化測試易讀、易維護 | 測試檔（`*.test.*`／`*_test.*`／`*.spec.*`） | 測試檔可獨立運行 |
| 6 放置＋更新 backlog | 按項目類型放對應目錄（見下方約定）；`docs/backlog.md` 標記「測試已編寫」 | 保持測試目錄約定、留下 audit trail | 測試檔到位 + backlog 標記 | backlog 對應 row 已標記 |

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 測試先於實作（TDD）| Bug 修復可後補 | 新功能必先寫測試 |
| 每個 AC 至少 1 個測試 | 不可分割的 AC 可多個 | 不允許「AC 沒測試」 |
| Given-When-Then 結構 | 簡單斷言可用 assert | 行為測試必用 BDD |
| 框架由 Agent 判斷 | 用戶明確指定時可覆蓋 | 不硬編碼 |
| 單元 + 集成 + E2E 三層考慮 | 純 util 可只有單元 | E2E 不可少於 AC 數的 20% |
| 測試必能獨立運行 | 共用 fixture 例外 | 不可有全局狀態依賴 |
| 純文字引用（v2.1） | skill 子檔可用 markdown | 不寫 `../` 或 `docs/` 跨檔連結 |

**測試結構模板**：每個測試含 Describing（測試目標）／Given（前置條件）／When（執行操作）／Then（預期結果）。

## 識別項目類型

| 識別依據 | Frontend | Backend | Full-stack |
|---------|----------|---------|------------|
| **入口文件** | index.html, App.js, main.tsx | server.js, main.py, main.go | 兩者都有 |
| **目錄結構** | src/components, src/pages | src/controllers, src/services | 兩者都有 |
| **依賴項** | react, vue, angular | express, django, gin | 混合 |
| **測試目標** | UI/交互/API Mock | API/數據庫/業務邏輯 | 全部 |

## 框架選擇指南

### Frontend 框架

| 框架 | 單元測試 | 集成測試 | E2E 測試 |
|------|---------|---------|----------|
| React | Jest + RTL | Testing Library | Playwright, Cypress |
| Vue | Vitest + Vue Test Utils | Vue Test Utils | Playwright, Cypress |
| Angular | Jasmine + Karma | TestBed | Playwright, Cypress |
| Svelte | Vitest | Testing Library | Playwright |

### Backend 框架

| 語言 | 單元測試 | 集成測試 | E2E 測試 |
|------|---------|---------|----------|
| JavaScript/TypeScript (Node) | Jest, Vitest | Supertest | Playwright |
| Python | pytest, unittest | pytest + fixtures | Playwright, httpx |
| Go | testing, testify | httptest | Playwright |
| Rust | #[test], cargo test | #[tokio::test] | Playwright |
| Java/Kotlin | JUnit, Spock | Testcontainers | Playwright |
| Ruby | RSpec, Minitest | Rails integration | Playwright |
| PHP | PHPUnit, Pest | Laravel Dusk | Playwright |
| C#/.NET | xUnit, NUnit | WebApplicationFactory | Playwright |

## 與其他技能協作

- **dav-planner** → 提供 backlog 與 AC
- **dev-checker-loop** → TDD 開發-校驗循環
- **regression-guard** → Gate 3 跑測試（禁用 watch 模式）

## Gate 定義（本節是 single source 之一；機器可讀副本 `docs/sop/gates.json`）

> 本節涵蓋 `name`／`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 五欄
> （`notes` 與 `remediation` 仍在 `gates.json` 與 handbook 2.3）。
> **進本 Gate 時必須在對話引用下表的 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」，依 SOP 的違規回報規則處理）。
> 2026-10-26 起 AGENTS.md 不再內嵌 SOP / Gate 表（只留「你是誰 + 萬事原則」）→
> Gate 的定義改由**承載它的 skill** 負責，讓 skill 自足。`tests/gate-in-skill.bats` 鎖兩份一致。

### Gate 1 TDD gate

| 欄位 | 內容 |
|------|------|
| pass_criteria | ① 測試可運行　② 看到「先紅後綠」（失敗 → 通過）|
| required_evidence | ① 測試執行指令（如 pytest / bats / npm test）② 失敗輸出（修改實作前的測試失敗訊息截錄）③ 通過輸出（修改實作後的測試通過訊息截錄）|
| fail_action | 不可寫實作 code |
| mandatory_phrase | 依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。|

> 純文件 / 配置改動可豁免，但須在交付摘要註明「無 TDD 需求」。

### Gate 2 lint / syntax gate

| 欄位 | 內容 |
|------|------|
| pass_criteria | 對應語言的 linter 0 error / 0 warning |
| required_evidence | linter 完整 output（不可只說「過了」）|
| fail_action | 不可繼續寫更多 code |
| mandatory_phrase | 依 gates.json 規範，Gate 2 (lint / syntax) 需要：對應語言的 linter 0 error / 0 warning，並在對話貼出 linter 完整 output。|

> Gate 2 沒有專屬 skill（`gates.json` 的 `trigger_skill: null`）→ 由本 skill 承載。
> bash/sh → shellcheck；python → ruff check 或 `python -m py_compile`；其他語言用對應工具。

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.4 | 2026-10-26 | 本輪支援檔無改動（只更新變動歷史以反映 TMO-083 全域瘦身） | 維持可追溯性 |
| v2.3 | 2026-10-26 | 支援檔瘦身（TMO-082 A 刀）：`examples.md` 563 → 251 行（4 種框架嘅長範例 → 1 個完整 React 範例 ＋ 其餘骨架 ＋ 金字塔改用表格）；順手修走一個跨 skill 死指標（同 skill 寫法改抽象措辭，唔再指向唔存在嘅相對路徑） | context 成本由 699 行降至 387 行；死指標會令 agent 順指標讀到唔存在嘅檔（Reviewer 二審 P1-3） |
| v2.2 | 2026-10-05 | 流程 6 步／觸發時機壓成表格、移除重複段（149 → 105 行） | TMO-046：主檔行數預檢（150 上限） |

**交叉引用（純文字）**：
- 測試結構示例 → 同套本 skill 子檔（`./examples.md`）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
