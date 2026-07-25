# Cross-Platform Usage Guide

> **Status:** Reference. Cross-platform usage guide for Claude Code and Codex.

This document explains how the same Tree Monstor core identity works across different agent platforms.

---

## Platform Comparison

| Platform | Delegation Mechanism | Tool Access | Session Persistence | Multi-Agent |
|----------|---------------------|-------------|---------------------|--------------|
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

---

## Claude Code

### How It Works

Recommended usage: open the repository normally and let Claude Code read root `CLAUDE.md`.

```bash
cd ~/Sites/localhost/tree_monstor  # or your tree_monstor clone path
claude
```

`CLAUDE.md` bridges Claude Code to:

- `SOUL.md`
- `AGENTS.md`
- `MEMORY.md`
- `docs/00-index.md`
- `skills/README.md`
- `adapters/claude-code/agent.md`

### Delegation

Use the Claude Code-native subagent / workflow mechanism available in the current installation (subagent tools, slash skills, or workflow support).

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

Since Codex can't spawn subagents, roles are applied internally as thinking patterns:

```
At any point, ask:
- "What would [ROLE] do in this situation?"
- "What would [ROLE] check/validate?"
- "What would [ROLE] output?"

Then apply that perspective before acting.
```

The Codex adapter (`adapters/codex/system-prompt.md`) includes the full core identity, the role-switching methodology, Think/Plan interaction patterns adapted for single-agent, QA Gate enforcement, and all red lines.

---

## Choosing a Platform

| Use Case | Recommended Platform |
|----------|---------------------|
| CLI development assistant | Claude Code |
| Single-task coding | Codex |
| Complex multi-agent orchestration | Claude Code when native subagents/workflows are available |
| Quick prototyping | Codex or Claude Code |

---

## Related docs

- [Documentation index](00-index.md)
- [README](../README.md)
- [Claude Code bridge](../CLAUDE.md)
- [Claude Code adapter](../adapters/claude-code/agent.md)
- [Codex adapter](../adapters/codex/system-prompt.md)
