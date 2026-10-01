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
   - **探針綁 Module（v2.9）**：探針名稱必含 Module prefix（如 `M01-user-login-returns-correct-data`）；用 `REGRESSION_MODULE=M01` 限定只跑某 Module
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

### Step 1：開發時埋入探針（含 Module prefix）

- **動作**：在關鍵代碼位置用 `probe(name, actual, expected)` / `assert(condition, message)` / `describe(name, fn)` 埋入測試點；**`name` 必含 Module prefix**（如 `M01-user-login-returns-correct-data`，其中 `M01` 為 system-design.md 定義的 Module 代碼）
- **為什麼**：探針讓後續測試 / 排錯 checker agent 能根據報錯和測試記錄驗證；Module prefix 讓探針可按 Module 跑、CI 可選只跑某 Module
- **產出**：源代碼內含探針（帶 Module prefix）
- **證據**：探針命名具體（避免 `test1`） + 探針名稱含 Module 代碼

### Step 2：環境變量配置（含 REGRESSION_MODULE）

- **動作**：設定 `REGRESSION_MODE=true` / `REGRESSION_OUTPUT=both` / `REGRESSION_STRICT=true` / `REGRESSION_REPORT_PATH=./report.json` / **`REGRESSION_MODULE=M01`（可選，限定只跑某 Module）**
- **為什麼**：環境變量控制探針開關 + 輸出格式 + 失敗處理 + Module 範圍
- **產出**：shell 環境變量或 .env 檔
- **證據**：`echo $REGRESSION_MODE` 顯示正確值 + `echo $REGRESSION_MODULE` 顯示 Module 代碼（若設定）

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
| **探針必含 Module prefix（v2.9 新增）** | Module 未定義（`M00` fallback）可省略 | `M01-user-login-returns-correct-data` 格式 |
| **`REGRESSION_MODULE` 限定 Module 範圍（v2.9 新增）** | 未設定 = 跑全部 | 設定後只跑該 Module 探針 |
| **探針不得跨 Module 檢查（v2.9 新增）** | integration test 例外（需標 `INT-` prefix） | 避免 Module 間隐含依賴 |

## 主流 runner TTY fail-fast 對照表

對照表（37 行）+ TTY 通用保險 + Fail-fast 自檢，見 [`runner-cheatsheet.md`](./runner-cheatsheet.md)。

## API 合約 + 環境變量

`probe` / `assert` / `describe` 三個 API + `REGRESSION_MODE` 等 4 個環境變量（30 行），見 [`api-contract.md`](./api-contract.md)。

## 輸出格式

文本輸出範例 + JSON 報告 schema（28 行），見 [`output-format.md`](./output-format.md)。

## 探針命名 + 粒度控制

命名最佳實踐 + 3 級粒度對照（16 行），見 [`probe-naming.md`](./probe-naming.md)。

## Jev Oracle 補充（進階）

> 這章是**可選章節**：預設 regression-guard 流程（Steps 1-4 + 上述全部規則）對多数項目已足夠。
> 只有在「柔性 AC / 真假 bug 混淆 / Confidence-gated 自動行動」等場景才需要。

完整 Jev Oracle（M6 / M6.1 / M6.2 / M6.3 / Flaky / M7 / M8 / CI 整合，共 506 行），見 [`jev-oracle.md`](./jev-oracle.md)。

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.10 | 2026-09-26 | Module 感知邏輯：探針必含 Module prefix；`REGRESSION_MODULE` 環境變量限定 Module 範圍；規則表加 3 條 Module 規則；dev-checker-loop v2.2 對齊 | 用戶決策：Module = 一組檔案；v2.6 dav-designer 鋪路、v2.2 dev-checker-loop 實作，本 skill 補完「探針 → Module」綁定 |
| v2.9 | 2026-09-26 | 拆檔：主檔 714 → 120 行；Jev Oracle（506 行）+ CI 整合→ `jev-oracle.md`；runner 對照表 → `runner-cheatsheet.md`；API+env → `api-contract.md`；輸出 → `output-format.md`；命名+粒度 → `probe-naming.md` | 達 150 行上限；Jev Oracle 屬「進階 / 可選」，拆出避免稀釋主檔注意力 |
| v2.8 | 2026-09-28 | 新增「M8 CI matrix」小節 + workflow strategy matrix + aggregate-matrix job | TMO-022：M8 CI matrix pipeline |

---
---

**交叉引用（純文字）**：
- 多語言實現範例 → 同套本 skill 子檔（`./examples.md`）
- 測試方法指南 → 同套本 skill 子檔（`./testing-methods.md`）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）

**核心精神**：語言可以換，框架可以變，但 Regression Guard 的原則永存。
