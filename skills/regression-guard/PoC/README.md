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
├─ journey_generator.py  # 讀 AC → 走 Jev complexity + action plan → 產 Journey spec
├─ journey_gen.py        # CLI: journey_generator 的命令列 entry
├─ journey_runner.py     # Dry-run loop: observe→Jev→verdict→recheck→stale detection
├─ run_journey.py        # CLI: 跑 journey_runner（支援 --stale-test 證邏輯 + --json-output）
├─ batch_report.py       # M4 核心：4 題 batch call 出 overall_health / fix_priority / flaky_likelihood / regression_type
├─ run_report.py         # CLI: batch_report 的入口
├─ run_pipeline.sh       # 🚀 一鍵跑 M2 → M3 → M4
├─ journeys/
│  └─ US-101.yaml        # 產出的人類可讀 journey spec（要進 git）
├─ cache/
│  ├─ fixture_helper.py  # 預塞假 Jev 回應（沒 key 時 demo 用）
│  └─ *.json             # 自動 cache（gitignored）
├─ .env.example          # OPENROUTER_API_KEY 範本
└─ README.md             # ← 你正在看
```

## 怎麼跑（沒 API key）

```bash
cd skills/regression-guard/PoC

# 1. 建 venv 裝 httpx + pyyaml
uv venv && uv pip install httpx pyyaml

# 2. seed 預塞假 Jev 回應
.venv/bin/python cache/fixture_helper.py

# 3. 跑 oracle demo（4 條 AC、4 種 verdict）
.venv/bin/python example_run.py
```

會看到：

```
▶ US-101-AC01  verdict=pass    confidence=0.97
▶ US-101-AC02  verdict=fail    confidence=0.99  is_real_bug=0.74
▶ US-101-AC03  verdict=flaky   confidence=0.60  is_real_bug=0.64
▶ US-101-AC04  verdict=fail    confidence=0.67  is_real_bug=0.65
```

## 怎麼跑（真 API）

```bash
# .env 三個地方可以放，自動找到：
#   1. PoC/.env
#   2. ~/.claude/skills/regression-guard/PoC/.env
#   3. export OPENROUTER_API_KEY=...

.venv/bin/python example_run.py           # 走 oracle，cache hit 就 hit
.venv/bin/python journey_gen.py \
    ../../../docs/ac/US-101.md           # 產 journey YAML
.venv/bin/python example_run.py --no-cache  # 強制 live
```

## 🚀 一鍵 pipeline（M2 → M3 → M4）

```bash
# 走完全流程（generate journey → run → batch report）
./run_pipeline.sh US-101

# 換輸出位置（預設 ./report）
REGRESSION_REPORT_PATH=./out/US-101-report ./run_pipeline.sh US-101

# 用 --stale 驗證 stale detection 邏輯
./run_pipeline.sh US-101 --stale

# 強制重跑 M2（產新 YAML，預設讀 cache）
REGEN_JOURNEY=1 ./run_pipeline.sh US-101
```

會產出：
```
journeys/US-101.yaml     ← human-readable journey spec（git tracked）
/tmp/US-101-run.json     ← M3 run 結果（給 M4 讀）
report.json              ← batch report 機器版
report.md                ← batch report 人讀版（emoji + 表格 + 每步結果）
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
| 真 API 打接 + 介面正確（/api/alpha/decisions）| ✅ |
| 三層 API key 自動讀取（env / PoC/.env / ~/.claude/.../PoC/.env）| ✅ |

## M2 完成的證據

| 項 | 狀態 |
|---|---|
| `journey_generator.py`：讀 AC → 兩階段 Jev call（complexity score + action plan choice）| ✅ |
| `journey_gen.py` CLI entry | ✅ |
| 產 human-readable YAML 到 `journeys/<story_id>.yaml` | ✅ |
| 自動拆步（依 complexity 0-3 → 1~4 步 / AC）| ✅ |
| Step 之間 depends_on chain（跨 AC 串連）| ✅ |
| Cache 機制（同一個 AC 不會重 call Jev）| ✅ |
| US-101 4 條 AC → 9 步（2.25 步 / AC），8 個 Jev call，3.4s | ✅ |

## M3 完成的證據（dry-run loop）

| 項 | 狀態 |
|---|---|
| `journey_runner.py`：observe → Jev → verdict → recheck 迴路 | ✅ |
| `run_journey.py` CLI 兩種模式：ac-aware（預設）+ stale-test | ✅ |
| AC-aware mock 觀察器（用 fixture 對應 AC Then）| ✅ |
| Stale detection：連續 3 步同 state + fail → block | ✅ |
| `--json-output` 選項：把 run 結果落盤成可被 M4 讀的 JSON | ✅ |
| US-101 預設模式：3 pass / 6 fail / 0 block / 2ms 全 cache | ✅ |
| US-101 stale-test 模式：7 fail + 2 BLOCKED（驗證 block 邏輯）| ✅ |
| 每步 verdict + confidence + severity + is_real_bug 全印出 | ✅ |

## M4 完成的證據（end-of-run batch report）

| 項 | 狀態 |
|---|---|
| `batch_report.py`：4 題 batch call（overall_health / fix_priority / flaky_likelihood / regression_type）| ✅ |
| `run_report.py` CLI：讀 run JSON → Jev batch → 寫 report.json + .md | ✅ |
| 支援 `REGRESSION_REPORT_PATH` env（指定輸出 basename）| ✅ |
| Markdown 報表：emoji + 表格 + 每步結果 + 信心分布 | ✅ |
| `run_pipeline.sh` 一鍵跑完 M2 → M3 → M4 | ✅ |
| US-101 batch report：🔴 red / fix_priority 2.93 / flaky 0.22 / real_bug | ✅ |
| Cost $0.000070 / latency 628ms（單次 Jev call）/ cache 重跑免費 | ✅ |

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

**Journey runner**：Chrome + DOM snapshot driver（dry-run loop 先、不接 Chrome；接 Chrome 留 M3.1）。每步用 oracle 評估 + recheck freshness。## M4 接續

**End-of-run report**：batch call 出 overall_health / fix_priority / flaky_likelihood，寫進 `REGRESSION_REPORT_PATH`。✅ 完成

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|---|---|---|---|
| M0 | 2026-09-28 | 環境探勘：看 docs/backlog.md、docs/ac/US-101.md、regression-guard skill 子檔 | 先理解現實再動工 |
| M1 | 2026-09-28 | oracle + AC parser + example runner + cache fixture；介面改 /api/alpha/decisions；加三層 key loader；真 API 驗證 | 證明「讀 AC → Jev → verdict」流程跑得起來 |
| M2 | 2026-09-28 | journey_generator.py + journey_gen.py CLI；兩階段 Jev call（complexity score + action plan choice）；產 journeys/US-101.yaml | 證明「讀 AC → Jev 自評拆步 → 產 journey spec」跑得起來 |
| M3 | 2026-09-28 | journey_runner.py + run_journey.py CLI；dry-run loop；AC-aware mock observer；stale detection（--stale-test 驗證）；加 --json-output | 證明 observe→Jev→verdict→recheck 迴路 + block 機制跑得起來，不接 Chrome |
| M4 | 2026-09-28 | batch_report.py + run_report.py CLI；4 題 batch call；report.json + .md 雙輸出；run_pipeline.sh 一鍵串接 M2→M3→M4 | 證明 end-of-run 4 維度綜合判定跑得起來（overall_health / fix_priority / flaky_likelihood / regression_type）|
| M5 | 2026-09-28 | (a) fixtures/US-101.yaml + `_load_fixture()`（脫離 hardcoded fixture）；(b) stale 限「同一 AC」+ `mock_observe_static`；(c) `run_dry()` 統一入口；(d) `tests/v2.1-jev-poc.bats` 16 探針 | 16/16 bats 探針過；M3 行為完全向後相容（3 pass / 6 fail）|

---

## M5 完成的證據（去 hardcode + 重構 + 探針覆蓋）

| 項 | 狀態 |
|---|---|
| `fixtures/US-101.yaml` config-driven（脫離 hardcoded `AC_AWARE_FIXTURES` dict）| ✅ |
| `ac_aware_observe(step, prev, story_id=...)` 從 YAML 自動載入 | ✅ |
| Stale detection 限「同一 AC」連續（`current_ac_id` 狀態機，換 AC reset counter）| ✅ |
| `mock_observe_static` 強制同 state（讓 stale-test 仍能 trigger block，門檻降為 2）| ✅ |
| `run_dry(journey, story_acs, stale_test=...)` 統一入口（CLI 不再 inline 邏輯）| ✅ |
| `run_journey.py` 從 ~50 行收縮到 ~20 行；`run_dry()` 一行 dispatch | ✅ |
| `tests/v2.1-jev-poc.bats` 16 探針：4 區塊 + 2 runtime | ✅ 16/16 |
| 向後相容：M3 預設模式仍 3 pass / 6 fail（無迴歸）| ✅ |

```bash
# 跑探針
bats tests/v2.1-jev-poc.bats
# → 1..16, all ok
```

---

**核心精神**：regression-guard 不只記錄「test 是 pass 還是 fail」，而是「這個 fail 是真 bug、flaky、還是 AC 本身寫得不好」。Jev oracle 把這層語意判定帶進來，用 confidence gating 確保不誤導修正循環。

**M5 之後的 next step（已超出 PoC 範圍）**：
- **M3.1**：接 Playwright Chrome driver，observer 改 DOM snapshot，不再用 mock fixture
- **M6（future）**：把「修正循環」接進 regression-guard skill — Jev verdict → 自動產 fix proposal → 跑回 validate
- **PR 階段**：把所有 5 個 milestone 整合回 SKILL.md / examples.md，變成正式規範

## M5 化解決的 TMO-011 反思問題

| 反思項 | M5 解決方式 |
|---|---|
| `ac_aware_observe` hardcoded | → `fixtures/<story_id>.yaml` config-driven |
| Stale 跨 AC 誤判 | → `current_ac_id` 狀態機 + `same_ac` reset |
| `--stale-test` 散在 CLI | → 抽進 `runner.run_dry(stale_test=True)` |
| 無 bats 探針 | → 16 探針（4 區塊 + 2 runtime）|
