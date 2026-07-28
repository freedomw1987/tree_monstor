#!/usr/bin/env python3
"""Advisory audit: flag skills that look like single-project case history.

Scores each SKILL.md on markers that only appear when a skill is a write-up of
one specific incident in one specific codebase, rather than a reusable pattern.
Advisory only -- exits 0 regardless. Human judgment decides the boundary.

Usage:
    python3 scripts/case_history_audit.py            # active skills, ranked
    python3 scripts/case_history_audit.py --min 4    # only score >= 4
    python3 scripts/case_history_audit.py --detail <path>   # show hits for one file
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Each marker: (label, weight, compiled regex)
MARKERS = [
    # A concrete deployed hostname pins the skill to one deployment.
    ("concrete-domain", 3, re.compile(r"\b[a-z0-9-]+\.david-developer\.com\b", re.I)),
    # Routable IPv4 literals (localhost / 0.0.0.0 / docs ranges excluded below).
    ("concrete-ip", 3, re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")),
    # Known project code names.
    ("project-name", 3, re.compile(
        r"\b(lemontree(_aws)?|pm-system|tree_monstor|treemonstor|chatbot-proxy)\b", re.I)),
    # Absolute paths into one machine's home dir.
    ("machine-path", 2, re.compile(r"(/Users/[a-z0-9_.-]+|~/projects/)", re.I)),
    # "Bug A:" / "Bug Q:" enumeration == one debugging campaign's log.
    ("bug-enumeration", 3, re.compile(r"^#{2,4}\s*Bug\s+[A-Z]\b", re.M)),
    # Named source files from a specific app.
    ("app-component-file", 2, re.compile(r"\b[A-Z][A-Za-z0-9]{2,}\.(?:jsx|tsx|vue)\b")),
    # Incident narrative framing.
    ("symptom-narrative", 1, re.compile(r"^\*\*(?:Symptom|症狀)", re.M | re.I)),
]

# IPs that are generic infrastructure, not a specific host.
GENERIC_IPS = {"127.0.0.1", "0.0.0.0", "255.255.255.255", "8.8.8.8", "1.1.1.1"}


def score(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    hits = {}
    total = 0
    for label, weight, pattern in MARKERS:
        found = pattern.findall(text)
        if label == "concrete-ip":
            found = [
                f for f in found
                if f not in GENERIC_IPS and not f.startswith(("0.", "255."))
            ]
        if not found:
            continue
        uniq = sorted({f if isinstance(f, str) else f[0] for f in found})
        hits[label] = (len(found), uniq[:4])
        total += weight
    return total, hits, len(text.split("\n"))


def applicability(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^applicability:[ \t]*(\S+)", text, re.M)
    return m.group(1) if m else "-"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min", type=int, default=1, help="minimum score to list")
    ap.add_argument("--detail", help="show marker hits for a single file")
    args = ap.parse_args()

    if args.detail:
        path = pathlib.Path(args.detail)
        if not path.is_absolute():
            path = ROOT / path
        total, hits, lines = score(path)
        print(f"{path.relative_to(ROOT)}  score={total}  lines={lines}  "
              f"applicability={applicability(path)}")
        for label, (count, samples) in sorted(hits.items()):
            print(f"  {label:22} x{count:<4} {samples}")
        return 0

    rows = []
    for path in sorted((ROOT / "skills").rglob("SKILL.md")):
        total, hits, lines = score(path)
        if total >= args.min:
            rows.append((total, lines, path, hits))
    rows.sort(key=lambda r: (-r[0], -r[1]))

    print(f"case-history marker audit -- {len(rows)} of "
          f"{len(list((ROOT / 'skills').rglob('SKILL.md')))} active skills "
          f"scored >= {args.min}\n")
    print(f"{'score':>5}  {'lines':>5}  {'applicability':<15} path")
    print(f"{'-' * 5}  {'-' * 5}  {'-' * 15} {'-' * 50}")
    for total, lines, path, hits in rows:
        print(f"{total:>5}  {lines:>5}  {applicability(path):<15} "
              f"{path.relative_to(ROOT)}")
        print(f"{'':>5}  {'':>5}  {'':<15} markers: {', '.join(sorted(hits))}")
    print("\nAdvisory only. High score = likely one-project write-up; confirm by "
          "reading before archiving.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
