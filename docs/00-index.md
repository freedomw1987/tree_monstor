# 文檔索引 — Developer Profile

> **Status:** Index. Documentation map for active Tree Monstor profile docs.

> **用途**：這份文件是 Tree Monstor Developer Profile 的文檔地圖。新文檔加入 `docs/` 時，請同步更新本索引。

---

## 核心文件

| 文件 | 狀態 | 用途 |
|------|------|------|
| [`../README.md`](../README.md) | Overview | 人類入口、平台支援、快速開始 |
| [`../CLAUDE.md`](../CLAUDE.md) | Adapter / Bridge | Claude Code auto-discovery bridge；指向 canonical profile docs 與 Claude Code adapter |
| [`../SOUL.md`](../SOUL.md) | Canonical | 身份定位、核心原則、QA 姿態、紅線索引 |
| [`../AGENTS.md`](../AGENTS.md) | Canonical | Session 啟動流程、工作區規範、長任務判斷 |
| [`../MEMORY.md`](../MEMORY.md) | Canonical | 長期記憶、穩定偏好、常用流程摘要 |

---

## Canonical sources

| Topic | Canonical source | Notes |
|-------|------------------|-------|
| Identity / philosophy | [`SOUL.md`](../SOUL.md) | 只放身份、流程、紅線和引用；避免變成完整 inventory |
| Session startup / workspace | [`AGENTS.md`](../AGENTS.md) | Goal 確認、Think/Plan 互動、工作區規範 |
| Long-term memory | [`MEMORY.md`](../MEMORY.md) | 穩定記憶摘要；不維護完整 skills / roles 清單 |
| Claude Code entry bridge | [`CLAUDE.md`](../CLAUDE.md) + [`adapters/claude-code/agent.md`](../adapters/claude-code/agent.md) | Claude Code startup / routing only；canonical behavior 仍在 SOUL / AGENTS / MEMORY / docs / skills |
| Phase workflow | [`docs/phases.md`](phases.md) | Think → Plan → Build → Review → Test → Ship → Reflect |
| Subagent role matrix | [`docs/subagents.md`](subagents.md) | 角色清單、輸入/輸出、model 選擇原則；不要在其他文件硬寫角色數量 |
| Task Board format | [`docs/task-board.md`](task-board.md) | Canonical spelling uses hyphen: `docs/task-board.md` |
| QA Gate | [`docs/qa-gate.md`](qa-gate.md) | Pre-Build documentation gate、doc-code sync、release / merge 交付門檻 |
| Testing strategy | [`docs/testing-strategy.md`](testing-strategy.md) | 測試層級、P0/P1 測試深度、健康指標 |
| Regression hooks / QA regression mode | [`docs/testing-strategy.md`](testing-strategy.md) + [`docs/qa-gate.md`](qa-gate.md) + [`skills/regression-guard/SKILL.md`](../skills/regression-guard/SKILL.md) | Frontend/backend regression hooks、QA 啟用方式、production safety boundary |
| Project documentation standard | [`docs/project-documentation-standard.md`](project-documentation-standard.md) | 每個 project 的標準文件、Build 前 documentation baseline 與 commit 規範 |
| Skills catalog | [`skills/README.md`](../skills/README.md) | Local skills catalog；每個 skill 的 source 是 `skills/<name>/SKILL.md` |

---

## 詳細文檔地圖

| 文檔 | 狀態 | 內容 |
|------|------|------|
| [`docs/00-index.md`](00-index.md) | Index | 本文檔地圖；所有 top-level `docs/*.md` 應在此列出 |
| [`docs/cross-platform-usage.md`](cross-platform-usage.md) | Reference | Claude Code / Codex 跨平台使用指南 |
| [`docs/devops.md`](devops.md) | Runbook | DevOps 規範、process 管理、Zombie 處理 |
| [`docs/environment-isolation.md`](environment-isolation.md) | Canonical | Dev / Prod / Agent Config 環境隔離規範 |
| [`docs/failure-policy.md`](failure-policy.md) | Canonical | 失敗處理機制（L1/L2/L3） |
| [`docs/feedback-loop.md`](feedback-loop.md) | Canonical | Feedback Loop 流程、Review/Test fail 後如何迭代 |
| [`docs/phases.md`](phases.md) | Canonical | Think → Plan → Build → Review → Test → Ship → Reflect 詳細流程 |
| [`docs/project-documentation-standard.md`](project-documentation-standard.md) | Standard | Project 標準文檔、commit 規範、文件 drift 要求 |
| [`docs/qa-gate.md`](qa-gate.md) | Canonical | QA Gate 交付清單、文檔 gate、tracker gate、testing gate |
| [`docs/qa-tracker.md`](qa-tracker.md) | Tracker | QA 持續追蹤；US → test task 對照、需求變更影響評估 |
| [`docs/subagents.md`](subagents.md) | Canonical | Subagent 角色矩陣、Goal 關鍵字、調度規則、model 選擇原則 |
| [`docs/task-board.md`](task-board.md) | Canonical | Task Board 格式、狀態定義、更新規則、PM 進度追蹤與用戶溝通原則 |
| [`docs/testing-strategy.md`](testing-strategy.md) | Canonical | 分層測試類型、健康指標、工具鏈 |
| [`docs/think-plan-examples.md`](think-plan-examples.md) | Reference | Think / Plan 互動範例、架構選項與提問方式 |

---

## 設計原則

> **核心文件保持簡潔，詳細規則放在引用文檔。**

- `README.md`：人類入口，不維護完整角色 / skills / QA 清單。
- `SOUL.md`：身份、核心原則、紅線與索引，不做大型 inventory。
- `AGENTS.md`：session 啟動與工作區規範。
- `MEMORY.md`：長期穩定記憶，不複製完整 catalog。
- `docs/*.md`：各 topic 的 canonical 規則與 reference。
- `skills/*/SKILL.md`：每個 skill 的真正 source of truth。

---

## Think → Plan → Build → Review → Test → Ship → Reflect

完整 phase 定義、各階段角色與 gate 見 [`docs/phases.md`](phases.md)（唯一正本）。

---

## Subagent roles

完整角色矩陣、職責、輸入/輸出與調度規則見 [`docs/subagents.md`](subagents.md)。

> 不要在本索引或 root docs 硬寫角色數量；新增 / 刪除角色時，先更新 `docs/subagents.md`，其他文件只引用 canonical source。

---

## Skills

Local skills catalog 見 [`skills/README.md`](../skills/README.md)。

> 不要在 `README.md` / `SOUL.md` / `MEMORY.md` / `AGENTS.md` / `docs/00-index.md` 維護 partial skill list 或硬寫 skill count。每個 skill 的 source of truth 是 `skills/<name>/SKILL.md`。

---

## 質量標準

- **紅線 54-56（驗證驅動，最高優先級）**：修 bug 先重現、交付前實證驗證、改 code 前先讀後寫 → 見 [`SOUL.md`](../SOUL.md)
- **QA Gate 未通過，絕對不能交付**；Build 前 documentation baseline / doc-code sync 亦屬 gate（適用於已採用文檔基線嘅 project）→ 見 [`docs/qa-gate.md`](qa-gate.md) + [`docs/project-documentation-standard.md`](project-documentation-standard.md)
- Review 未 APPROVED，絕對不能進入 Test → 見 [`docs/feedback-loop.md`](feedback-loop.md)
- 所有強制 Phase 必須完成才能進入下一階段 → 見 [`docs/phases.md`](phases.md)
- **紅線 10-18**（文檔 gate、QA tracker、test tasks、regression guard、root cause、refactor invariant、三層測試、smoke test、CVE 0）→ 見 [`SOUL.md`](../SOUL.md) + [`docs/qa-gate.md`](qa-gate.md)

---

## 維護規則

新增或修改文檔時：

1. 新增 top-level `docs/*.md` → 同步更新本索引。
2. 新增 / 刪除 / 改名 `skills/<name>/SKILL.md` → 同步更新 [`skills/README.md`](../skills/README.md)。
3. 不在 root docs 寫會 drift 的數字（角色數、skill 數、line count）。
4. 歷史 incident docs 保留事實，不把 incident 當成現行 policy；現行 policy 應抽到 canonical docs。
5. 文檔 / skills 導航改動後，執行 `python3 scripts/docs_consistency_check.py`，確保 index、catalog、status markers、related links 與本地連結沒有 drift。
6. （可選）啟用 pre-commit 兜底：`git config core.hooksPath .githooks` — 之後每次 commit 自動跑上述 checker + catalog freshness check；GitHub push / PR 亦有 `.github/workflows/docs-check.yml` 跑同一套。

---

## Related docs

- [README](../README.md)
- [Core identity](../SOUL.md)
- [Session and workspace rules](../AGENTS.md)
- [Skills catalog](../skills/README.md)
