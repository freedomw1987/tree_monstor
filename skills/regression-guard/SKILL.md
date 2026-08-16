---
name: regression-guard
description: 在開發過程中埋入探針，透過 REGRESSION_MODE 自動運行驗證，失敗時提供建議讓 Agent 自動修正。
---

# Regression Guard Skill

## 核心原則

| 原則 | 說明 |
|------|------|
| **1. 預留探針** | 在關鍵代碼位置埋入測試點 |
| **2. 環境控制** | `REGRESSION_MODE` 控制探針開關 |
| **3. 自動運行** | 開關開啟時執行所有探針 |
| **4. 自我修正** | Agent 閱讀結果，有問題就自動修正 |

## 環境變量

```
REGRESSION_MODE=true          # 開關探針
REGRESSION_OUTPUT=both        # 輸出格式: json | text | both
REGRESSION_STRICT=true        # 遇錯即停
REGRESSION_REPORT_PATH=./report.json  # 報告路徑
```

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

| 粒度 | 說明 |
|------|------|
| 太粗 | 一個功能一個探針 |
| 太細 | 每一行都探針 |
| 適中 | 每個邏輯斷言一個探針 |

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
