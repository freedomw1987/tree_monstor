#!/usr/bin/env python3
"""
QA-TRACKER.md parser — used in Step 1 of unit-test-coverage-push skill.
Reads docs/QA-TRACKER.md, counts P0 US by test status, and prints actionable breakdown.
Real session: 2026-06-08 pm-system, 29 P0 US total, 22 needed unit tests.
"""
import re
import sys
from pathlib import Path


def parse_qa_tracker(path: str = "docs/QA-TRACKER.md") -> list:
    """Parse QA-TRACKER.md into list of (US, title, priority, status_x, status_e, test_status) tuples."""
    md = Path(path).read_text()
    rows = []
    for line in md.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 7:  # need at least 7 columns
            continue
        # Skip separator row (---)
        if set(c.replace("-", "").replace(":", "").strip() for c in cells) == {""}:
            continue
        head = cells[1]
        m = re.search(r"(US-[\d.]+)\s+(.*?)\s*$", head)
        if not m:
            continue
        us, title = m.group(1), m.group(2).replace("**", "").strip()
        # Column layout (2026-06-08 convention): ID | Title | Priority | US Status | Code Status | Test Status | Notes
        priority = cells[2]
        us_status = cells[3]
        code_status = cells[4]
        test_status = cells[5] if len(cells) > 5 else ""
        rows.append((us, title, priority, us_status, code_status, test_status))
    return rows


def classify(rows: list) -> dict:
    """Classify P0 US into action buckets."""
    p0 = [r for r in rows if "P0" in r[2]]
    none = [r for r in p0 if r[5].startswith("NONE")]
    partial = [r for r in p0 if r[5].startswith("PARTIAL") and "PASS" not in r[5]]
    pass_e2e_only = [
        r for r in p0
        if "PASS-E2E" in r[5] and "PASS-UNIT" not in r[5]
    ]
    pass_unit = [r for r in p0 if "PASS-UNIT" in r[5]]
    pass_full = [r for r in p0 if "PASS" in r[5] and "FAIL" not in r[5]]
    return {
        "total_p0": len(p0),
        "need_unit": none + partial + pass_e2e_only,
        "pass_unit": pass_unit,
        "pass_full": pass_full,
        "none": none,
        "partial": partial,
        "pass_e2e_only": pass_e2e_only,
    }


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        path = "docs/QA-TRACKER.md"
    rows = parse_qa_tracker(path)
    if not rows:
        print(f"No rows parsed from {path} — check column layout")
        sys.exit(1)
    cls = classify(rows)
    print(f"=== {path} ===")
    print(f"Total P0 US: {cls['total_p0']}")
    print(f"Need unit test: {len(cls['need_unit'])}")
    print(f"  - NONE: {len(cls['none'])}")
    print(f"  - PARTIAL: {len(cls['partial'])}")
    print(f"  - PASS-E2E-only: {len(cls['pass_e2e_only'])}")
    print(f"Already PASS-UNIT: {len(cls['pass_unit'])}")
    print(f"PASS-UNIT + PASS-E2E: {len(cls['pass_full'])}")
    cov = len(cls['pass_full']) / max(cls['total_p0'], 1) * 100
    print(f"Coverage: {cov:.0f}% (target: 紅線 12 = 100% P0, 紅線 16 = 100% P0 with 3 layers)")
    if cls['need_unit']:
        print("\n=== US needing unit test ===")
        for r in cls['need_unit']:
            print(f"  {r[0]:<10} {r[1][:50]:<50} {r[5]}")


if __name__ == "__main__":
    main()
