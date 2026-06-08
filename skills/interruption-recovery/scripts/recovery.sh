#!/usr/bin/env bash
# recovery.sh — Auto-save dev task state on any interruption, then show resume command.
#
# Usage:
#   bash recovery.sh <project_name> [reason]
#   bash recovery.sh crm-system "gateway restart"
#   bash recovery.sh crm-system "/new slash command"
#   bash recovery.sh crm-system "context window overflow"
#
# What it does:
#   1. Snapshot the active Hermes session_id + Discord thread info
#   2. Save state via dev-task-memory/save_state.py
#   3. Sync to external memory via dev-task-memory/sync_external.py
#   4. Print exact resume command (hermes --resume <id>) or `hermes -c "name"`
#   5. Also write a "interruption_log.md" for the project
#
# Run BEFORE the interruption if possible. If you can't (e.g. gateway crash),
# run on next manual invocation — state is reconstructed from last save_state call.

set -e

PROFILE="developer"
PROJECT="${1:-}"
REASON="${2:-manual}"

if [ -z "$PROJECT" ]; then
    echo "Usage: bash recovery.sh <project_name> [reason]"
    echo "Example: bash recovery.sh crm-system 'gateway restart'"
    exit 1
fi

SKILL_DIR="$HOME/.hermes/profiles/$PROFILE/skills/dev-task-memory"
RECOVERY_SKILL_DIR="$HOME/.hermes/profiles/$PROFILE/skills/interruption-recovery"
SESSIONS_JSON="$HOME/.hermes/profiles/$PROFILE/sessions/sessions.json"
DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"

if [ ! -d "$SKILL_DIR" ]; then
    echo "❌ dev-task-memory skill not found: $SKILL_DIR"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "🔄 INTERRUPTION RECOVERY — Project: $PROJECT"
echo "   Reason: $REASON"
echo "   Time:   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "═══════════════════════════════════════════════════════════════"

# Step 1: Find active session for this project
echo ""
echo "📡 Step 1: Finding active session..."

# Try to find a session whose dev-task-state.md mentions this project
# (saved earlier), or use the most recent active discord session as fallback.
ACTIVE_SID=$(sqlite3 "$DB_PATH" "
SELECT id FROM sessions
WHERE source='discord' AND ended_at IS NULL
ORDER BY started_at DESC LIMIT 1;
" 2>/dev/null)

if [ -z "$ACTIVE_SID" ]; then
    # Fall back to most recent session (even if ended)
    ACTIVE_SID=$(sqlite3 "$DB_PATH" "
SELECT id FROM sessions
WHERE source='discord'
ORDER BY started_at DESC LIMIT 1;
" 2>/dev/null)
fi

if [ -z "$ACTIVE_SID" ]; then
    echo "  ⚠️  No active session found. State will be saved without session_id."
    ACTIVE_SID="(no-session)"
else
    # Look up display_name
    DISPLAY_NAME=$(python3 -c "
import json
with open('$SESSIONS_JSON') as f:
    data = json.load(f)
for key, entry in data.items():
    if entry.get('session_id') == '$ACTIVE_SID':
        print(entry.get('display_name', ''))
        break
" 2>/dev/null)
    echo "  ✅ Active session: $ACTIVE_SID"
    echo "     Display: ${DISPLAY_NAME:-(none)}"
fi

# Step 2: Save state via dev-task-memory skill
echo ""
echo "💾 Step 2: Saving dev task state..."

if ! python3 "$SKILL_DIR/scripts/save_state.py" \
    --project "$PROJECT" \
    --goal "(recovery from: $REASON)" \
    --trigger "interruption-recovery-$REASON" 2>&1; then
    echo "  ⚠️  save_state.py failed, continuing anyway"
fi

# Day 11 (2026-06-09) lesson: the state file just written is likely a
# GENERIC template (Decisions / Files / Next Steps are placeholders).
# save_state.py's `detect_decisions_from_session` is a stub and most
# template `replace()` calls don't fire. The agent that resumes in a
# new session MUST hand-overwrite dev-task-state.md with real state
# before continuing. See: dev-task-memory/references/recovery-template-limitation.md
echo ""
echo "⚠️  Day 11 lesson: the state file just written is likely a GENERIC"
echo "    template (Decisions / Files / Next Steps are placeholders)."
echo "    Before resuming in a new session, hand-overwrite:"
echo "    ~/www/$PROJECT/docs/_meta/dev-task-state.md"
echo "    with real Goal / Decisions / Files / Next Steps from today."

# Step 3: Sync to external memory
echo ""
echo "🔌 Step 3: Syncing facts to external memory..."
if ! python3 "$SKILL_DIR/scripts/sync_external.py" \
    --project "$PROJECT" 2>&1 | tail -3; then
    echo "  ⚠️  sync_external.py failed, continuing anyway"
fi

# Step 4: Write interruption log
echo ""
echo "📋 Step 4: Writing interruption log..."
INTERRUPTION_LOG="$HOME/www/$PROJECT/docs/_meta/interruption_log.md"
mkdir -p "$(dirname "$INTERRUPTION_LOG")"
TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
{
    echo "# Interruption Log — $PROJECT"
    echo ""
    echo "| When | Reason | Active session_id |"
    echo "|------|--------|-------------------|"
    echo "| $TS | $REASON | $ACTIVE_SID |"
} > "$INTERRUPTION_LOG"
echo "  ✅ $INTERRUPTION_LOG"

# Step 5: Generate the resume command
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ State saved. To RESUME, run one of these:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  # Option A: Resume this specific session (preserves session_id, exact context)"
echo "  hermes --profile $PROFILE --resume $ACTIVE_SID"
echo ""
echo "  # Option B: Resume by project name (most recent matching session)"
if [ -n "$DISPLAY_NAME" ]; then
    echo "  hermes --profile $PROFILE --continue \"$DISPLAY_NAME\""
else
    echo "  hermes --profile $PROFILE --continue \"$PROJECT\""
fi
echo ""
echo "  # Option C: New session + auto-inject state via load_state.py"
echo "  bash $RECOVERY_SKILL_DIR/scripts/resume.sh $PROJECT"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📋 Next steps for David:"
echo "   1. (Optional) Take a break — your work is safely saved"
echo "   2. When ready, run Option C (cleanest: new session + injected state)"
echo "   3. The new session will start with: '📍 Resuming $PROJECT — last activity ...'"
echo "═══════════════════════════════════════════════════════════════"
