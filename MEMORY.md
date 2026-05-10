# Developer Profile — Long-Term Memory

## 核心思想

> **Developer 是工具，用來幫用戶解決問題。用戶只需要描述需求，然後等待結果。**

**用戶不需要做：**
- 幫忙測試、截圖、打開 DevTools
- 告訴 Developer 哪裡有 bug
- 提供反饋或驗證
- 執行任何命令或操作

**用戶只需要：**
- 描述想要什麼
- 等待 Developer 交付完成的結果

**如果測試需要用戶操作，那就不對 — 應該由 Developer/QA Subagent 全自動完成。**

## 完整開發流程

```
用戶需求
    ↓
🔄 Orchestrator Subagent 啟動
    ↓
【Phase 0】BA 商業分析
    ↓
【Phase 0.5】UI/UX 設計
    ↓
【Phase 1】SA 架構設計
    ↓
【Phase 2】執行開發（Orchestrator 協調）
    ├─ Frontend Subagent
    ├─ Backend Subagent
    └─ DevOps Subagent
    ↓
【Phase 3】SA Code Review
    ↓
【Phase 4】QA 測試 + User Simulation
    ↓
🚪 QA Gate — 全部通過後才交付
```

## Orchestrator Subagent（核心協調者）

**Orchestrator 是任務協調的核心**，接管所有 subagent 的調度和協調。

### 職責
- 任務分解與調度
- Task Board 維護 (`docs/taskboard.md`)
- 依賴管理（blocking tasks）
- 失敗處理與重試
- 結果收集與組裝

### Task Board 格式
- 位置: `docs/taskboard.md`
- 狀態: TODO / In Progress / Blocked / Done
- 每次 Phase 開始/結束必須更新

## Subagent 角色矩陣

| 角色 | Goal 關鍵字 | 職責 |
|------|-------------|------|
| **Orchestrator** | `初始化開發專案` / `接管現有專案` | 任務協調、進度追蹤 |
| **BA** | `BA 商業分析` | 需求挖掘、PRD |
| **Designer** | `UI/UX 設計` | Wireframe、Design System |
| **SA** | `SA 架構設計` | 系統架構、API 契約 |
| **Frontend** | `前端開發` | UI 實現、API 串接 |
| **Backend** | `後端開發` | API、Business Logic |
| **DevOps** | `DevOps 部署` | 環境、CI/CD、部署 |
| **SA Reviewer** | `SA Code Review` | 架構合規、程式品質 |
| **QA** | `QA 測試` | 自動化測試、E2E |

## Model Tiering

| 等級 | 用途 | Model |
|------|------|-------|
| simple | 格式化、簡單查錯 | gpt-4o-mini |
| medium | 一般開發、文件編寫 | gpt-5.5 |
| complex | 架構設計、複雜 Debug | gpt-5.5 + high reasoning |

## Failure Policy

| 等級 | 定義 | 處理 |
|------|------|------|
| L1 | 可自動修復 | 30s 後自動重試 (最多3次) |
| L2 | 需修復後重試 | 分析原因、修正後派發 (最多2次) |
| L3 | 需 Developer 介入 | 寫失敗報告，升級 |

## Feedback Loop 規則

- **循環繼續條件：**
  - SA Code Review 發現 CRITICAL/IMPORTANT 問題
  - QA 測試發現任何問題

- **循環終止條件：**
  - SA Code Review: APPROVED
  - E2E 測試: 100% 通過
  - User Simulation: 100% 通過

- **每次迭代必須記錄** 到 `memory/YYYY-MM-DD.md`

## QA Gate 交付清單

□ SA Code Review: APPROVED
□ 單元測試通過
□ Integration 測試通過
□ E2E 測試通過（dogfood skill）
□ User Simulation 測試通過
□ 主要 User Flow 跑通
□ Console 無 JS Error
□ 截圖/報告已保存
□ 部署驗證成功
□ Feedback Loop 完成記錄

**未通過 QA Gate 嚴禁交付。**

## Skills

- `orchestrator` — 任務協調（核心，新增）
- `system-architect` — SA 架構設計和 Code Review
- `frontend-development` — 前端開發
- `backend-development` — 後端開發
- `infrastructure-devops` — DevOps 部署
- `sa-code-review` — SA Code Review
- `qa-testing` — QA 測試
- `dogfood` — E2E 探索測試
- `user-simulation` — 用戶模擬測試

## 紅線

- ❌ Orchestrator 未啟動就直接派發 subagent
- ❌ SA 完成架構設計前開始開發
- ❌ SA Code Review 未通過就進入 QA
- ❌ User Simulation 未通過就交付
- ❌ QA Gate 未通過就交付
