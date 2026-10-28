#!/usr/bin/env bats
#
# skills/dav-trust/tests/sleep-guard.bats
#
# Locks the "no waiting for the clock" guard: which shell commands count as idling
# (short sleeps must stay allowed — they are normal for ports and retry backoff).
# Pure functions only (extension/lib/sleep-guard.ts) — no pi API, no I/O.

setup() {
  GUARD_TS="$BATS_TEST_DIRNAME/../extension/lib/sleep-guard.ts"
  [ -f "$GUARD_TS" ] || { echo "missing $GUARD_TS" >&2; return 1; }
  command -v node >/dev/null || skip "node not installed"
}

# classify "<command>" [maxSleepSeconds] -> prints "allow" or "BLOCK <kind>"
classify() {
  GUARD_TS="$GUARD_TS" CMD="$1" MAX="${2:-30}" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.GUARD_TS);
    const r = m.findIdleWait(process.env.CMD, Number(process.env.MAX));
    console.log(r ? "BLOCK " + r.kind : "allow");
  '
}

@test "SG-1: a long sleep is blocked (the reported trust-mode behaviour)" {
  run classify "sleep 600"
  [ "$output" = "BLOCK long-sleep" ]
}

@test "SG-2: sleeps up to the threshold stay allowed" {
  run classify "sleep 30"
  [ "$output" = "allow" ]
  run classify "sleep 0.5"
  [ "$output" = "allow" ]
  run classify "sleep 2 && curl -s localhost:3000"
  [ "$output" = "allow" ]
}

@test "SG-3: unit suffixes are converted (5m / 1h are long)" {
  run classify "sleep 5m"
  [ "$output" = "BLOCK long-sleep" ]
  run classify "sleep 1h"
  [ "$output" = "BLOCK long-sleep" ]
  run classify "sleep 10s"
  [ "$output" = "allow" ]
}

@test "SG-4: a sleep whose length cannot be proven is blocked (e.g. waiting until the deadline)" {
  run classify 'sleep $(($(date -d "$DEADLINE" +%s) - $(date +%s)))'
  [ "$output" = "BLOCK unknown-sleep" ]
  run classify 'sleep "$WAIT"'
  [ "$output" = "BLOCK unknown-sleep" ]
}

@test "SG-5: idling is caught behind other commands, pipes and wrappers" {
  run classify "echo hi; sleep 700"
  [ "$output" = "BLOCK long-sleep" ]
  run classify "true && sleep 120"
  [ "$output" = "BLOCK long-sleep" ]
  run classify "timeout 10 sleep 900"
  [ "$output" = "BLOCK long-sleep" ]
}

@test "SG-6: busy loops and a bare wait are blocked; real work is not" {
  run classify "while true; do :; done"
  [ "$output" = "BLOCK busy-loop" ]
  run classify "until false; do sleep 1; done"
  [ "$output" = "BLOCK busy-loop" ]
  run classify "wait"
  [ "$output" = "BLOCK bare-wait" ]
  run classify "npm test"
  [ "$output" = "allow" ]
  run classify "for i in 1 2 3; do sleep 1; done"
  [ "$output" = "allow" ]
}

@test "SG-7: the threshold is configurable" {
  run classify "sleep 45" 60
  [ "$output" = "allow" ]
  run classify "sleep 61" 60
  [ "$output" = "BLOCK long-sleep" ]
}

@test "SG-8: the block reason tells the model what to do instead" {
  GUARD_TS="$GUARD_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.GUARD_TS);
    const r = m.findIdleWait("sleep 600", 30);
    const text = m.blockReason(r, 30);
    for (const want of ["L1 → L2 → L3", "report early completion", "time-anchor.md §6", "sleep 600"]) {
      if (!text.includes(want)) { console.error("missing: " + want + "\n" + text); process.exit(1); }
    }
    console.log("reason OK");
  '
}
