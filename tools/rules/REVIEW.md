# RSI 規則庫 Review

> 自動產生 by `tools/rsi-rules-review.sh`（Sprint 14 TD-038）
> 產生時間：2026-09-22 14:07:08
> 規則庫：`docs/sop/rsi-rules.md`

## 統計

| 項目 | 數值 |
| --- | --- |
| 總規則數 | 12 |
| 閾值 | 20 |
| 相似規則對數 | 6 |

### 按前綴分類

| 前綴 | 規則數 |
| --- | --- |
| markdown | 4 |
| bash | 3 |
| shellcheck | 1 |
| py | 1 |
| json | 1 |
| bats | 1 |
| awk | 1 |

## 相似規則對

```json
{
  "schema_version": "rsi-propose-similar/1.0",
  "rules_file": "docs/sop/rsi-rules.md",
  "total_events": 12,
  "similar_pairs": [
    {
      "a": "markdown_md029_ol_prefix",
      "b": "markdown_md036_emphasis",
      "prefix_similarity": 0.5,
      "lev_distance": 9
    },
    {
      "a": "markdown_md029_ol_prefix",
      "b": "markdown_md047_error",
      "prefix_similarity": 0.5,
      "lev_distance": 10
    },
    {
      "a": "markdown_md029_ol_prefix",
      "b": "markdown_md058_blanks",
      "prefix_similarity": 0.5,
      "lev_distance": 10
    },
    {
      "a": "markdown_md036_emphasis",
      "b": "markdown_md047_error",
      "prefix_similarity": 0.52,
      "lev_distance": 9
    },
    {
      "a": "markdown_md036_emphasis",
      "b": "markdown_md058_blanks",
      "prefix_similarity": 0.52,
      "lev_distance": 8
    },
    {
      "a": "markdown_md047_error",
      "b": "markdown_md058_blanks",
      "prefix_similarity": 0.57,
      "lev_distance": 8
    }
  ],
  "total_similar_pairs": 6
}
```

## 建議合併方案（人類決策）

依 SP-005 結論：AI 提建議，人類決策合併。

建議處理流程：
1. 上方 JSON 中 `similar_pairs` 每對都考慮是否合併
2. 合併原則：
   - 保留「描述較精準」的事件類型
   - 合併後要在 PRD §11 + rules/ 同步更新
   - 若規則觸發頻率差 > 5x，建議拆分而非合併
3. 決定後執行：
   - 修改 `docs/sop/rsi-rules.md`（刪除 / 合併 / 拆分）
   - 跑 `./tools/rsi-rules-review.sh` 重新驗證

## 何時該跑

依 docs/sop/handbook/2.8-rsi-evolution.md §6.6：
- 累積 5 個新事件後提醒 review（避免噪音）
- Sprint 結束時強制 review
- 規則庫 ≥ 20 條時強制 review

## 參考

- docs/prd/04-self-evolution.md §11.7 — Sprint 14 RSI 成熟化 PRD
- docs/system-design.md ADR-027 — 定期 review 原則
- docs/sop/rsi-rule-extension-2026-09-20.md — 規則庫擴展歷史
