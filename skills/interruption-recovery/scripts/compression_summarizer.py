#!/usr/bin/env python3
"""
compression_summarizer.py — Compress session history into a concise summary

This is Layer 1 of the context-compression subagent system. Given a session
with growing context, it produces a structured summary suitable for being
appended back to the session as a "memory anchor" — letting the model
continue with full awareness of what was done so far, but using ~5% of
the original tokens.

Strategy:
  1. LLM-powered summarization (preferred): use the active model's
     `chat.completions` API via a lightweight call. Falls back gracefully
     if no API key or model is reachable.
  2. Extractive fallback: if LLM call fails, use heuristic extraction
     — take the goal/decision/tool-call lines verbatim, drop the chit-chat.

The summary format follows the existing `dev-task-state.md` schema so it
can be ingested by `resume_task.py` and other tools uniformly.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/Users/davidchu/.hermes"))
PROFILE_HOME = HERMES_HOME / "profiles" / "developer"
STATE_DB = PROFILE_HOME / "state.db"

# Keep last N exchanges verbatim
KEEP_LAST_EXCHANGES = 4

# Trigger thresholds
COMPRESS_PRESSURE = 0.85   # try to compress
FORK_PRESSURE = 1.20       # if compress fails, fork

# Token targets
TARGET_SUMMARY_TOKENS = 2000
MAX_SUMMARY_TOKENS = 3000


def get_state_db() -> sqlite3.Connection:
    if not STATE_DB.exists():
        print(f"state.db not found: {STATE_DB}", file=sys.stderr)
        sys.exit(1)
    return sqlite3.connect(f"file:{str(STATE_DB).replace('?', '%3F')}?mode=ro", uri=True)


def get_state_db_rw() -> sqlite3.Connection:
    """Read-write connection (for the executor layer)."""
    return sqlite3.connect(str(STATE_DB))


def load_session_messages(conn: sqlite3.Connection, sid: str) -> List[Dict[str, Any]]:
    """Load all messages for a session, oldest first."""
    cur = conn.execute("""
        SELECT id, role, content, tool_name, tool_call_id, timestamp, token_count
        FROM messages
        WHERE session_id = ? AND active = 1
        ORDER BY id ASC
    """, (sid,))
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def partition_head_tail(
    messages: List[Dict[str, Any]],
    keep_last: int = KEEP_LAST_EXCHANGES,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Split messages into [head, tail] preserving user-turn boundary.

    Strategy: try to keep the last `keep_last` user turns verbatim. If the
    session has fewer user turns than that, fall back to keeping the last
    `keep_last * 4` total messages (an exchange ≈ 1 user + 3 assistant/tool).

    For zombie sessions (0-1 user turns, lots of tool spam), we still need
    a non-empty tail so the model has *some* recent context to continue.
    """
    # Walk backwards, count user turns
    user_turns = 0
    user_split_idx = len(messages)
    for i in range(len(messages) - 1, -1, -1):
        if messages[i].get("role") == "user":
            user_turns += 1
            if user_turns == keep_last:
                user_split_idx = i
                break

    # Fallback: not enough user turns, use last N total messages
    if user_turns < keep_last:
        n_fallback = min(keep_last * 4, len(messages))
        if n_fallback >= len(messages):
            # Session too small, return all as head, empty tail
            return messages, []
        return messages[:-n_fallback], messages[-n_fallback:]

    return messages[:user_split_idx], messages[user_split_idx:]


# === LLM summarization ===

def call_llm_summarize(head: List[Dict[str, Any]], title: Optional[str], api_base: str, api_key: str, model: str) -> Optional[str]:
    """Call the LLM to produce a structured summary of the head messages.

    Auto-detects endpoint format:
    - If URL contains '/anthropic' or model is a Claude/MiniMax model, use
      Anthropic Messages API format
    - Otherwise use OpenAI chat.completions format

    Returns None on any failure (caller will fall back to extractive summary).
    """
    # Build a compact transcript for the LLM
    transcript_lines = []
    for m in head:
        role = m.get("role", "?")
        content = (m.get("content") or "")[:800]  # truncate per-msg
        if not content and m.get("tool_name"):
            content = f"[tool_call: {m['tool_name']}]"
        if not content:
            continue
        transcript_lines.append(f"[{role}] {content[:400]}")
    transcript = "\n".join(transcript_lines)

    if len(transcript) < 100:
        # Not enough content to summarize
        return None

    # Build the summarization prompt
    system_prompt = """You are a context compressor for a long-running development task.
Your output is read by a fresh agent session that needs to continue the work.

Produce a structured summary with these sections (use Markdown):
1. 🎯 Goal (one sentence — what was being built/accomplished)
2. 📋 Decisions made (with WHY for each — critical for the next session)
3. 🏗️ Current state (files touched, key code paths, what's working/broken)
4. ⏭️ Next 3-5 steps (concrete, with file paths)
5. 🧠 Key insights (non-obvious things the next agent must know)
6. ⚠️ Risks / blockers

Be CONCISE. Target ~1500-2000 tokens. Drop chit-chat. Keep code snippets only
when they're load-bearing for understanding. Use Chinese if the original
conversation was Chinese; English otherwise."""

    user_prompt = f"""Session title: {title or '(no title)'}

Compress the following conversation history into a structured summary.

CONVERSATION:
{transcript[:24000]}

OUTPUT (structured Markdown, no preamble):"""

    # Detect format from URL
    use_anthropic = "/anthropic" in api_base or model.startswith(("MiniMax", "claude"))

    try:
        if use_anthropic:
            # Anthropic Messages API format
            url = api_base.rstrip('/') + "/v1/messages"
            payload = json.dumps({
                "model": model,
                "system": system_prompt,
                "messages": [{"role": "user", "content": user_prompt}],
                "max_tokens": TARGET_SUMMARY_TOKENS,
                "temperature": 0.2,
            }).encode("utf-8")
            headers = {
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json",
            }
        else:
            # OpenAI chat.completions format
            url = api_base.rstrip('/') + "/chat/completions"
            payload = json.dumps({
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "max_tokens": TARGET_SUMMARY_TOKENS,
                "temperature": 0.2,
            }).encode("utf-8")
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            }

        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            # Parse response (different shapes for different APIs)
            if use_anthropic:
                content_blocks = data.get("content", [])
                summary = "".join(b.get("text", "") for b in content_blocks if b.get("type") == "text")
            else:
                summary = data["choices"][0]["message"]["content"]
            return summary
    except (urllib.error.URLError, urllib.error.HTTPError, KeyError, json.JSONDecodeError, TimeoutError) as e:
        print(f"  ⚠️  LLM call failed: {e}", file=sys.stderr)
        return None


# === Extractive fallback ===

GOAL_PATTERNS = [
    r"(?:goal|task|objective)[:\s]+(.+?)(?:\n|$)",
    r"^#\s+(.+)$",  # markdown H1
]

DECISION_PATTERNS = [
    r"(?:decided|chose|picked|using|will use|採用|選擇|決定)[:\s]+(.+?)(?:\n|$)",
]

INSIGHT_PATTERNS = [
    r"(?:important|note|remember|key insight|重點|注意|關鍵)[:\s]+(.+?)(?:\n|$)",
    r"⚠️\s*(.+)",
    r"🚨\s*(.+)",
]


def extractive_summary(head: List[Dict[str, Any]], title: Optional[str]) -> str:
    """Heuristic extraction: pull goal/decision/insight lines verbatim."""
    goals: List[str] = []
    decisions: List[str] = []
    insights: List[str] = []
    files_touched: set = set()

    for m in head:
        content = m.get("content") or ""
        if not content:
            tool_name = m.get("tool_name")
            if tool_name in ("write_file", "patch", "edit_file"):
                # Try to extract file path from tool_call data (stored elsewhere)
                pass
            continue

        for pat in GOAL_PATTERNS:
            for m2 in re.finditer(pat, content, re.MULTILINE | re.IGNORECASE):
                g = m2.group(1).strip()
                if 10 < len(g) < 200:
                    goals.append(g)

        for pat in DECISION_PATTERNS:
            for m2 in re.finditer(pat, content, re.MULTILINE | re.IGNORECASE):
                d = m2.group(1).strip()
                if 5 < len(d) < 250:
                    decisions.append(d)

        for pat in INSIGHT_PATTERNS:
            for m2 in re.finditer(pat, content, re.MULTILINE):
                i = m2.group(1).strip()
                if 10 < len(i) < 300:
                    insights.append(i)

        # Detect file paths
        for m2 in re.finditer(r"[\w/]+\.(py|js|ts|tsx|jsx|md|yaml|yml|sh|json|sql)\b", content):
            files_touched.add(m2.group(0))

    # Dedupe + limit
    seen = set()
    decisions = [d for d in decisions if not (d in seen or seen.add(d))][:10]
    seen.clear()
    insights = [i for i in insights if not (i in seen or seen.add(i))][:8]
    seen.clear()
    goals = [g for g in goals if not (g in seen or seen.add(g))][:3]

    summary = f"""# Extracted Summary — {title or 'session'}

**Generated**: {datetime.now(timezone.utc).isoformat()}
**Method**: Extractive (LLM fallback — no API call)
**Head messages compressed**: {len(head)}
**Tail preserved**: {KEEP_LAST_EXCHANGES} exchanges

## 🎯 Goal

{chr(10).join(f'- {g}' for g in goals) or '- (no explicit goal detected)'}

## 📋 Decisions

{chr(10).join(f'- {d}' for d in decisions) or '- (no decisions detected)'}

## 🏗️ Current state

Files touched: {', '.join(sorted(files_touched)[:20]) or '(none detected)'}

## 🧠 Key insights

{chr(10).join(f'- {i}' for i in insights) or '- (no insights flagged)'}

## ⏭️ Next steps

- (Re-read latest user message in tail for current direction)
"""
    return summary


# === Main entry point ===

def summarize_session(
    sid: str,
    api_base: Optional[str] = None,
    api_key: Optional[str] = None,
    model: Optional[str] = None,
    keep_last: int = KEEP_LAST_EXCHANGES,
) -> Dict[str, Any]:
    """Produce a summary of a session.

    Returns a dict with:
      - summary: str (the summary text)
      - method: 'llm' | 'extractive'
      - head_count: int
      - tail_count: int
      - sid: str
      - title: Optional[str]
    """
    conn = get_state_db()
    try:
        # Load session metadata
        cur = conn.execute("SELECT title, message_count FROM sessions WHERE id = ?", (sid,))
        row = cur.fetchone()
        if not row:
            return {"error": f"Session {sid} not found"}
        title, msg_count = row

        # Load messages
        messages = load_session_messages(conn, sid)
        if len(messages) < keep_last + 2:
            return {"error": f"Session {sid} has only {len(messages)} messages, not enough to compress"}

        # Partition
        head, tail = partition_head_tail(messages, keep_last)

        result = {
            "sid": sid,
            "title": title,
            "head_count": len(head),
            "tail_count": len(tail),
            "summary": None,
            "method": None,
        }

        # Try LLM first
        if api_base and api_key and model:
            print(f"  📞 Calling LLM ({model}) for summary...")
            summary = call_llm_summarize(head, title, api_base, api_key, model)
            if summary:
                result["summary"] = summary
                result["method"] = "llm"
                return result

        # Fallback: extractive
        print(f"  📝 Using extractive summary (LLM unavailable or skipped)")
        result["summary"] = extractive_summary(head, title)
        result["method"] = "extractive"
        return result
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session_id", help="Session ID to summarize")
    parser.add_argument("--keep-last", type=int, default=KEEP_LAST_EXCHANGES, help="Exchanges to preserve verbatim")
    parser.add_argument("--api-base", help="LLM API base URL (default: from developer profile .env)")
    parser.add_argument("--api-key", help="LLM API key (default: from developer profile .env)")
    parser.add_argument("--model", help="Model name (default: from developer profile .env)")
    parser.add_argument("--output", help="Output file for summary (default: stdout)")
    args = parser.parse_args()

    # Load defaults from .env (profile first, then root fallback)
    env_candidates = [PROFILE_HOME / ".env", HERMES_HOME / ".env"]
    env_content = ""
    for env_file in env_candidates:
        if env_file.exists():
            env_content += env_file.read_text() + "\n"

    if not args.api_base:
        for key_name in ("MINIMAX_URL", "MINIMAX_BASE_URL", "LLM_API_BASE", "OPENAI_BASE_URL", "MODEL_BASE_URL", "OPENROUTER_BASE_URL"):
            m = re.search(rf"{key_name}=([^\s\n]+)", env_content)
            if m:
                args.api_base = m.group(1).strip().strip('"').strip("'")
                break
    if not args.api_key:
        for key_name in ("MINIMAX_API_KEY", "LLM_API_KEY", "OPENAI_API_KEY", "OPENROUTER_API_KEY"):
            m = re.search(rf"{key_name}=([^\s\n]+)", env_content)
            if m:
                args.api_key = m.group(1).strip().strip('"').strip("'")
                break
    if not args.model:
        m = re.search(r"(?:MINIMAX_MODEL|LLM_MODEL|MODEL)=([^\s\n]+)", env_content)
        if m:
            args.model = m.group(1).strip().strip('"').strip("'")
        else:
            args.model = "minimax-m3"  # sensible default for Developer Profile

    if not args.api_base or not args.api_key or not args.model:
        print("  ⚠️  No LLM config found, will use extractive fallback", file=sys.stderr)

    result = summarize_session(args.session_id, args.api_base, args.api_key, args.model, args.keep_last)

    if args.output:
        Path(args.output).write_text(json.dumps(result, indent=2, ensure_ascii=False))
        print(f"  ✅ Summary written to {args.output}")
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
