---
name: tdd-test-writer
description: 在執行階段開始時，根據目標代碼項目的 docs/backlog.md 編寫測試用例，為 Test-Driven Development 打好基礎。
---

# TDD Test Writer

## 使用場景

當用戶需要在執行階段開始時，為其他代碼項目編寫測試時使用。適用於：
- 用 dav-planner 完成需求探索後的測試準備
- 為新功能編寫測試先行代碼
- 建立項目測試覆蓋基礎

## 核心步驟

| 步驟 | 動作 | 說明 |
|------|------|------|
| 1 | 定位 backlog | 找到目標項目的 `docs/backlog.md` |
| 2 | 分析 AC | 理解每個任務的驗收標準 |
| 3 | 識別測試點 | 從 AC 提取可測試的功能點 |
| 4 | 選擇框架 | Agent 判斷項目最佳測試框架 |
| 5 | 編寫測試 | 創建測試文件（單元/集成/E2E） |
| 6 | 放置文件 | 放入項目正確的測試目錄 |

## 識別項目類型

Agent 自動識別目標項目屬於哪種類型：

| 識別依據 | Frontend | Backend | Full-stack |
|---------|----------|---------|------------|
| **入口文件** | index.html, App.js, main.tsx | server.js, main.py, main.go | 兩者都有 |
| **目錄結構** | src/components, src/pages | src/controllers, src/services | 兩者都有 |
| **依賴項** | react, vue, angular | express, django, gin | 混合 |
| **測試目標** | UI/交互/API Mock | API/數據庫/業務邏輯 | 全部 |

## 框架選擇指南

### Frontend 框架選擇

| 框架 | 單元測試 | 集成測試 | E2E 測試 |
|------|---------|---------|----------|
| React | Jest + RTL | Testing Library | Playwright, Cypress |
| Vue | Vitest + Vue Test Utils | Vue Test Utils | Playwright, Cypress |
| Angular | Jasmine + Karma | TestBed | Playwright, Cypress |
| Svelte | Vitest | Testing Library | Playwright |

### Backend 框架選擇

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

## 測試文件放置約定

### Frontend 項目

```
src/
├── components/           # 組件測試: *.test.tsx
├── hooks/               # Hook 測試: *.hook.test.ts
├── context/             # Context 測試: *.context.test.ts
├── store/               # Store 測試: *.store.test.ts
├── utils/               # 工具函數測試: *.util.test.ts
└── services/            # API Mock 測試

tests/
├── unit/
├── integration/
└── e2e/                 # Playwright/Cypress specs
```

### Backend 項目

```
src/
├── controllers/          # 控制器測試
├── services/             # 服務測試: *.service.test.ts
├── models/               # 模型測試: *.model.test.ts
├── validators/           # 驗證器測試
└── utils/                # 工具函數測試

tests/
├── unit/
├── integration/          # API + Database 測試
│   └── __tests__/
│       └── api/
└── fixtures/             # 測試數據
```

## 測試結構模板

每個測試應包含：
1. **Describing** - 測試目標
2. **Given** - 測試前置條件
3. **When** - 執行操作
4. **Then** - 預期結果

示例請參考 [[examples]]

## 與其他技能協作

```
┌─────────────────────────────────────────────────┐
│              執行階段工作流                       │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────┐    ┌───────────────────┐  │
│  │ tdd-test-writer │───▶│ 為每個 Backlog 任務 │  │
│  │ (本技能)        │    │ 編寫測試用例        │  │
│  └─────────────────┘    └─────────┬─────────┘  │
│                                    │            │
│                                    ▼            │
│  ┌─────────────────┐    ┌───────────────────┐  │
│  │ dev-checker-loop│◀───│ 進入開發-校驗循環   │  │
│  │                 │    │ 執行 TDD          │  │
│  └─────────────────┘    └───────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 產出要求

| 產出 | 說明 |
|------|------|
| 測試文件 | 放置於項目正確測試目錄 |
| 測試覆蓋 | 每個 AC 至少一個測試用例 |
| 文檔更新 | 在 backlog 中標記測試已編寫 |

## 關鍵原則

- **框架靈活**：由 Agent 根據項目技術棧判斷，不硬編碼
- **覆蓋完整**：單元、集成、E2E 三層都要考慮
- **TDD 準備**：測試先於實現，為開發打好基礎
- **可執行**：測試必須能獨立運行
