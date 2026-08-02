# 文檔索引 — Developer Profile
> **When to read:** Always

> **Status:** Index. Documentation map for active Tree Monstor profile docs.

> **用途**：這份文件是 Tree Monstor Developer Profile 的文檔地圖。新文檔加入 `docs/` 時，請同步更新本索引。
>
> **結構**：Always（每 session 讀）→ Plan → Build → Ship → Reflect → On-demand。Agent 按當前任務階段只讀對應 phase 的文檔，不必掃整個 map。

---

## Always（每 session 必讀）

| 文件 | 用途 |
|------|------|
| [`../CLAUDE.md`](../CLAUDE.md) | Claude Code auto-discovery entrypoint；鐵律 + skill routing + verify gates |
| [`../SOUL.md`](../SOUL.md) | 身份定位、核心原則、紅線索引 |
| [`../AGENTS.md`](../AGENTS.md) | Session 啟動流程、工作區規範、長任務判斷 |
| [`../MEMORY.md`](../MEMORY.md) | 長期記憶、穩定偏好、常用流程摘要 |
| `docs/00-index.md`（本檔） | 文檔地圖（按 phase 組織） |

## Plan（規劃 / 規格）

| 文件 | 用途 |
|------|------|
| [`docs/phases.md`](phases.md) | Think → Plan → Build → Review → Test → Ship → Reflect 詳細流程 |
| [`docs/task-tiering.md`](task-tiering.md) | 任務分級（T1/T2/T3）、小型任務判準、例外申報格式 |
| [`docs/project-documentation-standard.md`](project-documentation-standard.md) | Project 標準文檔、Build 前 documentation baseline；templates 在 `docs/project-doc-templates/` |
| [`docs/project-doc-templates/`](project-doc-templates/) | 14 個 per-doc templates（US、component contract、endpoint resource 等） |
| [`docs/think-plan-examples.md`](think-plan-examples.md) | Think / Plan 互動範例、架構選項與提問方式 |

## Build（開發 / 品質）

| 文件 | 用途 |
|------|------|
| [`docs/subagents.md`](subagents.md) | Subagent 角色矩陣（具體角色數見 canonical source；orchestrator skill 是實際 entry） |
| [`docs/devops.md`](devops.md) | DevOps 規範、process 管理、Zombie 處理 |
| [`docs/environment-isolation.md`](environment-isolation.md) | Dev / Prod / Agent Config 三層環境隔離 |
| [`docs/claude-code-workflow.md`](claude-code-workflow.md) | Claude Code runtime features：Dynamic Workflow / ultracode / 多 agent 編排 |
| `skills/orchestrator/SKILL.md` | Multi-subagent + per-work-item dev+checker loop（內外層一體，2026-08-02 合併 dev-checker-loop） |
| `skills/regression-guard/SKILL.md` | bug fix SOP、RG-XXX entry format、QA enablement |
| `skills/docs-sync/SKILL.md` | Review / QA feedback → durable docs（per-modular-doc sync rules） |
| `skills/existing-project-intake/SKILL.md` | 接手現有 project 的 source-first baseline 流程 |
| `skills/patch-corruption-recovery/SKILL.md` | replace-all / fuzzy-match edit 崩潰嘅救援 |
| `skills/structural-doc-batch/SKILL.md` | 一次過補齊 8 份結構性文檔（modular docs） |

## Ship（驗證 / 上線）

| 文件 | 用途 |
|------|------|
| [`docs/qa-gate.md`](qa-gate.md) | QA Gate 交付清單、Pre-Build documentation gate、doc-code sync、release / merge 門檻 |
| [`docs/qa-tracker.md`](qa-tracker.md) | US ↔ test task 對照、需求變更影響評估 |
| [`docs/testing-strategy.md`](testing-strategy.md) | 13 層測試策略、健康指標、工具鏈 |
| [`docs/testing-strategy-tiered.md`](testing-strategy-tiered.md) | 按 project 成熟度 T1/T2/T3 必做 / 應做 / 選做 |
| [`docs/flaky-test-handling.md`](flaky-test-handling.md) | Flaky test 偵測 / Quarantine / 修 / 預防 SOP |
| `skills/orchestrator/` slash command（adapter → orchestrator canonical；`/dev-loop` 亦 redirect） | inner loop quick-start — 已於 2026-08-02 合併到 orchestrator skill |
| `skills/devops/dependency-cve-audit/SKILL.md` | Critical/High CVE = 0 才可 merge（紅線 18） |
| `skills/tech-debt-register/SKILL.md` | TECH-DEBT.md 5-field format |

## Reflect（復盤 / 失敗處理）

| 文件 | 用途 |
|------|------|
| [`docs/failure-policy.md`](failure-policy.md) | L1/L2/L3 失敗處理 + 進度停滯檢測 |
| [`docs/feedback-loop.md`](feedback-loop.md) | Review/Test fail iteration 規則 + 獎勵 / 罰則 |
| [`docs/task-board.md`](task-board.md) | Task Board 格式 + PM 進度追蹤與用戶溝通原則 |

## On-demand（特定場景）

| 文件 | 用途 |
|------|------|
| [`../README.md`](../README.md) | Human-facing overview；不是 agent 工作入口 |
| [`docs/subagents.md`](subagents.md) | Conceptual role matrix；新增 / 刪除角色時才讀 |
| `skills/README.md` | Skills catalog；只在確認 local skill 是否存在時讀 |
| `SOUL-rationale.md` | SOUL.md 嘅 why / how / when-not context；反思 / 衝突解決時讀 |

---

## 設計原則

> **核心文件保持簡潔，詳細規則放在引用文檔。**

- `README.md`：人類入口，不維護完整角色 / skills / QA 清單
- `SOUL.md`：身份、核心原則、紅線與索引，不做大型 inventory
- `AGENTS.md`：session 啟動與工作區規範
- `MEMORY.md`：長期穩定記憶，不複製完整 catalog
- `docs/*.md`：各 topic 的 canonical 規則與 reference
- `skills/*/SKILL.md`：每個 skill 的真正 source of truth

## 維護規則

新增或修改文檔時：

1. 新增 top-level `docs/*.md` → 同步更新本索引對應 phase section
2. 新增 / 刪除 / 改名 `skills/<name>/SKILL.md` → 同步更新 [`skills/README.md`](../skills/README.md)
3. 不在 root docs 寫會 drift 的數字（角色數、skill 數、line count）
4. 歷史 incident docs 保留事實，不把 incident 當成現行 policy；現行 policy 應抽到 canonical docs
5. 文檔 / skills 導航改動後，執行 `python3 scripts/docs_consistency_check.py`，確保 index、catalog、status markers、related links 與本地連結沒有 drift
6. （可選）啟用 pre-commit 兜底：`git config core.hooksPath .githooks` — 之後每次 commit 自動跑上述 checker + catalog freshness check；GitHub push / PR 亦有 `.github/workflows/docs-check.yml` 跑同一套

---

## Related docs

- [README](../README.md)
- [Core identity](../SOUL.md)
- [Session and workspace rules](../AGENTS.md)
- [Skills catalog](../skills/README.md)