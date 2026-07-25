#!/usr/bin/env bash
# terminal_preflight.sh — Wrapper to detect & reject long-lived commands before
# they hit Hermes's hard 300s timeout.
#
# Usage in agent code:
#   bash <profile-root>/skills/interruption-recovery/scripts/terminal_preflight.sh <command>
#   bash <profile-root>/skills/interruption-recovery/scripts/terminal_preflight.sh --wrap <command>
#
# What it does:
#   1. Detect long-lived patterns (npm run dev, docker compose up, server start, etc.)
#   2. If detected, emit clear error pointing to `background=true` pattern
#   3. Otherwise, exec the command normally
#
# Heuristics for long-lived:
#   - `npm run dev` / `npm start` / `yarn dev` / `pnpm dev`
#   - `docker compose up` (without --detach)
#   - `python -m http.server` / `flask run` / `uvicorn` (without --reload + timeout)
#   - `node server.js` (anywhere `node` invoked as server)
#   - `vite` (vite dev server)
#   - `watch` commands (fswatch, inotifywait)
#   - any `&` at the end
#   - `tail -f` / `ping -t`

set -e

WRAP_MODE=0
COMMAND=""

for arg in "$@"; do
    case $arg in
        --wrap) WRAP_MODE=1 ;;
        *) COMMAND="$COMMAND $arg" ;;
    esac
done

COMMAND="${COMMAND# }"  # trim leading space

# Heuristics
is_long_lived() {
    local cmd="$1"
    
    # explicit background markers (carefully avoid matching && chains)
    # Match: trailing ' &', ' & ', ' &;' but NOT '&&' (logical AND)
    if [[ "$cmd" =~ (^|[^&])(\&[[:space:]]|\&$) ]]; then
        return 0
    fi
    
    # common dev server patterns
    [[ "$cmd" == *"npm run dev"* ]] && return 0
    [[ "$cmd" == *"npm start"* ]] && return 0
    [[ "$cmd" == *"yarn dev"* ]] && return 0
    [[ "$cmd" == *"yarn start"* ]] && return 0
    [[ "$cmd" == *"pnpm dev"* ]] && return 0
    [[ "$cmd" == *"pnpm start"* ]] && return 0
    [[ "$cmd" == *"bun run dev"* ]] && return 0
    [[ "$cmd" == *"bun --hot"* ]] && return 0
    
    # docker compose without --detach
    [[ "$cmd" == *"docker compose up"* ]] && [[ "$cmd" != *"--detach"* ]] && [[ "$cmd" != *"-d"* ]] && return 0
    [[ "$cmd" == *"docker-compose up"* ]] && [[ "$cmd" != *"--detach"* ]] && [[ "$cmd" != *"-d"* ]] && return 0
    
    # python servers
    [[ "$cmd" == *"python -m http.server"* ]] && return 0
    [[ "$cmd" == *"python3 -m http.server"* ]] && return 0
    [[ "$cmd" == *"flask run"* ]] && return 0
    [[ "$cmd" == *"uvicorn "* ]] && return 0
    [[ "$cmd" == *"gunicorn "* ]] && return 0
    
    # node servers (heuristic: .js/.ts with port)
    [[ "$cmd" == *"node "*".js"* ]] && return 0
    [[ "$cmd" == *"node "*".ts"* ]] && return 0
    
    # vite, webpack-dev-server
    [[ "$cmd" == *"vite"* ]] && [[ "$cmd" != *"vite build"* ]] && [[ "$cmd" != *"vite preview"* ]] && return 0
    [[ "$cmd" == *"webpack-dev-server"* ]] && return 0
    
    # watch tools
    [[ "$cmd" == *"fswatch"* ]] && return 0
    [[ "$cmd" == *"inotifywait"* ]] && return 0
    [[ "$cmd" == *"watch "* ]] && return 0
    [[ "$cmd" == *" --watch"* ]] && return 0
    [[ "$cmd" == *"-w "* ]] && return 0
    
    # tail -f
    [[ "$cmd" == *"tail -f"* ]] && return 0
    [[ "$cmd" == *"tail -F"* ]] && return 0
    
    # ping -t
    [[ "$cmd" == *"ping -t"* ]] && return 0
    
    # nohup/disown
    [[ "$cmd" == *"nohup"* ]] && return 0
    [[ "$cmd" == *"disown"* ]] && return 0
    
    # tmux/screen sessions
    [[ "$cmd" == *"tmux new-session"* ]] && return 0
    [[ "$cmd" == *"screen -S"* ]] && return 0
    
    return 1
}

if is_long_lived "$COMMAND"; then
    echo "❌ LONG-LIVED COMMAND DETECTED" >&2
    echo "   Command: $COMMAND" >&2
    echo "" >&2
    echo "💡 Hermes terminal tool REJECTS long-lived foreground commands (300s timeout)." >&2
    echo "" >&2
    echo "   ✅ CORRECT — use background=true with health check:" >&2
    echo "      1. terminal(background=true, notify_on_complete=true)  # starts process" >&2
    echo "      2. process(action='poll') or wait  # verify readiness" >&2
    echo "      3. Run your test/query commands" >&2
    echo "      4. process(action='kill') when done" >&2
    echo "" >&2
    echo "   📋 Common patterns:" >&2
    echo "      • npm run dev        → background=true, then curl localhost:3000" >&2
    echo "      • docker compose up  → add --detach or use background=true" >&2
    echo "      • python -m http.server → background=true" >&2
    echo "" >&2
    exit 78  # EX_CONFIG - configuration error
fi

# Not long-lived — exec as normal
if [ "$WRAP_MODE" = "1" ]; then
    exec bash -c "$COMMAND"
else
    # Just report and exit 0 (so caller knows it's safe)
    echo "✅ Safe to run as foreground: $COMMAND"
    exit 0
fi
