# Developer Profile — 安裝指南

> 如何在 **Hermes Agent**、**Claude Code**、**Codex**、**OpenClaw** 中使用這個 Developer Profile

---

## 目錄

1. [Hermes Agent](#1-hermes-agent)
2. [Claude Code](#2-claude-code)
3. [Codex](#3-codex)
4. [OpenClaw](#4-openclaw)
5. [快速對比](#快速對比)

---

## 1. Hermes Agent

Hermes Agent 是這個 Profile 的原生運行時。

### 安裝

```bash
# npm 全域安裝
npm install -g hermes-agent

# 驗證
hermes-agent --version
```

### 創建 Developer Profile

```bash
# 創建新 profile
hermes profile create developer

# 或克隆現有的（推薦）
git clone git@github.com:freedomw1987/tree_monstor.git ~/.hermes/profiles/developer
```

### 配置

```bash
# 編輯環境變量
cat > ~/.hermes/profiles/developer/.env << 'EOF'
DISCORD_BOT_TOKEN=your_discord_bot_token
OPENROUTER_API_KEY=your_openrouter_key
MINIMAX_API_KEY=your_minimax_key
HERMES_MAX_ITERATIONS=1500
EOF
```

### 啟動

```bash
# 直接運行
hermes-agent --profile developer gateway run

# 或使用 systemd（後台運行）
systemctl --user enable hermes-gateway-developer.service
systemctl --user start hermes-gateway-developer.service

# 查看日誌
journalctl --user -u hermes-gateway-developer.service -f
```

---

## 2. Claude Code

### 安裝

```bash
# macOS / Linux
curl -1sLf 'https://storage.googleapis.com/claude-code/claude-code-installer.sh' | bash

# npm
npm install -g @anthropic-ai/claude-code

# 驗證
claude --version
```

### 使用 Developer Profile（--agent 方式）

```bash
# 方式一：直接指定 system prompt 文件
claude --system-prompt-file ~/.hermes/profiles/developer/SOUL.md

# 方式二：使用 --agent 參數（自定義 agent）
claude --agent 'developer' --agents '{
  "developer": {
    "description": "AI 軟件開發團隊，執行 Think→Plan→Build→Review→Test→Ship→Reflect 流程",
    "system-prompt": "你是一個專業的軟件開發團隊。參考 ~/.hermes/profiles/developer/SOUL.md 中的身份定位和原則工作。"
  }
}'
```

### 長期使用（寫入 settings）

```bash
# 創建 claude-settings.json
cat > ~/.claude/settings-dev.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.minimax.io/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "your_token_here",
    "ANTHROPIC_MODEL": "MiniMax-M2.7"
  },
  "agents": {
    "developer": {
      "description": "AI 軟件開發團隊",
      "system-prompt": "你是一個專業的軟件開發團隊..."
    }
  }
}
EOF

# 使用該配置
claude --settings ~/.claude/settings-dev.json
```

### 在專案中使用

```bash
# 在專案目錄下創建 CLAUDE.md
cat > /path/to/your/project/CLAUDE.md << 'EOF'
# 開發助手配置

你是一個專業的軟件開發團隊，參考 ~/.hermes/profiles/developer/SOUL.md 工作。

## 流程
- Think → Plan → Build → Review → Test → Ship → Reflect
EOF

cd /path/to/your/project
claude
```

---

## 3. Codex

### 安裝

```bash
# pip 安裝
pip install openai-codex

# 或使用 brew (macOS)
brew install openai-codex

# 驗證
codex --version
```

### 配置 API Key

```bash
export OPENAI_API_KEY=your_api_key
```

### 使用 Developer Profile

```bash
# 方式一：命令行指定 system prompt
codex --system-prompt "你是一個專業的軟件開發團隊。參考 ~/.hermes/profiles/developer/SOUL.md 中的身份定位和原則工作。" "幫我創建一個用戶登入系統"

# 方式二：創建專案配置
cat > ~/.codex/projects/developer.json << 'EOF'
{
  "name": "developer",
  "system_prompt": "你是一個專業的軟件開發團隊...",
  "model": "gpt-5.5"
}
EOF

codex --project developer "我想做一個電商網站"
```

### 在專案目錄使用

```bash
# 在專案根目錄創建 .codex.json
cat > /path/to/project/.codex.json << 'EOF'
{
  "system_prompt": "你是一個專業的軟件開發團隊，參考 ~/.hermes/profiles/developer/SOUL.md 工作。"
}
EOF

cd /path/to/project
codex "幫我創建 REST API"
```

---

## 4. OpenClaw

### 安裝

```bash
# npm 全域安裝
npm install -g openclaw

# 驗證
openclaw --version
```

### 首次配置

```bash
# 互動式引導配置
openclaw configure

# 或手動配置
openclaw config set channels.discord.token --ref-provider default --ref-source env --ref-id DISCORD_BOT_TOKEN
```

### 添加 Developer Agent

```bash
# 添加新 agent
openclaw agents add developer \
  --system-prompt-file ~/.hermes/profiles/developer/SOUL.md \
  --description "AI 軟件開發團隊"

# 列出所有 agents
openclaw agents list

# 綁定到 Discord 頻道
openclaw agents bind developer --channel discord:#developer
```

### 使用 Developer Profile 啟動

```bash
# 方式一：使用 profile 名（隔離狀態）
openclaw --profile developer gateway run

# 方式二：在 OpenClaw 配置中引用
openclaw config set agents.developer.system-prompt-file ~/.hermes/profiles/developer/SOUL.md

# 啟動 gateway 並使用 developer agent
openclaw agent --agent developer "幫我規劃一個課程管理系統"
```

### 後台運行

```bash
# 啟動為 daemon
openclaw daemon start --profile developer

# 查看狀態
openclaw daemon status

# 查看日誌
openclaw daemon logs --profile developer
```

---

## 快速對比

| 工具 | 配置文件方式 | 啟動命令 | 難度 |
|------|-------------|---------|------|
| **Hermes Agent** | `~/.hermes/profiles/developer/` | `hermes-agent --profile developer` | ⭐ 最適合 |
| **Claude Code** | `--agent` / `settings.json` | `claude --system-prompt-file SOUL.md` | ⭐⭐ |
| **Codex** | `.codex.json` | `codex --project developer` | ⭐⭐ |
| **OpenClaw** | `openclaw agents add` | `openclaw --profile developer` | ⭐⭐ |

---

## 共用文件

所有工具都可以引用這些核心文件：

```
~/.hermes/profiles/developer/
├── SOUL.md              # 身份定位、核心原則
├── AGENTS.md            # Session 啟動流程
├── MEMORY.md            # 長期記憶
├── docs/
│   ├── phases.md        # Think→Ship 詳細流程
│   ├── subagents.md     # 18 個 Subagent 角色
│   └── qa-gate.md       # QA Gate 交付清單
└── skills/              # 可復用技能庫
```

---

## 常見問題

### Q: 如何更新 Profile？
```bash
cd ~/.hermes/profiles/developer
git pull origin master
```

### Q: 如何查看運行狀態？
```bash
# Hermes
systemctl --user status hermes-gateway-developer.service

# OpenClaw
openclaw agents list
```

### Q: 可以同時運行多個嗎？
可以，但建議不同工具使用不同端口或 Profile 名稱避免衝突。

---

## License

MIT — [Hermes Agent GitHub](https://github.com/freedomw1987/hermes-agent)
