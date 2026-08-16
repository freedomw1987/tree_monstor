# 設計計劃：為 tree_monstor 加入 `install.sh`

**對應 Backlog**：US-001
**日期**：2025-08-16
**狀態**：待用戶審核
**作者**：Agent（依 SOP 2.2）
**討論來源**：[`docs/discussion/2025-08-16-install-sh-design.md`](../discussion/2025-08-16-install-sh-design.md)

---

## 1. 目標

為 `tree_monstor` 提供一個**冪等、可卸載、跨平台**的安裝腳本，讓 Claude Code 和 Pi Agent 能在全域或專案層讀取到 `AGENTS.md`、`SOUL.md` 和 `skills/`，並且改源檔能即時生效（透過軟連結）。

---

## 2. 系統架構

### 2.1 檔案結構

```
tree_monstor/
├── install.sh                  ← 主腳本（純 Bash）
├── install.sh.md (或 README.md)
├── tests/
│   ├── install.bats            ← bats 測試（黑盒測試 install.sh）
│   ├── helpers/
│   │   └── test-env.bash       ← 測試環境（建立 tmp dir、模擬 home）
│   └── fixtures/
│       └── mock-tree-monstor/  ← 模擬的 tree_monstor 結構
│           ├── AGENTS.md
│           ├── SOUL.md
│           └── skills/
│               ├── skill-a/
│               └── skill-b/
└── docs/
    ├── plan/2025-08-16-install-sh-design.md  ← 本檔
    └── ...
```

### 2.2 安裝佈局示意圖

#### 全域安裝（預設）

```
~/.claude/
├── CLAUDE.md                       ← wrapper，內含：
│     # tree_monstor loader (auto-managed)
│     @/Users/<you>/path/tree_monstor/AGENTS.md
│     @/Users/<you>/path/tree_monstor/SOUL.md
└── skills/ → /Users/<you>/path/tree_monstor/skills  (symlink)

~/.pi/
├── AGENTS.md → /Users/<you>/path/tree_monstor/AGENTS.md  (symlink)
├── SOUL.md   → /Users/<you>/path/tree_monstor/SOUL.md    (symlink)
└── skills/   → /Users/<you>/path/tree_monstor/skills      (symlink)

~/.agents/
├── tree_monstor/                   ← 本機副本（官方慣例）
│   ├── AGENTS.md    (copy)
│   ├── SOUL.md      (copy)
│   └── skills/      (copy，排除 .obsidian/.git/.DS_Store)
```

#### 專案層安裝（`--local`）

```
<target>/
├── .claude/
│   ├── CLAUDE.md (wrapper)
│   └── skills/ → <tree_monstor>/skills
├── .pi/
│   ├── AGENTS.md → <tree_monstor>/AGENTS.md
│   ├── SOUL.md   → <tree_monstor>/SOUL.md
│   └── skills/   → <tree_monstor>/skills
└── .agents/tree_monstor/ (copy)
```

### 2.3 旗標設計

| 旗標 | 說明 | 預設 |
|---|---|---|
| `--global` | 安裝到 `~/` | ✅（預設） |
| `--local` | 安裝到當前目錄 | |
| `--target <path>` | 安裝到指定路徑（隱含 `--local` 語意） | |
| `--agent claude` | 只裝給 Claude Code | |
| `--agent pi` | 只裝給 Pi Agent | |
| `--agents-dir` | 同時裝一份到 `.agents/` | ✅（預設開） |
| `--no-agents-dir` | 不裝到 `.agents/` | |
| `--uninstall` | 卸載（含 `--local` / `--target` / `--agent` 篩選） | |
| `--dry-run` | 只印出會做什麼，不實際執行 | |
| `--help` / `-h` | 顯示說明 | |

---

## 3. 技術架構設計

### 3.1 技術棧

- **語言**：純 Bash（POSIX 相容為目標，但用 `#!/usr/bin/env bash`）
- **測試框架**：[bats](https://github.com/bats-core/bats-core)（Bash Automated Testing System）
- **依賴**：無（只用 shell 內建指令：`ln`、`rm`、`mkdir`、`readlink`、`find`）
- **相容性**：macOS（Bash 3.2+）、Linux（Bash 4+）、WSL

### 3.2 模組劃分（Module M1）

| 子模組 | 職責 | 函數 |
|---|---|---|
| **M1.1 旗標解析** | 解析 CLI 參數 | `parse_args()` |
| **M1.2 環境偵測** | 偵測 OS、來源路徑、目標路徑 | `detect_env()` |
| **M1.3 冪等連結** | 檢查、修復、建立 symlink/copy | `ensure_symlink()`, `ensure_copy()` |
| **M1.4 Claude 安裝** | Claude Code 安裝邏輯 | `install_claude()` |
| **M1.5 Pi 安裝** | Pi Agent 安裝邏輯 | `install_pi()` |
| **M1.6 Agents dir 安裝** | 本機 `.agents/` 安裝 | `install_agents_dir()` |
| **M1.7 排除規則** | 過濾不該複製的檔案 | `should_exclude()` |
| **M1.8 卸載** | 反向操作 | `uninstall()` |
| **M1.9 輸出** | 彩色 log | `log_info()`, `log_ok()`, `log_warn()`, `log_err()` |
| **M1.10 Dry-run** | 預覽模式 | `DRY_RUN` 全域變數 |

每個子模組獨立函數，方便測試與維護。

### 3.3 冪等性策略

每次安裝前對目標做檢查：

```
對每個預期目標：
  1. 不存在 → 建立
  2. 存在，是 symlink，指向正確 → 跳過 ✅
  3. 存在，是 symlink，但指向錯誤 / 斷掉 → �掉重建 🔧
  4. 存在，是普通檔（非 symlink）→ 警告，詢問是否覆蓋 ⚠️
```

Wrapper 檔（`CLAUDE.md`）會包含獨特 marker：
```bash
# tree-monstor-loader:DO-NOT-EDIT-START
... 自動生成內容 ...
# tree-monstor-loader:DO-NOT-EDIT-END
```

`--uninstall` 透過 marker 識別哪些是自己建的，只刪除自己建的。

---

## 4. 測試策略（TDD）

### 4.1 測試框架選擇

用 **bats**，原因：
- 專門為 Bash 設計，社群標準
- 支援 `setup` / `teardown` / `skip` / table-driven test
- 易於在 CI 跑

### 4.2 測試案例對照 AC

| AC | 測試案例 |
|---|---|
| AC-1 | `test_installs_skills_symlinks_globally` |
| AC-2 | `test_creates_claude_wrapper_with_at_references` |
| AC-3 | `test_creates_pi_symlinks_to_source_files` |
| AC-4 | `test_also_installs_to_local_agents_dir` |
| AC-5 | `test_local_flag_installs_to_cwd` |
| AC-6 | `test_target_flag_installs_to_specified_path` |
| AC-7 | `test_agent_flag_filters_targets` |
| AC-8 | `test_uninstall_removes_only_managed_files` |
| AC-9 | `test_dry_run_makes_no_changes` |
| AC-10 | `test_help_prints_usage` |
| AC-11 | `test_idempotent_repeated_runs`、`test_repairs_broken_symlinks` |
| AC-12 | `test_excludes_obsidian_git_dsstore` |
| AC-13 | `test_output_uses_colors` |
| AC-14 | `test_runs_on_macos_bash_3_plus`（CI 跑） |
| AC-15 | `test_readme_exists_and_documents_usage` |
| AC-16 | `test_all_acs_have_test`（meta-test） |

### 4.3 測試輔助

- `tests/helpers/test-env.bash`：建立 tmp 目錄、模擬 `$HOME`、複製 fixture
- `tests/fixtures/mock-tree-monstor/`：模擬的 tree_monstor 結構
- 所有測試跑在 tmp dir，**不污染用戶真實 `~/`**

### 4.4 CI 規劃（未來）

```
.github/workflows/test.yml
  - runs-on: macos-latest + ubuntu-latest
  - steps:
    - checkout
    - install bats
    - run: bats tests/
```

（本計劃階段不實作 CI，但程式設計要 CI-friendly）

---

## 5. 開發流程（TDD + 循環）

按 SOP 2.3，使用以下技能：

### 階段 A：TDD 骨架（`tdd-test-writer`）
1. 寫空的 `install.sh`（只 echo "TODO"）
2. 寫 bats 測試，**全部紅燈**
3. 提交 red

### 階段 B：實作迴圈（`dev-checker-loop` + `regression-guard`）
1. 挑一個 AC → 寫最小實作讓對應測試綠燈
2. 重構
3. 跑全部測試，確認沒破壞其他東西
4. 下一個 AC

每完成一個 AC 就 commit。

### 階段 C：探針（`regression-guard`）
在關鍵函數加 `__PROBE__` 標記，方便日後除錯：
```bash
install_claude() {
  echo "__PROBE__:install_claude:start" >&2
  ...
  echo "__PROBE__:install_claude:end" >&2
}
```

### 階段 D：反省（`dav-reflection`）
US-001 完成後，做 User Story 級別反省：
- 6 維度檢查（UX 一致性、技術債、可維護性、測試覆蓋、需求對齊...）
- 產出 `docs/reflection/2025-08-16-install-sh-reflection.md`

### 階段 E：提交（`dav-submitter`）
產出 3 層交付物：
- 對話摘要
- `docs/deliverable/2025-08-16-install-sh.md`
- `docs/deliverable/2025-08-16-install-sh.html`

---

## 6. UX/UI 規劃

雖然這是 CLI 工具，但有「使用者體驗」：

### 6.1 輸出風格

```
[✓] Detected source: /Users/you/path/tree_monstor
[✓] Target mode: global
[✓] Agent: Claude Code + Pi Agent
[i] Plan:
    - ~/.claude/CLAUDE.md (wrapper with @references)
    - ~/.claude/skills → /Users/you/path/tree_monstor/skills
    - ~/.pi/AGENTS.md → /Users/you/path/tree_monstor/AGENTS.md
    - ~/.pi/SOUL.md → /Users/you/path/tree_monstor/SOUL.md
    - ~/.pi/skills → /Users/you/path/tree_monstor/skills
    - ~/.agents/tree_monstor/ (copy)

[?] Proceed? [y/N]
```

- ✅ 綠、`[i]` 藍、`[?]` 黃、`[✗]` 紅
- Dry-run 時全部加 `(dry-run)` 前綴
- 卸載時**先預覽**再確認

### 6.2 互動設計

- 預設互動式（讀 stdin）
- 加 `--yes` / `-y` 跳過確認，給 CI 用
- 加 `--quiet` / `-q` 只印錯誤與最終摘要

---

## 7. 風險與緩解

| 風險 | 緩解 |
|---|---|
| 覆蓋用戶自己的 `CLAUDE.md` | 偵測到普通檔（非 symlink、非我們的 wrapper）→ 警告 + 詢問 |
| 路徑含空格或特殊字元 | 所有路徑用 `"$var"` 包裹；測試案例包含空格路徑 |
| macOS 預設 Bash 3.2 不支援某些語法 | 避免 `mapfile`、associative array；用 POSIX 相容寫法 |
| 軟連結迴圈（symlink 到自己） | 檢查目標路徑不是來源路徑的子集 |
| `--uninstall` 誤刪 | 用 marker comment 識別；先預覽；加 `--force` 才真的刪 |
| 來源 tree_monstor 位置改變 | Wrapper 寫死絕對路徑（不支援相對）；README 提醒若搬移要重跑 |

---

## 8. 已知限制 / 未做事項

- ❌ 不支援 Windows 原生（WSL 可）
- ❌ 不做自動更新檢查
- ❌ 不做備份用戶原檔（卸載時若偵測到衝突會警告）
- ❌ 第一版不做 CI（架構留好，未來加）

---

## 9. 交付物清單

完成後應產出：

- [ ] `install.sh`（含 marker、可執行、有 `set -euo pipefail`）
- [ ] `tests/install.bats`（覆蓋所有 AC）
- [ ] `tests/helpers/test-env.bash`
- [ ] `tests/fixtures/mock-tree-monstor/...`
- [ ] `README.md`（給用戶看的安裝說明）
- [ ] `docs/deliverable/2025-08-16-install-sh.md`（交付詳錄）
- [ ] `docs/deliverable/2025-08-16-install-sh.html`（視覺化）
- [ ] `docs/reflection/2025-08-16-install-sh-reflection.md`（US 級反省）

---

## 10. 待用戶確認

請你看完這份計劃後告訴我：

1. **計劃 OK，可以進入 SOP 2.3 開始寫程式？**
2. 或者你想改某個部分（例如：模組劃分、測試框架、旗標設計、交付物清單）？

確認後我就會：
1. 進入 SOP 2.3：用 `tdd-test-writer` 先寫測試（red）
2. 然後 `dev-checker-loop` 實作 → 綠燈 → 重構
3. 中間穿插 `regression-guard` 加探針
4. 完成後 `dav-reflection` + `dav-submitter`
