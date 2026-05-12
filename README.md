# Hermes Developer Profile

> Hermes Agent 的 Developer Profile — 你的 AI 軟件開發團隊

## 這是什麼？

Developer Profile 是運行在 **Hermes Agent** 框架內的 AI 軟件開發專家。它不是普通的 AI 助手，而是一個具備完整開發能力的虛擬團隊：

- **Think / Plan 階段**：深度理解需求，提供選項，問對問題
- **Build 階段**：獨立完成前端、後端、架構設計、DevOps
- **Review 階段**：代碼審查、UX 合規檢查
- **Test 階段**：自動化測試、壓測
- **Ship 階段**：部署上線

### 核心原則

- **用戶只需要描述願景** — 你說出來，我來實現
- **不只執行命令** — 我會挑戰你、給你更好的方案
- **未通過 QA Gate 絕不交付**

---

## 安裝方法

### Hermes Agent（推薦）

Hermes Agent 是這個 Profile 的運行時。需要 Node.js 18+。

```bash
# 方法一：npm 全域安裝
npm install -g hermes-agent
hermes-agent --version

# 方法二：使用 npx 直接運行
npx hermes-agent@latest --profile developer

# 方法三：從源碼安裝
git clone https://github.com/freedomw1987/hermes-agent.git
cd hermes-agent
npm install
npm run build
node dist/index.js --profile developer
```

#### 配置 Profile

```bash
# 創建 developer profile
hermes profile create developer

# 配置 Discord 機器人 Token（編輯 .env）
cat > ~/.hermes/profiles/developer/.env << 'EOF'
DISCORD_BOT_TOKEN=your_bot_token_here
OPENROUTER_API_KEY=your_api_key
MINIMAX_API_KEY=your_api_key
HERMES_MAX_ITERATIONS=1500
EOF

# 啟動服務
systemctl --user enable hermes-gateway-developer.service
systemctl --user start hermes-gateway-developer.service
```

---

### Claude Code（Anthropic 官方 CLI）

適用於需要直接在本地終端使用 Claude 的開發者。

```bash
# macOS / Linux
curl -1sLf 'https://storage.googleapis.com/claude-code/claude-code-installer.sh' | bash

# 或使用 npm
npm install -g @anthropic-ai/claude-code

# 安裝後運行
claude

# 常用命令
claude --help              # 查看幫助
claude -p "你的問題"       # 單次 prompt 模式
claude --model claude-opus-4  # 指定模型
```

---

### Codex（OpenAI 官方 CLI）

OpenAI 的命令行編程工具，專注於代碼生成和修改。

```bash
# 安裝
pip install openai-codex

# 或使用 brew（macOS）
brew install openai-codex

# 首次使用需設置 API Key
export OPENAI_API_KEY=your_api_key

# 運行
codex

# 無頭模式（無需 UI）
codex --mode headless "你的指令"
```

---

### OpenClaw（複合工具）

本地運行的 agent 工具，整合多種能力。

```bash
# npm 全域安裝
npm install -g openclaw

# 首次運行，會引導配置
openclaw --setup

# 常用命令
openclaw --help
openclaw agent "你的任務"
openclaw gateway --port 18789   # 啟動 gateway
```

#### 環境變量

```bash
export OPENCLAW_API_KEY=your_api_key
export OPENCLAW_CONFIG_DIR=~/.openclaw
```

---

## 快速開始

### 1. 啟動 Developer Profile

```bash
# 使用 hermes-agent
hermes-agent --profile developer gateway run

# 或使用 systemd（後台運行）
systemctl --user start hermes-gateway-developer.service
journalctl --user -u hermes-gateway-developer.service -f
```

### 2. 連接 Discord

1. 在 Discord Developer Portal 創建 Application
2. 添加 Bot，獲取 Token
3. 配置 `.env` 中的 `DISCORD_BOT_TOKEN`
4. 使用 OAuth2 URL 邀請 Bot 到服務器

### 3. 開始開發

```
你：我想做一個課程管理系統
Bot：好的！在開始之前，我想確認幾個方向...
```

---

## 文件結構

```
~/.hermes/profiles/developer/
├── SOUL.md              # 身份定位、核心原則
├── AGENTS.md            # Session 啟動流程
├── MEMORY.md            # 長期記憶
├── README.md            # 本文件
├── config.yaml          # 運行配置
├── .env                 # 環境變量（API Keys）
├── docs/                # 完整文檔
│   ├── 00-index.md      # 文檔索引
│   ├── phases.md        # Think→Build→Ship 流程
│   ├── subagents.md     # 18 個 Subagent 角色
│   ├── qa-gate.md       # QA Gate 交付清單
│   └── ...
└── skills/              # 可復用技能庫
```

---

## 開發流程

```
需求輸入
    ↓
Think ── 市場分析 + 技術調研
    ↓
Plan ── 商業計劃 + 架構設計
    ↓
Build ── 前端 / 後端 / DevOps
    ↓
Review ── SA Code Review
    ↓
Test ── 自動化測試
    ↓
Ship ── 部署上線
    ↓
Reflect ── 復盤總結
```

---

## 常見問題

### Q: 如何查看運行日誌？
```bash
journalctl --user -u hermes-gateway-developer.service -f
tail -f ~/.hermes/profiles/developer/logs/gateway.log
```

### Q: 如何重啟服務？
```bash
systemctl --user restart hermes-gateway-developer.service
```

### Q: 如何更新到最新版本？
```bash
npm install -g hermes-agent@latest
```

### Q: 支持哪些平台？
- Discord（主要）
- Telegram
- Line
- 自定義 WebSocket

---

## License

MIT — 請參考 [Hermes Agent](https://github.com/freedomw1987/hermes-agent)
