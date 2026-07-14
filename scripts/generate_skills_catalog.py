#!/usr/bin/env python3
"""Generate the nested-skills section of skills/README.md.

The top-level catalog tables in skills/README.md stay hand-curated.
This script owns only the block between the BEGIN/END markers below,
listing every skills/<category>/<skill>/SKILL.md with its frontmatter
description so nested skills stay discoverable without manual upkeep.

Usage:
  python3 scripts/generate_skills_catalog.py           # rewrite the block
  python3 scripts/generate_skills_catalog.py --check   # exit 1 if stale
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BEGIN_MARKER = "<!-- BEGIN GENERATED: nested-skills-catalog (scripts/generate_skills_catalog.py) -->"
END_MARKER = "<!-- END GENERATED: nested-skills-catalog -->"
DESCRIPTION_LIMIT = 160

FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)
DESCRIPTION_KEY_RE = re.compile(r"^description:\s*(.*)$", re.M)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate nested skills catalog section.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true", help="Exit 1 if the generated section is stale; do not write.")
    return parser.parse_args(argv)


def skill_description(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8")
    frontmatter = FRONTMATTER_RE.match(text)
    description = ""
    if frontmatter:
        match = DESCRIPTION_KEY_RE.search(frontmatter.group(1))
        if match:
            description = match.group(1).strip().strip("\"'")
    if not description:
        body = FRONTMATTER_RE.sub("", text)
        for line in body.splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                description = stripped
                break
    description = re.sub(r"\s+", " ", description)
    if len(description) > DESCRIPTION_LIMIT:
        description = description[: DESCRIPTION_LIMIT - 1].rstrip() + "…"
    return description.replace("|", "\\|") or "(no description)"


def nested_skills(root: Path) -> dict[str, list[Path]]:
    by_category: dict[str, list[Path]] = {}
    for skill_md in sorted((root / "skills").glob("*/*/SKILL.md")):
        by_category.setdefault(skill_md.parent.parent.name, []).append(skill_md)
    return by_category


def category_intro(root: Path, category: str) -> str:
    description_md = root / "skills" / category / "DESCRIPTION.md"
    if not description_md.exists():
        return ""
    match = DESCRIPTION_KEY_RE.search(description_md.read_text(encoding="utf-8"))
    if not match:
        return ""
    return match.group(1).strip().strip("\"'")


def render_section(root: Path) -> str:
    lines = [
        BEGIN_MARKER,
        "",
        "## Nested skills by category（自動生成）",
        "",
        "> 本段由 `scripts/generate_skills_catalog.py` 生成，**不要手改**；"
        "新增 / 刪除嵌套技能後重跑該腳本。每個技能的 canonical source 仍是其 `SKILL.md`。",
        "",
    ]
    for category, skills in nested_skills(root).items():
        lines.append(f"### `{category}/`")
        intro = category_intro(root, category)
        if intro:
            lines.extend(["", intro])
        lines.extend(["", "| Skill | Description |", "|-------|-------------|"])
        for skill_md in skills:
            rel = skill_md.relative_to(root / "skills").as_posix()
            name = skill_md.parent.name
            lines.append(f"| [`{name}`]({rel}) | {skill_description(skill_md)} |")
        lines.append("")
    lines.append(END_MARKER)
    return "\n".join(lines)


def apply(root: Path) -> tuple[str, str]:
    catalog = root / "skills" / "README.md"
    current = catalog.read_text(encoding="utf-8")
    begin = current.find(BEGIN_MARKER)
    end = current.find(END_MARKER)
    if begin == -1 or end == -1 or end < begin:
        raise SystemExit(
            f"markers not found in {catalog}: add {BEGIN_MARKER!r} and {END_MARKER!r} where the section belongs"
        )
    updated = current[:begin] + render_section(root) + current[end + len(END_MARKER):]
    return current, updated


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    current, updated = apply(root)
    catalog = root / "skills" / "README.md"
    if current == updated:
        print("nested skills catalog is up to date")
        return 0
    if args.check:
        print("nested skills catalog is stale: run python3 scripts/generate_skills_catalog.py", file=sys.stderr)
        return 1
    catalog.write_text(updated, encoding="utf-8")
    print(f"regenerated nested skills catalog in {catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
