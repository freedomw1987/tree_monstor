"""
Flaky 驗證：跑 N 次同一 journey，比 verdict 分布差異，識別 flaky test。

設計：
- 跑 5 次（default，可改）同一 journey + 同一 source
- 每次產 <run-id>.json
- 聚合所有 verdict，比 min/max/range/STD
- flaky_likelihood 公式：range / (max + 1)
  - 0 = 完全穩定
  - 接近 1 = 完全 flaky
- 產出 flaky_report.md

用法：
    .venv/bin/python flaky_check.py journeys/US-M62.yaml \
        --source docs/ac/US-M62.md \
        --runs 5
"""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))


@dataclass
class RunRecord:
    run_id: str
    verdict_counts: dict[str, int]
    total_steps: int
    blocked: bool
    wall_time_ms: int


@dataclass
class FlakyReport:
    story_id: str
    run_count: int
    runs: list[RunRecord]
    per_verdict_stats: dict[str, dict[str, float]]  # {verdict: {min, max, mean, stdev}}
    flaky_likelihood: float          # 0=stable, 1=fully flaky
    classification: str              # stable | mildly_flaky | highly_flaky
    error: Optional[str] = None

    def to_dict(self) -> dict:
        d = asdict(self)
        return d


def _run_journey(journey_yaml: Path, run_json: Path, source_md: Path) -> RunRecord:
    """跑一次 journey，回傳 RunRecord。"""
    t0 = time.perf_counter()
    cmd = [
        str(THIS_DIR / ".venv/bin/python"),
        str(THIS_DIR / "run_journey.py"),
        str(journey_yaml),
        "--json-output", str(run_json),
    ]
    if source_md.exists():
        cmd += ["--source", str(source_md)]
    p = subprocess.run(cmd, cwd=THIS_DIR, capture_output=True, text=True, check=False)
    if p.returncode != 0 and not run_json.exists():
        raise RuntimeError(f"run_journey failed: rc={p.returncode} stderr={p.stderr[:300]}")
    wall = int((time.perf_counter() - t0) * 1000)
    j = json.loads(run_json.read_text(encoding="utf-8"))
    counts: dict[str, int] = {"pass": 0, "fail": 0, "blocked": 0}
    for r in j.get("records", []):
        if r.get("blocked"):
            counts["blocked"] += 1
        elif r.get("oracle"):
            counts[r["oracle"]["verdict"]] += 1
        else:
            counts["fail"] += 1
    return RunRecord(
        run_id=run_json.stem.replace("-run-", "#"),
        verdict_counts=counts,
        total_steps=len(j.get("records", [])),
        blocked=j.get("blocked", False),
        wall_time_ms=wall,
    )


def analyze_runs(runs: list[RunRecord]) -> FlakyReport:
    """分析多次跑的 verdict 分布，計算 flaky_likelihood。"""
    all_v = sorted({v for run in runs for v in run.verdict_counts})
    stats: dict[str, dict[str, float]] = {}
    for v in all_v:
        series = [r.verdict_counts.get(v, 0) for r in runs]
        stats[v] = {
            "min": float(min(series)),
            "max": float(max(series)),
            "mean": float(statistics.mean(series)),
            "stdev": float(statistics.stdev(series) if len(series) > 1 else 0.0),
            "range": float(max(series) - min(series)),
        }

    # flaky_likelihood = 總 range 比例
    total_range = sum(s["range"] for s in stats.values())
    total_max = sum(s["max"] for s in stats.values())
    flaky = total_range / (total_max + 1)

    classification = (
        "stable" if flaky < 0.05
        else "mildly_flaky" if flaky < 0.20
        else "highly_flaky"
    )
    return FlakyReport(
        story_id="?",
        run_count=len(runs),
        runs=runs,
        per_verdict_stats=stats,
        flaky_likelihood=round(flaky, 4),
        classification=classification,
    )


def render_flaky_report(report: FlakyReport) -> str:
    """渲染 flaky_report.md。"""
    emoji = {
        "stable": "🟢",
        "mildly_flaky": "🟡",
        "highly_flaky": "🔴",
    }.get(report.classification, "?")
    lines = [
        "# Flaky Verification Report",
        "",
        f"**story**：`{report.story_id}`",
        f"**runs**：{report.run_count}",
        f"**分類**：{emoji} **{report.classification}**",
        f"**flaky_likelihood**：{report.flaky_likelihood}",
        "",
        "## Per-Verdict Stats",
        "",
        "| verdict | min | max | mean | stdev | range |",
        "|---------|-----|-----|------|-------|-------|",
    ]
    for v, s in sorted(report.per_verdict_stats.items()):
        lines.append(
            f"| {v} | {s['min']:.0f} | {s['max']:.0f} | {s['mean']:.2f} | {s['stdev']:.2f} | {s['range']:.0f} |"
        )
    lines.extend(["", "## Per-Run Detail", ""])
    for i, r in enumerate(report.runs, 1):
        lines.append(f"### Run #{i} ({r.run_id}) — {r.wall_time_ms}ms")
        for v, c in sorted(r.verdict_counts.items()):
            lines.append(f"- {v}: {c}")
        lines.append("")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Flaky 驗證：跑多次同一 journey 比 verdict 分布")
    parser.add_argument("journey", type=Path, help="journey YAML")
    parser.add_argument("--source", type=Path, help="AC 範本 .md")
    parser.add_argument("--story-id", type=str, required=True, help="story ID")
    parser.add_argument("--runs", type=int, default=5, help="跑幾次 (default 5)")
    parser.add_argument("--output", "-o", type=Path, help="輸出 report path")
    parser.add_argument("--json", action="store_true", help="JSON 輸出")
    args = parser.parse_args(argv[1:])

    if not args.journey.exists():
        print(f"❌ 檔案不存在：{args.journey}")
        return 1

    runs: list[RunRecord] = []
    out_dir = THIS_DIR / "tmp" / f"flaky-{args.story_id}"
    out_dir.mkdir(parents=True, exist_ok=True)
    for i in range(1, args.runs + 1):
        run_json = out_dir / f"run-{i}.json"
        print(f"▶ Run #{i}/{args.runs} …")
        rec = _run_journey(args.journey, run_json, args.source or Path("/dev/null"))
        runs.append(rec)

    report = analyze_runs(runs)
    report.story_id = args.story_id

    md = render_flaky_report(report)
    if args.json:
        print(json.dumps(report.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(md)

    if args.output:
        args.output.write_text(md, encoding="utf-8")
        print(f"\n📝 Wrote {args.output}  ({args.output.stat().st_size} bytes)")

    return 0 if report.classification == "stable" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
