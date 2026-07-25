#!/usr/bin/env python3
"""
llm-acp-discord helper — quick API calls for the skill.
Run directly: python3 scripts/acp_helper.py <cmd> [args]
Also importable: from acp_helper import random_n, start_attempt, ...
"""
import json
import sys
import os
import urllib.request
import urllib.parse

API = os.environ.get("LLM_ACP_API", "http://localhost:8080/api")


def get(path, **params):
    url = f"{API}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=5) as r:
        return json.loads(r.read())


def post(path, body):
    req = urllib.request.Request(
        f"{API}{path}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read())


def health():
    return get("/health")


def random_n(n=1):
    return get("/questions", mode="random", count=n)


def wrong_questions():
    return get("/wrong-questions")


def start_attempt(ids, mode="random"):
    return post("/attempts", {"questionIds": ids, "mode": mode})


def submit_answer(attempt_id, question_id, user_answer):
    return post(
        f"/attempts/{attempt_id}/answer",
        {"questionId": str(question_id), "userAnswer": user_answer},
    )


def finish(attempt_id):
    return post(f"/attempts/{attempt_id}/finish", {})


def stats():
    return get("/stats")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "health"
    if cmd == "health":
        print(json.dumps(health(), indent=2, ensure_ascii=False))
    elif cmd == "random":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        print(json.dumps(random_n(n), indent=2, ensure_ascii=False))
    elif cmd == "wrong":
        print(json.dumps(wrong_questions(), indent=2, ensure_ascii=False))
    elif cmd == "stats":
        print(json.dumps(stats(), indent=2, ensure_ascii=False))
    elif cmd == "answer":
        # python3 acp_helper.py answer <attempt_id> <question_id> <user_answer>
        aid, qid, ans = sys.argv[2], sys.argv[3], sys.argv[4]
        print(json.dumps(submit_answer(aid, qid, ans), indent=2, ensure_ascii=False))
    elif cmd == "start":
        # python3 acp_helper.py start <id1,id2,id3> [mode]
        ids = [int(x) for x in sys.argv[2].split(",")]
        mode = sys.argv[3] if len(sys.argv) > 3 else "random"
        print(json.dumps(start_attempt(ids, mode), indent=2, ensure_ascii=False))
    elif cmd == "finish":
        print(json.dumps(finish(sys.argv[2]), indent=2, ensure_ascii=False))
    else:
        print(f"unknown: {cmd}")
        print("commands: health, random [N], wrong, stats, start <ids> [mode], answer <aid> <qid> <ans>, finish <aid>")
