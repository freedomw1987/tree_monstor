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

skill 自帶探針（`skills/*/tests/*.bats`，3 條）**不在** `bats tests/` 內，要自己跑；它們預設掃
`~/.pi/agent/skills`，在 repo 內請用覆寫變數指向本 repo（否則會 fail-closed 紅）：

```bash
SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats
```

CI（`.github/workflows/ci.yml`）也在 `bats tests/` 前跑同一支腳本。

> **clean clone（無 venv）總共會紅 43 條**（2026-10-05 實測（TMO-040 後）：`542 ok / 43 not ok`，套件共 585 條。
> 43 ＝ `v2.1-jev-poc.bats` 40 ＋ `poc-clean-clone.bats` 2（CLEAN-POC-f/i）＋ `env-equivalence.bats` 1（ENV-EQ-7）。
> 較早量測：`532 ok / 44 not ok` @ `f600385` 之後（576 條；當時多 1 條 = `poc-bootstrap.bats` 的 PyYAML 斷言，
> 因該機 `python3` 無 PyYAML；本機 python3 剛好有 → 現在是 43。缺 PyYAML 的機器仍會是 44）：
> - `v2.1-jev-poc.bats` 40
> - `poc-clean-clone.bats` 2（CLEAN-POC-f/i，整檔離線重跑也要 venv）
> - `env-equivalence.bats` 1（ENV-EQ-7 網路黑洞下的 oracle 子集）
> - `poc-bootstrap.bats` 1（**只在缺 PyYAML 的機器上紅**：TMO-038 的 CI 契約語意斷言用 PyYAML 解 workflow）
> 全部都是**紅＋修復指令**（不 skip）；`tests/poc-bootstrap.bats` 那條是刻意取捨：
> 字串比對看不到 trigger／步驟先後／矩陣，而 CI 的執行次序保證了 venv 先建好。

### 環境等價探針（TMO-041）

`tests/env-equivalence.bats`（19 條）守「本機全綠 ≠ CI 全綠」那類假綠。`bats tests/` 現在是 **585 條**；
CI 另跑 **3 條** skill 自帶探針（`skills/*/tests/*.bats`，TMO-047 起），所以 CI 實際執行 **588 條**：

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
| ENV-EQ-11 | skill 自帶探針（`skills/*/tests/*.bats`，≥2 檔）存在且 CI 真跑：override 下逐檔實跑綠、不得 `skip`、每檔須認 override；空 root 必紅（防空過）；`ci.yml` 恰好一步 | bats |
| ENV-EQ-12 | 全 repo `.bats` 不得有 orphan（只允許 `tests/` 頂層與 `skills/*/tests/`；**精確 regex**，因 CI 的 `bats tests/` 非遞迴）＋列舉下限 ≥40。列舉用 `find`（才抓得到未追蹤檔），再以 `git check-ignore -q` **逐檔**排除 gitignored 項（依 gitignore 事實，非硬編清單；`git check-ignore` 預設看 index → **被追蹤的檔永不排除**，故 gitignored 樹內若有被追蹤 `.bats` 仍會被檢查） | find + git check-ignore + bash regex |
| ENV-EQ-13 | 每個 shell 檔須宣告 shell（shebang 或 `# shellcheck shell=`）＋ Gate 2 指令須自我列舉且含 `*.sh`／`*.bash`＋下限 ≥20 | git |
| ENV-EQ-14 | 每個被追蹤 `.py` 須 `ast.parse` 通過、`.json` 須 `json.load` 通過（stdlib、不寫 `__pycache__`）＋下限 ≥25／≥5 | python3 |
| ENV-EQ-15 | `.bats` 不得有**下列字面**的空過斷言：`[ true ]`／`[[ true ]]`／單行 `true`／`:`（先剝行尾註解再比對）＋下限 ≥40。**注意**：`\|\| true`、`[[ 1 -eq 1 ]]` 等變體**不在鎖內**（實測 `.bats` 內有 49 處 `\|\| true`，硬鎖會誤殺） | grep + sed |
| ENV-EQ-16 | 每個被追蹤文字檔須以換行結尾（binary 以 NUL 嗅探排除）＋下限 ≥100 | python3 |
| ENV-EQ-17 | shell／CI 檔不得有「`$var` 緊接非 ASCII 字元」——bash 3.2 + UTF-8 locale 會把該字元首位元組吞進變數名（`$f（` → 展開 `$f\xef`）。實作：`scripts/ci/lint-shell-var-nonascii.py` | python3 + git |
| ENV-EQ-18 | CI `test` job 必須跑**自我列舉**的 shellcheck，且 `Verify bash syntax` 不得回頭用硬編子集 glob；這兩步不得有 `\|\| true`／`continue-on-error` | git + awk |
| ENV-EQ-19 | `scripts/ci/*.sh` 在**每一個本機可用** bash 版本 × 每支腳本（組合數必須全部跑到）＋UTF-8 locale 下都必須 rc=0 且有輸出 | bash 多版本 |
| （另檔）SSG-1..3 | `tests/skill-size-guard.bats`：每個 `SKILL.md` ≤150 行＋CI 必須呼叫自動列舉腳本 | — |

三個靜態鎖的實作在 `scripts/ci/lint-probe-tmp-paths.py`、`scripts/ci/lint-probe-tools.py` 與
`scripts/ci/lint-shell-var-nonascii.py`，都可單獨跑（`--self-test` 驗抽取器本身）。寫檔請用
`$BATS_TEST_TMPDIR`；真的只是「資料引用」（例如壞值清單、故意不存在的路徑）就在該行標 `TMP-OK`
就地豁免——反向鎖會擋「拿標記當萬用豁免」。

> ⚠️ **`git ls-files` 型鎖的已知盲點**：`ENV-EQ-14`／`16`／`17` 這類以 `git ls-files` 列舉的鎖，
> **看不到「還沒 `git add` 的新檔」**。本輪就吃過一次：新鎖檔本身缺檔尾換行，本機全綠、
> 一進 clean clone（已追蹤）才被 `ENV-EQ-16` 咬到。新增檔案請先 `git add -N`（intent-to-add）
> 或直接 `git add` 後再跑一次套件。

CI 的 bats-core 已釘版：兩個 runner 都 `git clone --branch v1.14.0`＋`install.sh /usr/local`
（apt 的 bats 與 brew 的 bats-core 版本會漂移，`@test` 名稱／旗標行為跟著變），契約由
`tests/poc-bootstrap.bats` 的 PyYAML 語意斷言鎖住（兩平台同 tag、`>= v1.14.0`）。

2026-10-05 CI 首跑後另修三件事（見 `ENV-EQ-17/18/19`）：clone 位置改 `$RUNNER_TEMP`
（過去 clone 進工作區，會被 `ENV-EQ-12` 當成 ~250 個孤兒 `.bats`）、macOS leg 改裝 bash 5
（原本 `/bin/bash` 3.2 會讓 bats 1.14.0 的 test-name 編碼壞掉、**靜默丟掉 31 條**非 ASCII 名稱的測試）、
CI 補上自我列舉的 shellcheck。

> **⚠️ shellcheck 版本漂移（2026-10-05 實測，已發生過一次）**：本機 **0.11.0 已不再報 SC2002**，
> 而 ubuntu apt 的 **0.9.x 仍會報** → 同一份碼「本機 Gate 2 綠、CI 紅」是真的會發生
> （實例：`wiki-ocr.sh` 的 `cat file | tr`，已改成 `tr < file`）。CI 的 shellcheck 步驟會先印
> `shellcheck --version`（由 ENV-EQ-18 鎖住），遇到紅燈請先看版本再判定。
>
> **⚠️ macOS PATH 教訓（同輪自傷，已修）**：把整個 `$(brew --prefix)/bin` 前置到 `$GITHUB_PATH`
> 會讓後續步驟的 `python3` 變成 homebrew python（沒裝 `python-pptx`）→ PPTX 探針 AC-E5／E6／E21 紅。
> 現在只把 **bash 一個符號連結**放進 `$HOME/.ci-bin` 再前置，副作用最小。
bash 3.2 的覆蓋改由本機 `ENV-EQ-19` 接手（逐版本實跑 `scripts/ci/*.sh`）。
**⚠️ 但這條只在「本機真的裝了 3.2」時有效**（本機 macOS 的 `/bin/bash` 就是 3.2，故 5.3.20＋3.2.57
兩個版本都跑到）；**CI 兩 leg 已無 3.2**（ubuntu 是 5.x、macOS 已改用 brew bash 5），所以
「CI 也能擋 3.2 專屬 bug」**不成立**——那是換取「macOS leg 跑得完 576 條」的必要取捨，已在此揭露。

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
