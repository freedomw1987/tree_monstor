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
  echo "$output" | grep -q 'soft=100k hard=120k'
}

@test "Z2: native fuse fires exactly at the hard block when reserveTokens = window - hardTokens" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":200000}' 10000 1000000 880000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'fires at 12.0% (120k tokens) = hard block'
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

@test "Z7: fuse too late (default reserve) is reported with the fix value" {
  run run_zone '{"softPercent":50,"hardPercent":60,"absoluteCapTokens":0}' 10000 1000000 16384
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '⚠ native auto-compaction only fires at'
  echo "$output" | grep -q 'set compaction.reserveTokens=400000'
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
