# Output Format — 文本 / JSON 報告格式

> 本檔為 regression-guard 的「輸出格式」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：輸出格式 28 行屬於「解析報告 / 串 CI」時才查。

## 文本輸出

```
✅ probe: user-login (12ms)
❌ probe: data-fetch (234ms)
   actual: null
   expected: { items: [...] }
   💡 Suggestion: Check database connection
```

## JSON 報告

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
