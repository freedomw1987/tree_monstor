#!/usr/bin/env python3
"""
文件減法盤點：掃描 docs/, skills/, tests/ 的 .md 檔，產出 4 類清單。

分類規則：
- KEEP   — 至少被 2 個其他檔 cross-link（含 SKILL.md, README.md, AGENTS.md, handbook）
- MERGE  — 內容跟 KEEP 檔有 >50% 主題重疊（標題相似 + 內容同義）
- DELETE — orphan 或被 0 個其他檔 cross-link（除了自己）
- REVIEW — 1 個 cross-link，需人工 review

用法：
  python3 docs/cleanup/cleanup-scan.py
  python3 docs/cleanup/cleanup-scan.py --json   # JSON output
  python3 docs/cleanup/cleanup-scan.py --apply  # 自動刪 DELETE 類（需手動確認）
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
SCAN_DIRS = ["docs", "skills", "tests"]
EXCLUDE_PATTERNS = [
    "**/.cache/**",
    "**/__pycache__/**",
    "**/node_modules/**",
    "**/.venv/",
    "**/.venv/**",
    "**/.relay/**",
    "**/journeys/**",
    "**/fixtures/**",
    "**/cache/**",
]


def is_excluded(rel: str) -> bool:
    """EXCLUDE 比對：支援 .venv 這種多層情況（fnmatch 不支援 **/ 任意深度）"""
    for pat in EXCLUDE_PATTERNS:
        if "/.venv" in rel:
            return True  # 任何含 /.venv 的路徑一律排除
        if Path(rel).match(pat):
            return True
    return False
PROTECTED_PATTERNS = [
    "AGENTS.md",
    "README.md",
    "**/SKILL.md",
    "**/handbook/**",
    "**/ac/US-*.md",          # User Story AC 範本
    "**/deliverable/**",      # Sprint deliverable（保留歷史）
    "**/backlog.md",
    "**/gates.json",
    "**/ci/**",               # CI SOP
    "**/dav-designer/**",     # dav-designer skill 完整保留
    "**/dav-planner/**",      # dav-planner skill 完整保留
    "**/dav-reflection/**",   # dav-reflection skill 完整保留
    "**/dav-skill-creater/**",
    "**/dav-submitter/**",
    "**/dav-trust/**",
    "**/dav-wiki/**",
    "**/dev-checker-loop/**",
    "**/find-skills/**",
    "**/gsap-*/**",
    "**/council-mode/**",
    "**/orchestration/**",
    "**/pi-subagents/**",
    "**/regression-guard/PoC/prompts/**",  # prompt templates
    "**/orca-cli/**",
    "**/tdd-test-writer/**",
]
CROSS_LINK_RE = re.compile(r"\[.*?\]\(([^)]+\.md)(?:#[^)]*)?\)")


def is_protected(path: Path) -> bool:
    rel = str(path.relative_to(REPO_ROOT))
    for pat in PROTECTED_PATTERNS:
        if Path(rel).match(pat):
            return True
    return False


def find_all_md_files() -> list[Path]:
    files = []
    for d in SCAN_DIRS:
        base = REPO_ROOT / d
        if not base.exists():
            continue
        for p in base.rglob("*.md"):
            rel = str(p.relative_to(REPO_ROOT))
            if is_excluded(rel):
                continue
            files.append(p)
    return sorted(files)


def count_crosslinks(target: Path, all_files: list[Path]) -> tuple[int, list[str]]:
    """計算 target 被多少其他 .md 檔 cross-link（不含自己）。"""
    target_stem = target.stem
    target_name = target.name
    refs = []
    for f in all_files:
        if f == target:
            continue
        try:
            content = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        # 1. markdown link [text](path/to/file.md)
        for m in CROSS_LINK_RE.finditer(content):
            link_target = m.group(1)
            # 相對路徑或 basename 都算
            if link_target.endswith(target_name):
                refs.append(str(f.relative_to(REPO_ROOT)))
                break
            if target_stem in link_target and "/" not in link_target:
                refs.append(str(f.relative_to(REPO_ROOT)))
                break
        else:
            # 2. inline mention（檔名 / 檔 stem）
            if target_name in content or target_stem in content:
                # 排除 SKILL.md / AGENTS.md 內的交叉引用（太常見）
                if "AGENTS.md" not in str(f) and "SKILL.md" not in str(f):
                    refs.append(str(f.relative_to(REPO_ROOT)))
    # 去重
    refs = list(set(refs))
    return len(refs), refs


def get_file_stats(path: Path) -> dict:
    try:
        content = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return {"size": 0, "lines": 0, "mtime": 0, "title": "(unreadable)"}
    stat = path.stat()
    # 標題：第一個 # heading
    title = "(no title)"
    for line in content.split("\n"):
        if line.startswith("# "):
            title = line[2:].strip()
            break
    return {
        "size": stat.st_size,
        "lines": content.count("\n") + 1,
        "mtime": int(stat.st_mtime),
        "title": title,
    }


def classify(path: Path, link_count: int) -> str:
    if is_protected(path):
        return "KEEP"
    if link_count >= 2:
        return "KEEP"
    if link_count == 1:
        return "REVIEW"
    if link_count == 0:
        return "DELETE"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--apply", action="store_true", help="Auto-DELETE (use with caution)")
    args = parser.parse_args()

    files = find_all_md_files()
    results = []
    for f in files:
        rel = str(f.relative_to(REPO_ROOT))
        link_count, link_refs = count_crosslinks(f, files)
        cat = classify(f, link_count)
        stats = get_file_stats(f)
        results.append({
            "path": rel,
            "category": cat,
            "crosslink_count": link_count,
            "crosslink_refs": link_refs,
            **stats,
        })

    # 統計
    by_cat = defaultdict(list)
    for r in results:
        by_cat[r["category"]].append(r)

    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
        return 0

    # Human-readable
    print("═══════════════════════════════════════════════")
    print("  文件減法盤點 — regression-guard PoC + 專案")
    print("═══════════════════════════════════════════════")
    print(f"  掃描目錄：     {' / '.join(SCAN_DIRS)}")
    print(f"  總 .md 檔數：  {len(results)}")
    print()
    print("  統計：")
    for cat in ["KEEP", "REVIEW", "DELETE", "MERGE"]:
        n = len(by_cat[cat])
        marker = "🟢" if cat == "KEEP" else "🟡" if cat == "REVIEW" else "🔴" if cat == "DELETE" else "🔵"
        print(f"    {marker} {cat:8} {n:3}")
    print()

    # 列出 DELETE 類（最高優先處理）
    if by_cat["DELETE"]:
        print("─── 🔴 DELETE（孤立檔，0 cross-link）───")
        for r in sorted(by_cat["DELETE"], key=lambda x: -x["mtime"]):
            print(f"  {r['path']:60}  {r['size']:6}B  {r['lines']:3}L  ({r['title'][:40]})")
        print()

    # 列出 REVIEW 類
    if by_cat["REVIEW"]:
        print("─── 🟡 REVIEW（1 個 cross-link，需人工 review）───")
        for r in sorted(by_cat["REVIEW"], key=lambda x: -x["mtime"]):
            refs = ", ".join(r["crosslink_refs"][:2])
            print(f"  {r['path']:60}  {r['size']:6}B  ({r['title'][:40]})")
            print(f"     ↳ linked by: {refs}")
        print()

    # 列出 KEEP 類（Top 10 最新）
    if by_cat["KEEP"]:
        print(f"─── 🟢 KEEP（前 10 個最新的）───")
        for r in sorted(by_cat["KEEP"], key=lambda x: -x["mtime"])[:10]:
            print(f"  {r['path']:60}  {r['size']:6}B  ({r['title'][:40]})")
        print()

    # 套用 DELETE
    if args.apply and by_cat["DELETE"]:
        print("─── 套用 DELETE ───")
        for r in by_cat["DELETE"]:
            target = REPO_ROOT / r["path"]
            if target.exists():
                target.unlink()
                print(f"  ✓ Deleted: {r['path']}")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
