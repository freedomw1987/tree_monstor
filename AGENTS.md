# AGENTS.md - Developer Profile

> **Status:** Canonical. Source of truth for session startup, workspace rules, and long-task handling.

_Developer Profile Session 啟動流程與工作區規範。_

---

## Session 啟動流程

### 步驟 0：確認 Goal（第一件事）

用一兩句 plain text 向 David 確認理解嘅任務目標同階段（Think/Plan/Build/...）。呢個 goal 係北極星，整個 session 不能偏離。

**如果需求模糊**：先執行 Think/Plan 互動模式，問問題、給選項，再確認方向。

### 步驟 1：建立工作區（長期任務）
- 創建 `memory/YYYY-MM-DD.md`
- 創建 `docs/task-board.md`（如有需要）

### 步驟 2：判斷任務類型
```
長期任務?
  ├─ 是 → 用 task list / 原生 subagent 機制協作
  └─ 否 → 直接執行
```

---

## Think / Plan 互動模式（重要）

**Think 和 Plan 階段是與用戶深度對話的窗口，不是悶頭做。**

### Think 階段（市場分析 + 技術調研）

用戶表達需求後，不要直接進入開發。按順序執行：

1. **理解需求背後的「為什麼」**
   - 問：「您為什麼需要這個？」
   - 問：「沒有這個會怎樣？」
   - 問：「成功是什麼樣子？」

2. **提供選項**
   - 根據需求，提供 2-4 個方向性的選項
   - 每個選項包含：方案名稱、優缺點、成本/時間估算
   - 選項後必附「這個清單可能漏了什麼」段：至少一個沒放上桌的方向 + 排除原因
   - 推薦熟悉棧要明說理由（現有 skills、維護成本），至少一個選項跳出慣用棧
   - 讓用戶選擇方向後再深入

3. **市場 + 技術驗證**
   - CEO subagent 做市場分析
   - Researcher subagent 做技術調研
   - 確保項目值得做

### Plan 階段（商業計劃 + 需求 + 架構）

確認方向後：

1. **確認商業模式**
   - 問：「這個系統怎麼賺錢？」
   - 問：「目標用戶是誰？」

2. **確認技術方案**
   - 提供 2-3 個技術架構選項
   - 讓用戶參與決策

3. **確認優先級**
   - 問：「如果只能做三個功能，是哪三個？」
   - 問：「什麼是 MVP，什麼是 以後？」

4. **制定執行計劃**
   - Tech Lead 整合所有輸入
   - 產出 Task Board

5. **Documentation-First Handoff（Build 前強制）**
   - 把 Think / Plan 共識寫入 project docs；必備文檔清單以 `docs/project-documentation-standard.md` 為唯一正本
   - **模組化結構**：`PRD.md` 是 master（US index），每個 US 一個檔 `docs/US/<US-id>-<slug>.md`；`DESIGN.md` 是 master（tokens + component/page index），每個 component 一個檔 `docs/components/<Name>.md`、每個 page 一個檔 `docs/pages/<page>.md`；`API.md` 是 master（conventions + endpoint index），每個 resource 一個檔 `docs/endpoints/<resource>.md`；`TEST-COVERAGE.md` 是 master（summary + RT/RG index），每個 US 一個檔 `docs/coverage/<US-id>.md`（路徑用 `<US-id>` / `<Name>` / `<page>` / `<resource>` placeholder 表示，非真實檔名）。Agent 為單一 feature 工作時**只讀對應 per-US / per-component / per-endpoint / per-coverage 檔**，不讀整個 master。
   - **No-code rule**：structural docs 不含 source 語言 snippet（TS/JS/Python/Go/Rust 等）。Component contract 以 props table / events / a11y / states 描述，**不用 `[example code]`**。API.md JSON schema 保留（屬 interface 規格）。詳細邊界見 `docs/project-documentation-standard.md` § No-code-in-docs Rule。
   - `docs/PRD.md` 有 US → `docs/QA-TRACKER.md` 必須有對應 row；P0/P1 US 必須有 test task baseline
   - baseline 未存在或無法回答「做什麼 / 為誰 / 驗收標準 / 架構決策 / 測試計劃」→ 停留在 Plan，**不能進 Build**
   - Build 中或之後 David 提出新需求 / 修正 → 暫停 Build，先更新對應 per-US/per-component/per-endpoint 檔及受影響 master，再繼續
   - 現有 project 的 docs / tests / regression hooks 不完整或未驗證時，先執行 `skills/existing-project-intake/SKILL.md`；完成 source-first docs baseline、QA/test inventory、regression gaps 記錄後才可 Build，除非 David 明確只要 read-only intake。既有 monolithic docs 需套用 monolithic → modular 拆分 step。
   - Review / QA / code-review feedback 改變需求、驗收標準、設計、API、架構、測試、regression 行為或 tech debt 時，必須執行 `skills/docs-sync/SKILL.md`，把項目 apply / defer / reject 的結論寫入受影響 project docs（含 per-US / per-component / per-endpoint / per-coverage 檔）；只留在 chat 的 feedback 不算 resolved

### Agent 開發預設路徑：orchestrator（含 dev+checker 內層 loop）

> **Status:** Default path for multi-item feature work, not optional.
> 2026-08-02 起，dev-checker-loop 已合併到 `orchestrator` skill — outer loop (multi-subagent) + inner loop (dev+checker) 一體。

對於符合以下條件的任務，**`orchestrator` 是預設路徑**（內層自動啟用 dev+checker loop）：

- 多 work item 的 feature 開發或重構
- 多 phase 專案（Plan → BA → SA → Frontend/Backend → QA → Ship）
- 失敗成本高（regression 風險、production 相關、安全敏感）
- David 明確要求 quality gate / "dev-loop" / "checker agent" / 雙 agent 開發

**為什麼是預設**：orchestrator 把外層（task board、multi-subagent dispatch）和內層（dev+checker verification）包在一起。對單純 feature dev，內層 loop 自動啟用；對多 phase 專案，外層 task board + 跨 task dependency 是主要價值。原有流程（鐵律、Think/Plan、plan mode、skill routing）照常適用。Loop 不豁免任何步驟，但帶來「每個功能都有可開關、有日誌的 regression test」的常態化保護。

**不適用**（直做 + 自驗，不開 orchestrator）：

- 1-2 行 typo / 配置改動
- 純研究 / 純閱讀任務
- 單 US 改動，無歧義，失敗成本低
- 環境壞了（先修環境）

**Modular docs 整合**：orchestrator / dev-checker-loop 的 Work Item 直接 reference per-US 檔（`docs/US/<US-id>-<slug>.md`）作 Spec，不引用 PRD.md 第 N 行。Checker 驗 WI-XXX 時：讀 per-US Spec → 讀 code diff → 讀 `docs/coverage/<US-id>.md` → 跑 RT-XXX。Token 效率 NET POSITIVE（讀小檔 vs 讀大檔）。

**操作版**：`~/.claude/skills/dev-loop/`（內層 loop quick-start 用 `/dev-loop`）和 `~/.claude/skills/orchestrator/`（外層 multi-subagent 用 `/orchestrator`）。兩個 adapter 都導向 canonical `skills/orchestrator/SKILL.md`，行為一致。When to use / When not to use 細節見該檔。

### 觸發 Clarify 的時機

問用戶的場景：
- 需求不明確，需要確認方向
- 有多個選項，用戶需要做決策
- 優先級衝突，需要用戶取捨
- 技術選型有風險，需要用戶確認

---

## 長期任務識別

滿足以下任一條件視為長期任務：
- 超過 30 個 tool calls
- 需要 Think/Plan/Build/Review/Test/Ship/Reflect 多階段
- 需要多個 Subagent 協作
- 任務時間預計超過 1 小時

另一端嘅「小型任務」（可降級文檔 gate）唔係憑感覺判斷：客觀判準、分級決策同申報格式以 `docs/task-tiering.md` 為唯一正本。

---

## Orchestrator 觸發

用 task list 追蹤 goal；**觸發任何 subagent 前，確認 subagent 任務服務於原始目標**。如果偏離了，先回到原始 goal。

當需要多角色協作時，使用平台原生的 delegation 機制（Claude Code 的 subagent / workflow、其他平台的等效方式）。核心原則不變，只是語法因平台而異。

詳細文檔：`docs/subagents.md`

---

## 工作區規範

### 長期任務工作區
```
memory/YYYY-MM-DD.md  — 當前任務的記憶文件
docs/task-board.md     — 任務面板
docs/context-summary.md — 長期任務 context 總結
```

### 文件路徑
- 用戶專案：`~/www/<project-name>/`
- Claude Code：先偵測 active git / project root；`docs/task-board.md`、`memory/YYYY-MM-DD.md` 等相對路徑預設屬於 active project root，除非 David 明確說正在維護 Tree Monstor profile repo

### Profile 文件結構

完整文檔地圖見 `docs/00-index.md`（core files、canonical sources、詳細文檔地圖）；skills catalog 見 `skills/README.md`。唔好喺呢度維護會 drift 嘅文件樹。

---

## Session 結束流程

### 長期任務結束前
1. 更新 Task Board 為 Done
2. 寫入 context-summary.md（如有需要）
3. 確保所有 Subagent 已終止
4. 通知 Developer 任務完成

### 失敗場景
- 任何 Subagent 失敗 → 按 `docs/failure-policy.md` 處理
- 無法解決 → 升級並通知 Developer

---

## Related docs

- [Documentation index](docs/00-index.md)
- [Core identity](SOUL.md)
- [Task Board rules](docs/task-board.md)
- [Failure policy](docs/failure-policy.md)
