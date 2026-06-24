#!/usr/bin/env python3
"""Read-only documentation consistency checker for Tree Monstor.

Validates the navigation invariants established by the documentation cleanup:
- docs/00-index.md covers top-level docs/*.md
- skills/README.md covers immediate skills/*/SKILL.md
- active docs have Status markers and Related docs footers
- stale path/count references do not reappear
- local markdown links and concrete backticked repo paths resolve
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from urllib.parse import unquote, urlparse


@dataclass(frozen=True)
class Issue:
    check: str
    path: str
    line: int | None
    message: str

    def format(self) -> str:
        loc = self.path if self.line is None else f"{self.path}:{self.line}"
        return f"[{self.check}] {loc} {self.message}"


CORE_FILES = ["README.md", "SOUL.md", "AGENTS.md", "MEMORY.md", "setup-macos.md"]
ADAPTER_FILES = [
    "adapters/claude-code/agent.md",
    "adapters/codex/system-prompt.md",
    "adapters/hermes/README.md",
]
CATALOG_FILES = ["skills/README.md"]

STALE_PATHS = {
    "docs/taskboard.md": "docs/task-board.md",
}

STALE_COUNT_PATTERNS = [
    re.compile(r"\b\d+\s*(?:個\s*)?專業角色\b", re.I),
    re.compile(r"Subagent\s*角色(?:矩陣|系統)?[（(]\s*\d+\s*個", re.I),
    re.compile(r"\b\d+[- ]role\b", re.I),
    re.compile(r"\b\d+\s+roles?\b", re.I),
    re.compile(r"\bSkills?\s*\(\s*\d+\s+total\s*\)", re.I),
    re.compile(r"\b\d+\s+skills?\b", re.I),
    re.compile(r"\b\d+\s*個\s*skills?\b", re.I),
    re.compile(r"\b\d+\s*個\s*skill\b", re.I),
    re.compile(r"行數目標"),
]

COUNT_SCOPE = [
    "README.md",
    "SOUL.md",
    "AGENTS.md",
    "MEMORY.md",
    "docs/00-index.md",
    "skills/README.md",
]

# These are downstream-project artifact examples, placeholders, or historical references.
ALLOW_MISSING_PATH_PATTERNS = [
    re.compile(r"^docs/PROJECT-OVERVIEW\.md$"),
    re.compile(r"^docs/progress\.md$"),
    re.compile(r"^docs/_meta/"),
    re.compile(r"^docs/incident-20260619-gateway-conflict\.md$"),
    re.compile(r"^skills/.+\.backup-"),
    re.compile(r"^docs/PRD\.md$"),
    re.compile(r"^docs/DESIGN\.md$"),
    re.compile(r"^docs/API\.md$"),
    re.compile(r"^docs/TEST-COVERAGE\.md$"),
    re.compile(r"^docs/TECH-DEBT\.md$"),
    re.compile(r"^docs/QA-TRACKER\.md$"),
    re.compile(r"^docs/REGRESSION-GUARD\.md$"),
    re.compile(r"^docs/PROJECT-OVERVIEW\.md$"),
    re.compile(r"^docs/ceo-.*\.md$"),
    re.compile(r"^docs/prd\.md$"),
    re.compile(r"^docs/design\.md$"),
    re.compile(r"^docs/architecture\.md$"),
    re.compile(r"^docs/api\.md$"),
    re.compile(r"^docs/tech-debt\.md$"),
    re.compile(r"^docs/sprint-.*\.md$"),
    re.compile(r"^docs/context-summary\.md$"),
    re.compile(r"^docs/checkpoint\.md$"),  # may be project-local checkpoint, not this profile doc
    re.compile(r"^docs/architecture/"),
    re.compile(r"^docs/retros/"),
    re.compile(r"^docs/archive/"),
    re.compile(r"^adapters/hermes/gateway\.yaml$"),  # historical reference in Hermes adapter docs
]

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
BACKTICK_PATH_RE = re.compile(
    r"`((?:(?:docs|skills|adapters|scripts)/[^`\s,;:)]+)|(?:README|SOUL|AGENTS|MEMORY)\.md)`"
)
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check Tree Monstor docs consistency.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--quiet", action="store_true", help="Only print failures.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text.")
    return parser.parse_args(argv)


def rel(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_fenced_code_blocks(text: str) -> str:
    lines: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if FENCE_RE.match(line):
            in_fence = not in_fence
            lines.append("")
            continue
        lines.append("" if in_fence else line)
    return "\n".join(lines)


def active_markdown_files(root: Path) -> list[Path]:
    files = [root / p for p in CORE_FILES + ADAPTER_FILES + CATALOG_FILES]
    docs_dir = root / "docs"
    if docs_dir.exists():
        files.extend(sorted(docs_dir.glob("*.md")))
    # Keep only existing files and de-duplicate while preserving order.
    seen: set[Path] = set()
    result: list[Path] = []
    for path in files:
        if path.exists() and path not in seen:
            seen.add(path)
            result.append(path)
    return result


def has_status_marker(path: Path) -> bool:
    lines = read_text(path).splitlines()[:25]
    return any(re.match(r"^\s*>\s*\*\*Status:\*\*", line) for line in lines)


def has_related_docs(path: Path) -> bool:
    return any(re.match(r"^\s*##\s+Related docs\s*$", line) for line in read_text(path).splitlines())


def normalize_target(current_file: Path, target: str) -> Path | None:
    target = unquote(target.strip())
    if not target:
        return None
    parsed = urlparse(target)
    if parsed.scheme or target.startswith("#") or target.startswith("mailto:"):
        return None
    target = target.split("#", 1)[0].split("?", 1)[0]
    if not target:
        return None
    if target.startswith("~") or target.startswith("/"):
        return None
    return (current_file.parent / target).resolve()


def markdown_links(path: Path) -> list[tuple[int, str]]:
    clean = strip_fenced_code_blocks(read_text(path))
    links: list[tuple[int, str]] = []
    for line_no, line in enumerate(clean.splitlines(), start=1):
        for match in LINK_RE.finditer(line):
            links.append((line_no, match.group(1)))
    return links


def docs_links_in_index(root: Path) -> set[str]:
    index = root / "docs" / "00-index.md"
    found: set[str] = set()
    if not index.exists():
        return found
    for _, target in markdown_links(index):
        resolved = normalize_target(index, target)
        if resolved is None:
            continue
        try:
            repo_rel = resolved.relative_to(root.resolve()).as_posix()
        except ValueError:
            continue
        if re.match(r"^docs/[^/]+\.md$", repo_rel):
            found.add(repo_rel)
    text = strip_fenced_code_blocks(read_text(index))
    for match in re.finditer(r"`(docs/[^/`]+\.md)`", text):
        candidate = match.group(1)
        if "*" not in candidate:
            found.add(candidate)
    return found


def skills_links_in_catalog(root: Path) -> set[str]:
    catalog = root / "skills" / "README.md"
    found: set[str] = set()
    if not catalog.exists():
        return found
    for _, target in markdown_links(catalog):
        resolved = normalize_target(catalog, target)
        if resolved is None:
            continue
        try:
            repo_rel = resolved.relative_to(root.resolve()).as_posix()
        except ValueError:
            continue
        if re.match(r"^skills/[^/]+/SKILL\.md$", repo_rel):
            found.add(repo_rel)
    return found


def check_required_files(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in CORE_FILES[:-1] + ["docs/00-index.md", "skills/README.md"]:
        full = root / path
        if not full.exists():
            issues.append(Issue("required-files", path, None, "required file is missing"))
    return issues


def check_docs_index(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    index_rel = "docs/00-index.md"
    index = root / index_rel
    if not index.exists():
        return [Issue("docs-index", index_rel, None, "docs index is missing")]
    actual = {rel(root, p) for p in sorted((root / "docs").glob("*.md"))}
    listed = docs_links_in_index(root)
    for missing in sorted(actual - listed):
        issues.append(Issue("docs-index", index_rel, None, f"does not list {missing}"))
    for stale in sorted(listed - actual):
        issues.append(Issue("docs-index", index_rel, None, f"lists missing {stale}"))
    return issues


def check_skills_catalog(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    catalog_rel = "skills/README.md"
    catalog = root / catalog_rel
    if not catalog.exists():
        return [Issue("skills-catalog", catalog_rel, None, "skills catalog is missing")]
    actual = {rel(root, p) for p in sorted((root / "skills").glob("*/SKILL.md"))}
    listed = skills_links_in_catalog(root)
    for missing in sorted(actual - listed):
        issues.append(Issue("skills-catalog", catalog_rel, None, f"does not list {missing}"))
    for stale in sorted(listed - actual):
        issues.append(Issue("skills-catalog", catalog_rel, None, f"lists missing {stale}"))
    return issues


def check_doc_markers(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_markdown_files(root):
        path_rel = rel(root, path)
        if not has_status_marker(path):
            issues.append(Issue("doc-markers", path_rel, None, "missing top-of-file Status marker"))
        if not has_related_docs(path):
            issues.append(Issue("doc-markers", path_rel, None, 'missing "## Related docs" section'))
    return issues


def check_stale_refs(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_markdown_files(root):
        path_rel = rel(root, path)
        text = read_text(path)
        for line_no, line in enumerate(text.splitlines(), start=1):
            for stale, replacement in STALE_PATHS.items():
                if stale in line:
                    issues.append(
                        Issue("stale-refs", path_rel, line_no, f"references stale path {stale}; use {replacement}")
                    )
    for path_rel in COUNT_SCOPE:
        path = root / path_rel
        if not path.exists():
            continue
        for line_no, line in enumerate(read_text(path).splitlines(), start=1):
            for pattern in STALE_COUNT_PATTERNS:
                if pattern.search(line):
                    issues.append(
                        Issue("stale-refs", path_rel, line_no, "has hard-coded dynamic role/skill count; link canonical source instead")
                    )
                    break
    return issues


def should_skip_missing_path(repo_rel: str) -> bool:
    if any(token in repo_rel for token in ("<", ">", "[", "]", "*", "YYYY", "...")):
        return True
    return any(pattern.search(repo_rel) for pattern in ALLOW_MISSING_PATH_PATTERNS)


def is_existing_case_sensitive(root: Path, target: Path) -> bool:
    try:
        repo_rel = target.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return target.exists()
    current = root.resolve()
    for part in Path(repo_rel).parts:
        if not current.exists() or not current.is_dir():
            return False
        names = {child.name for child in current.iterdir()}
        if part not in names:
            return False
        current = current / part
    return current.exists()


def check_target(root: Path, current_file: Path, target: str, line_no: int, check_name: str) -> Issue | None:
    resolved = normalize_target(current_file, target)
    if resolved is None:
        return None
    try:
        repo_rel = resolved.relative_to(root.resolve()).as_posix()
    except ValueError:
        return None
    if should_skip_missing_path(repo_rel):
        return None
    if not is_existing_case_sensitive(root, resolved):
        return Issue(check_name, rel(root, current_file), line_no, f"local target missing or wrong case: {target}")
    return None


def backticked_paths(path: Path) -> list[tuple[int, str]]:
    clean = strip_fenced_code_blocks(read_text(path))
    refs: list[tuple[int, str]] = []
    for line_no, line in enumerate(clean.splitlines(), start=1):
        for match in BACKTICK_PATH_RE.finditer(line):
            refs.append((line_no, match.group(1)))
    return refs


def check_local_links_and_paths(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_markdown_files(root):
        for line_no, target in markdown_links(path):
            issue = check_target(root, path, target, line_no, "local-links")
            if issue is not None:
                issues.append(issue)
        for line_no, target in backticked_paths(path):
            if target in STALE_PATHS:
                continue  # stale-ref check gives a clearer message
            issue = check_target(root, root / "_repo_root_.md", target, line_no, "local-paths")
            if issue is not None:
                # Use the source file path, not the synthetic root file.
                issues.append(Issue(issue.check, rel(root, path), line_no, issue.message))
    return issues


def report(issues: list[Issue], *, json_output: bool, quiet: bool) -> None:
    if json_output:
        print(json.dumps({"ok": not issues, "issue_count": len(issues), "issues": [asdict(i) for i in issues]}, ensure_ascii=False, indent=2))
        return
    if not issues:
        if not quiet:
            print("docs consistency check passed")
        return
    print(f"docs consistency check failed: {len(issues)} issue(s)")
    for issue in issues:
        print(issue.format())


def run(root: Path) -> list[Issue]:
    checks = [
        check_required_files,
        check_docs_index,
        check_skills_catalog,
        check_doc_markers,
        check_stale_refs,
        check_local_links_and_paths,
    ]
    issues: list[Issue] = []
    for check in checks:
        issues.extend(check(root))
    return issues


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    if not root.exists() or not root.is_dir():
        print(f"invalid root: {root}", file=sys.stderr)
        return 2
    issues = run(root)
    report(issues, json_output=args.json, quiet=args.quiet)
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
