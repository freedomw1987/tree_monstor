# API Contract — 探針 / 模組 / 環境變量 / 本機 CI runner

> 本檔講**介面契約**：API 合約、環境變量、safety 規則、runner 回傳碼；對應章節見同套 `dav-developer` skill。
> 判準同流程 → 同套本 skill 子檔（`./jev-oracle.md`）；輸出長相 → 同套本 skill 子檔（`./output-format.md`）。

## 探針 API 合約

- **`probe(name, actual, expected)`** — `name`（string）：探針名稱（描述性）；`actual`（any）：實際值；`expected`（any）：預期值；**return**：通過時
✅，失敗時 ❌ ＋ suggestion
- **`assert(condition, message)`** — `condition`（bool）：布林條件；`message`（string）：描述文字；**return**：通過時 ✅，失敗時 ❌
- **`describe(name, fn)`** — `name`（string）：套件名稱；`fn`（function）：包含探針的函數／區塊；**return**：分組結果

## 環境變量

- **`REGRESSION_MODE`** — 預設值：`false`；說明：開關探針
- **`REGRESSION_OUTPUT`** — 預設值：`both`；說明：輸出格式：`json`／`text`／`both`
- **`REGRESSION_STRICT`** — 預設值：`true`；說明：遇錯即停
- **`REGRESSION_REPORT_PATH`** — 預設值：`./report.json`；說明：報告路徑
- **`REGRESSION_MODULE`** — 預設值：（未設定）；說明：Module 範圍限定（v2.9 新增）：設為 `M01` 時只跑 `M01-*` prefix 的探針；未設定 = 跑全部；Module 代碼定義見
monorepo 對應的系統設計文件
- **`OBSERVER_BACKEND`** — 預設值：`ac_aware`；說明：observer backend（`ac_aware`／`mock`／`playwright`）
- **`JEV_FIX_PROPOSAL`** — 預設值：（未設定）；說明：`=1` 開 M6 fix proposal（信心度報告 ＋ 失敗走跡）
- **`JEV_FIX_PROPOSAL_V2`** — 預設值：（未設定）；說明：`=1` 開 M6.1 LLM Relay（產 prompt bundle ＋ final report）
- **`JEV_PATCH_AND_REVALIDATE`** — 預設值：（未設定）；說明：`=1` 開 M6.2 patch ＋ re-validate 閉環（產 `-patches.json`）
- **`JEV_SANDBOX_RUN`** — 預設值：（未設定）；說明：`=1` 開 M6.3 互動式 sandbox（自動 apply／re-validate／rollback）
- **`JEV_FLAKY_INTEGRATION`** — 預設值：（未設定）；說明：`=1` 開 M7 flaky 整合（跑 pipeline 同時額外跑 2 次算 flaky_likelihood）
- **`JEV_GH_PR_COMMENT`** — 預設值：（未設定）；說明：`=1` 開 M7 gh pr comment
- **`GITHUB_PR_NUMBER`** — 預設值：（未設定）；說明：PR comment 目標 PR 號
- **`OPENROUTER_API_KEY`** — 預設值：（未設定）；說明：Jev API key；缺 key／網絡錯 → 降級做純 LLM 評分（要明示）

## M6.2 模組 API ＋ safety 規則

- **`patch_parser.py`** — 抽 `(file, old, new)` → `parse_fix_proposal(md_text)`
- **`playwright_patcher.py`** — apply patch：dry-run／apply／rollback → `apply_patch(file, old, new, dry_run=True)`
- **`re_validate.py`** — 比較 before/after verdict 分布 → `re_validate(before.json, after.json)`

**safety 規則**（`playwright_patcher.py`）：

- **`old_text` 不存在** — 動作：❌ abort
- **`old_text` 出現 > 1 次** — 動作：❌ abort（拒絕靜默套用）
- **`old_text` 出現 1 次 ＋ dry-run** — 動作：👀 產 diff 報告 ＋ 建 .bak，不改檔案
- **`old_text` 出現 1 次 ＋ `--apply`** — 動作：✅ apply ＋ .bak 已建
- **`--rollback`** — 動作：⏪ 從 .bak 還原

**自動分類**（`re_validate.py`）：fail delta < 0 → 🟢 improvement（keep patch）｜> 0 → 🔴 regression（rollback）｜= 0 → 🟡
no_change（review）。

## M6.3 sandbox_runner 模組 ＋ safety 規則

- **1. 建立 sandbox** — 動作：mkdir ＋ copy fixture ＋ 備份到 `.pre-patch/`；輸出：sandbox 目錄已建
- **2. apply patch** — 動作：playwright_patcher.py in sandbox；輸出：file 已改（sandbox 內）
- **3. 重跑 journey** — 動作：run_journey.py 產 after.json；輸出：verdict_after
- **4. re-validate** — 動作：re_validate.py 比對；輸出：classification: improvement／regression／no_change
- **5. auto rollback** — 動作：若 regression：從 .pre-patch/ 還原；輸出：file 回到 baseline
- **6. cleanup** — 動作：shutil.rmtree(sandbox)；輸出：隔離目錄已刪

**safety 規則**（繼承 M6.2）：ambiguous old → 整個 sandbox abort，cleanup 仍跑｜not-found old → 同上｜sandbox 目錄不論結果都刪，不留垃圾｜主 repo
永遠不被改。
**Return code**：error=1，regression=2，improvement／no_change=0。

## flaky_check 模組 API

- **`RunRecord`** — 一次跑嘅 verdict 計數 ＋ blocked ＋ wall time
- **`analyze_runs(runs)`** — 聚合 ＋ 計 flaky_likelihood ＋ 分類
- **`render_flaky_report(report)`** — 渲染 flaky_report.md

## 本機 CI runner 契約（run_ci.sh）

- **`probes`** — 用途：跑 `tests/v2.1-jev-poc.bats`；需 API key：❌
- **`pipeline`** — 用途：跑 `run_pipeline.sh <STORY>`；需 API key：✅（本機 `OPENROUTER_API_KEY`）
- **`matrix`** — 用途：跑多個 story ＋ 匯總 `matrix-summary.md`；需 API key：✅
- **`cleanup-scan`** — 用途：跑文件減法盤點（內部行 `cleanup-scan.py --json`）；需 API key：❌

**Return code gate**（同原本 workflow 一致）：`0`（green）通過｜`2`（yellow）warning，唔擋｜`1`（red）error，**擋**｜`3` 用法／環境錯誤（缺 key／缺 venv）。
**Verdict 來源**：由 batch report JSON 嘅 `overall_health` 讀（`run_pipeline.sh` 嘅離開碼永遠係 0 → 捉唔到紅燈）。
**背景**：2026-10-27 用戶決策「ci 在本地跑都得，不用在 github 上跑」→ 原本嘅 GitHub Actions workflow **已刪除**；原本 4 個
job（`bats`／`pipeline`／`aggregate-matrix`／`cleanup-scan`）改由本機 runner 承擔；目標專案想自己喺 GitHub Actions 跑（secrets／branch
protection）見 monorepo 對應的 CI 文件。

## cleanup-scan 分類契約（文件減法盤點）

- **適用情境**：repo 文件會隨時間累積（PRD、reflection、audit trail）；定期自動掃描找出「建議刪除」的文件。
- **排程**：2026-10-27 起本 repo 唔喺 GitHub Actions 跑 → **自己排程或人手跑** `./PoC/run_ci.sh cleanup-scan`。
- **4 類分類**：
  - **KEEP** — 標準：≥2 cross-link 或 protected pattern；動作：保留
  - **REVIEW** — 標準：1 cross-link；動作：人工 review（考慮是否 merge／補連結／刪）
  - **DELETE** — 標準：0 cross-link；動作：⚠️ 警告：考慮刪除（仍需人工 `--apply`）
  - **MERGE** — 標準：TODO；動作：預留 hook（v2.0 規則禁止改存量，未實作）
- **為什麼不自動刪 DELETE**：可能是 audit trail｜可能是重要文件但缺交叉引用｜可能是 contributor 故意留下的 work-in-progress。
- **為什麼是 weekly 不是 daily**：文件分類變化不快；daily 太頻繁，CI minutes 浪費。
