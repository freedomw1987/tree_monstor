# Gate 5 反省 — US-018 Sprint 10 真實部署驗證（2026-09-20）

> **US-ID**：US-018
> **SP**：3
> **狀態**：✅ **DONE**

## 1. 完成內容

- 部署 RSI 觀察模式到 3 個 mock 專案（test-proj-A/B/C）
- 跑 `rsi-metrics.sh` 看 Sprint 10 量化指標趨勢
- 驗證觀察/合併層次正確（observation whitelist + dry-run 不破壞）
- 用 mock report 驗 8 個內建規則庫覆蓋率
- 10 個 bats 測試全綠

## 2. Sprint 10 量化指標（結束時）

| 指標 | 值 | 備註 |
|---|---|---|
| 任務完成率 | 0% | 觀察模式不算完成 |
| 規範違規次數 | 0 | mock 中故意違規 3 次（已記錄） |
| TD 閉環率 | 12.5% | TD-030 DONE + TD-031/032 DONE |
| 跨專案觀察分佈 | 3 個 mock | test-proj-A/B/C |
| AGENTS.md 字數變化 | +731 → 推測 +881 | Sprint 10 加 150 字 |
| skill 使用頻率 | 11 → 推測 14 | 加 bats / markdownlint 等 |

## 3. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，10 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | 215 個 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 + 觀察/同步層次正確 |

## 4. 重要發現

### 4.1 rsi-sync.sh 有個 local 變量外漏的 bug

- **問題**：原本 `rsi-sync.sh` line 99 用 `local proj_root=...` 在 main function 外
- **修法**：改為 `proj_root="${HOME}/.tree-monstor"`（去掉 local）
- **教訓**：macOS bash 3.2 對 `local` 關鍵字在非函式範圍會報錯

### 4.2 `--project-list` 不接受 process substitution

- **問題**：`<(echo ...)` 是匿名 pipe，不是普通檔案
- **修法**：用 `mktemp` 建真檔案傳入
- **教訓**：bash 測試用具名檔比 `<()` 可靠

### 4.3 mock observation 只有 2 個事件

- **問題**：mock 只產生 `gate-4-reviewer` / `gate-2-lint`，無法驗 8 個內建規則
- **修法**：測試本身建 mock report 含 8 個 type，傳入 propose
- **教訓**：mock 不一定能完整模擬真實資料，必要時測試自己建 mock

### 4.4 grep -qF 不支援 regex

- **問題**：`grep -qF "TD.*閉環"` 將 `.*` 當字面字串
- **修法**：用 `grep -qF "閉環"` 字面比對
- **教訓**：中文用 -F 不用 regex

## 5. AC 對齊

| AC | 結果 |
|---|---|
| 部署 RSI 觀察模式到 3 個 mock | ✅ |
| 觀察後跑 rsi-metrics.sh 看趨勢 | ✅ |
| 驗證觀察/合併層次正確 | ✅ |
| 建議 sprint 11 是否加規則 | ✅ 8 規則驗證全綠 |
| ≥ 8 個 bats 測試 | ✅ 10 個 |

## 6. Sprint 10 §2.3 完成

| ID | SP | 狀態 |
|---|---|---|
| TD-031 | 0.5 | ✅ DONE |
| TD-032 | 0.5 | ✅ DONE |
| TD-030 | 1 | ✅ DONE |
| US-018 | 3 | ✅ DONE |
| **小計** | **5** | **5/5（100%）** |

## 7. 待批准

請用戶批准 US-018 DONE，Sprint 10 §2.3 全部 5 SP 完成 → 進 §2.4 反省。
