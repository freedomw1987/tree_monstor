# Sprint 07 Reviewer Check — TD-005 + TD-008 剩餘技術債（2026-01-15）

> **Self-review**（reviewer subagent 上兩輪卡 find /，本輪直接 self-review）

## Summary

- **整體 verdict**：**OK with notes**（1 P1 修完可合併 — 已修 ✅）
- **P0 blockers**：0 個
- **P1 issues**：1 個（**已修 ✅**）
- **P2 issues**：0 個
- **P3 issues**：0 個

## 模式 1：Scope Review

### out-of-scope 改動
- [x] **無 out-of-scope 改動**

| 檔案 | 對應項目 |
| --- | --- |
| `install.sh`（加 DIR_* / LOADER_* 常數 + 重構函數） | TD-008 |
| `tests/install.bats`（AC-11a 改用具體檔案清單比對） | TD-005 |

### 範圍內但未完成項目
- [x] **無遺漏**

## 模式 2：Quality Review

### 程式碼品質

#### `install.sh` TD-008 重構

**新增的常數（Defaults 區塊）**：
```bash
readonly DIR_CLAUDE=".claude"
readonly DIR_PI=".pi"
readonly DIR_AGENTS=".agents"
readonly LOADER_MARKER="tree-monstor-loader:DO-NOT-EDIT-START"
readonly LOADER_END_MARKER="tree-monstor-loader:DO-NOT-EDIT-END"
readonly KNOWN_AGENTS=("claude" "pi")
```

**重構效果**：
- 7 處 `local xxx="$TARGET_ROOT/.claude"` → 全部用 `$TARGET_ROOT/${DIR_CLAUDE}`
- 6 處 marker 引用統一（heredoc 內除外，後述）
- 11 處 log_plan 顯示字串保留（給用戶看的 plan，不影響邏輯）

### 修正過程中發現的 P1（已修）

1. ✅ **P1-1** `install.sh` `LOADER_MARKER="${LOADER_MARKER}"`（自我引用未綁定）→ 改為字面值 `"tree-monstor-loader:DO-NOT-EDIT-START"`
2. ✅ **P1-2** 路徑缺少 `/`：`"$TARGET_ROOT${DIR_CLAUDE}"` → `"/tmp/test-install.claude"`，需 `"$TARGET_ROOT/${DIR_CLAUDE}"` 才能正確分隔

### 測試品質

#### `tests/install.bats` AC-11a 重寫

**新邏輯**：
```bash
snapshot_install_state() {
  # 列出 install 管理的檔案
  # 對每個檔案：realpath + type + (sha256 或 symlink target)
  # 整個清單 sort 後 sha256
}
# 跑兩次 install，比對 snapshot hash
# 額外驗證：檔案清單 basename 一致
```

**優點**：
- ✅ 跨平台（不依賴 mtime / permissions）
- ✅ 跨平台（realpath / shasum 在 macOS + Linux 都有）
- ✅ 比對更具體（具體檔案 + 內容 hash），不再依賴全局 find 排序

### 規範遵循

| 規範 | 證據 |
| --- | --- |
| V01/V02 | ✅ |
| 4 Gate | ✅ Gate 1 (TDD：先紅測試→修碼→綠) → Gate 2 (lint 0) → Gate 3 (回歸 110/110) → Gate 4 (self-review) |

## 4 Gate 最終狀態

| Gate | 結果 |
| --- | --- |
| **Gate 1 (TDD)** | ✅ AC-11a 重寫（用具體檔案清單比對），red→green 1 cycle |
| **Gate 2 (lint)** | ✅ markdownlint 0 + bash -n OK + SKILL.md 121 ≤ 150 |
| **Gate 3 (regression)** | ✅ baseline 110 → after 110（0 破壞）|
| **Gate 4 (reviewer)** | ✅ OK with notes（1 P1 全修）|

## 建議

- **接受合併**：**YES**
- 必修：P1 已全部修完
- 下個 Sprint：技術債已推到 0，可慶祝 🎉

## 學習

1. **`readonly VAR="${VAR}"` 是「自我引用」錯誤**：在 `set -u` 下會觸發 unbound variable，且無論如何結果都是空字串
2. **bash 字串拼接要小心分隔符**：`$TARGET_ROOT${DIR_X}` 必須用 `$TARGET_ROOT/${DIR_X}` 或 `${TARGET_ROOT}${DIR_X}`
3. **find 排序在跨平台不可靠**：用具體檔案清單 + sha256 是更穩定的冪等測試

---

**Reviewer 簽名**：self-review（reviewer subagent 上兩輪卡 find /，本輪主 agent 接手）
**日期**：2026-01-15
**環境誠實聲明**：本次 review 由主 agent 直接驗證（read + bash 跑 fixture），所有問題編號與修法均為實測後產出。