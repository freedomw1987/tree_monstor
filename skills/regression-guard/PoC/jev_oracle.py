"""
Jev Oracle — typed decision model 把 AC 文字轉成 verdict。

模型: typesafe/jev-1.13 (透過 OpenRouter)
介面: OpenAI-compatible /chat/completions (tools= 沒有 special 對 Jev 有意義，因 Jev
     output 是 typed decision，不是 function call)
"""

from __future__ import annotations

import json
import os
import time
import hashlib
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

import httpx

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "typesafe/jev-1.13"
CACHE_DIR = Path(__file__).parent / "cache"


# ─── Data shapes ────────────────────────────────────────────────────────────

@dataclass
class ACContext:
    """一條 AC（Given/When/Then）被打包成 Jev 的 state。"""
    ac_id: str
    story_id: str
    given: str
    when: str
    then: str
    additional_and: list[str] = field(default_factory=list)
    # 觀察到的實際結果
    observed_url: str = ""
    observed_status: int = 0
    observed_body_excerpt: str = ""
    observed_user_message: str = ""
    elapsed_ms: int = 0
    history: list[dict] = field(default_factory=list)

    def to_state_json(self) -> str:
        """Jev 的 state 接受 string / object / array；用 string 結構最簡。"""
        return json.dumps(asdict(self), ensure_ascii=False, indent=2)


@dataclass
class JevAnswer:
    """單題答案（Choice / Noul / Score 都包這形狀）。"""
    qid: str
    raw: dict


@dataclass
class OracleResult:
    """一個 AC 跑完 oracle 後的最終評估。"""
    ac_id: str
    verdict: str
    verdict_probs: dict[str, float]
    severity: float
    severity_legend: dict[str, str]
    severity_probs: dict[str, float]
    confidence: float
    model: str
    latency_ms: int
    cached: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


# ─── HTTP / cache 層 ───────────────────────────────────────────────────────

def _cache_key(body: dict) -> str:
    return hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()[:16]


def _load_cache(key: str) -> dict | None:
    p = CACHE_DIR / f"{key}.json"
    if p.exists():
        return json.loads(p.read_text())
    return None


def _save_cache(key: str, payload: dict) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    (CACHE_DIR / f"{key}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2))


def _post_with_retry(url: str, body: dict, headers: dict, *, retries: int = 3) -> dict:
    last_err = None
    for attempt in range(retries):
        try:
            r = httpx.post(url, json=body, headers=headers, timeout=60.0)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(0.5 * (2 ** attempt))
                last_err = f"HTTP {r.status_code}: {r.text[:200]}"
                continue
            r.raise_for_status()
            return r.json()
        except httpx.HTTPError as e:
            last_err = str(e)
            time.sleep(0.5 * (2 ** attempt))
    raise RuntimeError(f"OpenRouter 連線失敗（{retries} 次重試）：{last_err}")


# ─── Jev 呼叫核心 ─────────────────────────────────────────────────────────

# 三題一次 batch call（parallel_questions cookbook 模式）
QUESTIONS_SCHEMA = {
    "verdict": {
        "type": "choice",
        "criteria": {
            "pass": "The observed action cleanly satisfies every clause of the AC `Then`.",
            "fail": "The observed action does NOT satisfy one or more clauses of `Then`.",
            "flaky": "Result depends on timing/network/order; rerun may produce different outcome.",
            "over_assertion": "AC `Then` itself is ambiguous or impossible to verify from observation.",
        },
    },
    "severity": {
        "type": "score",
        "criteria": [
            "Cosmetic: wording, spacing, color",
            "Minor: one extra step needed but reach goal",
            "Major: blocks a happy-path user flow",
            "Critical: data loss, payment error, security",
        ],
    },
    "is_real_bug": {
        "type": "noul",
        "criteria": {
            "yes": "There's a real underlying bug independent of test conditions.",
            "no":  "Outcome is fully explained by environment, fixture, or test order.",
        },
    },
}


def _build_payload(context: ACContext, *, model: str) -> dict:
    return {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a senior QA engineer. Given an acceptance criterion (AC) "
                    "and the observed system state from a user-journey step, decide "
                    "whether the AC was satisfied. Answer three questions at once: "
                    "(1) verdict, (2) severity if it failed, (3) is it a real bug."
                ),
            },
            {
                "role": "user",
                "content": (
                    "Evaluate the following AC against the observed state.\n\n"
                    f"=== AC ({context.ac_id} of {context.story_id}) ===\n"
                    f"Given: {context.given}\n"
                    f"When:  {context.when}\n"
                    f"Then:  {context.then}\n"
                    + ("And:   " + "\nAnd:   ".join(context.additional_and) + "\n" if context.additional_and else "")
                    + "\n"
                    f"=== Observed state ===\n"
                    f"URL:        {context.observed_url}\n"
                    f"Status:     {context.observed_status}\n"
                    f"Body (excerpt): {context.observed_body_excerpt[:300]}\n"
                    f"User-facing message: {context.observed_user_message[:300]}\n"
                    f"Elapsed:    {context.elapsed_ms} ms\n"
                    f"History (last 5): {json.dumps(context.history[-5:], ensure_ascii=False)}\n"
                ),
            },
        ],
        "response_format": {"type": "json_object"},
        "max_tokens": 1024,
    }


def _parse_jev_response(raw: dict) -> tuple[OracleResult | None, dict]:
    """
    從 raw response 抽出三題答案。
    Jev 經由 OpenRouter 走 OpenAI 相容介面時，傾向把 structured decision 收進
    message.content 為一段 JSON 字串（不是 tool_calls，因我們沒下 tools=）。
    """
    content = raw["choices"][0]["message"]["content"].strip()
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        return None, raw

    # Jev 標準 schema：{"answers": {qid: {...}}}
    if "answers" in parsed:
        ans = parsed["answers"]
    elif all(k in parsed for k in ("verdict", "severity", "is_real_bug")):
        ans = parsed
    else:
        return None, raw

    verdict = ans.get("verdict", {})
    severity = ans.get("severity", {})
    is_bug = ans.get("is_real_bug", {})

    return OracleResult(
        ac_id="",
        verdict=verdict.get("choice", "unknown"),
        verdict_probs=verdict.get("probabilities", {}),
        severity=float(severity.get("score", 0)),
        severity_legend=severity.get("legend", {}),
        severity_probs=severity.get("probabilities", {}),
        confidence=float(verdict.get("confidence", severity.get("confidence", 0))),
        model=raw.get("model", "?"),
        latency_ms=0,
    ), raw


# ─── Public API ────────────────────────────────────────────────────────────

def evaluate_ac(context: ACContext, *, model: str = DEFAULT_MODEL,
                use_cache: bool = True) -> OracleResult:
    """主入口：給一條 AC + 觀察結果，回 OracleResult。"""
    body = _build_payload(context, model=model)
    key = _cache_key(body)
    if use_cache:
        c = _load_cache(key)
        if c is not None:
            result, _ = _parse_jev_response(c["raw_response"])
            if result is not None:
                result.ac_id = context.ac_id
                result.cached = True
                return result

    if not os.environ.get("OPENROUTER_API_KEY"):
        raise RuntimeError(
            "Cache miss 且 OPENROUTER_API_KEY 未設定。\n"
            "請 cp .env.example .env 並補 key，或確保 cache/ 內已有 hit。"
        )

    headers = {
        "Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/browser-use/jev-ultrafast",
        "X-Title": "regression-guard-jev-oracle",
    }
    started = time.perf_counter()
    raw = _post_with_retry(OPENROUTER_URL, body, headers)
    latency_ms = int((time.perf_counter() - started) * 1000)

    _save_cache(key, {"raw_response": raw, "context": asdict(context)})
    result, _ = _parse_jev_response(raw)
    if result is None:
        raise RuntimeError(
            "Jev 回傳的格式不是預期 JSON decisions；請看 raw response debug。\n"
            f"raw={json.dumps(raw, ensure_ascii=False)[:800]}"
        )
    result.ac_id = context.ac_id
    result.latency_ms = latency_ms
    return result
