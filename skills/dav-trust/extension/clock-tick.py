#!/usr/bin/env python3
"""clock-tick.py — trust mode 機械報時（pi／Claude Code／Qoder 通用，單一真相）。

為什麼：trust mode 跑幾個鐘，agent **冇自己嘅鐘** —— 佢只喺 4 個 checkpoint 主動
`date`（skills/dav-trust/time-anchor.md §2）。中間嘅盲區就係三個實際問題嘅根源：
  1. trust-log 時間戳靠估（假時間戳）
  2. 過咗 deadline 都唔知，繼續開新工作
  3. 剩 < 10% 冇觸發器去收斂（T3）

呢支腳本讀專案 `docs/trust-log.md` 檔頭 → 產生一段「現在時間（絕對）＋ deadline ＋
剩幾多 / 幾 % ＋ 跟住點做」嘅文字 → 依 host 包成唔同形態交付：

  pi           extension 用 timer 每 30 分鐘叫（`--format text`）→ `pi.sendMessage`
  Claude Code  hook：`--format hook --event PreToolUse|SessionStart|Stop`（stdout JSON）
  Qoder        hook：同上（事件名同 JSON 形態一致）

節流：**同一個 state 檔**（`~/.dav-trust/tick.json`，按專案記 `last_emit`）→ 換 host
或者 hook 事件重疊都唔會重複報時。間隔預設 30 分鐘（`--interval-minutes`／
`DAV_TRUST_TICK_MINUTES`／`~/.pi/agent/dav-trust.json` 嘅 `timeTickMinutes`）。

閘門（唔報時）：冇 trust-log／解析唔到 `> Deadline:`／`PHASE=終局`（已結束）／
`PHASE=暫停`（用戶揸方向盤）／未夠間隔。

裝 hook（唔會靜靜改你嘅設定檔；預設只印 JSON，要 `--apply` 才寫，寫前備份）：
  clock-tick.py --install-hooks claude --scope user            # 印出 patch
  clock-tick.py --install-hooks claude --scope user --apply    # 合併入 settings.json
  clock-tick.py --install-hooks qoder  --scope project --apply --project .
  clock-tick.py --install-hooks claude --scope user --uninstall
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_INTERVAL_MINUTES = 30.0
CONVERGE_PERCENT = 10  # 同 SKILL.md「剩餘 < 10% 主動收斂」同源
STATE_PATH = Path.home() / ".dav-trust" / "tick.json"
HOOK_MARKER = "tree-monstor:dav-trust-clock-tick"
HEADER_LINES = 20  # 檔頭只喺頭幾行；唔可以喺正文亂撈（正文可能引用 "Deadline" 一詞）

STAMP_RE = re.compile(
    r"(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?\s*([+-])(\d{2}):?(\d{2})"
)


# ---------------------------------------------------------------- trust-log 檔頭


def parse_stamp(text: str, field: str) -> dict | None:
    """`> Deadline: 2026-10-23 16:23:07 +0800` / `START_TS=...` → {ms, offset}."""
    head = "\n".join(text.split("\n")[:HEADER_LINES])
    pattern = re.compile(r"^\s*>?\s*(?:.*\s)?" + re.escape(field) + r"\s*[:：=]")
    for line in head.split("\n"):
        if not pattern.search(line):
            continue
        m = STAMP_RE.search(line)
        if not m:
            return None
        year, month, day, hour, minute, second, sign, off_h, off_m = m.groups()
        offset = (int(off_h) * 60 + int(off_m)) * (-1 if sign == "-" else 1)
        tz = timezone(timedelta(minutes=offset))
        stamp = datetime(
            int(year), int(month), int(day), int(hour), int(minute), int(second or 0), tzinfo=tz
        )
        return {"epoch": stamp.timestamp(), "offset": offset}
    return None


def format_stamp(epoch: float, offset_minutes: int) -> str:
    """epoch → `YYYY-MM-DD HH:MM:SS ±HHMM`（同 trust-log 嘅時間戳格式一致）。"""
    stamp = datetime.fromtimestamp(epoch, timezone(timedelta(minutes=offset_minutes)))
    sign = "-" if offset_minutes < 0 else "+"
    abs_off = abs(offset_minutes)
    return stamp.strftime("%Y-%m-%d %H:%M:%S ") + f"{sign}{abs_off // 60:02d}{abs_off % 60:02d}"


def read_header(text: str) -> dict:
    phase_match = re.search(r"^\s*>?\s*進度錨點:[^\n]*PHASE=([^\s、，]+)", text, re.M)
    phase = phase_match.group(1) if phase_match else ""
    return {
        "phase": phase,
        "deadline": parse_stamp(text, "Deadline") or parse_stamp(text, "DEADLINE_TS"),
        "start": parse_stamp(text, "啟動時間") or parse_stamp(text, "START_TS"),
        "finished": "終局" in phase,
        "paused": "暫停" in phase,
    }


# ---------------------------------------------------------------------- 報時文字


def tick_text(now: float, header: dict, interval_minutes: float) -> str:
    """三個形態（正常 / 剩 < 10% / 已過 deadline），每個都講「而家幾點」＋「跟住點做」。"""
    deadline = header["deadline"]
    start = header["start"]
    at = lambda ms: format_stamp(ms, deadline["offset"])  # noqa: E731
    head = (
        f"[dav-trust] ⏱ clock tick (every {interval_minutes:g} min, automatic — not a user message): "
        f"now {at(now)}."
    )
    stale = "Refresh the docs/trust-log.md checkpoint if the phase/US state changed."
    never = (
        "Never wait for the clock — `sleep` is blocked; the deadline is a ceiling, not a target."
    )

    if now >= deadline["epoch"]:
        over = round((now - deadline["epoch"]) / 60)
        return "\n".join(
            [
                f"{head} Deadline {at(deadline['epoch'])} has passed (over by {over} min).",
                "Stop new work: finish the atomic step, consolidate, deliver (dav-reviewer), "
                "set trust-log PHASE=終局 and exit trust mode.",
                never,
            ]
        )

    left_ms = deadline["epoch"] - now
    parts = [f"Deadline {at(deadline['epoch'])} → {round(left_ms / 60)} min left"]
    budget_ms = deadline["epoch"] - start["epoch"] if start else 0
    if budget_ms > 0:
        percent = int(left_ms * 100 / budget_ms)
        parts.append(
            f"{percent}% of the {round(budget_ms / 60)} min budget "
            f"(elapsed {round((now - start['epoch']) / 60)} min)"
        )
        if percent < CONVERGE_PERCENT:
            return "\n".join(
                [
                    f"{head} {', '.join(parts)}.",
                    f"Converge now: under {CONVERGE_PERCENT}% left → stop opening new work (no new L3), "
                    "consolidate and deliver, then exit trust mode.",
                    f"{stale} {never}",
                ]
            )
    return "\n".join(
        [
            f"{head} {', '.join(parts)}.",
            "Keep the L1 → L2 → L3 relay moving: next PENDING US, then re-visit ⏸️, then docs/ expansion.",
            f"{stale} {never}",
        ]
    )


# ------------------------------------------------------------------------- 節流


def load_state(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_state(path: Path, state: dict) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state, ensure_ascii=False))
    except Exception:
        pass  # 寫唔到 state 唔應該令 hook 失敗（最多下次早報一次）


def _remember(state_path: Path, project: Path, now: float, status: dict) -> None:
    """記低今次報時（節流靠佢；跨 host 共用同一份 state）。"""
    state = load_state(state_path)
    state[str(project)] = {"last_emit": now, "phase": status.get("phase", "")}
    save_state(state_path, state)


# ---------------------------------------------------------------------- 判定


def resolve_interval(explicit: float | None) -> float:
    if explicit is not None:
        return explicit
    env = os.environ.get("DAV_TRUST_TICK_MINUTES")
    if env:
        try:
            return max(0.0, float(env))
        except ValueError:
            pass
    for candidate in (Path.home() / ".pi" / "agent" / "dav-trust.json",):
        try:
            value = json.loads(candidate.read_text()).get("timeTickMinutes")
            if isinstance(value, (int, float)) and value >= 0:
                return float(value)
        except Exception:
            pass
    return DEFAULT_INTERVAL_MINUTES


def evaluate(project: Path, now: float, interval_minutes: float, state_path: Path, force: bool) -> dict:
    """回傳 status dict：due=True 時 status['text'] 就係要交付嘅文字。"""
    log_path = project / "docs" / "trust-log.md"
    try:
        text = log_path.read_text()
    except Exception:
        return {"due": False, "reason": "no-trust-log", "project": str(project)}

    header = read_header(text)
    base = {"project": str(project), "phase": header["phase"], "interval_minutes": interval_minutes}
    if not header["deadline"]:
        return {**base, "due": False, "reason": "no-deadline"}
    if header["finished"]:
        return {**base, "due": False, "reason": "finished"}
    if header["paused"]:
        return {**base, "due": False, "reason": "paused"}

    state = load_state(state_path)
    entry = state.get(str(project)) if isinstance(state.get(str(project)), dict) else {}
    last_emit = float(entry.get("last_emit") or 0)
    if interval_minutes <= 0:
        return {**base, "due": False, "reason": "disabled"}
    if not force and last_emit and now - last_emit < interval_minutes * 60:
        return {
            **base,
            "due": False,
            "reason": "throttled",
            "minutes_since_last": round((now - last_emit) / 60, 1),
        }

    return {
        **base,
        "due": True,
        "reason": "due",
        "now": format_stamp(now, header["deadline"]["offset"]),
        "deadline": format_stamp(header["deadline"]["epoch"], header["deadline"]["offset"]),
        "remaining_minutes": round((header["deadline"]["epoch"] - now) / 60),
        "text": tick_text(now, header, interval_minutes),
    }


# ------------------------------------------------------------------ hook 設定


def settings_path(host: str, scope: str, project: Path) -> Path:
    root = Path.home() / (".claude" if host == "claude" else ".qoder")
    return (root if scope == "user" else project / (".claude" if host == "claude" else ".qoder")) / "settings.json"


def hook_entries(host: str, wake: bool) -> dict:
    # abspath（唔 resolve）：經 skill 嘅 symlink 叫就用 symlink 路徑 → repo 搬家都唔會斷
    script = os.path.abspath(__file__)
    cmd = lambda event: f"python3 '{script}' --format hook --event {event}  # {HOOK_MARKER}"  # noqa: E731
    entries = {
        "SessionStart": [{"hooks": [{"type": "command", "command": cmd("SessionStart"), "timeout": 10}]}],
        "PreToolUse": [
            {"matcher": "*", "hooks": [{"type": "command", "command": cmd("PreToolUse"), "timeout": 10}]}
        ],
    }
    if wake:
        # Stop 阻斷 = 叫醒閒置中嘅 agent（trust mode 唔應該閒置）；預設唔開，因為
        # 「專案仲留住 PHASE=執行 但其實已經收工」嘅情況會變成每 30 分鐘嘈一次。
        entries["Stop"] = [{"hooks": [{"type": "command", "command": cmd("Stop --wake"), "timeout": 10}]}]
    return entries


def merge_hooks(settings: dict, host: str, wake: bool, uninstall: bool) -> tuple[dict, list[str]]:
    changes: list[str] = []
    hooks = settings.setdefault("hooks", {})
    # uninstall 要掃**所有**可能裝過嘅事件（唔理今次有冇帶 --wake），否則 Stop 會留低
    wanted = hook_entries(host, True) if uninstall else hook_entries(host, wake)
    for event, entries in wanted.items():
        current = hooks.get(event)
        current = current if isinstance(current, list) else []
        kept = [
            group
            for group in current
            if HOOK_MARKER not in json.dumps(group, ensure_ascii=False)
        ]
        removed = len(current) - len(kept)
        if removed:
            changes.append(f"removed {removed} stale {event} hook group(s)")
        if uninstall:
            if kept:
                hooks[event] = kept
            else:
                hooks.pop(event, None)
            continue
        hooks[event] = kept + entries
        changes.append(f"installed {event} hook (matcher: {entries[0].get('matcher', 'all')})")
    if not hooks:
        settings.pop("hooks", None)
    return settings, changes


def run_install_hooks(args) -> int:
    path = settings_path(args.install_hooks, args.scope, Path(args.project or os.getcwd()).resolve())
    try:
        settings = json.loads(path.read_text()) if path.is_file() else {}
        if not isinstance(settings, dict):
            raise ValueError("settings.json 唔係 object")
    except FileNotFoundError:
        settings = {}
    except Exception as exc:
        print(f"FAIL: 讀唔到 {path}（{exc}）→ 唔會改動", file=sys.stderr)
        return 2

    merged, changes = merge_hooks(settings, args.install_hooks, args.wake, args.uninstall)
    action = "uninstall" if args.uninstall else "install"
    if not args.apply:
        print(json.dumps({action: str(path), "settings": merged}, ensure_ascii=False, indent=2))
        print(f"# dry-run：加 --apply 才會寫入 {path}（寫前備份）", file=sys.stderr)
        return 0

    try:
        if path.is_file():
            backup = path.with_suffix(f".json.bak.{int(time.time())}")
            backup.write_text(path.read_text())
            print(f"backup: {backup}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n")
    except Exception as exc:
        print(f"FAIL: 寫唔到 {path}（{exc}）", file=sys.stderr)
        return 2
    print(f"{action}ed {path}")
    for change in changes:
        print(f"  - {change}")
    return 0


# ------------------------------------------------------------------------- main


def stdin_project() -> Path | None:
    """hook 會經 stdin 傳 JSON（含 cwd）；唔係 pipe 就唔好讀（會卡住）。"""
    if sys.stdin.isatty():
        return None
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        return None
    cwd = data.get("cwd") if isinstance(data, dict) else None
    return Path(cwd) if isinstance(cwd, str) and cwd else None


def hook_output(event: str, text: str, wake: bool) -> str:
    """Claude Code／Qoder 都讀同一形態：hookSpecificOutput.additionalContext。"""
    if event == "Stop" and wake:
        return json.dumps({"decision": "block", "reason": text}, ensure_ascii=False)
    return json.dumps(
        {"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}},
        ensure_ascii=False,
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="trust mode 機械報時（pi／Claude Code／Qoder）")
    ap.add_argument("--project", default=None, help="專案目錄（預設：hook stdin 嘅 cwd，否則 pwd）")
    ap.add_argument("--interval-minutes", type=float, default=None, help="報時間隔（預設 30）")
    ap.add_argument("--state", default=str(STATE_PATH), help="節流 state 檔")
    ap.add_argument("--format", choices=["text", "hook"], default="text")
    ap.add_argument("--event", default="PreToolUse", help="hook 事件名（--format hook 用）")
    ap.add_argument("--wake", action="store_true", help="Stop 事件用：阻斷停止叫醒閒置 agent")
    ap.add_argument("--force", action="store_true", help="忽略節流（測試／手動查時間用）")
    ap.add_argument("--now", default=None, help="覆寫現在時間（ISO 8601，測試用）")
    ap.add_argument("--json", action="store_true", help="輸出判定 JSON 而唔係文字")
    ap.add_argument("--install-hooks", choices=["claude", "qoder"], default=None, help="裝 hook")
    ap.add_argument("--scope", choices=["user", "project"], default="user")
    ap.add_argument("--apply", action="store_true", help="真寫入（預設只印 patch）")
    ap.add_argument("--uninstall", action="store_true", help="移除本 skill 裝嘅 hook")
    args = ap.parse_args()

    if args.install_hooks:
        return run_install_hooks(args)

    project = Path(args.project).resolve() if args.project else (stdin_project() or Path.cwd())
    now = datetime.fromisoformat(args.now).timestamp() if args.now else time.time()
    interval = resolve_interval(args.interval_minutes)
    state_path = Path(args.state)
    status = evaluate(project, now, interval, state_path, args.force)

    if args.json:
        print(json.dumps(status, ensure_ascii=False))
        if status["due"]:
            _remember(state_path, project, now, status)
        return 0

    if not status["due"]:
        return 0  # hook 靜靜退出：唔注入任何嘢

    if args.format == "hook":
        print(hook_output(args.event, status["text"], args.wake))
    else:
        print(status["text"])

    _remember(state_path, project, now, status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
