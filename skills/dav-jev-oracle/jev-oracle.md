# Jev Oracle 補充（進階）＋ 修正循環

> 本檔只留**規則同判準**；指令層（點跑、milestone 證據、輸出範例）→ 同套本 skill 子檔（`./examples.md`、`./PoC/README.md`）。
> 本 skill 係**可選章節**：預設流程（Steps 1-4 ＋ 全部規則）對多數項目已足夠；只有下列**特殊場景**先用 Jev 加一層語意判定。

## 適用場景

1. **AC 驗收容易誤判的「柔性」條件**：「紅字提示」「友好錯誤」「流暢體驗」這類主觀描述，Jev 能解讀「鬆／緊」口徑。
2. **同個 fail 背後多種原因**：「真 bug」「flaky」「AC 寫得不好」這 3 種原因，傳統 pass/fail 沒分，後續修正循環會浪費時間。
3. **Confidence-gated 自動行動**：CI 看到 `severity >= 2.5` 才開 issue；`flaky_likelihood > 0.7` 自動重跑；避免每一次 transient fail 都打閿開發者。

## 不適用的場景

- **純語法／類型／CRUD 測試**：傳統斷言快又準，Jev 反而慢 ＋ 貴。
- **高頻跑數千例的微探針**：Jev API 有 cost／latency，量起來傷荷包。
- **Determinism 要求 100% 的場景**（如金融交易）：Jev 每次 verdict 可能微跳（AC 係語意判定唔係 bool）。

## 怎麼試

Jev PoC 已喺同套本 skill 子檔（`./PoC/`）跑出 M1-M5 完整 milestone，**以 `US-101` 付款頁為範例**（逐個 PoC 檔案用途 → 同套本 skill
子檔（`./PoC/README.md`））：

- `PoC/journey_runner.py` — 用途：observe→Jev→verdict→recheck 迴路
- `PoC/batch_report.py` — 用途：4 維度 end-of-run 報告
- `PoC/run_pipeline.sh` — 用途：M2→M3→M4 一鍵串接

**3 種 observer backend**（`.venv/bin/python run_journey.py journeys/US-101.yaml`）：

- **`ac_aware`（預設）** — 用途：從 `fixtures/<story_id>.yaml` 讀；備註：—
- **`mock`** — 用途：純 mock，不接 fixture；備註：—
- **`playwright`** — 用途：真 Chrome driver；備註：要 `uv pip install playwright` ＋ `playwright install chromium`

## 實作成本預估

- **PoC 評估** — 預估：1 批次（1 個 Module）；重點：以一個 PENDING US 跑 M1-M5 驗證 4 維度判定是否準確
- **整合進主流程** — 預估：1 批次；重點：把 Jev 該在的 Gate 調進 Steps 1-4；不是取代是補充
- **換 driver** — 預估：1 批次；重點：從 fixture 轉 Playwright Chrome／Chrome DevTools Protocol
- **CI 接 batch report** — 預估：半天；重點：batch report JSON 進 issue tracker／Slack

## 探針選名參考

- **規則**：如果決定採用，探針名稱可加 `JEV-` prefix
區分（例：`JEV-US-101-AC01-red-error-message`／`JEV-US-101-AC02-friend-checkout-flow`／`JEV-US-101-AC04-confirmed-200-not-500`）
  。
- **並行規則**：跟傳統 `US-101-AC01` 並行、不重疊，CI 可選只跑哪一類；跨語言命名格式 → 同套本 skill 子檔（`./examples.md`）。

## 修正循環補充（M6 自動 fix proposal）

適用情境：M3 runner 跑出 `real_bug` verdict 後，手動看 batch report 太慢，**先讓 Jev 給出信心度報告**幫 reviewer 加速。
作法（PoC 階段，3 題 noul batch call）：`JEV_FIX_PROPOSAL=1 .venv/bin/python fix_proposal.py /tmp/<STORY>-run.json` → 產
`/tmp/<STORY>-fix-proposal.md`。
`fix_proposal.py` 會產出：

- **整體信心度** — 內容：3 題平均 noul 概率 (0–1) ＋ 評級（高／中／低／不可判定）
- **信心度評估表** — 內容：問題摘要／建議修正／驗證步驟 三維度各自的信心度
- **原始失敗走跡** — 內容：失敗步的 URL／status／body 截錄 200 字
- **上下文** — 內容：Journey ID／verdict counts／blocked 狀態

**重要限制**（v1 範圍）：

- Jev v1.13 **不支援 free_response 題型**，只有 `choice`／`score`／`noul` 三種 → M6 階段的 fix proposal 是「信心度報告 ＋ 失敗走跡」，不是自動寫出 fix 文字
- Reviewer 接手起點：**看信心度表格 → 找最低那一維 → 對應走跡去定位 component**
- 0.5 為 gating 門檻：≥0.5 自動接手；<0.5 先加 observer context 再跑

**升級路徑**（M6.1+，需另起批次）：接 Claude／GPT 生成實際 fix 文字（Jev 信心度作為 gating）、接 patch ＋ re-validate 自動迴圈。
**輸出範例**（fix proposal 嘅完整樣子）→ 同套本 skill 子檔（`./examples.md`）「Jev Oracle 範例」章節。

## M6.1 修正循環補充：LLM Relay（v2 接力）

**適用情境**：v1 M6 fix proposal 跑出整體信心度 **≥ 0.5** 時，由「當下對話的 LLM agent」接力寫 fix 文字。
**為什麼是 skill 本身 LLM（不接外部 Claude/GPT）**：召喚同套 `dav-developer` skill 嗰個 LLM（subagent／pi 本身）就係「接力的 LLM」→ 冇外部依賴、冇額外 API
cost、prompt template 係檔案（可迭代、唔使改 code）。
**流程（3 步）**：① pipeline 產 v1 ＋ v2 ＋ prompt bundle → ② 在對話中讀 `prompt.md`、按 template 寫 `answer.md` → ③
`fix_proposal_v2.py` 拼 final report（指令見 `./examples.md`）。
**信心度 gating 規則**（`fix_proposal_v2.py` 的 `RELAY_GATING_THRESHOLD`）：

- **≥ 0.5** — 動作：✅ 召喚 LLM relay，產 prompt bundle；final report 內容：信心度報告 ＋ LLM 接力文字 ＋ 走跡對照
- **0.25–0.49** — 動作：❌ 跳過 LLM relay；final report 內容：信心度報告 ＋ 走跡，標「reviewer 接手」
- **< 0.25** — 動作：❌ 跳過，明確標「需先加 observer context」；final report 內容：同上 ＋ 警告

**Prompt template 位置**：`PoC/prompts/fix_relay.md`（涵蓋角色／輸入／產出 3 段／約束／範例／gating 規則）。
**已知限制**（v2 範圍）：

- 接力 LLM 必須是「當下對話的 agent」— CI 環境需特別設定（手動觸發 subagent 或加 `gh pr comment` step）
- Prompt template 是 markdown 而非 jinja — 簡單可讀但不支援條件邏輯
- Final report 中 LLM 接力段落沒有「versioning」— 改了 prompt template 跑出來的文字可能差很多，**需在 deliverable 中註明用的是哪一版 prompt**

## 修正循環閉環（M6.2 patch ＋ M6.3 sandbox）

- **M6.2 適用情境**：M6.1 LLM Relay 產出的 fix 文字需要真的 apply 到 source file，並驗證是否真的修好。
- **M6.2 怎麼用**（sandbox 環境，手動步驟）：① `JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh <STORY>` 產 fix_proposal_v2.md ＋
patches.json → ② `playwright_patcher.py` dry-run（看 diff 不改檔）→ ③ `--apply` → ④ 重跑 journey 產 after.json → ⑤
  `re_validate.py` 比對 before/after → regression 時 `playwright_patcher.py --rollback`。
- **M6.3 適用情境**：M6.2 還需手動 3 步（apply → 重跑 → re-validate）；M6.3 把這 3 步封裝成一個 sandbox 流程。
- **M6.3 一鍵跑法**：`JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1` → 再跑
`./run_pipeline.sh <STORY>` → 建 `tmp/.sandbox-<STORY>-<ts>/` 隔離工作目錄 → apply patch（只喺 sandbox 內，唔掂主 repo）→ 重跑 journey →
  自動 re-validate → 若 regression 自動 rollback → 產 `sandbox_report.md` → cleanup。
- **Pipeline 整合**：`JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑 M2→M3→M4→M6→M6.1→M6.2；M6.2 步驟只「產 patch
素材」（`-patches.json`），apply／re-validate 仍需手動在 sandbox 跑。
- **為什麼 apply ＋ re-validate 不全自動**：sandbox 限制（CI 環境不能無人工 commit）｜LLM 給的 patch 可能是錯的，需人工 review｜scope 控制（M6.2／M6.3 不做自動
commit）。
- **為什麼叫「互動式」**：apply in sandbox ＋ re-validate ＋ rollback 都**自動**；「要不要把 sandbox 的 patch 拿回主 repo ＋ commit」仍**人工**。
- **Return code**：error=1，regression=2，improvement／no_change=0。
- **模組 API ＋ safety 規則** → 同套本 skill 子檔（`./api-contract.md`）

## Flaky 驗證：跑 N 次同一 journey 識别穩定性

- **適用情境**：懷疑某個 journey 結果不穩定（同一 source 多次跑 verdict 分布不一樣）。
- **怎麼用**：`flaky_check.py <journey> --source <ac.md> --story-id <ID> --runs 5 --output <report>` → 跑 N 次 → 聚合 verdict
分布 → 計算 flaky_likelihood → 產 `flaky_report.md`。
- **flaky_likelihood 公式**：`d = Σ(verdict_max - verdict_min) / (Σ verdict_max + 1)`；`0.0` = 每次都一模一樣（完全穩定）；接近 `1.0` = 每次
verdict 都大幅波動（完全 flaky）。
- **實測（US-M62 跑 5 次）**：fail=12／blocked=1／pass=0 每次都一致 → flaky_likelihood = 0.0 → 🟢 **stable**。
- **為什麼 flaky_likelihood 重要**：CI 訊號穩定（穩定嘅 journey 結果可以信）｜regression 報告加值（標記「這次跑是否 flaky」）｜debug 線索（flaky 高嘅 journey 多半係
Jev cache 命中、observer 不穩、AC 定義模糊）。
- **flaky_check 模組 API** → 同套本 skill 子檔（`./api-contract.md`）

## M7 修正循環補充：flaky 整合 ＋ gh pr comment

- **適用情境**：TMO-020 嘅 flaky_check.py 能量測，但「跑多次」貴且結果沒自動整合 → M7 做兩件事。
- **兩件事**：① **flaky 整合進 batch_report**（`JEV_FLAKY_INTEGRATION=1` → 跑 pipeline 同時額外跑 2 次算 flaky_likelihood）② **gh pr
comment**（`JEV_GH_PR_COMMENT=1` ＋ `GITHUB_PR_NUMBER` → CI 自動推 fix_proposal ＋ 信心度報告到 PR）。
- **PR comment 4 段結構 ＋ batch_report 新欄位 ＋ 降級邏輯** → 同套本 skill 子檔（`./output-format.md`）
- **為什麼 M7 解鎖 review 流程**：reviewer 不用離開 PR 就能看 regression 結果｜flaky_likelihood 動態驗證 → 對結果信心度提高｜comment 失敗不中斷 → CI 不會因 gh
token 問題 block。

## M8 修正循環補充：CI matrix pipeline

- **適用情境**：多個 US 同時變更時，需要一次看多個 regression 結果。
- **做法**：本機 runner `run_ci.sh matrix` 預設跑 3 個 story（`US-101`／`US-M62`／`US-M63`），各自產報告，再合併成 `matrix-summary.md`（每 story
欄位 → 同套本 skill 子檔（`./output-format.md`））。
- **3 個關鍵設計**：`fail-fast: false`（一個 fail 不停其他）｜最差 verdict 先決定整體 rc｜可傳自訂 story 列表。
- **歷史說明**：2026-10-27 前呢段講嘅係 GitHub Actions 嘅 `matrix` ＋ `aggregate-matrix` job；該 workflow 已刪 → 改由本機 runner 承擔（契約 → 同套本
skill 子檔（`./api-contract.md`））。
