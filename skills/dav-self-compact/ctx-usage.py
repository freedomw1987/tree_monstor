#!/usr/bin/env python3
"""ctx-usage.py — 由 agent transcript 檔計 context 使用率（Claude Code／Qoder 通用）。

用喺冇 agent 可呼叫嘅量度工具嘅 host（Claude Code、Qoder）：
讀最新 session transcript → 攞 context 用量 → 換算 percent／zone／action。

用法：
  ctx-usage.py --host claude [--project DIR] [--window N] [--json]
  ctx-usage.py --host qoder  [--project DIR] [--window N] [--json]

輸出：JSON（單行）＋ 人讀一行（除非 --json）。
來源可信度：usage（transcript 有 token 數）> estimate（按 transcript 估算）> none（冇資料）。

三個 zone 門檻同 pi 一致：smart <50%／soft ≥50%／opportunity ≥55%／hard ≥60%。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

DEFAULT_WINDOW = 200_000
DEFAULT_ZONES = {"softPercent": 50, "opportunityPercent": 55, "hardPercent": 60}
DEFAULT_OVERHEAD = 15_000  # system prompt + 工具 schema 粗估（估算路徑用）
TAIL_MESSAGES = 40  # 估算路徑：只計尾段幾多條訊息


def host_home(host: str) -> Path:
    return Path.home() / (".claude" if host == "claude" else ".qoder")


def encode_project(path: str) -> str:
    return path.rstrip("/").replace("/", "-") or "-"


def load_config(host: str, explicit: str | None) -> dict:
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    else:
        candidates.append(host_home(host) / "dav-self-compact.json")
    for c in candidates:
        try:
            if c.is_file():
                return json.loads(c.read_text())
        except Exception:
            pass
    return {}


def latest_session(project_dir: str, host: str, explicit: str | None) -> Path | None:
    if explicit:
        p = Path(explicit)
        return p if p.is_file() else None
    root = host_home(host) / "projects" / encode_project(project_dir)
    if not root.is_dir():
        return None
    files = [f for f in root.glob("*.jsonl") if f.is_file()]
    if not files:
        return None
    return max(files, key=lambda f: f.stat().st_mtime)


def usage_tokens(usage: dict) -> int:
    keys = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
    return sum(int(usage.get(k) or 0) for k in keys)


def text_len(obj) -> int:
    if isinstance(obj, str):
        return len(obj)
    if isinstance(obj, list):
        return sum(text_len(x) for x in obj)
    if isinstance(obj, dict):
        if obj.get("type") == "text" and isinstance(obj.get("text"), str):
            return len(obj["text"])
        if obj.get("type") == "tool_result":
            return text_len(obj.get("content"))
        return sum(text_len(v) for v in obj.values())
    return 0


def analyse(path: Path) -> dict:
    """行一次 transcript：攞 usage／壓縮標記／尾段估算。"""
    last_usage: dict | None = None
    last_boundary: dict | None = None
    tail_chars = 0
    tail_msgs = 0
    after_boundary_chars = 0
    after_boundary_msgs = 0
    runtime_window: int | None = None
    model: str | None = None

    with path.open(errors="ignore") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            dtype = d.get("type")

            if dtype == "runtime-config":
                cw = d.get("contextWindow")
                if isinstance(cw, (int, float)) and cw > 0:
                    runtime_window = int(cw)

            if dtype == "system" and d.get("subtype") == "compact_boundary":
                meta = d.get("compactMetadata") or d.get("compact_metadata") or {}
                last_boundary = {
                    "pre_tokens": meta.get("preTokens", meta.get("pre_tokens")),
                    "post_tokens": meta.get("postTokens", meta.get("post_tokens")),
                    "trigger": meta.get("trigger"),
                    "timestamp": d.get("timestamp"),
                }
                after_boundary_chars = 0
                after_boundary_msgs = 0

            if dtype == "assistant":
                msg = d.get("message") or {}
                model = msg.get("model") or model
                usage = msg.get("usage") or d.get("usage")
                if isinstance(usage, dict):
                    n = usage_tokens(usage)
                    if n > 0:
                        last_usage = {"tokens": n, "timestamp": d.get("timestamp"), "model": msg.get("model")}

            if dtype in ("user", "assistant", "attachment"):
                msg = d.get("message") or {}
                size = text_len(msg.get("content")) if isinstance(msg, dict) else 0
                size += text_len(d.get("content"))
                tail_chars += size
                tail_msgs += 1
                after_boundary_chars += size
                after_boundary_msgs += 1
                if tail_msgs > TAIL_MESSAGES:
                    tail_chars -= size
                    tail_msgs -= 1
                if last_boundary and after_boundary_msgs > TAIL_MESSAGES:
                    after_boundary_chars -= size
                    after_boundary_msgs -= 1

    return {
        "last_usage": last_usage,
        "last_boundary": last_boundary,
        "tail_chars": tail_chars,
        "tail_msgs": tail_msgs,
        "after_boundary_chars": after_boundary_chars,
        "after_boundary_msgs": after_boundary_msgs,
        "runtime_window": runtime_window,
        "model": model,
    }


def resolve_window(args, cfg: dict, runtime_window: int | None) -> int:
    for cand in (
        args.window,
        int(os.environ.get("CTX_WINDOW") or 0) or None,
        cfg.get("contextWindow"),
        int(os.environ.get("CLAUDE_CODE_MAX_CONTEXT_TOKENS") or 0) or None,
        runtime_window,
    ):
        if isinstance(cand, (int, float)) and cand > 0:
            return int(cand)
    return DEFAULT_WINDOW


def zone_of(percent: float, zones: dict) -> tuple[str, str]:
    soft = zones["softPercent"]
    opp = zones["opportunityPercent"]
    hard = zones["hardPercent"]
    if percent < soft:
        return "smart", "keep_working"
    if percent < opp:
        return "soft", "prepare_then_compact"
    if percent < hard:
        return "opportunity", "compact_at_boundary"
    return "hard", "compact_now"


def main() -> int:
    ap = argparse.ArgumentParser(description="由 transcript 計 context 使用率（Claude Code／Qoder）")
    ap.add_argument("--host", choices=["claude", "qoder"], required=True)
    ap.add_argument("--project", default=os.getcwd(), help="專案目錄（預設 pwd）")
    ap.add_argument("--window", type=int, default=None, help="context window token 數")
    ap.add_argument("--session", default=None, help="指定 transcript 檔")
    ap.add_argument("--config", default=None, help="閾值設定檔（預設 <agent home>/dav-self-compact.json）")
    ap.add_argument("--json", action="store_true", help="只出 JSON")
    args = ap.parse_args()

    cfg = load_config(args.host, args.config)
    zones = dict(DEFAULT_ZONES)
    for k in DEFAULT_ZONES:
        v = cfg.get(k)
        if isinstance(v, (int, float)) and 0 < v <= 100:
            zones[k] = int(v)
    cap = cfg.get("absoluteCapTokens")
    cap = int(cap) if isinstance(cap, (int, float)) and cap > 0 else 0

    path = latest_session(args.project, args.host, args.session)
    if path is None:
        out = {"host": args.host, "source": "none", "error": "no-session", "note": "搵唔到 session transcript"}
        print(json.dumps(out, ensure_ascii=False))
        return 2

    info = analyse(path)
    window = resolve_window(args, cfg, info["runtime_window"])
    effective = min(window, cap) if cap else window

    used = None
    source = "none"
    if info["last_usage"]:
        used = info["last_usage"]["tokens"]
        source = "usage"
    elif info["last_boundary"] and info["last_boundary"].get("post_tokens"):
        base = int(info["last_boundary"]["post_tokens"])
        used = base + info["after_boundary_chars"] // 4
        source = "estimate"
    elif info["tail_chars"]:
        used = info["tail_chars"] // 4 + DEFAULT_OVERHEAD
        source = "estimate"

    if used is None:
        out = {
            "host": args.host,
            "source": "none",
            "session_file": str(path),
            "note": "transcript 冇 token 資料 → 當 soft 區處理（唔好亂報百分比）",
        }
        print(json.dumps(out, ensure_ascii=False))
        return 2

    percent = round(used / effective * 100, 1)
    zone, action = zone_of(percent, zones)
    out = {
        "host": args.host,
        "source": source,
        "used_tokens": used,
        "window_tokens": window,
        "effective_window_tokens": effective,
        "percent": percent,
        "zone": zone,
        "action": action,
        "model": info["model"],
        "session_file": str(path),
        "last_compaction": info["last_boundary"],
        "note": (
            "usage = transcript 最後一次 assistant usage"
            if source == "usage"
            else "estimate = 估算值（按 transcript 字數／4 推算，± 誤差大）"
        ),
    }
    print(json.dumps(out, ensure_ascii=False))
    if not args.json:
        print(
            f"ctx {percent}% · {used}/{effective} tokens · zone={zone} · action={action} · "
            f"source={source} · session={path.name}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
