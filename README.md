# tree_monstor

[![CI](https://github.com/freedomw1987/tree_monstor/actions/workflows/ci.yml/badge.svg)](https://github.com/freedomw1987/tree_monstor/actions/workflows/ci.yml)

`tree_monstor` 是給 AI coding agents（Claude Code、Pi Agent 等）的**工作 SOP + skills**。
`install.sh` 把它 expose 到 agent 的讀取路徑（全域或專案層），以 symlink 為主，改源檔即時生效。

## Quick Start

```bash
chmod +x install.sh        # 一次性（如果檔案沒執行權限）
./install.sh               # 全域裝給 Claude Code + Pi Agent
```

## 本機開發前置（想在這個 repo 跑測試才需要）

```bash
brew install bash                                # macOS 內建 /bin/bash 是 3.2；測試要 5.x（ubuntu CI 即是）
bash skills/regression-guard/PoC/setup-venv.sh   # 建 PoC/.venv（v2.1-jev-poc.bats 的 40 條需要）
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
| `--agent <claude\|pi>` | 只裝給單一 agent（可重複；預設兩個都裝） |
| `--uninstall` | 卸載（只刪腳本自己建的檔案/連結） |
| `--dry-run` | 只印計畫，不實際執行 |
| `--claude-skills-mode <merge\|replace\|skip>` | `~/.claude/skills` 已存在時的策略（預設 `merge`，保留你原有 skills） |
| `-y` / `-q` | 跳過確認 / 安靜模式 |

常用範例：

```bash
./install.sh --agent claude     # 只裝 Claude Code
./install.sh --local            # 裝到當前專案
./install.sh --dry-run          # 先預覽會做什麼
./install.sh --uninstall        # 卸載全域安裝
```

> 完整旗標（`--no-agents-dir`、`--source`、`--version` 等）與所有細節 →
> [docs/install-reference.md](docs/install-reference.md)

## 工作流程：看 AGENTS.md

安裝後 agent 會讀到 [`AGENTS.md`](AGENTS.md)，那是整套 SOP 的入口：

| 章節 | 內容 |
|---|---|
| §1 萬事原則 | 行為基礎：誠實、負責、有承擔、Think Big |
| §1.5 提問紀律 | V01 一次一問、V02 方案必標推薦、V03 SOP 修改走 Reviewer 二審 |
| §2.0 任務分類 | 開發任務走完整 SOP；一般任務走 §2.6 輕量流程 |
| §2.1 – §2.5 | 規劃 → 設計 → 執行（4 Gate）→ 反省 → 提交 |
| §2.3 | 4 Gate 速查：TDD / lint / regression / reviewer |
| §2.7 | 違規回報（fail-fast 防線） |

深入閱讀：

- Handbook 全文：[docs/sop/handbook/](docs/sop/handbook/)
- Gate 定義（single source of truth）：[docs/sop/gates.json](docs/sop/gates.json)
- 安裝後會以 symlink 出現在 `~/.pi/sop/` 與 `~/.claude/sop/`（gates + handbook）

## Skills

11 個 skill，隨安裝一起 expose；每個的完整規則在 `skills/<name>/SKILL.md`。

| Skill | 一句話 |
|---|---|
| [`dav-planner`](skills/dav-planner/SKILL.md) | §2.1 規劃：釐清背景/目的/驗收標準，拆 Backlog（含 INVEST AC） |
| [`dav-designer`](skills/dav-designer/SKILL.md) | §2.2 設計：DESIGN.md、system-design.md、PRD、互動 HTML 原型 |
| [`tdd-test-writer`](skills/tdd-test-writer/SKILL.md) | Gate 1：依 backlog 先寫測試，紅後綠 |
| [`regression-guard`](skills/regression-guard/SKILL.md) | Gate 3：埋探針，`REGRESSION_MODE` 自動回歸驗證 |
| [`dev-checker-loop`](skills/dev-checker-loop/SKILL.md) | Gate 4：dev / checker 雙 subagent 循環校驗 |
| [`dav-reflection`](skills/dav-reflection/SKILL.md) | §2.4 反省：US / Sprint / Module 六維度反思 |
| [`dav-submitter`](skills/dav-submitter/SKILL.md) | §2.5 提交：交付摘要 + Markdown 詳錄 |
| [`dav-wiki`](skills/dav-wiki/SKILL.md) | 文件知識庫化：PDF / 網頁 / OCR / 字幕 → Markdown |
| [`dav-trust`](skills/dav-trust/SKILL.md) | 信任模式：給大目標 + deadline 後自主跑完 5 階段 |
| [`ask-me`](skills/ask-me/SKILL.md) | 逐題確認 trust 期間的待決擔憂，回寫 backlog |
| [`dav-skill-creater`](skills/dav-skill-creater/SKILL.md) | 提煉 / 修改 skill，守住 5 段結構與 150 行上限 |

## 進階

安裝後的檔案結構、設計重點（symlink / 冪等 / 智慧合併 / 安全卸載）、環境變數、疑難排解、開發測試：
→ [docs/install-reference.md](docs/install-reference.md)

## License

Same as parent tree_monstor project.
