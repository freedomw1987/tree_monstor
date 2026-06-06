#!/usr/bin/env bash
# resume.sh — One-command resume of an interrupted dev task.
#
# Usage:
#   bash resume.sh <project_name> [options]
#   bash resume.sh crm-system
#   bash resume.sh crm-system --list
#   bash resume.sh crm-system --peek
#
# Options:
#   --list     List available past sessions for this project
#   --peek     Show state without starting a new session (dry-run)
#
# What it does:
#   1. Find dev-task-state.md (auto-saved by recovery.sh or save_state.py)
#   2. Find past sessions mentioning this project (via FTS5 search)
#   3. Show David a quick summary: "What was I doing? Where? What's next?"
#   4. Emit the exact resume command for him to run
#
# This is the user-facing entry point. No need to know session IDs or
# internal mechanics — just project name.

set -e

PROFILE="developer"
PROJECT="${1:-}"
MODE="summary"

if [ -z "$PROJECT" ]; then
    echo "Usage: bash resume.sh <project_name> [--list|--peek]"
    echo ""
    echo "Examples:"
    echo "  bash resume.sh crm-system              # Show summary + resume cmd"
    echo "  bash resume.sh crm-system --list       # List past sessions"
    echo "  bash resume.sh crm-system --peek       # Show state only, no action"
    exit 1
fi

# Parse flags
shift
while [ $# -gt 0 ]; do
    case $1 in
        --list) MODE="list" ;;
        --peek) MODE="peek" ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
    shift
done

SKILL_DIR="$HOME/.hermes/profiles/$PROFILE/skills/dev-task-memory"
SESSIONS_JSON="$HOME/.hermes/profiles/$PROFILE/sessions/sessions.json"
DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 RESUME — Project: $PROJECT"
echo "═══════════════════════════════════════════════════════════════"

# Step 1: Load dev-task-state.md
echo ""
echo "📂 Step 1: Loading dev-task-state.md..."
STATE_PATH="$HOME/www/$PROJECT/docs/_meta/dev-task-state.md"
if [ ! -f "$STATE_PATH" ]; then
    # Try alternate locations
    for alt in "$HOME/www/$PROJECT/dev-task-state.md" "$PWD/docs/_meta/dev-task-state.md" "$PWD/dev-task-state.md"; do
        if [ -f "$alt" ]; then
            STATE_PATH="$alt"
            break
        fi
    done
fi

if [ -f "$STATE_PATH" ]; then
    echo "  ✅ Found: $STATE_PATH"
    echo "     Last modified: $(stat -f "%Sm" "$STATE_PATH" 2>/dev/null || stat -c "%y" "$STATE_PATH" 2>/dev/null)"

    if [ "$MODE" != "peek" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "📋 STATE SUMMARY"
        echo "═══════════════════════════════════════════════════════════════"
        # Show key sections only
        awk '
            /^## 🎯 Goal/ { in_goal=1 }
            /^## 📋 Decisions/ { in_dec=1; print ""; print "─── " $0 " ───"; next }
            /^## 🏗️ Current State/ { in_state=1; print ""; print "─── " $0 " ───"; next }
            /^## ⏭️ Next 3-5 Steps/ { in_next=1; print ""; print "─── " $0 " ───"; next }
            /^## 🚨 Risks/ { in_risk=1; print ""; print "─── " $0 " ───"; next }
            /^## 🧠 Key Insights/ { in_insight=1; print ""; print "─── " $0 " ───"; next }
            /^## 🔗 Session Lineage/ { in_lineage=1; print ""; print "─── " $0 " ───"; next }
            in_goal { print }
            in_dec && /^[0-9]\./ { print; next }
            in_state && /^\|/ && !/^---/ { print; next }
            in_next && /^[0-9]\./ { print; next }
            in_risk && /^-\s+\*\*/ { print; next }
            in_insight && /^-\s+\*\*/ { print; next }
            in_lineage && /^\*\*/ { print; next }
            /^## / { in_goal=0; in_dec=0; in_state=0; in_next=0; in_risk=0; in_insight=0; in_lineage=0 }
        ' "$STATE_PATH" | head -60
    fi
else
    echo "  ⚠️  No dev-task-state.md found"
    echo "     Searched:"
    echo "     - $HOME/www/$PROJECT/docs/_meta/dev-task-state.md"
    echo "     - $HOME/www/$PROJECT/dev-task-state.md"
    echo "     - ./docs/_meta/dev-task-state.md"
    echo "     - ./dev-task-state.md"
    echo ""
    echo "  💡 To create: bash recovery.sh $PROJECT 'first save'"
fi

# Step 2: Find past sessions
echo ""
echo "🔎 Step 2: Past sessions for $PROJECT..."
PAST_SESSIONS=$(sqlite3 "$DB_PATH" "
SELECT id, datetime(started_at,'unixepoch'), message_count, title
FROM sessions
WHERE source='discord' AND id IN (
    SELECT DISTINCT session_id FROM messages
    WHERE content LIKE '%$PROJECT%'
       OR content LIKE '%' || replace('$PROJECT', '-', '%') || '%'
)
ORDER BY started_at DESC LIMIT 5;
" 2>/dev/null)

if [ -n "$PAST_SESSIONS" ]; then
    echo "  ✅ Found $(echo "$PAST_SESSIONS" | wc -l | tr -d ' ') session(s):"
    echo "$PAST_SESSIONS" | head -5 | while IFS='|' read -r sid ts msgcount title; do
        echo "     • $sid  ($ts, $msgcount msgs)  ${title:-(no title)}"
    done
else
    echo "  ⚠️  No past sessions found mentioning '$PROJECT'"
fi

# Step 3: Resume command
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 TO RESUME — pick one:"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Find the most recent session_id
LATEST_SID=$(sqlite3 "$DB_PATH" "
SELECT id FROM sessions
WHERE source='discord'
ORDER BY started_at DESC LIMIT 1;
" 2>/dev/null)

if [ -n "$LATEST_SID" ]; then
    echo "  # A. Resume most recent session EXACTLY (preserves full context):"
    echo "  hermes --profile $PROFILE --resume $LATEST_SID"
    echo ""
    echo "  # B. Resume by project name (Hermes auto-picks matching session):"
    echo "  hermes --profile $PROFILE --continue \"$PROJECT\""
    echo ""
fi
echo "  # C. Start a FRESH session + auto-load dev-task-state.md as system context:"
echo "  #    (cleanest for long interruptions; agent reads the state file on first turn)"
echo "  hermes --profile $PROFILE --skills dev-task-memory -c \"$PROJECT\""
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "💡 TIP: If you've been away for > 1 day, use option C (fresh session)."
echo "   The state file is the single source of truth — your decisions,"
echo "   current state, and next steps are all persisted."
echo "═══════════════════════════════════════════════════════════════"
