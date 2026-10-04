---
name: tree-monstor-install-reference
description: |
  tree_monstor install.sh 的完整安裝參考：全部旗標、安裝後檔案結構、
  設計重點（symlink / 冪等 / 智慧合併 / 安全卸載）、環境變數、開發測試與疑難排解。
  README.md 只保留精簡安裝導覽，細節以本檔為準。
---

# tree_monstor 安裝參考（install.sh）

> 精簡版請看 [README.md](../README.md)；本檔保留全部安裝細節。

- [完整旗標](#完整旗標)
- [安裝後的檔案結構](#安裝後的檔案結構)
- [設計重點](#設計重點)
- [環境變數](#環境變數)
- [開發 / 測試](#開發--測試)
- [疑難排解](#疑難排解)

---

## 完整旗標

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
| `--agent <claude\|pi>` | 只裝給單一 agent（可重複；預設兩個都裝） |
| `--no-agents-dir` | 不裝到 `.agents/` 本機副本 |

### Source（選擇性）

| 旗標 | 說明 |
|---|---|
| `--source <path>` | tree_monstor 源路徑（預設：腳本所在目錄） |

### Actions

| 旗標 | 說明 |
|---|---|
| `--uninstall` | 卸載（只刪腳本自己建的檔案/連結） |
| `--dry-run` | 只印計畫，不實際執行 |

### Claude skills 衝突處理（當 `~/.claude/skills` 已存在時）

| 旗標 | 說明 |
|---|---|
| `--claude-skills-mode <mode>` | 處理 `~/.claude/skills` 已存在時的策略（預設 `merge`） |

可選值：

- `merge`（預設）：逐個 skill symlink 進去，保留你原有的自裝 skills
- `replace`：自動備份現有的 `~/.claude/skills` 為 `~/.claude/skills.bak.<時間戳>`，再建 symlink 覆蓋
- `skip`：完全不動 `~/.claude/skills`，只裝 wrapper + `.pi` + `.agents`

### UX

| 旗標 | 說明 |
|---|---|
| `-y`, `--yes` | 跳過確認（給 CI 用） |
| `-q`, `--quiet` | 安靜模式（只印錯誤） |
| `-h`, `--help` | 顯示說明 |
| `--version` | 顯示版本 |

### Examples

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

```text
~/.claude/
├── CLAUDE.md        ← wrapper，用 @ 引用 tree_monstor 的 AGENTS.md / SOUL.md
├── skills → ~/path/tree_monstor/skills   (symlink)
└── sop/             ← gates.json / gates.schema.json / handbook/*.md（per-file symlinks）

~/.pi/
├── AGENTS.md → ~/path/tree_monstor/AGENTS.md   (symlink)
├── SOUL.md   → ~/path/tree_monstor/SOUL.md     (symlink)
├── skills    → ~/path/tree_monstor/skills      (symlink)
└── sop/      ← 同 ~/.claude/sop/（gates + handbook，per-file symlinks）

~/.agents/tree_monstor/   ← 完整副本（排除 .obsidian/.git/.DS_Store）
├── AGENTS.md
├── SOUL.md
└── skills/...
```

### 專案層安裝（`--local` 或 `--target <path>`）

```text
<project>/
├── .claude/
│   ├── CLAUDE.md
│   ├── skills → <tree_monstor>/skills
│   └── sop/   ← gates + handbook symlinks
├── .pi/
│   ├── AGENTS.md → <tree_monstor>/AGENTS.md
│   ├── SOUL.md   → <tree_monstor>/SOUL.md
│   ├── skills    → <tree_monstor>/skills
│   └── sop/      ← gates + handbook symlinks
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

```text
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
| `NO_COLOR=1` | 關掉彩色輸出（[no-color.org](https://no-color.org/) 標準） |
| `HOME` | `--global` 預設目標（正常由系統設定） |

---

## 開發 / 測試

```bash
# 跑全部測試
bats tests/

# 看單一測試
bats tests/install.bats --filter "AC-1"

# 追 bash 執行流程（真除錯）
bash -x install.sh --dry-run --global
```

需要 [bats-core](https://github.com/bats-core/bats-core)。**請裝釘版 `v1.14.0`**（CI 兩平台用同一個
tag；發行版版本會漂移——apt 的 `bats` 是 1.10、brew 的 `bats-core` 隨更新變動，`@test` 名稱與旗標
行為會跟著變，於是「本機綠、CI 紅」）：

```bash
git clone --branch v1.14.0 --depth 1 https://github.com/bats-core/bats-core.git
sudo ./bats-core/install.sh /usr/local   # macOS 與 Linux 相同
bats --version                           # 應顯示 Bats 1.14.0
```

> 這條由 `tests/env-equivalence.bats` 的 `ENV-EQ-10` 鎖住：本文件與 `CONTRIBUTING.md`
> 都必須教釘版安裝，且不得再出現發行版安裝指令（否則本機就還是漂移來源）。

### 跑全套測試前：建 Jev PoC venv（必需）

`tests/v2.1-jev-poc.bats` 的 100 條裡有 **40 條**要跑 PoC 解譯器（`httpx` + `PyYAML`），其餘 60 條是純靜態
檔案檢查、不需要 venv。這個 venv **不入版控**（`PoC/.gitignore` 有 `.venv/`），clean clone 沒建它時那 40 條
會全紅，而且每一條失敗測試各自印出修復指令（TMO-038 起這 40 條的名單由探針自動列舉，不再硬編）：

```bash
bash skills/regression-guard/PoC/setup-venv.sh        # 有 uv 用 uv，否則 python3 -m venv
```

CI（`.github/workflows/ci.yml`）也在 `bats tests/` 前跑同一支腳本。

> **clean clone（無 venv）總共會紅 44 條**（2026-10-05 實測：`523 ok / 44 not ok`，@ `c686dd4`）：
> - `v2.1-jev-poc.bats` 40 + `poc-clean-clone.bats` 2（CLEAN-POC-f/i，整檔離線重跑也要 venv）
> - `poc-bootstrap.bats` 1（TMO-038 的 CI 契約語意斷言，PyYAML 解 workflow）
> - `env-equivalence.bats` 1（ENV-EQ-7 網路黑洞下的 oracle 子集）。
> 全部都是**紅＋修復指令**（不 skip）；`tests/poc-bootstrap.bats` 那條是刻意取捨：
> 字串比對看不到 trigger／步驟先後／矩陣，而 CI 的執行次序保證了 venv 先建好。

### 環境等價探針（TMO-041）

`tests/env-equivalence.bats`（10 條）守「本機全綠 ≠ CI 全綠」那類假綠，全套現在是 **567 條**：

| 探針 | 守什麼 | 本機需要什麼 |
|------|--------|--------------|
| ENV-EQ-1 | 本機要有 bash 5.x（CI 的 ubuntu 就是 5.x）| macOS：`brew install bash`（沒裝 → 紅＋這行指令，不 skip） |
| ENV-EQ-2 | **每一個**本機可用的 bash 版本都跑一遍 `tests/wiki-cleanup.bats` | 同上（macOS 多一個 5.x 版本要跑） |
| ENV-EQ-3 | PATH shim 真的把 bash 換掉（不然 ENV-EQ-2 是假的） | — |
| ENV-EQ-4 | 空陣列 × `set -u` 行為逐版本量測並印表 | — |
| ENV-EQ-5 | 探針不得寫固定 `/tmp/<name>`（跨 run 殘檔 → 假綠） | `python3` |
| ENV-EQ-6 | 探針不得直接執行 `gh` / `brew`（工具狀態依賴） | `python3` |
| ENV-EQ-7 | oracle 子集在「網路黑洞」下仍全綠（黑洞有 canary） | PoC venv |
| ENV-EQ-8 | `scripts/ci` 護欄腳本自動列舉：不得有孤兒鎖，`--self-test` 必須自己綠 | `python3` |
| ENV-EQ-9 | `@test` 宣告數 == `bats --count`（防「宣告 N／實跑 N-3」；含 CJK 名稱 canary） | bats |
| ENV-EQ-10 | 本機安裝文件必須教釘版 bats（只鎖 CI 一側＝本機仍漂移） | — |
| （另檔）SSG-1..3 | `tests/skill-size-guard.bats`：每個 `SKILL.md` ≤150 行＋CI 必須呼叫自動列舉腳本 | — |

兩個靜態鎖的實作在 `scripts/ci/lint-probe-tmp-paths.py` 與 `scripts/ci/lint-probe-tools.py`，
都可單獨跑（`--self-test` 驗抽取器本身）。寫檔請用 `$BATS_TEST_TMPDIR`；真的只是「資料引用」
（例如壞值清單、故意不存在的路徑）就在該行標 `TMP-OK` 就地豁免——反向鎖會擋「拿標記當萬用豁免」。

CI 的 bats-core 已釘版：兩個 runner 都 `git clone --branch v1.14.0`＋`install.sh /usr/local`
（apt 的 bats 與 brew 的 bats-core 版本會漂移，`@test` 名稱／旗標行為跟著變），契約由
`tests/poc-bootstrap.bats` 的 PyYAML 語意斷言鎖住（兩平台同 tag、`>= v1.14.0`）。

### 可選：dav-wiki 媒體提取的測試依賴

`tests/wiki-extract-media.bats` 有一部分案例需要額外工具；**缺工具時這些探針會直接失敗**（不會 skip），
因為它們是產品承諾的功能，不是可選裝飾：

| 工具 | 用在哪 | 安裝 |
| --- | --- | --- |
| `pdfimages` / `pdftotext`（poppler） | AC-E1/E2/E9–E12/E15–E17/E19–E22（PDF） | `brew install poppler` ／ `apt install poppler-utils` |
| `pandoc` | AC-E3/E4（DOCX） | `brew install pandoc` ／ `apt install pandoc` |
| `python-pptx` | AC-E5/E6/E21（PPTX） | `pip install python-pptx` |
| `tesseract` | OCR 補強（FR-2.2.3，非阻塞） | `brew install tesseract` ／ `apt install tesseract-ocr` |

> 若本機沒有 poppler，PDF 相關探針會以 `exit 4` 失敗並附安裝提示 — 這是刻意設計（見上方說明）。

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
