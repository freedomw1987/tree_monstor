# tree_monstor install.sh

`install.sh` 幫你把 `tree_monstor` 的 `AGENTS.md`、`SOUL.md` 和 `skills/` 暴露給 AI coding agents（Claude Code、Pi Agent 等），讓它們在**全域**或**專案層**都能讀取到，且改源檔能即時生效。

## Quick Start

```bash
chmod +x install.sh        # 一次性（如果檔案沒執行權限）
./install.sh               # 全域裝給 Claude Code + Pi Agent
```

---

## Usage

```bash
./install.sh [options]
```

### Scope（選一個）

| 旗標 | 說明 |
|---|---|
| `--global` | 裝到 `$HOME`（**預設**） |
| `--local` | 裝到當前目錄 |
| `--target <path>` | 裝到指定路徑 |

### Selection（選擇性）

| 旗標 | 說明 |
|---|---|
| `--agent <claude\|pi>` | 只裝給單一 agent（可重複；預設兩個都裝）|
| `--no-agents-dir` | 不裝到 `.agents/` 本機副本 |

### Source（選擇性）

| 旗標 | 說明 |
|---|---|
| `--source <path>` | tree_monstor 源路徑（預設：腳本所在目錄）|

### Actions

| 旗標 | 說明 |
|---|---|
| `--uninstall` | 卸載（只刪腳本自己建的檔案/連結）|
| `--dry-run` | 只印計畫，不實際執行 |

### UX

| 旗標 | 說明 |
|---|---|
| `-y`, `--yes` | 跳過確認（給 CI 用）|
| `-q`, `--quiet` | 安靜模式（只印錯誤）|
| `-h`, `--help` | 顯示說明 |
| `--version` | 顯示版本 |

---

## Examples

```bash
# 最常見：全域裝給 Claude Code + Pi Agent
./install.sh

# 只裝給 Claude Code
./install.sh --agent claude

# 裝到當前專案（給整個 repo 用）
./install.sh --local

# 裝到指定專案
./install.sh --target ~/projects/my-app

# 預覽會做什麼（不實際執行）
./install.sh --dry-run

# 不裝到 ~/.agents/ 本機副本（節省空間）
./install.sh --no-agents-dir

# 卸載全域安裝
./install.sh --uninstall

# 卸載專案層安裝
./install.sh --uninstall --local

# CI / 腳本用（跳過確認）
./install.sh --yes
```

---

## 安裝後的檔案結構

### 全域安裝（`--global`）

```
~/.claude/
├── CLAUDE.md        ← wrapper，用 @ 引用 tree_monstor 的 AGENTS.md / SOUL.md
└── skills → ~/path/tree_monstor/skills   (symlink)

~/.pi/
├── AGENTS.md → ~/path/tree_monstor/AGENTS.md   (symlink)
├── SOUL.md   → ~/path/tree_monstor/SOUL.md     (symlink)
└── skills    → ~/path/tree_monstor/skills      (symlink)

~/.agents/tree_monstor/   ← 完整副本（排除 .obsidian/.git/.DS_Store）
├── AGENTS.md
├── SOUL.md
└── skills/...
```

### 專案層安裝（`--local` 或 `--target <path>`）

```
<project>/
├── .claude/
│   ├── CLAUDE.md
│   └── skills → <tree_monstor>/skills
├── .pi/
│   ├── AGENTS.md → <tree_monstor>/AGENTS.md
│   ├── SOUL.md   → <tree_monstor>/SOUL.md
│   └── skills    → <tree_monstor>/skills
└── .agents/tree_monstor/
```

---

## 設計重點

### 雙軌設計：symlink + 本機 copy

| 安裝方式 | 優點 | 用途 |
|---|---|---|
| **Symlink**（`~/.claude/skills`、`~/.pi/AGENTS.md` 等） | 改源檔即時生效，零重複 | 主要給 agent 讀 |
| **本機 copy**（`~/.agents/tree_monstor/`） | 符合 Claude Code 官方慣例 | 給 IDE、工具列舉用 |

### 冪等（Idempotent）

重複執行 `install.sh` 結果一致：
- ✅ 已存在且正確 → 跳過
- ✅ 存在但指向錯 → 自動修復
- ✅ 損壞連結 → 自動重建
- ⚠️ 是普通檔而非 symlink → 警告，不覆蓋

### 安全卸載

`--uninstall` 只刪自己建的：
- `~/.claude/skills` 等 symlink → 刪
- `~/.claude/CLAUDE.md` 含 `tree-monstor-loader:DO-NOT-EDIT` marker → 才刪
- `~/.claude/user-notes.md`（你自己建的）→ **不動**
- `~/.agents/tree_monstor/` → 刪

### 排除規則

`.agents/` 副本自動排除：
- `.obsidian/`（Obsidian 設定）
- `.git/`（版本控制）
- `.DS_Store`（macOS 垃圾檔）

---

## 環境變數

| 變數 | 效果 |
|---|---|
| `NO_COLOR=1` | 關掉彩色輸出（[no-color.org](https://no-color.org/) 標準）|
| `HOME` | `--global` 預設目標（正常由系統設定）|

---

## 開發 / 測試

```bash
# 跑全部測試
bats tests/

# 看單一測試
bats tests/install.bats --filter "AC-1"

# 除錯模式（保留探針輸出）
REGRESSION_MODE=true bash install.sh --dry-run --global
```

需要 [bats-core](https://github.com/bats-core/bats-core)：
```bash
brew install bats-core    # macOS
apt install bats          # Debian/Ubuntu
```

---

## 疑難排解

### Q: 出現 "Path exists but is not a symlink"
**原因**：目標路�已被你（或別的工具）建為普通檔/目錄。
**解法**：手動備份並移走後重跑，例如：
```bash
mv ~/.claude/skills ~/.claude/skills.bak
./install.sh --global --agent claude
```

### Q: 修改了 `tree_monstor/AGENTS.md`，agent 還是讀到舊版？
**原因**：某些 agent 會快取文件內容；symlink 本身是即時的。
**解法**：重啟 agent session，或讓 agent 重新讀檔。

### Q: 想完全乾淨卸載
**解法**：
```bash
./install.sh --uninstall
# 再手動確認 ~/.claude、~/.pi、~/.agents 沒�留
```

### Q: 跨平台（Linux / macOS / WSL）？
腳本用純 Bash 相容寫法，macOS（3.2+）和 Linux（4+）皆可跑。Windows 原生不支援（建議 WSL）。

---

## License

Same as parent tree_monstor project.
