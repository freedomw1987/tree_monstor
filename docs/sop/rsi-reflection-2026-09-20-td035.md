# Gate 5 反省 — TD-035 修 macOS bash 3.2 + set -u 相容性（2026-09-20）

> **US-ID**：TD-035
> **SP**：0.5
> **狀態**：✅ **DONE**

## 1. 完成內容

- `tools/rsi-metrics.sh` 修 `trend_sparkline()` 函式
- 用 `set +u` / `set -u` 隔離層包 `local -a vals=("$@")`
- 用 `prev_setopts="$-"` 記錄原狀、函式末尾還原
- `tests/td035-bash-setu.bats` 4 個 bats 全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 4 個 bats 全綠（us033 + td035） |
| Gate 2 (lint) | ✅ | rsi-metrics.sh bash -n syntax OK |
| Gate 3 (regression) | ✅ | us033 = 5 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 修法選擇

| 選項 | 描述 | 採用 |
|---|---|---|
| A. `local -a arr=()` | macOS bash 3.2 + set -u 不穩 | ❌ |
| B. string 累加（`arr+="val"`）| 改所有 caller | 🟡 也可行 |
| C. `set +u` / `set -u` 隔離層 | TD-035 採用 | ✅ 推薦 |

選 C 因為：
- 不需改 caller
- 函式內自動恢復原 setopts
- 對其他 sprint 工具沒影響

### 3.2 Sprint 11 留下的 TD-036 一併解決

Sprint 11 反省發現的 TD-036（trend_history 函式加 `set -u` 隔離層）→ TD-035 順手解決了。

## 4. 累積指標

| 指標 | Sprint 11 末 | TD-035 後 | 變化 |
|---|---|---|---|
| 工具 subcommand | 9 | 9 | 0 |
| 規則庫 | 12 | 12 | 0 |
| bats 累計 | 235 | 239（+4 td035） | +4 |
| FR | 17 | 18（+FR-4.20）| +1 |

## 5. 下一步

US-022（加回歸警告）。
