"""
M6.2 AC02 — Patch Applier (playwright_patcher.py)
接 (file, old, new) 三元組 → apply patch 到 source file（dry-run / 真的 apply）。

設計：
- dry-run：產 unified diff 報告 + 自動備份到 .bak
- apply：真的改 source file（先用 backup 守住），回傳新內容
- safety：
  - old_text 不存在 → abort
  - old_text 多處 match → abort（拒絕靜默套用）
  - 自動備份到 <file>.bak
- scope 控制：不自動 commit；只留報告

用法：
    .venv/bin/python playwright_patcher.py <file> --old "..." --new "..." [--apply]
    或 import：
        from playwright_patcher import apply_patch
        result = apply_patch(file=Path("x.py"), old="...", new="...", dry_run=True)
"""

from __future__ import annotations

import argparse
import difflib
import json
import shutil
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


@dataclass
class PatchResult:
    file: str
    action: str            # "applied" | "dry_run" | "aborted"
    diff: str              # unified diff 格式
    backup_path: Optional[str] = None
    matches_found: int = 0
    error: Optional[str] = None
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)


def _make_diff(file_path: Path, old_content: str, new_content: str) -> str:
    """產 unified diff 字串。"""
    diff = difflib.unified_diff(
        old_content.splitlines(keepends=True),
        new_content.splitlines(keepends=True),
        fromfile=f"a/{file_path.name}",
        tofile=f"b/{file_path.name}",
        n=3,
    )
    return "".join(diff)


def apply_patch(
    *,
    file: Path,
    old: str,
    new: str,
    dry_run: bool = True,
    backup_suffix: str = ".bak",
) -> PatchResult:
    """主入口：套用 patch。

    safety：
    - file 不存在 → aborted
    - old 是空字串 → describe_only 模式（沒 old 不能 patch，只回 diff 報告）
    - old 不存在於 file → aborted
    - old 出現 > 1 次 → aborted（拒絕靜默套用）
    - 自動備份（即使 dry-run 也備份以便比對）
    """
    result = PatchResult(file=str(file), action="dry_run", diff="")

    if not file.exists():
        result.action = "aborted"
        result.error = f"file not found: {file}"
        return result

    original = file.read_text(encoding="utf-8")

    # describe_only 模式（無 old）
    if not old:
        if not new:
            result.action = "aborted"
            result.error = "old 和 new 都為空，無 patch 可做"
            return result
        # 只能產 diff 報告，無法套用
        result.action = "describe_only"
        result.diff = (
            f"⚠️  describe_only mode: parser 沒抽到 old_text（描述型 patch）\n"
            f"   file: {file}\n"
            f"   proposed new content:\n{new[:500]}{'...' if len(new) > 500 else ''}\n"
        )
        result.notes.append("describe_only：人工 review 檔案後手動改")
        return result

    # 計算 old 出現次數
    matches = original.count(old)
    result.matches_found = matches
    if matches == 0:
        result.action = "aborted"
        result.error = f"old_text not found in {file}"
        return result
    if matches > 1:
        result.action = "aborted"
        result.error = f"old_text appears {matches} times in {file}; refusing to silently patch (請改用更精確的 old_text)"
        return result

    # 計算 new content
    new_content = original.replace(old, new, 1)
    result.diff = _make_diff(file, original, new_content)

    # 自動備份
    backup = file.with_suffix(file.suffix + backup_suffix)
    if not backup.exists():
        shutil.copy2(file, backup)
        result.backup_path = str(backup)
    else:
        result.notes.append(f"backup 已存在：{backup}（不覆蓋）")
        result.backup_path = str(backup)

    if dry_run:
        result.action = "dry_run"
        return result

    # 真的 apply
    file.write_text(new_content, encoding="utf-8")
    result.action = "applied"
    return result


def rollback(file: Path, backup_suffix: str = ".bak") -> PatchResult:
    """從 .bak 還原 file。"""
    result = PatchResult(file=str(file), action="rolled_back", diff="")
    backup = file.with_suffix(file.suffix + backup_suffix)
    if not backup.exists():
        result.error = f"no backup found: {backup}"
        result.action = "aborted"
        return result
    shutil.copy2(backup, file)
    result.backup_path = str(backup)
    result.notes.append(f"從 {backup} 還原 {file}")
    return result


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="M6.2 Patch Applier")
    parser.add_argument("file", type=Path, help="要 patch 的檔案路徑")
    parser.add_argument("--old", help="要取代的舊文字（rollback 模式可省略）")
    parser.add_argument("--new", help="新的文字（rollback 模式可省略）")
    parser.add_argument("--apply", action="store_true", help="真的 apply（預設 dry-run）")
    parser.add_argument("--rollback", action="store_true", help="從 .bak 還原")
    parser.add_argument("--json", action="store_true", help="JSON 輸出")
    args = parser.parse_args(argv[1:])

    if args.rollback:
        result = rollback(args.file)
    elif not args.old or not args.new:
        print("❌ --old 和 --new 必填（rollback 模式除外）")
        parser.print_help()
        return 2
    else:
        result = apply_patch(
            file=args.file,
            old=args.old,
            new=args.new,
            dry_run=not args.apply,
        )

    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        action_emoji = {
            "applied": "✅",
            "dry_run": "👀",
            "aborted": "❌",
            "describe_only": "📝",
            "rolled_back": "⏪",
        }.get(result.action, "?")
        print(f"{action_emoji} action: {result.action}")
        print(f"   file:         {result.file}")
        print(f"   matches:      {result.matches_found}")
        if result.backup_path:
            print(f"   backup:       {result.backup_path}")
        if result.error:
            print(f"   error:        {result.error}")
        if result.diff:
            print()
            print(result.diff)
        if result.notes:
            print()
            for n in result.notes:
                print(f"   note: {n}")

    # 0=applied, 1=dry_run, 2=aborted, 3=describe_only, 4=rolled_back
    return {
        "applied": 0,
        "dry_run": 0,  # dry-run 不算錯誤
        "aborted": 1,
        "describe_only": 0,
        "rolled_back": 0,
    }.get(result.action, 1)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
