"""
Journey Runner (Dry-Run) — 跑 journey YAML → 每步 mock observe → Jev oracle → verdict。

不接 Chrome、不接 httpx。重點：證明 observe→choose→act→recheck 迴路 + stale detection。

用法:
    .venv/bin/python journey_runner.py journeys/US-101.yaml
"""

from __future__ import annotations

import json
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

import yaml

from ac_schema import parse_story_file
from jev_oracle import evaluate_ac, ACContext, OracleResult
from journey_generator import Journey, Step, JOURNEYS_DIR

THIS_DIR = Path(__file__).parent


# ─── Mock observer — 模擬按 step action 後系統狀態 ───────────────────────

@dataclass
class ObservedState:
    url: str
    status: int
    body_excerpt: str = ""
    user_message: str = ""
    elapsed_ms: int = 0
    history: list[dict] = field(default_factory=list)


def mock_observe(step: Step, prev: ObservedState | None) -> ObservedState:
    """
    乾跑模擬：根據 step.action 回一個假的觀察。
    真實版（M3.1+）會用 Chrome remote debug 或 Playwright 取代這個。
    注意：sig 會隨 action 變（點擊 / 跳轉都改 URL）— stale-test 另用 mock_observe_static。
    """
    base_url = prev.url if prev else "https://example.com"
    elapsed = 500 + (hash(step.id) % 1500)

    if step.action == "setup_state":
        return ObservedState(
            url=base_url,
            status=200,
            body_excerpt=f"[setup] 進入準備狀態 {step.verifying_ac}",
            elapsed_ms=elapsed,
            history=(prev.history if prev else []) + [{"step": step.id, "state": "setup"}],
        )
    if step.action == "navigate":
        return ObservedState(
            url=step.target or f"{base_url}/navigated",
            status=200,
            body_excerpt=f"[navigate] 到達 {step.target}",
            elapsed_ms=elapsed,
            history=(prev.history if prev else []) + [{"step": step.id, "url": step.target}],
        )
    if step.action == "click":
        return ObservedState(
            url=f"{base_url}/clicked-{step.target_text or 'button'}",
            status=200,
            body_excerpt=f"[click] 點擊「{step.target_text}」",
            elapsed_ms=elapsed,
            history=(prev.history if prev else []) + [{"step": step.id, "clicked": step.target_text}],
        )
    if step.action == "type":
        return ObservedState(
            url=base_url,
            status=200,
            body_excerpt=f"[type] 輸入「{step.value}」到 {step.target}",
            elapsed_ms=elapsed,
            history=(prev.history if prev else []) + [{"step": step.id, "typed": step.value}],
        )
    if step.action == "wait":
        return ObservedState(
            url=base_url,
            status=200,
            body_excerpt=f"[wait] 等待 {step.timeout_ms}ms",
            elapsed_ms=step.timeout_ms,
            history=(prev.history if prev else []) + [{"step": step.id, "waited": step.timeout_ms}],
        )
    if step.action == "observe":
        return ObservedState(
            url=base_url,
            status=200,
            body_excerpt=f"[observe] 觀察到 current state",
            elapsed_ms=elapsed,
            history=(prev.history if prev else []) + [{"step": step.id, "observed": True}],
        )
    # default
    return ObservedState(url=base_url, status=200, elapsed_ms=elapsed)


def mock_observe_static(step: Step, prev: ObservedState | None) -> ObservedState:
    """stale-test 專用：不論 step 為何都回相同 ObservedState（force 觸發 stale detection）。
    M5 後因為 stale 限「同一 AC」+ AC 內可能只有 2 步，static observer 是唯一保證
    stale_test 一定會觸發 block 的方式。
    """
    return ObservedState(
        url="https://example.com/frozen",
        status=500,
        body_excerpt="[stale-test] 全步同 state 為驗證 stale detection",
        elapsed_ms=1000,
        history=(prev.history if prev else []) + [{"step": step.id, "static": True}],
    )


# ─── AC-aware fixture loader（config-driven, M5 重構） ────────────────────

def _load_fixture(story_id: str) -> dict[str, dict]:
    """從 fixtures/<story_id>.yaml 讀 AC-aware fixture。
    找不到就 fallback 到內建 minimal defaults（所有 AC 回 200 頁）。
    """
    fixture_path = THIS_DIR / "fixtures" / f"{story_id}.yaml"
    if fixture_path.exists():
        return yaml.safe_load(fixture_path.read_text(encoding="utf-8")) or {}
    # fallback: 所有 AC 回 200 頁（oracle 會看 body_excerpt 判 fail）
    return {}


def _get_fixture_for_ac(fixtures: dict, ac_id: str) -> dict:
    """抓對應 AC 的 fixture；fallback 空 dict（observe 會用 base_url）。"""
    return fixtures.get(ac_id, {})


def ac_aware_observe(step: Step, prev: ObservedState | None, story_id: str = "") -> ObservedState:
    """比 mock_observe 聰明：用 AC-aware fixture 模擬「對應 AC 通過時」應該看到的 state。
    M5：fixture 從 fixtures/<story_id>.yaml 讀（config-driven）。"""
    base_url = prev.url if prev else "https://example.com"
    elapsed = 500 + (hash(step.id) % 1500)
    fixtures = _load_fixture(story_id) if story_id else {}
    fixture = _get_fixture_for_ac(fixtures, step.verifying_ac)

    if step.action == "setup_state":
        return ObservedState(
            url=fixture.get("url", base_url),
            status=fixture.get("status", 200),
            body_excerpt=f"[setup for {step.verifying_ac}] " + fixture.get("body_excerpt", "")[:150],
            elapsed_ms=fixture.get("elapsed_ms", elapsed),
            history=(prev.history if prev else []) + [{"step": step.id, "state": "setup"}],
        )

    if step.action == "click":
        return ObservedState(
            url=fixture.get("url", f"{base_url}/clicked-button"),
            status=fixture.get("status", 200),
            body_excerpt=fixture.get("body_excerpt", f"[click 結帳] → {fixture.get('url')}"),
            elapsed_ms=fixture.get("elapsed_ms", elapsed),
            history=(prev.history if prev else []) + [{"step": step.id, "clicked": step.target_text}],
        )

    if step.action == "type":
        # AC02：輸入錯誤卡號應顯示紅字。但 mock fixture 沒寫這個 state 的紅字。
        # 用一個「不完整」的 body_excerpt 讓 oracle 判 fail（這就是 dry-run 想知道的事）。
        return ObservedState(
            url=fixture.get("url", base_url),
            status=fixture.get("status", 200),
            body_excerpt=fixture.get("body_excerpt", ""),  # 沒有「紅字錯誤」訊息
            elapsed_ms=fixture.get("elapsed_ms", elapsed),
            history=(prev.history if prev else []) + [{"step": step.id, "typed": step.value}],
        )

    if step.action == "wait":
        return ObservedState(
            url=fixture.get("url", base_url),
            status=fixture.get("status", 200),
            body_excerpt=fixture.get("body_excerpt", ""),
            elapsed_ms=fixture.get("elapsed_ms", step.timeout_ms),
            history=(prev.history if prev else []) + fixture.get("history_seed", []) + [{"step": step.id, "waited": step.timeout_ms}],
        )

    if step.action == "observe":
        return ObservedState(
            url=fixture.get("url", base_url),
            status=fixture.get("status", 200),
            body_excerpt=fixture.get("body_excerpt", ""),
            elapsed_ms=fixture.get("elapsed_ms", elapsed),
            history=(prev.history if prev else []) + [{"step": step.id, "observed": True}],
        )

    if step.action == "navigate":
        return ObservedState(
            url=step.target or fixture.get("url", base_url),
            status=fixture.get("status", 200),
            body_excerpt=fixture.get("body_excerpt", ""),
            elapsed_ms=fixture.get("elapsed_ms", elapsed),
            history=(prev.history if prev else []) + [{"step": step.id, "url": step.target}],
        )

    return ObservedState(url=base_url, status=200, elapsed_ms=elapsed)


def mock_observed_to_ac_context(ac, step: Step, observed: ObservedState) -> ACContext:
    """把 mock observed 轉成 ACContext 餵給 oracle。"""
    return ACContext(
        ac_id=ac.ac_id,
        story_id=ac.story_id,
        given=ac.given,
        when=ac.when,
        then=ac.then,
        additional_and=ac.additional_and,
        observed_url=observed.url,
        observed_status=observed.status,
        observed_body_excerpt=observed.body_excerpt,
        observed_user_message=observed.user_message,
        elapsed_ms=observed.elapsed_ms,
        history=observed.history,
    )


# ─── Stale detection（jev-ultrafast 概念移植） ────────────────────────────

def _state_signature(observed: ObservedState) -> str:
    """用 url + status + body 前 100 字當指紋。"""
    return f"{observed.url}|{observed.status}|{observed.body_excerpt[:100]}"


def _state_signature_strict(observed: ObservedState) -> str:
    """更厳的指紋：只含 url + status。
    適用於 stale detection — body 不重要，只看「頁面是否還是同一個」。"""
    return f"{observed.url}|{observed.status}"


@dataclass
class StepRecord:
    step_id: str
    action: str
    verifying_ac: str
    observed: ObservedState
    oracle: OracleResult | None
    blocked: bool = False
    block_reason: str = ""


# ─── 主迴路 ──────────────────────────────────────────────────────────────

def run_journey(journey: Journey, story_acs: list, *,
                stale_threshold: int = 3, story_id: str = "") -> tuple[list[StepRecord], dict]:
    """
    跑整個 journey。
    - story_acs: 從 parse_story_file 拿來的 AC 列表（用 ac_id 查詢）
    - stale_threshold: 連續幾次同 state 視為 block
    - story_id: M5 新增，傳給 ac_aware_observe 用來載 fixture YAML
    """
    ac_by_id = {ac.ac_id: ac for ac in story_acs}

    records: list[StepRecord] = []
    prev_signature: str | None = None
    consecutive_stale = 0
    blocked = False
    block_reason = ""
    current_ac_id: str | None = None  # M5：限 stale 計數於同一 AC

    for step in journey.steps:
        if blocked:
            # 已被 block，後續只記錄不執行
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=ObservedState(url="", status=0),
                oracle=None, blocked=True, block_reason="journey blocked earlier",
            ))
            continue

        # 1. Observe（用 AC-aware fixture 模擬）
        prev_observed = records[-1].observed if records and records[-1].observed else None
        observed = ac_aware_observe(step, prev_observed, story_id=story_id)
        sig = _state_signature_strict(observed)

        # 2. Stale detection（只在 ac 是 fail 時介入，正常過就不卡）
        ac = ac_by_id.get(step.verifying_ac)
        if ac is None:
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=observed, oracle=None, blocked=True,
                block_reason=f"verifying_ac {step.verifying_ac} not found",
            ))
            blocked = True
            block_reason = f"AC {step.verifying_ac} not found in story"
            continue

        # 3. Oracle
        ctx = mock_observed_to_ac_context(ac, step, observed)
        try:
            oracle_result = evaluate_ac(ctx, use_cache=True)
        except Exception as e:
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=observed, oracle=None, blocked=True,
                block_reason=f"oracle failed: {e}",
            ))
            blocked = True
            block_reason = f"oracle call failed: {e}"
            continue

        # 4. Stale check（M5：限「同一 AC」連續 fail）
        # 邏輯：進 step 前先看 ac_id 有沒有換；換了就 reset counter
        same_ac = (current_ac_id == step.verifying_ac)
        current_ac_id = step.verifying_ac
        if not same_ac:
            consecutive_stale = 0  # 換 AC，counter 重設
            prev_signature = None

        if oracle_result.verdict == "fail" and sig == prev_signature:
            consecutive_stale += 1
            if consecutive_stale >= stale_threshold:
                records.append(StepRecord(
                    step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                    observed=observed, oracle=oracle_result, blocked=True,
                    block_reason=f"consecutive_stale={consecutive_stale} ≥ {stale_threshold} (ac={step.verifying_ac})",
                ))
                blocked = True
                block_reason = f"consecutive stale state for {consecutive_stale} steps (ac={step.verifying_ac})"
                continue
        else:
            consecutive_stale = 0

        prev_signature = sig

        records.append(StepRecord(
            step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
            observed=observed, oracle=oracle_result,
        ))

    summary = {
        "total_steps": len(records),
        "blocked": blocked,
        "block_reason": block_reason,
        "verdict_counts": _count_verdicts(records),
        "total_latency_ms": sum(r.oracle.latency_ms for r in records if r.oracle),
        "total_cost_usd": sum(r.oracle.cost_usd for r in records if r.oracle),
        "cache_hits": sum(1 for r in records if r.oracle and r.oracle.cached),
    }
    return records, summary


# ─── run_dry：stale-test 與 default test 的統一入口（M5 重構） ────────────

def run_dry(journey: Journey, story_acs: list, *, stale_test: bool = False,
            story_id: str = "", stale_threshold: int = 3) -> tuple[list[StepRecord], dict]:
    """
    統一 dry-run 入口。

    - stale_test=False（預設）：用 AC-aware fixture（從 fixtures/<story_id>.yaml 讀）
    - stale_test=True：用粗糙 mock_observe（同 state）來驗證 stale detection 邏輯。
                    因為 M5 後 stale 限「同一 AC」（單一 AC 通常只有 2 步），
                    stale-test 模式自動把 threshold 降為 2。

    兩種模式都共用 stale detection 機制、AC-aware 限定（M5）。
    """
    if stale_test:
        # stale-test 下 threshold 強制 2（保證能觸發 block 以驗證邏輯）
        effective_threshold = min(stale_threshold, 2)
        records, summary = _run_dry_stale_test(journey, story_acs, stale_threshold=effective_threshold)
    else:
        records, summary = run_journey(journey, story_acs, story_id=story_id, stale_threshold=stale_threshold)
    return records, summary


def _run_dry_stale_test(journey: Journey, story_acs: list, *,
                        stale_threshold: int = 3) -> tuple[list[StepRecord], dict]:
    """
    Stale-test 模式：用 mock_observe（所有 step 同 state）證 stale detection 邏輯。
    重點：跨 AC 不誤判（M5 — consecutive_stale 只計同 AC）。
    """
    from jev_oracle import evaluate_ac

    ac_by_id = {ac.ac_id: ac for ac in story_acs}
    records: list[StepRecord] = []
    prev_signature: str | None = None
    consecutive_stale = 0
    blocked = False
    block_reason = ""
    current_ac_id: str | None = None  # M5：限 stale 計數於同一 AC

    for step in journey.steps:
        if blocked:
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=mock_observe_static(step, None), oracle=None, blocked=True,
                block_reason="blocked earlier",
            ))
            continue

        observed = mock_observe_static(step, None)
        sig = _state_signature_strict(observed)
        ac = ac_by_id.get(step.verifying_ac)
        if ac is None:
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=observed, oracle=None, blocked=True, block_reason="AC not found",
            ))
            blocked = True
            continue

        # M5：換 AC 就 reset counter
        same_ac = (current_ac_id == step.verifying_ac)
        current_ac_id = step.verifying_ac
        if not same_ac:
            consecutive_stale = 0
            prev_signature = None

        ctx = mock_observed_to_ac_context(ac, step, observed)
        try:
            oracle_result = evaluate_ac(ctx, use_cache=True)
        except Exception as e:
            records.append(StepRecord(
                step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                observed=observed, oracle=None, blocked=True,
                block_reason=f"oracle failed: {e}",
            ))
            blocked = True
            block_reason = f"oracle call failed: {e}"
            continue

        if oracle_result.verdict == "fail" and sig == prev_signature:
            consecutive_stale += 1
            if consecutive_stale >= stale_threshold:
                records.append(StepRecord(
                    step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
                    observed=observed, oracle=oracle_result, blocked=True,
                    block_reason=f"stale={consecutive_stale} (ac={step.verifying_ac})",
                ))
                blocked = True
                block_reason = f"stale {consecutive_stale}"
                continue
        else:
            consecutive_stale = 0

        prev_signature = sig
        records.append(StepRecord(
            step_id=step.id, action=step.action, verifying_ac=step.verifying_ac,
            observed=observed, oracle=oracle_result,
        ))

    summary = {
        "total_steps": len(records),
        "blocked": blocked,
        "block_reason": block_reason,
        "verdict_counts": _count_verdicts(records),
        "total_latency_ms": sum(r.oracle.latency_ms for r in records if r.oracle),
        "total_cost_usd": sum(r.oracle.cost_usd for r in records if r.oracle),
        "cache_hits": sum(1 for r in records if r.oracle and r.oracle.cached),
    }
    return records, summary


def _count_verdicts(records: list[StepRecord]) -> dict[str, int]:
    from collections import Counter
    return dict(Counter(
        r.oracle.verdict for r in records if r.oracle
    ))
