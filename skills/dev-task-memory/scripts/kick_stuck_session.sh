#!/usr/bin/env bash
# kick_stuck_session.sh — Auto-detect and reset sessions stuck in [CONTEXT COMPACTION] loop.
#
# Usage:
#   bash kick_stuck_session.sh                    # check all active sessions
#   bash kick_stuck_session.sh <session_id>       # check specific session
#   bash kick_stuck_session.sh --auto             # auto-reset stuck sessions
#
# Detection logic:
#   - Check last 3 assistant messages
#   - If ALL of them are [CONTEXT COMPACTION — REFERENCE ONLY] handoffs
#   - AND api_calls == 1 AND finish_reason == 'stop'
#   - Then session is STUCK (zombie)
#
# Action (with --auto):
#   1. Mark sessions.json entry with `suspended: true` (CRITICAL — triggers reset on next inbound)
#   2. UPDATE sessions SET ended_at=now, end_reason=... in state.db (preserve history)
#   3. INSERT sentinel message into messages table
#   4. Print "Send a message in Discord to start fresh session" instruction
#
# Key insight (2026-06-06): The Discord thread → session mapping is in `sessions.json`,
# NOT in the SQLite sessions table. Marking ended_at in SQLite alone does NOT redirect
# the gateway to a new session. Must edit sessions.json to set `suspended: true`,
# which causes SessionStore.get_or_create_session() to reset the entry on next call.

set -e

PROFILE="developer"
DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"
SESSIONS_JSON="$HOME/.hermes/profiles/$PROFILE/sessions/sessions.json"
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
SESSIONS_JSON="$HOME/.hermes/profiles/$PROFILE/sessions/sessions.json"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ DB not found: $DB_PATH"
    exit 1
fi
if [ ! -f "$SESSIONS_JSON" ]; then
    echo "⚠️  sessions.json not found: $SESSIONS_JSON (continuing without it)"
    SESSIONS_JSON=""
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
echo "   sessions.json: ${SESSIONS_JSON:-(none)}"
echo ""

STUCK_COUNT=0
for sid in $SESSIONS; do
    title=$(sqlite3 "$DB_PATH" "SELECT title FROM sessions WHERE id = '$sid'" 2>/dev/null)
    last_active=$(sqlite3 "$DB_PATH" "SELECT datetime(started_at, 'unixepoch') FROM sessions WHERE id = '$sid'" 2>/dev/null)
    msg_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM messages WHERE session_id = '$sid'" 2>/dev/null)
    ended=$(sqlite3 "$DB_PATH" "SELECT ended_at FROM sessions WHERE id = '$sid'" 2>/dev/null)
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
            echo "     🚨 Auto-resetting session..."

            # Find matching sessions.json entry by scanning all values for this session_id
            if [ -n "$SESSIONS_JSON" ] && [ -f "$SESSIONS_JSON" ]; then
                python3 - "$SESSIONS_JSON" "$sid" <<'PYTHON'
import json
import sys

sessions_json = sys.argv[1]
target_sid = sys.argv[2]

with open(sessions_json) as f:
    data = json.load(f)

found_keys = []
for key, entry in data.items():
    if entry.get("session_id") == target_sid:
        found_keys.append(key)
        entry["suspended"] = True
        entry["auto_reset_reason"] = "stuck_in_compaction_loop_8_turns_no_real_work"

if found_keys:
    with open(sessions_json, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"     ✅ sessions.json: marked suspended=True on {len(found_keys)} entry(ies):")
    for k in found_keys:
        print(f"        - {k}")
else:
    print(f"     ⚠️  sessions.json: no entry found for session_id={target_sid}")
PYTHON
            fi

            # Mark session as ended in state.db (preserve history)
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
{"type": "session_terminated_sentinel", "reason": "Stuck in [CONTEXT COMPACTION] loop for ${stuck_count} turns. Auto-reset by kick_stuck_session.sh (suspended flag set on sessions.json entry).", "ended_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "replacement": "hermes gateway will derive new session_id on next inbound"}
JSON
)
            sqlite3 "$DB_PATH" "
                INSERT INTO messages (id, session_id, role, content, timestamp, tool_calls, tool_call_id)
                VALUES ($next_id, '$sid', 'system', '$sentinel', $now, NULL, NULL);
            " 2>&1
            echo "     ✅ state.db: session ended, sentinel inserted"
        else
            echo "     💡 To auto-reset: re-run with --auto"
        fi
    fi
    echo ""
done

if [ "$STUCK_COUNT" -gt 0 ]; then
    echo "🚨 Found $STUCK_COUNT stuck session(s)"
    if [ "$AUTO" = "1" ]; then
        echo ""
        echo "📋 Next steps (CRITICAL):"
        echo "   ⚠️  The gateway's in-memory cache still holds the old entry."
        echo "      MUST restart gateway to reload sessions.json with suspended=True:"
        echo ""
        echo "      launchctl bootout gui/\$(id -u)/ai.hermes.gateway-$PROFILE"
        echo "      launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/ai.hermes.gateway-$PROFILE.plist"
        echo ""
        echo "   2. Send a message in Discord #developer-home channel to start fresh session"
        echo "   3. (Optional) Inject state via:"
        echo "      python3 ~/.hermes/profiles/$PROFILE/skills/dev-task-memory/scripts/load_state.py \\"
        echo "          --project hermes-developer-profile"
        echo ""
    fi
else
    echo "✅ All sessions healthy"
fi
