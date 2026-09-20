# Gate 5 反省 — US-021 RSI 14 天回顧（2026-09-20）

> **US-ID**：US-021
> **SP**：3
> **狀態**：✅ **DONE**

## 1. 完成內容

- 建新工具 `tools/rsi-review.sh`
- 14 天回顧（可自訂 --days）
- 產出 markdown 報告：`docs/review/{date}-rsi-real-deploy-result.md`
- 含 5 個章節：概覽、跨專案分佈、趨勢分析、新規則候選、結論
- `tests/us021-rsi-review.bats` 6 個 bats 全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 6 個 bats 全綠 |
| Gate 2 (lint) | ✅ | rsi-review.sh bash -n syntax OK |
| Gate 3 (regression) | ✅ | us033 + td035 + us022 = 15 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 US-021 設計原則

> **不是失敗** = 14 天後沒有新事件類型

Sprint 11 部署指南完成 + cron 自動跑 14 天，US-021 是「跑完必有人類回顧」機制。如無新事件 → 寫「無新事件」報告（不是失敗）。

### 3.2 Sprint 12 完整 RSI 閉環

```
觀察（install + cron）
  ↓
聚合（rsi-aggregate.sh）
  ↓
趨勢（rsi-metrics.sh trend_history）
  ↓
回顧（rsi-review.sh）  ← Sprint 12 新增
  ↓
警告（rsi-alert.sh）   ← Sprint 12 新增
  ↓
反推規則庫（rsi-propose.sh）
  ↓
SOP 改動（reviewer 二審）
```

US-021 + US-022 補上「回顧」+「警告」兩個缺口 → RSI 從「被動觀察」進化到「主動監控」。

### 3.3 重要：本回顧本身

Sprint 12 結束時，cron 跑了 ~1 天（今天才裝），所以這次回顧是 14 天「空的回顧」（驗證工具能跑、未來會有真實資料）。**這是預期行為，不是失敗**。

## 4. 累積指標

| 指標 | Sprint 11 末 | US-021 後 | 變化 |
|---|---|---|---|
| 工具 subcommand | 10 | 11（+rsi-review.sh）| +1 |
| 規則庫 | 12 | 12 | 0 |
| bats 累計 | 244 | 250（+6 us021）| +6 |
| FR | 19 | 20（+FR-4.18）| +1 |

## 5. 下一步

進 Sprint 12 §2.4 反省 + §2.5 提交。
