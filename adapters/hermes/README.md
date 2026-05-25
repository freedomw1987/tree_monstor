# Hermes Adapter

This directory explains how to use Tree Monstor as a Hermes Agent profile.

## Usage

### Option 1: Clone as Hermes Profile

```bash
# Clone to Hermes profile directory
git clone git@github.com:freedomw1987/tree_monstor.git ~/.hermes/profiles/developer

# Configure environment
cat > ~/.hermes/profiles/developer/.env << 'EOF'
DISCORD_BOT_TOKEN=your_discord_bot_token
OPENROUTER_API_KEY=your_openrouter_key
MINIMAX_API_KEY=your_minimax_key
HERMES_MAX_ITERATIONS=1500
EOF

# Run Hermes Agent
hermes-agent --profile developer gateway run
```

### Option 2: Use as Standalone Profile

If your Hermes setup uses a different profile path, you can copy this entire repo to your profile directory:

```bash
cp -r /path/to/tree_monstor ~/.hermes/profiles/developer/
```

## Profile Structure

```
~/.hermes/profiles/developer/
├── SOUL.md              — Core identity, principles, workflow
├── AGENTS.md            — Session startup, interaction patterns
├── MEMORY.md            — Subagent matrix, model tiering, failure policy
├── README.md            — Project overview, quick start
├── docs/                — Detailed documentation
│   ├── 00-index.md      — Documentation index
│   ├── phases.md        — Think→Ship→Reflect workflow
│   ├── subagents.md     — 22 role definitions
│   ├── qa-gate.md       — Quality assurance checklist
│   ├── failure-policy.md — Error handling
│   ├── checkpoint.md    — Long-task recovery
│   ├── task-board.md    — Project tracking
│   ├── environment-isolation.md — Dev/Prod separation
│   └── ...
├── skills/              — 56 specialized skills
│   ├── frontend/
│   ├── backend/
│   ├── devops/
│   ├── creative/
│   └── ...
└── adapters/            — Cross-platform adapters (for reference)
    ├── claude-code/
    ├── codex/
    └── hermes/
```

## Hermes-Specific Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DISCORD_BOT_TOKEN` | Yes | Discord bot token for Hermes gateway |
| `OPENROUTER_API_KEY` | Yes | OpenRouter API key for model routing |
| `MINIMAX_API_KEY` | No | MiniMax API key (optional) |
| `HERMES_MAX_ITERATIONS` | No | Max iterations (default: 1000) |

### Gateway Configuration

Create `~/.hermes/profiles/developer/gateway.yaml`:

```yaml
gateway:
  host: 0.0.0.0
  port: 3000
  websocket: true
  auth:
    type: discord
    bot_token: ${DISCORD_BOT_TOKEN}
```

## Platform-Agnostic Core

The core files (SOUL.md, AGENTS.md, MEMORY.md, docs/, skills/) are platform-agnostic and shared across all adapters (Hermes, Claude Code, Codex).

Hermes-specific configuration is limited to:
- `.env` file (API keys, tokens)
- `gateway.yaml` (gateway connection settings)
- This README (setup instructions)

## /goal Directive — 任務專注模式

When user sends `/goal <task>`, the agent should:

1. **Parse the goal** — Extract the core objective
2. **Display Goal Affirmation Box**:
   ```
   ╔══════════════════════════════════════════╗
   ║  🎯 GOAL                                 ║
   ╠══════════════════════════════════════════╣
   ║  任務: [parsed goal text]                ║
   ║  階段: [Think/Plan/Build/...]             ║
   ║  專注: 拒絕偏離，拒絕額外需求             ║
   ╚══════════════════════════════════════════╝
   ```
3. **Create task board** — `docs/taskboard.md`
4. **Execute** — Follow workflow
5. **Stay focused** — Reject scope creep

## Starting a Session

```bash
hermes-agent --profile developer
```

The agent will:
1. Read SOUL.md — understand Developer identity
2. Read MEMORY.md — load long-term memory and subagent matrix
3. Read docs/00-index.md — understand documentation structure
4. Ask for the Goal — "🎯 Goal: What would you like to build?"
5. Follow Think → Plan → Build → Review → Test → Ship → Reflect workflow

## Background Service (systemd)

Create `~/.config/systemd/user/hermes-gateway-developer.service`:

```ini
[Unit]
Description=Hermes Developer Gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hermes-agent --profile developer gateway run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

Enable with:
```bash
systemctl --user enable hermes-gateway-developer.service
systemctl --user start hermes-gateway-developer.service
```