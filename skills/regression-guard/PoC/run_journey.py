"""
Journey Runner CLI — 讀 YAML → 跑 dry-run loop → 印結果。

用法:
    .venv/bin/python run_journey.py journeys/US-101.yaml
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

import yaml

from ac_schema import parse_story_file
from journey_generator import Journey
from journey_runner import run_journey, StepRecord


def _load_journey(path: Path) -> Journey:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    # yaml → Journey dataclass
    from dataclasses import fields
    from journey_generator import Step as StepCls
    steps = [StepCls(**s) for s in raw.pop("steps", [])]
    raw["steps"] = steps
    j = Journey(**raw)
    return j


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: run_journey.py <path/to/journey.yaml> [--source AC.md] [--stale-test]")
        return 1
    journey_path = Path(argv[1])
    if not journey_path.exists():
        print(f"❌ Journey YAML 找不到：{journey_path}")
        return 1

    use_stale_test = "--stale-test" in argv
    json_output = None
    if "--json-output" in argv:
        idx = argv.index("--json-output")
        if idx + 1 < len(argv):
            json_output = Path(argv[idx + 1])
        else:
            print("❌ --json-output 需要接檔名")
            return 1

    # source 預設從 YAML 的 source 欄位推
    journey = _load_journey(journey_path)
    src_path = Path(journey.source)
    if not src_path.is_absolute():
        # journey.source 是相對於 repo root，repo root = 4 層往上
        # journeys/US-101.yaml 在 PoC/ 下，所以 source 的相對路徑是從 PoC 算的
        src_path = (THIS_DIR / src_path).resolve()
    if not src_path.exists():
        print(f"❌ source AC 檔找不到：{src_path}")
        return 1
    story = parse_story_file(src_path)

    print(f"📖 Journey: {journey.journey_id} 「{journey.title}」")
    print(f"   source: {src_path}")
    print(f"   steps:  {journey.total_steps}")
    print(f"   generated_by: {journey.generated_by} @ {journey.generated_at}")
    print()

    started = time.perf_counter()
    from journey_runner import run_dry
    records, summary = run_dry(journey, story.acs, stale_test=use_stale_test,
                                 story_id=journey.journey_id)
    if use_stale_test:
        print("⚙️  stale-test mode: 所有 step 強制回相同 ObservedState")
    elapsed = int((time.perf_counter() - started) * 1000)

    # 印每步
    for r in records:
        if r.oracle:
            v = r.oracle.verdict
            conf = r.oracle.confidence
            sev = r.oracle.severity
            bug = r.oracle.is_real_bug
            print(
                f"  {r.step_id:<24} {r.action:<13} "
                f"verdict={v:<14} conf={conf:.2f} sev={sev:.2f} bug={bug:.2f} "
                f"[{r.observed.url[:50]}]"
            )
        elif r.blocked:
            print(f"  {r.step_id:<24} {r.action:<13} ⚠️  BLOCKED ({r.block_reason})")
        else:
            print(f"  {r.step_id:<24} {r.action:<13} (no oracle)")

    print()
    print(f"📊 Summary:")
    print(f"   total_steps:        {summary['total_steps']}")
    print(f"   verdict counts:     {summary['verdict_counts']}")
    print(f"   blocked:            {summary['blocked']} ({summary['block_reason']})")
    print(f"   total latency:      {summary['total_latency_ms']}ms")
    print(f"   total cost:         ${summary['total_cost_usd']:.6f}")
    print(f"   cache hits:         {summary['cache_hits']}/{summary['total_steps']}")
    print(f"   wall time:          {elapsed}ms")

    if json_output:
        json_output.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "journey_id": journey.journey_id,
            "journey_title": journey.title,
            "journey_source": str(src_path),
            "total_steps": summary["total_steps"],
            "blocked": summary["blocked"],
            "block_reason": summary["block_reason"],
            "verdict_counts": summary["verdict_counts"],
            "total_latency_ms": summary["total_latency_ms"],
            "total_cost_usd": summary["total_cost_usd"],
            "cache_hits": summary["cache_hits"],
            "wall_time_ms": elapsed,
            "records": [
                {
                    "step_id": r.step_id,
                    "action": r.action,
                    "verifying_ac": r.verifying_ac,
                    "observed": {
                        "url": r.observed.url,
                        "status": r.observed.status,
                        "body_excerpt": r.observed.body_excerpt[:200],
                        "elapsed_ms": r.observed.elapsed_ms,
                    } if r.observed else None,
                    "oracle": {
                        "verdict": r.oracle.verdict,
                        "confidence": r.oracle.confidence,
                        "verdict_probs": r.oracle.verdict_probs,
                        "severity": r.oracle.severity,
                        "severity_probs": r.oracle.severity_probs,
                        "is_real_bug": r.oracle.is_real_bug,
                        "is_real_bug_confidence": r.oracle.is_real_bug_confidence,
                        "latency_ms": r.oracle.latency_ms,
                        "cost_usd": r.oracle.cost_usd,
                        "cached": r.oracle.cached,
                    } if r.oracle else None,
                    "blocked": r.blocked,
                    "block_reason": r.block_reason,
                }
                for r in records
            ],
        }
        json_output.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\n📝 Wrote run records → {json_output}  ({json_output.stat().st_size} bytes)")

    return 0 if not summary["blocked"] else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
