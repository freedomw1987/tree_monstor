#!/usr/bin/env bash
# run_loop.sh — Long-task-resilience daemon loop
#
# Runs context_pressure_monitor + approval-spam-detector every 30 seconds.
# Sleeps between iterations. Exits cleanly on SIGTERM (so launchd can restart).
#
# Why bash loop instead of long-running Python:
# - launchd KeepAlive is more reliable for short-lived processes
# - Each iteration is stateless (reads state.db, takes action, exits)
# - No memory leaks over time
# - Easy to debug (each iteration's output is timestamped)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="[long-task-resilience]"
SLEEP_INTERVAL=30  # seconds between iterations

echo "${LOG_PREFIX} $(date -u +%FT%TZ) daemon started (PID $$, interval=${SLEEP_INTERVAL}s)"

# Trap signals for clean shutdown
trap 'echo "${LOG_PREFIX} $(date -u +%FT%TZ) received signal, exiting"; rm -f /tmp/hermes-long-task-resilience.pid; exit 0' SIGTERM SIGINT

# Track our PID for the file lock
PIDFILE="/tmp/hermes-long-task-resilience.pid"
echo $$ > "$PIDFILE"

iteration=0
while true; do
    iteration=$((iteration + 1))
    ts="$(date -u +%FT%TZ)"

    # Run context pressure monitor
    python3 "$SCRIPT_DIR/context_pressure_monitor.py" --once 2>&1 | head -20 || true

    # Run approval-spam detector (added 2026-06-07 in response to David's zombie report)
    python3 "$SCRIPT_DIR/approval_spam_detector.py" --once 2>&1 | head -10 || true

    # Run fork queue processor
    python3 "$SCRIPT_DIR/process_fork_queue.py" 2>&1 | head -5 || true

    sleep "$SLEEP_INTERVAL"
done
