"""
M7 — flaky_integration.py
動態算 flaky_likelihood（跑 N 次）並整合進 batch_report。

設計：
- 預設額外跑 2 次（總共 3 次：原 M3 算 1 次 + 額外 2 次）
- 跑完用 flaky_check.analyze_runs 算 flaky_likelihood
- 寫回 batch_report.json 為 `flaky_measured` 欄位
- 對比 Jev 算的 flaky_likelihood（`flaky_likelihood`）vs 動態算的（`flaky_measured`）
- 若差異大 → 標 `⚠️` 在 overall_health（用 `overall_health_probs` 改）

用法：
    .venv/bin/python flaky_integration.py \
        --batch-report /tmp/US-M62-batch.json \
        --runs 2 \
        --journey journeys/US-M62.yaml \
        --story-id US-M62 \
        --source docs/ac/US-M62.md
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

from flaky_check import RunRecord, analyze_runs


def _run_journey(journey_yaml: Path, output_json: Path, source_md: Path | None) -> RunRecord:
    """跑 1 次 journey，回傳 RunRecord。"""
    t0 = time.perf_counter()
    cmd = [
        str(THIS_DIR / ".venv/bin/python"),
        str(THIS_DIR / "run_journey.py"),
        str(journey_yaml),
        "--json-output", str(output_json),
    ]
    if source_md and source_md.exists():
        cmd += ["--source", str(source_md)]
    p = subprocess.run(cmd, cwd=THIS_DIR, capture_output=True, text=True, check=False)
    if p.returncode != 0 and not output_json.exists():
        raise RuntimeError(f"run_journey failed: rc={p.returncode} stderr={p.stderr[:300]}")
    wall = int((time.perf_counter() - t0) * 1000)
    j = json.loads(output_json.read_text(encoding="utf-8"))
    counts: dict[str, int] = {"pass": 0, "fail": 0, "blocked": 0}
    for r in j.get("records", []):
        if r.get("blocked"):
            counts["blocked"] += 1
        elif r.get("oracle"):
            counts[r["oracle"]["verdict"]] += 1
        else:
            counts["fail"] += 1
    return RunRecord(
        run_id=output_json.stem,
        verdict_counts=counts,
        total_steps=len(j.get("records", [])),
        blocked=j.get("blocked", False),
        wall_time_ms=wall,
    )


def integrate_flaky(
    *,
    batch_report_path: Path,
    journey_yaml: Path,
    story_id: str,
    source_md: Path | None = None,
    extra_runs: int = 2,
) -> dict:
    """
    額外跑 N 次，動態算 flaky_likelihood，整合進 batch_report。

    Returns: {
        flaky_measured: float,
        flaky_classification: str,
        jev_flaky: float,
        delta: float,
        warning: bool,
    }
    """
    if not batch_report_path.exists():
        raise FileNotFoundError(f"batch_report not found: {batch_report_path}")

    batch = json.loads(batch_report_path.read_text(encoding="utf-8"))
    jev_flaky = batch.get("batch_report", {}).get("flaky_likelihood", 0.0)

    # 額外跑 N 次
    extra_records: list[RunRecord] = []
    with tempfile.TemporaryDirectory(prefix=f"flaky-int-{story_id}-") as tmpdir:
        tmp = Path(tmpdir)
        for i in range(1, extra_runs + 1):
            run_json = tmp / f"extra-{i}.json"
            print(f"   flaky run #{i}/{extra_runs} …", file=sys.stderr)
            rec = _run_journey(journey_yaml, run_json, source_md)
            extra_records.append(rec)

    if not extra_records:
        # 即使沒跑，也寫回 jev flaky_likelihood 作為 flaky_measured（保持 schema 一致）
        br = batch.setdefault("batch_report", {})
        br["flaky_measured"] = {
            "likelihood": jev_flaky,
            "classification": "no_dynamic_data",
            "jev_flaky_likelihood": jev_flaky,
            "delta": 0.0,
            "warning": False,
            "sample_count": 0,
        }
        batch_report_path.write_text(json.dumps(batch, ensure_ascii=False, indent=2), encoding="utf-8")
        return {
            "flaky_measured": jev_flaky,
            "flaky_classification": "no_dynamic_data",
            "jev_flaky": jev_flaky,
            "delta": 0.0,
            "warning": False,
        }

    report = analyze_runs(extra_records)
    measured = report.flaky_likelihood
    delta = abs(measured - jev_flaky)
    # 動態算 ≥ 0.20 → 標警告
    warning = report.classification in ("highly_flaky",)

    # 寫回 batch_report
    br = batch.setdefault("batch_report", {})
    br["flaky_measured"] = {
        "likelihood": measured,
        "classification": report.classification,
        "jev_flaky_likelihood": jev_flaky,
        "delta": round(delta, 4),
        "warning": warning,
        "sample_count": len(extra_records),
    }
    # 高度 flaky → overall_health_probs 加 warning 標記（向後相容：保留原 probs）
    if warning and br.get("overall_health_probs"):
        # 在 probs 上加 warning flag；UI 可選用
        br.setdefault("flaky_warning", True)
        br["overall_health"] = br.get("overall_health", "yellow")  # 降一級：red → yellow
        # 簡單降級：red→yellow if currently red
        if br.get("overall_health") == "red":
            br["overall_health"] = "yellow"

    batch_report_path.write_text(json.dumps(batch, ensure_ascii=False, indent=2), encoding="utf-8")

    return {
        "flaky_measured": measured,
        "flaky_classification": report.classification,
        "jev_flaky": jev_flaky,
        "delta": round(delta, 4),
        "warning": warning,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="M7 flaky 整合進 batch_report")
    parser.add_argument("--batch-report", type=Path, required=True)
    parser.add_argument("--journey", type=Path, required=True)
    parser.add_argument("--story-id", required=True)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--runs", type=int, default=2, help="額外跑幾次 (default 2)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv[1:])

    result = integrate_flaky(
        batch_report_path=args.batch_report,
        journey_yaml=args.journey,
        story_id=args.story_id,
        source_md=args.source,
        extra_runs=args.runs,
    )

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        emoji = {"stable": "🟢", "mildly_flaky": "🟡", "highly_flaky": "🔴"}.get(
            result["flaky_classification"], "?"
        )
        warn = "⚠️" if result["warning"] else ""
        print(
            f"{emoji} flaky_measured={result['flaky_measured']} "
            f"(jev={result['jev_flaky']}, delta={result['delta']}) "
            f"{result['flaky_classification']} {warn}"
        )

    return 0 if not result["warning"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
