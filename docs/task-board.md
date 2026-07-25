# Task Board 格式

> **Status:** Canonical. Source of truth for Task Board format, statuses, and update rules.

## 位置
`docs/task-board.md`

## 格式模板

```markdown
# Task Board — [項目名稱]

## 基本資訊
- 項目: [名稱]
- 開始時間: [時間]
- 總任務數: N
- 完成: X / N

## 階段狀態
| Phase | 狀態 | 負責 | 備註 |
|-------|------|------|------|
| Think | ✅ Done | CEO + Researcher | - |
| Plan | 🔄 In Progress | BA + Designer + SA + Tech Lead | 70% |
| Build | ⏳ TODO | Frontend + Backend Subagent | 等待 Plan 完成 |
| Review | ⏳ TODO | SA Reviewer + UX Reviewer | - |
| Test | ⏳ TODO | QA | - |
| Ship | ⏳ TODO | Release Manager | - |
| Reflect | ⏳ TODO | Retrospective | - |

## 任務清單

### TODO
- [ ] TASK-005: 實現庫存預警通知功能
- [ ] TASK-006: 編寫庫存預警 API 文件

### In Progress
- [ ] TASK-004: 前端登入頁面
  - 負責: Frontend Subagent
  - 進度: 70%
  - Blocked by: TASK-003 (API 契約未確認)
  - 預計完成: 30分鐘

### Blocked
- [ ] TASK-004: 前端登入頁面
  - 原因: 等待 TASK-003 API 契約確認
  - 解除條件: SA 完成 API 契約文件

### Done
- [x] TASK-001: 需求分析 (BA Subagent) — 100% — 20分鐘
- [x] TASK-002: PRD 文檔編寫 — 100% — 15分鐘
- [x] TASK-003: API 契約設計 (SA Subagent) — 100% — 25分鐘

## 依賴圖
```
TASK-001 (BA) ──→ TASK-003 (SA) ──┬──→ TASK-004 (Frontend)
                   │              └──→ TASK-005 (Backend)
                   ↓
              TASK-002 (Design)
```

## 最近更新
- [HH:MM] TASK-004 開始執行，發現需要等待 TASK-003
- [HH:MM] TASK-001, TASK-002 完成，轉交 SA

## 阻塞清單
- TASK-004 blocked by TASK-003

## 失敗紀錄
(空)
```

---

## 任務狀態說明

| 狀態 | 意義 |
|------|------|
| TODO | 尚未開始 |
| In Progress | 執行中 |
| Blocked | 被其他任務阻塞 |
| Done | 已完成 |

---

## 更新規則

1. **每個 Phase 開始** → 更新階段狀態
2. **每個 Task 開始** → 從 TODO 移到 In Progress
3. **每個 Task 完成** → 從 In Progress 移到 Done
4. **Task 被阻塞** → 移到 Blocked 並註明原因
5. **阻塞解除** → 移回 TODO，適時重新派發

---

## PM 進度追蹤與用戶溝通

### 目的
定期向用戶彙報進度，屏蔽技術細節，讓用戶專注於業務決策。

### PM 核心職責

| 職責 | 說明 |
|------|------|
| **進度追蹤** | 記錄每個 Phase 的完成狀態、耗時、遇到的問題 |
| **用戶溝通** | 用非技術語言向用戶解釋發生了什麼、接下來做什麼 |
| **技術屏蔽** | 不讓用戶接觸技術術語、錯誤信息、Debug 過程 |
| **進度彙報** | 定期輸出項目進度文檔 |

### 進度文檔

位置：`docs/progress.md`

```markdown
# [項目名稱] 進度報告

## 基本信息
- 開始時間：[時間]
- 當前 Phase：[Think / Plan / Build / Review / Test / Ship / Reflect]
- 整體進度：[XX%]

## Phase 進度
| Phase | 狀態 | 耗時 | 備註 |
|-------|------|------|------|
| Think 市場分析 + 技術調研 | ✅ 完成 | 30分鐘 | - |
| Plan 需求 + 設計 + 架構 | 🔄 進行中 | 15分鐘 | 預計還需 30 分鐘 |
| Build 開發執行 | ⏳ 待開始 | - | - |
| Review 架構審查 + UX 合規 | ⏳ 待開始 | - | - |
| Test 測試 + 壓測 | ⏳ 待開始 | - | - |
| Ship 部署上線 | ⏳ 待開始 | - | - |
| Reflect 復盤 | ⏳ 待開始 | - | - |

## 最近更新

### [時間] - [Phase] 進行中
- 完成了：[描述]
- 正在做：[描述]
- 預計完成：[時間]

### [時間] - [Phase] 完成
- 完成內容：[描述]
- 下一階段：[描述]

## 用戶需要決策的事項
（如果有需要用戶決策的問題，列在這裡，用非技術語言描述）

## 已知問題
（如果有阻礙進度的問題，描述但不透露技術細節）
```

### PM 溝通原則

#### ✅ 應該這樣說
- 「功能 X 已經完成，可以開始使用了」
- 「目前正在做用戶登入模組，預計今天下午完成」
- 「發現一個小問題需要多一點時間處理」

#### ❌ 不應該讓用戶看到
- 「SQL Injection 被修了」
- 「React 組件有 TypeScript 錯誤」
- 「Docker compose 啟動失敗」
- 「某個依賴有 vulnerability」

### 觸發時機

PM 進度更新在以下時機自動觸發：
1. 每個 Phase 開始時
2. 每個 Phase 完成時
3. 用戶詢問進度時
4. 遇到重大問題需要用戶決策時

---

## Related docs

- [Documentation index](00-index.md)
- [Phase workflow](phases.md)
- [QA tracker](qa-tracker.md)
