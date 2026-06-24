# Task Board 格式

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
| Phase 0 BA | ✅ Done | BA Subagent | - |
| Phase 0.5 UI/UX | 🔄 In Progress | Designer | 70% |
| Phase 1 SA | ⏳ TODO | SA Subagent | 等待 BA 完成 |
| Phase 2 Frontend | ⏳ TODO | - | - |
| Phase 2 Backend | ⏳ TODO | - | - |
| Phase 3 Code Review | ⏳ TODO | - | - |
| Phase 4 QA | ⏳ TODO | - | - |

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
