# Gate 5 反省 — TD-033 rsi-metrics trend_history（2026-09-20）

> **US-ID**：TD-033
> **SP**：0.5
> **狀態**：✅ **DONE**

## 1. 完成內容

- `rsi-metrics.sh` 加 `trend_history` subcommand
- 30 天滑動視窗
- 4 個指標趨勢（completion_rate / violation_count / td_close_rate / skill_usage）
- 8 級 sparkline（`▁▂▃▄▅▆▇█`）
- 5 個 bats 全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，5 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | us014 + us033 = 22 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 macOS date -v vs Linux date -d

- **問題**：trend_history 要算最近 N 天的日期
- **修法**：`date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d'`
- **教訓**：macOS / Linux 雙平台都需兼容

### 3.2 SUBCOMMAND 旗標解析

- **做法**：先掃所有 flag，遇 `trend_history` 字串就設 SUBCOMMAND 變數，再 `shift`
- **影響**：所有 `--option` 還能被 subcommand 用（順序無關）

### 3.3 sparkline bash 實作

- 用 `chars="▁▂▃▄▅▆▇█"` + `${chars:$idx:1}` 切片
- 8 級分布：`idx = (v - min) * 7 / (max - min)`
- 全部相同值時 min==max，給 `▁` 防除以 0

## 4. AC 對齊

| AC | 結果 |
|---|---|
| `rsi-metrics.sh trend_history` subcommand | ✅ |
| 30 天滑動視窗 | ✅ |
| 4 個指標有 trend | ✅ |
| Sparkline 字符 | ✅ `▁▂▃▄▅▆▇█` |
| ≥ 5 個 bats 測試 | ✅ 5 個 |
| markdownlint 0 issues | ✅ |

## 5. 待批准

請用戶批准 TD-033 DONE，進 TD-034。
