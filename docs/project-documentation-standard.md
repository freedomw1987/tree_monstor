# 項目文檔規格（Project Documentation Standard）

> **Status:** Standard. Source of truth for project documentation requirements and commit expectations.

> **為什麼要有這份規格** — David 在 2026-06-06 的 kanban task 明確指出：
> 「用戶給您需求，您要和他設計及思考。我想要您可以落實了之後，多些在項目中編寫文件，包括設計、架構及技術文件。」
>
> 換句話說:**在 Think/Plan 階段跟用戶口頭對齊之後,落實的時候必須把共識寫進項目文件**,而不是停留在對話紀錄。
>
> 之前 `docs/phases.md` 講了要產 `prd.md` / `design.md` / `architecture.md`,但**沒有強制每個 project 必須包含**,也沒有 commit 規範。**這份文件就是補這個洞。**

---

## 🗂️ 強制文件清單（每個 project 必須有）

| # | 文件 | 路徑 | 負責階段 | 何時 commit |
|---|------|------|---------|------------|
| 1 | Project Overview | `docs/PROJECT-OVERVIEW.md` | Think + Plan | Plan 結束時(跟首個 code commit 一起) |
| 2 | Product Requirements (PRD) | `docs/PRD.md` | Plan | Plan 結束時 |
| 3 | Design Spec | `docs/DESIGN.md` | Plan | Plan 結束時(設計定稿時) |
| 4 | Architecture Decision Records (ADR) | `docs/architecture/0001-*.md` | Plan + Build | 每個重大架構決策即時寫 |
| 5 | API Reference | `docs/API.md` | Build | 每個 endpoint 上線前 |
| 6 | Test Coverage Report | `docs/TEST-COVERAGE.md` | Test | 每個 sprint 結束時 |
| 7 | Tech Debt Register | `docs/TECH-DEBT.md` | Build + Reflect | 發現就記,每 sprint review |
| 8 | Retrospective | `docs/retros/YYYY-MM-DD-<feature>.md` | Reflect | 每個 feature/incident 完成後 |
| 9 | Verify Commands | `docs/VERIFY.md` | Plan + Build | 首個 code commit 前(跟 baseline 一起) |

**紅線:任何 project 在 ship 之前,1-7 號及 9 號文件必須存在 + commit 到 git**。

---

## 🧭 Documentation-First Rule（Build 前強制）

> **核心原則**：Think / Plan 的共識必須先變成 project docs，才可以進入 Build。對話紀錄會消失，git 裡的文檔才是可交接、可驗收、可 QA 的真相。

### Baseline vs Final

Build 前要求的是 **baseline / skeleton / N/A**，不是所有細節 final；但 baseline 必須足以回答：做什麼、為誰做、驗收標準是什麼、架構決策是什麼、測試計劃是什麼。

| 文件 | Build 前 baseline | Build 中更新 | Ship 前 final |
|------|------------------|-------------|---------------|
| `docs/PROJECT-OVERVIEW.md` | 一句話、目標用戶、scope、成功標準 | scope / KPI / risk 變更即更新 | 反映最終 scope 與風險 |
| `docs/PRD.md` | P0/P1 US + acceptance criteria | 新需求 / 修正 / 刪減即更新 changelog | 所有 shipped US 最新 |
| `docs/DESIGN.md` | UI/UX baseline；無 UI 標 N/A | UI、component、layout、token 變更即更新 | 與實作一致 |
| `docs/architecture/0001-*.md` | 至少一個初始 ADR / architecture decision | 重大架構決策即新增 ADR | 所有重大決策可追溯 |
| `docs/API.md` | API contract draft；無 API 標 N/A | endpoint、request、response、error code 變更即更新 | 與實際 API 一致 |
| `docs/QA-TRACKER.md` | 每個 PRD US 有對應 row | PRD 改即同步，P0/P1 test task 保持最新 | 無 PRD ↔ tracker drift |
| `docs/TEST-COVERAGE.md` | test plan skeleton | 測試新增 / 變更 / coverage gap 即更新 | US → test 對照完整 |
| `docs/TECH-DEBT.md` | register skeleton | debt、refactor、dependency、trade-off 發現即記 | 已知 debt 完整 |
| `docs/VERIFY.md` | lint / typecheck / test / build 各一條命令或 N/A + reason | 驗證命令變更（scripts、tooling）即更新 | 命令與專案實際 tooling 一致 |

**Build-blocking rule**：baseline 不存在、PRD 與 QA-TRACKER 不同步、或 API / Design / ADR / Test / Tech Debt 沒有 baseline / N/A 說明時，任務停留在 Plan，不能開始 Build。

### Existing Project Intake / Bootstrap Mode

**Greenfield project**：用一鍵 bootstrap 生成全套 baseline skeleton（不覆蓋既有檔案，生成後自動跑 `--project-docs` 檢查）：

```bash
python3 <profile-root>/scripts/bootstrap_project.py --root <project-root> --name "<Project Name>"
```

現有 project 未必一開始就有完整 docs baseline。接手 existing / inherited project 時，先執行 `skills/existing-project-intake/SKILL.md`，用 source-first intake 建立真實現狀，而不是直接套用理想模板或憑記憶補文件。bootstrap 腳本在 existing project 只可用來補「確實缺失」的 skeleton（它會跳過既有檔案），不可取代 source-first intake。

原則：

- 不 fabricate missing PRD / API / design details；source code、routes、schemas、tests、git history、existing docs 才是 evidence base。
- 如果 docs 與 source 矛盾，標記 docs stale，並以 source-derived baseline 更新。
- Unknown details 必須標 `TBD`、`Unknown` 或 `N/A + reason`。
- 第一個 code change 前，至少要為受影響範圍建立 task-scoped baseline：affected requirement、API/design behavior、test/regression plan、QA tracker row。
- 非當前任務需要的缺失 docs，可記入 `docs/TECH-DEBT.md` 或 intake report follow-up；不可 silently ignore。
- 缺 `/__qa/*` endpoint 不自動阻擋 Build；intake 必須判斷 requested task 是否真的需要 deterministic QA hook。
- 行為變更、bug fix、API/design/test 變更仍必須在 Build / Ship 前更新受影響 docs。

### 需求變更同步 Protocol

David 在 Build 中、Review 後、Test 後或 Ship 前提出新需求 / 修正時，先停手做 doc sync：

| 變更類型 | 必須同步文檔 |
|---------|-------------|
| scope / business goal / 成功標準 | `docs/PROJECT-OVERVIEW.md` + `docs/PRD.md` + `docs/QA-TRACKER.md` |
| 新增 / 修改 / 刪除 User Story | `docs/PRD.md` + `docs/QA-TRACKER.md`（新 US 加 row，改 US 標 PARTIAL，刪 US 標 DEPRECATED） |
| UI / component / layout / token | `docs/DESIGN.md` + `docs/TEST-COVERAGE.md` |
| API contract / endpoint / error code | `docs/API.md` + `docs/TEST-COVERAGE.md` |
| 新增 / 修改 / 刪除 `/__qa/*` endpoint 或 regression hook | `docs/API.md` + `docs/TEST-COVERAGE.md` + `docs/QA-TRACKER.md`；如 bug / `RG-XXX` 相關則加 `docs/REGRESSION-GUARD.md`；如 frontend QA panel 則加 `docs/DESIGN.md`；如引入 test tenant / fake mailbox / test clock / queue drain 等 test-only architecture 則新增 ADR |
| 架構 / data model / infrastructure | 新 ADR + 受影響文檔 |
| test plan / coverage | `docs/QA-TRACKER.md` + `docs/TEST-COVERAGE.md` |
| refactor / dependency / known trade-off | `docs/TECH-DEBT.md` |
| bug fix | `docs/REGRESSION-GUARD.md` + `docs/TEST-COVERAGE.md` + 相關 US row 備註 |
| 驗證命令 / test runner / build tooling 變更 | `docs/VERIFY.md` |

### Review Feedback → Docs Sync Protocol

Review / QA / code-review feedback 在改變 scope、acceptance criteria、design、API、architecture、test coverage、regression behavior 或 known debt 時，即屬於 durable project knowledge，不能只留在 chat、PR comments 或臨時 notes。

一個 feedback item 只有在以下任一條件成立時才算完成：

1. suggestion 已 apply，且受影響 docs 在同一 change 中同步更新；
2. suggestion 已 defer，且 defer 原因記錄在 `docs/TECH-DEBT.md`、`docs/QA-TRACKER.md` 或受影響 doc 的 changelog / notes；
3. suggestion 已 reject，且 reject rationale 記錄在受影響 doc 或 review summary。

最小同步 mapping：

| Feedback type | Required docs |
|---|---|
| requirement / acceptance criteria | `docs/PRD.md` + `docs/QA-TRACKER.md` |
| UI / UX / component / layout | `docs/DESIGN.md` + `docs/TEST-COVERAGE.md` |
| API / wire shape / error code | `docs/API.md` + `docs/TEST-COVERAGE.md` |
| architecture / data model / infrastructure | ADR under `docs/architecture/NNNN-<short-title>.md` + affected docs |
| test gap / QA finding | `docs/QA-TRACKER.md` + `docs/TEST-COVERAGE.md` |
| bug / regression risk | `docs/REGRESSION-GUARD.md` + `docs/TEST-COVERAGE.md` + related tracker row |
| refactor / cleanup / trade-off | `docs/TECH-DEBT.md` |

Operational workflow 見 `skills/docs-sync/SKILL.md`。

### Commit expectations

- 首個有意義 code commit 之前，必須已有 documentation baseline commit；如同一 commit 包含 baseline docs + 初始 scaffolding，可接受但要清楚標示。
- PRD 改動必須與 QA-TRACKER 改動同 commit / 同 PR；否則視為未完成。
- Code 改動必須與受影響文檔同 commit / 同 PR；否則視為 doc-code drift。


## 📄 文件 1 — PROJECT-OVERVIEW.md

**目的**:讓任何新人(包含 3 個月後的自己)在 5 分鐘內掌握這個 project 嘅全貌。

**必填區塊**:
```markdown
# <Project Name> — Project Overview

## 一句話
[這個 project 做什麼,用一句非技術語言解釋]

## 目標用戶
- 主要: [誰會用]
- 次要: [誰會間接受影響]

## 核心價值主張
- 用戶用呢個 project 解決咩問題?
- 跟現有方案比,我們的差異點是?

## 成功標準
- KPI 1: [具體可量度,例:DAU > 1000]
- KPI 2: ...

## 範圍 (Scope)
- ✅ In scope: [做咩]
- ❌ Out of scope: [不做咩,防止 scope creep]

## 主要 Risk
- Risk 1: [風險] → Mitigation: [應對]
- Risk 2: ...

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-06-06 | 初版 | 從 kanban task t_c658eba4 開始 |
```

**更新時機**:
- 每次 scope 變更
- 每季度 review 一次
- 不能在 commit 之前(必須跟首個 code commit 同步入 git)

---

## 📄 文件 2 — PRD.md (Product Requirements Document)

**目的**:把口頭討論的 user stories 變成可驗收的規格。

**必填區塊**:
```markdown
# <Project Name> — PRD

## User Stories

### US-001 — [一句話標題]
**As** [誰] **I want** [做咩] **so that** [為什麼]

**優先級**: P0 / P1 / P2 / P3
**驗收標準**:
- [ ] Given [前置條件], when [動作], then [預期結果]
- [ ] ...
**Out of scope**: [呢個 story 唔做咩]
**依賴**: [依賴邊啲 US 或外部系統]

### US-002 ...

## Non-Functional Requirements
- 效能: [response time < 200ms (p95)]
- 安全: [敏感資料加密儲存,API rate limit 100 req/min]
- 兼容性: [支援 Chrome/Firefox/Safari 最新兩個 major version]
- 可用性: [99.9% uptime,允許每月 43 分鐘 downtime]

## 假設與風險
- 假設: [假設咗咩,例:用戶有 Gmail]
- 風險: [風險列表]

## 變更紀錄
| 日期 | US ID | 變更 | 原因 |
|------|-------|------|------|
```

**User Story 編號規則**:`US-` + 3 位數（`US-001`, `US-002` ...）；如需拆細 sub-task，可用 `US-001.1` / `US-001.2`。**所有 test case 都引用 US 編號**。

**更新時機**:
- 每次新功能加入 → 新增 US
- 每次需求變更 → 修改 US + 標記 change log
- 刪除 US → 標記 "DEPRECATED" 而非真的刪除(保留歷史)

---

## 📄 文件 3 — DESIGN.md (Design Spec)

**目的**:UI/UX 的「單一真相來源」,所有 frontend 開發都依此實作。

**必填區塊**(沿用 `docs/phases.md` §Plan 嘅標準):
```markdown
# Design Spec — <Project Name>

## Overview
- 設計理念、品牌定位
- 目標用戶畫像
- 設計參考(inspiration links)

## Design Tokens
### Colors
| Token | HEX | 用途 |
|-------|-----|------|
| --color-primary | #FF6B35 | CTA, 強調 |
| --color-bg | #FFFFFF | 背景 |
| ... | ... | ... |

### Typography
| Token | Font | Size / Line-height | Weight | 用途 |
|-------|------|-------------------|--------|------|
| --text-h1 | Inter | 32/40 | 700 | 頁面標題 |
| --text-body | Inter | 16/24 | 400 | 內文 |
| ... | ... | ... | ... | ... |

### Spacing
- 4px grid system
- --space-1: 4px
- --space-2: 8px
- --space-3: 16px
- --space-4: 24px
- --space-5: 32px

### Elevation
| Token | CSS | 用途 |
|-------|-----|------|
| --elevation-1 | box-shadow: 0 1px 3px rgba(0,0,0,0.12) | Card |
| --elevation-2 | box-shadow: 0 4px 6px rgba(0,0,0,0.16) | Modal |
| ... | ... | ... |

### Shapes
- Border radius: 4px (small), 8px (medium), 16px (large)

## Components
### Button
- Variants: primary / secondary / ghost
- Sizes: sm / md / lg
- States: default / hover / active / disabled / loading
- 用法: [example code]

### Input
- ...

### Card
- ...

## Page Layouts
### Home
- [ASCII wireframe 或 圖片連結]
- 互動規格

### Login
- ...

## Do's and Don'ts
- ✅ Do: 文字按鈕至少 44x44px
- ❌ Don't: 顏色用純黑/純白(用 neutral 9 / neutral 1)

## Changelog
| 日期 | 變更 | 原因 |
```

**更新時機**:
- 加新 component → 加 component 段落
- 改 token 值 → 全文件搜尋影響範圍
- 設計大改 → 升 version (`v1.0` → `v2.0`),保留舊版

---

## 📄 文件 4 — Architecture Decision Records (ADR)

**目的**:把架構決策**為什麼這樣選**記下來,避免 6 個月後「點解當初用 PostgreSQL 而唔用 MongoDB?」

**位置**:`docs/architecture/NNNN-<short-title>.md`(NNNN 是 4 位數,單調遞增)

**模板**(沿用 Michael Nygard ADR 格式):
```markdown
# ADR-0001 — <簡短標題>

## Status
- Proposed / Accepted / Deprecated / Superseded by ADR-XXXX

## Context
[面對咩問題?有咩 constraints?有咩 forces?]

## Decision
[揀咗咩方案?具體講做咩。]

## Consequences
### Positive
- 好處 1
- 好處 2
### Negative
- 壞處 1
- 壞處 2
### Neutral
- 中性影響

## Alternatives Considered
### 方案 A — [名]
- 優: ...
- 缺: ...
- 不選原因: ...

### 方案 B — [名]
- ...

## References
- [相關連結]
```

**範例 ADR**:
- `0001-use-postgres-for-primary-db.md`
- `0002-monorepo-vs-polyrepo.md`
- `0003-jwt-vs-session-auth.md`
- `0004-tailwind-v4-with-vite.md`

**規則**:
- **一個 ADR 一個決策**(不要一篇寫 5 個決策)
- **永遠不要修改已 Accepted 的 ADR**,要改就寫新 ADR 並在舊 ADR 標 `Superseded by ADR-XXXX`
- **用 git 歷史保留時序**

---

## 📄 文件 5 — API.md (API Reference)

**目的**:每個 endpoint 的 contract(輸入、輸出、錯誤碼、範例)。

**必填區塊**:
```markdown
# API Reference — <Project Name>

> Base URL: `https://api.example.com/v1`
> Auth: Bearer JWT in `Authorization` header

## Endpoints

### POST /auth/login
**描述**: 用戶登入,回傳 access token

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "string (8+ chars)"
}
```

**Response 200**:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "...",
  "expires_in": 3600
}
```

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 400 | INVALID_EMAIL | Email 格式錯 |
| 401 | INVALID_CREDENTIALS | 帳號/密碼錯 |
| 429 | RATE_LIMIT | 1 分鐘內超過 5 次 |

**對應 US**: US-001
**對應 Test**: [link to test file]
**變更歷史**: v1.0 (2026-06-06) 初版

### GET /users/{id}
...

## QA / Regression Endpoints

> Scope: dev/test/staging only. Production must not mount `/__qa/*` or must hard reject before side effects.

| Method | Path | Purpose | Auth / Guard | Data Scope | Audit | Production Behavior | Related US/RG |
|--------|------|---------|--------------|------------|-------|---------------------|---------------|
| POST | /__qa/seed | Seed deterministic fixture | QA secret + staging auth | test tenant only | yes | 404 / 403 | US-001 / RG-001 |

### POST /__qa/seed
**描述**: Idempotently seed regression fixture for a `US-XXX` or `RG-XXX` scenario.

**Allowed caller**: QA / CI / test automation only.
**Allowed environments**: dev/test/staging only.
**Production behavior**: Not mounted or returns 404 / 403 before side effects.
**Auth / access control**: QA secret / staging SSO / IP allowlist / authenticated test role.
**Tenant / data scope**: test tenant / test DB / test schema only.
**Side effects**: No real email / SMS / payment; sandbox / fake services only.
**Audit event**: Record actor, endpoint, tenant, US/RG, fixture version.
**Idempotency**: Safe to rerun.
**對應 US/RG**: US-001 / RG-001
**對應 Test**: `test:regression:rg -- RG-001` or equivalent.
**Safety verification**: production 404 / 403; `REGRESSION_MODE=true` production hard fail / reject.
```

**生成方式**:
- 手工維護(小 project)
- 半自動:`auto-doc-gen` skill 從 JSDoc/TSDoc 生成,人手修飾
- 完全自動:OpenAPI/Swagger codegen

**更新時機**:
- Build 前 → 先寫 API contract draft；無 API 則明確標 N/A
- 新 endpoint → 加段落 + commit
- Request / response / error code 改動 → 同步更新 endpoint contract + TEST-COVERAGE
- Breaking change → 升 major version,保留舊版文件

---

## 📄 文件 6 — TEST-COVERAGE.md

**目的**:把測試從「有跑過」變成「系統性覆蓋」。

**必填區塊**:
```markdown
# Test Coverage — <Project Name>

> 最後更新: YYYY-MM-DD
> 總體覆蓋率: X% (statement / branch / function / line)

## User Story → Test Case 對照

| US | 描述 | Unit | Integration | E2E | 狀態 | 備註 |
|----|------|------|-------------|-----|------|------|
| US-001 | 登入 | ✅ 3 | ✅ 1 | ✅ 1 | PASS | |
| US-002 | 註冊 | ✅ 5 | ✅ 2 | ❌ 0 | PARTIAL | E2E 待補 |
| US-003 | 忘記密碼 | ✅ 2 | ✅ 1 | ✅ 1 | PASS | |
| ... | ... | ... | ... | ... | ... | ... |

## 測試金字塔分佈
- Unit tests: N
- Integration tests: M
- E2E tests: K
- Manual smoke tests: L

## Regression Mode / Hooks

| ID | Type | US/RG | Frontend hook | Backend hook | QA enablement | Test command | Env | Production safety | Status |
|----|------|-------|---------------|--------------|---------------|--------------|-----|-------------------|--------|
| RG-001 | Bug regression | RG-001 / US-001 | `data-testid=login-form` | `/__qa/regression/RG-001` | `qa:seed -- RG-001` | `test:regression:rg -- RG-001` | dev/test/staging | `/__qa/*` not mounted in production | READY |
| US-002 | P0 flow | US-002 | fake mailbox panel | `/__qa/mailbox` | `qa:seed -- US-002` | `test:regression:e2e` | staging | sandbox mailbox only | PARTIAL |

## 已知未覆蓋區域
- [ ] US-005 edge case: empty list
- [ ] US-012 性能測試未做
- [ ] US-020 a11y 測試

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-06-06 | 初版 | 從 kanban task t_c658eba4 開始 |
```

**更新時機**:
- 每個 sprint 結束
- 重大功能上線前
- 新增 / 修改 regression hook、`/__qa/*` endpoint、QA panel、test fixture、fake mailbox、test clock 時
- 詳見 `docs/qa-tracker.md`

**Regression rule**:`docs/REGRESSION-GUARD.md` 不是無 bug project 的必備文件；但 project 一旦有 bug fix / `RG-XXX` entry，就必須存在，且 `TEST-COVERAGE.md` 必須在 Regression Mode / Hooks matrix 收錄對應 QA 啟用方式。

**`/__qa/*` hook rule**:Backend hook 以 `/__qa/` 開頭時，必須在 `docs/API.md` 的 QA / Regression Endpoints section 有對應 endpoint contract。該 row 的 `Production safety` 不可留空，且必須明確寫 production not mounted / 404 / 403 / hard reject、test tenant / test DB / test schema scope、auth / secret / allowlist。`READY` row 必須同時有 test command、QA enablement、environment 與 production safety。

---

## 📄 文件 7 — TECH-DEBT.md

**沿用 `skills/tech-debt-register/SKILL.md` 既模板**(已存在),**新要求**:
- 必須 commit 入 git(放 `docs/TECH-DEBT.md`)
- 每個 sprint planning 必須 review
- 重大 debt (P0/P1) 必須有對應嘅 ticket ID

---

## 📄 文件 8 — Retrospective

**位置**:`docs/retros/YYYY-MM-DD-<short-name>.md`

**必填區塊**:
```markdown
# Retrospective — <Feature> — YYYY-MM-DD

## 概述
- 做了什麼
- 涉及哪些 user stories
- 花了多少時間(預估 vs 實際)

## 做得好的
1. ...
2. ...

## 需要改進的
1. ...
2. ...

## 關鍵教訓 (Lessons Learned)
1. ...
2. ...

## 決策回訪（每次 retro 必做一個）
- 抽查對象: [隨機抽一個過去的 ADR / 技術選擇 / Think-Plan 決策]
- 當初的理由: [當時為什麼這樣選]
- 以現在所知: [會不會選不同？為什麼]
- 結論: [維持 / 需要新 ADR 修正 / 記入 TECH-DEBT]

## 下次改進 Action Items
- [ ] AI: ...
- [ ] Owner: ...
- [ ] Due: YYYY-MM-DD

## 對文件的更新
- [ ] TECH-DEBT.md 新增項目
- [ ] 設計 token 需要更新
- [ ] ADR 需要新增
```

**更新時機**:
- 每個 feature 完成後
- 每次重大 incident 之後
- 每個 sprint 結束時(sprint retro)

**決策回訪 rule**：incident 驅動嘅改進只會修正「出咗事」嘅決策；安靜嘅次優決策（架構其實唔啱、更好方案冇上桌）唔會自己浮現。所以每次 retro 必須隨機抽一個過去嘅 ADR / 技術選擇，用「以現在所知會唔會選唔同」重新審視一次，結論寫入 retro。答案係「會」時，開新 ADR（標 Supersedes）或記入 `docs/TECH-DEBT.md`，唔可以只留喺 retro。

---

## 📄 文件 9 — VERIFY.md (Verify Commands)

**目的**:紅線 55（實證驗證）的**執行入口**。把「這個專案的最小驗證命令是什麼」寫死在一個固定位置，agent 交付前照跑，不用每次重新推斷、不會跑錯或漏跑。

**必填區塊**:
```markdown
# Verify — <Project Name>

> 最後核對: YYYY-MM-DD（命令與 package.json / tooling 一致）

## Verification commands

| Gate | Command | N/A + reason |
|------|---------|--------------|
| Lint | `bun run lint` | |
| Typecheck | `bun run typecheck` | |
| Test | `bun test` | |
| Build | `bun run build` | |
| Smoke (deploy 後) | `curl -fsS https://<host>/health` | |

## Regression suite

- Full regression: `bun run test:regression`（或 N/A + reason）

## 規則

- 每個 gate 必須有 command 或明確 N/A + reason，**不可留空**。
- 代碼改動交付前，跑最小相關 gates 並回報真實輸出（紅線 55）。
- **驗證輸出必須落地成 artifact**：每次交付前的驗證寫入
  `docs/verify-log/YYYY-MM-DD-<task>.txt`（執行的命令 + 真實輸出摘要 + exit code；
  跑唔到嘅 gate 在 log 寫 N/A + reason）。「聲稱驗證過」必須可覆核。
- `package.json` scripts / test runner / build tooling 變更時，本檔必須同 commit 更新。
```

**Verify-log artifact 規則**：

- 位置：`docs/verify-log/YYYY-MM-DD-<short-task>.txt`（或 `.md`），跟 code 改動**同 commit**。
- 內容三要素：執行的命令原文、真實輸出（長輸出可截尾，保留失敗 / 總結行）、exit code。
- 目的：紅線 55 的「回報真實輸出」由自我報告升級為 git 內可覆核的證據；
  `--doc-code-sync` 檢查會驗「code 改咗但冇新 verify-log」。
- Verify-log 係證據，唔係文檔——**不能**用嚟滿足「code 改動必須同步更新 project docs」嘅要求。

**更新時機**:
- Build 前 baseline 必須存在（跟其他 baseline 文件一起 commit）
- 任何驗證命令變更 → 同 commit 更新
- 每次 Ship 前核對「最後核對」日期與實際 tooling 是否一致

---

## 🔗 文件之間的交叉引用

```
PROJECT-OVERVIEW.md
    ↓ 引用
PRD.md (User Stories)
    ↓ 引用
DESIGN.md ─→ 影響 frontend 實作
    ↓ 引用
architecture/*.md (ADR) ─→ 影響 backend 實作
    ↓ 引用
API.md (Endpoints) ─→ 對應到 PRD 嘅 US 編號
    ↓ 引用
TEST-COVERAGE.md (US → Test Cases)
    ↓ 引用
TECH-DEBT.md (持續累積)
    ↓ 引用
retros/*.md (事後改進)
```

**重要**:每份文件底部都應該有「相關文件」section,列出交叉引用。

---

> 紅線 10（Build 前 documentation baseline、doc-code drift 即 blocker）全文以 `SOUL.md` 紅線清單為唯一正本；本文件係該清單嘅內容規格。

---

## 📚 跟其他文件的關係

- `docs/phases.md` §Plan 的 project artifacts 以本文件的 `docs/PRD.md` / `docs/DESIGN.md` / `docs/architecture/0001-*.md` 為準,本文件加強:
  - 強制 commit(不只是寫了就好)
  - 統一編號(US-XXX, ADR-NNNN)
  - 加入 PROJECT-OVERVIEW / TEST-COVERAGE / Retrospective
- `docs/qa-gate.md` 嘅交付清單加一條:`□ 所有強制文件已 commit`
- `docs/qa-tracker.md`(新文檔)會持續追蹤 TEST-COVERAGE.md 嘅進度
- `docs/feedback-loop.md` 的罰則套用到「沒寫文件就 ship」

---

## Related docs

- [Documentation index](00-index.md)
- [QA Gate](qa-gate.md)
- [QA tracker](qa-tracker.md)
- [Testing strategy](testing-strategy.md)
