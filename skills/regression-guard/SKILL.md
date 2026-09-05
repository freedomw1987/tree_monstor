---
name: regression-guard
description: 在開發過程中埋入探針，透過 REGRESSION_MODE 自動運行驗證，失敗時提供建議讓 Agent 自動修正。
---
# Regression Guard Skill

## 核心原則

在開發過程中埋入探針，目的是為了系統的代碼是可以對之後的測試和排錯工作友好，測試和排錯checker agent 可以根據開發項目中探針的報錯和測試記錄進行驗證；


| 原則          | 說明                       |
| ----------- | ------------------------ |
| **1. 預留探針** | 在關鍵代碼位置埋入測試點             |
| **2. 環境控制** | `REGRESSION_MODE` 控制探針開關 |
| **3. 自動運行** | 開關開啟時執行所有探針              |
| **4. 自我修正** | Agent 閱讀結果，有問題就自動修正      |


## 環境變量

```
REGRESSION_MODE=true          # 開關探針
REGRESSION_OUTPUT=both        # 輸出格式: json | text | both
REGRESSION_STRICT=true        # 遇錯即停
REGRESSION_REPORT_PATH=./report.json  # 報告路徑
```

## 測試指令執行規範（fail-fast）

> **為什麼有這節**：agent shell 在 TTY 偵測上是模糊的（watch mode 通常依賴 isatty()），若 runner 進入 watch / interactive，shell 會卡住等 stdin，整個 session 凍結（截圖症狀：`Waiting for task (esc to give additional instructions)`）。

**強制規則**：執行 Gate 3 baseline / 修改後 output 時，**測試指令必須禁用 interactive / watch 模式**。不可使用會預設進入 watch 的指令。

### 主流 runner 前綴對照表

| Runner | ❌ 禁用（會卡） | ✅ 使用（一次性跑完） |
|---|---|---|
| **vitest** | `vitest` / `npx vitest` | `vitest run` / `npx vitest --run` |
| **jest** | `jest` / `npm test`（若 script 帶 watch） | `jest --ci` / `CI=1 npm test -- --watchAll=false` |
| **npm test** | 視 package.json 設定 | 加 `CI=1` 前綴，並顯式傳 `--watchAll=false`（jest）或 `--run`（vitest） |
| **bats** | — | `bats tests/`（無 watch，預設 OK）|
| **pytest** | `pytest --watch` | `pytest` / `pytest -x`（預設非 watch）|
| **playwright** | `playwright test --ui` | `playwright test`（預設 headless、非 watch）|
| **cargo test** | — | `cargo test`（無 watch）|
| **go test** | — | `go test ./...`（無 watch）|

### 通用保險：TTY 強制關閉

若不確定 runner 行為，**一律在指令後加 `< /dev/null`** 強制關閉 stdin：

```bash
npm test < /dev/null
npx vitest < /dev/null     # 即使忘記加 --run，也會立刻退出 watch
```

或設定環境變量 `CI=1`（多數 runner 會自動關 watch）：

```bash
CI=1 npm test
```

### Fail-fast 自檢

執行後若出現以下任一情況，視為 **Gate 3 失敗**，不可聲稱「做完了」：

- shell 卡住 > 30 秒無輸出
- 輸出末端出現 `Watch Usage` / `press h to show help` / `Waiting for file changes`
- 進程未退出、`Ctrl+C` 才能結束

正確做法：kill 進程 → 補上前綴規則 → 重跑。

## API 合約

### probe(name, actual, expected)

比對實際值與預期值。

```
參數:
  name     - 探針名稱（描述性）
  actual   - 實際值
  expected - 預期值
```

### assert(condition, message)

斷言條件為真。

```
參數:
  condition - 布林條件
  message   - 描述文字
```

### describe(name, fn)

分組管理探針。

```
參數:
  name - 套件名稱
  fn   - 包含探針的函數/區塊
```

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

## Agent 工作流程

```
┌────────────────────────────────────────────┐
│  1. 開發時：嵌入探針                         │
│     probe("login", result, expectedUser)   │
├────────────────────────────────────────────┤
│  2. 環境 REGRESSION_MODE=true              │
├────────────────────────────────────────────┤
│  3. 自動運行 → 印出結果                     │
│     失敗 → Agent 讀取報告                   │
├────────────────────────────────────────────┤
│  4. Agent 分析 suggestion                  │
│     自動修正代碼                            │
├────────────────────────────────────────────┤
│  5. 再次運行驗證 → 全部通過                │
└────────────────────────────────────────────┘
```

## 多語言實現示例

詳細可以參考 [[examples]]

## 測試方法參考

日常開發常用的測試方法指南，可以參考 [[testing-methods]]

## 最佳實踐

### 探針命名

```
✅ 'user-login-returns-correct-data'
✅ 'api-v1-users-[id]-returns-404'
❌ 'test1'
```

### 預期值管理

將預期值存放在 `fixtures/` 目錄：

```
fixtures/
├── user.json
├── config.yaml
└── expected-output.json
```

### 粒度控制


| 粒度  | 說明         |
| --- | ---------- |
| 太粗  | 一個功能一個探針   |
| 太細  | 每一行都探針     |
| 適中  | 每個邏輯斷言一個探針 |


## 關鍵實現要求

- ✅ 支援 `probe()` 值比對
- ✅ 支援 `assert()` 斷言
- ✅ 支援 `describe()` 套件分組
- ✅ 讀取環境變量配置
- ✅ 輸出文本 + JSON 雙軌
- ✅ 提供 `suggestion` 建議
- ✅ 失敗時 Agent 可自動修正

---

**核心精神**：語言可以換，框架可以變，但 Regression Guard 的原則永存。