# Gate 5 反省 — TD-030 規則庫擴充 3→8（2026-09-20）

> **TD-ID**：TD-030
> **SP**：1
> **狀態**：✅ **DONE**

## 1. 完成內容

| 規則 | 對應事件 | 改動建議 |
|---|---|---|
| prompt_too_long | prompt 太長 | AGENTS.md 加 max prompt 限制 |
| skill_error | skill 缺 frontmatter | 修 SKILL.md |
| gate_skip | agent 跳過 gate | gates.json 加必跑機制 |
| **markdownlint_error** | markdown lint 錯 | AGENTS.md 或 handbook 修 |
| **bash_error** | shell script 錯 | tools/*.sh 加 shellcheck + set -e |
| **test_fail** | 測試失敗 | tests/*.bats 加 skip 或修 |
| **bats_unknown** | bats 不識 test name | 改 ASCII test name |
| **v02_violated** | 未標「推薦」 | AGENTS.md §1.5 強化 V02 |

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，10 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | 205 個 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 觀察/同步層次正確 |

## 3. 重要發現

### 3.1 while read 把「跨專案分佈」表也誤抓

- **問題**：「事件類型 | 次數」表之前的「專案 ID | 觀察數」表 5 行也被當成事件
- **修法**：加 `IN_EVENT_TABLE` 狀態，只在「事件類型 | 次數」header 之後抓
- **教訓**：解析 markdown 表格需要 stateful 機制

### 3.2 中文 grep 用 `[[ =~ ]]` 失敗

- **問題**：`[[ "$output" =~ V02 ]]` 在某些 locale 不穩
- **修法**：保持 ASCII 規則名 + `grep -qF` 字面比對
- **教訓**：規則 ID 一律 ASCII（如 v02_violated），中文用 description

## 4. AC 對齊

| AC | 結果 |
|---|---|
| 加 5 個新內建規則（3+5=8 個） | ✅ |
| AC 涵蓋每個規則 | ✅ |
| ≥ 8 個 bats 測試 | ✅ 10 個 |
| markdownlint 0 issues | ✅ |

## 5. 待批准

請用戶批准 TD-030 DONE，下一步可進 US-018 真實部署驗證。
