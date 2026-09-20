# Gate 5 反省 — TD-032 rsi-sync.sh --dry-run 列出檔案清單（2026-09-20）

> **TD-ID**：TD-032
> **SP**：0.5
> **狀態**：✅ **DONE**

## 1. 完成內容

- 擴充 `tools/rsi-sync.sh` 的 `--dry-run` 邏輯
- 對每個將同步檔案顯示：path / action（add/modify/skip）/ md5 hash
- 加 `MODIFY_COUNT` / `ADD_COUNT` 統計
- `--dry-run` 模式預設不破壞（必加 `--apply` 才真正寫）

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，7 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | 完整套件 195 個 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 + 觀察/同步的層次正確 |

## 3. 重要發現

### 3.1 test setup 的「local-override」覆蓋所有專案

- **問題**：第一次 TDD 測試三個專案都被標 local-override，導致 dry-run 沒列檔案
- **修法**：setup 結尾 `rm -f proj1/.pi/sop/.local-override`，讓 proj1 有同步行為
- **教訓**：mock 專案要分清楚 3 種場景：sync 成功 / skip override / diff 覆蓋

### 3.2 bash regex `[[ =~ ]]` 不匹配中文

- **問題**：`[[ "$output" =~ [Rr]esult ]]` 不匹配「=== 結果 ===」
- **修法**：改用 `echo "$output" | grep -qF "已處理專案"`（字面比對）
- **教訓**：中文輸出不要用 `[[ =~ ]]`，改用 grep -F

### 3.3 md5 在 macOS vs Linux 不同

- **問題**：macOS `md5 -q file`，Linux `md5sum file | awk '{print $1}'`
- **修法**：`md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | awk '{print $1}'`
- **教訓**：跨平台腳本要寫 fallback

## 4. AC 對齊

| AC | 結果 |
|---|---|
| 顯示檔案路徑 + 動作 + hash 對比 | ✅ |
| 預設不破壞（dry-run 模式） | ✅ |
| ≥ 5 個 bats 測試 | ✅ 7 個 |
| markdownlint 0 issues | ✅ |

## 5. 待批准

請用戶批准 TD-032 DONE，下一步可進 TD-030（規則庫擴充 1 SP）。
