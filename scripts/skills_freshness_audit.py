#!/usr/bin/env python3
"""Advisory content-freshness audit for Tree Monstor skills.

docs_consistency_check.py verifies navigation structure (index coverage,
links, markers) but says nothing about whether a skill's CONTENT is still
true — e.g. an Elysia 1.2 workaround may be obsolete two versions later.
This script closes that gap at the reporting level:

For each skills/**/SKILL.md it determines a "last reviewed" date:
1. an explicit ``Last-verified: YYYY-MM-DD`` line in the file (preferred —
   lets you re-validate a skill without a content change), else
2. the last git commit date touching the file, else
3. filesystem mtime (untracked files).

Skills older than --max-age-days (default 180) are reported as stale,
oldest first. Skills that pin explicit tech versions ("Elysia 1.2",
"Prisma 5", "React 19", …) are flagged as review-priority: they go stale
fastest.

ADVISORY BY DESIGN: exit code is 0 even when stale skills exist, so this
never blocks a commit and must NOT be added to pre-commit / CI. Use
--strict (exit 1 on stale version-pinned skills) only for deliberate
review sessions. Content review itself stays a human/agent judgement —
this script only ranks where to look first.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

LAST_VERIFIED_RE = re.compile(r"Last-verified[:：]\s*(\d{4}-\d{2}-\d{2})", re.I)

# Tech names whose adjacent version numbers make a skill version-pinned.
# Curated (not a generic number regex) to avoid matching dates and US-/RG- ids.
TECH_NAMES = [
    "bun", "elysia", "react", "vite", "prisma", "node", "node.js", "nodejs",
    "typescript", "tailwind", "tailwindcss", "playwright", "nginx", "caddy",
    "docker", "cdk", "aws-cdk", "python", "postgres", "postgresql", "sqlite",
    "next", "next.js", "express", "fastify", "hono", "nestjs", "pdf-parse",
    "multer", "zod", "react-router", "vitest", "jest", "eslint", "pnpm",
    "npm", "yarn", "ios", "safari", "macos",
]
VERSION_PIN_RE = re.compile(
    r"\b(" + "|".join(re.escape(name) for name in TECH_NAMES) + r")"
    r"[\s@]+v?(\d+(?:\.\d+)*)\b",
    re.I,
)


@dataclass
class SkillFreshness:
    path: str
    reviewed_on: str
    source: str  # "marker" | "git" | "fs"
    age_days: int
    version_pins: list[str]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Advisory freshness audit for skills/**/SKILL.md.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--max-age-days", type=int, default=180, help="Age threshold for stale (default 180).")
    parser.add_argument("--all", action="store_true", help="List every skill, not only stale ones.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 1 if any stale skill is version-pinned. Off by default; do not wire into pre-commit/CI.",
    )
    return parser.parse_args(argv)


def skill_files(root: Path) -> list[Path]:
    return sorted(root.glob("skills/*/SKILL.md")) + sorted(root.glob("skills/*/*/SKILL.md"))


def git_last_commit_date(root: Path, path: Path) -> str | None:
    proc = subprocess.run(
        ["git", "log", "-1", "--format=%as", "--", str(path.relative_to(root))],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if proc.returncode != 0:
        return None
    date = proc.stdout.strip()
    return date or None


def reviewed_date(root: Path, path: Path, text: str) -> tuple[str, str]:
    marker = LAST_VERIFIED_RE.search(text)
    if marker:
        return marker.group(1), "marker"
    git_date = git_last_commit_date(root, path)
    if git_date:
        return git_date, "git"
    mtime = dt.date.fromtimestamp(path.stat().st_mtime)
    return mtime.isoformat(), "fs"


def version_pins(text: str) -> list[str]:
    pins: list[str] = []
    seen: set[str] = set()
    for match in VERSION_PIN_RE.finditer(text):
        pin = f"{match.group(1)} {match.group(2)}"
        key = pin.lower()
        if key not in seen:
            seen.add(key)
            pins.append(pin)
    return pins


def audit(root: Path, today: dt.date) -> list[SkillFreshness]:
    results: list[SkillFreshness] = []
    for path in skill_files(root):
        text = path.read_text(encoding="utf-8")
        date_str, source = reviewed_date(root, path, text)
        try:
            reviewed = dt.date.fromisoformat(date_str)
        except ValueError:
            reviewed = today
            source = "invalid-marker"
        results.append(
            SkillFreshness(
                path=path.relative_to(root).as_posix(),
                reviewed_on=reviewed.isoformat(),
                source=source,
                age_days=(today - reviewed).days,
                version_pins=version_pins(text),
            )
        )
    return results


def report(results: list[SkillFreshness], *, max_age_days: int, show_all: bool, json_output: bool) -> int:
    stale = sorted(
        (r for r in results if r.age_days > max_age_days),
        key=lambda r: (-r.age_days, r.path),
    )
    stale_pinned = [r for r in stale if r.version_pins]
    if json_output:
        payload = {
            "audited": len(results),
            "max_age_days": max_age_days,
            "stale_count": len(stale),
            "stale_version_pinned_count": len(stale_pinned),
            "skills": [r.__dict__ for r in (results if show_all else stale)],
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return len(stale_pinned)

    print(
        f"skills freshness audit: {len(results)} skills audited; "
        f"{len(stale)} stale (> {max_age_days} days), {len(stale_pinned)} of them version-pinned"
    )
    rows = sorted(results, key=lambda r: (-r.age_days, r.path)) if show_all else stale
    if rows:
        print()
        print(f"{'AGE(d)':>6}  {'REVIEWED':<10}  {'SRC':<6}  PATH  [version pins]")
        for r in rows:
            pins = f"  [{', '.join(r.version_pins[:4])}]" if r.version_pins else ""
            print(f"{r.age_days:>6}  {r.reviewed_on:<10}  {r.source:<6}  {r.path}{pins}")
        print()
        print("Review priority: version-pinned rows first (verify against current versions,")
        print("then update content or add a `Last-verified: YYYY-MM-DD` line near the top).")
    return len(stale_pinned)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    if not (root / "skills").is_dir():
        print(f"no skills/ directory under root: {root}", file=sys.stderr)
        return 2
    results = audit(root, dt.date.today())
    stale_pinned_count = report(
        results, max_age_days=args.max_age_days, show_all=args.all, json_output=args.json
    )
    if args.strict and stale_pinned_count:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
