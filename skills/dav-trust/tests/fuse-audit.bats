#!/usr/bin/env bats
#
# skills/dav-trust/tests/fuse-audit.bats
#
# Locks the trust-mode fuse audit: trust mode assumes compaction happens by itself,
# so pi's reserveTokens must make auto-compaction fire inside the opportunity window.
# Pure functions only (extension/lib/fuse-audit.ts) — no pi API, no I/O.

setup() {
  AUDIT_TS="$BATS_TEST_DIRNAME/../extension/lib/fuse-audit.ts"
  [ -f "$AUDIT_TS" ] || { echo "missing $AUDIT_TS" >&2; return 1; }
  command -v node >/dev/null || skip "node not installed"
}

@test "FA-1: a fuse inside the opportunity window is OK (and reports the fix value)" {
  AUDIT_TS="$AUDIT_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.AUDIT_TS);
    const zones = m.normalizeTrustZones({ softPercent: 50, opportunityPercent: 55, hardPercent: 60, absoluteCapTokens: 200000 });
    const a = m.auditFuse(1000000, 890000, zones);
    if (!a.ok || a.tooLate || a.tooEarly) { console.error(JSON.stringify(a)); process.exit(1); }
    if (a.triggerTokens !== 110000 || a.reserveNeeded !== 890000) { console.error(JSON.stringify(a)); process.exit(1); }
    if (!m.fuseAuditText(a, zones).includes("fuse OK")) { console.error("text"); process.exit(1); }
    console.log("ok");
  '
}

@test "FA-2: pi's default reserve is far too late and the text says how to fix it" {
  AUDIT_TS="$AUDIT_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.AUDIT_TS);
    const zones = m.normalizeTrustZones({ absoluteCapTokens: 200000 });
    const a = m.auditFuse(1000000, 16384, zones);
    if (!a.tooLate || a.ok) { console.error(JSON.stringify(a)); process.exit(1); }
    const text = m.fuseAuditText(a, zones);
    for (const want of ["TOO LATE", "120000", "reserveTokens = 890000", "cannot compact by itself"]) {
      if (!text.includes(want)) { console.error("missing: " + want + "\n" + text); process.exit(1); }
    }
    console.log("ok");
  '
}

@test "FA-3: a fuse that fires before the smart zone ends is flagged as too early" {
  AUDIT_TS="$AUDIT_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.AUDIT_TS);
    const zones = m.normalizeTrustZones({ absoluteCapTokens: 200000 });
    const a = m.auditFuse(1000000, 950000, zones);
    if (!a.tooEarly || a.ok) { console.error(JSON.stringify(a)); process.exit(1); }
    if (!m.fuseAuditText(a, zones).includes("too early")) { console.error("text"); process.exit(1); }
    console.log("ok");
  '
}

@test "FA-4: zone thresholds are sanitised and the opportunity window stays inside (soft, hard]" {
  AUDIT_TS="$AUDIT_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.AUDIT_TS);
    const high = m.normalizeTrustZones({ softPercent: 50, hardPercent: 60, opportunityPercent: 90 });
    if (high.opportunityPercent !== 60) { console.error("high=" + high.opportunityPercent); process.exit(1); }
    const low = m.normalizeTrustZones({ softPercent: 50, hardPercent: 60, opportunityPercent: 10 });
    if (low.opportunityPercent !== 51) { console.error("low=" + low.opportunityPercent); process.exit(1); }
    const junk = m.normalizeTrustZones({ softPercent: "x", hardPercent: -1, opportunityPercent: null, absoluteCapTokens: -5 });
    if (junk.softPercent !== 50 || junk.hardPercent !== 60 || junk.opportunityPercent !== 55 || junk.absoluteCapTokens !== 0) {
      console.error(JSON.stringify(junk)); process.exit(1);
    }
    console.log("ok");
  '
}

@test "FA-5: reserveTokens resolves like pi does (model override first, then ordinary, then default)" {
  AUDIT_TS="$AUDIT_TS" node --experimental-strip-types --no-warnings -e '
    const m = await import(process.env.AUDIT_TS);
    const key = "minimax/MiniMax-M3.1-Flash";
    const own = { reserveTokens: 111, modelOverrides: { [key]: { reserveTokens: 222 } } };
    const other = { reserveTokens: 333, modelOverrides: { [key]: { reserveTokens: 444 } } };
    const cases = [
      [m.resolveReserveTokens(own, key, other), 222],
      [m.resolveReserveTokens(own, undefined, other), 111],
      [m.resolveReserveTokens(undefined, key, other), 444],
      [m.resolveReserveTokens(undefined, undefined, undefined), 16384],
      [m.resolveReserveTokens({ reserveTokens: "bad" }, undefined, undefined), 16384],
    ];
    for (const [got, want] of cases) {
      if (got !== want) { console.error("got " + got + " want " + want); process.exit(1); }
    }
    console.log("ok");
  '
}
