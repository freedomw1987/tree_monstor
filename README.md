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

### Claude skills 衝突處理（當 `~/.claude/skills` 已存在時）

| 旗標 | 說明 |
|---|---|
| `--claude-skills-mode <mode>` | 處理 `~/.claude/skills` 已存在時的策略（預設 `merge`）|

可選值：
- `merge`（預設）：逐個 skill symlink 進去，保留你原有的自裝 skills
- `replace`：自動備份現有的 `~/.claude/skills` 為 `~/.claude/skills.bak.<時間戳>`，再建 symlink 覆蓋
- `skip`：完全不動 `~/.claude/skills`，只裝 wrapper + `.pi` + `.agents`

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
- ⚠️ 是普通檔/目錄而非 symlink → 見下方「智慧合併」

### 智慧合併（Merge into existing skills）

當 `~/.claude/skills` **已經是一個真實目錄**（你自裝的 69 個 skills），預設 `merge` 模式會：
- 對每個 tree_monstor skill 建立一個 per-skill symlink
- 你原有的自裝 skills **完全保留**
- 命名衝突的 skill **跳過並警告**，不覆蓋

例如：
```
~/.claude/skills/
├── autoplan/           ← 你的現有 skill（保留）
├── benchmark/          ← 你的現有 skill（保留）
├── dav-planner  ->     ~/Sites/localhost/tree_monstor/skills/dav-planner  ← 新合併
├── dav-designer ->     ~/Sites/localhost/tree_monstor/skills/dav-designer ← 新合併
└── ...
```

如果你要覆蓋或跳過，見 `--claude-skills-mode` 旗標。

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

### Q: `~/.claude/skills` 已經裝了 69 個 skills，安裝會覆蓋嗎？

**答案**：**不會**。預設 `merge` 模式會自動合併：
- 在 `~/.claude/skills/` 內對每個 tree_monstor skill 建立 **per-skill symlink**
- 你原有的自裝 skills **完全保留**
- 命名衝突時**跳過並警告**，不覆蓋

如果你想要強制覆蓋（破壞式）：
```bash
./install.sh --claude-skills-mode=replace
# 原 skills 會自動備份為 ~/.claude/skills.bak.YYYYMMDD-HHMMSS
```

### Q: 出現 "Path exists but is not a symlink"

**原因**：你的 `~/.claude/skills` 是真實目錄（不是 symlink），且你跑的是**舊版** install.sh（v0.1.0 之前），或顯式指定了 `--claude-skills-mode=replace` 時碰到邊緣情況。

**解法**：
- 確認 install.sh 版本：`./install.sh --version`（v0.1.0+ 預設 merge 模式）
- 顯式指定 merge：`./install.sh --claude-skills-mode=merge`
- 或手動處理：`mv ~/.claude/skills ~/.claude/skills.bak && ./install.sh --global --agent claude`

### Q: 有很多 `~/.claude/skills.bak.YYYYMMDD-HHMMSS` 目錄怎麼辦？

**原因**：每次 `--claude-skills-mode=replace` 都會建一個備份，install.sh 不會自動清除。

**解法**：手動確認後清理
```bash
ls -la ~/.claude/skills.bak.* | head -5        # 看備份
rm -rf ~/.claude/skills.bak.YYYYMMDD-HHMMSS   # 刪除特定備份
```

> TODO：未來會加 `--claude-skills-clean-backups` 自動清理（TD-013）。

### Q: 修改了 `tree_monstor/AGENTS.md`，agent 還是讀到舊版？

**原因**：某些 agent 會快取文件內容；symlink 本身是即時的。

**解法**：重啟 agent session，或讓 agent 重新讀檔。

### Q: 想完全乾淨卸載

**解法**：
```bash
./install.sh --uninstall
# 再手動確認 ~/.claude、~/.pi、~/.agents 沒有殘留
```

### Q: 跨平台（Linux / macOS / WSL）？
腳本用純 Bash 相容寫法，macOS（3.2+）和 Linux（4+）皆可跑。Windows 原生不支援（建議 WSL）。

---

## License

Same as parent tree_monstor project.
