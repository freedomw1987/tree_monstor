---
name: context-summarizer
description: 定時壓縮長時間任務的 context，避免 token 爆炸。寫入 context-summary.md 保留決策和當前狀態，丢棄細節。
trigger: "context / 上下文管理 / 總結進度 / 壓縮 context"
version: 1
category: productivity
---

# Context Summarizer

長時間任務 context 會越來越長，每個 subagent 的 intermediate results 堆積導致 token 爆炸。Context Manager 定期壓縮，保留決策和當前狀態。

## 觸發時機

1. 每 30 分鐘自動觸發
2. 每完成一個大 task 後
3. 預計還有 > 1 小時工作時

## 工作流程

```python
# 1. 讀取當前 context
current_context = read_file("docs/context-summary.md")  # 如果存在

# 2. 讀取 task board 狀態
task_board = read_file("docs/taskboard.md")

# 3. 讀取最近 subagent 輸出（最後 5 個）
recent_outputs = get_recent_subagent_results(limit=5)

# 4. 生成總結
summary = f"""
# Context Summary — {datetime.now().strftime('%Y-%m-%d %H:%M')}

## 當前任務
{task_board.current_task}

## 已完成
{summary_of_completed(recent_outputs)}

## 關鍵決策
{extract_decisions(recent_outputs)}

## 當前狀態
{extract_current_state(recent_outputs)}

## 待處理
{task_board.pending_tasks}

## 風險
{extract_risks(recent_outputs)}
"""

# 5. 寫入 context-summary.md
write_file("docs/context-summary.md", summary)

# 6. 通知 Orchestrator 可以丢棄 intermediate
```

## Context Summary 格式

```markdown
# Context Summary — 2026-05-10 18:30

## 當前任務
正在開發用戶登入功能（Backend API）

## 已完成
- [x] BA 需求分析完成
- [x] SA 架構設計完成
- [x] 數據庫 migration 完成
- [x] Auth middleware 完成

## 關鍵決策
1. 使用 JWT token，過期時間 24h
2. Password hashing 使用 bcrypt
3. Session 存 Redis，過期時間 7d

## 當前狀態
- Backend: 80% 完成，登入 API 尚需 unit test
- Frontend: 60% 完成，登入頁面 UI 完成，等待 API 就緒
- DevOps: 部署腳本已就緒，等待 Backend 完成

## 待處理
- TASK-005: Backend unit test（30分鐘）
- TASK-006: Frontend API 串接（1小時）
- TASK-007: E2E 測試（1小時）

## 風險
- 前端需要修改一次才能串接後端（API response 格式待確認）
- 預計完成時間：今日 22:00
```

## 保留 vs 丢棄

**保留**：
- 所有決策（架構、技術選型、API contract）
- 當前任務狀態
- 識別的風險
- Task Board 進度
- 任何對未來有影響的判斷

**丢棄**：
- 詳細的錯誤堆疊
- 試探性的代碼（已廢棄的方案）
- 中間過程的調試輸出
- 已經修復的 bug 記錄
- 具體的代碼片段（除非是重要參考）

## 工具

使用 `execute_code` 處理：
- 讀取 `docs/taskboard.md`
- 讀取 `docs/context-summary.md`（如果存在）
- 獲取最近 subagent results
- 寫入新的 `docs/context-summary.md`