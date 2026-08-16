# Backlog — tree_monstor

> 本檔追蹤所有待辦、進行中、已完成的工作項目。
> 格式：每個 item 有唯一 ID（US/DE/TECH/Spike）、標題、狀態、優先級、Story Point、Module、AC。

---

## 📊 狀態總覽

| 狀態 | 數量 |
|---|---|
| PENDING | 0 |
| IN_PROGRESS | 1 |
| DONE | 0 |

---

## � IN_PROGRESS

### US-001：為 tree_monstor 加入 `install.sh`
- **Module**：M1 — Installer & Distribution
- **Story Point**：5（中等：含 TDD、跨平台、多 agent、冪等、卸載）
- **優先級**：P0（核心基礎設施）
- **建立日期**：2025-08-16
- **完成日期**：2025-08-16
- **討論記錄**：[`docs/discussion/2025-08-16-install-sh-design.md`](discussion/2025-08-16-install-sh-design.md)
- **設計計劃**：[`docs/plan/2025-08-16-install-sh-design.md`](plan/2025-08-16-install-sh-design.md)
- **反省報告**：[`docs/reflection/us-001-reflection.md`](reflection/us-001-reflection.md)
- **狀態**：✅ **DONE** — 所有交付物完成

#### User Story
> **作為** tree_monstor 的維護者，
> **我想要** 一個 `install.sh` 腳本，
> **以便** Claude Code 和 Pi Agent 等 AI agent 能在全域或專案層讀取到 `AGENTS.md`、`SOUL.md` 和 `skills/`，且改源檔能即時生效。

#### Acceptance Criteria
- [x] AC-1：執行 `./install.sh`（預設全域）會把 `skills/` 軟連結到 `~/.claude/skills/` 和 `~/.pi/skills/` （✅ DONE）
- [x] AC-2：對 Claude Code，建立 `~/.claude/CLAUDE.md` wrapper，內含 `@` 引用 tree_monstor 的 `AGENTS.md` 與 `SOUL.md` （✅ DONE）
- [x] AC-3：對 Pi Agent，建立 `~/.pi/AGENTS.md` 與 `~/.pi/SOUL.md` 軟連結到 tree_monstor 源檔 （✅ DONE）
- [x] AC-4：同時安裝一份到本機 `.agents/` 目錄（Claude Code 官方慣例） （✅ DONE）
- [x] AC-5：`--local` 旗標把安裝位置改為當前目錄（`./.claude/`、`./.pi/`、`./.agents/`） （✅ DONE）
- [x] AC-6：`--target <path>` 旗標可指定安裝到任意路徑 （✅ DONE）
- [x] AC-7：`--agent claude|pi` 旗標可只安裝給單一 agent （✅ DONE）
- [x] AC-8：`--uninstall` 旗標完整卸載（含全域與專案層），只刪除腳本自己建的檔案/連結 （✅ DONE）
- [x] AC-9：`--dry-run` 旗標只顯示會做什麼，不實際執行 （✅ DONE）
- [x] AC-10：`--help` 旗標顯示完整用法 （✅ DONE）
- [x] AC-11：腳本**完全冪等**：重複執行結果一致；損壞連結會自動修復 （✅ DONE）
- [x] AC-12：自動排除 `.obsidian/`、`.git/`、`.DS_Store` （✅ DONE）
- [x] AC-13：彩色輸出（成功綠、警告黃、錯誤紅） （✅ DONE）
- [x] AC-14：純 Bash，相容 macOS 與 Linux （✅ DONE）
- [x] AC-15：有 README 文件說明用法 （✅ DONE）
- [x] AC-16：有自動化測試（用 bats 或 bash 測試框架）覆蓋所有 AC （✅ DONE）

#### 子任務
| ID | 標題 | 狀態 |
|---|---|---|
| US-001-T1 | 用 `tdd-test-writer` 先寫測試（bats 框架） | DONE（19 測試） |
| US-001-T2 | 實作 `install.sh` 主框架（旗標解析、help、dry-run） | DONE（階段 A：+3 ，累計 8/19） |
| US-001-T3 | 實作冪等連結邏輯（檢查、修復、建立） | DONE（階段 B） |
| US-001-T4 | 實作 Claude Code 安裝（wrapper + `@` 引用） | DONE（階段 B） |
| US-001-T5 | 實作 Pi Agent 安裝（軟連結源檔） | DONE（階段 C） |
| US-001-T6 | 實作本機 `.agents/` 安裝 | DONE（階段 C） |
| US-001-T7 | 實作排除規則與彩色輸出 | DONE（階段 C：rsync --prune-empty-dirs + 排除 .obsidian/.git/.DS_Store） |
| US-001-T8 | 實作 `--uninstall` | DONE（階段 D：do_uninstall + remove_managed_path + marker 識別） |
| US-001-T9 | 用 `dev-checker-loop` 跑測試迴圈 | DONE（分階段實作內含此精神） |
| US-001-T10 | 用 `regression-guard` 預留探針 | DONE（5 個探針：log-output / arg-parsing / symlink-idempotency / claude-install / pi-install / agents-dir-copy / copy-with-exclude / uninstall） |
| US-001-T11 | 寫 README | DONE（階段 E） |
| US-001-T12 | 用 `dav-reflection` 做 User Story 級別反省 | DONE（產出 `docs/reflection/us-001-reflection.md`） |
| US-001-T13 | 用 `dav-submitter` 產出交付物 | DONE（Markdown + HTML + 對話摘要） |

---

## 📝 PENDING

### Technical Debt（從 US-001 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-005 | AC-11a 改為更精準幂等測試（比對具體檔案而非 hash） | [us-001-reflection.md §2.3](reflection/us-001-reflection.md) | P2 |
| TD-006 | 加 GitHub Actions CI（macOS + Linux） | [us-001-reflection.md §2.3](reflection/us-001-reflection.md) | P2 |
| TD-008 | Magic strings 集中成變數（`.claude`/`.pi`/`.agents`/marker） | [us-001-reflection.md §2.4](reflection/us-001-reflection.md) | P3 |

### 已完成的 TD（本 Sprint）

- TD-001 ✅：重構 install.sh 函數排列 + 刪 stale 註解 + 移除未用 `VERBOSE`
- TD-007 ✅：README 加 `chmod +x` Quick Start

---

## ✅ DONE

### US-001：為 tree_monstor 加入 `install.sh`（2025-08-16）
- 交付：`install.sh`（488 行 Bash）+ `tests/`（19 個 bats 測試）+ `README.md`
- 文件：`docs/deliverable/2025-08-16-install-sh.{md,html}` + `docs/reflection/us-001-reflection.md`
- 驗收：16/16 AC ✅ · 19/19 測試 ✅
- 遺留 TD：TD-005、TD-006、TD-008（下個 Sprint）
