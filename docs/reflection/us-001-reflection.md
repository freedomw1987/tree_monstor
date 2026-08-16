# User Story US-001 反省報告

**User Story**：[US-001 為 tree_monstor 加入 `install.sh`](../../backlog.md)
**日期**：2025-08-16
**級別**：User Story（輕量反省）
**作者**：Agent（依 SOP 2.4 觸發）
**狀態**：已完成

---

## 1. 反省摘要

| 項目 | 結果 |
|---|---|
| 測試 | ✅ 19/19 通過 |
| AC 完成度 | ✅ 16/16 AC 全部 DONE |
| 子任務完成度 | ✅ 11/13（剩 T12 反省本任務、T13 提交） |
| 程式碼量 | 488 行 install.sh + 227 行 bats 測試 + 94 行 helper + 213 行 README |
| 文件完整度 | ✅ 討論記錄 + 計劃 + README + 反省（本檔）|

---

## 2. 6 維度檢查

### 2.1 ✅ UX/UI 一致性
**CLI UX 評估**：

| 面向 | 評估 | 證據 |
|---|---|---|
| 旗標命名一致性 | ✅ | 全部用 `--kebab-case`；單字母旗標 `-y`、`-q`、`-h` 為常用簡寫 |
| 輸出格式 | ✅ | 統一 `[i]`、`[✓]`、`[!]`、`[✗]`、`[~]` 5 種 prefix |
| 顏色 | ✅ | 6 色 + NO_COLOR 相容（符合 [no-color.org](https://no-color.org/) 標準） |
| 確認步驟 | ✅ | 預設互動；`--yes` 跳過；`--dry-run` 自動跳過 |
| 錯誤訊息 | ✅ | 每個錯誤都附「Try --help」提示 |
| 進度回饋 | ✅ | 每個動作都有 `log_ok`/`log_warn`/`log_err` |

**結論**：CLI UX 一致且友善。

### 2.2 ⏭️ RWD 響應式設計
**N/A** — CLI 工具不適用。

### 2.3 ⚠️ 技術債

| # | 問題 | 位置 | 嚴重度 | 行動 |
|---|---|---|---|---|
| TD-1 | `install_pi` 和 `install_agents_dir` 函數定義在 `uninstall_*` 函數之後；註解 "install_pi / install_agents_dir / uninstall are still stubs" 是階段開發遺留的 stale 註解 | install.sh:386-401 | 低 | 馬上修（重構：把函數按邏輯群組排列；刪除 stale 註解） |
| TD-2 | `install_pi` 和 `install_agents_dir` 在宣告時是 stub，現在有實作但函數宣告順序混亂 | install.sh | 低 | 同 TD-1 |
| TD-3 | `VERBOSE=0` 變數宣告了但從未使用 | install.sh | 極低 | �除或實作 |
| TD-4 | 沒做 `make install` 之類的 wrapper，使用者要記得 `chmod +x` | install.sh | 低 | README 已說明，但可在腳本開頭加自我 chmod 的友善提示，或文件加說明 |
| TD-5 | AC-11a 冪等測試是 hash-based，跨 macOS / Linux 的 `find` 排序可能不一致 | tests/install.bats:155 | 中 | 已有對應的 `AC-11b` 補強；以後可加更精準測試 |
| TD-6 | 沒做 CI（GitHub Actions） | 缺失 | 中 | 下個 Sprint 加（已有 TODO：設計計劃有提） |
| TD-7 | 沒做自動 `chmod +x install.sh` | install.sh | 低 | 文件化即可 |

### 2.4 ⚠️ 可維護性

| # | 項目 | 評估 |
|---|---|---|
| 程式碼結構 | ✅ | 模組化清楚：`parse_args`、`resolve_source`、`resolve_target_root`、`ensure_symlink`、`ensure_file`、`ensure_copy_tree`、`install_*`、`uninstall_*`、`do_uninstall` |
| 命名 | ✅ | 函數名稱語義清楚（`ensure_*` 表示冪等） |
| 函數長度 | ✅ | 沒有函數超過 50 行 |
| 重複代碼 | ✅ | `uninstall_claude` / `uninstall_pi` / `uninstall_agents_dir` 共享 `remove_managed_path`，無重複 |
| 註解 | ⚠️ | 部分註解是階段開發遺留（如 "still stubs"），需清理 |
| Magic strings | ⚠️ | `.claude`、`.pi`、`.agents`、`tree-monstor-loader:DO-NOT-EDIT-START` 等常散落在函數中，可考慮集中成變數 |

### 2.5 ✅ 測試覆蓋率

| 面向 | 評估 |
|---|---|
| AC 對應 | ✅ 16/16 AC 都有對應測試（含子測試共 19 個）|
| 邊角案例 | ✅ 冪等（AC-11a）、修復斷掉 symlink（AC-11b）、卸載保留使用者檔案（AC-8） |
| 安裝場景 | ✅ global、local、target、--agent 篩選、--no-agents-dir |
| 排除規則 | ✅ .obsidian、.git、.DS_Store（含巢狀目錄） |
| 環境隔離 | ✅ 每個測試用 `mktemp -d` + `env -i`，不污染真實 `~/` |
| 跨平台 | ⚠️ 沒在 CI 跑 Linux；macOS 已驗證 |

**測試套件結構**：

```
tests/
├── install.bats             ← 19 個 @test
├── helpers/
│   └── test-env.bash        ← 環境設定 + assert 函數
└── fixtures/
    └── mock-tree-monstor/   ← 模擬源（含 .obsidian/.git/.DS_Store）
```

### 2.6 ✅ 需求對齊

| 原始需求（討論 6 題） | 實際交付 |
|---|---|
| Q1: A + C（symlink + 本機 copy） | ✅ `ensure_symlink` + `install_agents_dir` |
| Q2: Claude Code + Pi Agent | ✅ 兩者皆有獨立 install 函數 |
| Q3: 按 agent 分流（Claude wrapper + Pi symlink） | ✅ Claude wrapper 含 `@` 引用；Pi 直接 symlink |
| Q4: 全域 + 專案層 + --target | ✅ 三個 mode 旗標 |
| Q5: 完全冪等 + --uninstall | ✅ `ensure_*` 冪等；`remove_managed_path` 用 marker 保護 |
| Q6: 純 Bash + README + 排除 + --dry-run + 彩色輸出 | ✅ 全部交付 |

**結論**：用戶的 6 個決定 100% 對應實作。

---

## 3. 過程中的重要決策（歷史追溯）

### 3.1 改用 `rsync` 取代 Bash find/read 迴圈
- **原因**：原本用 `find -print0 | while read -d ''`，在 bats 環境下 stdin 被佔用導致卡死
- **決策**：用 `rsync -a --prune-empty-dirs --exclude='.git/**' ...`
- **備援**：沒 rsync 時退回 `cp + find -prune -exec rm`
- **驗證**：AC-12 通過；測試全部恢復正常

### 3.2 `read -d ''` 在 bats 中的陷阱
- **原因**：`set -euo pipefail` + `< <(find ...)` 的 process substitution 與 bats 的 stdin 互動衝突
- **學到的教訓**：bats 黑盒測試下，避免在腳本中使用 process substitution 讀 find 結果；用管線 + 檔案或外部工具

### 3.3 排除規則用 `--prune-empty-dirs`
- **原因**：rsync 預設會留下「全被排除的空目錄」（如 `should-exclude-git/.git` 被排除但父目錄還在）
- **決策**：加 `--prune-empty-dirs`，讓「裡面完全沒內容的目錄」也被跳過

### 3.4 dry-run 自動跳過確認
- **原因**：dry-run 本身就不會改東西，再問確認是多餘
- **決策**：`confirm()` 第一個檢查 `[[ $DRY_RUN -eq 1 ]] && return 0`

### 3.5 NO_COLOR 標準 vs TTY 偵測
- **原因**：原本用 `[[ ! -t 1 ]]` 決定顏色，但這讓 AC-13 測試失敗（bats 的 `run` 接管 stdout → 非 tty）
- **決策**：只遵循 NO_COLOR 標準，不去偵測 tty；CI log 也看得見顏色

---

## 4. Action Items

### 4.1 立即處理（P0 / P1，現在就修）

| ID | 動作 | 預估時間 |
|---|---|---|
| TD-1 | 重構 `install.sh` 函數排列順序，刪 stale 註解，移除 `VERBOSE` 未用變數 | 5 分鐘 |
| TD-7 | 確認 README 有提及 `chmod +x`（已寫進 README「疑難排解」嗎？待查）| 1 分鐘 |

### 4.2 下個 Sprint（P2）

| ID | 動作 |
|---|---|
| TD-5 | 把 AC-11a 改成更精準的冪等測試（比對具體檔案而非 hash） |
| TD-6 | 加 GitHub Actions CI（macOS + Linux） |
| 增強 | Magic strings 集中成變數（讓未來新增 agent 更簡單）|

### 4.3 已完成但需記錄

- AC-1 ~ AC-16 全部 DONE
- 19 個 bats 測試全綠
- README 完成
- 5 個 Regression-Guard 探針埋好

---

## 5. 下一步

1. 立即處理 TD-1、TD-7（重構 + 確認 chmod 說明）
2. 進入 **SOP 2.5 — 提交成果**（用 `dav-submitter` 產出 3 層交付物）
