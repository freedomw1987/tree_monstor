"""
Journey Gen CLI — 讀 AC 檔 → 產 journey YAML。

用法:
    .venv/bin/python journey_gen.py <path/to/US-XXX.md> [output.yaml]
    .venv/bin/python journey_gen.py ../../../docs/ac/US-101.md
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

from ac_schema import parse_story_file
from journey_generator import generate_journey, JOURNEYS_DIR


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: journey_gen.py <path/to/US-XXX.md> [output.yaml]")
        print("例如: journey_gen.py ../../../docs/ac/US-101.md")
        return 1

    src = Path(argv[1])
    if not src.exists():
        print(f"❌ AC 檔找不到：{src}")
        return 1

    out = Path(argv[2]) if len(argv) > 2 else JOURNEYS_DIR / f"{src.stem}.yaml"

    story = parse_story_file(src)
    print(f"📖 讀 {src}")
    print(f"   story: {story.story_id} 「{story.title}」 ({len(story.acs)} 條 AC)")
    print()

    started = time.perf_counter()
    journey = generate_journey(story)
    elapsed_ms = int((time.perf_counter() - started) * 1000)

    print(f"✅ Generated journey:")
    print(f"   journey_id: {journey.journey_id}")
    print(f"   total_steps: {journey.total_steps}")
    print(f"   steps per AC: {journey.total_steps // max(1, len(story.acs))}")
    print()

    print(f"   Steps:")
    for s in journey.steps:
        dep_str = f"  depends_on={s.depends_on}" if s.depends_on else ""
        print(f"     • {s.id:<22}  {s.action:<13} → {s.verifying_ac}{dep_str}")

    # cost / latency
    total_calls = len(journey.meta.get("calls", []))
    live_calls = [c for c in journey.meta.get("calls", []) if not c.get("cached", False)]
    cache_hits = total_calls - len(live_calls)
    total_lat = sum(c.get("latency_ms", 0) for c in journey.meta.get("calls", []))

    print()
    print(f"   Jev calls:   {total_calls} total  ({len(live_calls)} live, {cache_hits} cached)")
    print(f"   Total latency (live): {total_lat}ms")
    print(f"   Wall time:   {elapsed_ms}ms")
    print()

    out.parent.mkdir(parents=True, exist_ok=True)
    txt = journey.to_yaml(path=out)
    print(f"📄 Wrote {out}  ({len(txt)} bytes, {journey.total_steps} steps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
