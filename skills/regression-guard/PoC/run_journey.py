"""
Journey Runner CLI — 讀 YAML → 跑 dry-run loop → 印結果。

用法:
    .venv/bin/python run_journey.py journeys/US-101.yaml
"""

from __future__ import annotations

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
    if use_stale_test:
        # 用粗製 mock_observe（所有 step 同 state）來證 stale detection 邏輯
        from journey_runner import mock_observe, mock_observed_to_ac_context, _state_signature_strict, StepRecord
        from jev_oracle import evaluate_ac

        print("⚙️  stale-test mode: 所有 step 強制回相同 ObservedState")
        records = []
        blocked = False
        block_reason = ""
        prev_signature = None
        consecutive_stale = 0
        ac_by_id = {ac.ac_id: ac for ac in story.acs}
        for step in journey.steps:
            if blocked:
                records.append(StepRecord(step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                                            observed=mock_observe(step, None), oracle=None, blocked=True,
                                            block_reason="blocked earlier"))
                continue
            observed = mock_observe(step, None)
            sig = _state_signature_strict(observed)
            ac = ac_by_id.get(step.verifying_ac)
            if not ac:
                records.append(StepRecord(step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                                            observed=observed, oracle=None, blocked=True,
                                            block_reason="AC not found"))
                blocked = True
                continue
            ctx = mock_observed_to_ac_context(ac, step, observed)
            oracle_result = evaluate_ac(ctx, use_cache=True)
            if oracle_result.verdict == "fail" and sig == prev_signature:
                consecutive_stale += 1
                if consecutive_stale >= 3:
                    records.append(StepRecord(step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                                                observed=observed, oracle=oracle_result, blocked=True,
                                                block_reason=f"stale={consecutive_stale}"))
                    blocked = True
                    block_reason = f"stale {consecutive_stale}"
                    continue
            else:
                consecutive_stale = 0
            prev_signature = sig
            records.append(StepRecord(step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                                        observed=observed, oracle=oracle_result))
        from collections import Counter
        summary = {
            "total_steps": len(records),
            "blocked": blocked,
            "block_reason": block_reason,
            "verdict_counts": dict(Counter(r.oracle.verdict for r in records if r.oracle)),
            "total_latency_ms": sum(r.oracle.latency_ms for r in records if r.oracle),
            "total_cost_usd": sum(r.oracle.cost_usd for r in records if r.oracle),
            "cache_hits": sum(1 for r in records if r.oracle and r.oracle.cached),
        }
    else:
        records, summary = run_journey(journey, story.acs)
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

    return 0 if not summary["blocked"] else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
