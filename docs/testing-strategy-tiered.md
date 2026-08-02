# Testing Strategy Tiered — 按階段套用測試層級
> **When to read:** Ship

> **Status:** Canonical. Companion to `docs/testing-strategy.md` (13 層完整版) — 本文件按 project 成熟度把 13 層壓縮成 3 個 tier,對應 `docs/task-tiering.md` 嘅 T1/T2/T3 進入條件。

> **為何需要這份**:David 喺 2026 年中多個 downstream project session 出現「13 層太多,MVP 階段根本用唔晒」嘅困擾。一份「按階段必做 / 應做 / 選做」分級表比一份「全部都做」嘅完整 spec 實用。

> **配套關係**:`docs/testing-strategy.md` 講「點樣測試」(13 層深度),本文件講「邊個 tier 必測邊啲」(成熟度導向)。同一個 project 嘅「已採用 tier」喺 `docs/qa-tracker.md` 嘅 Sprint 概覽記低。

---

## 🎯 三個測試 tier

對應 `docs/task-tiering.md` 嘅任務分級,但係 **project 層級** 而非單次任務:

| Tier | 名稱 | 何時進入 | 必測層 | 應測層 | 選測層 |
|------|------|----------|--------|--------|--------|
| **T1** | MVP / Prototype | project 喺 0 → 1,只係驗證可行性,未進入真實用戶 | Unit + Integration + E2E(critical flow) | Static + Lint | — |
| **T2** | Growth | 已經有真實用戶、有 staging env、有 PR review | Unit + Integration + E2E + Regression Mode + Security | Performance + A11y | Visual + Smoke |
| **T3** | Mature | 有 SLA、有 SRE 編制、有 compliance 需求 | T2 全部 + Performance + A11y + Security + Smoke | Visual + Contract + Chaos + Compatibility | — |

> **永不降級(任何 tier 必做)**:Static Analysis(Lint + Typecheck)、三層測試(Unit/Integration/E2E)嘅 P0 US 覆蓋、Security 嘅 Critical/High CVE 0。

---

## T1 — MVP / Prototype

**適用**:hackathon / 概念驗證 / 內部 demo / 1-2 個 dev 用嘅 tooling。**唔適用** 任何有真實用戶或金流嘅 production system。

### 必測層(4 層)

| 層 | 最低要求 |
|---|---------|
| **Static Analysis** | ESLint + TypeScript `--noEmit` + Prettier(pre-commit hook 必跑) |
| **Unit** | P0 US 嘅核心 helper function 至少 1 個 test(用 `derive pure helper from inline route logic` 模式) |
| **Integration** | 每個 P0 API endpoint 至少 1 個 happy path test(用真 DB / SQLite-in-memory / supertest) |
| **E2E (critical flow)** | 1-2 個 critical user flow(例:註冊→登入 / 下單→付款)— 用 Playwright |

### 應測層(1 層,鼓勵但非必需)

- **Lint 細項**:`gitleaks`(即使 MVP 都有 secret 風險)

### 跳過(刻意不做,寫 N/A + 理由)

- Performance / A11y / Visual / Contract / Chaos / Compatibility / Smoke:呢個階段做咗冇人睇
- **Regression Mode**(`/__qa/*`):fixture / hook 投資回報低,unit + integration + E2E 已經夠

### QA Gate 對應

跟 `docs/qa-gate.md` §4 嘅 11 步,但可以**跳過 §3A Regression Mode Gate**(寫 N/A + reason),其他步驟必跑。

---

## T2 — Growth

**適用**:有真實用戶(>100)、有 staging environment、有 PR review 流程、有 CI/CD、**未進入** SLA / SRE 階段。David 嘅大部分 downstream project 屬呢個 tier。

### 必測層(7 層)

| 層 | 最低要求 |
|---|---------|
| **Static Analysis** | T1 全部 + `npm audit --audit-level=high` / `pip-audit` |
| **Unit** | P0 US 100% line + 80% branch coverage;P1 US ≥ 2 test/helper |
| **Integration** | P0 endpoint happy + sad path;P1 endpoint happy path |
| **E2E** | 所有 P0 US 嘅 happy path + 3 個 critical edge case(auth fail / network timeout / empty state) |
| **Regression Mode** | `skills/regression-guard/` SOP + `/__qa/seed` + `/__qa/reset`(per RG entry);production not mounted + env guard |
| **Security** | SAST(Semgrep basic ruleset) + dependency scan + secret scan,每次 PR 跑 |
| **Smoke** | Deploy 到 staging 後跑 5 分鐘 health check + critical endpoint 200 |

### 應測層(3 層)

- **Performance**:P0 endpoint 有 baseline(用 k6 / autocannon),不設 SLA 但要有 trend 紀錄
- **A11y**:E2E 內加 `axe-core`,Lighthouse score ≥ 85
- **Lint 細項**:ESLint 自訂 rule 禁止 silent catch in auth-related code(對齊 regression-guard RG-001 教訓)

### 跳過(寫 N/A + 理由)

- **Visual Regression**:PR 改 UI 都用人眼 review,呢個階段 ROI 低
- **Contract Testing**:除非有 microservice,否則 API 邊界 = backend 內部
- **Chaos / Compatibility**:無 SRE 編制、production traffic 未穩定

### QA Gate 對應

跟 `docs/qa-gate.md` §4 嘅 11 步,**§3A Regression Mode Gate 全套必跑**(production safety boundary + RG entry QA enablement)。

---

## T3 — Mature

**適用**:有 SLA(99.9%+)、有 SRE / on-call、有 compliance(SOC2 / GDPR / PCI)、multi-region、microservice 邊界多。

### 必測層(11 層)

T2 全部 +:

| 層 | 最低要求 |
|---|---------|
| **Performance** | k6 load test + threshold breach 自動 alert + 每次 release 跑 baseline diff |
| **A11y** | Lighthouse ≥ 95 + 季度 screen reader 手動驗證 + keyboard nav 全站覆蓋 |
| **Visual Regression** | Percy / Chromatic / Playwright screenshot,critical page 必備 baseline |
| **Contract Testing** | Pact consumer-driven,每個 microservice 邊界必備 |
| **Chaos** | 季度 chaos drill + Litmus / AWS FIS |
| **Compatibility** | BrowserStack 跨瀏覽器 + iOS / Android 主流 device |
| **Smoke** | Production deploy 後 1 分鐘內自動跑 + fail 即 rollback |

### 應測層

- **Property-based testing**(fast-check):對涉及大量 input / boundary condition 嘅核心演算法(pricing / scheduling / RBAC)使用
- **Mutation testing**(Stryker / mutmut):P0 US 季度跑一次,確認 test 不只是「覆蓋」還「有效」
- **Fuzz testing**(AFL / Jazzer):對 protocol parser / serialization / file upload pipeline

### QA Gate 對應

跟 `docs/qa-gate.md` §4 嘅全套 11 步 + quarterly mutation score 報告附入 `docs/qa-tracker.md` 嘅 changelog。

---

## 🔄 Tier 升級 / 降級規則

### 升級時機(自然演進)

| 觸發事件 | 升級方向 |
|---------|---------|
| 真實用戶開始付費 / SLA 簽約 | T1 → T2 |
| 出現 SLA 違約罰款 / compliance audit | T2 → T3 |
| Microservice 拆分 | 自動加 Contract Testing 到當前 tier 嘅「應測層」 |

### 降級時機(罕見但要明說)

- 暫時降級:**必須**寫入 `docs/qa-tracker.md` 嘅 changelog + 預計恢復日期
- 例如:release week T3 → T2(跳過 Visual Regression 加快出貨),release 後 1 週恢復

### 例外申報

跳過必測層 = 例外,必須按 `docs/task-tiering.md` 嘅「申報格式」寫明:

```
【測試 tier 降級申報】本 sprint 按 T2 處理,但跳過 E2E 嘅 RG-XXX edge case test。
理由:RG-005 同 RG-012 嘅 fixture 設計未完成,預計下 sprint 補齊。
仍然執行:Unit 100% + Integration 全 endpoint + Smoke test。
```

冇申報嘅降級 = 違規(`feedback-loop.md` P1 過)。

---

## 📊 Tier 自評 checklist

每個 project 在 `docs/PROJECT-OVERVIEW.md` 嘅「成功標準」section 旁邊加一個 **測試 tier 自我宣告**:

```markdown
## 測試 tier
**當前 tier**: T2 / Growth
**觸發升級 T3 嘅條件**: [例如:月活 > 10K 或 SOC2 audit 啟動]
**當前跳過嘅測試層**: Visual Regression(N/A — PR 改 UI 都用人眼 review)
**預計補齊日期**: 2026-Q4(請於 docs/qa-tracker.md 同步)
```

---

## 🛠 工具對照(per tier)

| Tier | Unit | Integration | E2E | Perf | Security | A11y | Visual |
|------|------|-------------|-----|------|----------|------|--------|
| T1 | Vitest | supertest | Playwright | — | gitleaks | — | — |
| T2 | Vitest + pytest | testcontainers | Playwright | k6(advisory) | Semgrep + npm audit | axe-core | — |
| T3 | + Stryker | + WireMock | + Percy/Chromatic | + SLA threshold | + Snyk + ZAP | + Lighthouse | + Chromatic |

---

## Related docs

- [Testing strategy (full 13 層)](testing-strategy.md)
- [Task tiering](task-tiering.md)
- [QA Gate](qa-gate.md)
- [Regression guard skill](../skills/regression-guard/SKILL.md)
- [QA tracker template](qa-tracker.md)