---
name: orchestrator
description: Multi-subagent coordination (task board, dependencies, multi-role) with per-work-item dev+checker verification loop (STATE.md, regression test). One canonical skill for the full orchestration pattern. Default path for multi-item feature work and multi-phase projects.
trigger: |
  "協調任務 | 管理進度 | 派發工作 | 任務追蹤 | 任務組裝 | dev-loop | dev checker loop | 雙 agent 開發 | checker agent | STATE.md | regression 開關 | 自動檢查循環 | 開發檢查協作 | 多 subagent | 派發 subagent"
category: development
applicability: operational
---


Last-verified: 2026-08-02
# Orchestrator — Multi-subagent coordination with dev+checker inner loop

> **Status:** Operational workflow. Single canonical skill combining two layers:
>
> - **Outer loop** = multi-subagent, multi-phase, multi-role coordination (task board, dependency graph)
> - **Inner loop** = per-work-item dev+checker verification (STATE.md, regression test, fresh checker)
>
> 對於多 item feature dev 或多 phase project，**這是 default path**（不是可選）。

---

## Core rule

0. **Loop 是外加層，不是替代流程。** Outer + inner loop 只外加兩件事：(a) 開發單位記錄為 task board / STATE.md work items；(b) 每輪獨立 checker 實證覆核。原有流程（鐵律、Think/Plan 互動、plan mode、skill routing）在 loop 內全部照常適用 — 任何「因為在跑 loop 所以省略原流程某一步」都是誤用。
1. **Checker 的判斷標準永遠是「實際跑過、觀察到正確行為」**（代碼品質鐵律 3/5）。文檔寫齊、測試檔案存在、dev 聲稱通過，都不構成 VERIFIED。
2. **Checker 必須是 fresh、獨立的 subagent** — 不沿用 dev 的 context，不帶 dev 的偏見。Checker 的職責是找問題，不是幫 dev 通過。
3. **所有協作狀態必須寫進對應檔案** — outer loop 寫 `docs/task-board.md`，inner loop 寫 `docs/STATE.md`。Findngs 只留在對話中不算數；dev 的完成聲明沒寫進去就不會被檢查。
4. **Loop 有硬性上限** — 不允許無限打乒乓。達到上限就停下向 David 升級，帶著完整證據。
5. **每個功能都要有可開關、有日誌的 regression test** — dev 交付一個 item 不只交代碼，還要交該功能的 regression test（掛在專案統一的 regression 開關下，執行時輸出結構化日誌）。Checker 每輪開開關實跑全套 regression、讀日誌、並審計前端+後端功能覆蓋 — 漏測的功能就是 finding。
6. **Orchestrator 不自己寫代碼** — 協調者不做實際開發。所有實作委派給 dev agent；所有驗證委派給 checker agent。

---

## When to use

- **多 phase 專案**（Plan → BA → SA → Frontend + Backend → QA → Ship → Reflect）需要 task board 追整個 project 進度。
- **多 work item 的 feature 開發或重構** — 每步都要有品質 gate。
- **失敗成本高**（regression 風險、production 相關、安全敏感）。
- **David 明確要求**「dev-loop」、「checker agent」、「雙 agent 開發」、"quality gate"。

## When NOT to use

- 1-2 行 typo / 配置改動 — 直接做 + 自己跑最小驗證即可，loop 開銷不值得。
- 純研究 / 純閱讀任務 — 沒有代碼改動就沒有東西可 check。
- 該專案連最小驗證命令都跑不起來（無法安裝依賴等）— 先修好環境，否則 checker 無法實證。
- 單 US 改動，無歧義，失敗成本低 — 直做 + 自驗。

---

## Default path（2026-08-02 起）

對於多 item 的 feature 開發或重構，本 skill 是 Tree Monstor 的**預設路徑**（不是可選）— 詳見 `AGENTS.md` § Agent 開發預設路徑。Loop 只外加兩件事：(a) 開發單位記錄為 task board / STATE.md work items；(b) 每輪獨立 checker 實證覆核。原有流程（鐵律、Think/Plan、plan mode、skill routing）在 loop 內**全部照常適用** — loop 從不豁免任何原步驟。

---

## Subagent trigger table

> 讀到本 skill 後，Agent **必須按下面 table 自動 dispatch 對應 role**（用 `Agent` tool + `role=<name>`；`.claude/agents/<name>.md` 已預先定義）。唔需要 Agent 自己判斷派邊個 — table 就係 source of truth。

| Phase / 訊號關鍵詞 | 自動派 role | 派完產出 / 後續動作 |
|---|---|---|
| Phase 0 Think + 「市場規模 / 競爭 / SWOT / 定價」 | **CEO** | `docs/ceo-market-analysis.md` |
| Phase 0 Think + 「技術可行性 / 比較 X vs Y / 競品技術棧」 | **Researcher** | 調研報告 |
| Phase 1 Plan + 「用戶故事 / US / 需求 / AC」 | **BA** | `docs/US/<id>-<slug>.md` + 更新 PRD index |
| Phase 1 Plan + 「UI / wireframe / component / token」 | **Designer** | `docs/components/<Name>.md` + 更新 DESIGN index |
| Phase 1 Plan + 「架構 / 框架選型 / schema」 | **SA** | `docs/architecture/NNNN-<title>.md` |
| Phase 1 Plan + 「Pre-Build Gate / doc baseline」 | **Documentation Engineer** | `docs/qa-gate.md` §0A 跑過 |
| Phase 2 Build + 「前端 / React / Elysia-Bun / Tailwind」 | **Frontend** | 改 `src/components/` + 補 RT-XXX |
| Phase 2 Build + 「API / DB / Prisma / migration」 | **Backend** | 改 `src/api/` + 補 RT-XXX |
| Phase 2 Build + 「CI/CD / Docker / deploy」 | **DevOps** | 改 infra + regression switch |
| Phase 2 Build + 「auth / XSS / SQL injection / secret scan」 | **Security Engineer** | SAST/DAST 掃 + fix |
| Phase 3 Review + 「架構 / 安全性 / code quality」 | **SA Reviewer** | review report |
| Phase 3 Review + 「UI 合規 / 截圖比對 / RWD」 | **UX Reviewer** | review report + screenshots |
| Phase 4 Test + 「自動化測試 / E2E / User Simulation」 | **QA** | 測試報告 + regression suite pass |
| Phase 4 Test + 「load / k6 / benchmark / 瓶頸」 | **Performance Engineer** | 壓測報告 |
| Phase 5 Ship + 「部署 / rollback / monitoring」 | **Release Manager** | 部署確認 + smoke test |
| Phase 5 Ship + 「package.json 升級 / CVE」 | **Dependency Manager** | upgrade + CVE check |
| Phase 5 Ship + 「process 僵死 / tunnel 斷 / API 異常」 | **Observability Monitor** | alert + 通知 |
| Phase 6 Reflect + 「retro / 復盤 / lessons」 | **Retrospective** | `docs/retros/YYYY-MM-DD-<name>.md` |
| Phase 6 Reflect + 「sprint planning / 進度追蹤」 | **Sprint Manager** | sprint board + retro |
| Phase 6 Reflect + 「tech debt / 5-field format」 | **Tech Debt Tracker** | 更新 `docs/TECH-DEBT.md` |
| 任何 phase + 「context 過長 / summarise」 | **Context Manager** | 寫 `docs/context-summary.md` |
| Build 中 + 「bug fix / 舊 bug 復發 / RG-XXX」 | 觸發 `skills/regression-guard/`（不走 Agent tool dispatch） | red→green test + fix + RG entry |
| Plan 中 + 「新項目 / greenfield」 | 觸發 `skills/plan-author/` | modular plan docs |
| 接手 project | 觸發 `skills/existing-project-intake/` | source-first baseline |
| Review / QA feedback | 觸發 `skills/docs-sync/` | per-modular doc update |

### 使用方法

```python
# 在 orchestrator 流程中：
Agent(
    role="ba",          # ← 讀 .claude/agents/ba.md 嘅 description
    goal="為 US-005 filter 寫 acceptance criteria",
    context="PRD § US-005 已存在，spec 在 docs/US/US-005-filter.md"
)

# 多 subagent 並行派工：
parallel([
    Agent(role="frontend", goal="實作 Filter component", ...),
    Agent(role="backend", goal="補 filter API endpoint", ...),
])
```

### 22 個 role 嘅 .claude/agents/<role>.md 定義

每個 role 嘅 full description / tools / model 見 `.claude/agents/<role>.md`（canonical source）。Agent tool dispatch 時只用具 role name + brief goal；role 嘅完整 system prompt 由該 .md 提供。

---

## Plan doc standards（Plan-phase dispatch 必跟）

> 任何 Plan-phase agent dispatch（BA / Designer / SA / Documentation Engineer）所產出嘅 doc **必須**符合以下標準。呢啲標準由 `skills/plan-author/SKILL.md` 嘅 Workflow Step 4 定義，**orchestrator dispatch 唔可以放寬**。

| 標準 | 規則 | Reference |
|---|---|---|
| **Modular 結構** | Master (PRD / DESIGN / API / TEST-COVERAGE) + per-US / per-component / per-endpoint / per-coverage 子檔 | `docs/project-documentation-standard.md` § 文件 2/3/5/6 |
| **Templates** | 14 個 per-doc templates 必須直接用（唔好從頭寫） | `docs/project-doc-templates/` |
| **No-code rule** | Structural docs 唔含 source 語言 snippet；JSON schema / tables / ASCII wireframe OK | `docs/project-documentation-standard.md` § No-code-in-docs Rule |
| **US 編號** | `US-001`, `US-002`...;sub-task `US-001.1` | `docs/project-documentation-standard.md` § 文件 2 |
| **US status** | `DRAFT` / `IN_PROGRESS` / `DONE` / `DEPRECATED` 必填 | `us-template.md` |
| **AC format** | 每個 US AC 必係 Given / When / Then | `us-template.md` |
| **Component contract** | Props table + events list + a11y + states + token usage — **no source code example** | `component-contract-template.md` |
| **Endpoint contract** | Request / Response (JSON) + error code + test / RG 引用 | `endpoint-resource-template.md` |
| **ADR format** | Michael Nygard: Status / Context / Decision / Consequences / Alternatives | `adr-template.md` |
| **Cross-link** | Master index 表必須 link 到每個 per-X 檔 | `project-documentation-standard.md` |

**違反任何一條 = orchestrator dispatch 失敗**，要重做。

完整 workflow 細節見 `skills/plan-author/SKILL.md` Step 0-6。

---

# Outer loop — Multi-subagent orchestration

## 角色定位

**Orchestrator 是開發流程的指揮官** — 不是實際寫代碼的人，而是協調所有其他 subagent 確保任務順利完成的角色。

## 核心職責

| 職責 | 說明 |
|------|------|
| **任務分解** | 把大需求拆成可執行的 task |
| **任務調度** | 決定並行/串行執行順序 |
| **依賴管理** | 追蹤 task 間的 blocking 關係 |
| **進度追蹤** | 更新 Task Board |
| **結果收集** | 收集 subagent 產出並組裝 |
| **失敗處理** | 根據 Failure Policy 處理/升級 |

## Task Board 格式

```markdown
# Task Board — [項目名稱]

## 基本資訊
- 項目: [名稱]
- 開始時間: [時間]
- 總任務數: N
- 完成: X / N

## 階段狀態
| Phase | 狀態 | 負責 | 備註 |
|-------|------|------|------|
| Phase 0 BA | ✅ Done | BA Subagent | - |
| Phase 0.5 UI/UX | 🔄 In Progress | Designer | 70% |
| Phase 1 SA | ⏳ TODO | SA Subagent | 等待 BA 完成 |
| Phase 2 Frontend | ⏳ TODO | - | - |
| Phase 2 Backend | ⏳ TODO | - | - |
| Phase 3 Code Review | ⏳ TODO | - | - |
| Phase 4 QA | ⏳ TODO | - | - |

## 任務清單 (TODO)

### TODO
- [ ] TASK-005: 實現庫存預警通知功能
- [ ] TASK-006: 編寫庫存預警 API 文件

### In Progress
- [ ] TASK-004: 前端登入頁面
  - 負責: Frontend Subagent
  - 進度: 70%
  - Blocked by: TASK-003 (API 契約未確認)
  - 預計完成: 30分鐘

### Blocked
- [ ] TASK-004: 前端登入頁面
  - 原因: 等待 TASK-003 API 契約確認
  - 解除條件: SA 完成 API 契約文件

### Done
- [x] TASK-001: 需求分析 (BA Subagent) — 100% — 20分鐘
- [x] TASK-002: PRD 文檔編寫 — 100% — 15分鐘
- [x] TASK-003: API 契約設計 (SA Subagent) — 100% — 25分鐘

## 依賴圖
```
TASK-001 (BA) ──→ TASK-003 (SA) ──┬──→ TASK-004 (Frontend)
                   │              └──→ TASK-005 (Backend)
                   ↓
              TASK-002 (Design)
```

## 最近更新
- [HH:MM] TASK-004 開始執行，發現需要等待 TASK-003
- [HH:MM] TASK-001, TASK-002 完成，轉交 SA

## 阻塞清單
- TASK-004 blocked by TASK-003

## 失敗紀錄
(空)
```

## 工作流程

### Phase 0-1: 初始化專案

```python
# 1. 創建 Task Board
write_file(
    path="docs/task-board.md",
    content="# Task Board — [項目名]\n\n## 基本資訊\n..."
)

# 2. 派發 BA
delegate_task(
    goal="BA需求分析",
    context="...",
    role="leaf"
)

# 3. BA 完成後，派發 UI/UX
delegate_task(
    goal="UI/UX設計",
    context="...",
    role="leaf"
)

# 4. UI/UX 完成後，派發 SA
delegate_task(
    goal="SA架構設計",
    context="...",
    role="leaf"
)

# 5. 更新 Task Board
```

### Phase 2: 任務調度

```python
# 根據 SA 的輸出，拆解為具體 task
tasks = [
    {"id": "TASK-F001", "name": "前端登入頁面", "type": "frontend", "blocked_by": ["TASK-B001"]},
    {"id": "TASK-F002", "name": "前端庫存列表頁", "type": "frontend", "blocked_by": ["TASK-B001"]},
    {"id": "TASK-B001", "name": "認證 API", "type": "backend", "blocked_by": []},
    {"id": "TASK-B002", "name": "庫存 CRUD API", "type": "backend", "blocked_by": []},
]

# 分析依賴，確定並行度
parallel_tasks = find_non_blocked_tasks(tasks)  # 找出未被阻塞的任務
sequential_groups = group_by_dependency(tasks)  # 分組為 [group1, group2, ...]

# group1: 可並行執行
# group2: 等待 group1 完成

# 派發第一批（並行）
for task in parallel_tasks:
    delegate_task(
        goal=f"執行任務: {task.name}",
        context=f"TASK-ID: {task.id}\n{task.detail}",
        role="leaf",
        toolsets=["terminal", "file", "web"]
    )
```

對於每個 code-implementation task（type=frontend|backend|devops），派發時附帶「進入 inner loop」的 instruction：dev 完成後要寫 regression test、掛進開關、更新 STATE.md，spawn fresh checker 驗證。

### Phase 2: 進度追蹤與協調

```python
# 持續監控 subagent 進度
# 更新 Task Board

# 當 subagent 失敗
if subagent_failed:
    handle_failure(task_id, subagent_result)

# 當 subagent 完成
if subagent_completed:
    mark_done(task_id)
    unblock_dependent_tasks(task_id)
    dispatch_next_batch()
```

### Phase 3-4: 審查與測試

```python
# SA Code Review
delegate_task(
    goal="SA Code Review",
    context="...",
    role="leaf"
)

# QA Testing
delegate_task(
    goal="QA 測試",
    context="...",
    role="leaf"
)
```

## Failure Policy（失敗處理）

```markdown
## 失敗處理流程

### 等級 1: 可自動修復
- 例如: 網路短暫波動、port 被臨時占用
- 處理: 等待 30 秒後自動重試
- 嘗試次數: 3 次

### 等級 2: 需要修復後重試
- 例如: 代碼有 bug、邏輯錯誤
- 處理: 記錄錯誤，分析原因，修正後重新派發
- 嘗試次數: 2 次

### 等級 3: 升級處理
- 例如: 架構設計有誤、需要用戶決策
- 處理: 記錄失敗報告，等待 Developer 主體介入
- 通知: 向 Developer 主體發送失敗報告

### 失敗報告模板
```markdown
## Subagent Failure Report

### Task: TASK-XXX
### Subagent: [BA/SA/Frontend/Backend/etc]
### Failure Time: YYYY-MM-DD HH:MM
### Error Summary: [一句話描述]
### Detailed Error: [完整錯誤信息]
### Attempted Solutions: [嘗試過什麼]
### Root Cause (suspected): [懷疑原因]
### Next Action: [建議的解決方案]
### Blocking: [是否阻塞其他任務]
```
```

## Orchestrator 觸發方式

Developer 主體呼叫：

```python
# 初始化新專案
delegate_task(
    goal="初始化開發專案並建立 Task Board",
    context="""
    項目名稱: [名稱]
    用戶需求: [需求描述]

    請執行:
    1. 建立 docs/ 目錄
    2. 建立 docs/task-board.md (Task Board)
    3. 分析需求，拆解為初步 task 列表
    4. 派發 BA Subagent 開始需求分析
    5. 更新 Task Board
    """,
    role="orchestrator",
    toolsets=["terminal", "file", "web", "delegation"]
)

# 或接管現有專案
delegate_task(
    goal="接管現有開發專案",
    context="""
    項目路徑: /path/to/project
    請:
    1. 讀取現有的 PRD, Architecture, Design 文件
    2. 建立或更新 Task Board
    3. 分析當前進度和阻塞點
    4. 恢復執行
    """,
    role="orchestrator",
    toolsets=["terminal", "file", "web", "delegation"]
)
```

---

# Inner loop — Dev + checker verification

> 啟動 outer loop 後，每個 code work item 進入此 inner loop。

## Agent roles

| 角色 | 執行者 | 職責 | 禁止事項 |
|------|--------|------|----------|
| **Dev agent** | 主對話 / 主 agent | **按原有完整開發流程工作**（鐵律、plan mode、skill routing 照常），外加：拆解計畫為 work items；完成 item 時自跑最小驗證並更新 `docs/STATE.md`；**為每個功能型 item 寫 regression test 並掛進專案 regression 開關**；維護 STATE.md 的 Regression Coverage 表；回應 checker findings 並修復 | 不可跳過自我驗證直接標 DEV_DONE；不可為了讓 checker 通過而弱化/刪除測試；不可以「loop 在跑」為由省略原流程步驟；不可交付沒有 regression test 的功能型 item |
| **Checker agent** | 獨立 fresh subagent（每輪新 spawn） | 讀 STATE.md（含 Verification Commands、Resolved Findings、Regression Coverage）；按範圍讀 DEV_DONE items 的 diff；**實際執行**驗證命令；**開 regression 開關實跑全套 regression suite 並逐條讀日誌**；行為可見改動做 runtime 驗證；覆核 FIXED findings；**審計前端+後端功能的 regression 覆蓋**；對照 Goal 做完整性檢查；把 findings + 真實輸出證據寫回 STATE.md | 不可只讀 STATE.md 聲稱就下判斷；不可直接改實作代碼（發現問題交回 dev 修）；不可在沒跑驗證的情況下標 VERIFIED；不可無新證據重提已裁決 finding；不可用純懷疑標 blocker/major；不可只看 runner 的 exit code 不讀日誌內容 |

Checker 唯一允許的寫入是 `docs/STATE.md`（findings、evidence、狀態欄）。

## Regression harness contract（專案內的 regression test 基建）

Loop 啟動時，如果專案還沒有以下三件東西，**建立它們就是第一批 work items**（同樣走 dev→checker 流程檢查）：

### 1. Regression 開關

專案統一的開關控制 regression suite 是否執行，形式依專案技術棧（環境變數如 `REGRESSION_MODE=1`、test runner tag/filter 如 `--grep @regression`、或 npm/bun script 如 `test:regression`）。要求：

- **一個開關跑全套** — checker 不需要知道每個測試怎麼跑，開開關執行 runner 就是全部。
- 開關 off 時 regression suite 不干擾正常 dev/test 流程。
- 開關和 runner 命令記錄在 STATE.md 的 `Verification Commands` 表（`regression` 一行）。
- 沿用 [`regression-guard`](../regression-guard/SKILL.md) 的安全邊界：涉及 `/__qa/*` endpoints 或 runtime fixture 時，只在 dev/test/staging 掛載，production 必須 404/403；開關不得繞過 auth / 權限 / audit。

### 2. 結構化日誌輸出

開關 on 執行時，每條 regression test 輸出機器可讀的一行日誌（寫到 stdout 或約定的日誌檔，位置記錄在 Verification Commands 備註），至少含：

```text
[REGRESSION] <RT-ID> | <feature 名稱> | <frontend|backend|e2e> | PASS|FAIL | <耗時> | <失敗時：錯誤摘要>
```

結尾輸出總結行：`[REGRESSION SUMMARY] total=N pass=N fail=N skip=N`。要求日誌**逐功能可對賬** — checker 靠日誌行對照 Coverage 表，而不是只看 exit code。

### 3. STATE.md 的 Regression Coverage 表

專案所有用戶可見功能（前端頁面/交互 + 後端 endpoint/服務行為）的清單，每個功能對應它的 regression test。這是 checker 覆蓋審計的對賬單（格式見 File contract）。

- Loop 第一輪先盤點現有功能建立初版（existing project 可結合 [`existing-project-intake`](../existing-project-intake/SKILL.md)）。
- Dev 每完成一個功能型 item，必須同步在表中登記新功能和對應 `RT-XXX`。
- 純內部重構（無用戶可見行為變化）可標 N/A，但要寫理由。

### Dev 的每 item regression 義務

功能型 item 標 DEV_DONE 的前提，除了原有自驗，還包括：

1. 該功能的 regression test 已寫好、掛進開關、本地開開關跑過一次真實通過。
2. Coverage 表已登記（feature → `RT-XXX` → 類型 frontend/backend/e2e）。
3. 測試斷言的是**用戶可觀察的行為**（頁面渲染結果、API response、狀態變化），不是實作細節 — 這樣重構不會誤殺，真 regression 逃不掉。

## File contract: `docs/STATE.md`

位置：downstream project root 的 `docs/STATE.md`。**Committed**（不是 gitignored runtime state），保留審計線索。

模板：

```markdown
# STATE — <項目名>

> **Status:** Inner loop coordination state (within Orchestrator outer loop).
> **Goal:** <用戶需求一句話>
> **Round:** 3 / 10 (max)
> **Check depth:** normal | deep
> **Last updated:** YYYY-MM-DD HH:MM by <dev-agent|checker-agent>

## Verification Commands

<第一輪確立本專案的驗證命令，之後每輪 checker 直接使用，不重新摸索>

| 檢查 | 命令 | 備註 |
|------|------|------|
| typecheck | `bun tsc --noEmit` | |
| test | `bun test` | |
| regression | <開關 + runner，如 `REGRESSION_MODE=1 bun test:regression`> | 日誌位置：<stdout / 檔案路徑> |
| runtime smoke | <啟動方式 + 觀察路徑> | 行為可見改動必跑 |

## Regression Coverage

<專案所有用戶可見功能的對賬單。checker 每輪據此審計覆蓋；dev 新增功能必須同步登記>

| Feature | 類型 | RT-ID | 狀態 | 備註 |
|---------|------|-------|------|------|
| 登入流程 | frontend | RT-001 | COVERED | |
| POST /api/orders | backend | RT-002 | COVERED | |
| 訂單列表分頁 | frontend | — | **MISSING** | CK-012 |
| 內部 util 重構 | — | — | N/A | 無用戶可見行為，單元測試覆蓋 |

狀態: COVERED / MISSING / N/A(附理由)

## Work Items

| ID | 描述 | Spec | 涉及檔案 / commits | 狀態 | 打回次數 | 最後更新 |
|----|------|------|-------------------|------|---------|----------|
| WI-001 | 實作 US-001 登入 | `docs/US/US-001-login.md` | `src/auth.ts` / abc1234 | VERIFIED | 1 | ... |
| WI-002 | 補 US-002 註冊 | `docs/US/US-002-registration.md` | `src/api/x.ts` / def5678..HEAD | CHECK_FAILED | 2 | ... |

狀態: TODO / IN_PROGRESS / DEV_DONE / CHECKING / CHECK_FAILED / VERIFIED / ESCALATED

**Spec column 規則**（modular docs era，per `docs/project-documentation-standard.md` 2026-08-02）：

- 每個 WI 必須填 `Spec` column，reference 對應 per-US / per-component / per-endpoint / per-coverage 檔路徑
- 格式：`docs/US/<US-id>-<slug>.md` / `docs/components/<Name>.md` / `docs/endpoints/<resource>.md` / `docs/coverage/<US-id>.md`
- Spec 是 dev 跟 checker 對齊的單一真相；**不要 reference monolithic 檔（如「PRD.md § line 1234」）** — 那是 anti-pattern，會在 per-X 檔拆分後失效
- Spec 缺失 = 視同「涉及檔案 / commits」缺失，CHECK_FAILED（needs-info）

## Checker Findings (open)

### CK-003 — WI-002: <finding 標題>
- **Severity:** blocker | major | minor | needs-info
- **問題:** <具體問題>
- **證據:** <命令 + 真實輸出摘錄；blocker/major 必須是實際觀察到的失敗>
- **要求:** <dev 需要做什麼>
- **狀態:** OPEN / FIXED / DISPUTED

## Verification Evidence

| WI | 檢查 | 命令 | 結果 | 回合 |
|----|------|------|------|------|
| WI-001 | typecheck | `bun tsc --noEmit` | ✅ 0 errors | 2 |

## Resolved Findings

<CK-XXX 關閉後移到這裡，保留審計線索。含 DISPUTED 後被裁決不成立的 finding 及裁決理由>

## Escalation

<觸發升級時：原因、卡住的 item、已嘗試方案、需要 David 決定什麼>
```

規則：

- Work item ID 格式 `WI-XXX`，checker finding ID 格式 `CK-XXX`，regression test ID 格式 `RT-XXX`，各自遞增。`RT-XXX` 同時出現在測試代碼（測試名或註解）和日誌行，保持可對賬。
- 每次寫入必須更新 header 的 `Round` 和 `Last updated`（含寫入者身份）。
- Dev 標 DEV_DONE 時必須填「涉及檔案 / commits」欄 — checker 據此定位本輪 diff 範圍，不會被跨回合累積的整體 diff 淹沒。
- `Verification Commands` 由第一輪 checker（或 dev 啟動時）確立並持續修正；後續 checker 直接使用，省去每輪重新摸索專案。
- Finding 關閉後從 `Checker Findings (open)` 移到 `Resolved Findings`，不刪除。已裁決不成立的 finding 也要留在 Resolved 並記裁決理由 — 防止後續 fresh checker 重提。
- `Verification Evidence` 只接受真實執行過的命令 + 真實輸出摘錄；沒跑的檢查明確寫「未跑 + 原因」。
- `Check depth` 預設 `normal`；David 要求或 item 涉及 production / 安全敏感 / 高 regression 風險時可設 `deep`（見 Checker standards）。

## Loop lifecycle

```text
用戶需求（outer loop dispatch）
  → ┌─ Outer: Orchestrator 拆解為 task groups，分派 ─────────────────┐
    │ task groups 中每個 code-implementation task 進入 inner loop：
    │   dev: 拆解為 STATE.md work items
    │   ┌─ Round N ─────────────────────────────────────────┐
    │     │ dev: 取一個 TODO item → IN_PROGRESS               │
    │     │ dev: 小步實作 + 自跑最小驗證 → DEV_DONE           │
    │     │ dev: spawn fresh checker subagent                  │
    │     │ checker: 讀整份 STATE.md（commands/resolved 在內） │
    │     │ checker: 按範圍讀 DEV_DONE items 的 diff           │
    │     │ checker: 實際執行驗證命令 + runtime 行為驗證       │
    │     │ checker: 開 regression 開關跑全套 + 逐條讀日誌     │
    │     │ checker: 覆蓋審計（Coverage 表 vs 實際功能/日誌）  │
    │     │ checker: 覆核 FIXED findings（重跑原證據命令）     │
    │     │ checker: 完整性檢查（items 集合 vs Goal）          │
    │     │ checker: 寫 evidence + findings 回 STATE.md        │
    │     │   ├─ 無問題 → VERIFIED                             │
    │     │   └─ 有問題 → CHECK_FAILED + CK-XXX（打回次數+1）  │
    │     │ dev: 讀 STATE.md → 修復 open findings → 重新 DEV_DONE│
    │     └────────────────────────────────────────────────────┘
    │ task 全部 items VERIFIED → outer 標 task 完成，dispatch_next_batch()
    └────────────────────────────────────────────────────────────┘
  → 全部 task 完成、無 open blocker/major finding → 向 David 總結報告
  → 或觸發終止條件 → 寫 Escalation section → 停下問 David
```

- 一輪只推進一個（或少量高度相關的）work item — 小步改動，改完即驗證（鐵律 4）。
- 多個 DEV_DONE items 可以在同一次 checker run 一起檢查（省 subagent 開銷），但 findings 必須逐 item 記錄。

## Checker standards（檢查清單）

Checker 每輪的固定順序：

**Step 0 — 讀 context（先做，避免重複勞動和重提舊案）**

- 讀整份 `docs/STATE.md`，包括 `Verification Commands`（直接用，不重新摸索專案）和 `Resolved Findings`。
- **不得重提已裁決不成立的 finding**，除非有新證據（新 diff 觸及同一處、新的失敗輸出）；重提時必須引用新證據並註明與舊 finding 的差異。

**Step 1 — 逐 item 檢查（DEV_DONE items）**

1. **Diff 核對（按範圍）** — 依 Work Items 表的「涉及檔案 / commits」欄讀該 item 的 diff（`git diff <range> -- <files>`），核對代碼實際做的事是否符合 item 聲稱的行為，檢查明顯邏輯錯誤、遺漏邊界、hardcode。範圍欄缺失 = 直接 CHECK_FAILED（needs-info），要求 dev 補填。
2. **實證驗證** — 按 `Verification Commands` 實際執行該專案最小相關的 lint / typecheck / test / build，命令和真實輸出摘錄寫進 `Verification Evidence`。跑不了的檢查明確寫明什麼沒跑、為什麼。
3. **Runtime 行為驗證** — item 的改動行為可見時（UI、API endpoint、CLI 輸出、任何用戶可觀察的行為），靜態檢查不夠：實際啟動 app / 呼叫 endpoint / 走一次 happy path 並觀察行為（typecheck 通過不是 runtime 證明）。純內部重構且測試已覆蓋者可豁免，但要在 evidence 註明豁免理由。
4. **FIXED finding 覆核** — 對每個 dev 標了 `FIXED` 的 finding，**重跑該 finding 證據欄的原命令**（或重走原觀察路徑）並貼新輸出，確認該問題本身真的修好（而不是整體測試碰巧通過）。覆核通過才移進 Resolved Findings。
5. **Regression test 交付檢查** — 功能型 item 必須帶 regression test：測試存在且掛在開關下、`RT-XXX` 已登記 Coverage 表、斷言的是用戶可觀察行為而非實作細節。缺任一項 = CHECK_FAILED（major）。
6. **Bug fix 專項** — item 屬於 bug fix 時，依 [`regression-guard`](../regression-guard/SKILL.md) 標準檢查：有無重現證據、有無 red→green 測試、有無 `docs/REGRESSION-GUARD.md` entry 和 `RG-XXX` 代碼標記。
7. **Dev 流程合規** — 順帶檢查：diff 是否小步（一個 item 塞了多個無關邏輯改動 = major）；有無弱化 / 跳過 / 刪除測試的跡象（= blocker，升級）；行為 / API / 測試變更有無按專案規則同步文檔。

**Step 2 — Regression suite 全套執行 + 日誌檢查（每輪必做，不限本輪 items）**

1. 按 `Verification Commands` 的 `regression` 行，**開開關實跑全套 regression suite** — 不是只跑本輪 item 的測試。這是抓「本輪改動弄壞舊功能」的主要手段。
2. **逐條讀日誌**（`[REGRESSION]` 行），不是只看 exit code：
   - 任何 `FAIL` → 寫 `CK-XXX` finding（blocker），引用該日誌行 + 錯誤摘要，指向對應 feature 和 `RT-XXX`。
   - 日誌行數 / summary 與 Coverage 表 COVERED 條目對不上（表裡有 RT 但日誌沒出現 = 測試沒跑或被 skip）→ finding（major）。
   - Runner exit 0 但 summary 有 fail、或日誌格式壞掉無法對賬 → finding（major，harness 本身壞了也是問題）。
3. 全套結果（total/pass/fail + 失敗清單）寫進 `Verification Evidence`。

**Step 3 — Regression 覆蓋審計（前端 + 後端功能都要有測試）**

1. 盤點實際功能面：讀路由定義（前端 routes / 後端 endpoints）、對照 STATE.md Goal 和已 VERIFIED items，列出用戶可見功能清單。
2. 對照 `Regression Coverage` 表：
   - 實際存在但表裡沒有的功能 → 補進表標 `MISSING` + 寫 `CK-XXX` finding（major，coverage gap 類），要求 dev 補 regression test。
   - 表標 N/A 的條目抽查理由是否成立（有用戶可見行為卻標 N/A = finding）。
3. 本輪新增 / 修改的功能**必須**當輪覆蓋；存量缺口（loop 開始前就沒測試的舊功能）逐輪補 — 最後一輪結束時 Coverage 表不得有無 finding 記錄的 MISSING。

**Step 4 — 完整性檢查（對照 Goal，不只對照 items）**

- 對照 STATE.md header 的 **Goal**，判斷現有 work items 集合是否真的覆蓋用戶需求。逐 item 全 VERIFIED ≠ 需求完成。
- 發現缺口（漏掉的功能面、未處理的明顯場景）→ 寫 `SCOPE` 類 finding（`CK-XXX`，severity 按影響定），建議新增 work item。此檢查每輪都做，最後一輪（所有 items 都 VERIFIED 時）**必做**且要在摘要中明確回答「Goal 是否已被覆蓋」。

**證據門檻與 severity：**

| Severity | 含義 | 證據要求 | 對狀態的影響 |
|----------|------|---------|---------------|
| blocker | 功能錯誤、驗證失敗、regression 風險、弱化測試 | **必須附實際觀察到的失敗**（命令輸出 / runtime 行為） | 必須 CHECK_FAILED，計入打回次數 |
| major | 明顯品質問題（遺漏邊界、錯誤處理缺失、非小步 diff） | **必須附實際觀察到的失敗或具體代碼位置** | 必須 CHECK_FAILED，計入打回次數 |
| minor | 風格 / 可讀性 / 非必要優化 | 具體代碼位置即可 | 記錄 finding 但可 VERIFIED，dev 自行決定 |
| needs-info | 無法確認正確性、缺證據、範圍欄缺失 | 說明缺什麼、dev 要補什麼 | CHECK_FAILED，但**不計入打回次數** |

純懷疑（沒有觀察到的失敗）不得標 blocker/major — 標 needs-info 要 dev 補證據，或標 minor。這防止猜測性 finding 燒掉打回額度、製造假性乒乓。

**Deep 模式（header `Check depth: deep` 時）：**

- 對高風險 item（production 相關、安全敏感、高 regression 風險），dev 並行 spawn 2–3 個不同視角的 fresh checker：**正確性**（上述清單）、**regression**（會不會弄壞現有行為，跑既有測試全集 + RG guards）、**安全**（輸入驗證、權限、秘密洩漏）。
- 各自寫 findings 進 STATE.md（ID 不衝突：spawn 前 dev 在 prompt 裡分配 ID 區段）；任一 checker 標 blocker/major 即 CHECK_FAILED。
- Token 成本明顯較高，預設 normal；由 David 要求或 dev 判斷 item 風險後升級，並在 header 註明。

## Termination and escalation

| 條件 | 動作 |
|------|------|
| 全部 work items VERIFIED、無 open blocker/major finding、最後一輪 regression 全套 PASS、Coverage 表無未處理 MISSING、且 checker 明確確認 Goal 已被覆蓋 | Inner loop 正常結束，outer 標 task 完成，dispatch next batch（或全 project 收尾向 David 總結，引用 STATE.md evidence + regression summary） |
| 同一 work item 打回次數達 **3** | 該 item 標 ESCALATED，停 inner loop，寫 Escalation section，問 David |
| 總回合數達上限（預設 **10**，可在 STATE.md header 調整） | 停 inner loop，寫 Escalation section（含剩餘 items 狀態），問 David |
| dev 與 checker 對同一 finding 標 DISPUTED 往返達 **2** 次 | 停 inner loop，把雙方理據寫進 Escalation section，交 David 裁決 |
| checker 無法執行任何驗證命令（環境壞） | 停 inner loop，先向 David 報告環境問題 |

Escalation section 必須包含：卡住的 item、finding 全文、dev 已嘗試的方案、雙方證據、需要 David 決定的具體問題。**不允許靜默放棄或靜默降級標準。**

---

## Files owned

| File | Owner | Scope |
|---|---|---|
| `docs/task-board.md` | Orchestrator (outer loop) | Project-wide phases, dependencies, multi-role progress |
| `docs/STATE.md` | Orchestrator (inner loop) | Per-work-item: spec, diff range, evidence, findings |
| `docs/REGRESSION-GUARD.md` | regression-guard skill | Bug fixes (cross-cutting, applies to both loops) |
| `docs/QA-TRACKER.md` / `docs/TEST-COVERAGE.md` | doc baseline | US ↔ test status (cross-cutting) |
| `docs/_meta/dev-task-state.md` | dev-task-memory (retired runtime) | 中斷恢復仍走 Claude Code 內建機制 |

STATE.md 是 task board 上一個 task 內部 loop 用的；兩者獨立。大型多階段專案中，STATE.md 對應 task board 上一個任務的內部 loop。Bug fix item 兩者都要：RG entry + 掛進開關的 regression test。

---

## 與 Developer 主體的協作

```
Developer 主體
    │
    ├── 收到用戶需求
    │
    ├── 觸發 Orchestrator（outer + inner 一體）
    │       │
    │       ├── Outer: 派發 BA/SA/Designer/Frontend/Backend/DevOps
    │       │         管理 Task Board
    │       │         跨 task dependency
    │       │
    │       └── 對每個 code-implementation task:
    │           Inner: dev + checker loop
    │           STATE.md 協調
    │           regression test + 結構化日誌
    │
    └── 接收 Orchestrator 的彙報
            │
            ├── Phase 完成通知
            ├── 失敗升級報告（outer: 等級 3 / inner: ESCALATED）
            └── 用戶需要決策的問題
```

**Developer 主體的職責：**
- 接收用戶需求
- 觸發 Orchestrator
- 處理升級報告
- 做重大決策（架構變更、用戶決策）
- 最終交付確認

---

## 關鍵原則

1. **不要自己寫代碼** — 協調者不做實際開發；委派給 dev agent。
2. **進度透明** — Outer 寫 Task Board；Inner 寫 STATE.md。
3. **依賴要清晰** — outer 知道什麼 task 在等什麼 task；inner 知道什麼 item 在等什麼 item。
4. **失敗要記錄** — 失敗不可怕，可怕的是失敗了不知道。outer 用 3 級 Failure Policy；inner 用 ESCALATED section。
5. **定期上報** — 每完成一個 phase / task，向 Developer 主體彙報。
6. **Loop 不豁免原流程** — 鐵律、Think/Plan、plan mode、skill routing 全部照常。Loop 只外加 (a) 開發單位記錄 + (b) 獨立 checker 覆核。

---

## Pitfalls

0. **把 loop 的精簡步驟當成完整開發流程 = 最常見誤用。** Loop lifecycle 描述的是協作節奏，不是開發方法；dev 階段的開發方法永遠是原有流程（鐵律 + Think/Plan + skill routing）。實測發現 dev agent 跑 loop 時會退化成只照 loop 步驟走、丟失原流程 — 所以本檔明文：loop 從不豁免任何原有步驟。
1. **Checker 只看 STATE.md 聲稱不看代碼 / 不跑命令 = 失職。** VERIFIED 沒有 evidence 行支撐就是無效判定。
2. **Dev 為了讓 checker 通過而弱化、跳過或刪除測試 = 紅線。** 發現此行為時 checker 必須標 blocker 並升級。
3. **Findings 只留在 subagent 回覆、沒寫進 STATE.md = 不算數。** 下一輪 checker 是 fresh 的，STATE.md 是唯一協作媒介。
4. **同一個 checker context 重用多輪** — 會累積對 dev 實作的熟悉和偏見，失去獨立性。每輪必須 fresh spawn。
5. **沒設回合上限就開 loop** — 收斂不了的問題會無限燒 token。開 loop 前 header 必須有 max round。
6. **把 STATE.md 當 dev 的個人筆記** — 它是兩個 agent 的協作契約，格式亂了 checker 會漏檢。遵守模板欄位。
7. **逐 item 全 VERIFIED 就宣告完成 = 漏了完整性檢查。** Items 是 dev 自己拆的，拆漏了 checker 逐 item 檢查也看不見；最後一輪必須對照 Goal 確認覆蓋。
8. **靜態檢查通過就放行行為可見的改動 = runtime 盲區。** TypeScript / lint 通過不是 runtime 證明；UI / API / CLI 行為改動必須實際跑起來觀察。
9. **Fresh checker 重提已裁決的舊 finding = 假性乒乓。** Step 0 先讀 Resolved Findings；無新證據不得重提。
10. **只看 regression runner 的 exit code = 白裝了日誌。** Runner 可能吞掉失敗、skip 掉測試而 exit 0；checker 必須逐條對賬日誌行和 Coverage 表。
11. **Regression test 斷言實作細節而非用戶可觀察行為** — 重構時大片誤報，dev 為了過檢查開始刪測試，整個 harness 失去公信力。寫測試時就要斷言行為。
12. **Coverage 表只登記不維護** — 功能改名 / 刪除後表沒更新，checker 對賬全是噪音。dev 改動功能時同步維護表。
13. **Work Item Spec 欄 reference monolithic 檔（舊 anti-pattern）** —「US-001 in PRD.md § line 1234」會在 modular 拆分後失效，checker 找不到對應行。**Spec 必須 reference per-US / per-component / per-endpoint / per-coverage 檔路徑**。Spec 缺失或指向 monolithic 檔 = needs-info finding。
14. **Per-US spec changelog 沒同步更新** — dev 改 code 完成 WI-XXX，但 `docs/US/<US-id>-<slug>.md` 的 changelog / 狀態欄位沒更新，checker 看 spec 還停留在舊狀態。dev 完成 DEV_DONE 時必須：(a) 更新 Spec 的狀態欄；(b) append changelog 行（含 commit SHA + 簡述）。Checker 看到 Spec 狀態與 STATE.md DEV_DONE 不一致 = minor finding 要求同步。
15. **Outer loop 跳過 inner loop = 沒 quality gate** — 派發完 code task 後沒要求 dev+checker iteration = task 不算真正完成。「Frontend 已交付」 ≠ 「Frontend VERIFIED」。outer 標 Done 必須 inner 全部 items 都 VERIFIED。
16. **Inner loop 越界到 outer 範圍** — inner 是 per-work-item，**不處理跨 task dependency / phase 進度**。那是 outer + Task Board 的職責。

---

## References

- [`references/subagent-recovery-patterns.md`](references/subagent-recovery-patterns.md) — trust-but-verify on `completed`, early-stop signals for typecheck loops, stuck-main-agent detection + recovery procedure, pre-`git push` audit. Compact patterns folded from the now-archived `agent-stuck-recovery` + `subagent-timeout-recovery` skills.

---

## Claude Code runtime note

在 Claude Code 中，Orchestrator 是主對話本身 + 委派給 subagent 的組合。Dev agent = 主對話；Checker 用 Agent tool spawn general-purpose subagent。

**Slash command**：`/dev-loop` 透過 `adapters/claude-code/skills/dev-checker-loop/SKILL.md`（已 redirect 到本檔）觸發 inner loop 的快速啟動。`/orchestrator` 透過 `adapters/claude-code/skills/orchestrator/SKILL.md` 觸發 outer loop。兩個 adapter 都導向本 canonical 檔，行為一致。

---

## Related docs

- [Regression Guard](../regression-guard/SKILL.md) — bug fix 驗證標準
- [Docs Sync](../docs-sync/SKILL.md) — findings 影響需求/設計/測試時同步文檔
- [Existing Project Intake](../existing-project-intake/SKILL.md) — 接手現有 project 的入口
- [Structural Doc Batch](../structural-doc-batch/SKILL.md) — 補 / 重做結構性 doc
- [Task Board rules](../../docs/task-board.md) — outer loop 嘅 project-wide task board 格式
- [QA Gate](../../docs/qa-gate.md) — 出貨品質關卡
- [Skills catalog](../README.md)