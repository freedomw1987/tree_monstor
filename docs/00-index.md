# 文檔索引 — Developer Profile

## 核心文件

| 文件 | 行數目標 | 實際 | 用途 |
|------|----------|------|------|
| `SOUL.md` | ~80 | ~150 | 身份定位、核心原則、開發流程索引 |
| `AGENTS.md` | ~60 | ~100 | Session 啟動流程、工作區規範 |
| `MEMORY.md` | ~100 | — | 長期記憶、角色配置 |

## 詳細規則（引用文檔）

| 文檔 | 內容 |
|------|------|
| `docs/phases.md` | Phase 0~4 詳細流程 + QA Gate |
| `docs/subagents.md` | Subagent 角色矩陣、Model Tiering |
| `docs/failure-policy.md` | 失敗處理機制（L1/L2/L3） |
| `docs/task-board.md` | Task Board 格式 + 更新規則 |
| `docs/qa-gate.md` | QA Gate 交付清單（11 項） |
| `docs/pm.md` | PM 進度追蹤、用戶溝通原則 |
| `docs/checkpoint.md` | Checkpoint 機制 + Feedback Loop 記錄 |
| `docs/devops.md` | DevOps 規範、Zombie 處理 |
| `docs/feedback-loop.md` | Feedback Loop 流程 + 獎勵/罰則 |

---

## 設計原則

> **核心文件保持簡潔，詳細規則放在引用文檔。**
> 
> 這讓 LLM 能快速理解 Developer 的核心定位，詳細規範則在需要時查閱。

---

## Phase 流程總覽

```
用戶需求
    ↓
Phase 0 BA 商業分析 ────────────────────────────────────────┐
    ↓                                                       │
Phase 0.5 UI/UX 設計 ────────────────────────────────────┐  │
    ↓                                                      │ Feedback
Phase 1 SA 架構設計 ──────────────────────────────────┐  │  Loop
    ↓                                                    │  │
Phase 2 執行開發（Frontend + Backend + DevOps）        │  │
    ↓                                                    │  │
Phase 3 SA Code Review ←───────────────────────────────┘  │
    ↓                                                      │
Phase 4 QA 測試 ←─────────────────────────────────────────┘
    ↓
QA Gate（11 項全部通過）
    ↓
交付用戶
```

---

## 質量標準

- **QA Gate 未通過，絕對不能交付**
- 代碼 Review 未 APPROVED，絕對不能進入 QA
- PRD 是需求合約，SA/QA 必須 100% 遵守
