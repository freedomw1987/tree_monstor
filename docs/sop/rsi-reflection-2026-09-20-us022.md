# Gate 5 反省 — US-022 RSI 回歸警告（2026-09-20）

> **US-ID**：US-022
> **SP**：2
> **狀態**：✅ **DONE**

## 1. 完成內容

- 建新工具 `tools/rsi-alert.sh`
- 觀察數下降 30%+ 觸發告警
- 設基線 = 前 N 天平均觀察數（預設 7 天）
- 閾值 = 0.7（自訂可）
- 告警輸出到 stderr + `~/.tree-monstor/alerts.log`
- `tests/us022-rsi-alert.bats` 5 個 bats 全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 5 個 bats 全綠 |
| Gate 2 (lint) | ✅ | rsi-alert.sh bash -n syntax OK |
| Gate 3 (regression) | ✅ | us033 + td035 = 9 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 雙 log 設計

- **stderr**（Agent 可讀）：告警立即顯示給當下 agent
- **~/.tree-monstor/alerts.log**（人類可查）：歷史查詢

### 3.2 浮點比較用 awk

macOS bash 3.2 不支援 `((...))` 浮點，用 `awk` 算比值與閾值比較：

```bash
echo "$RATIO $THRESHOLD" | awk '{exit !($1 < $2)}'
```

退出碼 0 = true（比值小於閾值 → 告警）

### 3.3 Cron 整合

```bash
# 加入 crontab
0 0 * * * cd /path/to/tree_monstor && bash tools/rsi-alert.sh >> ~/.tree-monstor/cron.log 2>&1
```

每日 0 點跑 metrics + alert。

## 4. 累積指標

| 指標 | Sprint 11 末 | US-022 後 | 變化 |
|---|---|---|---|
| 工具 subcommand | 9 | 10（+rsi-alert.sh）| +1 |
| 規則庫 | 12 | 12 | 0 |
| bats 累計 | 239 | 244（+5 us022）| +5 |
| FR | 18 | 19（+FR-4.19）| +1 |

## 5. 下一步

US-021（14 天回顧）。
