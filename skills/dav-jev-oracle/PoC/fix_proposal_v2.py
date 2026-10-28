"""
M6.1 Fix Proposal v2 — Jev 信心度報告 + LLM 接力素材 + 走跡對照。

設計：
- v1 範圍（fix_proposal.py）：Jev 信心度報告 + 原始失敗走跡，reviewer 接手寫 fix
- v2 範圍（本檔）：v1 + 「LLM relay 素材打包」 — 信心度 ≥ 0.5 時產出 prompt bundle，
  給當下對話的 LLM agent（subagent / pi 本身）接力寫 fix 文字

雙模式：
  - 預設 (run mode)：產出 fix_proposal_v2.md + .relay/prompt.md（prompt bundle）
  - --answer-from FILE：從 .relay/answer.md 讀 LLM 接力產出，併入 final report

觸發：
  JEV_FIX_PROPOSAL=1 ./run_pipeline.sh US-101   # v2 自動接在 v1 後
  或
  JEV_FIX_PROPOSAL=1 .venv/bin/python fix_proposal_v2.py /tmp/<STORY>-run.json
"""

from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

import httpx

# 重用 v1 模組
from fix_proposal import (
    PROPOSAL_QUESTIONS,
    _state_text,
    _build_proposal_payload,
    _parse_proposal_response,
    FixProposal,
    generate_fix_proposal,
    _cache_key,
    _load_cache,
    _save_cache,
    _post_with_retry,
    _load_api_key,
    DEFAULT_MODEL,
    OPENROUTER_URL,
)

PROMPT_TEMPLATE_PATH = THIS_DIR / "prompts" / "fix_relay.md"
RELAY_DIR_NAME = ".relay"
RELAY_GATING_THRESHOLD = 0.5  # 整體信心度 ≥ 0.5 才召喚 LLM relay


# ─── LLM Relay Bundle ─────────────────────────────────────────────────────

@dataclass
class LLMRelayBundle:
    """產出給 subagent 的接力素材。"""
    journey_id: str
    journey_title: str
    source_ac: str
    fix_proposal: FixProposal
    failed_steps_text: str
    run_summary: dict
    gating_pass: bool
    relay_dir: Path

    def write_prompt_bundle(self) -> Path:
        """把 prompt template + 走跡 + 信心度打包成 .relay/prompt.md"""
        prompt_template = PROMPT_TEMPLATE_PATH.read_text(encoding="utf-8")

        # 信心度評估表
        proposal_md = self.fix_proposal.to_markdown(self.run_summary)
        # 走跡
        state_text = self._failed_steps_only()

        bundle = f"""{prompt_template}

---

# 當下對話輸入

## Jev 信心度報告

{proposal_md}

## 原始失敗走跡

```
{state_text}
```

---

**請根據上述 template 的「產出」段，寫 1 段 ≤ 500 字的 LLM relay fix proposal。**
寫完後存到 `{self.relay_dir}/answer.md`（用 `\\\\n` 分隔 3 個子段落）。
"""
        prompt_path = self.relay_dir / "prompt.md"
        prompt_path.write_text(bundle, encoding="utf-8")
        return prompt_path

    def _failed_steps_only(self) -> str:
        """只取失敗步（給 subagent 更聚焦）。"""
        lines = []
        for r in self.run_summary["records"]:
            if r.get("blocked"):
                lines.append(f"  [{r['step_id']}] {r['action']} → BLOCKED ({r['block_reason']})")
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
        return "\n".join(lines) if lines else "(no failed steps)"


# ─── Final Report (v2 拼裝) ──────────────────────────────────────────────

def build_final_report(
    bundle: LLMRelayBundle,
    *,
    llm_answer: str | None = None,
) -> str:
    """組合 v2 final report：v1 信心度報告 + LLM relay 區塊（若有）+ 走跡對照。"""
    run = bundle.run_summary
    parts = [
        bundle.fix_proposal.to_markdown(run),
    ]

    if bundle.gating_pass and llm_answer:
        parts.append(
            "\n---\n\n"
            "## LLM Relay Fix Proposal（M6.1）\n\n"
            f"{llm_answer}\n\n"
            "### 信心度佐證對照\n\n"
            f"- 整體信心度：{bundle.fix_proposal.overall_confidence:.2f}（門檻 {RELAY_GATING_THRESHOLD}）\n"
            f"- Gating：{'✅ 通過' if bundle.gating_pass else '❌ 未通過'}\n"
            f"- 走跡筆數：{sum(1 for r in run['records'] if r.get('oracle') and r['oracle']['verdict'] == 'fail')}\n"
        )
    elif not bundle.gating_pass:
        parts.append(
            "\n---\n\n"
            "## LLM Relay 跳過\n\n"
            f"整體信心度 {bundle.fix_proposal.overall_confidence:.2f} 低於門檻 {RELAY_GATING_THRESHOLD}，"
            "未召喚 LLM relay。\n\n"
            "**下一步**：\n"
            "1. 加 observer context（更多 response 細節）重跑\n"
            "2. 或由 reviewer 直接接手看「原始失敗走跡」段\n"
        )

    parts.append(
        "\n---\n\n"
        "### Prompt Bundle（重跑 LLM relay）\n\n"
        f"`{bundle.relay_dir}/prompt.md` 保留完整 prompt template + 走跡，"
        "可手動召喚 subagent 接力（`fix_proposal_v2.py --answer-from <FILE>`）。\n"
    )
    return "".join(parts)


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: fix_proposal_v2.py <path/to/run-journey.json> [OUTPUT_PATH] [--answer-from FILE]")
        print()
        print("  <run-journey.json>  M3 產出的 JSON")
        print("  [OUTPUT_PATH]       輸出 .md（預設 ./fix_proposal_v2.md）")
        print("  --answer-from FILE  讀 LLM 接力產出（subagent 寫進 .relay/answer.md）")
        print()
        print("環境變量：")
        print("  OPENROUTER_API_KEY   Jev API key")
        print("  JEV_FIX_PROPOSAL=1   啟用")
        return 1

    run_path = Path(argv[1])
    if not run_path.exists():
        print(f"❌ Run JSON 找不到：{run_path}")
        return 1
    run_json = json.loads(run_path.read_text(encoding="utf-8"))

    # parse args
    out_path = Path("./fix_proposal_v2.md")
    answer_from = None
    i = 2
    while i < len(argv):
        if argv[i] == "--answer-from" and i + 1 < len(argv):
            answer_from = Path(argv[i + 1])
            i += 2
        else:
            out_path = Path(argv[i])
            i += 1

    # relay dir
    relay_dir = run_path.parent / RELAY_DIR_NAME
    relay_dir.mkdir(exist_ok=True)

    # 1. 跑 v1 fix_proposal（Jev 信心度）
    print(f"📖 Reading run records: {run_path}")
    print(f"   journey:        {run_json['journey_id']} — {run_json['journey_title']}")
    print()
    try:
        fix_proposal = generate_fix_proposal(run_json)
    except RuntimeError as e:
        print(f"❌ {e}")
        return 1

    overall = fix_proposal.overall_confidence
    gating_pass = overall >= RELAY_GATING_THRESHOLD

    print(f"=== 信心度 ===")
    print(f"  整體: {overall:.2f}  (門檻 {RELAY_GATING_THRESHOLD} → {'✅ 通過召喚' if gating_pass else '❌ 跳過 LLM relay'})")
    print()

    # 2. 組 bundle + 寫 prompt
    bundle = LLMRelayBundle(
        journey_id=run_json['journey_id'],
        journey_title=run_json['journey_title'],
        source_ac=run_json['journey_source'],
        fix_proposal=fix_proposal,
        failed_steps_text="",
        run_summary=run_json,
        gating_pass=gating_pass,
        relay_dir=relay_dir,
    )

    if gating_pass:
        prompt_path = bundle.write_prompt_bundle()
        print(f"📝 Wrote prompt bundle → {prompt_path}  ({prompt_path.stat().st_size} bytes)")
        print(f"   → 召喚 subagent 接力（讀 prompt.md，寫 answer.md）")
        print()

    # 3. 讀 LLM 接力（若有）
    llm_answer = None
    if answer_from and answer_from.exists():
        llm_answer = answer_from.read_text(encoding="utf-8")
        print(f"📖 Read LLM answer: {answer_from}  ({len(llm_answer)} chars)")
    elif gating_pass:
        answer_default = relay_dir / "answer.md"
        if answer_default.exists():
            llm_answer = answer_default.read_text(encoding="utf-8")
            print(f"📖 Read LLM answer: {answer_default}  ({len(llm_answer)} chars)")

    # 4. 寫 final report
    final_md = build_final_report(bundle, llm_answer=llm_answer)
    out_path.write_text(final_md, encoding="utf-8")
    print()
    print(f"📝 Wrote final report → {out_path}  ({out_path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
