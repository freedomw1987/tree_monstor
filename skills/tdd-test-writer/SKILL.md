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
| §2.3 執行階段開始 | ✅ 必須 |
| dav-planner 完成後、實作代碼前 | ✅ 必須 |
| 為新功能編寫測試先行 | ✅ 必須 |
| 項目測試覆蓋率建立 | ✅ 必須 |
| 純提問 / 不寫測試 | ❌ 不觸發 |
| 已有完整測試 | ❌ 跳過（除非用戶要求補） |

## 流程（6 步）

### Step 1：定位 backlog

- **動作**：讀 `docs/backlog.md`，找到目標任務（PENDING 或 in_progress 中要寫測試的）
- **為什麼**：測試必對應 backlog item，避免「不知道測什麼」
- **產出**：識別目標 US / DE / TECH ID
- **證據**：對話中有「目標 = X」

### Step 2：分析 AC

- **動作**：讀取每個任務的 AC（含 `docs/ac/<US-ID>.md` 完整 AC 範本）
- **為什麼**：AC 是「驗收標準」，測試必對應 AC
- **產出**：AC 清單（含 Given / When / Then）
- **證據**：每個 AC 都有對應測試用例

### Step 3：識別測試點

- **動作**：從 AC 提取可測試的功能點（每個 AC 至少 1 個測試）
- **為什麼**：避免「測試過粗」或「測試漏 AC」
- **產出**：測試點清單（每個 AC 對應 1+ 個）
- **證據**：AC 數 = 測試點數（最低）

### Step 4：選擇測試框架

- **動作**：Agent 自動判斷項目類型（Frontend / Backend / Full-stack）並選對應框架
- **為什麼**：不同類型有最佳框架；硬編碼會誤導
- **產出**：選定框架清單（單元 / 集成 / E2E）
- **證據**：對話有「項目類型 = X / 框架 = Y」

### Step 5：編寫測試

- **動作**：創建測試文件，遵循 Given-When-Then 結構
- **為什麼**：結構化測試易讀、易維護
- **產出**：測試文件（*.test.* / *_test.* / *.spec.*）
- **證據**：測試檔可獨立運行

### Step 6：放置文件 + 更新 backlog

- **動作**：按項目類型放對應目錄（見下方約定）；`docs/backlog.md` 標記「測試已編寫」
- **為什麼**：保持測試目錄約定、留下 audit trail
- **產出**：測試文件到位 + backlog 標記
- **證據**：`docs/backlog.md` 對應 row 標記

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

## 測試結構模板

每個測試應包含：
1. **Describing** — 測試目標
2. **Given** — 測試前置條件
3. **When** — 執行操作
4. **Then** — 預期結果

## 與其他技能協作

- **dav-planner** → 提供 backlog 與 AC
- **dev-checker-loop** → TDD 開發-校驗循環
- **regression-guard** → Gate 3 跑測試（禁用 watch 模式）

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 8：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版含 ASCII 流程圖）| 詳見 `docs/sop/handbook/changelog.md` |

---

**交叉引用（純文字）**：
- 測試結構示例 → 見 `skills/tdd-test-writer/examples.md`
- 全域 SOP 變動歷史 → 見 `docs/sop/handbook/changelog.md`
