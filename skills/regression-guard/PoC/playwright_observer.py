"""
Playwright Observer — M3.1：把 mock observer 升級成 headless Chrome driver。

設計原則：
1. **lazy import playwright**：沒裝 playwright 也能 import 此模組（不破壞現有 PoC）
2. **介面對齊 ac_aware_observe**：(step, prev, story_id) -> ObservedState
3. **DOM snapshot 作為 body_excerpt**：oracle 仍能根據 body_excerpt 跟 AC Then 比對
4. **失敗 graceful fallback**：driver 出錯時 body_excerpt 帶錯誤訊息，oracle 仍可判 fail

啟用方式：
    export OBSERVER_BACKEND=playwright
    .venv/bin/python run_journey.py journeys/US-101.yaml

M3.1 範圍：
- ✅ 5 個 action 實作（navigate / click / type / wait / observe）
- ✅ 單 browser instance 共用（不每 step 開新 page）
- ✅ DOM snapshot 摘要（取 main / body 文字 + 互動元素清單）
- ⏸ 真實跑 example.com（不在本 sprint 範圍，留 M3.2 / 真實 US）
"""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import TYPE_CHECKING

from journey_runner import ObservedState

if TYPE_CHECKING:
    from journey_generator import Step


# ─── 環境配置 ────────────────────────────────────────────────────────────

DEFAULT_TIMEOUT_MS = 3000
VIEWPORT = {"width": 1280, "height": 720}
USER_AGENT = "regression-guard-jev-poc/3.1"


def _is_playwright_available() -> bool:
    """檢查 playwright 是否有裝。沒裝就不能用這個 backend。"""
    try:
        import playwright  # noqa: F401
        return True
    except ImportError:
        return False


# ─── DOM snapshot 摘要 ────────────────────────────────────────────────────

def _snapshot_dom(page, max_chars: int = 600) -> str:
    """從 Playwright page 抓 DOM 結構化摘要，給 oracle 看。
    重點：text content + 互動元素清單，刻意不抓全 HTML（避免長度爆）。
    """
    try:
        # 主要文字（main > article > body fallback）
        main_text = page.evaluate("""
            () => {
                const main = document.querySelector('main, article, [role="main"]')
                          || document.body;
                if (!main) return '';
                return (main.innerText || main.textContent || '').trim();
            }
        """)
        # 互動元素清單（按鈕 / 輸入 / 連結）
        interactive = page.evaluate("""
            () => {
                const items = [];
                document.querySelectorAll('button, input, a, select, textarea').forEach(el => {
                    const tag = el.tagName.toLowerCase();
                    const text = (el.innerText || el.value || el.placeholder || el.name || '').trim();
                    const type_ = el.getAttribute('type') || '';
                    if (text || tag === 'input' || tag === 'textarea') {
                        items.push(`${tag}${type_ ? '['+type_+']' : ''}: ${text.slice(0, 50)}`);
                    }
                });
                return items.slice(0, 20);
            }
        """)
        snapshot = main_text[:max_chars]
        if interactive:
            snapshot += "\n\n[互動元素]\n" + "\n".join(f"  - {item}" for item in interactive)
        return snapshot or "(空頁面)"
    except Exception as e:
        return f"[snapshot error: {type(e).__name__}: {e}]"


# ─── Browser context 管理 ─────────────────────────────────────────────────

class PlaywrightSession:
    """共用一個 browser + context，steps 共用同一 page。
    第一次 observe 時 lazy 啟動；close() 由 caller 負責（M3.1 簡化版：process 結束自動關）。"""

    def __init__(self, headless: bool = True):
        self._headless = headless
        self._browser = None
        self._context = None
        self._page = None
        self._started_at: float = 0.0

    def _ensure_started(self) -> None:
        if self._page is not None:
            return
        # Lazy import：沒裝 playwright 會在這裡 raise
        from playwright.sync_api import sync_playwright
        self._started_at = time.perf_counter()
        pw = sync_playwright().start()
        self._browser = pw.chromium.launch(headless=self._headless)
        self._context = self._browser.new_context(
            viewport=VIEWPORT,
            user_agent=USER_AGENT,
        )
        self._page = self._context.new_page()
        self._page.set_default_timeout(DEFAULT_TIMEOUT_MS)

    def page(self):
        self._ensure_started()
        return self._page

    def close(self) -> None:
        try:
            if self._context:
                self._context.close()
            if self._browser:
                self._browser.close()
        except Exception:
            pass
        self._page = None
        self._context = None
        self._browser = None

    @property
    def started(self) -> bool:
        return self._page is not None


# 全域 session（M3.1 簡化：process 共用一個瀏覽器）
_session: PlaywrightSession | None = None


def get_session() -> PlaywrightSession:
    global _session
    if _session is None:
        _session = PlaywrightSession()
    return _session


# ─── Action 實作 ──────────────────────────────────────────────────────────

def _do_navigate(step: "Step") -> ObservedState:
    """navigate: 開新 URL"""
    page = get_session().page()
    started = time.perf_counter()
    if not step.target:
        return _err_state("navigate", "missing step.target URL")
    try:
        response = page.goto(step.target, wait_until="domcontentloaded", timeout=DEFAULT_TIMEOUT_MS)
        status = response.status if response else 0
    except Exception as e:
        return _err_state("navigate", f"{type(e).__name__}: {e}")
    elapsed = int((time.perf_counter() - started) * 1000)
    return ObservedState(
        url=page.url,
        status=status,
        body_excerpt=_snapshot_dom(page),
        elapsed_ms=elapsed,
        history=[{"step": step.id, "action": "navigate", "to": step.target}],
    )


def _do_click(step: "Step") -> ObservedState:
    """click: 點按鈕（用 text / selector）"""
    page = get_session().page()
    started = time.perf_counter()
    if not (step.target or step.target_text):
        return _err_state("click", "missing step.target or step.target_text")
    selector = step.target or f"text={step.target_text}"
    try:
        page.click(selector, timeout=DEFAULT_TIMEOUT_MS)
    except Exception as e:
        return _err_state("click", f"{type(e).__name__}: {e} (selector={selector})")
    elapsed = int((time.perf_counter() - started) * 1000)
    return ObservedState(
        url=page.url,
        status=200,  # Playwright 不直接給 status（response 才有），簡化
        body_excerpt=_snapshot_dom(page),
        elapsed_ms=elapsed,
        history=[{"step": step.id, "action": "click", "selector": selector}],
    )


def _do_type(step: "Step") -> ObservedState:
    """type: 輸入文字到欄位"""
    page = get_session().page()
    started = time.perf_counter()
    if not step.target or not step.value:
        return _err_state("type", "missing step.target (selector) or step.value")
    try:
        page.fill(step.target, step.value, timeout=DEFAULT_TIMEOUT_MS)
    except Exception as e:
        return _err_state("type", f"{type(e).__name__}: {e} (target={step.target})")
    elapsed = int((time.perf_counter() - started) * 1000)
    return ObservedState(
        url=page.url,
        status=200,
        body_excerpt=_snapshot_dom(page),
        elapsed_ms=elapsed,
        history=[{"step": step.id, "action": "type", "target": step.target, "value": step.value}],
    )


def _do_wait(step: "Step") -> ObservedState:
    """wait: 等一段時間（讓 async 動作完成）"""
    page = get_session().page()
    started = time.perf_counter()
    try:
        page.wait_for_timeout(step.timeout_ms or DEFAULT_TIMEOUT_MS)
    except Exception as e:
        return _err_state("wait", f"{type(e).__name__}: {e}")
    elapsed = int((time.perf_counter() - started) * 1000)
    return ObservedState(
        url=page.url,
        status=200,
        body_excerpt=_snapshot_dom(page),
        elapsed_ms=elapsed,
        history=[{"step": step.id, "action": "wait", "ms": step.timeout_ms}],
    )


def _do_observe(step: "Step") -> ObservedState:
    """observe: 只看當前狀態，不互動"""
    page = get_session().page()
    started = time.perf_counter()
    elapsed = int((time.perf_counter() - started) * 1000)
    return ObservedState(
        url=page.url,
        status=200,
        body_excerpt=_snapshot_dom(page),
        elapsed_ms=elapsed,
        history=[{"step": step.id, "action": "observe"}],
    )


def _do_setup_state(step: "Step") -> ObservedState:
    """setup_state: 跟 observe 同義（不互動、看當下狀態）"""
    return _do_observe(step)


def _err_state(action: str, msg: str) -> ObservedState:
    """driver 錯誤時回傳 fail state（oracle 仍能判 fail）"""
    return ObservedState(
        url="",
        status=0,
        body_excerpt=f"[{action} error] {msg}",
        elapsed_ms=0,
        history=[{"step": "?", "action": action, "error": msg}],
    )


# ─── 對外入口（介面跟 ac_aware_observe 對齊） ────────────────────────────

ACTIONS = {
    "navigate": _do_navigate,
    "click": _do_click,
    "type": _do_type,
    "wait": _do_wait,
    "observe": _do_observe,
    "setup_state": _do_setup_state,
}


def playwright_observe(step: "Step", prev: "ObservedState | None", story_id: str = "") -> ObservedState:
    """Playwright driver 版 observer。
    介面跟 ac_aware_observe 對齊：(step, prev, story_id) -> ObservedState。
    沒裝 playwright 時 raise RuntimeError，runner dispatcher 應 fallback。
    """
    if not _is_playwright_available():
        raise RuntimeError(
            "OBSERVER_BACKEND=playwright 但 playwright 沒裝。"
            "請：uv pip install playwright && playwright install chromium"
        )
    handler = ACTIONS.get(step.action)
    if handler is None:
        return _err_state(step.action, f"unknown action: {step.action}")
    return handler(step)


def close_session() -> None:
    """M3.1：runner 跑完後呼叫（雖然 process 結束也會自動關）"""
    global _session
    if _session is not None:
        _session.close()
        _session = None
