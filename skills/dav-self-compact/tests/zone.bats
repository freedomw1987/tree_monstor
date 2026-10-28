#!/usr/bin/env bats
#
# skills/dav-self-compact/tests/zone.bats
#
# Locks the numbers the skill documents: soft/hard token thresholds, the
# native-fuse trigger point, and the pathological reserveTokens >= window case.
# Pure functions only (extension/lib/zone.ts) — no pi API, no I/O.

setup() {
  ZONE_TS="$BATS_TEST_DIRNAME/../extension/lib/zone.ts"
  [ -f "$ZONE_TS" ] || { echo "missing $ZONE_TS" >&2; return 1; }
  command -v node >/dev/null || skip "node not installed"
}

# run_zone '<zones json>' '<tokens>' '<window>' '<reserve>' -> prints oneLine|fuse
run_zone() {
  local zones_json="$1" tokens="$2" window="$3" reserve="$4"
  ZONES="$zones_json" TOKENS="$tokens" WINDOW="$window" RESERVE="$reserve" \
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const zones = m.normalizeZones(JSON.parse(process.env.ZONES));
    const r = m.computeReading({
      tokens: Number(process.env.TOKENS),
      contextWindow: Number(process.env.WINDOW),
      percent: null,
    }, Number(process.env.RESERVE), zones);
    console.log(m.oneLine(r));
    console.log("FUSE:" + m.fuseNote(r, zones));
  '
}

# ---------- AC: documented thresholds (cap 200k / window 1M / reserve 880k) ----------
@test "Z1: cap 200000 makes soft=100k and hard=120k even on a 1M window" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 10000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'soft=100k win=110k hard=120k'
}

@test "Z2: native fuse fires inside the opportunity window when reserveTokens = window - opportunityTokens" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 10000 1000000 890000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'fires at 11.0% (110k tokens) = inside the opportunity window'
}

@test "Z2b: default config opens the opportunity window at 55% (110k of a 200k budget)" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 110000 1000000 890000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'zone=opportunity'
  echo "$output" | grep -q 'action=compact_at_boundary'
}

@test "Z2c: a fuse that fires after the opportunity window is reported as too late" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 10000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'too late (hard block is 120k tokens)'
  echo "$output" | grep -q 'set compaction.reserveTokens=890000'
}

@test "Z3: 120k tokens on a 1M window with cap 200k reads as zone=hard (not 12%)" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 120000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'zone=hard'
  echo "$output" | grep -q 'ctx 60.0%'
}

@test "Z4: capped mode still shows the real window size" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 120000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'window 1000k'
}

@test "Z5: soft zone starts at 50% of the effective window" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 100000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'zone=soft'
}

# ---------- AC: fuse audit catches bad settings ----------
@test "Z6: reserveTokens >= contextWindow is reported as a warning, not OK" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":0}' 10000 200000 250000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '⚠ compaction.reserveTokens is larger than the context window'
}

@test "Z7: default pi reserve (16384) is far too late and reports the fix value" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 10000 1000000 16384
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '⚠ native auto-compaction fires at'
  echo "$output" | grep -q 'set compaction.reserveTokens=890000'
}

@test "Z7b: opportunityPercent is clamped into (soft, hard]" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const high = m.normalizeZones({ softPercent: 50, hardPercent: 60, opportunityPercent: 90 });
    if (high.opportunityPercent !== 60) { console.error("high=" + high.opportunityPercent); process.exit(1); }
    const low = m.normalizeZones({ softPercent: 50, hardPercent: 60, opportunityPercent: 10 });
    if (low.opportunityPercent !== 51) { console.error("low=" + low.opportunityPercent); process.exit(1); }
    const ok = m.normalizeZones({ softPercent: 50, hardPercent: 60 });
    if (ok.opportunityPercent !== 55) { console.error("default=" + ok.opportunityPercent); process.exit(1); }
    console.log("clamp OK");
  '
}

# ---------- AC: percent null right after compaction ----------
@test "Z8: null tokens reads as zone=unknown, not an error" {
  ZONES='{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' ZONE_TS="$ZONE_TS" \
  node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const zones = m.normalizeZones(JSON.parse(process.env.ZONES));
    const r = m.computeReading({ tokens: null, contextWindow: 1000000, percent: null }, 880000, zones);
    if (r.zone !== "unknown") { console.error("zone=" + r.zone); process.exit(1); }
    if (r.percent !== null) { console.error("percent=" + r.percent); process.exit(1); }
    console.log("unknown OK");
  '
}

@test "Z9: broken config falls back to documented defaults" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const z = m.normalizeZones({ softPercent: "nope", hardPercent: 999, absoluteCapTokens: -5 });
    const want = { softPercent: 50, hardPercent: 60, targetMinPercent: 20, targetPercent: 35, absoluteCapTokens: 0 };
    for (const [k, v] of Object.entries(want)) {
      if (z[k] !== v) { console.error(k + "=" + z[k]); process.exit(1); }
    }
    console.log("defaults OK");
  '
}

# ---------- AC: usage milestones (20 / 40 / 60 by default) ----------
@test "Z10: a milestone fires once, and only the highest newly crossed one" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const zones = m.normalizeZones({});
    let announced = new Set();

    // Jump straight past 20% and 40%: one notice, for 40.
    let step = m.nextNotice(42, zones.noticePercents, announced);
    if (step.notice !== 40) { console.error("first=" + step.notice); process.exit(1); }
    announced = step.announced;

    // Nothing new below the next milestone.
    step = m.nextNotice(45, zones.noticePercents, announced);
    if (step.notice !== null) { console.error("repeat=" + step.notice); process.exit(1); }

    // Crossing 60 later fires exactly once.
    step = m.nextNotice(61, zones.noticePercents, step.announced);
    if (step.notice !== 60) { console.error("sixty=" + step.notice); process.exit(1); }
    step = m.nextNotice(70, zones.noticePercents, step.announced);
    if (step.notice !== null) { console.error("again=" + step.notice); process.exit(1); }
    console.log("milestones OK");
  '
}

@test "Z11: null usage does not disturb milestone state; a big drop resets it" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const zones = m.normalizeZones({});
    const announced = new Set([20, 40]);
    const afterNull = m.nextNotice(null, zones.noticePercents, announced);
    if (afterNull.notice !== null || afterNull.announced.size !== 2) { console.error("null disturbed state"); process.exit(1); }
    if (!m.shouldResetNotices(45, 12)) { console.error("drop not detected"); process.exit(1); }
    if (m.shouldResetNotices(45, 44)) { console.error("false reset"); process.exit(1); }
    const reset = m.nextNotice(21, zones.noticePercents, new Set());
    if (reset.notice !== 20) { console.error("no re-notify after reset"); process.exit(1); }
    console.log("reset OK");
  '
}

@test "Z12: milestone text carries the reading, the zone label and the advice" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const zones = m.normalizeZones({ softPercent: 50, opportunityPercent: 55, hardPercent: 60, absoluteCapTokens: 200000 });
    const soft = m.computeReading({ tokens: 102000, contextWindow: 1000000, percent: null }, 890000, zones);
    const text = m.milestoneText(soft, zones, 40);
    for (const want of ["just crossed 40%", "51.0%", "102k/200k tokens", "window 1000k", "zone=soft (soft block)", "action=prepare_then_compact", "handoff note"]) {
      if (!text.includes(want)) { console.error("missing: " + want + " | " + text); process.exit(1); }
    }
    const hard = m.computeReading({ tokens: 120000, contextWindow: 1000000, percent: null }, 890000, zones);
    if (!m.milestoneText(hard, zones, 60).includes("zone=hard (hard block)")) { console.error("hard label"); process.exit(1); }
    console.log("text OK");
  '
}

@test "Z13: noticePercents is sanitised (dedupe, sort, drop junk, fall back to default)" {
  ZONE_TS="$ZONE_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.ZONE_TS);
    const cleaned = m.normalizeZones({ noticePercents: [60, 20, 40, 40, "x", 0, 140] }).noticePercents;
    if (JSON.stringify(cleaned) !== "[20,40,60]") { console.error(JSON.stringify(cleaned)); process.exit(1); }
    const fallback = m.normalizeZones({ noticePercents: [] }).noticePercents;
    if (JSON.stringify(fallback) !== "[20,40,60]") { console.error(JSON.stringify(fallback)); process.exit(1); }
    console.log("noticePercents OK");
  '
}
