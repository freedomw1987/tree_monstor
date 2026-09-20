# Gate 5 反省 — TD-034 rsi-propose confidence（2026-09-20）

> **US-ID**：TD-034
> **SP**：0.5
> **狀態**：✅ **DONE**

## 1. 完成內容

- `rsi-propose.sh` 加 `--confidence <0~1>` 旗標
- 計算公式：`min(1.0, freq × 0.05 + projects × 0.1)`
- 達門檻標「✅ 主要提案」，未達標「⚠️ Low Confidence（需人工確認）」
- 5 個 bats 全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，5 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | us030 + us034 = 15 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 confidence 公式反覆試錯

- **第一次**：freq × 0.3 + projects × 0.2 + 1 → 公式範圍 1.0~∞，全部 cap 1.00 → 沒區別
- **修正**：freq × 0.05 + projects × 0.1（10 次 + 5 專案達 1.0）→ freq=1, projects=0 = 0.05（低信心）
- **教訓**：公式要先用測試資料驗證範圍

### 3.2 `local` 在 main pipeline 內不能用

- **問題**：while loop 內 `local confidence` 報「can only be used in a function」
- **修法**：去掉 `local`，讓全域變數覆寫
- **教訓**：macOS bash 3.2 對 `local` 限制嚴

### 3.3 awk 浮點比較

- **問題**：`[[ "$a" > "$b" ]]` 不能比浮點
- **修法**：`awk -v a=... -v b=... 'BEGIN { print (a >= b) ? "yes" : "no" }'`
- **教訓**：浮點比較一律用 awk

## 4. AC 對齊

| AC | 結果 |
|---|---|
| 計算 confidence（0~1） | ✅ freq × 0.05 + projects × 0.1 |
| ≥ 0.7 列主要提案 | ✅ `✅ 主要提案` 標記 |
| < 0.7 列需人工確認 | ✅ `⚠️ Low Confidence（需人工確認）` 標記 |
| ≥ 5 個 bats | ✅ 5 個 |
| 預設行為不退化 | ✅ 沒 `--confidence` 時不標信心 |

## 5. 待批准

請用戶批准 TD-034 DONE，進 US-019。
