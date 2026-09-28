"""
M6 Fix Proposal — Jev oracle 自動產出 fix proposal markdown。

設計：
- 輸入：M3 跑完的 run JSON（`/tmp/<STORY>-run.json` 或 `--json-output` 產物）
- 處理：3 題一次 batch call（跟 batch_report.py 同 pattern）
  1. problem_summary    (noul: 1 句話總結失敗)
  2. proposed_fix       (noul: 1 句話建議怎麼修)
  3. verification_steps (noul: 1 句話怎麼驗證 fix 有效)
- 輸出：fix_proposal.md（人讀格式）

觸發方式：
    JEV_FIX_PROPOSAL=1 ./run_pipeline.sh US-101
    # 或
    .venv/bin/python fix_proposal.py /tmp/US-101-run.json
"""

from __future__ import annotations

import json
import sys
import time
from dataclasses import dataclass
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

import httpx

from jev_oracle import _cache_key, _load_cache, _save_cache, _post_with_retry, _load_api_key

DEFAULT_MODEL = "typesafe/jev-1.13"
OPENROUTER_URL = "https://openrouter.ai/api/alpha/decisions"


# ─── Batch 3 題 schema ───────────────────────────────────────────────────
# Note: Jev v1.13 只支援 `choice` 跟 `noul` 兩種題型；沒有 free_response。
# M6 範圍：用 noul 題把 Jev 當「信心度判定器」—— 給失敗走跡問「能不能一句話總結？」
# （true=高信心有清晰失敗走跡、false=不確定/訊息不足），output 是一個 probability。
# 然後由人工 / 下一個 LLM（未來 M6.1）接 寫出實際 fix 文字。
# 現階段產出 → fix_proposal.md 是「Jev 信心度報告 + 原始失敗走跡」，給 reviewer 直閱讀。

PROPOSAL_QUESTIONS = {
    "problem_summary": {
        "type": "noul",
        "instructions": (
            "Given the failed journey steps, can you confidently state a 1-sentence "
            "problem summary (≤ 30 words) that names the failing behavior concretely? "
            "true = high confidence a concise summary is possible; "
            "false = failure pattern is unclear or too tangled for a short summary."
        ),
        "criteria": {
            "true":  "One failed step is dominant, has a clear URL/status, and the failure cause is identifiable.",
            "false": "Multiple steps fail in a chain, or failure cause is ambiguous from the observed state alone.",
        },
    },
    "proposed_fix": {
        "type": "noul",
        "instructions": (
            "Based on the failure pattern, can you confidently suggest a concrete fix "
            "(naming a specific component like route / service / template)? "
            "true = fix is actionable and points to a specific code area; "
            "false = too speculative without deeper code inspection."
        ),
        "criteria": {
            "true":  "The failure maps to a known component (e.g. payment service returns 500 → fix /api/payment route).",
            "false": "The fix could be in many places (UI, API, DB, config) — needs more code reading to pin down.",
        },
    },
    "verification_steps": {
        "type": "noul",
        "instructions": (
            "Can you confidently suggest 1-2 verification steps (runnable in <5 min) "
            "to confirm the fix? true = steps are concrete and CI-runnable; "
            "false = needs manual inspection or non-trivial setup."
        ),
        "criteria": {
            "true":  "Re-running run_pipeline.sh or a specific curl/check would confirm the fix.",
            "false": "Verification requires manual user flow reproduction or staging deployment.",
        },
    },
}


# ─── Jev 呼叫（跟 batch_report.py 對齊） ──────────────────────────────────

def _state_text(run_json: dict) -> str:
    """壓縮 run JSON 為 Jev state。重點：失敗步的 url/status/body 給 Jev 看。"""
    lines = [
        f"=== Journey {run_json['journey_id']} — {run_json['journey_title']} ===",
        f"Source AC:    {run_json['journey_source']}",
        f"Total steps:  {run_json['total_steps']}",
        f"Blocked:      {run_json['blocked']}  ({run_json['block_reason']})",
        "",
        "=== Verdict distribution ===",
        json.dumps(run_json["verdict_counts"], ensure_ascii=False),
        "",
        "=== Failed steps (only) ===",
    ]
    failed_count = 0
    for r in run_json["records"]:
        if r["blocked"]:
            lines.append(f"  [{r['step_id']}] {r['action']} → BLOCKED ({r['block_reason']})")
            failed_count += 1
            continue
        if r.get("oracle") and r["oracle"]["verdict"] == "fail":
            o = r["oracle"]
            obs = r.get("observed") or {}
            lines.append(
                f"  [{r['step_id']}] {r['action']} → FAIL "
                f"conf={o['confidence']:.2f} sev={o['severity']:.2f} bug={o['is_real_bug']:.2f}"
            )
            lines.append(f"    url:    {obs.get('url', '(none)')}")
            lines.append(f"    status: {obs.get('status', '?')}")
            body = obs.get("body_excerpt", "")[:200]
            if body:
                lines.append(f"    body:   {body}")
            failed_count += 1
    if failed_count == 0:
        lines.append("  (no failures)")
    return "\n".join(lines)


def _build_proposal_payload(run_json: dict, *, model: str) -> dict:
    return {
        "model": model,
        "state": _state_text(run_json),
        "questions": PROPOSAL_QUESTIONS,
    }


def _parse_proposal_response(raw: dict) -> "FixProposal":
    """Jev noul 題型回傳 {type, noul: probability}。轉成 FixProposal 信心度字段。"""
    answers = raw.get("answers", {})

    def _noul(qid: str) -> float:
        a = answers.get(qid, {})
        if isinstance(a, dict):
            return float(a.get("noul", 0.0))
        return 0.0

    return FixProposal(
        problem_summary_conf=_noul("problem_summary"),
        proposed_fix_conf=_noul("proposed_fix"),
        verification_steps_conf=_noul("verification_steps"),
    )


# ─── DataClass ───────────────────────────────────────────────────────────

@dataclass
class FixProposal:
    # Jev 給的 noul 概率 0.0–1.0
    problem_summary_conf: float
    proposed_fix_conf: float
    verification_steps_conf: float
    latency_ms: int = 0
    cost_usd: float = 0.0
    cached: bool = False

    @property
    def overall_confidence(self) -> float:
        return (self.problem_summary_conf + self.proposed_fix_conf + self.verification_steps_conf) / 3.0

    def _conf_label(self, conf: float) -> str:
        """0–1 概率轉人讀標籤。"""
        if conf >= 0.75:
            return "🟢 高信心"
        if conf >= 0.5:
            return "🟡 中信心"
        if conf >= 0.25:
            return "🟠 低信心"
        return "🔴 不可判定"

    def to_markdown(self, run_json: dict) -> str:
        verdict_counts = run_json.get("verdict_counts", {})
        return (
            f"# Fix Proposal — {run_json['journey_id']}\n\n"
            f"> **M6 Jev 信心度報告**（3 題 noul batch call）— PoC 階段，需人工接手寫 fix 細節。\n\n"
            f"**整體信心度**：{self.overall_confidence:.2f} ({self._conf_label(self.overall_confidence)})\n\n"
            f"## 信心度評估\n\n"
            f"| 維度 | 信心度 | 評級 | 備註 |\n"
            f"|---|---|---|---|\n"
            f"| 問題摘要 | {self.problem_summary_conf:.2f} | {self._conf_label(self.problem_summary_conf)} | Jev 認為能寫出 1 句話明確總結 |\n"
            f"| 建議修正 | {self.proposed_fix_conf:.2f} | {self._conf_label(self.proposed_fix_conf)} | Jev 認為能指向特定 component |\n"
            f"| 驗證步驟 | {self.verification_steps_conf:.2f} | {self._conf_label(self.verification_steps_conf)} | Jev 認為步驟能在 <5min CI-runnable |\n\n"
            f"## 原始失敗走跡（reviewer 接手起點）\n\n"
            f"```\n{_state_text(run_json)}\n```\n\n"
            f"---\n\n"
            f"### 上下文\n\n"
            f"| 項 | 值 |\n|---|---|\n"
            f"| Journey | `{run_json['journey_id']}` — {run_json['journey_title']} |\n"
            f"| Source AC | `{run_json['journey_source']}` |\n"
            f"| Total steps | {run_json['total_steps']} |\n"
            f"| Verdict counts | {verdict_counts} |\n"
            f"| Blocked | {run_json['blocked']} ({run_json['block_reason']}) |\n"
            f"| Latency | {self.latency_ms}ms |\n"
            f"| Cached | {self.cached} |\n\n"
            f"### 下一步\n\n"
            f"1. 整體信心度 ≥ 0.5 → reviewer 直接接手寫 fix proposal\n"
            f"2. 整體信心度 < 0.5 → 需要更多 context（重跑或加 observer），先跳過 fix 階段\n"
            f"3. M6.1 (未來)：接 Claude/GPT 生成實際 fix 文字，Jev 信心度作為 gating\n\n"
            f"_Generated by `regression-guard/PoC/fix_proposal.py` (M6)_\n"
        )


# ─── 公開 API ─────────────────────────────────────────────────────────────

def generate_fix_proposal(run_json: dict, *, model: str = DEFAULT_MODEL,
                          use_cache: bool = True) -> FixProposal:
    """
    主入口：給 M3 runner 輸出的 dict → 出 FixProposal。
    cache key 是 sha256 of (state text + questions schema)；同一份 run 結果重跑免費。
    """
    body = _build_proposal_payload(run_json, model=model)
    key = _cache_key(body)
    if use_cache:
        c = _load_cache(key)
        if c is not None:
            proposal = _parse_proposal_response(c["raw_response"])
            proposal.cached = True
            return proposal

    api_key = _load_api_key()
    if not api_key:
        raise RuntimeError(
            "Cache miss 且 OPENROUTER_API_KEY 找不到。"
            "請：1) export OPENROUTER_API_KEY=sk-or-v1-... 或 2) 寫進 .env"
        )

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/browser-use/jev-ultrafast",
        "X-Title": "regression-guard-jev-fix-proposal",
    }
    started = time.perf_counter()
    raw = _post_with_retry(OPENROUTER_URL, body, headers)
    latency_ms = int((time.perf_counter() - started) * 1000)

    _save_cache(key, {"raw_response": raw, "context_summary": {"journey_id": run_json["journey_id"]}})
    proposal = _parse_proposal_response(raw)
    proposal.latency_ms = latency_ms
    return proposal


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: fix_proposal.py <path/to/run-journey.json> [OUTPUT_PATH]")
        print()
        print("  <run-journey.json>  M3 run_journey.py --json-output 產出的 JSON")
        print("  [OUTPUT_PATH]       輸出 .md 路徑（預設 ./fix_proposal.md）")
        print()
        print("環境變數：")
        print("  OPENROUTER_API_KEY   Jev API key")
        print("  JEV_FIX_PROPOSAL=1   啟用（run_pipeline.sh 內自動檢查）")
        return 1

    run_path = Path(argv[1])
    if not run_path.exists():
        print(f"❌ Run JSON 找不到：{run_path}")
        return 1
    run_json = json.loads(run_path.read_text(encoding="utf-8"))

    out_path = Path(argv[2]) if len(argv) > 2 else Path("./fix_proposal.md")

    # 計算失敗步數 (for printout)
    failed = sum(
        1 for r in run_json["records"]
        if (r.get("blocked") or
            (r.get("oracle") and r["oracle"]["verdict"] == "fail"))
    )

    print(f"📖 Reading run records: {run_path}")
    print(f"   journey:        {run_json['journey_id']} — {run_json['journey_title']}")
    print(f"   failed steps:   {failed} / {run_json['total_steps']}")
    print(f"   blocked:        {run_json['blocked']} ({run_json['block_reason']})")
    print()

    try:
        proposal = generate_fix_proposal(run_json)
    except RuntimeError as e:
        print(f"❌ {e}")
        return 1

    md = proposal.to_markdown(run_json)
    out_path.write_text(md, encoding="utf-8")

    elapsed_str = f" (cached)" if proposal.cached else f" / {proposal.latency_ms}ms"
    print(f"   ⏱️  latency: {elapsed_str}")
    print()
    print(f"📝 Wrote fix_proposal → {out_path}  ({out_path.stat().st_size} bytes)")
    print()
    print("=== 信心度評估 ===")
    print(f"  問題摘要:   {proposal.problem_summary_conf:.2f}  ({proposal._conf_label(proposal.problem_summary_conf)})")
    print(f"  建議修正:   {proposal.proposed_fix_conf:.2f}  ({proposal._conf_label(proposal.proposed_fix_conf)})")
    print(f"  驗證步驟:   {proposal.verification_steps_conf:.2f}  ({proposal._conf_label(proposal.verification_steps_conf)})")
    print(f"  整體:       {proposal.overall_confidence:.2f}  ({proposal._conf_label(proposal.overall_confidence)})")
    print()
    if proposal.overall_confidence >= 0.5:
        print("✅ 整體信心度 ≥ 0.5，reviewer 可接手寫 fix 細節")
    else:
        print("⚠️ 整體信心度 < 0.5，建議先加 observer context 再跑一次")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
