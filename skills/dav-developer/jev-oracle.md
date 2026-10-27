# Jev Oracle 補充（進階）+ CI 整合

> 本檔為 dav-developer 的「Jev Oracle 補充」+「CI 整合補充」章節（v2.2-v2.8 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：拆檔當時 Jev Oracle 506 行 + CI 整合 30 行 = 536 行屬於「進階 / 可選」，不在「skill 基本用法」主流程上。
>
> ⚠️ **本檔是**可選章節：預設 dav-developer 流程（Steps 1-4 + 上述全部規則）對多数項目已足夠。只有在下列**特殊場景**下，才需要用 Jev oracle 加一層語意判定。
>
> **指令層**（點跑、milestone 證據、輸出範例）→ 同套本 skill 子檔（`./examples.md`、`./PoC/README.md`）；本檔只留**規則同判準**。

---

## 適用場景

1. **AC 驗收容易誤判的「柔性」条件**：「紅字提示」「友好錯誤」「流暢體驗」這類主觀描述，Jev 能解讀「鬆 / 緊」口徑。
2. **同個 fail 背後多種原因**：「真 bug」「flaky」「AC 寫得不好」這 3 種原因，傳統 pass/fail 沒分，後續修正循環會浪費時間。
3. **Confidence-gated 自動行動**：CI 看到 `severity >= 2.5` 才開 issue；`flaky_likelihood > 0.7` 自動重跑；避免每一次 transient fail 都打閿開發者。

## 不適用的場景

- **純語法 / 類型 / CRUD 測試**：傳統斷言快又準，Jev 反而慢 + 貴。
- **高頻跑數千例的微探針**：Jev API 有 cost / latency，量起來傷荷包。
- **Determinism 要求 100% 的場景**（如金融交易）：Jev 每次 verdict 可能微跳（ac 是語意判定不是 bool）。

## 怎麼試

Jev PoC 已在 `skills/dav-developer/PoC/` 跑出 M1-M5 完整 milestone，**以 `US-101` 付款頁為範例**：

- **`PoC/README.md`**
  - 用途：Milestone 紀錄 + 快用範例（點跑）
- **`PoC/journey_runner.py`**
  - 用途：observe→Jev→verdict→recheck 迴路
- **`PoC/batch_report.py`**
  - 用途：4 維度 end-of-run 報告
- **`PoC/run_pipeline.sh`**
  - 用途：M2→M3→M4 一鍵串接

**3 種 observer backend**（`.venv/bin/python run_journey.py journeys/US-101.yaml`）：

- **`ac_aware`（預設）**
  - 用途：從 `fixtures/<story_id>.yaml` 讀
  - 備註：—
- **`mock`**
  - 用途：純 mock，不接 fixture
  - 備註：—
- **`playwright`**
  - 用途：真 Chrome driver
  - 備註：要 `uv pip install playwright` ＋ `playwright install chromium`

## 實作成本預估

- **PoC 評估**
  - 預估：1 sprint
  - 重點：以一個 PENDING US 跑 M1-M5 驗證 4 維度判定是否準確
- **整合進主流程**
  - 預估：1 sprint
  - 重點：把 Jev 該在的 Gate 調進 Steps 1-4；不是取代是補充
- **換 driver**
  - 預估：1 sprint
  - 重點：從 fixture 轉 Playwright Chrome / Chrome DevTools Protocol
- **CI 接 batch report**
  - 預估：半天
  - 重點：batch report JSON 進 issue tracker / Slack

## 探針選名參考

如果決定採用，探針名稱可加 `JEV-` prefix 區分：

```JEV
-US-101-AC01-red-error-message

JEV-US-101-AC02-friend-checkout-flow
JEV-US-101-AC04-confirmed-200-not-500
```

跟傳統 `US-101-AC01` 並行、不重疊，CI 可選只跑哪一類。

---

## 修正循環補充（M6 自動 fix proposal）

適用情境：M3 runner 跑出 `real_bug` verdict 後，手動看 batch report 太慢，**先讓 Jev 給出信心度報告**幫 reviewer 加速。

作法（PoC 階段，3 題 noul batch call）：

```bash
JEV_FIX_PROPOSAL
=1 .venv/bin/python fix_proposal.py /tmp/<STORY>-run.json

# → /tmp/<STORY>-fix-proposal.md
```

`fix_proposal.py` 會產出：

- **整體信心度**
  - 內容：3 題平均 noul 概率 (0–1) + 評級 (高/中/低/不可判定)
- **信心度評估表**
  - 內容：問題摘要 / 建議修正 / 驗證步驟 三維度各自的信心度
- **原始失敗走跡**
  - 內容：失敗步的 URL / status / body 截錄 200 字
- **上下文**
  - 內容：Journey ID / verdict counts / blocked 狀態

**重要限制**（v1 範圍）：

- Jev v1.13 **不支援 free_response** 題型，只有 `choice` / `score` / `noul` 三種
- 所以 M6 階段的 fix proposal 是 **「信心度報告 + 失敗走跡」**，不是自動寫出 fix 文字
- Reviewer 接手起點：**看信心度表格 → 找最低那一維 → 對應走跡去定位 component**
- 0.5 為 gating 門檻：≥0.5 自動接手；<0.5 先加 observer context 再跑

**升級路徑**（M6.1+，需另起 sprint）：接 Claude / GPT 生成實際 fix 文字（Jev 信心度作為 gating）、接 patch + re-validate 自動迴圈。
**輸出範例**（fix proposal 嘅完整樣子）→ 同套本 skill 子檔（`./examples.md`）「Jev Oracle 範例」章節。

## M6.1 修正循環補充：LLM Relay（v2 接力）

**適用情境**：v1 M6 fix proposal 跑出整體信心度 **≥ 0.5** 時，由「當下對話的 LLM agent」接力寫 fix 文字。

**為什麼是 skill 本身 LLM（不接外部 Claude/GPT）**：召喚 dav-developer 嗰個 LLM（subagent／pi 本身）
就係「接力的 LLM」→ 冇外部依賴、冇額外 API cost、prompt template 係檔案（可迭代、唔使改 code）。

**流程（3 步）**：① pipeline 產 v1 + v2 + prompt bundle → ② 在對話中讀 `prompt.md`、
按 template 寫 `answer.md` → ③ `fix_proposal_v2.py` 拼 final report（指令見 `./examples.md`）。

**信心度 gating 規則**（`fix_proposal_v2.py` 的 `RELAY_GATING_THRESHOLD`）：

- **≥ 0.5**
  - 動作：✅ 召喚 LLM relay，產 prompt bundle
  - final report 內容：信心度報告 + LLM 接力文字 + 走跡對照
- **0.25–0.49**
  - 動作：❌ 跳過 LLM relay
  - final report 內容：信心度報告 + 走跡，標「reviewer 接手」
- **< 0.25**
  - 動作：❌ 跳過，明確標「需先加 observer context」
  - final report 內容：同上 + 警告

**Prompt template 位置**：`PoC/prompts/fix_relay.md`（涵蓋角色／輸入／產出 3 段／約束／範例／gating 規則）。

**已知限制**（v2 範圍）：

- 接力 LLM 必須是「當下對話的 agent」 — CI 環境需特別設定（手動觸發 subagent 或加 `gh pr comment` step）
- Prompt template 是 markdown 而非 jinja — 簡單可讀但不支援條件邏輯
- Final report 中 LLM 接力段落沒有「versioning」— 改了 prompt template 跑出來的文字可能差很多，**需在 deliverable 中註明用的是哪一版 prompt**

## M6.2 修正循環補充：patch + re-validate 閉環

**適用情境**：M6.1 LLM Relay 產出的 fix 文字需要真的 apply 到 source file，並驗證是否真的修好。
**怎麼用**（sandbox 環境，手動步驟）：① `JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh <STORY>` 產 fix_proposal_v2.md + patches.json →
② `playwright_patcher.py` dry-run（看 diff 不改檔）→ ③ `--apply` → ④ 重跑 journey 產 after.json
→ ⑤ `re_validate.py` 比對 before/after → regression 時 `playwright_patcher.py --rollback`。

**三個模組**（在 `PoC/`）：`patch_parser.py`（抽 `(file, old, new)` → `parse_fix_proposal(md_text)`）｜
`playwright_patcher.py`（apply patch：dry-run／apply／rollback → `apply_patch(file, old, new, dry_run=True)`）｜
`re_validate.py`（比較 before/after verdict 分布 → `re_validate(before.json, after.json)`）。

**safety 規則**（`playwright_patcher.py`）：

- **`old_text` 不存在**
  - 動作：❌ abort
- **`old_text` 出現 > 1 次**
  - 動作：❌ abort（拒絕靜默套用）
- **`old_text` 出現 1 次 + dry-run**
  - 動作：👀 產 diff 報告 + 建 .bak，不改檔案
- **`old_text` 出現 1 次 + --apply**
  - 動作：✅ apply + .bak 已建
- **`--rollback`**
  - 動作：⏪ 從 .bak 還原

**自動分類**（`re_validate.py`）：fail delta < 0 → 🟢 improvement（keep patch）｜> 0 → 🔴 regression（rollback）｜= 0 → 🟡
no_change（review）。

**Pipeline 整合**：`JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑 M2→M3→M4→M6→M6.1→M6.2。
→ M6.2 步驟只「產 patch 素材」（`-patches.json`），apply / re-validate 仍需手動在 sandbox 跑。

**為什麼 apply + re-validate 不全自動**：sandbox 限制（CI 環境不能無人工 commit）｜LLM 給的 patch 可能是錯的，需人工 review｜scope 控制（M6.2 不做自動 commit）。

## M6.3 修正循環補充：互動式 sandbox（M6.2 自動版）

**適用情境**：M6.2 還需手動 3 步（apply → 重跑 → re-validate）；M6.3 把這 3 步封裝成一個 sandbox 流程。
**一鍵跑法**：`JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1`
→ 再跑 `./run_pipeline.sh <STORY>` → 建 `tmp/.sandbox-<STORY>-<ts>/` 隔離工作目錄
→ apply patch（只喺 sandbox 內，唔掂主 repo）
→ 重跑 journey → 自動 re-validate → 若 regression 自動 rollback → 產 `sandbox_report.md` → cleanup。

**sandbox_runner.py 模組**（在 `PoC/`）：

- **1. 建立 sandbox**
  - 動作：mkdir + copy fixture + 備份到 `.pre-patch/`
  - 輸出：sandbox 目錄已建
- **2. apply patch**
  - 動作：playwright_patcher.py in sandbox
  - 輸出：file 已改（sandbox 內）
- **3. 重跑 journey**
  - 動作：run_journey.py 產 after.json
  - 輸出：verdict_after
- **4. re-validate**
  - 動作：re_validate.py 比對
  - 輸出：classification: improvement / regression / no_change
- **5. auto rollback**
  - 動作：若 regression：從 .pre-patch/ 還原
  - 輸出：file 回到 baseline
- **6. cleanup**
  - 動作：shutil.rmtree(sandbox)
  - 輸出：隔離目錄已刪

**為什麼叫「互動式」**：apply in sandbox + re-validate + rollback 都**自動**；「要不要把 sandbox 的 patch 拿回主 repo + commit」仍**人工**。

**safety 規則**（繼承 M6.2）：ambiguous old → 整個 sandbox abort，cleanup 仍跑｜not-found old → 同上｜sandbox 目錄不論結果都刪，
不留垃圾｜主 repo 永遠不被改。

**return code**：error=1, regression=2, improvement/no_change=0

## Flaky 驗證：跑 N 次同一 journey 識别穩定性

**適用情境**：懷疑某個 journey 結果不穩定（同一 source 多次跑 verdict 分布不一樣）。
**怎麼用**：`flaky_check.py <journey> --source <ac.md> --story-id <ID> --runs 5 --output <report>` → 跑 N 次 → 聚合 verdict 分布 →
計算 flaky_likelihood → 產 `flaky_report.md`。

**flaky_likelihood 公式**：

```flaky_likelihoo
d = Σ(verdict_max - verdict_min) / (Σ verdict_max + 1)
```

- `0.0`：每次都一模一樣（完全穩定）
- `接近 1.0`：每次 verdict 都大幅波動（完全 flaky）

**實測（US-M62 跑 5 次）**：fail=12 / blocked=1 / pass=0 每次都一致 → flaky_likelihood = 0.0 → 🟢 **stable**。

**flaky_check.py 模組**（在 `PoC/`）：`RunRecord`（一次跑嘅 verdict 計數 + blocked + wall time）｜
`analyze_runs(runs)`（聚合 + 計 flaky_likelihood + 分類）｜`render_flaky_report(report)`（渲染 flaky_report.md）。

**為什麼 flaky_likelihood 重要**：CI 訊號穩定（穩定嘅 journey 結果可以信）｜regression 報告加值（標記「這次跑是否 flaky」）
｜debug 線索（flaky 高嘅 journey 多半係 Jev cache 命中、observer 不穩、AC 定義模糊）。

## CI 定期檢查：docs/cleanup-scan 排程

**適用情境**：repo 文件會隨時間累積（PRD、reflection、audit trail）；定期自動掃描找出「建議刪除」的文件。
**排程**：2026-10-27 起本 repo 唔喺 GitHub Actions 跑 → **自己排程或人手跑**
`bash skills/dav-developer/PoC/run_ci.sh cleanup-scan`（內部行 `cleanup-scan.py --json`）。

**cleanup-scan.py 4 類**：

- **KEEP**
  - 標準：≥2 cross-link 或 protected pattern
  - 動作：保留
- **REVIEW**
  - 標準：1 cross-link
  - 動作：人工 review（考慮是否 merge / 補連結 / 刪）
- **DELETE**
  - 標準：0 cross-link
  - 動作：⚠️ 警告：考慮刪除（仍需人工 `--apply`）
- **MERGE**
  - 標準：TODO
  - 動作：預留 hook（v2.0 規則禁止改存量，未實作）

**為什麼不自動刪 DELETE**：可能是 audit trail｜可能是重要文件但缺交叉引用｜可能是 contributor 故意留下的 work-in-progress。
**為什麼是 weekly 不是 daily**：文件分類變化不快；daily 太頻繁，CI minutes 浪費。

**本機觸發**：`bash skills/dav-developer/PoC/run_ci.sh cleanup-scan`（2026-10-27 起本 repo 唔再喺 GitHub Actions 跑 → 冇 cron
自動跑，要自己排程或人手跑）。

## M7 修正循環補充：flaky 整合 + gh pr comment

**適用情境**：TMO-020 的 flaky_check.py 能量測，但「跑多次」貴且結果沒自動整合。本 M7 做兩件事：
① **flaky 整合進 batch_report**（`JEV_FLAKY_INTEGRATION=1` → 跑 pipeline 同時額外跑 2 次算 flaky_likelihood）
② **gh pr comment**（`JEV_GH_PR_COMMENT=1` + `GITHUB_PR_NUMBER` → CI 自動推 fix_proposal + 信心度報告到 PR）

**gh pr comment 4 段結構**：

- **1. Journey 標題**
  - 內容：story_id + title + 4 維度表
- **2. Fix Proposal**
  - 內容：信心度 + gating 決定
- **3. 問題分析摘要**
  - 內容：從 fix_proposal 抓前 300 字
- **4. Sandbox 建議**
  - 內容：一鍵 pipeline 指令

**batch_report schema 新欄位**：

```json
{

  "batch_report": {
    "flaky_likelihood": 0.24,
    "flaky_measured": {
      "likelihood": 0.0,
      "classification": "stable",
      "jev_flaky_likelihood": 0.24,
      "delta": 0.24,
      "warning": false,
      "sample_count": 2
    }
  }
}
```

**降級邏輯**：`flaky_measured.classification == highly_flaky` → `overall_health` red 降為 yellow。
**為什麼 M7 解鎖 review 流程**：reviewer 不用離開 PR 就能看 regression 結果｜flaky_likelihood 動態驗證 → 對結果信心度提高｜
comment 失敗不中斷 → CI 不會因 gh token 問題 block。

## M8 修正循環補充：CI matrix pipeline

**適用情境**：多個 US 同時變更時，需要一次看多個 regression 結果。
**做法**：本機 runner `run_ci.sh matrix` 預設跑 3 個 story（`US-101`／`US-M62`／`US-M63`），
各自產報告，再合併成 `matrix-summary.md`（表格式同下）：

- **`US-101`**
  - Health：🟢 green
  - Fix Priority：0.50
  - Flaky：0.00
  - Type：stable
- **`US-M62`**
  - Health：🔴 red
  - Fix Priority：2.97
  - Flaky：0.00
  - Type：real_bug
- **`US-M63`**
  - Health：🟡 yellow
  - Fix Priority：1.80
  - Flaky：0.20
  - Type：flaky

**3 個關鍵設計**：`fail-fast: false`（一個 fail 不停其他）｜最差 verdict 先決定整體 rc｜可傳自訂 story 列表。
（2026-10-27 前呢段講嘅係 GitHub Actions 嘅 `matrix` + `aggregate-matrix` job；該 workflow 已刪 → 見下一節。）

## CI 整合補充（本機跑）

2026-10-27 用戶決策：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」
→ `.github/workflows/dav-developer-jev-poc.yml` **已刪除**；原本 4 個 job 改由本機 runner
`skills/dav-developer/PoC/run_ci.sh` 承擔：

- **`bats`**
  - 而家：`probes`
  - 用途：跑 `tests/v2.1-jev-poc.bats`
  - 需 API key：❌
- **`pipeline`**
  - 而家：`pipeline`
  - 用途：跑 `run_pipeline.sh <STORY>`
  - 需 API key：✅（本機 `OPENROUTER_API_KEY`）
- **`aggregate-matrix`**
  - 而家：`matrix`
  - 用途：跑多個 story ＋ 匯總 `matrix-summary.md`
  - 需 API key：✅
- **`cleanup-scan`**
  - 而家：`cleanup-scan`
  - 用途：跑 `docs/cleanup/cleanup-scan.py`
  - 需 API key：❌

**Return code gate**（同原本 workflow 一致）：

- `0` (green) — 通過
- `2` (yellow) — warning，唔擋
- `1` (red) — error，**擋**
- `3` — 用法／環境錯誤（缺 key／缺 venv）

⚠️ verdict 由 batch report JSON 嘅 `overall_health` 讀（`run_pipeline.sh` 嘅離開碼永遠係 0 → 捉唔到紅燈）。

目標專案想自己喺 GitHub Actions 跑（secrets／branch protection）見
[`docs/ci/dav-developer-jev-poc.md`](../../docs/ci/dav-developer-jev-poc.md)。
