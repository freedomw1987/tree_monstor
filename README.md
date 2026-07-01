# 🌳 Tree Monstor — AI Software Development Team

> **Status:** Overview. Human entry point for Tree Monstor; canonical rules live in `SOUL.md`, `AGENTS.md`, and `docs/00-index.md`.

> **Cross-Platform Developer Profile** — 可用於 Hermes Agent、Claude Code、Codex

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

---

## 跨平台適配架構

```
┌─────────────────────────────────────────────────────────────┐
│                    PLATFORM SHELL                           │
│        Hermes Agent / Claude Code / Codex                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 PLATFORM ADAPTER LAYER                      │
│  adapters/                                                  │
│  ├── claude-code/agent.md     — Claude Code agent 定義     │
│  ├── codex/system-prompt.md   — Codex 系統提示             │
│  └── hermes/                   — Hermes 配置                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  CORE IDENTITY (跨平台共享)                 │
│                                                              │
│  SOUL.md + AGENTS.md + MEMORY.md + docs/ + skills/          │
│                                                              │
│  所有平台共用的核心：身份原則、工作流程、QA Gate、Skills     │
└─────────────────────────────────────────────────────────────┘
```

### 平台支援矩陣

| 平台 | 機制 | 狀態 |
|------|------|------|
| **Hermes Agent** | Profile directory + gateway | ✅ 主要支援 |
| **Claude Code** | root `CLAUDE.md` bridge + optional `--agent-file` adapter | ✅ 已適配 |
| **Codex** | `--system-prompt` 文件 | ✅ 已適配 |
| **OpenClaw** | system-prompt import | 🧪 實驗 / 社群使用 |

---

## Where to start

| 如果你想... | 先讀 |
|-------------|------|
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

**Tree Monstor** 是一個運行在 [Hermes Agent](https://github.com/freedomw1987/hermes-agent) 框架內的 AI 軟件開發 Profile。它不是普通的 AI 聊天機械人，而是一個具備完整軟件工程能力的**虛擬開發團隊**。

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

完整角色矩陣以 [`docs/subagents.md`](docs/subagents.md) 為 canonical source；README 只展示核心工作流視角：

```
Orchestrator ──── 任務協調（全局視角）
    │
    ├── CEO ───────── 市場分析、商業計劃
    ├── Researcher ─── 技術調研、技術選型
    ├── BA ────────── 需求分析、PRD 編寫
    ├── Designer ───── UI/UX 設計、Design System
    ├── SA ────────── 架構設計、技術方案
    │
    ├── Frontend ───── React / Vue / Mobile
    ├── Backend ────── Node.js / Python / Go / Rust
    ├── DevOps ─────── CI/CD、Docker、K8s、AWS
    ├── Security Engineer ─ 安全審計、滲透測試
    │
    ├── SA Reviewer ── 架構合規審查
    ├── UX Reviewer ── 用戶體驗審查
    ├── QA ─────────── 自動化測試、測試用例
    ├── Performance Engineer ─ 壓測、效能優化
    │
    ├── Release Manager 部署、迴滾策略
    └── Retrospective ─ 復盤、持續改進
```

---

## 開發流程

```
你：「我想做一個線上課程平台」

         ↓
    ┌───────────────────────────────────────┐
    │  Think                                │
    │  「您是 B2C 還是 B2B？目標用戶是誰？」 │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Plan                                 │
    │  提供 2-3 個技術架構選項               │
    │  確認商業模式、優先級、MVP 範圍       │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Build                                │
    │  Frontend + Backend + DevOps 同時開發  │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Review                               │
    │  SA Reviewer 審查架構                 │
    │  UX Reviewer 審查介面                 │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Test                                 │
    │  E2E 測試、效能測試、安全掃描         │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Ship                                 │
    │  部署到生產環境、監控、告警           │
    └───────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────┐
    │  Reflect                              │
    │  復盤總結、記錄技術債、持續改進       │
    └───────────────────────────────────────┘
```

---

## 安裝指南

### Hermes Agent (macOS / Linux)

> 推薦用我們提供的啟動腳本(自動找 hermes CLI、檢查 .env、載入 SOUL.md):

```bash
# 1. 克隆 profile
git clone git@github.com:freedomw1987/tree_monstor.git ~/.hermes/profiles/developer

# 2. 編輯 .env 填入你的 tokens(**用 nano,不要 echo 進去**)
cp ~/.hermes/profiles/developer/adapters/hermes/.env.template \
   ~/.hermes/profiles/developer/.env
nano ~/.hermes/profiles/developer/.env

# 3. 啟動(一鍵)
~/.hermes/profiles/developer/LAUNCH.sh
# 或互動式:
hermes --profile developer
# 或跑 gateway:
hermes --profile developer gateway run
```

> ⚠️ **README 早期版本的 `hermes-agent --profile developer gateway run` 指令是過期的** — Hermes 0.15.1 的主程式叫 `hermes`,且 `gateway run` 是 subcommand。請用 `hermes --profile developer gateway run`(中間加 `--profile` flag)。

macOS / launchd 背景服務化、故障排除、跟 default profile 的並存設定,見:
- [adapters/hermes/README.md](adapters/hermes/README.md) — adapter 專用指南
- [setup-macos.md](setup-macos.md) — 完整 macOS 設定 runbook

### Claude Code

推薦方式：在 repo root 直接開啟 Claude Code，讓 root [`CLAUDE.md`](CLAUDE.md) 自動 bridge 到 `SOUL.md`、`AGENTS.md`、`MEMORY.md`、`docs/00-index.md`、`skills/README.md` 與 Claude Code adapter。

```bash
cd ~/.hermes/profiles/developer  # 或你的 tree_monstor clone path
claude
```

進階 / explicit adapter mode（如你的 Claude Code 版本支援）：

```bash
claude --agent-file adapters/claude-code/agent.md
```

Fallback system-prompt mode（較少 Claude Code-specific routing）：

```bash
claude --system-prompt-file SOUL.md
```

詳細文檔：[`CLAUDE.md`](CLAUDE.md) + [adapters/claude-code/agent.md](adapters/claude-code/agent.md)

### Codex

```bash
# 使用 system-prompt 文件
codex --system-prompt "$(cat adapters/codex/system-prompt.md)" "幫我創建一個用戶登入系統"
```

詳細文檔：[adapters/codex/system-prompt.md](adapters/codex/system-prompt.md)

### 在 OpenClaw 中使用（實驗 / 社群）

```bash
# 安裝 OpenClaw
npm install -g openclaw

# 添加 Developer Agent
openclaw agents add developer \
  --system-prompt-file ~/.hermes/profiles/developer/SOUL.md \
  --description "AI 軟件開發團隊"

# 啟動
openclaw --profile developer gateway run
```

OpenClaw 只負責把 Developer Profile 接入 orchestration shell；角色定義、工作流程、QA Gate 仍以 `SOUL.md`、`AGENTS.md`、`MEMORY.md`、`docs/`、`skills/` 為 canonical source。

---

## 核心文件

| 文件 | 用途 |
|------|------|
| `SOUL.md` | 身份定位、核心原則、做事方式（跨平台共享） |
| `AGENTS.md` | Session 啟動流程、Think/Plan 互動模式（跨平台共享） |
| `MEMORY.md` | 長期記憶、Subagent 配置、QA Gate（跨平台共享） |
| `docs/` | 詳細文檔（跨平台共享） |
| `skills/` | 可復用技能庫（跨平台共享） |
| `adapters/` | 平台特定適配層（Hermes/Claude Code/Codex） |

---

## QA Gate（嚴格執行）

未通過以下清單，**絕對不會交付**：

- [ ] Think: CEO 市場分析 + Researcher 調研報告完成
- [ ] Plan: 商業計劃 + PRD + Design + Architecture 確認
- [ ] Build: 所有代碼已提交
- [ ] Review: SA Reviewer APPROVED + UX Reviewer APPROVED
- [ ] Test: E2E 測試 100% 通過、效能測試通過
- [ ] Security: 安全掃描通過
- [ ] Ship: 生產環境部署確認
- [ ] Reflect: 復盤報告完成

---

## 紅線（底線原則）

```
❌ 不跳過 QA Gate 就交付
❌ 不在未通過測試的情況下部署
❌ 不寫有安全漏洞的代碼（SQL Injection、XSS 等）
❌ 不提交明文密鑰或 Secrets
❌ 不只執行命令 — Think/Plan 階段必須問對問題
```

---

## 常見問題

**Q: 這個和普通 AI 聊天機械人有什麼不同？**
> 普通 AI 是你說什麼我做什麼。Tree Monstor 是一個團隊，會問你「為什麼要做這個？」、「成功是什麼樣子？」，確保做出來的真的是你需要的。

**Q: 需要懂技術才能用嗎？**
> 不需要。你只需要描述你的業務需求和願景，技術細節全部交給 Developer。

**Q: 支持哪些平台？**
> Hermes Agent、Claude Code、Codex — 使用同一套核心身份，平台適配層分開。

**Q: 如何更新到最新版本？**
```bash
cd ~/.hermes/profiles/developer && git pull origin master
```

---

## 貢獻

歡迎提交 Issue 或 Pull Request！

---

## License

MIT License — [Hermes Agent](https://github.com/freedomw1987/hermes-agent)

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
