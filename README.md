# tree_monstor

[![CI](https://github.com/freedomw1987/tree_monstor/actions/workflows/ci.yml/badge.svg)](https://github.com/freedomw1987/tree_monstor/actions/workflows/ci.yml)

> **CI 係偵測器，唔係閘**（TMO-084，2026-10-27）：本 repo 係平時自用嘅技能庫，閘喺本機 ——
> 探針全綠 ＋ lint 0 issue ＋ mutant 全死 ＋ Reviewer 二審（V03：只限代碼／契約／探針改動；純 markdown 改動不適用）。一條指令跑齊：
> `bash scripts/check-all.sh`。CI 仍然會跑（跨環境偵測用），但**唔阻 merge**。
>
> **dav-developer 嘅 CI 完全唔喺 GitHub 跑**（2026-10-27 用戶決策）：改用本機 runner
> `bash skills/dav-jev-oracle/PoC/run_ci.sh all`（`probes`／`pipeline`／`matrix`／`cleanup-scan`）。

`tree_monstor` 是給 AI coding agents（Claude Code、Pi Agent、Qoder 等）的**工作 SOP + skills**。
本專案嘅專屬術語統一喺 [`docs/glossary_list.md`](docs/glossary_list.md)：新寫嘅文件用表內「術語」欄嘅寫法，
唔用「勿用寫法」清單入面嘅講法；發現新術語 → A-Z 插入同一張表。
`install.sh` 把它 expose 到 agent 的讀取路徑（全域或專案層），以 symlink 為主，改源檔即時生效。

## Quick Start

```bash
chmod +x install.sh        # 一次性（如果檔案沒執行權限）
./install.sh               # 全域裝給 Claude Code + Pi Agent + Qoder
```

## 本機開發前置（想在這個 repo 跑測試才需要）

```bash
brew install bash                                # macOS 內建 /bin/bash 是 3.2；測試要 5.x（ubuntu CI 即是）
bash skills/dav-jev-oracle/PoC/setup-venv.sh   # 建 PoC/.venv（v2.1-jev-poc.bats 的 40 條需要）
```

少這兩步時本機會**大幅報紅且難以看懂**：缺 venv ⇒ 43 條紅；用 bash 3.2 ⇒ 部分 CJK 測試名被
**靜默丟棄**（結尾會出現 `Executed N instead of expected M`，跑到的條數少於預期），
而 CI 全綠 —— 最容易被誤判成「程式壞了」。兩者都不 skip，每條失敗會自己印出修復指令。

bats 另外要**釘版 `v1.14.0`**（發行版會漂移）。完整前置、clean clone 的預期紅燈數、
單獨跑某個靜態鎖 → [docs/install-reference.md 開發 / 測試](docs/install-reference.md#開發--測試)。

## Usage

```bash
./install.sh [options]
```

| 旗標 | 說明 |
|---|---|
| `--global` | 裝到 `$HOME`（**預設**） |
| `--local` | 裝到當前目錄 |
| `--target <path>` | 裝到指定路徑 |
| `--agent <claude\|pi\|qoder\|all>` | 只裝給指定 agent（可重複；預設全部都裝） |
| `--uninstall` | 卸載（只刪腳本自己建的檔案/連結） |
| `--dry-run` | 只印計畫，不實際執行 |
| `--claude-skills-mode <merge\|replace\|skip>` | `~/.claude/skills` 已存在時的策略（預設 `merge`，保留你原有 skills） |
| `-y` / `-q` | 跳過確認 / 安靜模式 |

常用範例：

```bash
./install.sh --agent claude     # 只裝 Claude Code
./install.sh --agent qoder      # 只裝 Qoder
./install.sh --local            # 裝到當前專案
./install.sh --dry-run          # 先預覽會做什麼
./install.sh --uninstall        # 卸載全域安裝
```

> **Qoder 使用者注意**：Qoder 的 **IDE 只讀專案層 `AGENTS.md`**（在工作區內搜尋 `**/AGENTS.md`），
> 讀不到使用者層的 `~/.qoder/AGENTS.md`；但 **Qoder CLI 會讀 `~/.qoder/AGENTS.md`**。
> 所以要給 IDE 用請跑 `./install.sh --local`（或 `--target <專案>`）；
> skills 兩種 scope 都能用（`~/.qoder/skills/` / `<專案>/.qoder/skills/`）。
> 完整旗標（`--no-agents-dir`、`--source`、`--version` 等）與所有細節 →
> [docs/install-reference.md](docs/install-reference.md)

## 行為準則與流程

安裝後 agent 會讀到 [`AGENTS.md`](AGENTS.md) —— **它只講「你是誰、怎麼跟你合作」**：

| 章節 | 內容 |
|---|---|
| §1 萬事原則 | 行為基礎：誠實、負責、有承擔、Think Big |
| §1.5 行為紀律 | V01 一次一問、V02 方案必標推薦、V03 改規範按內容分流（純 markdown 自查行數上限；代碼／契約／探針走 Reviewer 二審） |

**流程與 Gate 不在 `AGENTS.md`** —— 它們寫在**各自的 skill** 裡，被觸發時才讀：

| Gate | 承載 skill |
|---|---|
| Gate 1 TDD / Gate 2 lint | [skills/dav-developer](skills/dav-developer/) |
| Gate 3 regression | [skills/dav-developer](skills/dav-developer/) |
| Gate 4 reviewer | [skills/dav-developer](skills/dav-developer/) |
| Gate 4.5 需求對帳 | [skills/dav-reconciler](skills/dav-reconciler/) |

**沒有指定要用哪道 Gate 時，預設就是直接做**（不跑流程、不建 backlog、不寫交付摘要）。

深入閱讀：

- SOP handbook 全文：[docs/sop/handbook/](docs/sop/handbook/)（按需查，非必讀）
- Gate 定義（機器可讀副本；定義本體在各自的 skill）：[docs/sop/gates.json](docs/sop/gates.json)
- 安裝後會以 symlink 出現在 `~/.pi/sop/` 與 `~/.claude/sop/`（gates + handbook）

## Skills

13 個 skill，隨安裝一起 expose；每個的完整規則在 `skills/<name>/SKILL.md`。

| Skill | 一句話 |
|---|---|
| [`dav-planner`](skills/dav-planner/SKILL.md) | §2.1 規劃：釐清背景/目的/驗收條件，拆 Backlog（含 INVEST AC） |
| [`dav-designer`](skills/dav-designer/SKILL.md) | §2.2 設計：DESIGN.md、system-design.md、PRD、互動 HTML 原型 |
| [`dav-developer`](skills/dav-developer/SKILL.md) | Gate 1：依 backlog 先寫測試，紅後綠 |
| [`dav-developer`](skills/dav-developer/SKILL.md) | Gate 3：埋探針，`REGRESSION_MODE` 自動回歸驗證 |
| [`dav-developer`](skills/dav-developer/SKILL.md) | Gate 4：dev / checker 雙 subagent 循環校驗 |
| **反省**（併入 [`dav-submitter`](skills/dav-submitter/SKILL.md) Step 3.5）| US / Sprint / Module 六維度反思 |
| [`dav-submitter`](skills/dav-submitter/SKILL.md) | §2.5 提交：交付摘要 + Markdown 詳錄 |
| [`dav-reconciler`](skills/dav-reconciler/SKILL.md) | Gate 4.5 需求對帳：獨立 subagent 拿需求錨點逐條比對成果；未對上不得宣告完成 |
| [`dav-wiki`](skills/dav-wiki/SKILL.md) | 文件知識庫化：PDF / 網頁 / OCR / 字幕 → Markdown |
| [`dav-trust`](skills/dav-trust/SKILL.md) | 信任模式：給大目標 + deadline 後自主跑完 SOP 執行段（執行 → 反省 → 提交；規劃 / 設計須啟動前完成；支援中斷續跑 / 用戶叫停）|
| [`ask-me`](skills/ask-me/SKILL.md) | 逐題確認 trust 期間的待決擔憂，回寫 backlog |
| [`dav-skill-creater`](skills/dav-skill-creater/SKILL.md) | 提煉 / 修改 skill，守住 4 段結構、文檔行數限制與 150 行上限 |
| [`pptx-slim`](skills/pptx-slim/SKILL.md) | PPTX 就地減重：轉碼影片／重壓圖片、只換媒體重打包、四關驗證（含畫質關） |

## 進階

安裝後的檔案結構、設計重點（symlink / 冪等 / 智慧合併 / 安全卸載）、環境變數、疑難排解、開發測試：
→ [docs/install-reference.md](docs/install-reference.md)

## License

Same as parent tree_monstor project.
