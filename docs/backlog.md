# Backlog — tree_monstor

> 本檔追蹤所有待辦、進行中、已完成的工作項目。
> 格式：每個 item 有唯一 ID（US/DE/TECH/Spike）、標題、狀態、優先級、Story Point、Module、AC。

---

## 📊 狀態總覽

| 狀態 | 數量 |
|---|---|
| PENDING | 0 (DE-001 已完成) |
| IN_PROGRESS | 0 |
| DONE | 2 (US-001 / DE-001) + Sprint 01 反省 |
| 登記 TD | 8 個 PENDING (TD-005/006/008/009/010/011/012/013) |

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

---

## 📝 PENDING

### DE-001：installer 拒絕在 `~/.claude/skills` 已存在的環境中安裝（2025-08-16）
- **Module**：M1 — Installer & Distribution
- **Story Point**：3（中等：需重構 `install_claude` 邏輯、新增 merge 模式、加測試）
- **優先級**：P0（阻塞全域安裝的核心場景）
- **建立日期**：2025-08-16
- **討論記錄**：[`docs/discussion/2025-08-16-install-sh-merge.md`](discussion/2025-08-16-install-sh-merge.md)
- **設計計劃**：[`docs/plan/2025-08-16-install-sh-merge.md`](plan/2025-08-16-install-sh-merge.md)
- **狀態**：🟡 **PENDING** — 等待用戶確認計劃後開始執行

#### Defect 描述
> **情境**：當 `~/.claude/skills` 已是一個真實目錄（用戶自行安裝了 69 個 skills），installer 會中止並顯示：
> `[✗] Path exists but is not a symlink: /Users/davidchu/.claude/skills`
> `[✗] Refusing to overwrite. Move it aside and re-run.`
>
> **後果**：全域安裝（`./install.sh` 不帶任何參數）直接失敗，無法完成。
>
> **根因**：`ensure_symlink()` 對「存在但不是 symlink」的目標直接拒絕，沒有提供「合併」選項。

#### 驗收標準 (AC)
- [ ] AC-1：當 `~/.claude/skills` 是真實目錄時，installer 自動進入 **merge 模式**（不報錯）
- [ ] AC-2：Merge 模式預設行為：對 `tree_monstor/skills/` 中每個 skill 建立一個 symlink 到 `~/.claude/skills/<skill-name>`（命名不衝突時）
- [ ] AC-3：當 `~/.claude/skills/<skill-name>` 已存在（用戶自有同名 skill）時，**跳過**但列出警告（不覆蓋）
- [ ] AC-4：新增 `--claude-skills-mode {merge|replace|skip}` 旗標覆寫預設（merge=預設，replace=原行為的破壞式覆蓋，skip=不安裝 Claude skills）
- [ ] AC-5：對 `~/.claude/CLAUDE.md` 處理：若已是 symlink 且指向非 tree_monstor 源頭，自動解除並重寫為標準 wrapper（用 `@` 引用新路徑）
- [ ] AC-6：對 `~/.pi/`（全新空的目錄）按原計劃執行 symlink
- [ ] AC-7：對 `.agents/tree_monstor/` copy 仍按原計劃執行
- [ ] AC-8：所有新邏輯有對應的 bats 測試（≥ 5 個新測試案例）
- [ ] AC-9：`./tests/install.bats` 全部通過（舊 19 + 新 ≥ 5）
- [ ] AC-10：dry-run 模式正確顯示 merge 行為（不實際執行）

---

## 📝 PENDING

### Technical Debt（從 US-001 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-005 | AC-11a 改為更精準幂等測試（比對具體檔案而非 hash） | [us-001-reflection.md §2.3](reflection/us-001-reflection.md) | P2 |
| TD-006 | 加 GitHub Actions CI（macOS + Linux） | [us-001-reflection.md §2.3](reflection/us-001-reflection.md) | P2 |
| TD-008 | Magic strings 集中成變數（`.claude`/`.pi`/`.agents`/marker） | [us-001-reflection.md §2.4](reflection/us-001-reflection.md) | P3 |

### Technical Debt（從 DE-001 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-009 | `abs_path` 對 trailing slash 邊緣案例補測試（目前靠真實環境發現 symlink 帶 trailing slash） | [de-001-reflection.md §2.3](reflection/de-001-reflection.md) | P2 |
| TD-010 | 旗標 `=` 形式支援統一化（目前只 `--claude-skills-mode` 支援 `=`，其他長旗標不支援） | [de-001-reflection.md §2.3](reflection/de-001-reflection.md) | P3 |
| TD-011 | `parse_args` 與 `print_plan` 對 modes 重複驗證「merge/replace/skip」，可集中成常數 | [de-001-reflection.md §2.3](reflection/de-001-reflection.md) | P3 |

### Technical Debt（從 Sprint 01 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-012 | 旗標命名一致性：`--claude-skills-mode` 的值都是動詞（merge/replace/skip），與 `mode`（名詞）不匹配 | [sprint-01-reflection.md §3](reflection/sprint-01-reflection.md) | P3 |
| TD-013 | 缺少年份/月份時間戳隔離的清除機制：`replace` 模式建立的 `~/.claude/skills.bak.*` 永遠不會被自動清除 | [sprint-01-reflection.md §3](reflection/sprint-01-reflection.md) | P3 |

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

### DE-001：installer 拒絕在 `~/.claude/skills` 已存在時安裝（2025-08-16）
- 交付：`install.sh`（+87 行：merge helper + `--claude-skills-mode` 旗標）+ 7 個新測試 + 2 個 helper + 1 個 fixture
- 文件：`docs/discussion/2025-08-16-install-sh-merge.md`、`docs/plan/2025-08-16-install-sh-merge.md`、`docs/reflection/de-001-reflection.md`、`docs/deliverable/2025-08-16-install-sh-merge.{md,html}`
- 驗收：10/10 AC ✅ · 26/26 測試 ✅ · 真實 `~/` 環境安裝成功（74 個 skills：保留 69 個 + 8 個 tree_monstor skills 合併）
- 遺留 TD：TD-009、TD-010、TD-011（下個 Sprint）

### Sprint 01 級別反省（2025-08-16）
- 範圍：US-001 + DE-001
- 報告：[`docs/reflection/sprint-01-reflection.md`](reflection/sprint-01-reflection.md)
- 結果：5 個維度通過、1 個 N/A、無 ❌
- 新發現：TD-012 / TD-013
- 結論：✅ 成功（100% 完成率 + 額外修復 DE-001）
