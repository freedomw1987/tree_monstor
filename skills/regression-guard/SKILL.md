---
name: regression-guard
description: 在開發過程中埋入探針，透過 REGRESSION_MODE 環境變量自動運行驗證，失敗時提供建議讓 Agent 自動修正。涵蓋 TTY/watch mode fail-fast 防線機制。
---

# Regression Guard

## TL;DR

1. **做什麼**：在開發時埋入探針（probe / assert / describe），透過 `REGRESSION_MODE=true` 自動運行；失敗時提供 `suggestion` 讓 Agent 自動修正。
2. **何時觸發**：每個 sprint 的 Gate 3 regression gate；任何會「跑 test runner」的場景。
3. **預設 SOP 路徑**：§2.3 Gate 3 regression gate（在 Gate 1 TDD 後、Gate 4 Reviewer 前）。
4. **關鍵紀律**：
   - **TTY fail-fast**：測試指令禁用 interactive / watch 模式；shell 卡住 > 30 秒 = Gate 3 失敗
   - **探針命名具體**：避免 `test1`，必含描述（如 `user-login-returns-correct-data`）
   - **粒度適中**：每個邏輯斷言一個探針（不過粗、不過細）
   - **純文字引用**：skill 內不放跨檔 markdown 連結
5. **必產出物**：探針程式碼（probe/assert/describe）+ 報告（文本 + JSON）+ 失敗時 `suggestion`

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 開發過程埋探針 | ✅ 必須 |
| Gate 3 regression baseline / 修改後驗證 | ✅ 必須 |
| 跑 test runner（vitest / jest / pytest / bats / playwright / cargo / go）| ✅ 必套 TTY fail-fast |
| 純提問 / 不跑測試 | ❌ 不觸發 |
| 用戶主動 watch 模式（如開發者本地手動 watch）| ⚠️ 允許但不視為 Gate 3 |

## 流程（5 步）

### Step 1：開發時埋入探針

- **動作**：在關鍵代碼位置用 `probe(name, actual, expected)` / `assert(condition, message)` / `describe(name, fn)` 埋入測試點
- **為什麼**：探針讓後續測試 / 排錯 checker agent 能根據報錯和測試記錄驗證
- **產出**：源代碼內含探針
- **證據**：探針命名具體（避免 `test1`）

### Step 2：環境變量配置

- **動作**：設定 `REGRESSION_MODE=true` / `REGRESSION_OUTPUT=both` / `REGRESSION_STRICT=true` / `REGRESSION_REPORT_PATH=./report.json`
- **為什麼**：環境變量控制探針開關 + 輸出格式 + 失敗處理
- **產出**：shell 環境變量或 .env 檔
- **證據**：`echo $REGRESSION_MODE` 顯示正確值

### Step 3：自動運行（禁用 watch / interactive）⭐

- **動作**：執行測試指令，但**禁用 watch / interactive 模式**（見下方規則表）
- **為什麼**：agent shell 在 TTY 偵測上是模糊的；watch mode 會卡住等 stdin，整個 session 凍結
- **產出**：測試輸出（文本 + JSON 報告）
- **證據**：測試一次性跑完退出，不卡住

### Step 4：失敗時 Agent 自動修正

- **動作**：讀取 `suggestion` 欄位 → 分析 → 修代碼 → 重跑
- **為什麼**：自動化修正循環、避免人為介入延遲
- **產出**：修正後代碼 + 重跑結果
- **證據**：第二輪跑全部通過

### Step 5：通過驗證

- **動作**：確認所有探針通過、報告寫入 `REGRESSION_REPORT_PATH`
- **為什麼**：留下 audit trail、供 Gate 4 Reviewer 讀
- **產出**：report.json / report.txt
- **證據**：report 檔存在 + summary 顯示 0 failed

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| TTY fail-fast（禁用 watch）| 用戶手動 watch | Gate 3 不接受 watch 結果 |
| 探針命名具體（必含描述）| N/A | 不可 `test1` / `probe1` |
| 粒度適中（每個邏輯斷言 1 個探針）| N/A | 不過粗（功能級）/ 不過細（每行級）|
| 預期值存 `fixtures/` 目錄 | 簡單值可 inline | 複雜 JSON / YAML 必抽檔 |
| 失敗時提供 `suggestion` | N/A | Agent 必須能照做 |
| 純文字引用（v2.1）| skill 子檔可用 markdown | 不寫 `../` 或 `docs/` 跨檔連結 |
| 探針必在 `REGRESSION_MODE=true` 才跑 | 開發 hot reload 例外 | 預設開啟 |

## 主流 runner TTY fail-fast 對照表

| Runner | ❌ 禁用（會卡） | ✅ 使用（一次性跑完） |
|---|---|---|
| **vitest** | `vitest` / `npx vitest` | `vitest run` / `npx vitest --run` |
| **jest** | `jest` / `npm test`（若 script 帶 watch）| `jest --ci` / `CI=1 npm test -- --watchAll=false` |
| **npm test** | 視 package.json 設定 | 加 `CI=1` 前綴 + 顯式 `--watchAll=false` 或 `--run` |
| **bats** | — | `bats tests/`（預設 OK）|
| **pytest** | `pytest --watch` | `pytest` / `pytest -x` |
| **playwright** | `playwright test --ui` | `playwright test`（預設 headless）|
| **cargo test** | — | `cargo test` |
| **go test** | — | `go test ./...` |

### 通用保險：TTY 強制關閉

若不確定 runner 行為，**一律在指令後加 `< /dev/null`**：

```bash
npm test < /dev/null
npx vitest < /dev/null
```

或設定 `CI=1`（多數 runner 自動關 watch）：

```bash
CI=1 npm test
```

### Fail-fast 自檢

執行後若出現以下任一情況 = **Gate 3 失敗**：
- shell 卡住 > 30 秒無輸出
- 輸出末端出現 `Watch Usage` / `press h to show help` / `Waiting for file changes`
- 進程未退出、`Ctrl+C` 才能結束

正確做法：kill 進程 → 補上前綴規則 → 重跑。

## API 合約

### `probe(name, actual, expected)`

- **name**（string）：探針名稱（描述性）
- **actual**（any）：實際值
- **expected**（any）：預期值
- **return**：通過時 ✅，失敗時 ❌ + suggestion

### `assert(condition, message)`

- **condition**（bool）：布林條件
- **message**（string）：描述文字
- **return**：通過時 ✅，失敗時 ❌

### `describe(name, fn)`

- **name**（string）：套件名稱
- **fn**（function）：包含探針的函數 / 區塊
- **return**：分組結果

## 輸出格式

### 文本輸出

```
✅ probe: user-login (12ms)
❌ probe: data-fetch (234ms)
   actual: null
   expected: { items: [...] }
   💡 Suggestion: Check database connection
```

### JSON 報告

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "summary": { "total": 10, "passed": 8, "failed": 2 },
  "failures": [
    {
      "name": "data-fetch",
      "error": "Mismatch: actual is null",
      "suggestion": "Check database connection"
    }
  ]
}
```

## 環境變量

| 變量 | 預設值 | 說明 |
|------|--------|------|
| `REGRESSION_MODE` | `false` | 開關探針 |
| `REGRESSION_OUTPUT` | `both` | 輸出格式：`json` / `text` / `both` |
| `REGRESSION_STRICT` | `true` | 遇錯即停 |
| `REGRESSION_REPORT_PATH` | `./report.json` | 報告路徑 |

## 探針命名最佳實踐

| ✅ 好的命名 | ❌ 不好的命名 |
|------------|--------------|
| `user-login-returns-correct-data` | `test1` |
| `api-v1-users-[id]-returns-404` | `probe1` |
| `payment-validation-rejects-empty-cart` | `test_payment` |

## 粒度控制

| 粒度 | 說明 | 範例 |
|------|------|------|
| ❌ 太粗 | 一個功能一個探針 | `user-management-works` |
| ❌ 太細 | 每一行都探針 | `line-42-returns-true` |
| ✅ 適中 | 每個邏輯斷言一個探針 | `user-login-returns-correct-data` |

## Jev Oracle 補充（進階）

> 這章是**可選章節**。預設 regression-guard 流程（Steps 1-4 + 上述全部規則）對多数項目已足夠。
> 只有在下列**特殊場景**下，才需要用 Jev oracle 加一層語意判定。

### 適用場景

1. **AC 驗收容易誤判的「柔性」条件**：「紅字提示」」「友好錯誤」」「流暢體驗」這類主觀描述，Jev 能解讀「鬆 / 緊」口徑。
2. **同個 fail 背後多種原因**：「真 bug」「flaky」「AC 寫得不好」這 3 種原因，傳統 pass/fail 沒分，後續修正循環會浪費時間。
3. **Confidence-gated 自動行動**：CI 看到 `severity >= 2.5` 才開 issue；`flaky_likelihood > 0.7` 自動重跑；避免每一次 transient fail 都打閿開發者。

### 不適用的場景

- **純語法 / 類型 / CRUD 測試**：傳統斷言快又準，Jev 反而慢 + 貴。
- **高頻跑數千例的微探針**：Jev API 有 cost / latency，量起來傷荷包。
- **Determinism 要求 100% 的場景**（如金融交易）：Jev 每次 verdict 可能微跳（ac 是語意判定不是 bool）。

### 怎麼試

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

### 實作成本預估

| 階段 | 預估 | 重點 |
|---|---|---|
| PoC 評估 | 1 sprint | 以一個 PENDING US 跑 M1-M5 驗證 4 維度判定是否準確 |
| 整合進主流程 | 1 sprint | 把 Jev 該在的 Gate 調進 Steps 1-4；不是取代是補充 |
| 換 driver | 1 sprint | 從 fixture 轉 Playwright Chrome / Chrome DevTools Protocol |
| CI 接 batch report | 半天 | batch report JSON 進 issue tracker / Slack |

### 探針選名參考

如果決定採用，探針名稱可加 `JEV-` prefix 區分：

```
JEV-US-101-AC01-red-error-message
JEV-US-101-AC02-friend-checkout-flow
JEV-US-101-AC04-confirmed-200-not-500
```

跟傳統 `US-101-AC01` 並行、不重疊，CI 可選只跑哪一類。

### 修正循環補充（M6 自動 fix proposal）

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

### M6.1 修正循環補充：LLM Relay（v2 接力）

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

### CI 整合補充

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

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.3 | 2026-09-28 | 新增「修正循環補充（M6 自動 fix proposal）」+「CI 整合補充」小節；changelog 升 v2.3 | TMO-015 / TMO-016：CI + M6 收尾 |
| v2.4 | 2026-09-28 | 新增「M6.1 修正循環補充：LLM Relay（v2 接力）」小節 + prompt template 位置 + 信心度 gating 表 | TMO-017：M6.1 LLM relay 啟用 |
| v2.2 | 2026-09-28 | 新增「Jev Oracle 補充（進階）」章節 + M3.1 Playwright observer 參考 | TMO-013 / TMO-014：整合 PoC M1-M5 進 skill 本體 |
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 7：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版含 ASCII 流程圖）| 詳見全域 SOP 變動歷史 v1.x |

---

**交叉引用（純文字）**：
- 多語言實現範例 → 同套本 skill 子檔（`./examples.md`）
- 測試方法指南 → 同套本 skill 子檔（`./testing-methods.md`）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）

**核心精神**：語言可以換，框架可以變，但 Regression Guard 的原則永存。
