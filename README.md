# 🌳 Tree Monstor — Developer Profile

> **Hermes Agent 的 Developer Profile** — 你的 AI 軟件開發團隊

[![Hermes Agent](https://img.shields.io/badge/Hermes%20Agent-v2.0-blue)](https://github.com/freedomw1987/hermes-agent)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

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

18 個專業角色，涵蓋軟件開發完整生命週期：

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
    ├── Security ───── 安全審計、滲透測試
    │
    ├── SA Reviewer ── 架構合規審查
    ├── UX Reviewer ── 用戶體驗審查
    ├── QA ─────────── 自動化測試、測試用例
    ├── Performance ── 壓測、效能優化
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

### 在 Hermes Agent 中使用（原生支援）

```bash
# 1. 安裝 Hermes Agent
npm install -g hermes-agent

# 2. 克隆 Developer Profile
git clone git@github.com:freedomw1987/tree_monstor.git ~/.hermes/profiles/developer

# 3. 配置環境變量
cat > ~/.hermes/profiles/developer/.env << 'EOF'
DISCORD_BOT_TOKEN=your_discord_bot_token
OPENROUTER_API_KEY=your_openrouter_key
MINIMAX_API_KEY=your_minimax_key
HERMES_MAX_ITERATIONS=1500
EOF

# 4. 啟動
hermes-agent --profile developer gateway run

# 或使用 systemd（後台運行）
systemctl --user enable hermes-gateway-developer.service
systemctl --user start hermes-gateway-developer.service
```

詳細文檔：[Hermes Agent 安裝](#1-hermes-agent)

### 在 Claude Code 中使用

```bash
# 安裝 Claude Code
curl -1sLf 'https://storage.googleapis.com/claude-code/claude-code-installer.sh' | bash

# 使用 Developer Profile
claude --system-prompt-file ~/.hermes/profiles/developer/SOUL.md

# 或自定義 agent
claude --agent 'developer' --agents '{
  "developer": {
    "description": "AI 軟件開發團隊",
    "system-prompt": "你是一個專業的軟件開發團隊，參考 ~/.hermes/profiles/developer/SOUL.md 工作"
  }
}'
```

詳細文檔：[Claude Code 安裝](#2-claude-code)

### 在 Codex 中使用

```bash
# 安裝 Codex
pip install openai-codex

# 使用 Developer Profile
codex --system-prompt "你是一個專業的軟件開發團隊，參考 ~/.hermes/profiles/developer/SOUL.md 工作。" "幫我創建一個用戶登入系統"
```

詳細文檔：[Codex 安裝](#3-codex)

### 在 OpenClaw 中使用

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

詳細文檔：[OpenClaw 安裝](#4-openclaw)

---

## 核心文件

| 文件 | 用途 |
|------|------|
| `SOUL.md` | 身份定位、核心原則、做事方式 |
| `AGENTS.md` | Session 啟動流程、Think/Plan 互動模式 |
| `MEMORY.md` | 長期記憶、Subagent 配置、QA Gate |
| `docs/phases.md` | Think → Ship → Reflect 詳細流程 |
| `docs/subagents.md` | 18 個 Subagent 角色定義 |
| `docs/qa-gate.md` | QA Gate 交付清單 |
| `skills/` | 可復用技能庫（自動文檔生成、壓測等） |

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
> Discord（主要）、Telegram、Line，以及任何支援 WebSocket 的平台。

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
