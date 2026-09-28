"""
M6.2 AC03 — re-validate loop
給 (before.json, after.json) → diff verdict 分布變化，自動判斷 improvement / regression / no_change。

設計：
- before/after 必須是 journey_runner.py 產的同一 journey 的 JSON
- 比較 verdict counts（pass/fail/blocked）+ total steps
- 規則：
  - fail 變少 → improvement（fix 有效）
  - fail 變多 → regression（fix 弄壞了，建議 rollback）
  - pass 變多、fail 不變 → improvement（多測一個 case）
  - 都沒變 → no_change
- 產出 unified_report.md（before/after 對照 + verdict diff + 建議）

用法：
    .venv/bin/python re_validate.py <before.json> <after.json> [--output FILE]
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


@dataclass
class VerdictDelta:
    verdict: str
    before: int
    after: int
    delta: int


@dataclass
class ReValidateResult:
    before_path: str
    after_path: str
    journey_id: str
    total_steps_before: int
    total_steps_after: int
    verdict_deltas: list[VerdictDelta] = field(default_factory=list)
    classification: str = ""   # improvement | regression | no_change | inconsistent
    recommendation: str = ""   # "keep patch" | "rollback" | "review"
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        d = asdict(self)
        return d


def _count_verdicts(run_json: dict) -> dict[str, int]:
    """從 run JSON 計算 verdict 分布（跟 batch_report 同樣規則）。"""
    counts: dict[str, int] = {"pass": 0, "fail": 0, "blocked": 0}
    for r in run_json.get("records", []):
        if r.get("blocked"):
            counts["blocked"] += 1
        elif r.get("oracle"):
            counts[r["oracle"]["verdict"]] += 1
        else:
            counts["fail"] += 1  # 沒 oracle 結果算 fail
    return counts


def _classify(before: dict[str, int], after: dict[str, int]) -> tuple[str, str]:
    """分類 verdict 變化 + 給建議。"""
    fail_delta = after.get("fail", 0) - before.get("fail", 0)
    pass_delta = after.get("pass", 0) - before.get("pass", 0)

    if fail_delta < 0:
        return "improvement", f"keep patch（fail -{-fail_delta}）"
    if fail_delta > 0:
        return "regression", f"rollback（fail +{fail_delta}）"
    if pass_delta > 0:
        return "improvement", f"keep patch（pass +{pass_delta}）"
    if pass_delta < 0:
        return "regression", f"rollback（pass -{pass_delta}）"
    return "no_change", "review（無明顯變化）"


def re_validate(before_path: Path, after_path: Path) -> ReValidateResult:
    """主入口：比較 before/after 並分類。"""
    before_json = json.loads(before_path.read_text(encoding="utf-8"))
    after_json = json.loads(after_path.read_text(encoding="utf-8"))

    before_counts = _count_verdicts(before_json)
    after_counts = _count_verdicts(after_json)

    # 算 deltas
    all_verdicts = set(before_counts) | set(after_counts)
    deltas = []
    for v in sorted(all_verdicts):
        b = before_counts.get(v, 0)
        a = after_counts.get(v, 0)
        deltas.append(VerdictDelta(verdict=v, before=b, after=a, delta=a - b))

    # 分類
    classification, recommendation = _classify(before_counts, after_counts)

    # 檢查 journey 一致性
    before_jid = before_json.get("journey_id", "?")
    after_jid = after_json.get("journey_id", "?")
    notes = []
    if before_jid != after_jid:
        notes.append(f"⚠️ journey_id 不一致：{before_jid} vs {after_jid}")

    total_b = sum(before_counts.values())
    total_a = sum(after_counts.values())
    if total_b != total_a:
        notes.append(f"⚠️ total steps 不一致：{total_b} vs {total_a}")

    result = ReValidateResult(
        before_path=str(before_path),
        after_path=str(after_path),
        journey_id=after_jid,
        total_steps_before=total_b,
        total_steps_after=total_a,
        verdict_deltas=deltas,
        classification=classification,
        recommendation=recommendation,
        notes=notes,
    )
    return result


def render_markdown(result: ReValidateResult) -> str:
    """渲染 re-validate 報告為 markdown。"""
    emoji = {
        "improvement": "🟢",
        "regression":  "🔴",
        "no_change":   "🟡",
        "inconsistent": "🟠",
    }.get(result.classification, "?")
    lines = [
        f"# Re-validate Report — {result.journey_id}",
        "",
        f"**分類**：{emoji} **{result.classification}**",
        f"**建議**：{result.recommendation}",
        "",
        f"**before**：`{result.before_path}`",
        f"**after**：`{result.after_path}`",
        "",
        "## Verdict Delta",
        "",
        "| verdict | before | after | delta |",
        "|---------|--------|-------|-------|",
    ]
    for d in result.verdict_deltas:
        emoji_d = "🔺" if d.delta > 0 else ("🔻" if d.delta < 0 else "—")
        lines.append(f"| {d.verdict} | {d.before} | {d.after} | {emoji_d} {d.delta:+d} |")

    lines.extend([
        "",
        f"**total steps**: {result.total_steps_before} → {result.total_steps_after}",
    ])

    if result.notes:
        lines.extend(["", "## Notes", ""])
        for n in result.notes:
            lines.append(f"- {n}")

    return "\n".join(lines) + "\n"


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="M6.2 re-validate loop")
    parser.add_argument("before", type=Path, help="patch 前 journey JSON")
    parser.add_argument("after", type=Path, help="patch 後 journey JSON")
    parser.add_argument("--output", "-o", type=Path, help="輸出 .md 報告")
    parser.add_argument("--json", action="store_true", help="JSON 輸出")
    args = parser.parse_args(argv[1:])

    for p in (args.before, args.after):
        if not p.exists():
            print(f"❌ 檔案不存在：{p}")
            return 1

    result = re_validate(args.before, args.after)
    md = render_markdown(result)

    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(md)

    if args.output:
        args.output.write_text(md, encoding="utf-8")
        print(f"\n📝 Wrote {args.output}  ({args.output.stat().st_size} bytes)")

    # return code：regression=1, improvement/no_change=0
    return 1 if result.classification == "regression" else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
