# Jev Oracle 補充（進階）+ CI 整合

> 本檔為 regression-guard 的「Jev Oracle 補充」+「CI 整合補充」章節（v2.2-v2.8 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：Jev Oracle 506 行 + CI 整合 30 行 = 536 行屬於「進階 / 可選」，不在「skill 基本用法」主流程上。
>
> ⚠️ **本檔是**可選章節**：預設 regression-guard 流程（Steps 1-4 + 上述全部規則）對多数項目已足夠。只有在下列**特殊場景**下，才需要用 Jev oracle 加一層語意判定。

## 適用場景

1. **AC 驗收容易誤判的「柔性」条件**：「紅字提示」」「友好錯誤」」「流暢體驗」這類主觀描述，Jev 能解讀「鬆 / 緊」口徑。
2. **同個 fail 背後多種原因**：「真 bug」「flaky」「AC 寫得不好」這 3 種原因，傳統 pass/fail 沒分，後續修正循環會浪費時間。
3. **Confidence-gated 自動行動**：CI 看到 `severity >= 2.5` 才開 issue；`flaky_likelihood > 0.7` 自動重跑；避免每一次 transient fail 都打閿開發者。

## 不適用的場景

- **純語法 / 類型 / CRUD 測試**：傳統斷言快又準，Jev 反而慢 + 貴。
- **高頻跑數千例的微探針**：Jev API 有 cost / latency，量起來傷荷包。
- **Determinism 要求 100% 的場景**（如金融交易）：Jev 每次 verdict 可能微跳（ac 是語意判定不是 bool）。

## 怎麼試

Jev PoC 已在 `skills/regression-guard/PoC/` 跑出 M1-M5 完整 milestone，**以 `US-101` 付款頁為範例**，4 個產出物可參考：

| 產出物 | 用途 |
|---|---|
| `PoC/README.md` | Milestone 紀錄 + 快用範例 |
| `PoC/journey_runner.py` | observe→Jev→verdict→recheck 迴路 |
| `PoC/batch_report.py` | 4 維度 end-of-run 報告 |
| `PoC/run_pipeline.sh` | M2→M3→M4 一鍵串接 |

**3 種 observer backend 選用**：

```bash
# 預設：ac_aware（從 fixtures/<story_id>.yaml 讀）
.venv/bin/python run_journey.py journeys/US-101.yaml

# 純 mock（不接 fixture）
OBSERVER_BACKEND=mock .venv/bin/python run_journey.py journeys/US-101.yaml

# 真 Chrome driver（要 uv pip install playwright + playwright install chromium）
OBSERVER_BACKEND=playwright .venv/bin/python run_journey.py journeys/US-101.yaml
```

## 實作成本預估

| 階段 | 預估 | 重點 |
|---|---|---|
| PoC 評估 | 1 sprint | 以一個 PENDING US 跑 M1-M5 驗證 4 維度判定是否準確 |
| 整合進主流程 | 1 sprint | 把 Jev 該在的 Gate 調進 Steps 1-4；不是取代是補充 |
| 換 driver | 1 sprint | 從 fixture 轉 Playwright Chrome / Chrome DevTools Protocol |
| CI 接 batch report | 半天 | batch report JSON 進 issue tracker / Slack |

## 探針選名參考

如果決定採用，探針名稱可加 `JEV-` prefix 區分：

```
JEV-US-101-AC01-red-error-message
JEV-US-101-AC02-friend-checkout-flow
JEV-US-101-AC04-confirmed-200-not-500
```

跟傳統 `US-101-AC01` 並行、不重疊，CI 可選只跑哪一類。

## 修正循環補充（M6 自動 fix proposal）

適用情境：M3 runner 跑出 `real_bug` verdict 後，手動看 batch report 太慢，**先讓 Jev 給出信心度報告**幫 reviewer 加速。

作法（PoC 階段，3 題 noul batch call）：

```bash
# 1. 跑完整 pipeline（觸發 M6）
JEV_FIX_PROPOSAL=1 .venv/bin/python fix_proposal.py /tmp/<STORY>-run.json
# → /tmp/<STORY>-fix-proposal.md

# 2. 或一鍵
JEV_FIX_PROPOSAL=1 ./run_pipeline.sh US-101
```

`fix_proposal.py` 會產出：

| 區塊 | 內容 |
|---|---|
| **整體信心度** | 3 題平均 noul 概率 (0–1) + 評級 (高/中/低/不可判定) |
| **信心度評估表** | 問題摘要 / 建議修正 / 驗證步驟 三維度各自的信心度 |
| **原始失敗走跡** | 失敗步的 URL / status / body 截錄 200 字 |
| **上下文** | Journey ID / verdict counts / blocked 狀態 |

**重要限制**（v1 範圍）：

- Jev v1.13 **不支援 free_response** 題型，只有 `choice` / `score` / `noul` 三種
- 所以 M6 階段的 fix proposal 是 **「信心度報告 + 失敗走跡」**，不是自動寫出 fix 文字
- Reviewer 接手起點：**看信心度表格 → 找最低那一維 → 對應走跡去定位 component**
- 0.5 為 gating 門檻：≥0.5 自動接手；<0.5 先加 observer context 再跑

**升級路徑**（M6.1+，需另起 sprint）：

- 接 Claude / GPT 生成實際 fix 文字，Jev 信心度作為 gating（低信心不送 LLM）
- 接 patch + re-validate 自動迴圈（playwright driver 拿到 fix 文字 → 跑回 validate）
- 詳見 [`examples.md`](./examples.md) 「Jev Oracle 範例」章節的 fix proposal 範例

## M6.1 修正循環補充：LLM Relay（v2 接力）

**適用情境**：v1 M6 fix proposal 跑出整體信心度 **≥ 0.5** 時，由「當下對話的 LLM agent」接力寫 fix 文字。

**為什麼是 skill 本身 LLM（不接外部 Claude/GPT）**：

- regression-guard 本身是個 skill → 召喚它時的 LLM（subagent / pi 本身）就是「接力的 LLM」
- 不增加外部依賴、不增加 API cost、不增加 prompt 邏輯雙重來源
- prompt template 是「檔案」而非 hardcoded 字串 → 可由 skill 維護者迭代、不需改 code

**怎麼用**：

```bash
# 1. pipeline 產 v1 + v2 + prompt bundle
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-101
# → /tmp/r-fix-proposal-v2.md
# → /tmp/US-101-run.relay/prompt.md

# 2. 手動召喚 subagent 接力（讀 prompt.md，寫 answer.md）
#    這個步驟在對話中進行：
#    - 讀 /tmp/US-101-run.relay/prompt.md
#    - 按 template 「產出」段寫 fix
#    - 寫到 /tmp/US-101-run.relay/answer.md

# 3. 拼 final report
.venv/bin/python fix_proposal_v2.py /tmp/US-101-run.json \
  /tmp/r-final.md --answer-from /tmp/US-101-run.relay/answer.md
# → /tmp/r-final.md 含 Jev 信心度 + LLM relay 文字 + 走跡對照
```

**信心度 gating 規則**（[`fix_proposal_v2.py`](../../skills/regression-guard/PoC/fix_proposal_v2.py) `RELAY_GATING_THRESHOLD`）：

| 整體信心度 | 動作 | final report 內容 |
|---|---|---|
| ≥ 0.5 | ✅ 召喚 LLM relay，產 prompt bundle | 信心度報告 + LLM 接力文字 + 走跡對照 |
| 0.25–0.49 | ❌ 跳過 LLM relay | 信心度報告 + 走跡，標「reviewer 接手」|
| < 0.25 | ❌ 跳過，明確標「需先加 observer context」| 同上 + 警告 |

**Prompt template 位置**：[`PoC/prompts/fix_relay.md`](./PoC/prompts/fix_relay.md)

模板涵蓋：
- 角色（regression-guard skill 的 LLM 接力 agent）
- 輸入（Jev 信心度 + 失敗走跡）
- 產出（3 段：問題分析 / 建議修正 / 驗證步驟，≤ 500 字）
- 約束（不重複數字、不虛構 code 路徑、不建議改 AC）
- 範例（輸入 / 產出對照）
- Gating 規則

**已知限制**（v2 範圍）：

- 接力 LLM 必須是「當下對話的 agent」 — CI 環境需特別設定（手動觸發 subagent 或加 `gh pr comment` step）
- Prompt template 是 markdown 而非 jinja — 簡單可讀但不支援條件邏輯
- Final report 中 LLM 接力段落沒有「versioning」— 改了 prompt template 跑出來的文字可能差很多，**需在 deliverable 中註明用的是哪一版 prompt**

## M6.2 修正循環補充：patch + re-validate 閉環

**適用情境**：M6.1 LLM Relay 產出的 fix 文字需要真的 apply 到 source file，並驗證是否真的修好。

**怎麼用**（sandbox 環境，手動三步）：

```bash
# 1. 跑 pipeline 產出 fix_proposal_v2.md
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  JEV_PATCH_AND_REVALIDATE=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-M62
# → /tmp/r-fix-proposal-v2.md + /tmp/r-patches.json

# 2. Dry-run patch（看 diff 不改檔案）
.venv/bin/python playwright_patcher.py <FILE> --old "..." --new "..."
# → unified diff 報告 + 自動備份 <FILE>.bak

# 3. 真的 apply
.venv/bin/python playwright_patcher.py <FILE> --old "..." --new "..." --apply

# 4. 重跑 journey（patch 後）
.venv/bin/python run_journey.py journeys/US-M62.yaml --json-output /tmp/US-M62-after.json

# 5. 比較 verdict 變化
.venv/bin/python re_validate.py /tmp/US-M62-before.json /tmp/US-M62-after.json
# → classification: improvement | regression | no_change
# → regression 時自動推薦 rollback：
.venv/bin/python playwright_patcher.py <FILE> --rollback
```

**三個模組**（在 `PoC/`）：

| 模組 | 角色 | 入口 |
|---|---|---|
| `patch_parser.py` | 從 fix_proposal_v2.md 抽 (file, old, new) | `parse_fix_proposal(md_text) → ParseResult` |
| `playwright_patcher.py` | apply patch（dry-run / apply / rollback）| `apply_patch(file, old, new, dry_run=True)` |
| `re_validate.py` | 比較 before/after verdict 分布 | `re_validate(before.json, after.json)` |

**safety 規則**（`playwright_patcher.py`）：

| 條件 | 動作 |
|---|---|
| `old_text` 不存在 | ❌ abort |
| `old_text` 出現 > 1 次 | ❌ abort（拒絕靜默套用）|
| `old_text` 出現 1 次 + dry-run | 👀 產 diff 報告 + 建 .bak，不改檔案 |
| `old_text` 出現 1 次 + --apply | ✅ apply + .bak 已建 |
| `--rollback` | ⏪ 從 .bak 還原 |

**自動分類**（`re_validate.py`）：

| fail delta | 分類 | 建議 |
|---|---|---|
| < 0 | 🟢 improvement | keep patch |
| > 0 | 🔴 regression | rollback |
| = 0 | 🟡 no_change | review |

**Pipeline 整合**：

`JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑 M2→M3→M4→M6→M6.1→M6.2。M6.2 步驟只「產 patch 素材」（`-patches.json`），apply / re-validate 仍需手動在 sandbox 跑（sandbox 限制：不能自動 commit / 不能無人工 apply）。

**為什麼 apply + re-validate 不全自動**：

- **sandbox 限制**：CI 環境不能無人工 commit；LLM 給的 patch 可能是錯的，需人工 review
- **safety**：rollback 機制 100% 可靠，但「LLM 接力文字可能錯」這點沒人為把關不行
- **scope 控制**：M6.2 不做「自動 commit」；patch 驗證通過後只留報告，由 reviewer 決定

## M6.3 修正循環補充：互動式 sandbox（M6.2 自動版）

**適用情境**：M6.2 還需手動 3 步（apply → 重跑 → re-validate）；M6.3 把這 3 步封裝成一個 sandbox 流程。

**怎麼用**（sandbox 環境，一鍵）：

```bash
# 一鍵跑 M2→M3→M4→M6→M6.1→M6.2→M6.3
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1 \
  ./run_pipeline.sh US-M63
# → 建 tmp/.sandbox-US-M63-<ts>/ 隔離工作目錄
# → copy fixture + journey + source file
# → apply patch in sandbox（不動主 repo）
# → 重跑 journey_runner.py 產 after.json
# → 自動 re_validate.py 比對 verdict
# → 若 regression：自動從 .pre-patch/ 還原
# → 產出 sandbox_report.md
# → 不論結果都 cleanup sandbox 目錄
```

**sandbox_runner.py 模組**（在 `PoC/`）：

| 步驟 | 動作 | 輸出 |
|---|---|---|
| 1. 建立 sandbox | mkdir + copy fixture + 備份到 `.pre-patch/` | sandbox 目錄已建 |
| 2. apply patch | playwright_patcher.py in sandbox | file 已改（sandbox 內）|
| 3. 重跑 journey | run_journey.py 產 after.json | verdict_after |
| 4. re-validate | re_validate.py 比對 | classification: improvement / regression / no_change |
| 5. auto rollback | 若 regression：從 .pre-patch/ 還原 | file 回到 baseline |
| 6. cleanup | shutil.rmtree(sandbox) | 隔離目錄已刪 |

**為什麼叫「互動式」**：
- apply in sandbox + re-validate + rollback 都**自動**
- 「要不要把 sandbox 的 patch 拿回主 repo + commit」仍**人工**

**safety 規則**（繼承 M6.2）：
- ambiguous old → 整個 sandbox abort，cleanup 仍跑
- not-found old → 同上
- sandbox 目錄不論結果都刪，不留垃圾
- 主 repo 永遠不被改

**return code**：error=1, regression=2, improvement/no_change=0

## Flaky 驗證：跑 N 次同一 journey 識别穩定性

**適用情境**：懷疑某個 journey 結果不穩定（同一 source 多次跑 verdict 分布不一樣）。

**怎麼用**：

```bash
.venv/bin/python flaky_check.py journeys/US-M62.yaml \
  --source docs/ac/US-M62.md \
  --story-id US-M62 --runs 5 \
  --output /tmp/flaky-usm62.md
# → 跑 5 次同一 journey
# → 聚合 verdict 分布
# → 計算 flaky_likelihood = total_range / (total_max + 1)
# → 分類：stable (<0.05) / mildly_flaky (<0.20) / highly_flaky (≥0.20)
# → 產出 flaky_report.md
```

**flaky_likelihood 公式**：

```
flaky_likelihood = Σ(verdict_max - verdict_min) / (Σ verdict_max + 1)
```

- `0.0`：每次都一模一樣（完全穩定）
- `接近 1.0`：每次 verdict 都大幅波動（完全 flaky）

**實測結果**（US-M62 5 次跑）：
- fail=12, blocked=1, pass=0 每次都一致
- flaky_likelihood = 0.0 → 🟢 **stable**

**flaky_check.py 模組**（在 `PoC/`）：

| 函數 | 用途 |
|---|---|
| `RunRecord` | 一次跑的 verdict 計數 + blocked + wall time |
| `analyze_runs(runs)` | 聚合 + 計算 flaky_likelihood + 分類 |
| `render_flaky_report(report)` | 渲染 flaky_report.md |

**為什麼 flaky_likelihood 重要**：
- **CI 訊號穩定**：穩定的 journey 結果可以信，flaky 的 journey 結果需謹慎解讀
- **regression 報告加值**：在 batch report 加上「這次跑是否 flaky」標記，避免被 flaky 結果誤導
- **debug 線索**：flaky 高的 journey 多半是 Jev cache 命中、observer 不穩、AC 定義模糊

## CI 定期檢查：docs/cleanup-scan 排程

**適用情境**：repo 文件會隨時間累積（PRD、reflection、audit trail）；定期自動掃描找出「建議刪除」的文件。

**怎麼用**（已配在現有 workflow）：

```yaml
# .github/workflows/regression-guard-jev-poc.yml
on:
  schedule:
    - cron: '0 0 * * 1'   # 每周一 00:00 UTC

jobs:
  cleanup-scan:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    steps:
      - run: python docs/cleanup/cleanup-scan.py --json
      - run: |
          DELETE=$(...)
          [ $DELETE -gt 0 ] && echo "⚠️ $DELETE 個建議刪除文件請 review" || true
```

**cleanup-scan.py 4 類**：

| 類別 | 標準 | 動作 |
|---|---|---|
| KEEP | ≥2 cross-link 或 protected pattern | 保留 |
| REVIEW | 1 cross-link | 人工 review（考慮是否 merge / 補連結 / 刪）|
| DELETE | 0 cross-link | ⚠️ 警告：考慮刪除（仍需人工 `--apply`）|
| MERGE | TODO | 預留 hook（v2.0 規則禁止改存量，未實作）|

**為什麼不自動刪 DELETE**：
- 可能是 audit trail（reflection、PRD-04、testing-methods.md 等都有保留價值）
- 可能是重要文件但缺交叉引用（單一來源）
- 可能是 contributor 故意留下的 work-in-progress

**為什麼是 weekly 不是 daily**：
- 文件分類變化不快（PRD、reflection 一次寫就不動）
- daily 太頻繁，CI minutes 浪費
- 每周一次夠 cover 「主動堆積」

**手動觸發**：`gh workflow run regression-guard-jev-poc.yml` 選 workflow_dispatch 即可。

## M7 修正循環補充：flaky 整合 + gh pr comment

**適用情境**：TMO-020 的 flaky_check.py 能量測，但「跑多次」貴且結果沒自動整合。本 M7 做兩件事：

1. **flaky 整合進 batch_report** — 跑 pipeline 同時額外跑 2 次算 flaky_likelihood
2. **gh pr comment** — CI 自動推 fix_proposal + 信心度報告到 PR

**flaky 整合**（`PoC/flaky_integration.py`）：

```bash
# 一鍵跑 M2→M3→M4→M7-flaky→M6→M6.1→M6.2
JEV_FLAKY_INTEGRATION=1 JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-M62
# → M4 後額外跑 2 次 journey
# → 寫回 batch_report.batch_report.flaky_measured
# → 對比 jev 算的 flaky_likelihood，delta 大時降級 overall_health
```

**batch_report schema 新欄位**：

```json
{
  "batch_report": {
    "flaky_likelihood": 0.24,           // Jev 算的
    "flaky_measured": {                  // M7 新增：動態算的
      "likelihood": 0.0,                 // 3 次跑聚合
      "classification": "stable",
      "jev_flaky_likelihood": 0.24,
      "delta": 0.24,
      "warning": false,
      "sample_count": 2
    }
  }
}
```

**降級邏輯**：`flaky_measured.classification == highly_flaky` → `overall_health` red 降為 yellow

**gh pr comment**（`PoC/gh_pr_comment.py`）：

```bash
# 推 PR comment（需 GITHUB_TOKEN）
.venv/bin/python gh_pr_comment.py \
  --batch-report /tmp/US-M62-batch.json \
  --fix-proposal /tmp/US-M62-fix-proposal-v2.md \
  --pr-number 42
# → 構造 4 段 comment + 推 PR
```

**4 段 comment 結構**：

| 段 | 內容 |
|---|---|
| 1. Journey 標題 | story_id + title + 4 維度表 |
| 2. Fix Proposal | 信心度 + gating 決定 |
| 3. 問題分析摘要 | 從 fix_proposal 抓前 300 字 |
| 4. Sandbox 建議 | 一鍵 pipeline 指令 |

**Pipeline 整合**：

```bash
JEV_GH_PR_COMMENT=1 JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  GITHUB_PR_NUMBER=42 \
  ./run_pipeline.sh US-M62
# → 自動 gh pr comment 推 PR
# → 失敗不中斷（best-effort）
```

**為什麼 M7 解鎖 review 流程**：
- reviewer 不用離開 PR 就能看 regression 結果
- flaky_likelihood 動態驗證 → 對結果信心度提高
- comment 失敗不中斷 → CI 不會因 gh token 問題 block

## M8 修正循環補充：CI matrix pipeline

**適用情境**：多個 US 同時變更時，需要一次看多個 regression 結果。

**Matrix 結構**：

```yaml
# .github/workflows/regression-guard-jev-poc.yml
jobs:
  pipeline:
    strategy:
      fail-fast: false
      matrix:
        story_id: [US-101, US-M62, US-M63]
    steps:
      - run: ./run_pipeline.sh "${{ matrix.story_id }}"

  aggregate-matrix:
    needs: pipeline
    if: always() && github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/download-artifact@v4
        with:
          pattern: regression-report-*
          merge-multiple: true
      - run: |
          # 合併 3 個 batch_report 成 matrix-summary.md
```

**3 個關鍵設計**：

| 設計 | 原因 |
|---|---|
| `fail-fast: false` | 一個 fail 不 cancel 其他；reviewer 一次看 3 個結果 |
| `workflow_dispatch` 才跑 matrix | push/PR 跑 3 個太慢；只在手動 trigger 跑 |
| `merge-multiple: true` | 下載時把多個 artifact merge 到同一目錄 |

**Aggregate output**（`matrix-summary.md`）：

```markdown
# regression-guard Matrix Summary

| Story | Health | Fix Priority | Flaky | Type |
|-------|--------|--------------|-------|------|
| `US-101` | 🟢 green | 0.50 | 0.00 | stable |
| `US-M62` | 🔴 red | 2.97 | 0.00 | real_bug |
| `US-M63` | 🟡 yellow | 1.80 | 0.20 | flaky |
```

**workflow_dispatch vs push/PR**：

| 觸發 | 行為 |
|---|---|
| `push` 到 master | 只跑 bats 探針 + 單一 story_id pipeline（matrix 預設 3 個但只跑 1）|
| `pull_request` | 同上 + post report to PR comment |
| `workflow_dispatch` | 跑完整 matrix（3 個 story_id）+ aggregate-matrix |

**為什麼 workflow_dispatch 跑 matrix**：
- 多 US 變更需要一次看多結果
- 自動 trigger 跑 matrix 太慢（3x CI minutes）
- 人工 trigger 拿可控性

## CI 整合補充

workflow 在 `.github/workflows/regression-guard-jev-poc.yml`：

| Job | 用途 | 觸發 | 需 API key |
|---|---|---|---|
| `bats` | 跑 25 個探針 | push / PR / dispatch | ❌ |
| `pipeline` | 跑 `run_pipeline.sh <STORY>` | push / PR / dispatch | ✅ (secret) |

**Return code gate**（擋 merge）：

- `0` (green) — 通過
- `2` (yellow) — warning，不擋 merge
- `1` (red) — error，**擋 merge**

詳細 branch protection + secrets 設定見 [`docs/ci/regression-guard-jev-poc.md`](../../docs/ci/regression-guard-jev-poc.md)。
