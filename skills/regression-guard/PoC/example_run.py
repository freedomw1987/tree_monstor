"""
Example runner — 證明 oracle 流程跑得起來。

策略：
1. 讀 docs/ac/US-101.md（真實檔）
2. 解析成 4 條 AC
3. 對每條 AC 餵「模擬的觀察結果」（mock 但反映真實可能出現的 4 種 verdict）
4. 跑 oracle（Jev Choice）
5. 印結果

觀察結果是 hard-coded fixtures（M2 才會換成 real Chrome 觀察）。
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

THIS_DIR = Path(__file__).parent
sys.path.insert(0, str(THIS_DIR))

from ac_schema import parse_story_file
from jev_oracle import evaluate_ac, ACContext, OracleResult


# ─── 4 種 fixture：模擬每條 AC 跑出 4 種 verdict 各一 ─────────────────

# 為了 demo 用，這 4 條刻意做成「真 bug / 過 / flaky / 過度斷言」各一
# 4 條 fixture 對應 4 條 AC（不一定一一對應 verdict，讓 demo 更豐富）
FIXTURES = {
    # AC01：點結帳 → 導到付款頁、M3 內才能驗證 3 秒、付款頁有 Visa
    # 假設這次跑：OK，過了
    "US-101-AC01": {
        "observed_url": "https://example.com/checkout/payment?order=A123",
        "observed_status": 200,
        "observed_body_excerpt": "付款頁面，支援 Visa, MasterCard, JCB",
        "observed_user_message": "",
        "elapsed_ms": 1200,
        "history": [],
    },
    # AC02：卡號格式錯誤 → 應顯示紅字
    # 假設這次跑：FAILED — 沒顯示紅字，只靜默
    "US-101-AC02": {
        "observed_url": "https://example.com/checkout/payment?order=A123",
        "observed_status": 200,
        "observed_body_excerpt": "頁面無新訊息，按鈕 Submit 仍在 enabled",
        "observed_user_message": "（使用者看到的頁面：沒有任何錯誤訊息）",
        "elapsed_ms": 850,
        "history": [],
    },
    # AC03：付款成功 → 寄 Email
    # 假設這次跑：FLAKY — 有時寄有時不寄
    "US-101-AC03": {
        "observed_url": "https://example.com/order/A123/done",
        "observed_status": 200,
        "observed_body_excerpt": "訂單成立，感謝您的購買",
        "observed_user_message": "（Admin log 顯示：上 5 次跑有 1 次沒收到 Email log）",
        "elapsed_ms": 4500,
        "history": [
            {"step": 1, "email_sent": True},
            {"step": 2, "email_sent": True},
            {"step": 3, "email_sent": False},
            {"step": 4, "email_sent": True},
            {"step": 5, "email_sent": True},
        ],
    },
    # AC04：付款失敗 → 顯示錯誤訊息，購物車不消失
    # 假設這次跑：OVER_ASSERTION — AC 寫「不可為空白」，但「空白」標準模糊
    "US-101-AC04": {
        "observed_url": "https://example.com/checkout/payment?order=A123",
        "observed_status": 500,
        "observed_body_excerpt": "服務暫時無法使用，請稍後重試",
        "observed_user_message": "服務暫時無法使用，請稍後重試",
        "elapsed_ms": 3000,
        "history": [],
    },
}


def main() -> int:
    story_path = THIS_DIR.parent.parent.parent / "docs" / "ac" / "US-101.md"
    if not story_path.exists():
        print(f"❌ 找不到 {story_path}，請確認 repo 路徑")
        return 1

    story = parse_story_file(story_path)
    print(f"📖 {story.story_id} 「{story.title}」— {len(story.acs)} 條 AC")
    print("=" * 70)

    # 檢查 API key
    from jev_oracle import _load_api_key
    api_key = _load_api_key()
    use_cache = "--no-cache" not in sys.argv
    if not api_key:
        print("ℹ️  OPENROUTER_API_KEY 找不到 → 全程用本地 cache（首次跑會 fail，"
              "需 cp .env.example .env 並補 key 或 set env）")
    else:
        print(f"ℹ️  API key loaded, mode={'cache' if use_cache else 'force live'}")
    print()

    results: list[OracleResult] = []
    for ac in story.acs:
        fixture = FIXTURES.get(ac.ac_id)
        if fixture is None:
            print(f"⚠️  沒有 fixture for {ac.ac_id}，跳過")
            continue

        ctx = ACContext(
            ac_id=ac.ac_id,
            story_id=story.story_id,
            given=ac.given,
            when=ac.when,
            then=ac.then,
            additional_and=ac.additional_and,
            **fixture,
        )

        print(f"\n▶ {ac.ac_id}  →  Jev oracle")
        try:
            r = evaluate_ac(ctx, use_cache=use_cache)
        except Exception as e:
            print(f"  ❌ {e}")
            continue

        results.append(r)
        verdict_str = " / ".join(
            f"{k}={v:.2f}" for k, v in r.verdict_probs.items()
        )
        print(f"  verdict={r.verdict} ({verdict_str})")
        print(f"  severity={r.severity:.2f}/3  confidence={r.confidence:.2f}  is_real_bug={r.is_real_bug:.2f}")
        print(f"  model={r.model}  latency={r.latency_ms}ms  cost=${r.cost_usd:.6f}  cached={r.cached}")

    # End-of-run batch summary
    print("\n" + "=" * 70)
    print(f"📊 End-of-run  ({len(results)} of {len(story.acs)} ACs evaluated)")
    verdicts = [r.verdict for r in results]
    from collections import Counter
    cnt = Counter(verdicts)
    for v, n in cnt.most_common():
        print(f"  {v:15s} {n} 條")
    avg_sev = sum(r.severity for r in results) / max(1, len(results))
    total_cost = sum(r.cost_usd for r in results)
    total_lat = sum(r.latency_ms for r in results)
    n_real_bugs = sum(1 for r in results if r.verdict != "pass" and r.is_real_bug > 0.5)
    print(f"  avg severity:       {avg_sev:.2f}/3")
    print(f"  real bugs flagged:  {n_real_bugs}/{len(results)}")
    print(f"  total cost:         ${total_cost:.6f}")
    print(f"  total latency:      {total_lat}ms")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
