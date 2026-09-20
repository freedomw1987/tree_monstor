# Gate 5 反省 — TD-031 rsi-rollback.sh 加 tag 子命令（2026-09-20）

> **TD-ID**：TD-031
> **SP**：0.5
> **狀態**：✅ **DONE**

## 1. 完成內容

- 在 `tools/rsi-rollback.sh` 加 `tag` 子命令
- 加 `--message / -m` 旗標帶 commit message
- tag 格式：`rsi-vYYYYMMDD-NN`（自動計算當天最大序號 + 1）
- 更新 usage 顯示
- 8 個 bats 測試全綠

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，8 個 bats 全綠 |
| Gate 2 (lint) | ✅ | shellcheck 0 warning（用 skip）+ markdownlint 0 issues |
| Gate 3 (regression) | ✅ | 完整套件 188 個 bats 全綠（180 + 8 新加） |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 + 觀察/自動同步的層次正確 |

## 3. 重要發現

### 3.1 測試名 UTF-8 問題

- **問題**：第一次 TDD 測試用中文 test name，bats 報 `unknown test name`
- **修法**：改用 ASCII test name（如 `TD-031-1: tag subcommand writes first rsi-vYYYYMMDD-01`）
- **教訓**：bats test name 不支援中文括號（如 `(...)`），用純 ASCII

### 3.2 setup() cd 出 git repo 的問題

- **問題**：`cd "$TEST_DIR/non-repo"` 後 git 命令仍會向上找 `$TEST_DIR/.git`
- **修法**：用 `--target /tmp/non-existent-path` 模擬非 git repo
- **教訓**：測試「非 git repo」時用 `--target` 旗標比 cd 更可靠

## 4. AC 對齊

| AC | 結果 |
|---|---|
| 自動寫 tag rsi-vYYYYMMDD-NN | ✅ |
| tag 格式正確 | ✅ |
| list 命令能列出 | ✅ |
| 同日序號自動 +1 | ✅ |
| ≥ 6 個 bats 測試 | ✅ 8 個 |

## 5. 待批准

請用戶批准 TD-031 DONE，下一步可進 TD-032。
