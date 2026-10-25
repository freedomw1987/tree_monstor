"""
Journey Generator — 從 AC 文字用 Jev 自動生成 user journey YAML。

兩個 Jev call 對每條 AC：
1. complexity_score (0-3): 0=直接驗證單一動作, 1=兩個動作, 2=三個動作, 3=多個狀態前置+動作+驗證
2. action_plan (choice): 對每個 step 選 navigate / click / type / setup_state / wait / observe

output: 一個 yaml 檔寫進 journeys/<story_id>.yaml
"""

from __future__ import annotations

import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field, asdict
from pathlib import Path

import httpx
import yaml

from jev_oracle import (
    _load_api_key, _post_with_retry, OPENROUTER_URL,
    _cache_key, _save_cache, _load_cache, resolve_model,
)

THIS_DIR = Path(__file__).parent
JOURNEYS_DIR = THIS_DIR / "journeys"


# ─── Journey spec 結構 ─────────────────────────────────────────────────────

@dataclass
class Step:
    id: str                       # "step-1", "step-2"...
    action: str                   # navigate / click / type / setup_state / wait / observe / assert_text
    target: str = ""              # URL / element id / text to type
    target_text: str = ""         # if click: button text
    value: str = ""               # if type: value
    expected_url: str = ""        # if navigate: expected URL pattern
    expected_text: str = ""       # if assert_text
    timeout_ms: int = 3000
    verifying_ac: str = ""        # US-101-AC01
    verifying_then: str = ""      # 對應 Then clause
    depends_on: list[str] = field(default_factory=list)  # step ids


@dataclass
class Journey:
    journey_id: str
    title: str
    source: str                   # path to source AC file
    generated_by: str
    generated_at: str             # ISO
    total_steps: int
    steps: list[Step] = field(default_factory=list)
    meta: dict = field(default_factory=dict)

    def to_yaml(self, path: Path | None = None) -> str:
        d = asdict(self)
        txt = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, default_flow_style=False)
        if path:
            JOURNEYS_DIR.mkdir(parents=True, exist_ok=True)
            path.write_text(txt, encoding="utf-8")
        return txt


# ─── Jev call 1: complexity score ──────────────────────────────────────────

COMPLEXITY_QUESTION = {
    "complexity": {
        "type": "score",
        "instructions": (
            "Given an AC (Given/When/Then), how many discrete user actions "
            "or setup steps does it imply? 0=just observe a state (no action), "
            "1=one action needed (click or navigate), 2=two actions (e.g. click + type), "
            "3=three or more actions or complex multi-step setup."
        ),
        "criteria": [
            "0 actions: just verify current state",
            "1 action: single navigate / click / type",
            "2 actions: click + type, or navigate + observe",
            "3+ actions: setup + multi-step interaction + verify",
        ],
    },
}

ACTION_PLAN_QUESTION = {
    "action_plan": {
        "type": "choice",
        "instructions": (
            "What is the PRIMARY action implied by this AC? Pick the dominant user gesture."
        ),
        "criteria": {
            "navigate":     "AC mainly drives navigation between pages",
            "click":        "AC mainly involves clicking a button or link",
            "type":         "AC mainly involves typing text into a field",
            "setup_state":  "AC requires preconditions (login, cart, fixtures) before action",
            "wait":         "AC mainly tests timing/async (wait for response, polling)",
            "observe":      "AC verifies a state without explicit user action",
            "assert_text":  "AC verifies specific text appears on page",
            "multi_step":   "AC clearly requires 3+ sequential steps",
        },
    },
}


def _state_for_ac(story_id: str, ac) -> str:
    lines = [
        f"=== AC {ac.ac_id} of {story_id} ===",
        f"Given: {ac.given}",
        f"When:  {ac.when}",
        f"Then:  {ac.then}",
    ]
    if ac.additional_and:
        lines.append("And:   " + "\nAnd:   ".join(ac.additional_and))
    return "\n".join(lines)


def _ask_jev_single_question(state: str, questions: dict, model: str, ctx_label: str) -> dict:
    """對一個 question 跑 Jev，cache-first。"""
    body = {
        "model": model,
        "state": state,
        "questions": questions,
    }
    key = _cache_key(body)
    if (c := _load_cache(key)) is not None:
        c["cached"] = True
        return c

    api_key = _load_api_key()
    if not api_key:
        raise RuntimeError(f"Cache miss {ctx_label} 且無 API key")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/browser-use/jev-ultrafast",
        "X-Title": "regression-guard-journey-gen",
    }
    started = time.perf_counter()
    raw = _post_with_retry(OPENROUTER_URL, body, headers)
    latency = int((time.perf_counter() - started) * 1000)

    payload = {"raw_response": raw, "latency_ms": latency, "cached": False}
    _save_cache(key, payload)
    return payload


def generate_journey(story, *, model: str | None = None,
                     max_workers: int = 8) -> Journey:
    """
    主入口：對一個 ParsedStory 跑 Jev 兩階段 → 產 Journey。

    **並行化（2026-10-26）**：原本每條 AC 嘅 complexity + action_plan 兩個 call
    **完全串行**跑 → 4 條 AC = 8 個 round trip（實測 US-M63：8 個 call 合計 **43.4 秒**，
    單個 call 慢到 14 秒）。但呢 8 個 call **互相獨立**（每個只依賴自己嗰條 AC 嘅
    Given/When/Then）→ 可以全部並行 → 總時間由「各個 latency 加埋」變成「最慢嗰個」。

    ⚠️ **唔改 payload 形狀** —— model / state / questions 三個欄位同改前逐字一樣
       → `_cache_key()` 出嚟嘅 key 唔變 → 既有 cache 仍然命中（離線可驗證）。
       （唔好用「一個 request 問兩條題」嘅 batch 方案：嗰個會改 payload → 成批 cache miss。）

    `meta["calls"]` 嘅**順序保持不變**（AC 順序，每條 AC 先 complexity 後 action_plan），
    即係並行化唔影響 journey YAML 嘅可重現性。
    """
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    model = resolve_model(model)

    # ── 1. 先列齊所有 call 規格（呢個順序 = 輸出順序）──
    specs: list[tuple] = []
    for ac in story.acs:
        state = _state_for_ac(story.story_id, ac)
        specs.append((ac, "complexity", state, COMPLEXITY_QUESTION, f"complexity/{ac.ac_id}"))
        specs.append((ac, "action_plan", state, ACTION_PLAN_QUESTION, f"action/{ac.ac_id}"))

    # ── 2. 並行跑（每個 call 獨立；唯一共享資源係 cache 目录，唔同 key = 唔同檔）──
    results: dict[tuple[str, str], dict] = {}
    errors: list[tuple[str, BaseException]] = []
    if specs:
        with ThreadPoolExecutor(max_workers=max(1, min(max_workers, len(specs)))) as ex:
            futures = {
                ex.submit(_ask_jev_single_question, state, q, model, label): (ac.ac_id, phase)
                for ac, phase, state, q, label in specs
            }
            for fut in as_completed(futures):
                key = futures[fut]
                try:
                    results[key] = fut.result()
                except Exception as e:   # noqa: BLE001 — 收集全部錯誤先報；
                                          # ⚠️ 唔用 BaseException（會包埋 KeyboardInterrupt）
                    errors.append((f"{key[0]}/{key[1]}", e))
    if errors:
        detail = "; ".join(f"{k}: {e}" for k, e in errors)
        raise RuntimeError(f"Jev call 失敗（{len(errors)}/{len(specs)} 個）：{detail}")

    # ── 3. 依原順序組出 steps + meta ──
    steps: list[Step] = []
    meta = {
        "story_id": story.story_id,
        "title": story.title,
        "ac_count": len(story.acs),
        "calls": [],
    }

    for ac in story.acs:
        # Call 1: complexity
        c1 = results[(ac.ac_id, "complexity")]
        meta["calls"].append({
            "ac_id": ac.ac_id, "phase": "complexity",
            "latency_ms": c1.get("latency_ms", 0),
            "cached": c1.get("cached", False),
            "score": c1["raw_response"]["answers"]["complexity"]["score"],
        })
        complexity = round(c1["raw_response"]["answers"]["complexity"]["score"])
        complexity = max(0, min(3, complexity))

        # Call 2: action plan
        c2 = results[(ac.ac_id, "action_plan")]
        meta["calls"].append({
            "ac_id": ac.ac_id, "phase": "action_plan",
            "latency_ms": c2.get("latency_ms", 0),
            "cached": c2.get("cached", False),
            "choice": c2["raw_response"]["answers"]["action_plan"]["choice"],
        })
        action = c2["raw_response"]["answers"]["action_plan"]["choice"]

        # 依 complexity 拆步
        step_count = complexity + 1  # 0→1, 1→2, 2→3, 3→4
        for i in range(step_count):
            sid = f"{ac.ac_id}-s{i+1}"
            depends: list[str] = []
            if i > 0:
                # 同 AC 的前一步
                depends.append(f"{ac.ac_id}-s{i}")
            elif steps and steps[-1].verifying_ac != ac.ac_id:
                # 第一個 step 跨 AC 串連到上一個 AC 的最後 step
                depends.append(steps[-1].id)
            step = Step(
                id=sid,
                action=action if i == step_count - 1 else "setup_state",
                verifying_ac=ac.ac_id,
                verifying_then=ac.then,
                depends_on=depends,
            )
            steps.append(step)

    journey = Journey(
        journey_id=story.story_id,
        title=story.title,
        source=str(story.file),
        generated_by=model,
        generated_at=now,
        total_steps=len(steps),
        steps=steps,
        meta=meta,
    )
    return journey
