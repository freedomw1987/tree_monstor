# Tree Monstor — AI Software Development Team
> **When to read:** On-demand: project overview (user-facing)

> **Status:** Overview. Human entry point for Tree Monstor; canonical rules live in `SOUL.md`, `AGENTS.md`, and `docs/00-index.md`.

> **Claude Code Developer Profile** — Tree Monstor 係 cross-platform profile，但 Codex adapter 已於 2026-07-28 蒸餾移除（David 長期只用 Claude Code）。Claude Code runtime 行為請睇 [`docs/claude-code-workflow.md`](docs/claude-code-workflow.md) 同 [`CLAUDE.md`](CLAUDE.md)。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

---

## ️ 代碼品質鐵律（最高優先級，跨平台適用）

品質判準是「實際執行、觀察行為」，不是「文檔存在」：**先重現、實證驗證、先讀後寫**，優先於所有流程規則。

**文檔齊全 ≠ 代碼正確。測試檔案存在 ≠ 測試通過。**

> 全文（含背景與違反後果）見 [`SOUL.md`](SOUL.md) 紅線 54-56——那裡是唯一 canonical 出處，本段只是入口摘要。

---

## 跨平台適配架構

```
┌─────────────────────────────────────────────────────────────┐
│                    PLATFORM SHELL                           │
│                    Claude Code                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 PLATFORM ENTRY                              │
│  CLAUDE.md                  — Claude Code auto-discovery     │
│  docs/claude-code-workflow.md — Claude Code runtime features │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  CORE IDENTITY                              │
│                                                              │
│  SOUL.md + AGENTS.md + MEMORY.md + docs/ + skills/          │
│  adapters/claude-code/skills/  — Claude Code runtime wrappers│
│                                                              │
│  身份原則、工作流程、QA Gate、Skills                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Where to start

| 如果你想... | 先讀 |
|-------------|------|
| 了解代碼品質鐵律（紅線 54-56） | [`SOUL.md`](SOUL.md)「驗證驅動紅線」段 |
| 5 分鐘內了解這個 profile | [`SOUL.md`](SOUL.md) |
| 啟動一個 session / 理解工作規範 | [`AGENTS.md`](AGENTS.md) |
| 理解長期記憶與穩定偏好 | [`MEMORY.md`](MEMORY.md) |
| 找完整文檔地圖 | [`docs/00-index.md`](docs/00-index.md) |
| 查 subagent 角色矩陣 | [`docs/subagents.md`](docs/subagents.md) |
| 查 QA Gate / 交付門檻 | [`docs/qa-gate.md`](docs/qa-gate.md) |
| 找可復用 skills | [`skills/README.md`](skills/README.md) |

> **Canonical rule**: README 只做入口與概覽；角色、QA、skills 的完整清單以 `docs/` 與 `skills/README.md` 為準。

---

## 這是什麼？

**Tree Monstor** 是一個跨平台的 AI 軟件開發 Profile。它不是普通的 AI 聊天機械人，而是一個具備完整軟件工程能力的**虛擬開發團隊**。

### 核心能力

| 能力 | 說明 |
|------|------|
| **💡 Think** | 市場分析、技術調研、需求挖掘 |
| **📋 Plan** | 商業計劃、PRD、UX Design、系統架構 |
| **⚒️ Build** | 前端 / 後端 / DevOps / Security 開發 |
| **🔍 Review** | SA Code Review、UX 合規檢查 |
| **🧪 Test** | 自動化測試、壓力測試、E2E 測試 |
| **🚀 Ship** | 部署上線、監控、 日誌追蹤 |
| **📝 Reflect** | 復盤總結、技術債追蹤 |

### 與普通 AI 助手的分別

- **普通 AI 助手**：你說什麼，它做什麼，做完就算
- **Tree Monstor**：你描述願景，我問對問題 → 給你選項 → 一起確認方向 → 做完了還要 QA 測試通過才交付

### Subagent 團隊矩陣

Orchestrator 協調 CEO / Researcher / BA / Designer / SA / Frontend / Backend / DevOps / Security / Reviewer / QA / Release 等角色。完整角色矩陣以 [`docs/subagents.md`](docs/subagents.md) 為唯一正本。

---

## 開發流程

**Think → Plan → Build → Review → Test → Ship → Reflect**，帶 Feedback Loop。你描述願景，我問對問題、給選項、確認方向，QA 測試通過才交付。詳細流程與各階段 gate 見 [`docs/phases.md`](docs/phases.md)（唯一正本）。

---

## 如何使用這個 Agent

> **Skill routing 兩層**：
> 1. ✅ **Skill 載入係自動** — 你講嘅訊息命中某 skill 嘅 `trigger:` keyword 時，Claude Code 自動 inject 該 skill 嘅 SKILL.md 內容入 context。例如你講「派 subagent 修 bug」會自動帶入 `skills/orchestrator/SKILL.md` + `skills/regression-guard/SKILL.md`。
> 2. ❌ **Workflow 執行唔自動** — Skill 載入後，Agent 仍要主動 dispatch subagent（call `Agent` tool）、寫 docs、跑 regression loop 等等。
>
> 即係「**睇到**自動，**做**唔自動**」。每個場景你需要嘅 trigger sequence 喺下面。

### 常見場景

### 場景 1：「我想做一個新嘢」（綠field）

```
你：「我想做一個 todo app，要有 due date、tag、filter」
        ↓
Agent 載入 SOUL.md + AGENTS.md（身份 + 流程）
        ↓
Trigger: plan-author skill
        ↓
Think/Plan 互動：
  「MVP 範圍？local storage 定 sync server？」
  「Auth 需要嗎？」
  「Tech stack 選項：Next.js + Postgres / SvelteKit + SQLite / ...」
        ↓
Output（modular plan docs）：
  docs/PRD.md                 ← US index
  docs/US/US-001-add-todo.md
  docs/US/US-002-filter.md
  docs/US/US-003-due-date.md
  docs/DESIGN.md              ← tokens + component index
  docs/components/Button.md    ← contract（no-code rule）
  docs/components/TodoItem.md
  docs/architecture/0001-stack-choice.md
  docs/QA-TRACKER.md          ← US ↔ test
  docs/VERIFY.md
        ↓
Pre-Build Gate: docs_consistency_check.py --project-docs
        ↓
你：「OK 開工」
        ↓
Trigger: orchestrator skill（inner loop 自動啟用）
        ↓
dev + checker per US work item
```

### 場景 2：「接手 existing project」（已有 source code）

```
你：「呢個係 ~/www/legacy-app，幫我補 docs + QA」
        ↓
Trigger: existing-project-intake skill
        ↓
Source-first analysis（唔 hallucinate，係 read source）：
  - 讀 source code、routes、schemas、tests、git history
  - 輸出 docs baseline（8+1 份 docs）
  - monolithic docs 自動拆 per-US / per-component / per-endpoint
        ↓
Output：同場景 1 嘅 plan docs，但係 derive 自 source 而非對話
        ↓
你：「可以開始改 X feature」
        ↓
Trigger: orchestrator skill
```

### 場景 3：「Bug：X」（紅線 54-56 觸發）

```
你：「用戶投訴 login 之後 redirect 去 /projects 但實際係 /」
        ↓
Trigger: regression-guard skill
        ↓
Step 1：先重現（紅線 54）
  寫 failing test 證明 bug
        ↓
Step 2：寫 fix
        ↓
Step 3：RG entry
  docs/REGRESSION-GUARD.md 加 RG-XXX
  source code 加 RG-XXX comment marker
        ↓
Output：bug fixed + regression test 永遠守住
```

### 場景 4：「加 feature / 改 scope」（Build 中）

```
你：「US-005 嘅 filter 加埋 multi-tag AND/OR」
        ↓
Agent 讀 docs/US/US-005-filter.md（modular）
        ↓
Trigger: orchestrator skill § Inner loop
        ↓
dev agent：
  - 改 src/components/Filter.tsx
  - 補 RT-005 regression test
  - 寫 docs/coverage/US-005.md 更新
  - append docs/US/US-005.md changelog 行
        ↓
fresh checker agent（independent subagent）：
  - 讀整份 docs/STATE.md
  - 開 regression 開關實跑全套 regression suite
  - 審計 coverage 表
  - 寫 CK-XXX findings 回 STATE.md
        ↓
loop until VERIFIED 或 escalation
```

### 場景 5：「Review / QA feedback 要落 doc」

```
你：「Reviewer 話 US-012 嘅 AC 唔夠，應加 empty list case」
        ↓
Trigger: docs-sync skill
        ↓
同步：
  docs/US/US-012.md ← append AC checkbox
  docs/coverage/US-012.md ← 加 test inventory row
  docs/QA-TRACKER.md ← Status 改 PARTIAL
        ↓
Spec 改完 → dev 跟改 → checker 覆核
```

### 場景 6：「純研究 / 純閱讀」

```
你：「比較 Elysia vs Hono 嘅 middleware pattern」
        ↓
Agent 走 Think/Plan 互動：
  「2 個 framework 都係 Bun-native；Elysia 強在 type safety，Hono 強在跨 runtime」
  「應用場景？serverless edge 揀 Hono，pure Bun server 揀 Elysia」
  「漏咗咩？Express / Fastify legacy 相容... 」
        ↓
無 doc 產出（research 不需要 commit artifact）
```

---

## 不會自動發生的事

| Agent 唔會...                               | 自動程度  | 你需要...                                                             |
| ----------------------------------------- | ----- | ------------------------------------------------------------------ |
| **Dispatch subagent** 做 multi-subagent 協調 | ❌ 唔自動 | Skill 載入自動，但 dispatch 須主動 call `Agent` tool 開始派工                   |
| **寫 Plan docs**                           | ❌ 唔自動 | `plan-author` 載入自動，但 US / ADR / docs 寫入須主動                         |
| **跑 dev+checker inner loop**              | ❌ 唔自動 | `orchestrator` § Inner loop 載入自動，但 STATE.md 協調 + spawn checker 須主動 |
| **補 RG entry**                            | ❌ 唔自動 | `regression-guard` 載入自動，但 reproduce + fix + RG-XXX 須主動             |
| **寫 retrospective**                       | ❌ 唔自動 | `orchestrator` § Reflect 或 inline retro 須主動                        |
|                                           |       |                                                                    |

### ✅ 自動嘅事（你唔使 trigger）

| 自動發生                                               | 機制                                                          |
| -------------------------------------------------- | ----------------------------------------------------------- |
| Skill SKILL.md 載入 context                          | `trigger:` keywords 命中你嘅訊息（例：「派 subagent」→ orchestrator 載入） |
| Skill description 顯示                               | Claude Code 用 skill frontmatter `description:` 決定係咪相關       |
| Adapter wrappers 啟用 (`/dev-loop`, `/orchestrator`) | 透過 `adapters/claude-code/skills/` symlink                   |

詳見 [`AGENTS.md`](AGENTS.md) § Agent 開發預設路徑 + [`CLAUDE.md`](CLAUDE.md) § Skill routing。

---

## 安裝指南

### Claude Code

Claude Code 的 `CLAUDE.md` auto-discovery 只在 current working directory 及其 parent chain 內有效。**直接 `cd tree_monstor && claude` 不會自動載入**（你的下游 project 才是 cwd）。

推薦做法：建立一個 thin global bridge 指向這個 profile repo。

**1. 全局載入 profile（推薦，所有 project 自動生效）**

建立 `~/.claude/CLAUDE.md`：

```markdown
# David 的全局 Claude Code profile

@~/Sites/localhost/tree_monstor/CLAUDE.md
```

之後 `claude` 開任何 session 都會自動載入 Tree Monstor 紅線、QA Gate、文件索引。

**2. 註冊 skills**

profile 裡的 `skills/*/SKILL.md` 不是 Claude Code 標準位置，需要 symlink：

```bash
mkdir -p ~/.claude/skills
for skill in ~/Sites/localhost/tree_monstor/skills/*/; do
  ln -s "$skill" ~/.claude/skills/
done
```

之後 `/regression-guard`、`/existing-project-intake` 等 skill 直接 invoke。

**3. Per-project 載入（只在某個 project 用）**

在下游 project 根目錄的 `CLAUDE.md` 加：

```markdown
@~/Sites/localhost/tree_monstor/CLAUDE.md
```

**4. 一次性 session（測試用，不展開 import）**

```bash
claude --append-system-prompt-file ~/Sites/localhost/tree_monstor/CLAUDE.md
```

**5. 整個 session 跑成 Tree Monstor agent**

把 profile 包成自訂 subagent 放 `~/.claude/agents/tree-monstor.md`，然後：

```bash
claude --agent tree-monstor
```

詳細文檔：[`CLAUDE.md`](CLAUDE.md) + [docs/claude-code-workflow.md](docs/claude-code-workflow.md)

> Codex adapter 已於 2026-07-28 蒸餾移除（David 長期只用 Claude Code）。如果你之前係 Codex 用家，呢個 profile 仍然可以人手應用 core identity — 讀 SOUL.md + AGENTS.md + docs/phases.md + docs/qa-gate.md，但冇官方 wrapper。

---

## 核心文件

| 文件 | 用途 |
|------|------|
| `SOUL.md` | 身份定位、核心原則、做事方式 |
| `AGENTS.md` | Session 啟動流程、Think/Plan 互動模式 |
| `MEMORY.md` | 長期記憶、Subagent 配置、QA Gate |
| `docs/` | 詳細文檔 |
| `skills/` | 可復用技能庫 |
| `adapters/claude-code/skills/` | Claude Code runtime 已註冊嘅 skill wrappers |

---

## QA Gate（嚴格執行）

未通過 QA Gate，**絕對不會交付**。驗證驅動紅線 54-56（先重現、實證驗證、先讀後寫）優先於一切流程規則。

- 完整交付清單與 gate 定義 → [`docs/qa-gate.md`](docs/qa-gate.md)（唯一正本）
- 紅線全文（基礎紅線 + 文檔紀律 10-12 + 工程紀律 13-18 + 驗證驅動 54-56）→ [`SOUL.md`](SOUL.md)（唯一正本）

> **文檔紀律紅線 10-18 為條件式**：只適用於已採用文檔基線的 project。小型任務或未採用基線的 project，文檔要求降為建議，**不可以因文檔缺失而拒絕交付經實證驗證的代碼**。

---

## 常見問題

**Q: 這個和普通 AI 聊天機械人有什麼不同？**
> 普通 AI 是你說什麼我做什麼。Tree Monstor 是一個團隊，會問你「為什麼要做這個？」、「成功是什麼樣子？」，確保做出來的真的是你需要的。

**Q: 需要懂技術才能用嗎？**
> 不需要。你只需要描述你的業務需求和願景，技術細節全部交給 Developer。

**Q: 支持哪些平台？**
> 主要 Claude Code。Codex adapter 已於 2026-07-28 移除（David 長期只用 Claude Code），但 core identity 仍可手動應用於其他平台。

**Q: 如何更新到最新版本？**
```bash
cd ~/Sites/localhost/tree_monstor && git pull origin master
```

---

## 貢獻

歡迎提交 Issue 或 Pull Request！

---

## License

MIT License

---

<div align="center">

**🌳 Tree Monstor** — 你的 AI 軟件開發團隊

_你描述願景，我來實現。_

</div>

---

## Related docs

- [Documentation index](docs/00-index.md)
- [Core identity](SOUL.md)
- [Session and workspace rules](AGENTS.md)
- [Skills catalog](skills/README.md)
