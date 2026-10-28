# Output Format — 文本 / JSON 報告 / PR comment / matrix summary

> 本檔講**報告長相**：字段、段落結構、欄位值；對應章節見同套 `dav-developer` skill。
> 點跑同 gating 規則 → 同套本 skill 子檔（`./jev-oracle.md`）；長範例 → 同套本 skill 子檔（`./examples.md`）。

## 文本輸出

```
✅ probe: user-login (12ms)

❌ probe: data-fetch (234ms)
   actual: null
   expected: { items: [...] }
   💡 Suggestion: Check database connection
```

## JSON 報告

- **`timestamp`** — 報告時間（ISO 8601）
- **`summary`** — `total`／`passed`／`failed` 三個計數
- **`failures[]`** — 每筆：`name`（探針名）／`error`（錯因）／`suggestion`（修正建議）

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

## batch report schema（M7 新增欄位）

- **`batch_report.flaky_likelihood`** — flaky 機率
- **`batch_report.flaky_measured.likelihood`** — 實測 flaky_likelihood
- **`batch_report.flaky_measured.classification`** — 分類（`stable`／`flaky`／`highly_flaky`）
- **`batch_report.flaky_measured.jev_flaky_likelihood`** — Jev 側計出嘅值
- **`batch_report.flaky_measured.delta`** — 兩者差值
- **`batch_report.flaky_measured.warning`** — 差異大就要標 ⚠️
- **`batch_report.flaky_measured.sample_count`** — 樣本數

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

## gh pr comment 4 段結構（M7）

1. **Journey 標題** — 內容：story_id ＋ title ＋ 4 維度表
2. **Fix Proposal** — 內容：信心度 ＋ gating 決定
3. **問題分析摘要** — 內容：從 fix_proposal 抓前 300 字
4. **Sandbox 建議** — 內容：一鍵 pipeline 指令

## matrix summary（M8）

- **每個 story 一段**，4 個欄位：
  - **`Health`** — 🟢 green／🟡 yellow／🔴 red
  - **`Fix Priority`** — 0–3 數值
  - **`Flaky`** — flaky_likelihood
  - **`Type`** — `stable`／`real_bug`／`flaky`
- **預設 3 個 story 嘅實測值**：
  - **`US-101`** — Health：🟢 green；Fix Priority：0.50；Flaky：0.00；Type：stable
  - **`US-M62`** — Health：🔴 red；Fix Priority：2.97；Flaky：0.00；Type：real_bug
  - **`US-M63`** — Health：🟡 yellow；Fix Priority：1.80；Flaky：0.20；Type：flaky
