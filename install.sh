#!/usr/bin/env bash
# install.sh — Install Tree Monstor agents + skills into ~/.claude/
#
# Usage:
#   ./install.sh                    # symlink agents + skills
#   ./install.sh --uninstall        # remove symlinks
#   ./install.sh --global-bridge    # also setup ~/.claude/CLAUDE.md bridge
#   PROFILE_DIR=~/custom/path ./install.sh
#
# Idempotent: safe to re-run. Existing files are not overwritten
# unless --force is passed.

set -euo pipefail

# Default profile repo location (override with PROFILE_DIR env var)
PROFILE_DIR="${PROFILE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
log_err()  { printf "${RED}✗${NC} %s\n" "$*" >&2; }

# Verify profile repo exists
if [ ! -d "$PROFILE_DIR/.claude/agents" ] || [ ! -d "$PROFILE_DIR/skills" ]; then
    log_err "Profile repo not found at $PROFILE_DIR"
    log_err "Expected: \$PROFILE_DIR/.claude/agents and \$PROFILE_DIR/skills to exist"
    exit 1
fi

# Verify Claude Code home exists
mkdir -p "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills"

# Parse flags
UNINSTALL=0
GLOBAL_BRIDGE=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --uninstall)     UNINSTALL=1 ;;
        --global-bridge) GLOBAL_BRIDGE=1 ;;
        --force)         FORCE=1 ;;
        --help|-h)
            echo "Usage: $0 [--uninstall] [--global-bridge] [--force]"
            echo ""
            echo "Environment:"
            echo "  PROFILE_DIR  Profile repo location (default: script dir)"
            echo "  CLAUDE_HOME  Claude Code home (default: ~/.claude)"
            exit 0
            ;;
        *) log_err "Unknown flag: $arg"; exit 1 ;;
    esac
done

# Symlink helper
symlink() {
    local src="$1"
    local dst="$2"
    local name
    name=$(basename "$src")

    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then
            log_ok "already linked: $name"
            return 0
        fi
        if [ "$FORCE" -eq 1 ]; then
            rm "$dst"
        else
            log_warn "exists (different target): $name — use --force to replace"
            return 1
        fi
    elif [ -e "$dst" ]; then
        log_warn "exists (not a symlink): $name — use --force to replace"
        return 1
    fi

    ln -s "$src" "$dst"
    log_ok "linked: $name"
}

# Uninstall helper
unlink() {
    local path="$1"
    local name
    name=$(basename "$path")

    if [ -L "$path" ]; then
        rm "$path"
        log_ok "removed: $name"
    elif [ -e "$path" ]; then
        log_warn "exists (not a symlink, skipping): $name"
    fi
}

# ---- Subcommand: uninstall ----
if [ "$UNINSTALL" -eq 1 ]; then
    echo "Uninstalling Tree Monstor from $CLAUDE_HOME..."

    # Remove agent symlinks
    if [ -d "$PROFILE_DIR/.claude/agents" ]; then
        for agent in "$PROFILE_DIR/.claude/agents/"*.md; do
            [ -e "$agent" ] || continue
            unlink "$CLAUDE_HOME/agents/$(basename "$agent")"
        done
    fi

    # Remove skill symlinks
    if [ -d "$PROFILE_DIR/skills" ]; then
        for skill_dir in "$PROFILE_DIR/skills/"*/; do
            [ -d "$skill_dir" ] || continue
            unlink "$CLAUDE_HOME/skills/$(basename "$skill_dir")"
        done
    fi

    # Remove global bridge (if installed by us)
    if [ -L "$CLAUDE_HOME/CLAUDE.md" ]; then
        target=$(readlink "$CLAUDE_HOME/CLAUDE.md" 2>/dev/null || true)
        if [ "$target" = "$PROFILE_DIR/CLAUDE.md" ]; then
            rm "$CLAUDE_HOME/CLAUDE.md"
            log_ok "removed: CLAUDE.md bridge"
        fi
    fi

    echo "Done."
    exit 0
fi

# ---- Default: install ----
echo "Installing Tree Monstor from $PROFILE_DIR..."
echo "  → Claude Code home: $CLAUDE_HOME"
echo ""

# Symlink agents
echo "[1/3] Agents (.claude/agents/ → ~/.claude/agents/)"
for agent in "$PROFILE_DIR/.claude/agents/"*.md; do
    [ -e "$agent" ] || continue
    symlink "$agent" "$CLAUDE_HOME/agents/$(basename "$agent")"
done

# Symlink skills
echo ""
echo "[2/3] Skills (skills/ → ~/.claude/skills/)"
for skill_dir in "$PROFILE_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    symlink "$skill_dir" "$CLAUDE_HOME/skills/$(basename "$skill_dir")"
done

# Optional global bridge
if [ "$GLOBAL_BRIDGE" -eq 1 ]; then
    echo ""
    echo "[3/3] Global bridge (~/.claude/CLAUDE.md → profile/CLAUDE.md)"
    symlink "$PROFILE_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
    GLOBAL_BRIDGE_INSTALLED=1
else
    echo ""
    echo "[3/3] Global bridge (skipped — pass --global-bridge to install)"
    GLOBAL_BRIDGE_INSTALLED=0
fi

# Count installed items
AGENT_COUNT=$(find "$PROFILE_DIR/.claude/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
SKILL_COUNT=$(find "$PROFILE_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "=== Summary ==="
echo "  → $AGENT_COUNT agents linked:    $CLAUDE_HOME/agents/"
echo "  → $SKILL_COUNT skills linked:    $CLAUDE_HOME/skills/"
if [ "$GLOBAL_BRIDGE_INSTALLED" -eq 1 ]; then
    echo "  → Global bridge:           $CLAUDE_HOME/CLAUDE.md → profile/CLAUDE.md"
else
    echo "  → Global bridge:           (skipped)"
fi
echo ""
echo "Verify: ls -la $CLAUDE_HOME/agents/ | head"
echo "Or test: claude --agent orchestrator"
echo "Or test: claude (then type '/orchestrator' or '/dev-loop' to trigger a skill)"