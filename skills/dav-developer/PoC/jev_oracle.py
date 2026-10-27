"""
Jev Oracle — 把 AC 文字 + 觀察結果送給 Jev 跑 typed decision。

模型: typesafe/jev-1.13 (透過 OpenRouter)
介面: POST https://openrouter.ai/api/alpha/decisions
      (不是 /chat/completions！Jev 是 decisions model，不是 chat model)

回應 schema: {"answers": {<qid>: {type, choice/score/noul, probabilities, confidence}}}
"""

from __future__ import annotations

import json
import os
import random
import threading
import time
import hashlib
from dataclasses import dataclass, field, asdict
from pathlib import Path

import httpx

OPENROUTER_URL = "https://openrouter.ai/api/alpha/decisions"
DEFAULT_MODEL = "typesafe/jev-1.13"
# 模型可配置（2026-10-26）：OpenRouter 嘅模型目錄會改（`typesafe/jev-1.13` 已唔喺 catalog，
# 只剩 `typesafe/jev-router`），而**改 code 唔係好方法**（每次 model 退役都要動 source）。
# → 加 `JEV_MODEL` env override：model 退役時用 env 切換就得，唔使改 code。
# ⚠️ 未設 `JEV_MODEL` 時必須**完全等同**舊嘅 "typesafe/jev-1.13" —— 因為 model 字串係
#    cache key 嘅一部分（`_cache_key(body)` 會 hash 整個 body）→ 改咗 model 就成批 cache miss。
def resolve_model(model: str | None = None) -> str:
    """解析實際用嘅 model：顯式參數 > JEV_MODEL env > DEFAULT_MODEL。

    ⚠️ 解析順序刻意把 **env 放喺 DEFAULT_MODEL 之前**：model 退役時 `JEV_MODEL=新名`
       就能即刻切換，唔使改 code；但冇設 env 時行徑同舊版一模一樣（cache key 唔變）。
    """
    return model or os.environ.get("JEV_MODEL") or DEFAULT_MODEL

# 快取目錄（預設 PoC/cache，機器本機 state；不版控）。
# JEV_CACHE_DIR 可覆寫 → 測試用離線 fixture（CI 沒有 API key、也沒有本機快取）。
CACHE_DIR = Path(os.environ.get("JEV_CACHE_DIR") or (Path(__file__).parent / "cache"))

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
    observed_url: str = ""
    observed_status: int = 0
    observed_body_excerpt: str = ""
    observed_user_message: str = ""
    elapsed_ms: int = 0
    history: list[dict] = field(default_factory=list)


@dataclass
class OracleResult:
    ac_id: str
    verdict: str                       # pass / fail / flaky / over_assertion
    verdict_probs: dict[str, float]
    severity: float                    # 0~3
    severity_legend: dict[str, str]
    severity_probs: dict[str, float]
    is_real_bug: float                 # 0~1 (Noul)
    is_real_bug_confidence: float
    confidence: float                  # 主信心（用 verdict 的）
    model: str
    latency_ms: int
    cost_usd: float = 0.0
    cached: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


# ─── HTTP / cache / key loader ────────────────────────────────────────────

def _env_file_candidates() -> list[Path]:
    """回傳「要去哪裡找 OPENROUTER_API_KEY=」的檔案清單。

    `JEV_ENV_FILE` 可覆寫此清單（TMO-045，reviewer P2-B）：設成 `/dev/null` 即等效
    「本機沒有任何 .env」——涵蓋 PoC/.env 與 ~/.claude/... 兩個來源。
    測試靠這個 seam 才能真的排除「本機 .env 掩蓋 fixture 缺口」的假綠。
    """
    override = os.environ.get("JEV_ENV_FILE")
    if override:
        return [Path(override)]
    return [
        Path(__file__).parent / ".env",
        Path.home() / ".claude" / "skills" / "dav-developer" / "PoC" / ".env",
    ]


def _load_api_key() -> str:
    """取得 OpenRouter API key。

    順序：**環境變數** > PoC/.env > ~/.claude/skills/dav-developer/PoC/.env

    ⚠️ **本機嘅正規來源係 `~/.zshrc` 嘅 `export OPENROUTER_API_KEY=...`**（→ 環境變數），
       本 repo 不版控任何 key。兩個 `.env` 檔只係**後備**。
       ⚠️ `~/.zshrc` 只喺**互動** shell 讀 → 非互動 shell（`zsh -c`、CI、IDE task runner、
          另一個 agent session）要用 `~/.zshenv`（zsh 唯一全 shell 都讀嘅檔）。
    檔案來源可用 `JEV_ENV_FILE` 覆寫（見 `_env_file_candidates()`）——測試靠呢個 seam
    排除「本機 .env 掩蓋 fixture 缺口」嘅假綠。
    """
    if k := os.environ.get("OPENROUTER_API_KEY"):
        return k
    candidates = _env_file_candidates()
    for p in candidates:
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("OPENROUTER_API_KEY="):
                    return line.split("=", 1)[1].strip()
    return ""


def _cache_key(body: dict) -> str:
    return hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()[:16]


def _load_cache(key: str) -> dict | None:
    p = CACHE_DIR / f"{key}.json"
    if p.exists():
        return json.loads(p.read_text())
    return None


def _save_cache(key: str, payload: dict) -> None:
    """寫入 cache。

    ⚠️ **原子寫**（2026-10-26）：journey_gen 改成並行後，多個 thread 可能同時寫
       （唔同 key = 唔同檔，所以唔會撞同一個檔），但**讀取方**（另一個並行 thread
       或另一個行程）可能喺 write_text 寫到一半時讀到 → JSON 解析失敗。
       → 寫去 `.tmp` 再 `os.replace`（同一個 filesystem 內 rename 係 atomic）。
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / f"{key}.json"
    tmp = CACHE_DIR / f".{key}.{os.getpid()}.{threading.get_ident()}.tmp"
    try:
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
        os.replace(tmp, target)
    finally:
        # 中途死（例外／中斷）會留殘 .tmp 檔 → 清埋（os.replace 成功後 tmp 已不存在，ignore_errors）
        try:
            tmp.unlink()
        except OSError:
            pass


def _backoff_delay(attempt: int) -> float:
    """指數退避 + 隨機 jitter（0–50%）。

    並行呼叫時（journey_gen 8 路）固定退避會令所有 thread 同一刻重試 → 撞得更狠；
    加 jitter 令重試時序錯開。
    """
    return random.uniform(0, 0.5) * (2 ** attempt) + 0.5 * (2 ** attempt)


def _post_with_retry(url: str, body: dict, headers: dict, *, retries: int = 3) -> dict:
    """POST + 指數退避重試。

    ⚠️ **退避加 jitter**（2026-10-26）：journey_gen 改成 8 路並行後，多個 thread 會
       **同時**撞 429 → 固定退避（0.5/1/2s）會令佢哋**同一刻**再撞一次（撞更狠）。
       → 加隨機 jitter（0–50%），令重試時序錯開。
    """
    last_err = None
    for attempt in range(retries):
        try:
            r = httpx.post(url, json=body, headers=headers, timeout=60.0)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(_backoff_delay(attempt))
                last_err = f"HTTP {r.status_code}: {r.text[:200]}"
                continue
            r.raise_for_status()
            return r.json()
        except httpx.HTTPError as e:
            last_err = str(e)
            time.sleep(_backoff_delay(attempt))
    raise RuntimeError(f"OpenRouter 連線失敗（{retries} 次重試）：{last_err}")


# ─── Jev schema：三題一次 batch ──────────────────────────────────────────

QUESTIONS_SCHEMA = {
    "verdict": {
        "type": "choice",
        "instructions": (
            "Given the AC (Given/When/Then) and the observed state, decide the verdict."
        ),
        "criteria": {
            "pass":           "The observed action cleanly satisfies every clause of the AC `Then`.",
            "fail":           "The observed action does NOT satisfy one or more clauses of `Then`.",
            "flaky":          "Result depends on timing/network/order; rerun may produce different outcome.",
            "over_assertion": "AC `Then` itself is ambiguous or impossible to verify from observation.",
        },
    },
    "severity": {
        "type": "score",
        "instructions": (
            "If the verdict is 'pass', severity should be 0. Otherwise assess impact:"
        ),
        "criteria": [
            "Cosmetic: wording, spacing, color, copy — user can still complete the flow",
            "Minor: one extra step needed but user can still reach goal",
            "Major: blocks a happy-path user flow; user gives up or calls support",
            "Critical: data loss, payment error, security breach, account lockout",
        ],
    },
    "is_real_bug": {
        "type": "noul",
        "instructions": (
            "Does this observed failure indicate a real underlying bug in the application, "
            "independent of test environment, fixtures, or test ordering? true = real bug, false = artifact."
        ),
        "criteria": {
            "true":  "There's a real underlying bug in the application code.",
            "false": "Outcome is fully explained by environment, fixture, or test order.",
        },
    },
}


def _state_text(context: ACContext) -> str:
    """把 ACContext 變成 Jev state string。"""
    lines = [
        f"=== AC ({context.ac_id} of {context.story_id}) ===",
        f"Given: {context.given}",
        f"When:  {context.when}",
        f"Then:  {context.then}",
    ]
    if context.additional_and:
        lines.append("And:   " + "\nAnd:   ".join(context.additional_and))
    lines.append("")
    lines.append("=== Observed state ===")
    lines.append(f"URL:                {context.observed_url}")
    lines.append(f"Status:             {context.observed_status}")
    lines.append(f"Body excerpt:       {context.observed_body_excerpt[:300]}")
    lines.append(f"User-facing msg:    {context.observed_user_message[:300]}")
    lines.append(f"Elapsed:            {context.elapsed_ms} ms")
    if context.history:
        lines.append(f"History (last 5):   {json.dumps(context.history[-5:], ensure_ascii=False)}")
    return "\n".join(lines)


def _build_payload(context: ACContext, *, model: str) -> dict:
    return {
        "model": model,
        "state": _state_text(context),
        "questions": QUESTIONS_SCHEMA,
    }


def _parse_jev_response(raw: dict) -> OracleResult:
    """從 raw response 抽出三題答案，組出 OracleResult。"""
    answers = raw.get("answers", {})
    verdict = answers.get("verdict", {})
    severity = answers.get("severity", {})
    is_bug = answers.get("is_real_bug", {})
    usage = raw.get("usage", {})

    return OracleResult(
        ac_id="",
        verdict=verdict.get("choice", "unknown"),
        verdict_probs=verdict.get("probabilities", {}),
        severity=float(severity.get("score", 0)),
        severity_legend=severity.get("legend", {}),
        severity_probs=severity.get("probabilities", {}),
        is_real_bug=float(is_bug.get("noul", 0)),
        is_real_bug_confidence=float(is_bug.get("confidence", 0)),
        confidence=float(verdict.get("confidence", 0)),
        model=raw.get("model", "?"),
        latency_ms=0,
        cost_usd=float(usage.get("cost", 0)),
    )


# ─── Public API ────────────────────────────────────────────────────────────

def evaluate_ac(context: ACContext, *, model: str | None = None,
                use_cache: bool = True) -> OracleResult:
    """主入口：給一條 AC + 觀察結果，回 OracleResult。"""
    model = resolve_model(model)
    body = _build_payload(context, model=model)
    key = _cache_key(body)
    if use_cache:
        c = _load_cache(key)
        if c is not None:
            result = _parse_jev_response(c["raw_response"])
            result.ac_id = context.ac_id
            result.cached = True
            return result

    api_key = _load_api_key()
    if not api_key:
        raise RuntimeError(
            "Cache miss 且 OPENROUTER_API_KEY 找不到。請：\n"
            "  1. cp PoC/.env.example PoC/.env && 編輯補 key\n"
            "  或 2. set OPENROUTER_API_KEY env\n"
            "  或 3. 放 ~/.claude/skills/dav-developer/PoC/.env"
        )

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/browser-use/jev-ultrafast",
        "X-Title": "dav-developer-jev-oracle",
    }
    started = time.perf_counter()
    raw = _post_with_retry(OPENROUTER_URL, body, headers)
    latency_ms = int((time.perf_counter() - started) * 1000)

    _save_cache(key, {"raw_response": raw, "context": asdict(context)})
    result = _parse_jev_response(raw)
    result.ac_id = context.ac_id
    result.latency_ms = latency_ms
    return result
