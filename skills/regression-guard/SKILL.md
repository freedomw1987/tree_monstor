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

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 7：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版含 ASCII 流程圖）| 詳見 `docs/sop/handbook/changelog.md` |

---

**交叉引用（純文字）**：
- 多語言實現範例 → 見 `skills/regression-guard/examples.md`
- 測試方法指南 → 見 `skills/regression-guard/testing-methods.md`
- 全域 SOP 變動歷史 → 見 `docs/sop/handbook/changelog.md`

**核心精神**：語言可以換，框架可以變，但 Regression Guard 的原則永存。
