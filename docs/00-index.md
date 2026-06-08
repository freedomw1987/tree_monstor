# 文檔索引 — Developer Profile

## 核心文件

| 文件 | 行數目標 | 用途 |
|------|----------|------|
| `SOUL.md` | ~80 | 身份定位、核心原則、開發流程索引 |
| `AGENTS.md` | ~60 | Session 啟動流程、工作區規範 |
| `MEMORY.md` | ~100 | 長期記憶、角色配置 |

## 詳細規則（引用文檔）

| 文檔 | 內容 |
|------|------|
| `docs/phases.md` | Think → Plan → Build → Review → Test → Ship → Reflect 詳細流程 + QA Gate |
| `docs/subagents.md` | Subagent 角色矩陣（18 個角色）、Model Tiering |
| `docs/failure-policy.md` | 失敗處理機制（L1/L2/L3） |
| `docs/task-board.md` | Task Board 格式 + 更新規則 |
| `docs/qa-gate.md` | QA Gate 交付清單 |
| `docs/pm.md` | PM 進度追蹤、用戶溝通原則 |
| `docs/checkpoint.md` | Checkpoint 機制 + Feedback Loop 記錄 |
| `docs/devops.md` | DevOps 規範、Zombie 處理 |
| `docs/feedback-loop.md` | Feedback Loop 流程 + 獎勵/罰則 |
| `docs/project-documentation-standard.md` | **🆕 項目文檔規格** — 每個 project 必有的 8 份文件 + commit 規範 |
| `docs/qa-tracker.md` | **🆕 QA 持續追蹤** — US → test task 對照、需求變更影響評估 |
| `docs/testing-strategy.md` | **🆕 測試策略** — 12 層測試類型 + 健康指標 + 工具鏈 |

---

## 設計原則

> **核心文件保持簡潔，詳細規則放在引用文檔。**

---

## Think → Plan → Build → Review → Test → Ship → Reflect

```
用戶需求
    ↓
Think ── CEO 市場分析 + Researcher 技術調研 ──────────┐
    ↓                                                 │
Plan ── CEO 商業計劃 + BA + Designer + SA + Tech Lead ┤
    ↓                                                 │ Feedback
Build ── Frontend + Backend + DevOps + Security Eng   ┤   Loop
    ↓                                                 │
Review ── SA Reviewer + UX Reviewer                   ┤
    ↓                                                 │
Test ── QA + Performance Engineer                     ┤
    ↓                                                 │
Ship ── Release Manager                               ┘
    ↓
Reflect ── Retrospective
    ↓
交付用戶
```

## Subagent 角色（18 個）

| 角色 | 階段 |
|------|------|
| Orchestrator | 全域 — 任務協調 |
| CEO | Think + Plan |
| Researcher | Think |
| Tech Lead | Plan |
| BA | Plan |
| Designer | Plan |
| SA | Plan |
| Frontend | Build |
| Backend | Build |
| DevOps | Build |
| Security Engineer | Build + Review |
| SA Reviewer | Review |
| UX Reviewer | Review |
| QA | Test |
| Performance Engineer | Test |
| Release Manager | Ship |
| Retrospective | Reflect |
| Tech Debt Tracker | Build + Sprint |
| Documentation Engineer | Build |
| Sprint Manager | Plan + Reflect |
| Dependency Manager | Build |
| Context Manager | Build（長期任務） |
| Observability Monitor | Build（長期任務） |

---

## 新增 Skills

| Skill | 用途 |
|-------|------|
| `auto-doc-gen` | 從代碼註解自動生成 API docs |
| `context-summarizer` | 定時壓縮 long-task context |
| `tech-debt-register` | 記錄 tech debt 的模板 |
| `development-watchdog` | 監控 subagent 健康、Zombie 檢測 |

---

## 質量標準

- **QA Gate 未通過，絕對不能交付**
- Review 未 APPROVED，絕對不能進入 Test
- 所有強制 Phase 必須完成才能進入下一階段
- **紅線 10-18(David 2026-06-06 kanban task 強化)**:
  - 紅線 10:沒文件的代碼不能 merge(8 份必備文檔)
  - 紅線 11:改 PRD 必更新 QA-TRACKER
  - 紅線 12:P0/P1 US 必須有 test tasks
  - 紅線 13:bug fix 必須有 RG-XXX entry
  - 紅線 14:bug fix 必須有 root cause + prevention
  - 紅線 15:refactor 不可違反 RG invariant
  - 紅線 16:P0 US 必須三層測試(Unit + Integration + E2E)
  - 紅線 17:deploy 前必跑 smoke test
  - 紅線 18:Critical/High CVE 必為 0