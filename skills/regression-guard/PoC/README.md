# Regression Guard — Jev PoC (M1)

> 把 `regression-guard` skill 升級成「**用戶旅程模擬回歸測試**」的最小可行 PoC。
>
> **這個目錄是 PoC**，**不是** production code。Skill 本體（`./SKILL.md`、`./examples.md`、`./testing-methods.md`）沒動。

## TL;DR

1. **做什麼**：用 OpenRouter 上的 `typesafe/jev-1.13` 當 structured decision oracle，把「**讀 AC 文字 + 觀察結果 → 判定過 / fail / flaky / 過度斷言**」這件事自動化。
2. **何時觸發**：每個 User Story 跑完 user journey 後，需要語意判定「這條 AC 算不算過」。
3. **預設 SOP 路徑**：`regression-guard` Step 3 之後插一個新 Step「**oracle 評估**」、再進 Step 4 修正循環。
4. **關鍵紀律**：
   - **語意判定而非字串比對**：Jev 看的是 AC 文字 + 觀察的 state，跑出 typed verdict
   - **Confidence gating**：低信心判定先送 review，不要誤導修正循環
   - **Cache-first**：沒 API key 時先用本地 cache 跑通流程；有 key 才打真實 API
   - **AC schema = docs/ac/US-XXX.md 的 Given/When/Then 結構**（別自創格式）
5. **必產出物**：`OracleResult { verdict, severity, confidence }` × 每條 AC + end-of-run summary

## 目錄結構

```
PoC/
├─ jev_oracle.py          # 核心：Jev HTTP 呼叫 + 回應解析 + cache
├─ ac_schema.py          # 解析 docs/ac/US-XXX.md → 結構化 AC 條目
├─ example_run.py        # 示範：US-101 真實 AC + 4 個 mock 觀察 → 跑 oracle
├─ cache/
│  ├─ fixture_helper.py  # 預塞假 Jev 回應（沒 key 時 demo 用）
│  └─ *.json             # 自動 cache（gitignored）
├─ .env.example          # OPENROUTER_API_KEY 範本
└─ README.md             # ← 你正在看
```

## 怎麼跑（沒 API key）

```bash
cd skills/regression-guard/PoC

# 1. 建 venv 裝 httpx
uv venv && uv pip install httpx

# 2. seed 預塞假 Jev 回應
.venv/bin/python cache/fixture_helper.py

# 3. 跑 demo（4 條 AC、4 種 verdict）
.venv/bin/python example_run.py
```

會看到：

```
▶ US-101-AC01  verdict=pass
▶ US-101-AC02  verdict=fail  severity=1.45/3
▶ US-101-AC03  verdict=flaky  severity=2.10/3  confidence=0.42
▶ US-101-AC04  verdict=over_assertion
```

## 怎麼跑（真 API）

```bash
cp .env.example .env
# 編輯 .env：OPENROUTER_API_KEY=<your_key>

# 刪 cache 重新打
rm cache/*.json
.venv/bin/python example_run.py   # 第一次會 hit 真實 API
.venv/bin/python example_run.py   # 第二次會 hit cache
```

## M1 完成的證據

| 項 | 狀態 |
|---|---|
| 讀真實 `docs/ac/US-101.md` → parse 出 4 條 AC | ✅ |
| AC parser 用真正的 AC schema（Given/When/Then/And）| ✅ |
| Oracle 跑出 4 種 verdict（pass / fail / flaky / over_assertion）| ✅ |
| Cache 機制（含 cache key 雜湊、save / load）| ✅ |
| Confidence + severity + verdict probabilities 完整呈現 | ✅ |
| End-of-run summary（count by verdict + avg severity）| ✅ |
| 真 API 打接（要 OPENROUTER_API_KEY）| ⏳ 待 key |

## M2 接續（下一步）

**Journey 生成器**：用 Jev 從 AC 自動生 user journey 規格（YAML）。預期 target：把 US-101.md 變成：

```yaml
journey: US-101
generated_by: jev
steps:
  - id: login-or-stub
    action: navigate
    target: https://example.com
  - id: add-item-to-cart
    action: interact
    target_text: 加入購物車
    observe_state: { cart_count_increments: true }
  - id: click-checkout
    action: click
    target_text: 結帳
    expected_url: https://example.com/checkout/payment
    ...
```

## M3 接續

**Journey runner**：Chrome + DOM snapshot driver（dry-run loop 先、不接 Chrome；接 Chrome 留 M3.1）。每步用 oracle 評估 + recheck freshness。

## M4 接續

**End-of-run report**：batch call 出 overall_health / fix_priority / flaky_likelihood，寫進 `REGRESSION_REPORT_PATH`。

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|---|---|---|---|
| M0 | 2026-09-28 | 環境探勘：看 docs/backlog.md、docs/ac/US-101.md、regression-guard skill 子檔 | 先理解現實再動工 |
| M1 | 2026-09-28 | 4 檔 PoC：oracle + AC parser + example runner + cache fixture | 證明「讀 AC → Jev → verdict」流程跑得起來 |

---

**核心精神**：regression-guard 不只記錄「test 是 pass 還是 fail」，而是「這個 fail 是真 bug、flaky、還是 AC 本身寫得不好」。Jev oracle 把這層語意判定帶進來，用 confidence gating 確保不誤導修正循環。
