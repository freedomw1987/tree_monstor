"""
End-of-Run Batch Report — 讀 journey run 結果 → 一次 Jev batch call → 出 4 維度綜合判定。

設計：
  - 4 題一次 batch（跟 M1 三題同 pattern，per-run 只付一次 Jev call 成本）
    1. overall_health   (choice: green / yellow / red)
    2. fix_priority     (score: 0=不急 / 3=立刻修)
    3. flaky_likelihood (noul: 是/否)
    4. regression_type  (choice: real_bug / flaky / over_assertion / n_a)
  - 輸出兩份檔：
    • report.json — 機器讀
    • report.md   — 人讀（給 reviewer 直接看）
  - 寫到 REGRESSION_REPORT_PATH（env 變數，預設 ./report.json/.md）
"""

from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

import httpx

from jev_oracle import _cache_key, _load_cache, _save_cache, _post_with_retry, _load_api_key

DEFAULT_MODEL = "typesafe/jev-1.13"
OPENROUTER_URL = "https://openrouter.ai/api/alpha/decisions"


# ─── Batch 4 題 schema ─────────────────────────────────────────────────────

BATCH_QUESTIONS = {
    "overall_health": {
        "type": "choice",
        "instructions": (
            "Based on the journey's overall verdict distribution and severity, "
            "decide the project's current health status for this user story."
        ),
        "criteria": {
            "green":  "All or nearly all steps passed; no critical-severity issues; ACs hold.",
            "yellow": "Some failures but they're either flaky or low severity; mostly stable.",
            "red":    "Multiple hard failures, high severity, or blocked — the story is broken.",
        },
    },
    "fix_priority": {
        "type": "score",
        "instructions": (
            "Rate how urgently this user story should be fixed on a 0-3 scale. "
            "0 = no fix needed (green health); 3 = drop everything and fix immediately."
        ),
        "criteria": [
            "0 — no fix needed; everything works as designed",
            "1 — minor polish / cosmetic / over-assertion ACs to revisit later",
            "2 — moderate issue affecting some user flows; fix this sprint",
            "3 — critical bug blocking the user story; fix immediately",
        ],
    },
    "flaky_likelihood": {
        "type": "noul",
        "instructions": (
            "Based on the failure pattern (timing? ordering? environment?), "
            "is this run's failure likely flaky (non-deterministic)? "
            "true = flaky (re-run might pass); false = deterministic real issue."
        ),
        "criteria": {
            "true":  "Failure pattern suggests flakiness — timing, race, env, or test ordering.",
            "false": "Failure looks deterministic; will likely reproduce consistently.",
        },
    },
    "regression_type": {
        "type": "choice",
        "instructions": (
            "If there are failures, classify the dominant type. "
            "If everything passed, choose n_a."
        ),
        "criteria": {
            "real_bug":       "Application code is genuinely broken (logic, state, network, error handling).",
            "flaky":          "Failure is non-deterministic; timing, race condition, or test order issue.",
            "over_assertion": "AC `Then` is too strict or ambiguous — outcome is actually fine.",
            "n_a":            "No failure; everything passed.",
        },
    },
}


# ─── State text 組裝 ──────────────────────────────────────────────────────

def _run_summary_to_state(run_json: dict) -> str:
    """把 M3 輸出 JSON 壓縮成 Jev state string。
    只含「語意」欄位：verdict / conf / sev / bug / counts / block。動態 stats（latency/cost/generated_at）排除以免 cache key 漂移。
    """
    lines = [
        f"=== Journey {run_json['journey_id']} — {run_json['journey_title']} ===",
        f"Source AC:    {run_json['journey_source']}",
        f"Total steps:  {run_json['total_steps']}",
        f"Blocked:      {run_json['blocked']}  ({run_json['block_reason']})",
        "",
        "=== Verdict distribution ===",
        json.dumps(run_json["verdict_counts"], ensure_ascii=False),
        "",
        "=== Per-step results ===",
    ]
    for r in run_json["records"]:
        if r["blocked"]:
            lines.append(f"  [{r['step_id']}] {r['action']} → BLOCKED ({r['block_reason']})")
            continue
        if not r["oracle"]:
            lines.append(f"  [{r['step_id']}] {r['action']} → (no oracle)")
            continue
        o = r["oracle"]
        obs = r["observed"] or {}
        # 語意欄位：verdict / conf / sev / bug
        # 不含：latency / cost / cached（動態、會讓 cache key 漂移）
        lines.append(
            f"  [{r['step_id']}] {r['action']} → verdict={o['verdict']} "
            f"conf={o['confidence']:.2f} sev={o['severity']:.2f} bug={o['is_real_bug']:.2f}"
        )
        lines.append(f"      url={obs.get('url', '?')[:80]}  status={obs.get('status', '?')}")
        lines.append(f"      body={obs.get('body_excerpt', '')[:120]}")
    return "\n".join(lines)


# ─── 4 題解析 ──────────────────────────────────────────────────────────────

@dataclass
class BatchReport:
    """4 維度綜合判定結果。"""
    overall_health: str               # green / yellow / red
    fix_priority: float               # 0-3
    flaky_likelihood: float           # 0-1
    regression_type: str              # real_bug / flaky / over_assertion / n_a
    overall_health_probs: dict[str, float] = field(default_factory=dict)
    fix_priority_legend: dict[str, str] = field(default_factory=dict)
    fix_priority_probs: dict[str, float] = field(default_factory=dict)
    flaky_likelihood_confidence: float = 0.0
    regression_type_probs: dict[str, float] = field(default_factory=dict)
    model: str = ""
    latency_ms: int = 0
    cost_usd: float = 0.0


def _build_payload(run_json: dict, *, model: str) -> dict:
    return {
        "model": model,
        "state": _run_summary_to_state(run_json),
        "questions": BATCH_QUESTIONS,
    }


def _parse_batch_response(raw: dict) -> BatchReport:
    answers = raw.get("answers", {})
    usage = raw.get("usage", {})

    health = answers.get("overall_health", {})
    priority = answers.get("fix_priority", {})
    flaky = answers.get("flaky_likelihood", {})
    rtype = answers.get("regression_type", {})

    return BatchReport(
        overall_health=health.get("choice", "unknown"),
        overall_health_probs=health.get("probabilities", {}),
        fix_priority=float(priority.get("score", 0)),
        fix_priority_legend=priority.get("legend", {}),
        fix_priority_probs=priority.get("probabilities", {}),
        flaky_likelihood=float(flaky.get("noul", 0)),
        flaky_likelihood_confidence=float(flaky.get("confidence", 0)),
        regression_type=rtype.get("choice", "n_a"),
        regression_type_probs=rtype.get("probabilities", {}),
        model=raw.get("model", "?"),
        cost_usd=float(usage.get("cost", 0)),
    )


# ─── Public API ────────────────────────────────────────────────────────────

def generate_batch_report(run_json: dict, *, model: str = DEFAULT_MODEL,
                           use_cache: bool = True) -> BatchReport:
    """
    主入口：給 M3 runner 輸出的 dict → 出 BatchReport。
    cache key 是 sha256 of (state text + questions schema)；同一份 run 結果重跑免費。
    """
    body = _build_payload(run_json, model=model)
    key = _cache_key(body)
    if use_cache:
        c = _load_cache(key)
        if c is not None:
            return _parse_batch_response(c["raw_response"])

    api_key = _load_api_key()
    if not api_key:
        raise RuntimeError(
            "Cache miss 且 OPENROUTER_API_KEY 找不到。"
            "請見 batch_report.py docstring 或 jev_oracle.py 頂部。"
        )

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/browser-use/jev-ultrafast",
        "X-Title": "regression-guard-jev-batch-report",
    }
    started = time.perf_counter()
    raw = _post_with_retry(OPENROUTER_URL, body, headers)
    latency_ms = int((time.perf_counter() - started) * 1000)

    _save_cache(key, {"raw_response": raw, "context_summary": {"journey_id": run_json["journey_id"]}})
    report = _parse_batch_response(raw)
    report.latency_ms = latency_ms
    return report


# ─── Reporter：把 BatchReport 寫成 JSON + MD ───────────────────────────────

def write_json_report(report: BatchReport, run_json: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "journey_id": run_json["journey_id"],
        "journey_title": run_json["journey_title"],
        "source": run_json["journey_source"],
        "batch_report": asdict(report),
        "run_summary": {
            "total_steps": run_json["total_steps"],
            "blocked": run_json["blocked"],
            "block_reason": run_json["block_reason"],
            "verdict_counts": run_json["verdict_counts"],
            "total_cost_usd": run_json["total_cost_usd"],
            "total_latency_ms": run_json["total_latency_ms"],
        },
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "model": report.model,
    }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def _emoji_for(health: str) -> str:
    return {"green": "🟢", "yellow": "🟡", "red": "🔴"}.get(health, "⚪")


def write_markdown_report(report: BatchReport, run_json: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    emoji = _emoji_for(report.overall_health)
    health_probs_str = "  ".join(f"{k}={v:.2f}" for k, v in report.overall_health_probs.items())
    rtype_probs_str = "  ".join(f"{k}={v:.2f}" for k, v in report.regression_type_probs.items())
    fix_probs_str = "  ".join(f"score{i}={v:.2f}" for i, v in report.fix_priority_probs.items())

    lines = [
        f"# {emoji} Regression Report — {run_json['journey_id']} {run_json['journey_title']}",
        "",
        f"_Source: `{run_json['journey_source']}`  •  Generated by `{report.model}`  •  {time.strftime('%Y-%m-%d %H:%M:%S')}_",
        "",
        "## 🎯 Overall Assessment",
        "",
        f"| 維度 | 結果 | 信心/分布 |",
        f"|---|---|---|",
        f"| **Overall Health** | {emoji} **{report.overall_health.upper()}** | {health_probs_str or '—'} |",
        f"| **Fix Priority** | **{report.fix_priority:.1f} / 3** | {fix_probs_str or '—'} |",
        f"| **Flaky Likelihood** | **{report.flaky_likelihood:.2f}** (conf={report.flaky_likelihood_confidence:.2f}) | — |",
        f"| **Regression Type** | **{report.regression_type}** | {rtype_probs_str or '—'} |",
        "",
        "## 📊 Run Summary",
        "",
        f"- Total steps:    **{run_json['total_steps']}**",
        f"- Blocked:        **{run_json['blocked']}**  ({run_json['block_reason'] or 'no'})",
        f"- Verdict counts: `{json.dumps(run_json['verdict_counts'], ensure_ascii=False)}`",
        f"- Run cost:       ${run_json['total_cost_usd']:.6f}",
        f"- Run latency:    {run_json['total_latency_ms']} ms",
        f"- Report cost:    ${report.cost_usd:.6f}",
        f"- Report latency: {report.latency_ms} ms",
        "",
        "## 🔍 Per-Step Results",
        "",
    ]

    # 步驟表
    for r in run_json["records"]:
        if r["blocked"]:
            lines.append(f"- ⚠️  **{r['step_id']}** ({r['action']}) → BLOCKED ({r['block_reason']})")
            continue
        if not r["oracle"]:
            lines.append(f"- __{r['step_id']}__ ({r['action']}) → no oracle")
            continue
        o = r["oracle"]
        verdict_emoji = {"pass": "✅", "fail": "❌", "flaky": "🟡", "over_assertion": "🟣"}.get(o["verdict"], "❓")
        lines.append(
            f"- {verdict_emoji} **{r['step_id']}** ({r['action']}, verifies `{r['verifying_ac']}`) "
            f"→ **{o['verdict']}** conf={o['confidence']:.2f} sev={o['severity']:.2f} bug={o['is_real_bug']:.2f}"
        )

    lines += [
        "",
        "---",
        "",
        "_Generated by `regression-guard/PoC/batch_report.py` (M4)_",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


# ─── CLI ───────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: run_report.py <path/to/run-journey.json> [REPORT_BASENAME]")
        print()
        print("  <run-journey.json>  M3 run_journey.py --json-output 產出的 JSON")
        print("  [REPORT_BASENAME]   不含副檔名的報告路徑（預設從 REGRESSION_REPORT_PATH env 讀，")
        print("                       再 fallback 到 ./report）")
        print()
        print("環境變數：")
        print("  REGRESSION_REPORT_PATH   報告 basename（不含 .json/.md）")
        print("  OPENROUTER_API_KEY       Jev API key")
        return 1

    run_path = Path(argv[1])
    if not run_path.exists():
        print(f"❌ Run JSON 找不到：{run_path}")
        return 1

    # 報告路徑
    report_basename = argv[2] if len(argv) >= 3 else os.environ.get("REGRESSION_REPORT_PATH", "./report")
    report_basename = Path(report_basename)
    if report_basename.is_dir():
        # 是目錄就自動補 default basename
        report_basename = report_basename / "report"

    print(f"📖 Reading run records: {run_path}")
    run_json = json.loads(run_path.read_text(encoding="utf-8"))
    print(f"   journey:        {run_json['journey_id']} — {run_json['journey_title']}")
    print(f"   total_steps:    {run_json['total_steps']}")
    print(f"   verdict_counts: {run_json['verdict_counts']}")
    print()

    print("🤖 Calling Jev (4-question batch)…")
    started = time.perf_counter()
    report = generate_batch_report(run_json)
    elapsed = int((time.perf_counter() - started) * 1000)

    emoji = _emoji_for(report.overall_health)
    print(f"   {emoji} overall_health:   {report.overall_health}")
    print(f"   🔧 fix_priority:     {report.fix_priority:.2f} / 3")
    print(f"   🎲 flaky_likelihood: {report.flaky_likelihood:.2f}  (conf={report.flaky_likelihood_confidence:.2f})")
    print(f"   📌 regression_type:  {report.regression_type}")
    print(f"   ⏱️  latency: {report.latency_ms}ms / cost ${report.cost_usd:.6f} / wall {elapsed}ms")

    json_path = report_basename.with_suffix(".json")
    md_path = report_basename.with_suffix(".md")
    write_json_report(report, run_json, json_path)
    write_markdown_report(report, run_json, md_path)

    print()
    print(f"📝 Wrote JSON  → {json_path}  ({json_path.stat().st_size} bytes)")
    print(f"📝 Wrote MD    → {md_path}  ({md_path.stat().st_size} bytes)")

    # 1 = 嚴重；0 = OK；2 = 中等（給 CI 用）
    if report.overall_health == "red":
        return 1
    if report.overall_health == "yellow":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
