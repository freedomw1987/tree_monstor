#!/usr/bin/env python3
"""Read-only documentation consistency checker for Tree Monstor.

Validates the navigation invariants established by the documentation cleanup:
- docs/00-index.md covers top-level docs/*.md
- skills/README.md covers immediate skills/*/SKILL.md
- skills/README.md's generated section covers nested skills/*/*/SKILL.md and is fresh
- active docs have Status markers and Related docs footers
- stale path/count references do not reappear
- red lines 54-56 full definitions appear only in SOUL.md
- no git-tracked or stale root-level backup files
- local markdown links and concrete backticked repo paths resolve
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
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


CORE_FILES = ["README.md", "CLAUDE.md", "SOUL.md", "AGENTS.md", "MEMORY.md"]
ADAPTER_FILES = [
    "adapters/claude-code/agent.md",
    "adapters/codex/system-prompt.md",
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
    re.compile(r"^docs/VERIFY\.md$"),
    re.compile(r"^docs/verify-log(/|$)"),
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
    parser.add_argument("--project-docs", action="store_true", help="Check downstream project documentation baseline and PRD/QA tracker sync.")
    parser.add_argument("--base-ref", help="Base git ref for diff-based doc-code sync checks.")
    parser.add_argument("--doc-code-sync", action="store_true", help="Require changed code to update corresponding project docs. Requires --base-ref.")
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


def skills_links_in_catalog(root: Path, pattern: str = r"^skills/[^/]+/SKILL\.md$") -> set[str]:
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
        if re.match(pattern, repo_rel):
            found.add(repo_rel)
    return found


def check_required_files(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in CORE_FILES + ["docs/00-index.md", "skills/README.md"]:
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


def check_nested_skills_catalog(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    catalog_rel = "skills/README.md"
    if not (root / catalog_rel).exists():
        return []  # check_skills_catalog already reports the missing catalog
    actual = {rel(root, p) for p in sorted((root / "skills").glob("*/*/SKILL.md"))}
    listed = skills_links_in_catalog(root, pattern=r"^skills/[^/]+/[^/]+/SKILL\.md$")
    for missing in sorted(actual - listed):
        issues.append(Issue("nested-skills-catalog", catalog_rel, None, f"does not list {missing}"))
    for stale in sorted(listed - actual):
        issues.append(Issue("nested-skills-catalog", catalog_rel, None, f"lists missing {stale}"))
    if not actual:
        return issues
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from generate_skills_catalog import apply as regenerate_catalog

        current, updated = regenerate_catalog(root)
        if current != updated:
            issues.append(
                Issue(
                    "nested-skills-catalog",
                    catalog_rel,
                    None,
                    "generated section is stale; run python3 scripts/generate_skills_catalog.py",
                )
            )
    except SystemExit as exc:
        issues.append(Issue("nested-skills-catalog", catalog_rel, None, str(exc)))
    except ImportError:
        issues.append(
            Issue("nested-skills-catalog", "scripts/generate_skills_catalog.py", None, "generator script is missing")
        )
    finally:
        sys.path.remove(str(Path(__file__).resolve().parent))
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


# Red lines 54-56 full definitions live only in SOUL.md. Other files may
# reference them (紅線 54-56, （紅線 55）, checklist rows) but must not restate
# the definition (`**紅線 5X / <name>**:` form) or the old README table rows.
REDLINE_FULLTEXT_PATTERNS = [
    re.compile(r"紅線\s*5[456]\s*/"),
    re.compile(r"\*\*5[456]\s+(?:先重現|實證驗證|先讀後寫)\*\*"),
]
BACKUP_STALE_DAYS = 30


def check_redline_single_source(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_markdown_files(root):
        path_rel = rel(root, path)
        if path_rel == "SOUL.md":
            continue
        clean = strip_fenced_code_blocks(read_text(path))
        for line_no, line in enumerate(clean.splitlines(), start=1):
            if any(pattern.search(line) for pattern in REDLINE_FULLTEXT_PATTERNS):
                issues.append(
                    Issue(
                        "redline-single-source",
                        path_rel,
                        line_no,
                        "restates red line 54-56 definition; SOUL.md is the only full-text source — link it instead",
                    )
                )
    return issues


def check_stale_backups(root: Path) -> list[Issue]:
    import time

    issues: list[Issue] = []
    proc = subprocess.run(
        ["git", "ls-files", "*.backup*", "*.bak", "*.bak-*"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if proc.returncode == 0:
        for tracked in [line.strip() for line in proc.stdout.splitlines() if line.strip()]:
            issues.append(
                Issue("stale-backups", tracked, None, "backup file is git-tracked; .gitignore bans backups — untrack it")
            )
    cutoff = time.time() - BACKUP_STALE_DAYS * 86400
    for candidate in sorted(root.glob("*.backup*")) + sorted(root.glob("*.bak*")):
        if candidate.is_file() and candidate.stat().st_mtime < cutoff:
            issues.append(
                Issue(
                    "stale-backups",
                    rel(root, candidate),
                    None,
                    f"root-level backup older than {BACKUP_STALE_DAYS} days; archive or delete (git history keeps it)",
                )
            )
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



US_ID_RE = re.compile(r"\bUS-\d+(?:\.\d+)?\b")
PROJECT_REQUIRED_DOCS = [
    "docs/PROJECT-OVERVIEW.md",
    "docs/PRD.md",
    "docs/DESIGN.md",
    "docs/API.md",
    "docs/QA-TRACKER.md",
    "docs/TEST-COVERAGE.md",
    "docs/TECH-DEBT.md",
    "docs/VERIFY.md",
]
PROJECT_DOC_PATHS = set(PROJECT_REQUIRED_DOCS) | {
    "docs/REGRESSION-GUARD.md",
}
PROJECT_DOC_PREFIXES = (
    "docs/architecture/",
    "docs/retros/",
)
CODE_EXTENSIONS = {
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".py", ".go", ".rs", ".java", ".kt", ".swift",
    ".php", ".rb", ".cs", ".css", ".scss", ".vue", ".svelte",
}
DEPENDENCY_FILES = {
    "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock", "bun.lockb",
    "requirements.txt", "pyproject.toml", "poetry.lock", "Pipfile", "Pipfile.lock",
    "Gemfile", "Gemfile.lock", "go.mod", "go.sum", "Cargo.toml", "Cargo.lock",
    "composer.json", "composer.lock",
}
API_PATH_HINTS = ("/api/", "/routes/", "/controllers/", "/endpoints/")
API_NAME_HINTS = ("route", "routes", "controller", "controllers", "endpoint", "endpoints")


def extract_us_ids(text: str) -> set[str]:
    return set(US_ID_RE.findall(strip_fenced_code_blocks(text)))


def active_tracker_us_ids(text: str) -> set[str]:
    ids: set[str] = set()
    for line in strip_fenced_code_blocks(text).splitlines():
        if "DEPRECATED" in line.upper():
            continue
        ids.update(US_ID_RE.findall(line))
    return ids


def has_na_marker(path: Path) -> bool:
    if not path.exists():
        return False
    text = read_text(path).lower()
    return "n/a" in text or "not applicable" in text or "無 api" in text or "無 ui" in text


def check_project_docs_baseline(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path_rel in PROJECT_REQUIRED_DOCS:
        path = root / path_rel
        if not path.exists():
            issues.append(Issue("project-docs", path_rel, None, "required project documentation baseline file is missing"))
    architecture_dir = root / "docs" / "architecture"
    adr_files = sorted(architecture_dir.glob("*.md")) if architecture_dir.exists() else []
    if not adr_files:
        issues.append(Issue("project-docs", "docs/architecture", None, "at least one ADR / architecture baseline file is required"))

    prd = root / "docs" / "PRD.md"
    if prd.exists() and not extract_us_ids(read_text(prd)):
        issues.append(Issue("project-docs", "docs/PRD.md", None, "PRD must contain at least one US-* user story"))

    overview = root / "docs" / "PROJECT-OVERVIEW.md"
    if overview.exists():
        text = read_text(overview)
        for section in ("## 一句話", "## 目標用戶", "## 成功標準", "## 範圍"):
            if section not in text:
                issues.append(Issue("project-docs", "docs/PROJECT-OVERVIEW.md", None, f"missing required section: {section}"))

    design = root / "docs" / "DESIGN.md"
    if design.exists() and "## Overview" not in read_text(design) and not has_na_marker(design):
        issues.append(Issue("project-docs", "docs/DESIGN.md", None, "DESIGN must include ## Overview or an explicit N/A marker"))

    api = root / "docs" / "API.md"
    if api.exists() and "## Endpoints" not in read_text(api) and not has_na_marker(api):
        issues.append(Issue("project-docs", "docs/API.md", None, "API must include ## Endpoints or an explicit N/A marker"))

    tracker = root / "docs" / "QA-TRACKER.md"
    if tracker.exists() and "## User Story → Test Task 對照" not in read_text(tracker):
        issues.append(Issue("project-docs", "docs/QA-TRACKER.md", None, "QA tracker must include User Story → Test Task 對照 section"))

    coverage = root / "docs" / "TEST-COVERAGE.md"
    if coverage.exists() and "## User Story → Test Case 對照" not in read_text(coverage):
        issues.append(Issue("project-docs", "docs/TEST-COVERAGE.md", None, "test coverage must include User Story → Test Case 對照 section"))

    verify = root / "docs" / "VERIFY.md"
    if verify.exists():
        verify_text = read_text(verify)
        if "## Verification commands" not in verify_text:
            issues.append(Issue("project-docs", "docs/VERIFY.md", None, "VERIFY must include ## Verification commands section"))
        elif "`" not in verify_text and not has_na_marker(verify):
            issues.append(Issue("project-docs", "docs/VERIFY.md", None, "VERIFY must contain at least one backticked command or an explicit N/A marker"))

    return issues


def check_prd_tracker_sync(root: Path) -> list[Issue]:
    prd = root / "docs" / "PRD.md"
    tracker = root / "docs" / "QA-TRACKER.md"
    if not prd.exists() or not tracker.exists():
        return []
    prd_ids = extract_us_ids(read_text(prd))
    tracker_ids = active_tracker_us_ids(read_text(tracker))
    issues: list[Issue] = []
    for missing in sorted(prd_ids - tracker_ids):
        issues.append(Issue("prd-tracker-sync", "docs/QA-TRACKER.md", None, f"missing active tracker row for {missing} from PRD"))
    for stale in sorted(tracker_ids - prd_ids):
        issues.append(Issue("prd-tracker-sync", "docs/QA-TRACKER.md", None, f"has active {stale} not present in PRD; mark DEPRECATED or update PRD"))
    return issues


def changed_files_since_base(root: Path, base_ref: str) -> tuple[list[str], list[Issue]]:
    try:
        proc = subprocess.run(
            ["git", "diff", "--name-only", f"{base_ref}...HEAD"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        return [], [Issue("doc-code-sync", ".", None, f"failed to run git diff: {exc}")]
    if proc.returncode != 0:
        return [], [Issue("doc-code-sync", ".", None, f"git diff failed for base ref {base_ref}: {proc.stderr.strip()}")]
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()], []


def changed_diff_since_base(root: Path, base_ref: str) -> tuple[str, list[Issue]]:
    try:
        proc = subprocess.run(
            ["git", "diff", "--unified=0", f"{base_ref}...HEAD"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        return "", [Issue("doc-code-sync", ".", None, f"failed to run git diff: {exc}")]
    if proc.returncode != 0:
        return "", [Issue("doc-code-sync", ".", None, f"git diff failed for base ref {base_ref}: {proc.stderr.strip()}")]
    return proc.stdout, []


def is_project_doc(path: str) -> bool:
    return path in PROJECT_DOC_PATHS or any(path.startswith(prefix) for prefix in PROJECT_DOC_PREFIXES)


def is_code_path(path: str) -> bool:
    if path.startswith(("docs/", "skills/", "adapters/")):
        return False
    suffix = Path(path).suffix
    if suffix in CODE_EXTENSIONS:
        return True
    return path in DEPENDENCY_FILES or Path(path).name in DEPENDENCY_FILES


def is_dependency_path(path: str) -> bool:
    return path in DEPENDENCY_FILES or Path(path).name in DEPENDENCY_FILES


def is_api_path(path: str) -> bool:
    lower = path.lower()
    if any(hint in lower for hint in API_PATH_HINTS):
        return True
    stem = Path(lower).stem
    return any(hint in stem for hint in API_NAME_HINTS)



REGRESSION_ID_RE = re.compile(r"\bRG-\d+\b")
QA_ENDPOINT_RE = re.compile(r"/__qa(?:/[A-Za-z0-9_:{}/.?=&-]*)?", re.I)
REGRESSION_TERMS_RE = re.compile(r"/__qa|REGRESSION_MODE|Regression Hook|Regression Mode|regression hook|regression mode", re.I)
REGRESSION_CODE_MARKER_RE = re.compile(r"REGRESSION_MODE|x-regression|seedRegression|qa:seed|qa:reset", re.I)
REGRESSION_SAFETY_RE = re.compile(r"production|dev/test/staging|dev.*test.*staging|staging|env guard|NODE_ENV|APP_ENV|N/A|not applicable", re.I)
QA_ENDPOINT_REQUIRED_TERMS = {
    "production boundary": re.compile(r"production|生產|not mounted|404|403|hard reject|NODE_ENV", re.I),
    "auth / access control": re.compile(r"auth|secret|SSO|allowlist|allow-list|IP|權限|驗證", re.I),
    "test data scope": re.compile(r"test tenant|test DB|test database|test schema|sandbox|測試租戶|測試 DB|測試 schema", re.I),
    "audit logging": re.compile(r"audit|審計", re.I),
    "idempotency": re.compile(r"idempotent|idempotency|safe to rerun|可重跑", re.I),
    "US/RG mapping": re.compile(r"\b(?:US|RG)-\d+\b"),
    "test command / QA enablement": re.compile(r"test:regression|qa:seed|qa:reset|test command|QA enablement|測試命令", re.I),
}
COVERAGE_QA_REQUIRED_TERMS = {
    "production safety": re.compile(r"production|not mounted|404|403|hard reject|Production safety|生產", re.I),
    "test command / QA enablement": re.compile(r"test:regression|qa:seed|qa:reset|Test command|QA enablement", re.I),
}
RG_QA_REQUIRED_FIELDS = (
    "Frontend hook",
    "Backend hook",
    "QA enablement",
    "Seed/reset data",
    "Test command",
    "Expected result",
    "Safety boundary",
    "Production exposure check",
)
UNSAFE_REGRESSION_WORDING = [
    re.compile(r"disable\s+rate\s+limit", re.I),
    re.compile(r"disableRateLimit", re.I),
    re.compile(r"disable[_-]?auth", re.I),
    re.compile(r"disable[_-]?audit", re.I),
    re.compile(r"disable[_-]?permission", re.I),
    re.compile(r"turn\s+off\s+auth", re.I),
    re.compile(r"skip\s+permission", re.I),
    re.compile(r"skipAuth", re.I),
    re.compile(r"skip[_-]?validation", re.I),
    re.compile(r"bypass\s+security", re.I),
    re.compile(r"bypass\s+auth", re.I),
    re.compile(r"bypassPermission", re.I),
    re.compile(r"bypass[_-]?permission", re.I),
    re.compile(r"rateLimit\s*=\s*false", re.I),
    re.compile(r"auth\s*=\s*false", re.I),
    re.compile(r"permission\s*=\s*false", re.I),
    re.compile(r"without\s+auth", re.I),
    re.compile(r"no\s+auth\s+required", re.I),
    re.compile(r"ignore\s+RBAC", re.I),
    re.compile(r"hardcoded\s+admin\s+token", re.I),
    re.compile(r"x-regression-mode.*(?:authority|permission|auth|權限|驗證)", re.I),
    re.compile(r"跳過.*(?:auth|permission|權限|驗證|validation)", re.I),
    re.compile(r"繞過.*(?:auth|permission|權限|驗證|security|安全)", re.I),
    re.compile(r"關閉.*(?:rate limit|限流|audit|審計)", re.I),
    re.compile(r"禁用.*(?:rate limit|限流|audit|審計)", re.I),
]
UNSAFE_ALLOWED_MARKERS = (
    "禁止", "forbidden", "anti-pattern", "anti pattern", "❌", "不要", "不可以", "不可", "唔好", "ng:",
    "blocked", "merge blocker", "must not", "never", "嚴禁", "不准"
)


def project_markdown_files(root: Path) -> list[Path]:
    docs = root / "docs"
    if not docs.exists():
        return []
    return sorted(docs.rglob("*.md"))


def is_allowed_unsafe_wording(line: str) -> bool:
    lower = line.lower()
    return any(marker in lower or marker in line for marker in UNSAFE_ALLOWED_MARKERS)


def check_required_terms(text: str, required: dict[str, re.Pattern[str]], path_rel: str, check_name: str, subject: str) -> list[Issue]:
    issues: list[Issue] = []
    for label, pattern in required.items():
        if not pattern.search(text):
            issues.append(Issue(check_name, path_rel, None, f"{subject} is missing {label}"))
    return issues


def check_regression_docs(root: Path) -> list[Issue]:
    issues: list[Issue] = []
    tracker = root / "docs" / "QA-TRACKER.md"
    if tracker.exists():
        tracker_text = read_text(tracker)
        if "Regression Hook" not in tracker_text and "Regression Mode" not in tracker_text:
            issues.append(Issue("regression-docs", "docs/QA-TRACKER.md", None, "QA tracker must include Regression Hook or Regression Mode columns"))

    coverage = root / "docs" / "TEST-COVERAGE.md"
    coverage_text = read_text(coverage) if coverage.exists() else ""
    if coverage.exists():
        if "## Regression Mode / Hooks" not in coverage_text:
            issues.append(Issue("regression-docs", "docs/TEST-COVERAGE.md", None, "test coverage must include ## Regression Mode / Hooks section"))
        if QA_ENDPOINT_RE.search(coverage_text):
            issues.extend(check_required_terms(coverage_text, COVERAGE_QA_REQUIRED_TERMS, "docs/TEST-COVERAGE.md", "regression-endpoint-policy", "TEST-COVERAGE.md /__qa coverage"))

    api = root / "docs" / "API.md"
    api_text = read_text(api) if api.exists() else ""
    if api.exists() and QA_ENDPOINT_RE.search(api_text):
        if "QA / Regression Endpoints" not in api_text and "Regression Endpoints" not in api_text:
            issues.append(Issue("regression-endpoint-policy", "docs/API.md", None, "docs/API.md mentions /__qa but lacks a QA / Regression Endpoints section"))
        issues.extend(check_required_terms(api_text, QA_ENDPOINT_REQUIRED_TERMS, "docs/API.md", "regression-endpoint-policy", "docs/API.md /__qa endpoint policy"))

    guard = root / "docs" / "REGRESSION-GUARD.md"
    if guard.exists():
        guard_text = read_text(guard)
        if REGRESSION_ID_RE.search(guard_text):
            if "QA Regression Mode" not in guard_text:
                issues.append(Issue("regression-docs", "docs/REGRESSION-GUARD.md", None, "RG entries must include a QA Regression Mode section"))
            for field in RG_QA_REQUIRED_FIELDS:
                if field not in guard_text:
                    issues.append(Issue("regression-docs", "docs/REGRESSION-GUARD.md", None, f"RG entries must include {field}"))

    safety_sensitive = {
        "docs/API.md",
        "docs/DESIGN.md",
        "docs/TEST-COVERAGE.md",
        "docs/REGRESSION-GUARD.md",
    }
    for path in project_markdown_files(root):
        path_rel = rel(root, path)
        text = read_text(path)
        if path_rel in safety_sensitive and REGRESSION_TERMS_RE.search(text) and not REGRESSION_SAFETY_RE.search(text):
            issues.append(Issue("regression-docs", path_rel, None, "mentions regression hooks/mode but does not mention production/dev-test-staging safety boundary"))
        for line_no, line in enumerate(text.splitlines(), start=1):
            if any(pattern.search(line) for pattern in UNSAFE_REGRESSION_WORDING) and not is_allowed_unsafe_wording(line):
                issues.append(Issue("regression-docs", path_rel, line_no, "unsafe regression wording must be marked as forbidden/anti-pattern, not guidance"))
    return issues

def check_doc_code_sync(root: Path, changed: list[str], diff_text: str = "") -> list[Issue]:
    issues: list[Issue] = []
    changed_set = set(changed)
    changed_docs = {path for path in changed if is_project_doc(path)}
    changed_code = [path for path in changed if is_code_path(path)]

    if "docs/PRD.md" in changed_set and "docs/QA-TRACKER.md" not in changed_set:
        issues.append(Issue("doc-code-sync", "docs/QA-TRACKER.md", None, "docs/PRD.md changed but docs/QA-TRACKER.md did not change"))

    if changed_code and not changed_docs:
        issues.append(Issue("doc-code-sync", ".", None, "code changed but no project documentation file changed"))

    if changed_code and not any(path.startswith("docs/verify-log/") for path in changed_set):
        issues.append(
            Issue(
                "doc-code-sync",
                "docs/verify-log",
                None,
                "code changed but no verification log was added (docs/verify-log/YYYY-MM-DD-<task>.txt with commands, real output, exit code)",
            )
        )

    api_changes = [path for path in changed_code if is_api_path(path)]
    if api_changes and "docs/API.md" not in changed_set:
        issues.append(Issue("doc-code-sync", "docs/API.md", None, f"API-looking code changed but docs/API.md did not change: {', '.join(api_changes[:5])}"))

    dep_changes = [path for path in changed if is_dependency_path(path)]
    if dep_changes and "docs/TECH-DEBT.md" not in changed_set:
        issues.append(Issue("doc-code-sync", "docs/TECH-DEBT.md", None, f"dependency files changed but docs/TECH-DEBT.md did not change: {', '.join(dep_changes[:5])}"))

    if changed_code and diff_text:
        added_lines = "\n".join(line[1:] for line in diff_text.splitlines() if line.startswith("+") and not line.startswith("+++"))
        if QA_ENDPOINT_RE.search(added_lines):
            for required_doc in ("docs/API.md", "docs/TEST-COVERAGE.md", "docs/QA-TRACKER.md"):
                if required_doc not in changed_set:
                    issues.append(Issue("doc-code-sync", required_doc, None, f"/__qa appears in changed code but {required_doc} did not change"))
            if REGRESSION_ID_RE.search(added_lines) and "docs/REGRESSION-GUARD.md" not in changed_set:
                issues.append(Issue("doc-code-sync", "docs/REGRESSION-GUARD.md", None, "/__qa and RG-* appear in changed code but docs/REGRESSION-GUARD.md did not change"))
        if REGRESSION_CODE_MARKER_RE.search(added_lines):
            for required_doc in ("docs/TEST-COVERAGE.md", "docs/QA-TRACKER.md"):
                if required_doc not in changed_set:
                    issues.append(Issue("doc-code-sync", required_doc, None, "regression mode marker appears in changed code but regression docs did not change"))
        if REGRESSION_ID_RE.search(added_lines):
            for required_doc in ("docs/REGRESSION-GUARD.md", "docs/TEST-COVERAGE.md"):
                if required_doc not in changed_set:
                    issues.append(Issue("doc-code-sync", required_doc, None, "RG-* marker appears in changed code but regression guard/test coverage docs did not change"))

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


def run(root: Path, *, project_docs: bool = False, base_ref: str | None = None, doc_code_sync: bool = False) -> list[Issue]:
    profile_checks = [
        check_required_files,
        check_docs_index,
        check_skills_catalog,
        check_nested_skills_catalog,
        check_doc_markers,
        check_stale_refs,
        check_redline_single_source,
        check_stale_backups,
        check_local_links_and_paths,
    ]
    project_checks = [
        check_project_docs_baseline,
        check_prd_tracker_sync,
        check_regression_docs,
        check_local_links_and_paths,
    ]
    checks = project_checks if project_docs else profile_checks
    issues: list[Issue] = []
    for check in checks:
        issues.extend(check(root))
    if doc_code_sync:
        if not base_ref:
            issues.append(Issue("doc-code-sync", ".", None, "--doc-code-sync requires --base-ref"))
        else:
            changed, diff_issues = changed_files_since_base(root, base_ref)
            issues.extend(diff_issues)
            if not diff_issues:
                diff_text, diff_text_issues = changed_diff_since_base(root, base_ref)
                issues.extend(diff_text_issues)
                issues.extend(check_doc_code_sync(root, changed, diff_text))
    return issues


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    if not root.exists() or not root.is_dir():
        print(f"invalid root: {root}", file=sys.stderr)
        return 2
    issues = run(root, project_docs=args.project_docs, base_ref=args.base_ref, doc_code_sync=args.doc_code_sync)
    report(issues, json_output=args.json, quiet=args.quiet)
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
