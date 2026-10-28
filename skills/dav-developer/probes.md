# Dav Developer — 探針、回歸同 Gate 4 交接

> 本檔為 `dav-developer` 嘅 Step 3（埋探針 + 回歸）＋ Step 4（交畀 `dav-reviewer`）子檔；主檔只留指標。
> Step 1／2 細節 → 同套 `./workflow.md`；Gate 定義 → 同套 `./gates.md`。

## §1 Step 3：埋探針 + 回歸（唔使全項目跑）

### 1.1 動作與理由

- **動作**：為新行為埋**探針**（記錄關鍵 state／行為／boundary）→ 跑**改動範圍內**嘅測試套件 → 對比修改前後結果
- **為什麼**：探針係「防復發」嘅最小單位；回歸只需覆蓋**改動範圍**，全項目跑探針嘅成本遠高過收益
  （而且 Gate 4 由用戶叫先做嘅 `dav-reviewer` skill 會再覆蓋一次）
- **產出**：探針檔 ＋ 範圍內測試輸出（baseline ＋ 修改後）＋ Diff 對比
- **證據**：對話貼「修改前 baseline ＋ 修改後 output ＋ Diff 對比」（Gate 3 證據）
- **範圍點決定**：改咗邊個 Module／邊啲檔 → 就跑邊啲（Module 級派工時用 `REGRESSION_MODULE=<M>`；
  唔涉及跨 Module 影響時唔需要全項目跑）

### 1.2 探針命名最佳實踐（含 Module prefix）

- **✅ `M01-user-login-returns-correct-data`**／**`M02-api-v1-users-[id]-returns-404`**／
  **`M03-payment-validation-rejects-empty-cart`**
- **❌ 唔好**：`test1`／`probe1`／`test_payment`
- **Module prefix 規則**：格式 `<MODULE_CODE>-<description>`；Module 代碼見 `docs/system-design.md` 嘅「Module 切割」章節；
  Module 未定義（`M00` fallback）時可省略 prefix；Integration test 用 `INT-` prefix（如 `INT-M01-M02-checkout-flow`）

### 1.3 粒度控制

- **❌ 太粗**：一個功能一個探針（`M01-user-management-works`）
- **❌ 太細**：每一行都探針（`M01-line-42-returns-true`）
- **✅ 適中**：每個邏輯斷言一個探針（`M01-user-login-returns-correct-data`）

### 1.4 Module 與探針嘅 4 個互動點

- **派工** — dev 領任務必綁 Module；同 Module 多任務可由同一 dev 順序處理、不同 Module 可平行
- **改檔** — dev 改檔必在 Module 邊界內；需跨 Module = 結束當前任務、新開跨 Module 任務
- **探針** — 探針名稱必含 Module prefix；CI 可選只跑某 Module
- **校驗** — checker 校驗範圍限定 Module 內；跨 Module 的 integration issue 標記為「跨 Module」、升級為新任務

### 1.5 測試指令防線

- **禁用 interactive／watch 模式**（會卡住等 stdin、凍結成個 session）→ 對照表見同套 `./runner-cheatsheet.md`
- **通用保險**：指令後加 `< /dev/null`，或設 `CI=1`
- **Fail-fast 自檢**（出現任一項 = Gate 3 失敗）：shell 卡住 > 30 秒無輸出／輸出末端出現 `Watch Usage` 或
  `press h to show help`／進程未退出要 `Ctrl+C` → 正確做法：kill 進程 → 補前綴規則 → 重跑

## §2 交畀 dav-reviewer 做 Gate 4（人手觸發）

- **Gate 4（品質審核）＋ Gate 4.5（需求對帳）由 `dav-reviewer` skill 承載**，2026-10-28 起**人手觸發**
  （唔喺 §2.3 自動執行段內 → 執行段做完 Gate 1/2/3 就交返用戶，唔使等審核）
- 本 skill 嘅責任到此為止：交付「探針已埋好 ＋ 改動範圍內回歸已過 ＋ 證據貼齊」畀審核者
- 詳細（審核流程 ＋ 需求對帳）→ 見同套 `dav-reviewer` skill
