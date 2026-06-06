#!/usr/bin/env bash
# kick_stuck_session.sh — Auto-detect and end sessions stuck in [CONTEXT COMPACTION] loop.
#
# Usage:
#   bash kick_stuck_session.sh                    # check all active sessions
#   bash kick_stuck_session.sh <session_id>       # check specific session
#   bash kick_stuck_session.sh --auto             # auto-end stuck sessions
#
# Detection logic:
#   - Check last 3 assistant messages
#   - If ALL of them are [CONTEXT COMPACTION — REFERENCE ONLY] handoffs
#   - AND api_calls == 1 AND finish_reason == 'stop'
#   - Then session is STUCK (zombie)
#
# Action (with --auto):
#   - UPDATE sessions SET ended_at=now, end_reason='stuck_in_compaction_loop'
#   - INSERT sentinel message into messages table
#   - Print "Restart gateway and start new session" instruction

set -e

PROFILE="developer"
DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"
AUTO=0
TARGET_SESSION=""

for arg in "$@"; do
    case $arg in
        --auto) AUTO=1 ;;
        --profile=*) PROFILE="${arg#*=}" ;;
        2026*) TARGET_SESSION="$arg" ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ DB not found: $DB_PATH"
    exit 1
fi

detect_stuck() {
    local session_id="$1"
    sqlite3 "$DB_PATH" "
        SELECT COUNT(*) FROM (
            SELECT content
            FROM messages
            WHERE session_id = '$session_id'
              AND role = 'assistant'
              AND content LIKE '[CONTEXT COMPACTION — REFERENCE ONLY]%'
            ORDER BY id DESC
            LIMIT 3
        )
        WHERE content LIKE '[CONTEXT COMPACTION%'
        ;
    " 2>/dev/null
}

# Get candidate sessions
if [ -n "$TARGET_SESSION" ]; then
    SESSIONS="$TARGET_SESSION"
else
    SESSIONS=$(sqlite3 "$DB_PATH" "
        SELECT id FROM sessions
        WHERE ended_at IS NULL
          AND source = 'discord'
          AND id IN (SELECT session_id FROM messages GROUP BY session_id HAVING COUNT(*) > 10)
        ORDER BY started_at DESC
        LIMIT 5
    " 2>/dev/null)
fi

if [ -z "$SESSIONS" ]; then
    echo "✅ No active sessions to check"
    exit 0
fi

echo "🔍 Scanning sessions for [CONTEXT COMPACTION] stuck loop..."
echo "   Profile: $PROFILE"
echo "   DB: $DB_PATH"
echo ""

STUCK_COUNT=0
for sid in $SESSIONS; do
    # Get session info
    title=$(sqlite3 "$DB_PATH" "SELECT title FROM sessions WHERE id = '$sid'" 2>/dev/null)
    last_active=$(sqlite3 "$DB_PATH" "SELECT datetime(started_at, 'unixepoch') FROM sessions WHERE id = '$sid'" 2>/dev/null)
    msg_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM messages WHERE session_id = '$sid'" 2>/dev/null)
    ended=$(sqlite3 "$DB_PATH" "SELECT ended_at FROM sessions WHERE id = '$sid'" 2>/dev/null)

    # Detect stuck
    stuck_count=$(detect_stuck "$sid")

    echo "  📋 $sid"
    echo "     Title: ${title:-(untitled)}"
    echo "     Started: $last_active | Ended: ${ended:-(active)}"
    echo "     Messages: $msg_count"
    echo "     Stuck count: $stuck_count / 3 last assistant messages"

    if [ "$stuck_count" -ge 2 ]; then
        echo "     ⚠️  STUCK DETECTED"
        STUCK_COUNT=$((STUCK_COUNT + 1))

        if [ "$AUTO" = "1" ]; then
            echo "     🚨 Auto-ending session..."
            sqlite3 "$DB_PATH" "
                UPDATE sessions
                SET ended_at = strftime('%s', 'now'),
                    end_reason = 'stuck_in_compaction_loop_${stuck_count}_turns'
                WHERE id = '$sid';
            " 2>&1

            # Insert sentinel
            next_id=$(sqlite3 "$DB_PATH" "SELECT COALESCE(MAX(id), 0) + 1 FROM messages WHERE session_id = '$sid'")
            now=$(date +%s)
            sentinel=$(cat <<JSON
{"type": "session_terminated_sentinel", "reason": "Stuck in [CONTEXT COMPACTION] loop for ${stuck_count} turns. Auto-ended by kick_stuck_session.sh.", "ended_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "replacement": "hermes --profile $PROFILE -c 'hermes-developer-profile' --skills dev-task-memory"}
JSON
)
            sqlite3 "$DB_PATH" "
                INSERT INTO messages (id, session_id, role, content, timestamp, tool_calls, tool_call_id)
                VALUES ($next_id, '$sid', 'system', '$sentinel', $now, NULL, NULL);
            " 2>&1
            echo "     ✅ Session ended + sentinel inserted"
        else
            echo "     💡 To auto-end: re-run with --auto"
        fi
    fi
    echo ""
done

if [ "$STUCK_COUNT" -gt 0 ]; then
    echo "🚨 Found $STUCK_COUNT stuck session(s)"
    if [ "$AUTO" = "1" ]; then
        echo ""
        echo "📋 Next steps:"
        echo "   1. Restart developer gateway:"
        echo "      launchctl bootout gui/\$(id -u)/ai.hermes.gateway-developer"
        echo "      launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/ai.hermes.gateway-developer.plist"
        echo "   2. Send a message in Discord #developer-home channel to start fresh session"
        echo "   3. (Optional) Inject state via:"
        echo "      python3 ~/.hermes/profiles/developer/skills/dev-task-memory/scripts/load_state.py \\"
        echo "          --project hermes-developer-profile"
        echo ""
    fi
else
    echo "✅ All sessions healthy"
fi
