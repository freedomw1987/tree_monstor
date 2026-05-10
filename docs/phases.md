# Phase 流程詳細規範

## Phase 總覽

| Phase | 名稱 | 輸出 | 強制 |
|-------|------|------|------|
| Phase 0 | BA 商業分析 | `docs/prd.md` | ✅ |
| Phase 0.5 | UI/UX 設計 | `docs/design.md` | ✅ |
| Phase 1 | SA 架構設計 | `docs/architecture.md` | ✅ |
| Phase 2 | 執行開發 | 代碼 | — |
| Phase 3 | SA Code Review | Review 報告 | ✅ |
| Phase 4 | QA 測試 | 測試報告 | ✅ |

---

## Phase 0: BA 商業分析

### 目的
挖掘真實需求，編寫 PRD 作為後續所有階段的**唯一依據**。

### 觸發條件
收到用戶需求後，第一步必須是 BA。

### BA 溝通原則
- 多輪探索，不是一次性索取所有資訊
- 目標：理解「為什麼」，不只是「做什麼」
- 每輪問 2-3 個問題，深入挖掘

### BA 必須問的問題方向
- **目的** — 為什麼需要這個？
- **必要性** — 沒有會怎樣？
- **使用者** — 誰會用？技術能力？
- **成功標準** — 怎麼判斷成功了？
- **優先級** — 只能做三個功能是哪三個？

### 觸發方式
```python
delegate_task(
    goal="BA 商業分析 — 用戶需求分析與 PRD 編寫",
    context="用戶原始需求: ...",
    toolsets=['terminal', 'file', 'web', 'clarify'],
    role="leaf"
)
```

### PRD 必須包含
- 產品概述與目標
- 用戶故事列表（帶優先級 P0/P1/P2）
- 功能需求詳情
- 非功能需求（效能、安全、兼容性）
- 驗收標準（每個功能如何驗證）
- 假設與風險清單

### 重要原則
- **PRD 是需求合約**
- SA 架構設計必須 100% 滿足 PRD
- QA 測試必須依據 PRD 判定 Pass/Fail
- 嚴禁 SA/QA 自行詮釋或忽略 PRD

---

## Phase 0.5: UI/UX 設計

### 目的
基於 PRD 進行 UX 研究與介面設計，輸出 `docs/design.md`。

### 觸發方式
```python
delegate_task(
    goal="UI/UX 設計 — 設計系統與 Wireframe",
    context="需求依據: docs/prd.md",
    toolsets=['terminal', 'file', 'web'],
    role="leaf"
)
```

### DESIGN.md 必須包含章節
1. Overview — 設計理念與品牌定位
2. Colors — 顏色系統（HEX 值）
3. Typography — 字體系統
4. Layout & Spacing — 間距系統
5. Elevation — 陰影/層級
6. Shapes — 圓角
7. Components — 元件規範（預設、hover、active、disabled）
8. Do's and Don'ts — 設計規範

### 設計原則
- WCAG AA 對比度（文字 vs 背景 >= 4.5:1）
- 使用相對單位（rem/em）
- Mobile-first 響應式設計

---

## Phase 1: SA 架構設計

### 目的
分析需求並設計系統架構，輸出 `docs/architecture.md`。

### 觸發方式
```python
delegate_task(
    goal="分析需求並設計系統架構",
    context="需求依據: docs/prd.md",
    toolsets=['terminal', 'file', 'web'],
    role="leaf"
)
```

### Architecture 必須包含
- 系統架構圖
- Frontend/Backend 技術棧建議
- 數據模型設計
- API 端點列表
- 開發規範和約定

---

## Phase 2: 執行開發

### 協調者
由 Orchestrator Subagent 協調。

### 任務調度原則
1. 分析 task 依賴圖，確定並行度
2. 首批：所有無依賴的 task 同時派發
3. 每批完成後，檢查是否有 task 解除 Blocked
4. 持續直到所有 task 完成

### Phase 2 Subagents
- **Frontend** — UI 實現、API 串接
- **Backend** — API、Business Logic、DB
- **DevOps** — 環境、CI/CD、部署腳本、監控

---

## Phase 3: SA Code Review

### 觸發條件
開發完成後、進入 QA 之前。

### 雙重審查
1. **SA 審查** — 技術架構、代碼品質、安全性
2. **UI/UX 審查** — 前端是否符合 design.md

### 結果處理
| 結果 | 處理 |
|------|------|
| CRITICAL 問題 | 必須修復 → 重新審查 |
| IMPORTANT 問題 | 應該修復 → 重新審查 |
| Minor 問題 | 可選，記錄供後續參考 |

### 紅線
- 安全漏洞（SQL Injection、XSS、Secrets 暴露）
- 嚴重偏離既定架構
- 測試是為了通過而寫，不是為了驗證功能

---

## Phase 4: QA 測試

### 組成
1. 單元測試 / Integration 測試
2. E2E 測試（dogfood skill）
3. User Simulation Testing

### User Simulation 原則
- 全自動化，不需要用戶介入
- 使用 playwright screenshot 截圖
- 使用 browser_console() 讀取 JS errors
- 使用 curl 測試 API

---

## QA Gate 交付清單

```
□ SA Code Review: APPROVED
□ UI/UX Design Review: APPROVED
□ 單元測試通過
□ Integration 測試通過
□ E2E 測試通過
□ User Simulation 測試通過
□ 主要 User Flow 跑通
□ Console 無 JS Error
□ 截圖/報告已保存
□ 部署驗證成功
□ Feedback Loop 完成記錄
```

**未通過 QA Gate 嚴禁交付。**
