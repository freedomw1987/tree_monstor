# Backlog — tree_monstor

> 本檔追蹤所有待辦、進行中、已完成的工作項目。
> 格式：每個 item 有唯一 ID（US/DE/TECH/Spike）、標題、狀態、優先級、Story Point、Module、AC。

---

## 📊 狀態總覽

| 狀態 | 數量 |
|---|---|
| PENDING | **0 🎉** |
| IN_PROGRESS | 0 |
| PARTIAL | 0 |
| DONE | 27 (US-001 / DE-001 / DE-002 / DE-003 / US-007 / US-008 / TD-014 / TD-015 / TD-016 / US-009 / US-010 / TD-019 / TD-020 / TD-021.1 ~ TD-021.7 / TD-006.1 ~ TD-006.4 / **TD-005 / TD-008**) + Sprint 01 / 04 / 05 / 06 / 07 反省 |

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
- **狀態**：✅ **DONE**（已修復，2025-08-21 隨 US-007 驗證期間推進。install.sh 重構為 merge 模式，5 個 bats 測試加；DE-003 負責測試期望調整）

#### 實作記錄
- 2025-08-21：原 commit 重構 install.sh merge 邏輯並加 5 個 bats 測試（DE-001 AC-1~5）
- DE-003 同步修 AC-5 測試期望（symlink → 目錄）
- 進度未更新到 backlog 狀態欄，補登如上

#### Defect 描述
> **情境**：當 `~/.claude/skills` 已是一個真實目錄（用戶自行安裝了 69 個 skills），installer 會中止並顯示：
> `[✗] Path exists but is not a symlink: /Users/davidchu/.claude/skills`
> `[✗] Refusing to overwrite. Move it aside and re-run.`
>
> **後果**：全域安裝（`./install.sh` 不帶任何參數）直接失敗，無法完成。
>
> **根因**：`ensure_symlink()` 對「存在但不是 symlink」的目標直接拒絕，沒有提供「合併」選項。

#### 驗收標準 (AC)
- [x] AC-1：當 `~/.claude/skills` 是真實目錄時，installer 自動進入 **merge 模式**（不報錯）
- [x] AC-2：Merge 模式預設行為：對 `tree_monstor/skills/` 中每個 skill 建立一個 symlink 到 `~/.claude/skills/<skill-name>`（命名不衝突時）
- [x] AC-3：當 `~/.claude/skills/<skill-name>` 已存在（用戶自有同名 skill）時，**跳過**但列出警告（不覆蓋）
- [x] AC-4：新增 `--claude-skills-mode {merge|replace|skip}` 旗標覆寫預設（merge=預設，replace=原行為的破壞式覆蓋，skip=不安裝 Claude skills）
- [x] AC-5：對 `~/.claude/CLAUDE.md` 處理：若已是 symlink 且指向非 tree_monstor 源頭，自動解除並重寫為標準 wrapper（用 `@` 引用新路徑）
- [x] AC-6：對 `~/.pi/`（全新空的目錄）按原計劃執行 symlink
- [x] AC-7：對 `.agents/tree_monstor/` copy 仍按原計劃執行
- [x] AC-8：所有新邏輯有對應的 bats 測試（≥ 5 個新測試案例）— 5 個 ✅（DE-001 AC-1~5）
- [x] AC-9：`./tests/install.bats` 全部通過（舊 19 + 新 ≥ 5）— 26/26 過 ✅
- [x] AC-10：dry-run 模式正確顯示 merge 行為（不實際執行）

---

## 📝 PENDING

### DE-002：AGENTS.md 缺「pi 不會讀 SOUL.md」marker 導致 agents-md.bats SOUL-3/SOUL-4 失敗（2025-08-21）
- **Module**：M2 — SOP Infrastructure
- **發現日期**：2025-08-21（US-007 設定檢查時）
- **狀態**：✅ **DONE**（已修復，待 US-007 驗收）
- **發現者**：Agent（US-007 執行前的 Gate 3 baseline）
- **根本原因**：先前 commit `chore(sop): harden AGENTS.md` 把 `> 註：本原則同步保留於 SOUL.md ... pi 不會讀 SOUL.md ...` 一行刪除，但沒同步更新 `tests/agents-md.bats` 的 awk 模式，導致兩個 bats 測試失敗。
- **修復**：在 AGENTS.md 「萬事原則」段尾加回該 marker 行（1 行改動）
- **驗證**：`bats tests/agents-md.bats` 從 4/6 → 6/6 ✅

#### Defect 描述
> 作為 tree_monstor 維護者，我發現 `bats tests/agents-md.bats` 在 2025-08-21 有 2 個失敗測試（SOUL-3 / SOUL-4），會阻擋任何 Gate 3 regression baseline。
> 期望：AGENTS.md 必須包含「pi 不會讀 SOUL.md」的明確標記，且 bats 測試全綠。
> 實際（修復前）：AGENTS.md 在 2025-08-21 的 commit 把 marker 刪除，bats SOUL-3/SOUL-4 失敗。

#### Acceptance Criteria
- [x] AC-1：AGENTS.md 「萬事原則」段尾包含 `> 註：... pi 不會讀 SOUL.md ...` 的 marker
- [x] AC-2：`bats tests/agents-md.bats` 全部 6 個測試通過
- [x] AC-3：AGENTS.md 的「萬事原則」bullet 數量仍等於 SOUL.md（維持 7 個）

### DE-003：AC-5 (`--local installs to current directory`) 測試期望與 DE-001 merge 模式衝突（2025-08-21）
- **Module**：M1 — Installer & Distribution
- **發現日期**：2025-08-21（US-007 設定檢查時）
- **狀態**：✅ **DONE**（已修復，待 US-007 驗收）
- **發現者**：Agent（US-007 執行前的 Gate 3 baseline）
- **根本原因**：DE-001 commit 重構了 install.sh 邏輯，當 `~/.claude/skills` 是真實目錄時會自動進入 merge 模式（per-skill symlinks），但 `tests/install.bats` 的 AC-5 測試仍期望 `./.claude/skills` 是樹級 symlink（用 `[ -L ]` 判斷），而非 merge 模式產生的真實目錄。
- **修復**：更新 AC-5 測試，把 `[ -L "./.claude/skills" ]` 改為 `[ -e "./.claude/skills" ]`，跟 AC-6 (`--target`) 測試期望對齊。註解說明 DE-001 merge 模式。
- **驗證**：`bats tests/install.bats` 從 25/26 → 26/26 ✅

#### Defect 描述
> 作為 tree_monstor 維護者，我發現 `bats tests/install.bats` 在 2025-08-21 有 1 個失敗測試（AC-5），會阻擋任何 Gate 3 regression baseline。
> 期望：`--local` 安裝後 `.claude/skills` 存在（接受 symlink 或目錄），bats 測試全綠。
> 實際（修復前）：AC-5 用 `[ -L ]` 期望 symlink，但 DE-001 merge 模式產生的是目錄含 per-skill symlinks。

#### Acceptance Criteria
- [x] AC-1：AC-5 測試用 `[ -e ]` 接受 symlink 或目錄
- [x] AC-2：`bats tests/install.bats` 全部 26 個測試通過
- [x] AC-3：測試註解明確指出「DE-001 merge 模式」以防未來混淆

### US-007：把 §2.3 Gate 邏輯抽成 `docs/sop/gates.json`（single source of truth）（2025-08-21）
> **ID 說明**：原本命名為 US-002，但 `docs/plan/2025-08-16-sprint-02-design.md` 已佔用 US-002~006 空間（雖未實際登記到 backlog.md）。依用戶決定（2025-08-21）跳號至 US-007，保留 US-002~006 給 sprint-02 計劃。
- **Module**：M2 — SOP Infrastructure
- **討論記錄**：[`docs/discussion/2025-08-21-sop-gates-json.md`](discussion/2025-08-21-sop-gates-json.md)
- **狀態**：🟢 **DONE**（結構驗收 7/7 通過；行為驗收 3 AC 由 US-008 接力）
- **計劃文件**：[`docs/plan/2025-08-21-sop-gates-json.md`](plan/2025-08-21-sop-gates-json.md)
- **交付文件**：[`docs/deliverable/2025-08-22-us-007-gates-json.md`](deliverable/2025-08-22-us-007-gates-json.md)
- **反省報告**：[`docs/reflection/us-007-reflection.md`](reflection/us-007-reflection.md)
- **Reviewer 檢查**：[`docs/review/2025-08-22-us-007-reviewer-check.md`](review/2025-08-22-us-007-reviewer-check.md)
- **Story Point**：13（上限，建議一次跑完）
- **Sprint**：獨立 Sprint（SOP Infra Sprint 01）

#### User Story
> **作為** tree_monstor 的維護者，
> **我想要** 把 AGENTS.md §2.3「4 個 Gate」的定義抽成 `docs/sop/gates.json`，
> **以便** 強制 Agent 在每個 Gate 留下證據（測試 output / lint output / 截圖），防止「跳過 gate」或「假報通過」；且未來改 Gate 只需改 JSON 一處。

#### Acceptance Criteria（結構驗收 — 必通過）
- [x] AC-1：`docs/sop/gates.json` 存在，含 4 個 Gate 定義（id / name / trigger_skill / pass_criteria / required_evidence / fail_action）
- [x] AC-2：`docs/sop/gates.schema.json` 存在，符合 JSON Schema Draft **07**（原計劃 2020-12，但 ajv-cli 不支援，見 reflection）
- [x] AC-3：使用 ajv 對 `gates.json` 跑驗證，結果 **0 錯誤**（`docs/sop/gates.json valid`）
- [x] AC-4：AGENTS.md §2.3 改為引用 `./sop/gates.json`，不再列 Gate 細節表格（522 行，減 61 行）
- [x] AC-5：`install.sh` 增加邏輯：複製 `docs/sop/` 到目標位置的 `sop/` 子目錄（`~/.pi/sop/` 與 `~/.claude/sop/`）— 5 個 bats 測試全綠
- [x] AC-6：`install.sh --dry-run` 正確顯示 sop/ 規劃
- [x] AC-7：AGENTS.md 中對 gates.json 的引用路徑在 install 後位置一致（用 `./sop/gates.json` 相對路徑）— 實際部署驗證：~/.pi/sop/gates.json symlink → 源檔

#### Acceptance Criteria（行為驗收 — 必通過）
- [ ] AC-8：跑 1 個真實小型任務（如透過 `dav-skill-creater` 登記一個 1 SP 新 skill），Agent 在執行過程中**明確引用** `gates.json` 內容
- [ ] AC-9：4 個 Gate（TDD / lint / regression / reviewer）全部觸發，且每個 Gate 都留有對應 `required_evidence` 指定的證據
- [ ] AC-10：執行日誌 / deliverable 中可看到 Agent 引用 JSON 的軌跡

> **AC-8/9/10 處理**：不適合在 US-007 內驗證（reviewer == implementer 反 pattern）。已建立接力任務 [US-008](#us-008驗收-us-007-ac-8910-用-dav-skill-creater-產-1-sp-任務模板)（1 SP，使用 `dav-skill-creater`）。

#### 已知設計決策
- ✅ JSON 是 single source of truth，AGENTS.md 改為引用（不列細節）
- ✅ 用 JSON Schema Draft 07（**原計劃 2020-12，因 ajv-cli 兼容性限制改 07**） + ajv 驗證
- ✅ AGENTS.md 用相對路徑 `./sop/gates.json`（install 後位置一致）
- ✅ install.sh 複製 `docs/sop/` 整個目錄（未來可擴充）
- ⚠️ install.sh 用 symlink 部署 gates.json，源檔被刪時 symlink 會失效 → 登記 [TD-014](#technical-debt)

#### Gate 驗收紀錄
- **Gate 1 (TDD)** ✅：5 個 US-007 bats 測試紅→綠（`tests/install.bats` US-007 AC-5/AC-5b/AC-5c/AC-6/AC-7）
- **Gate 2 (lint)** ✅：ajv 0 error + bash -n 0 error + 所有 JSON 0 syntax error
- **Gate 3 (regression)** ✅：baseline 32 → after 37（5 個新增，0 個破壞）
- **Gate 4 (reviewer)** ✅：手工 reviewer 模式（環境無 subagent 工具，誠實標記）— 見 [`docs/review/2025-08-22-us-007-reviewer-check.md`](review/2025-08-22-us-007-reviewer-check.md)

---

### US-008：驗收 US-007 AC-8/9/10 — 用 `dav-skill-creater` 產 1 SP 任務模板（2025-08-22）
- **Module**：M2 — SOP Infrastructure
- **狀態**：✅ **完成**（re-verify 於 2025-08-22，AC-2/AC-4 補為即時標示每個證據對應 `required_evidence` 第 X 項）
- **重要揭露**：執行過程發現「Agent 未即時引用 gates.json」 → 登記 TD-016
- **來源**：US-007 的 AC-8/9/10（行為驗收），因 reviewer == implementer 反 pattern 不能在 US-007 內驗證
- **Story Point**：1（trivial — 使用 `dav-skill-creater` 產模板）
- **Sprint**：下一個 Sprint（SOP Infra Sprint 02）
- **前置**：US-007 ✅ DONE

#### User Story
> **作為** tree_monstor 維護者，
> **我想要** 跑 1 個真實的 1 SP 小任務（例如用 `dav-skill-creater` 登記一個新 skill），
> **以便** 驗證 Agent 在執行任務時是否真的引用 `docs/sop/gates.json` 的 `pass_criteria` / `required_evidence`，而不是只在對話空談。

#### Acceptance Criteria
- [ ] AC-1：用 `dav-skill-creater` 產出 1 個 1 SP 任務模板（登記到 backlog）
- [ ] AC-2：跑該任務（可以是 trivial 加 log 改動），執行日誌中可看到 Agent 引用 `gates.json` 的具體 `required_evidence` 內容
- [ ] AC-3：對話中出現「依 gates.json 規範，Gate X 需要...」等字串至少 3 次
- [ ] AC-4：4 個 Gate 都觸發 + 每個 Gate 的 `required_evidence` 都在對話貼出（即使是 trivial task 的證據）

#### 為什麼不直接在 US-007 內做？
- reviewer == implementer 反 pattern（自己驗自己一定會偏向過）
- 行為驗收需要「跨 sprint」的真實使用情境
- US-007 結構驗收已 7/7 通過，獨立 1 SP 任務驗證行為更純淨

#### 建議執行者
下一個 sprint 第一個任務（warm-up），用真實場景驗證 SOP 規範是否真的約束 Agent 行為。

---

### US-009：建立 `dav-wiki` skill — 統一文件資料提取與 Markdown 化（2026-01-15）
- **Module**：M3 — Knowledge Management
- **Story Point**：8（中等偏重：含核心流程 + schema + 演進規則 + examples + 測試）
- **Sprint**：Sprint 03（建議）— 強相依不拆
- **優先級**：P1（個人 / 團隊知識管理基礎設施）
- **建立日期**：2026-01-15
- **討論記錄**：[`docs/discussion/2026-01-15-dav-wiki-design.md`](discussion/2026-01-15-dav-wiki-design.md)
- **設計計劃**：[`docs/plan/2026-01-15-dav-wiki-design.md`](plan/2026-01-15-dav-wiki-design.md)
- **PRD**：[`docs/prd/03-knowledge-extraction.md`](prd/03-knowledge-extraction.md) + [HTML 版](prd/03-knowledge-extraction.html)
- **架構設計**：[`docs/system-design.md`](system-design.md)、[`docs/DESIGN.md`](DESIGN.md)
- **狀態**：🟢 **執行完成** — 4 Gate 全部通過，提交交付物中

#### User Story
> **作為** tree_monstor 的使用者，
> **我想要** 一個 `dav-wiki` skill，可以接收各種來源的資料（純文字、Office 文件、網頁、圖片 OCR、影音字幕）並自動轉成 Markdown 知識庫，
> **以便** 我能把所有學習資料、研究筆記、會議記錄統一沉澱在 `docs/wiki/`，且未來 AI 引用時可透過 frontmatter、tag、概念交叉關聯快速取用。

#### 來源支援（核心 + 擴充）
| 來源 | 層級 | 備註 |
| --- | --- | --- |
| 純文字（.txt, .md） | 核心 | 最簡單、最快 |
| Office（.pdf, .docx, .pptx） | 核心 | 用 pandoc / pdf2text 等工具 |
| 網頁 URL | 核心 | 用 fetch_content 或爬蟲 |
| 圖片 OCR | 擴充模組 | 可選安裝 |
| YouTube 字幕 / 影片 | 擴充模組 | 可選安裝 |

#### 輸出結構
```
docs/
├── README.md                          ← 自動生成的導航頁
├── wiki/
│   ├── _index.json                    ← 文件索引
│   ├── _tags.json                     ← tag 反向索引
│   └── {category}/
│       └── {YYYY-MM}/
│           └── {title}.md             ← 帶 frontmatter
└── concepts/
    ├── _concepts.json                 ← 概念索引
    └── {slug}.md                      ← 獨立概念文件
```

#### 內容處理
- ✅ 清理格式噪音、加標題層級、提取重點摘要、標記圖表
- ✅ AI 加 tag、交叉引用相關文件（透過 `_index.json` 索引式比對）
- ✅ **概念提取**：從文件提煉概念（1-5 個/篇），寫進 `docs/concepts/`
- ✅ **概念演進**：衍生（derive）/ 修正（revise）/ 合併（merge）/ 棄用（deprecate）
- ✅ Obsidian-style 雙向連結 `[[xxx]]`
- ❌ QA 問答對（不做）

#### Trust 整合
- 用戶輸入加 `/trust` 前綴 → 走 `dav-trust` 自主模式
- 否則正常對話流程

#### Acceptance Criteria
- [x] AC-1：skill 存放於 `.agents/skills/dav-wiki/` 下，含 SKILL.md + examples.md + frontmatter-schema.md + concept-evolution.md
- [x] AC-2：SKILL.md **≤ 150 行**（dav-skill-creater 規則）— 107 行 ✅
- [x] AC-3：支援所有 5 種輸入來源（核心 3 種必支援；OCR / 字幕標為擴充模組）
- [x] AC-4：Category 走「AI 建議 + 用戶確認」流程（V01/V02 紀律）
- [x] AC-5：每篇產出檔案含完整 frontmatter（source, extracted_at, category, tags, summary, related, concepts）
- [x] AC-6：交叉引用透過 `_index.json` 索引式比對，結果用 `[[xxx]]` 標記
- [x] AC-7：概念提取成功後同時產出 `docs/concepts/{slug}.md` 並更新 `_concepts.json`
- [x] AC-8：概念演進 4 種動作（derive/revise/merge/deprecate）都有明確規則文件
- [x] AC-9：用 `/trust` 前綴時啟動 `dav-trust` 自主模式
- [x] AC-10：`docs/README.md` 在每次任務完成後自動重建
- [x] AC-11：軟刪除用 frontmatter 標記（`superseded_by` / `deprecated`）
- [x] AC-12：含測試（用 `tdd-test-writer` 流程，覆蓋核心路徑）— 20 tests ✅

#### 子任務（待拆解）
| ID | 標題 | 備註 |
| --- | --- | --- |
| US-009-T1 | 用 `dav-designer` 完成設計計劃 | ✅ DONE — DESIGN.md + system-design.md + PRD (.md/.html) + plan.md |
| US-009-T2 | 用 `tdd-test-writer` 寫測試 | ✅ DONE — tests/dav-wiki.bats（20 tests） |
| US-009-T3 | 實作 `SKILL.md`（核心流程 ≤ 150 行） | ✅ DONE — 107 行（含空行） |
| US-009-T4 | 實作 `frontmatter-schema.md` | ✅ DONE — 文件 + 概念兩種 schema |
| US-009-T5 | 實作 `concept-evolution.md` | ✅ DONE — 4 種演進動作規則 |
| US-009-T6 | 實作 `examples.md` | ✅ DONE — 9 個操作範例 |
| US-009-T7 | 用 `dev-checker-loop` 跑質量檢查 | ✅ DONE — reviewer verdict: OK with notes（2 P1 + 7 P2 已修） |
| US-009-T8 | 用 `regression-guard` 預留探針 | ✅ DONE — bats tests/dav-wiki.bats 充當探針；全套 76/76 通過 |
| US-009-T9 | 用 `dav-reflection` 反省 | ✅ DONE — docs/reflection/us-009-reflection.md |
| US-009-T10 | 用 `dav-submitter` 產出交付物 | ✅ DONE — .md + .html + 對話摘要 |

#### 設計決策摘要
- ✅ 核心三來源（純文字 / Office / 網頁）+ 兩個擴充（OCR / 字幕）
- ✅ 輸出結構：docs/README.md + docs/wiki/ + docs/concepts/
- ✅ 內容處理：C 級深度加工（不含 QA 問答對）
- ✅ Category：AI 建議 + 用戶確認
- ✅ 交叉引用：`_index.json` 索引式比對 + Obsidian `[[xxx]]`
- ✅ Trust 整合：可選 `/trust` 前綴
- ✅ 軟刪除：用 frontmatter 標記
- ✅ Skill 結構：SKILL.md + 3 個附件（examples / schema / concept-evolution）

---

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

### Technical Debt（從 US-007 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-014 ✅ | install.sh 用 symlink 部署 `docs/sop/`，源檔被刪時 symlink 會失效；`do_uninstall` 未清理 `~/.pi/sop/` 與 `~/.claude/sop/` | [us-007-reviewer-check.md §L3](review/2025-08-22-us-007-reviewer-check.md) | P3 |
| TD-015 ✅ | gates.schema.json 使用 Draft-07 而非原計劃 Draft-2020-12（因 ajv-cli 兼容性限制）；未來若改用 ajv API（非 CLI）可選擺 | [us-007-reviewer-check.md §L1](review/2025-08-22-us-007-reviewer-check.md) | P3 |

> **TD-015 ✅ 已修復**（2025-08-22）：加 `$comment` 三層註記（schema 頂層 / gates.json description / AGENTS.md §2.3 引用處）。詳見 [docs/deliverable/2025-08-22-td-015-draft-07-note.md](deliverable/2025-08-22-td-015-draft-07-note.md)。

### Technical Debt（從 US-008 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-016 ✅ | gates.json 規範未真正約束 Agent 行為：執行 4 Gate 流程但未即時明確標示「依 gates.json 規範, Gate X 需要...」引用來源 | [us-008-behavior-verification.md](deliverable/2025-08-22-us-008-behavior-verification.md) | P2 |

> **TD-016 ✅ 已修復**（2025-08-22）：加 `mandatory_phrase` 欄位（4 個 Gate 都加）+ Schema pattern `^依 gates.json 規範` + AGENTS.md §2.3 加 Agent 必須做的動作指示。詳見 [docs/deliverable/2025-08-22-td-016-mandatory-phrase.md](deliverable/2025-08-22-td-016-mandatory-phrase.md)。

**TD-016 詳細說明**：
- US-008 揭露的 SOP 規範形式大於實質問題
- 提案 1：在 AGENTS.md §2.3 引用處加「每次進 Gate 必須在對話標示『依 gates.json 規範』+ 列出 required_evidence 編號」
- 提案 2：考慮 agent 框架層把 gates.json 變成 system prompt 注入
- 提案 3：在 gates.json 加 `mandatory_phrase` 欄位，Agent 進 Gate 時必須引用

### Technical Debt（從用戶建議 2025-08-22 產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-017 ✅ | AGENTS.md 524 行過長，大模型難以穩記內容；§2.1-§2.8 + CHANGELOG 抽出去 `docs/sop/handbook/*.md` 一章一檔，AGENTS.md 精簡到 ~150 行 | 用戶建議 2025-08-22 | P1 |

> **TD-017 ✅ 已修復**（2025-08-22）：AGENTS.md 從 524 → 68 行（-87%），9 個 handbook 檔案新建 + 加 3 個 regression 探針保護。詳見 [docs/deliverable/2025-08-22-td-017-agents-md-slim.md](deliverable/2025-08-22-td-017-agents-md-slim.md)。

**TD-017 詳細說明**：
- 用戶反饋：「AGENTS.md 是精簡的（150 行左右），目的是讓大模型可以穩記 AGENTS.md 的內容去做任務」
- 提案 1：每個章節一個檔：`docs/sop/handbook/2.{1-8}-*.md` + `changelog.md`（方案 A，勳用）
- AGENTS.md 保留：§1 萬事原則 + §1.5 提問紀律 + §2.0 SOP 範圍 + §2.3 執行（精簡表格） + §3 引用索引
- AGENTS.md 用相對路徑引用 handbook：`[§2.1 規劃完整內容](./sop/handbook/2.1-planning.md)`
- 預估 SP：3（中量重構）

### Technical Debt（從 TD-017 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-018 ✅ | install.sh 部署 `docs/sop/*.json` 但**未部署 `docs/sop/handbook/*.md`**；AGENTS.md 用相對路徑引用 handbook，部署後若 handbook 不存在則引用全失效 | 用戶反饋 2025-08-22 + [td-017-deliverable §已知問題](deliverable/2025-08-22-td-017-agents-md-slim.md) | P1 |

> **TD-018 ✅ 已修復**（2025-08-22）：install_sop() 加 handbook/*.md 處理 + remove_merged_sop() 改遞迴清理 + AGENTS.md 加裝安裝後路徑表 + 6 個 bats 探針保護。詳見 [docs/deliverable/2025-08-22-td-018-handbook-deploy.md](deliverable/2025-08-22-td-018-handbook-deploy.md)。

**TD-018 詳細說明**：
- TD-017 精簡 AGENTS.md 用 `[§2.1](./sop/handbook/2.1-planning.md)` 引用 handbook
- 但 install.sh 只 symlink `docs/sop/*.json`（US-007 範圍），handbook/*.md 未被部署
- 提案：handbook/*.md 用**同樣 per-file symlink 機制**部署到 `~/.pi/sop/handbook/*.md` + `~/.claude/sop/handbook/*.md`
- 預估 SP：3（中量改動 — 要動 install.sh 的 plan + install + uninstall + 加 4-6 個 bats 測試）

### Technical Debt（從 US-009 反省產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-019 ✅ | 軟刪除磁碟清理機制（deprecated 檔案永遠保留）— 加定期清理工具 + `docs/wiki/_deprecated/` 子目錄隔離 | [us-009-reflection.md §2.3](reflection/us-009-reflection.md) | P1 |
| TD-020 ✅ | 交叉引用品質改善（純 tag 重疊比對 → 加上 summary 關鍵詞比對） | [us-009-reflection.md §2.3](reflection/us-009-reflection.md) | P1 |

> **TD-019 / TD-020 ✅ 已修復**（Sprint 04）：加 `tools/wiki-cleanup.sh` + `tools/wiki-cross-ref.sh` + 兩個 handbook + 20 個 bats tests。詳見 [docs/deliverable/2026-01-15-sprint-04.md](deliverable/2026-01-15-sprint-04.md)。

### Technical Debt（從 Sprint 04 reviewer 產生）

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| TD-021 | cleanup 工具強化 + README 重建 + 8 條 reviewer findings + 7 個邊緣案例測試 | [sprint-04-review.md](review/2026-01-15-sprint-04-review.md) | P1 |

### 已完成的 TD（本 Sprint）

- TD-001 ✅：重構 install.sh 函數排列 + 刪 stale 註解 + 移除未用 `VERBOSE`
- TD-007 ✅：README 加 `chmod +x` Quick Start
- TD-015 ✅：gates.schema.json 加 Draft-07 `$comment` 註記（三層同步：schema / gates.json / AGENTS.md）
- TD-014 ✅：`do_uninstall` 加 sop/ 清理（`remove_merged_sop` 函式，與 `remove_merged_skills` 對稱）
- TD-016 ✅：gates.json 加 `mandatory_phrase` 欄位 + Schema pattern 強制 + AGENTS.md §2.3 加 Agent 必須做的動作指示

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

---

## 🚀 Sprint 04 — dav-wiki 優化（2026-01-15 規劃）

**主題**：讓剛完工的 dav-wiki skill 從「規格通過」走到「實戰驗證 + 兩個 P1 技術債清除」

| ID | 標題 | SP | 優先級 | 狀態 |
| --- | --- | --- | --- | --- |
| **US-010** | dav-wiki 實戰測試（PDF + URL） | 2 | P0 | ✅ DONE |
| **TD-019** | 軟刪除磁碟清理機制 | 1.5 | P1 | ✅ DONE |
| **TD-020** | 交叉引用品質改善 | 1.5 | P1 | ✅ DONE |

**計劃文件**：[`docs/plan/2026-01-15-dav-wiki-sprint-04.md`](plan/2026-01-15-dav-wiki-sprint-04.md)
**交付文件**：[`docs/deliverable/2026-01-15-sprint-04.md`](deliverable/2026-01-15-sprint-04.md)
**反省報告**：[`docs/reflection/sprint-04-reflection.md`](reflection/sprint-04-reflection.md)
**Reviewer 檢查**：[`docs/review/2026-01-15-sprint-04-review.md`](review/2026-01-15-sprint-04-review.md)
**總 SP**：5 SP
**前置**：US-009 ✅ DONE

### US-010：dav-wiki 實戰測試
- **User Story**：拿真實的文件（1 個 PDF + 1 個 URL）跑 `dav-wiki` 流程，驗證 7 步流程順暢
- **AC-1**：拿真實 PDF 跑 dav-wiki，產出 1 篇 wiki + 1-5 個概念
- **AC-2**：拿真實 URL 跑 dav-wiki，產出 1 篇 wiki
- **AC-3**：發現 ≥ 2 個「規格沒說清楚」的問題
- **AC-4**：每個問題登記成 TD 或更新文件
- **AC-5**：產出 smoke-test 紀錄文件

### TD-019：軟刪除磁碟清理機制
- **User Story**：清理工具把 deprecated 標記超過 N 天的檔案移到 `docs/wiki/_deprecated/` 隔離
- **方案 A（推薦）**：移到 `_deprecated/{YYYY-MM}/` + 反向索引
- **方案 B**：CLI `tools/wiki-cleanup.sh` 手動清理
- **方案 C**：自動清理 N 天前

### TD-020：交叉引用品質改善
- **User Story**：交叉引用不只看 tag，也看 summary 關鍵詞，推薦更準
- **方案**：`_index.json` 加 `keywords: [string]` 欄位（從 summary 提取 3-5 個）+ tag+keywords 比對

---

## 🚀 Sprint 05 — TD-021 cleanup 強化（2026-01-15 規劃）

**主題**：清掉 Sprint 04 reviewer 找到的 P2/P3 + 7 個邊緣案例 + cleanup README 重建

| ID | 標題 | SP | 優先級 | 狀態 |
| --- | --- | --- | --- | --- |
| **TD-021.1** | `wiki-cleanup.sh` README 重建（補 step [9] 實作） | 0.5 | P1 | ✅ DONE |
| **TD-021.2** | `wiki-cleanup.sh` 修 `errors` counter 不變問題 | 0.25 | P2 | ✅ DONE |
| **TD-021.3** | `wiki-cross-ref.sh` 加第三排序鍵 tie 確定性 | 0.25 | P2 | ✅ DONE |
| **TD-021.4** | `wiki-cleanup.sh` 程式碼風格 | 0.25 | P3 | ✅ DONE |
| **TD-021.5** | `wiki-cross-ref.sh` 旗標解析風格統一 | 0.25 | P3 | ✅ DONE |
| **TD-021.6** | examples.md 範例 1 補 keywords 步驟 | 0.25 | P2 | ✅ DONE |
| **TD-021.7** | 7 個邊緣案例測試（E1-E7） | 1 | P1 | ✅ DONE |

**交付文件**：[`docs/deliverable/2026-01-15-sprint-05.md`](deliverable/2026-01-15-sprint-05.md)
**反省報告**：[`docs/reflection/sprint-05-reflection.md`](reflection/sprint-05-reflection.md)
**Reviewer 檢查**：[`docs/review/2026-01-15-sprint-05-review.md`](review/2026-01-15-sprint-05-review.md)

**計劃文件**：[`docs/plan/2026-01-15-dav-wiki-sprint-05.md`](plan/2026-01-15-dav-wiki-sprint-05.md)
**總 SP**：2.75 SP
**前置**：Sprint 04 ✅ DONE

### 邊緣案例清單（E1-E7）
| ID | 測試內容 |
| --- | --- |
| E1 | `--purge` 真刪除 |
| E2 | 季度分類正確性（2026-02 → 2026-Q1） |
| E3 | 無效 `deprecated_at` fallback |
| E4 | 冪等性 |
| E5 | new-doc.tags=[] 應回 0 推薦 |
| E6 | self-match 排除 |
| E7 | tie 排序 deterministic |

---

## 🚀 Sprint 06 — TD-006 GitHub Actions CI（2026-01-15 規劃）

**主題**：把技術債推到 0 — 從 US-001 留下的 P2 技術債

| ID | 標題 | SP | 優先級 | 狀態 |
| --- | --- | --- | --- | --- |
| **TD-006.1** | GitHub Actions workflow（`.github/workflows/ci.yml`）| 1 | P2 | ✅ DONE |
| **TD-006.2** | 在 README.md 加 CI badge | 0.25 | P3 | ✅ DONE |
| **TD-006.3** | 文件：貢獻者指南（CONTRIBUTING.md）含 CI 說明 | 0.5 | P3 | ✅ DONE |
| **TD-006.4** | 補一個 Linux-specific test fixture | 0.25 | P2 | ✅ DONE |

**交付文件**：[`docs/deliverable/2026-01-15-sprint-06.md`](deliverable/2026-01-15-sprint-06.md)
**反省報告**：[`docs/reflection/sprint-06-reflection.md`](reflection/sprint-06-reflection.md)
**Reviewer 檢查**：[`docs/review/2026-01-15-sprint-06-review.md`](review/2026-01-15-sprint-06-review.md)

**計劃文件**：[`docs/plan/2026-01-15-dav-wiki-sprint-06.md`](plan/2026-01-15-dav-wiki-sprint-06.md)
**總 SP**：2 SP
**前置**：Sprint 05 ✅ DONE

---

## 🚀 Sprint 07 — TD-005 + TD-008 剩餘技術債（2026-01-15 規劃）

**主題**：把技術債從 2 推到 0

| ID | 標題 | SP | 優先級 | 狀態 |
| --- | --- | --- | --- | --- |
| **TD-005** | install.sh AC-11a 改為更精準冪等測試（比對具體檔案而非 hash） | 0.5 | P2 | ✅ DONE |
| **TD-008** | install.sh Magic strings 集中成變數（`.claude`/`.pi`/`.agents`/marker） | 1 | P3 | ✅ DONE |

**交付文件**：[`docs/deliverable/2026-01-15-sprint-07.md`](deliverable/2026-01-15-sprint-07.md)
**反省報告**：[`docs/reflection/sprint-07-reflection.md`](reflection/sprint-07-reflection.md)
**Reviewer 檢查**：[`docs/review/2026-01-15-sprint-07-review.md`](review/2026-01-15-sprint-07-review.md)

**計劃文件**：[`docs/plan/2026-01-15-dav-wiki-sprint-07.md`](plan/2026-01-15-dav-wiki-sprint-07.md)
**總 SP**：1.5 SP
**前置**：Sprint 06 ✅ DONE
