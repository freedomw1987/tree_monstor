# RSI 反思 — US-024（2026-09-20）

> **對應 Sprint**：Sprint 13 US-024
> **類型**：User Story（rollback dry-run）
> **SP**：1 SP

## 1. 做了什麼

`rsi-rollback.sh` 加 `--dry-run` 旗標。

- 列出將被回滾的 commits（tag → HEAD 之間）
- 列出受影響的檔案清單
- 模擬將執行的 git 操作（revert / checkout）
- **不實際執行任何 git 操作**

## 2. 為什麼這樣做

rsi-rollback 是破壊性操作（git revert + tag delete），誤滾風險高。

| 情境 | 沒 dry-run | 有 dry-run |
|---|---|---|
| 滾錯 tag | 不可逆 | 先看再滾 |
| 衝突 | 強制 checkout 丟 commit | 先看會丟什麼 |
| 教育新人 | 不知道會發生什麼 | 看輸出就懂 |

## 3. 過程問題與解法

### 問題 1：函式內 set -u 報 unbound variable（TD-035）

`cmd_dry_run` 函式內用了未定義的 `$target_repo` 變量（heredoc 內），set -u 報錯。

**解法**：函式頂部 `set +u`，函式末尾 `set -u` 還原（TD-035 隔離層）

### 問題 2：中文輸出亂碼

macOS bash 3.2 + UTF-8 中文輸出會出現亂碼。

**解法**：函式頂部加 `export LC_ALL=C; export LANG=C`

### 問題 3：tag 格式驗證

dry-run 也需驗證 tag 格式（避免誤滾到任意 tag）。

**解法**：既有的 rsi-v* 格式驗證保留，dry-run 只是「看完不執行」

## 4. 量化指標

| 指標 | 數值 |
|---|---|
| 工具功能 | rsi-rollback 多了 1 個安全機制 |
| bats 新增 | 8 個 |
| markdownlint | 0 issues |

## 5. 下一步建議

- Sprint 14+ 可加 `--dry-run` 到 rsi-sync.sh
- 可加 `--dry-run --verbose` 顯示更多細節

## 6. 版本

- v1.0（2026-09-20）— US-024 反思初版