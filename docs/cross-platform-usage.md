# Cross-Platform Usage Guide

> **Status:** Reference. Cross-platform usage guide for Hermes, Claude Code, and Codex.

This document explains how the same Tree Monstor core identity works across different agent platforms.

---

## Platform Comparison

| Platform | Delegation Mechanism | Tool Access | Session Persistence | Multi-Agent |
|----------|---------------------|-------------|---------------------|--------------|
| **Hermes Agent** | `delegate_task()` via gateway | Full toolset via gateway | Built-in session management | ✅ Full subagent system |
| **Claude Code** | root `CLAUDE.md`, optional adapter file, Claude Code-native subagents/workflows when available | Claude Code tools | Per-session / repo-local context | ✅ Via Claude Code-native mechanisms when available |
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

Recommended usage: open the repository normally and let Claude Code read root `CLAUDE.md`.

```bash
cd ~/.hermes/profiles/developer  # or your tree_monstor clone path
claude
```

`CLAUDE.md` bridges Claude Code to:

- `SOUL.md`
- `AGENTS.md`
- `MEMORY.md`
- `docs/00-index.md`
- `skills/README.md`
- `adapters/claude-code/agent.md`

### Explicit Adapter Mode

If your Claude Code installation supports explicit adapter files, you can still use:

```bash
claude --agent-file adapters/claude-code/agent.md
```

### System Prompt Alternative

Fallback mode with fewer Claude Code-specific routing instructions:

```bash
claude --system-prompt-file SOUL.md
```

### Delegation

Use the Claude Code-native subagent / workflow mechanism available in the current installation. In some CLI environments this may look like `--agent`; in harness environments it may be exposed as subagent tools, slash skills, or workflow support.

Examples are conceptual; verify the mechanism supported by your Claude Code runtime:

```bash
# Example only, if supported by your Claude Code install
claude --agent "researcher" "Research tech stack for real-time chat app"
```

### Multi-Agent Pattern

When Claude Code supports subagents/workflows, map Tree Monstor roles from `docs/subagents.md` onto the runtime mechanism. If not available, use the Codex-style role-switching pattern inside a single agent.

Local Tree Monstor skills under `skills/<name>/SKILL.md` are markdown instructions unless separately registered as Claude Code runtime skills. Use `skills/README.md` to route to the right local skill.

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

### Hermes / Claude Code (Multi-Agent when supported)

Subagents are separate processes/agents/tools with their own context:

```
Orchestrator → spawns → CEO agent
                      → spawns → Researcher agent
                      → spawns → BA agent
```

Claude Code support depends on the active runtime. Use native subagent/workflow mechanisms when available; otherwise use role-switching.

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
- Root `CLAUDE.md` is the preferred integration point
- Explicit `adapters/claude-code/agent.md` remains available for adapter-file usage
- Local Tree Monstor skills are markdown instructions unless installed as Claude Code runtime skills
- Dynamic Workflow / subagents are availability-dependent; use them when supported and appropriate
- Session state is per session / repo-local context

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
| Complex multi-agent orchestration | Hermes Agent or Claude Code when native subagents/workflows are available |
| Quick prototyping | Codex or Claude Code |

---

## Related docs

- [Documentation index](00-index.md)
- [README](../README.md)
- [Claude Code bridge](../CLAUDE.md)
- [Claude Code adapter](../adapters/claude-code/agent.md)
- [Codex adapter](../adapters/codex/system-prompt.md)
- [Hermes adapter guide](../adapters/hermes/README.md)
