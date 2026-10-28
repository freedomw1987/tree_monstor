# Dav Developer — 探針、回歸同 Reviewer 二審

> 本檔為 `dav-developer` 嘅 Step 3（埋探針 + 回歸）＋ Step 4（Reviewer 二審）子檔；主檔只留指標。
> Step 1／2 細節 → 同套 `./workflow.md`；Gate 定義 → 同套 `./gates.md`。

## §1 Step 3：埋探針 + 回歸（唔使全項目跑）

### 1.1 動作與理由

- **動作**：為新行為埋**探針**（記錄關鍵 state／行為／boundary）→ 跑**改動範圍內**嘅測試套件 → 對比修改前後結果
- **為什麼**：探針係「防復發」嘅最小單位；回歸只需覆蓋**改動範圍**，全項目跑探針嘅成本遠高過收益
  （而且 Reviewer agent 下一 step 會再覆蓋一次）
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

## §2 Step 4：Reviewer 二審（Gate 4）

### 2.1 核心角色

- **dev** — 職責：領取任務 → 依 DESIGN.md／system-design.md／PRD 開發 → 保留探針 → 標記「等待校驗」
- **checker** — 職責：監控 backlog → 發現「等待校驗」→ 全面校驗 → 問題記錄 → dev 自動修復

### 2.2 Gate 4 前置

- **前置**：Step 1 測試已紅、Step 2 已綠、Step 3 探針已埋好（否則 reviewer 會捉到「測試係假綠」）
- **角色分工**：dev 做實作 → checker subagent 做獨立校驗 → 有問題返 dev 修 → 重複
- **證據**：checker subagent **原文回傳**（唔准自己改寫成「已通過」）

### 2.3 循環終止條件

- **用戶手動終止** — 由用戶決定何時停止
- **所有任務完成** — backlog 為空且所有狀態為「已完成」
- **循環上限** — 任一問題超過 20 次循環仍未解決則中斷（見同套 `./workflow.md` §2.4）

### 2.4 二審規則

- **獨立 reviewer 必開 subagent** — 例外：環境無 subagent 能力 → 降級並明示；限制：唔准自己審自己
- **UI 任務必跑 playwright-cli E2E**（連截圖證據） — 例外：純後端／CLI／腳本可跳過；限制：要在對話明示「無 UI 故不適用」及理由
- **有問題就返 Step 2 修** — 例外：無；限制：修完要重跑 Gate 3（探針／回歸）
- **證據要原文回傳** — 例外：無；限制：唔准改寫成「已通過」
