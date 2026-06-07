#!/usr/bin/env bash
# archive_old_sessions.sh — Archive old terminal sessions to free active session list.
#
# Problem: Hermes gateway keeps EVERY discord session "active" (ended_at=NULL)
# forever. After running overnight we have 6+ active sessions with 50-130 messages
# each. Eventually routing picks a stale one.
#
# This script:
#   1. Find discord sessions with ended_at IS NULL AND last activity > 24h ago
#   2. Mark them as ended with end_reason='archived_inactive_24h'
#   3. Insert a sentinel message so the session history is preserved
#   4. Print audit summary
#
# Safe to run daily via cron. Doesn't touch the messages themselves — only
# metadata. Future --resume or --continue will skip these.

set -e

PROFILE="${1:-developer}"
DB_PATH="$HOME/.hermes/profiles/$PROFILE/state.db"
SESSIONS_JSON="$HOME/.hermes/profiles/$PROFILE/sessions/sessions.json"
INACTIVITY_HOURS="${2:-24}"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ DB not found: $DB_PATH"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "🗄️  ARCHIVE OLD SESSIONS — Profile: $PROFILE, Inactivity: ${INACTIVITY_HOURS}h"
echo "═══════════════════════════════════════════════════════════════"

# Find candidates — use started_at since sessions table has no updated_at
ARCHIVE_LIST=$(sqlite3 "$DB_PATH" "
SELECT s.id, s.message_count, datetime(s.started_at, 'unixepoch') as started
FROM sessions s
WHERE s.source = 'discord'
  AND s.ended_at IS NULL
  AND s.archived = 0
  AND s.started_at < strftime('%s', 'now') - ($INACTIVITY_HOURS * 3600)
ORDER BY s.started_at ASC;
" 2>/dev/null)

ARCHIVE_COUNT=$(echo "$ARCHIVE_LIST" | grep -c '|' || echo 0)
echo ""
echo "Found $ARCHIVE_COUNT inactive discord session(s):"
echo "$ARCHIVE_LIST" | head -20 | while IFS='|' read -r sid msgcount started; do
    [ -z "$sid" ] && continue
    echo "  • $sid | ${msgcount} msgs | started: $started"
done
echo ""

# Archive each
ARCHIVED=0
echo "$ARCHIVE_LIST" | while IFS='|' read -r sid msgcount started; do
    [ -z "$sid" ] && continue
    
    # Mark session as archived + ended in state.db (use Hermes native archived flag)
    sqlite3 "$DB_PATH" "
        UPDATE sessions
        SET ended_at = strftime('%s', 'now'),
            end_reason = 'archived_inactive_${INACTIVITY_HOURS}h',
            archived = 1
        WHERE id = '$sid';
    " 2>&1 >/dev/null
    
    # Insert sentinel into messages (preserve history). Use full-table MAX(id)+1
    # to avoid UNIQUE constraint conflicts across sessions.
    next_id=$(sqlite3 "$DB_PATH" "SELECT COALESCE(MAX(id), 0) + 1 FROM messages")
    now=$(date +%s)
    sentinel=$(printf '{"type": "archive_sentinel", "reason": "Session auto-archived after %sh inactivity. Started: %s. Run resume.sh to restore if needed.", "ended_at": "%s"}' \
        "$INACTIVITY_HOURS" "$started" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    sqlite3 "$DB_PATH" "
        INSERT INTO messages (id, session_id, role, content, timestamp, tool_calls, tool_call_id)
        VALUES ($next_id, '$sid', 'system', '$sentinel', $now, NULL, NULL);
    " 2>&1 >/dev/null
    
    # Suspend in sessions.json (so gateway routes to new session)
    if [ -f "$SESSIONS_JSON" ]; then
        python3 - "$SESSIONS_JSON" "$sid" <<'PYTHON' 2>/dev/null
import json, sys
sessions_json, target_sid = sys.argv[1], sys.argv[2]
with open(sessions_json) as f:
    data = json.load(f)
for key, entry in data.items():
    if entry.get("session_id") == target_sid:
        entry["suspended"] = True
        entry["auto_reset_reason"] = f"archived_inactive_24h"
        break
with open(sessions_json, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYTHON
    fi
    
    ARCHIVED=$((ARCHIVED + 1))
    echo "  ✅ Archived $sid"
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Done. $ARCHIVE_COUNT session(s) archived."
echo ""
echo "Recovery: bash ~/.hermes/profiles/$PROFILE/skills/interruption-recovery/scripts/resume.sh <project>"
echo "═══════════════════════════════════════════════════════════════"
