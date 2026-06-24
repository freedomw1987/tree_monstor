# Cross-Platform Usage Guide

> **Status:** Reference. Cross-platform usage guide for Hermes, Claude Code, and Codex.

This document explains how the same Tree Monstor core identity works across different agent platforms.

---

## Platform Comparison

| Platform | Delegation Mechanism | Tool Access | Session Persistence | Multi-Agent |
|----------|---------------------|-------------|---------------------|--------------|
| **Hermes Agent** | `delegate_task()` via gateway | Full toolset via gateway | Built-in session management | ✅ Full subagent system |
| **Claude Code** | `--agent` spawning | Terminal, file, web, read | Per-session | ✅ Via `--agent` flag |
| **Codex** | Single-agent only | Codex tools | Per-session | ❌ Role-switching pattern |

---

## Core Identity (Shared Across All Platforms)

The following are **always the same** regardless of platform:

- **SOUL.md**: Core philosophy — "Developer is a dream partnership team"
- **Think/Plan/Build/Review/Test/Ship/Reflect workflow**
- **QA Gate** — Quality standards never waived
- **Red Lines** — Security, secrets, no-skip-QA
- **Subagent Role Matrix** — canonical role matrix lives in `docs/subagents.md`
- **Environment Isolation** — L1/L2/L3 architecture
- **Checkpoint Mechanism** — Long-task recovery

---

## Hermes Agent

### How It Works

Hermes uses the profile directory structure:
```
~/.hermes/profiles/developer/
├── SOUL.md
├── AGENTS.md
├── MEMORY.md
├── docs/
└── skills/
```

### Delegation

Use `delegate_task()`:
```
delegate_task(
    goal="市場分析",
    context="用戶需求: ...",
    role="CEO",
    toolsets=["terminal", "file", "web"]
)
```

### Startup

```bash
hermes --profile developer gateway run
```

### Configuration

See `adapters/hermes/`:
- `README.md` — Hermes adapter guide
- `.env.template` — Environment variables

Current Hermes versions use `config.yaml` under the profile directory for gateway/runtime settings; old `gateway.yaml` references are historical.

---

## Claude Code

### How It Works

Use the adapter file at `adapters/claude-code/agent.md`:

```bash
claude --agent-file adapters/claude-code/agent.md
```

### Delegation

Use `--agent` to spawn subagents:

```bash
claude --agent "researcher" "Research tech stack for real-time chat app"
```

### System Prompt Alternative

```bash
claude --system-prompt-file SOUL.md
```

### Multi-Agent Pattern

Claude Code supports multi-agent via `--agent` flag. In the agent definition, we specify:

```yaml
instructions: |
  # Tree Monstor instructions for Claude Code
  # Includes SOUL.md core + spawning patterns
```

Spawn subagents for complex tasks:
```
claude --agent "frontend" "Build React component for user dashboard"
claude --agent "backend" "Create user authentication API"
```

---

## Codex

### How It Works

Codex is single-agent only. Use `adapters/codex/system-prompt.md`:

```bash
codex --system-prompt "$(cat adapters/codex/system-prompt.md)" "task description"
```

### Role Switching Pattern

Since Codex can't spawn subagents, roles are applied internally:

**Before doing any task, pause and think:**
1. "What role am I acting as right now?"
2. "What would SA (Solutions Architect) say about this architecture?"
3. "What would Security Engineer check for?"
4. "What would QA test for?"

Example:
```
User: "Build a user login system"

Think (CEO): "Is this B2C or B2B? What's the business model?"
Think (Researcher): "What auth standards should we use? OAuth2? JWT?"
Think (SA): "What's the architecture? Microservices? Monolith?"
Think (Security): "Password hashing? Token storage? Attack vectors?"
Think (BA): "What are the requirements? MFA? Social login?"
Think (QA): "What test cases? Happy path? Edge cases?"
Then: Build
```

### System Prompt

The Codex adapter (`adapters/codex/system-prompt.md`) includes:
- Full core identity
- Role-switching methodology for single-agent
- Think/Plan interaction patterns adapted for single-agent
- QA Gate enforcement
- All red lines and principles

---

## Adapting Subagents for Single-Agent Platforms

### Hermes / Claude Code (Multi-Agent)

Subagents are separate processes/agents with their own context:

```
Orchestrator → spawns → CEO agent
                      → spawns → Researcher agent
                      → spawns → BA agent
```

### Codex (Single-Agent)

Subagent roles are applied as thinking patterns:

```
At any point, ask:
- "What would [ROLE] do in this situation?"
- "What would [ROLE] check/validate?"
- "What would [ROLE] output?"

Then apply that perspective before acting.
```

---

## Environment Variables

| Platform | Config Location | Key Variables |
|----------|----------------|---------------|
| Hermes | `~/.hermes/profiles/developer/.env` | `DISCORD_BOT_TOKEN`, `OPENROUTER_API_KEY` |
| Claude Code | Claude Code env management | Model, API keys via Claude Code config |
| Codex | Codex env management | Model, API keys via Codex config |

---

## Session Recovery (Checkpoint)

All platforms use the same checkpoint format:

```
# Checkpoint — [timestamp]

## Goal
[Original goal]

## Progress
[What was done]

## Current State
[What's being worked on]

## Blockers
[Any issues]

## Next Steps
[What comes next]
```

Recovery process is the same:
1. Read checkpoint
2. Restate goal
3. Review progress
4. Continue

---

## Platform-Specific Notes

### Hermes
- Full subagent delegation
- Gateway manages session state
- Discord/Telegram/etc. as messaging platforms

### Claude Code
- `--agent` for subagent spawning
- Tool access: terminal, file, web, read
- Session state per-invocation

### Codex
- Single agent only
- Role-switching for multi-perspective thinking
- System prompt contains all context
- Session state per-invocation

---

## Choosing a Platform

| Use Case | Recommended Platform |
|----------|---------------------|
| Discord/Telegram bot | Hermes Agent |
| CLI development assistant | Claude Code |
| Single-task coding | Codex |
| Complex multi-agent orchestration | Hermes Agent or Claude Code |
| Quick prototyping | Codex or Claude Code |

---

## Related docs

- [Documentation index](00-index.md)
- [README](../README.md)
- [Claude Code adapter](../adapters/claude-code/agent.md)
- [Codex adapter](../adapters/codex/system-prompt.md)
- [Hermes adapter guide](../adapters/hermes/README.md)
