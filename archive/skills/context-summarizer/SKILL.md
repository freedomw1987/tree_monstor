---
name: context-summarizer
description: 定時壓縮長時間任務的 context，避免 token 爆炸。寫入 context-summary.md 保留決策和當前狀態，丢棄細節。
trigger: "context / 上下文管理 / 總結進度 / 壓縮 context / resume from previous session"
version: 2
category: productivity
---

# Context Summarizer v2 (auto-invocation guide)

> **Patched 2026-06-19 (auto-dev Phase 2C)**: Auto-trigger guide + hallucination detection + session resume handshake. See §0 below.

## 0. v2 Changelog

- ✅ 改 trigger 邏輯：由「每 30 分鐘」改為「每 25 個 message / 30% token / 60% 強制 / detect loop」
- ✅ 加 hallucination detection（agent 問 David 同樣嘢 3 次 / reference 唔存在 file 2 次 → trigger summary）
- ✅ 加 session resume handshake（新 session 第一件事 read `docs/context-summary.md`）
- ✅ 標明由 orchestrator / agent 自己 trigger，唔再等 David 問

## 1. 觸發時機（AUTO — 唔等 David 問）

下列 trigger 全部**自動 fire**：

| Trigger | 條件 | 動作 |
|---|---|---|
| **每 25 個新 message** | agent 自己 count 緊 | 自動 write summary |
| **每次 sub-agent 跑完** | 任何 size | 自動 write summary（sub-agent 結果會 push context） |
| **Token usage 過 30% context** | `compression.threshold: 0.3` 已 trigger | 自動 write summary |
| **Context 用到 60% 強制** | 60% 已 trigger | 強制 write summary + log warning |
| **Detect hallucination (NEW)** | 問 David 同樣嘢 3 次 / reference 唔存在 file 2 次 | 強制 write summary + notify David |
| **David 講「/context」** | manual | 即刻 write summary |

## 2. 工作流程

```python
# 1. 讀取當前 context
current_context = read_file("docs/context-summary.md")  # 如果存在

# 2. 讀取 task board 狀態
task_board = read_file("docs/task-board.md")

# 3. 讀取最近 sub-agent 輸出（最後 5 個）
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

## 3. Context Summary 格式

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

## 4. 保留 vs 丢棄

**保留**：
- 所有決策（架構、技術選型、API contract）
- 當前任務狀態
- 識別的風險
- Task Board 進度
- Capabilities Table（per test-coverage-table skill）

**丢棄**（寫完 summary 之後可以清）：
- 中間 sub-agent 嘅 raw output
- 探索性 search / read 嘅 file path
- 失敗咗 retry 嘅 attempt log
- 重覆嘅 system reminder

## 5. Hallucination Detection (NEW in v2)

Agent 要**主動** detect 自己 hallucinate 嘅 signal：

| Signal | 計數 | 動作 |
|---|---|---|
| 問 David 同樣嘅 question 3 次 | ≥3 | 強制 trigger summary + 通知 David「我似乎行 loop」 |
| Reference 唔存在嘅 file path 2 次 | ≥2 | 強制 trigger summary + 通知 David「我 reference 咗唔存在 file」 |
| 同一個 tool call 重覆 3 次冇 progress | ≥3 | Hermes 嘅 `idempotent_no_progress: 2` rule 會 trigger warning；agent 收到 warning 就 trigger summary |
| 開始 output 「as an AI」/「I cannot」呢類 disclaimer | 出現 | 強制 trigger summary — 已經過咗 task scope |

**Notification format**（critical 級別）：
```
🚨 Hallucination Detected (signal: <X>)
- Trigger: <description>
- Action taken: 強制寫 context-summary.md
- Recommendation: David 用 /new session，context 自動 resume
```

## 6. Session Resume Handshake (NEW in v2)

**新 session 開頭，agent 自動**：

```python
# 7. 新 session 第一件事
summary_path = Path("<profile-root>/docs/context-summary.md").expanduser()
if summary_path.exists():
    content = summary_path.read_text()
    echo_to_david = f"📋 **Resume from previous session:**\n\n{content}\n\n---\n"
else:
    echo_to_david = "📋 No previous session summary found. Starting fresh.\n"
```

Agent 開新 session 嘅 first message 一定要 echo 上面嘅 block，**唔可以 skip**。

**為何咁做**：避免 David 要手動 paste context-summary.md 過去（David 痛點三）。

## 7. 邊個 trigger

| Trigger type | 邊個 fire |
|---|---|
| 25 message / 30% / 60% threshold | Agent 自己 count 住（pre-turn check） |
| Sub-agent 完 | Main agent 收到 sub-agent result 之後自動 |
| Hallucination detect | Agent 自己 detect |
| David 講「/context」 | 即刻 |

**永遠唔好等 David 講先 trigger**。Compression 係 safety net，唔係 feature toggle。

## 8. 永遠唔做

- 唔寫 context summary 直接 continue（會 token 爆）
- Skip 30% / 60% threshold（要提早 trigger）
- 問 David 同樣嘢而唔 detect（要 count 住）
- 新 session 唔 echo resume block
- 寫完 summary 但唔清掉 intermediate（要通知 orchestrator 丢棄）
