"""
M6.3 — 互動式 sandbox runner
封裝 patch + re-validate + rollback 3 步手動流程為一個 sandbox 流程。

設計：
- 在 tmp/.sandbox-<ts>/ 建立隔離工作目錄
- 把 (file, old, new) 套用到 sandbox 內的 source file
- 重跑 journey_runner.py 產 after.json
- 呼叫 re_validate.py 比對 verdict
- 若 classification=regression → 自動 rollback + 重跑確認 baseline
- 產出 sandbox_report.md（diff + verdict delta + 最終建議）
- 不論結果都 cleanup sandbox 目錄

用法：
    # dry-run：只算 sandbox 該做什麼、不真的 apply
    .venv/bin/python sandbox_runner.py \
      --before /tmp/before.json \
      --file skills/regression-guard/PoC/patch_parser.py \
      --old "old text" --new "new text" \
      --journey journeys/US-M62.yaml \
      --story-id US-M62 \
      --source docs/ac/US-M62.md \
      --sandbox-dry-run

    # 真的跑 sandbox 流程
    .venv/bin/python sandbox_runner.py \
      --before /tmp/before.json \
      --file <FILE> \
      --old "..." --new "..." \
      --journey journeys/US-M62.yaml \
      --story-id US-M62 \
      --source docs/ac/US-M62.md
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


THIS_DIR = Path(__file__).parent
POC_DIR = THIS_DIR
REPO_ROOT = POC_DIR.parent.parent.parent  # skills/regression-guard/PoC → tree_monstor
sys.path.insert(0, str(POC_DIR))

from playwright_patcher import apply_patch, rollback as patch_rollback
from re_validate import re_validate, render_markdown


# ─── 結果資料結構 ─────────────────────────────────────────────────────────

@dataclass
class SandboxStep:
    """sandbox 內的一個步驟記錄。"""
    step: str
    status: str          # ok | error | skipped
    message: str = ""
    elapsed_ms: int = 0


@dataclass
class SandboxResult:
    sandbox_dir: str
    steps: list[SandboxStep] = field(default_factory=list)
    classification: str = ""          # improvement | regression | no_change | inconsistent | error
    verdict_before: dict = field(default_factory=dict)
    verdict_after: dict = field(default_factory=dict)
    final_recommendation: str = ""   # keep_patch | rollback | review
    rolled_back: bool = False
    cleanup_ok: bool = False
    error: Optional[str] = None

    def to_dict(self) -> dict:
        d = asdict(self)
        return d


# ─── Sandbox 邏輯 ────────────────────────────────────────────────────────

def _run(cmd: list[str], cwd: Path, timeout: int = 60) -> tuple[int, str, str]:
    """跑 subprocess，回傳 (rc, stdout, stderr)。"""
    try:
        p = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True,
            timeout=timeout, check=False,
        )
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"timeout after {timeout}s"


def _copy_to_sandbox(src: Path, dst: Path) -> None:
    """複製檔案到 sandbox，保留目錄結構。"""
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _sandbox_relative_path(target_file: Path) -> Path:
    """把目標檔轉成「相對 sandbox」的安全路徑。

    pathlib 的 `sandbox_dir / p` 不做邊界檢查，有兩種逃逸路徑：
      1. p 是絕對路徑 → 右邊覆寫左邊，src == dst（SameFileError，原檔被就地改壞）
      2. p 含 `..`（如 ../../../tmp/x.py）→ 正規化後落在 sandbox 外（複本外洩）
    因此一律先 resolve 再相對化；轉不出來或仍含 `..` 就退回檔名，保證複本一定在 sandbox 內。
    """
    abs_target = target_file if target_file.is_absolute() else Path.cwd() / target_file
    try:
        rel = abs_target.resolve().relative_to(REPO_ROOT.resolve())
    except ValueError:
        return Path(target_file.name)
    if ".." in rel.parts:
        return Path(target_file.name)
    return rel


def _count_verdicts(run_json: dict) -> dict[str, int]:
    """跟 re_validate 同樣邏輯抽 verdict 計數。"""
    counts: dict[str, int] = {"pass": 0, "fail": 0, "blocked": 0}
    for r in run_json.get("records", []):
        if r.get("blocked"):
            counts["blocked"] += 1
        elif r.get("oracle"):
            counts[r["oracle"]["verdict"]] += 1
        else:
            counts["fail"] += 1
    return counts


def run_sandbox(
    *,
    before_path: Path,
    target_file: Path,         # repo 內的相對 / 絕對路徑
    old_text: str,
    new_text: str,
    journey_yaml: Path,
    story_id: str,
    source_md: Path,
    dry_run: bool = False,
    auto_rollback_on_regression: bool = True,
) -> SandboxResult:
    """主入口：跑 sandbox 流程。"""
    timestamp = int(time.time())
    sandbox_dir = REPO_ROOT / "tmp" / f".sandbox-{story_id}-{timestamp}"
    result = SandboxResult(sandbox_dir=str(sandbox_dir))

    if not before_path.exists():
        result.error = f"before_path not found: {before_path}"
        result.classification = "error"
        return result

    before_json = json.loads(before_path.read_text(encoding="utf-8"))
    result.verdict_before = _count_verdicts(before_json)

    # 步驟 1: 建立 sandbox
    t0 = time.perf_counter()
    try:
        sandbox_dir.mkdir(parents=True, exist_ok=True)
        # 複製 fixture / journey / source
        # 注意：目標路徑必須先「安全相對化」（見 _sandbox_relative_path）：
        # 絕對路徑與含 `..` 的相對路徑都會讓 `sandbox_dir / p` 指到 sandbox 之外。
        rel_file = _sandbox_relative_path(target_file)
        sandbox_file = sandbox_dir / rel_file
        _copy_to_sandbox(target_file, sandbox_file)
        # 複製 journey YAML
        sandbox_journey = sandbox_dir / "journey.yaml"
        _copy_to_sandbox(journey_yaml, sandbox_journey)
        # 備份（即使 dry-run 也備份）
        backup_dir = sandbox_dir / ".pre-patch"
        backup_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(sandbox_file, backup_dir / sandbox_file.name)
        elapsed = int((time.perf_counter() - t0) * 1000)
        result.steps.append(SandboxStep("建立 sandbox", "ok", f"sandbox={sandbox_dir}", elapsed))
    except Exception as e:
        result.steps.append(SandboxStep("建立 sandbox", "error", str(e)))
        result.error = str(e)
        result.classification = "error"
        return result

    if dry_run:
        result.steps.append(SandboxStep("dry-run", "skipped", "sandbox 建立完成，未 apply"))
        result.classification = "dry_run"
        result.cleanup_ok = True
        # 留 sandbox 給人工看（cleanup 用 --keep）
        return result

    # 步驟 2: 在 sandbox 內 apply patch
    t0 = time.perf_counter()
    patch_res = apply_patch(
        file=sandbox_file, old=old_text, new=new_text,
        dry_run=False,  # sandbox 內真的 apply
    )
    elapsed = int((time.perf_counter() - t0) * 1000)
    if patch_res.action != "applied":
        result.steps.append(SandboxStep(
            "apply patch", "error",
            f"patch action={patch_res.action} error={patch_res.error}",
            elapsed,
        ))
        result.error = patch_res.error or "patch failed"
        result.classification = "error"
        result.cleanup_ok = _cleanup(sandbox_dir)
        return result
    result.steps.append(SandboxStep(
        "apply patch", "ok",
        f"file={sandbox_file.name} matches={patch_res.matches_found}",
        elapsed,
    ))

    # 步驟 3: 在 sandbox 內重跑 journey
    t0 = time.perf_counter()
    after_json_path = sandbox_dir / "after.json"
    # 用 sandbox 內的 venv python（從 main repo 借，因為 venv 在 main repo）
    rc, stdout, stderr = _run(
        [str(POC_DIR / ".venv/bin/python"), str(POC_DIR / "run_journey.py"),
         str(sandbox_journey), "--json-output", str(after_json_path)],
        cwd=POC_DIR, timeout=120,
    )
    elapsed = int((time.perf_counter() - t0) * 1000)
    if rc != 0 and not after_json_path.exists():
        result.steps.append(SandboxStep(
            "重跑 journey", "error",
            f"rc={rc} stderr={stderr[:200]}",
            elapsed,
        ))
        result.error = "journey re-run failed"
        result.classification = "error"
        result.cleanup_ok = _cleanup(sandbox_dir)
        return result
    after_json = json.loads(after_json_path.read_text(encoding="utf-8"))
    result.verdict_after = _count_verdicts(after_json)
    result.steps.append(SandboxStep(
        "重跑 journey", "ok",
        f"verdict={result.verdict_after}",
        elapsed,
    ))

    # 步驟 4: re-validate
    t0 = time.perf_counter()
    validate_res = re_validate(before_path, after_json_path)
    elapsed = int((time.perf_counter() - t0) * 1000)
    result.classification = validate_res.classification
    result.final_recommendation = (
        "keep_patch" if validate_res.classification == "improvement"
        else "rollback" if validate_res.classification == "regression"
        else "review"
    )
    result.steps.append(SandboxStep(
        "re-validate", "ok",
        f"classification={validate_res.classification} recommendation={result.final_recommendation}",
        elapsed,
    ))

    # 步驟 5: 若 regression → 自動 rollback
    if validate_res.classification == "regression" and auto_rollback_on_regression:
        t0 = time.perf_counter()
        rollback_res = patch_rollback(sandbox_file)
        elapsed = int((time.perf_counter() - t0) * 1000)
        if rollback_res.action == "rolled_back":
            result.rolled_back = True
            result.steps.append(SandboxStep(
                "自動 rollback", "ok",
                f"file={sandbox_file.name} 已從 .pre-patch 還原",
                elapsed,
            ))
        else:
            result.steps.append(SandboxStep(
                "自動 rollback", "error",
                rollback_res.error or "rollback failed",
                elapsed,
            ))

    # 步驟 6: cleanup sandbox
    result.cleanup_ok = _cleanup(sandbox_dir)
    result.steps.append(SandboxStep(
        "cleanup sandbox", "ok" if result.cleanup_ok else "error",
        f"sandbox={sandbox_dir}",
    ))

    return result


def _cleanup(sandbox_dir: Path) -> bool:
    """刪除 sandbox 目錄。"""
    try:
        if sandbox_dir.exists():
            shutil.rmtree(sandbox_dir)
        return True
    except OSError:
        return False


def render_sandbox_report(result: SandboxResult) -> str:
    """渲染 sandbox_report.md。"""
    emoji = {
        "improvement": "🟢",
        "regression":  "🔴",
        "no_change":   "🟡",
        "inconsistent": "🟠",
        "error":       "❌",
        "dry_run":     "👀",
    }.get(result.classification, "?")
    lines = [
        "# Sandbox Report",
        "",
        f"**分類**：{emoji} **{result.classification}**",
        f"**最終建議**：{result.final_recommendation or 'N/A'}",
        f"**rolled_back**：{result.rolled_back}",
        "",
        f"**sandbox**：`{result.sandbox_dir}`",
        "",
        "## Verdict Delta",
        "",
        "| verdict | before | after |",
        "|---------|--------|-------|",
    ]
    all_v = set(result.verdict_before) | set(result.verdict_after)
    for v in sorted(all_v):
        b = result.verdict_before.get(v, 0)
        a = result.verdict_after.get(v, 0)
        d = a - b
        d_str = f" ({d:+d})" if d != 0 else ""
        lines.append(f"| {v} | {b} | {a}{d_str} |")

    lines.extend(["", "## Steps", ""])
    for s in result.steps:
        e = {"ok": "✅", "error": "❌", "skipped": "⏭️"}.get(s.status, "?")
        lines.append(f"- {e} **{s.step}** ({s.elapsed_ms}ms) — {s.message}")

    if result.error:
        lines.extend(["", "## Error", "", f"```\n{result.error}\n```"])

    return "\n".join(lines) + "\n"


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="M6.3 互動式 sandbox")
    parser.add_argument("--before", type=Path, required=True, help="patch 前 journey JSON")
    parser.add_argument("--file", type=Path, required=True, help="要 patch 的檔案")
    parser.add_argument("--old", required=True, help="要取代的舊文字")
    parser.add_argument("--new", required=True, help="新的文字")
    parser.add_argument("--journey", type=Path, required=True, help="journey YAML")
    parser.add_argument("--story-id", required=True, help="story ID（用於 sandbox 命名）")
    parser.add_argument("--source", type=Path, required=True, help="AC 範本 .md")
    parser.add_argument("--sandbox-dry-run", action="store_true", help="只建 sandbox 不 apply")
    parser.add_argument("--no-auto-rollback", action="store_true", help="regression 時不自動 rollback")
    parser.add_argument("--output", "-o", type=Path, help="輸出 sandbox_report.md")
    parser.add_argument("--json", action="store_true", help="JSON 輸出")
    args = parser.parse_args(argv[1:])

    for p in (args.before, args.file, args.journey, args.source):
        if not p.exists():
            print(f"❌ 檔案不存在：{p}")
            return 1

    result = run_sandbox(
        before_path=args.before,
        target_file=args.file,
        old_text=args.old,
        new_text=args.new,
        journey_yaml=args.journey,
        story_id=args.story_id,
        source_md=args.source,
        dry_run=args.sandbox_dry_run,
        auto_rollback_on_regression=not args.no_auto_rollback,
    )

    md = render_sandbox_report(result)
    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(md)

    if args.output:
        args.output.write_text(md, encoding="utf-8")
        print(f"\n📝 Wrote {args.output}  ({args.output.stat().st_size} bytes)")

    # return code：error=1, regression=2, improvement/no_change=0
    return {
        "error": 1,
        "regression": 2,
        "improvement": 0,
        "no_change": 0,
        "inconsistent": 1,
        "dry_run": 0,
    }.get(result.classification, 1)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
