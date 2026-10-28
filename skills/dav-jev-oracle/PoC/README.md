# Dav Developer — Jev PoC (M1)

> 把 `dav-developer` skill 升級成「**用戶旅程模擬回歸測試**」的最小可行 PoC。
>
> **這個目錄是 PoC**，**不是** production code。Skill 本體（主檔、示例、測試方法指南）沒動。

## TL;DR

1. **做什麼**：用 OpenRouter 上的 `typesafe/jev-1.13` 當 structured decision
   oracle，把「**讀 AC 文字 + 觀察結果 → 判定過 / fail / flaky / 過度斷言**」這件事自動化。
2. **何時觸發**：每個 User Story 跑完 user journey 後，需要語意判定「這條 AC 算不算過」。
3. **預設 SOP 路徑**：`dav-developer` Step 3 之後插一個新 Step「**oracle 評估**」、再進 Step 4 修正循環。
4. **關鍵紀律**：
   - **語意判定而非字串比對**：Jev 看的是 AC 文字 + 觀察的 state，跑出 typed verdict
   - **Confidence gating**：低信心判定先送 review，不要誤導修正循環
   - **Cache-first**：沒 API key 時先用本地 cache 跑通流程；有 key 才打真實 API
   - **AC schema = PoC/fixtures/ac/US-XXX.md 的 Given/When/Then 結構**（別自創格式）
5. **必產出物**：`OracleResult { verdict, severity, confidence }` × 每條 AC + end-of-run summary

## 目錄結構

```PoC
/

├─ jev_oracle.py          # 核心：Jev HTTP 呼叫 + 回應解析 + cache
├─ ac_schema.py           # 解析 PoC/fixtures/ac/US-XXX.md → 結構化 AC 條目
├─ example_run.py         # 示範：US-101 真實 AC + 4 個 mock 觀察 → 跑 oracle
├─ journey_generator.py   # 讀 AC → 走 Jev complexity + action plan → 產 Journey spec
├─ journey_gen.py         # CLI: journey_generator 的命令列 entry
├─ journey_runner.py      # Dry-run loop: observe→Jev→verdict→recheck→stale detection
├─ run_journey.py         # CLI: 跑 journey_runner（--stale-test + --json-output）
├─ batch_report.py        # M4 核心：4 題 batch call → overall_health / fix_priority / flaky_likelihood / regression_type
├─ run_report.py          # CLI: batch_report 的入口
├─ run_pipeline.sh        # 🚀 一鍵跑 M2 → M3 → M4
├─ fix_proposal.py / fix_proposal_v2.py   # M6 / M6.1：信心度報告 + LLM relay
├─ playwright_patcher.py / re_validate.py / sandbox_runner.py  # M6.2 / M6.3：patch + re-validate 閉環
├─ flaky_check.py / flaky_integration.py / gh_pr_comment.py   # M7：flaky 量測 + PR comment
├─ journeys/
│  └─ US-101.yaml        # 產出的人類可讀 journey spec（要進 git）
├─ fixtures/              # config-driven 觀察 fixture（脫離 hardcode）
├─ requirements.txt       # 執行期依賴（httpx / PyYAML）—— 唯一來源
├─ setup-venv.sh          # 一鍵建 venv + 裝 requirements.txt（優先 uv，否則 python3 -m venv；--force 有破壞性護欄）
├─ cache/
│  ├─ fixture_helper.py   # 預塞假 Jev 回應（沒 key 時 demo 用）
│  └─ *.json              # 自動 cache（gitignored）
├─ .env.example           # OPENROUTER_API_KEY 範本
└─ README.md              # ← 你正在看
```

## 怎麼跑（沒 API key）

```bash
c
d skills/dav-jev-oracle/PoC

# 1. 建 venv 並裝依賴（httpx + PyYAML）；有 uv 用 uv，沒有就 python3 -m venv
bash setup-venv.sh

# 1b.（可選）--force 砍掉重建
bash setup-venv.sh --force                                   # 預設 .venv：直接重建
POC_VENV_DIR=~/tmp/venv bash setup-venv.sh --force           # 自訂目錄：要你輸入 `venv` 確認
POC_VENV_DIR=~/tmp/venv bash setup-venv.sh --force --yes     # 非互動（腳本）免除二次確認

# 2. seed 預塞假 Jev 回應
.venv/bin/python cache/fixture_helper.py

# 3. 跑 oracle demo（4 條 AC、4 種 verdict）
.venv/bin/python example_run.py
```

> **⚠️ 破壞性護欄（TMO-040 / NYH-5 方案 A）**：`--force` 會 `rm -rf "$VENV_DIR"`，所以腳本擋兩層：
> ①**危險清單**（`$HOME` 本體、`$HOME/Documents`、`/private/tmp`、`/usr`、`/etc` …，以及容器本體直接子項
> `/Users/<x>`、`/Volumes/<碟>`、`/home/<x>`（層數==2，TMO-056））命中即拒，
> **`--force` 與 `--yes` 都不能繞過**（`HOME` 帶尾斜線、symlink 祖先、大小寫變體
> （`/private/TMP` 在 macOS 就是 `/private/tmp`）這三種字面繞道也堵了：存在的目錄另用
> `pwd -P` 取物理路徑比對一次，兩邊都比對前先轉小寫）；②自訂 `POC_VENV_DIR` 且目錄已存在時，`--force` 需
> **輸入目錄名**確認（讀不到輸入一律「不刪就退出」）。守門探針：`tests/poc-venv-guard.bats`（12 條）。

會看到：

```
▶ US-101-AC01  verdict=pass    confidence=0.97

▶ US-101-AC02  verdict=fail    confidence=0.99  is_real_bug=0.74
▶ US-101-AC03  verdict=flaky   confidence=0.60  is_real_bug=0.64
▶ US-101-AC04  verdict=fail    confidence=0.67  is_real_bug=0.65
```

## 怎麼跑（真 API）

```bash
# API key 放 ~/.zshrc（**本機正規來源**），唔好版控任何 key：

#   echo 'export OPENROUTER_API_KEY="sk-or-v1-..."' >> ~/.zshrc && source ~/.zshrc
#   ⚠️ ~/.zshrc 只喺互動 shell 讀；非互動 shell 請改用 ~/.zshenv（zsh 唯一全 shell 都讀嘅檔）。
#   ⚠️ CI 唔讀本機檔 → 用 secrets.OPENROUTER_API_KEY。
#
# 程式讀取順序：環境變數 → PoC/.env → ~/.claude/skills/dav-jev-oracle/PoC/.env
# （**後兩者**係後備；JEV_ENV_FILE=/dev/null 可令「完全冇 .env」）

.venv/bin/python example_run.py           # 走 oracle，cache hit 就 hit
.venv/bin/python journey_gen.py \
    ../fixtures/ac/US-101.md           # 產 journey YAML
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

```journeys
/US-101.yaml     ← human-readable journey spec（git tracked）

/tmp/US-101-run.json     ← M3 run 結果（給 M4 讀）
report.json              ← batch report 機器版
report.md                ← batch report 人讀版（emoji + 表格 + 每步結果）
```

## Milestone 完成證據

- **M1** oracle
  - 核心產出：`jev_oracle.py` + `ac_schema.py` + `example_run.py` + cache
  - 證據：
    讀真實 `PoC/fixtures/ac/US-101.md` → parse 出 4 條 AC；跑出 4 種 verdict（pass / fail / flaky / over_assertion）；cache 機制（含 key
    雜湊 / save / load）；confidence + severity + verdict probabilities 完整呈現；end-of-run summary；真 API
    打接（`/api/alpha/decisions`）；API key 自動讀取（環境變數為主，`JEV_MODEL` 可切模型）
- **M2** journey 生成
  - 核心產出：`journey_generator.py` + `journey_gen.py`
  - 證據：
    讀 AC → 兩階段 Jev call（complexity score + action plan choice）→ human-readable YAML；自動拆步（complexity 0-3 → 1~4 步 /
    AC）+ depends_on chain；US-101 4 條 AC → 9 步（2.25 步 / AC）、8 個 Jev call、3.4s
- **M3** dry-run loop
  - 核心產出：`journey_runner.py` + `run_journey.py`
  - 證據：
    observe → Jev → verdict → recheck 迴路；AC-aware mock 觀察器；stale detection（連續 3 步同 state + fail →
    block）；`--json-output` 落盤；US-101 預設 3 pass / 6 fail / 0 block / 2ms 全 cache；stale-test 模式 7 fail + 2 BLOCKED
- **M4** batch report
  - 核心產出：`batch_report.py` + `run_report.py` + `run_pipeline.sh`
  - 證據：
    4 題 batch call（overall_health / fix_priority / flaky_likelihood / regression_type）；`REGRESSION_REPORT_PATH`
    env；Markdown 報表（emoji + 表格 + 每步結果 + 信心分布）；US-101 → 🔴 red / fix_priority 2.93 / flaky 0.22 / real_bug；Cost
    $0.000070 / latency 628ms（cache 重跑免費）
- **M5** 去 hardcode
  - 核心產出：`fixtures/US-101.yaml` + `_load_fixture()`
  - 證據：
    config-driven 觀察（脫離 hardcoded dict）；stale 限「同一 AC」（`current_ac_id` 狀態機）；`mock_observe_static`（stale-test 門檻降為
    2）；`run_dry()` 統一入口（CLI 從 ~50 行收縮到 ~20 行）；`skills/dav-jev-oracle/tests/v2.1-jev-poc.bats` 16 探針全綠；向後相容（仍 3 pass
    / 6 fail）

**M5 化解決的 TMO-011 反思問題**：
`ac_aware_observe` hardcoded → config-driven｜Stale 跨 AC 誤判 → 狀態機 reset｜
`--stale-test` 散在 CLI → 抽進 `run_dry()`｜無 bats 探針 → 16 探針。

## CI 整合（本機跑）

2026-10-27 用戶決策：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」
→ GitHub Actions workflow 已刪除；改用本機 runner `skills/dav-jev-oracle/PoC/run_ci.sh`：

- **`probes`**
  - 用途：跑 `skills/dav-jev-oracle/tests/v2.1-jev-poc.bats`
  - 不需 / 需 API key：不需
- **`pipeline`**
  - 用途：跑 `run_pipeline.sh <story>`
  - 不需 / 需 API key：需（本機 `OPENROUTER_API_KEY`）
- **`matrix`**
  - 用途：跑多個 story ＋ 匯總 `matrix-summary.md`
  - 不需 / 需 API key：需
- **`cleanup-scan`**
  - 用途：跑 `docs/cleanup/cleanup-scan.py`
  - 不需 / 需 API key：不需

**Return code gate**：`0` (green) 通過｜`2` (yellow) warning（唔擋）｜`1` (red) error，擋｜`3` 用法／環境錯誤。

詳細（本機用法 ＋ 目標專案用 GH Actions 參考）見
[`docs/ci/dav-jev-oracle.md`](../../../docs/ci/dav-jev-oracle.md)。

---

**核心精神**：dav-developer 不只記錄「test 是 pass 還是 fail」，而是「這個 fail 是真 bug、flaky、還是 AC 本身寫得不好」。Jev oracle 把這層語意判定帶進來，用
confidence gating 確保不誤導修正循環。

**已完成**：M3.1 Playwright Chrome driver + dispatcher（`OBSERVER_BACKEND=playwright` 切換）｜
M6 fix proposal CLI + SKILL Step 4 整合｜**本機 CI runner + return code gate**（2026-10-27：唔再喺 GitHub Actions 跑）。

**Out of scope（順延到真實 PENDING US 觸發時）**：M3.2 真實 driver 跑 example.com｜
目標專案喺自己 repo 開 GitHub Actions（branch protection 實際開設）｜cleanup-scan 自動排程。
