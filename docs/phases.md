# Phase 流程詳細規範

> **Status:** Canonical. Source of truth for Think → Plan → Build → Review → Test → Ship → Reflect.

## Think → Plan → Build → Review → Test → Ship → Reflect

```
用戶需求
    ↓
Think ──────────────────────────────────────────────────┐
    ↓                                                 │
Plan ─────────────────────────────────────┐           │
    ↓                                      │           │
Build ─────────────────────────┐           │           │
    ↓                           │           │           │
Review ─────────────────┐       │           │           │
    ↓                     │       │           │           │
Test ───────────┐         │       │           │           │
    ↓           │         │       │           │           │
Ship ─┐        │         │       │           │           │
    ↓ │        │         │       │           │           │
Reflect ←──────┴─────────┴───────┴───────────┘  Feedback
                                                Loop
```

---

## Phase 總覽

| Phase | 名稱 | 輸出 | 負責 Subagent | 強制 |
|-------|------|------|--------------|------|
| Think | 市場分析 + 技術調研 | `ceo-market-analysis.md` + 調研報告 | CEO + Researcher | ✅ |
| Plan | 商業計劃 + 需求 + 架構 + 文檔 baseline | `ceo-business-plan.md` + `docs/PRD.md` + `docs/DESIGN.md` + ADR + `docs/QA-TRACKER.md` baseline | CEO + BA + Designer + SA + Tech Lead + Documentation Engineer | ✅ |
| Build | 開發執行 | 代碼 | Frontend + Backend + DevOps + Security Engineer | — |
| Review | 架構審查 + UX 合規 | Review 報告 | SA Reviewer + UX Reviewer | ✅ |
| Test | 測試 + 壓測 | 測試報告 + 壓測報告 | QA + Performance Engineer | ✅ |
| Ship | 部署上線 | 部署確認 | Release Manager | — |
| Reflect | 復盤 | 復盤報告 | Retrospective + Sprint Manager | — |

---

## Sprint 概念

### Sprint 0（Think 階段的一部分）
目的：理解問題域，確認可行性，**不寫代碼**。
- Research 技術可行性
- 競爭對手分析
- 用戶訪談（如果適用）
- 風險評估
- 確定是否繼續（Go/No-Go）

### Sprint N（常規迭代）
- 2-week sprint 為基準
- 每個 sprint 有明确的目標和交付物
- Sprint 結束時做 Sprint Retrospective

### Sprint Retrospective（在 Reflect 階段）
每個 sprint 结束都要做，不只是 project-level：
- 做得好的
- 需要改進的
- Action items（下次 sprint 改）

---

## Think

### 目的
市場機會評估與技術可行性調研，確保項目值得做。包含 Sprint 0 研究。

### 參與角色
- **CEO** — 市場分析、競爭格局、財務可行性
- **Researcher** — 技術調研、競品分析、技術選型驗證

### CEO 必須產出
`docs/ceo-market-analysis.md`:
- 市場規模與增長趨勢
- 競爭對手分析（功能/定價/用戶評價）
- 機會評估（SWOT）
- 財務可行性（成本預估、營收模型）
- 風險評估

### Researcher 必須產出
調研報告:
- 技術可行性分析
- 現有解決方案調研
- 技術棧建議
- 關鍵技術風險

### 觸發方式

使用平台原生的 delegation 機制：

```
goal="CEO 市場分析"
context="用戶需求: ..."
role="leaf"

goal="技術調研"
context="用戶需求: ..."
role="leaf"
```

---

## Plan

### 目的
综合 CEO/BA/Designer/SA 的輸出，產出可執行的完整計劃。

### 參與角色
- **CEO** — 商業計劃、成本模型、GTM
- **BA** — 需求挖掘、用戶故事、PRD
- **Designer** — UI/UX 設計、Design System
- **Tech Lead** — 綜合輸出執行 plan

### CEO 必須產出
`docs/ceo-business-plan.md`:
- 商業模式（如何賺錢）
- 成本模型（開發/運營/營銷）
- GTM 策略（如何獲客）
- 里程碑規劃
- 成功標準與 KPI

### BA 必須產出
`docs/PRD.md`（project artifact；模板見 `docs/project-documentation-standard.md`）:
- 產品概述與目標
- 用戶故事列表（帶優先級 P0/P1/P2）
- 功能需求詳情
- 非功能需求（效能、安全、兼容性）
- 驗收標準
- 假設與風險清單

### Designer 必須產出
`docs/DESIGN.md`（project artifact；無 UI 必須標 N/A 原因）:
- Overview — 設計理念與品牌定位
- Colors — 顏色系統（HEX 值）
- Typography — 字體系統
- Layout & Spacing — 間距系統
- Elevation — 陰影/層級
- Shapes — 圓角
- Components — 元件規範
- Do's and Don'ts

### SA 必須產出
`docs/architecture/0001-*.md`（ADR / architecture baseline）:
- 系統架構圖
- Frontend/Backend 技術棧建議
- 數據模型設計
- API 端點列表
- 開發規範和約定

### Tech Lead 職責
- 綜合 BA/Designer/SA 的輸出
- 識別任務依賴關係
- 制定執行計劃（Task Board）
- 分配優先級

### Pre-Build Documentation Gate（Build 前強制）

Plan 結束、Build 開始前，Documentation Engineer + Tech Lead 必須確認 project documentation baseline：
- `docs/PROJECT-OVERVIEW.md`：目標用戶、scope、成功標準
- `docs/PRD.md`：P0/P1 User Stories + acceptance criteria
- `docs/DESIGN.md`：UI/UX baseline，無 UI 則標 N/A
- `docs/architecture/0001-*.md`：至少一個初始 ADR / architecture decision
- `docs/API.md`：API contract draft，無 API 則標 N/A
- `docs/QA-TRACKER.md`：所有 PRD US 對應 rows
- `docs/TEST-COVERAGE.md`：test plan skeleton
- `docs/TECH-DEBT.md`：tech debt register skeleton

未通過此 gate → 留在 Plan，不能開始 Build。

---

## Build

### 目的
並行開發，产出可运行的代码。

### 參與角色
- **Frontend** — UI 實現、API 串接
- **Backend** — API、Business Logic、DB
- **DevOps** — 環境、CI/CD、部署腳本
- **Security Engineer** — Security-first 開發、SAST/DAST

### 任務調度原則
1. 分析 task 依賴圖，確定並行度
2. 首批：所有無依賴的 task 同時派發
3. 每批完成後，檢查是否有 task 解除 Blocked
4. 持續直到所有 task 完成

### Security Engineer 職責
- 安全開發規範培訓
- 代碼 security review（並行，不等 Phase 3）
- SAST/DAST 自動化掃描
- 修復 SQL Injection、XSS、Secrets 暴露等問題

### 協調者
由 Orchestrator Subagent 協調。

### 長期任務支援
**Context Manager** — 每 30 分鐘或每完成一個 task，自動總結當前進度：
- 寫入 `docs/context-summary.md`
- 壓縮非必要細節，保留決策和當前狀態
- 避免 context 膨脹導致 token 爆炸

**Observability Monitor** — 每 10 分鐘檢查一次：
- Subagent processes 是否僵死（development-watchdog）
- Cloudflare tunnels 是否斷開
- API calls 是否正常
- 如發現異常，立即通知 Developer 主體

### Documentation Engineer 職責
- Build 開始前驗證 Pre-Build Documentation Gate
- 代碼提交時，自動更新相關文檔
- 從 JSDoc/TSDoc 註解自動生成 API docs
- 確保 `docs/` 下的文檔與實際代碼同步
- David 在 Build / Review / Test / Ship 前提出新需求或修正時，暫停 Build → 更新 `docs/PRD.md`、`docs/QA-TRACKER.md` 與受影響文檔 → 再繼續
- 使用 `auto-doc-gen` skill 自動化

### Dependency Manager 職責
- 追蹤 `package.json` / `requirements.txt` 版本
- 定期檢查 security advisories（NPM audit / pip-audit）
- 記錄依賴變更日誌
- 發現 CVE 及時上報

---

## Review

### 目的
確保代碼質量、架構合規、UI 符合設計。

### 參與角色
- **SA Reviewer** — 技術架構、代碼品質、安全性
- **UX Reviewer** — 前端是否符合 design.md、截圖比對

### SA Reviewer 審查重點
- 架構是否符合 `docs/architecture.md`
- 代碼品質與最佳實踐
- 安全漏洞
- 測試覆蓋率

### UX Reviewer 審查重點
- UI 是否符合 `docs/design.md`
- 截圖比對關鍵頁面
- 響應式佈局
- 交互是否符合規範

### 結果處理
| 結果 | 處理 |
|------|------|
| CRITICAL 問題 | 必須修復 → 重新審查 |
| IMPORTANT 問題 | 應該修復 → 重新審查 |
| Minor 問題 | 可選，記錄供後續參考 |

### 紅線
- 安全漏洞（SQL Injection、XSS、Secrets 暴露）
- 嚴重偏離既定架構
- 測試是為了通過而寫，不是為了驗證功能

---

## Test

### 目的
全面測試，確保交付質量。

### 參與角色
- **QA** — 自動化測試、E2E、User Simulation
- **Performance Engineer** — Load testing、benchmark

### QA 測試組成
1. 單元測試 / Integration 測試
2. E2E 測試（dogfood skill）
3. User Simulation Testing

### User Simulation 原則
- 全自動化，不需要用戶介入
- 使用 playwright screenshot 截圖
- 使用 browser_console() 讀取 JS errors
- 使用 curl 測試 API

### Performance Engineer 職責
- Load testing（k6/Gatling）
- Benchmark 對比
- 瓶頸分析
- 壓測報告

---

## Ship

### 目的
安全部署上線，確保穩定運行。

### 參與角色
- **Release Manager** — 部署、rollback、monitoring

### Release Manager 職責
- 部署前 smoke test
- 藍綠部署 / Canary release
- Rollback plan
- 監控儀表板
- 上線確認報告

### 部署檢查清單
```
□ Smoke test 通過
□ 健康檢查通過
□ 主要功能驗證
□ 監控指標正常
□ Rollback plan 就緒
```

### Feature Flag 機制
新功能用 Feature Flag 控制，不需要等到完全 ready 才能 deploy：
- 每個新功能都有對應的 flag
- Flag 可以独立開關
- 上線時默認關閉，通過測試後再逐步開啟
- 常用方案：LaunchDarkly、Unleash、或者簡單的環境變量

---

## Reflect

### 目的
Post-mortem 復盤，沉淀經驗，更新 SOP。

### 參與角色
- **Retrospective** — 結構化復盤

### Retrospective 產出
`docs/retrospective-<project>-<date>.md`:
- 項目概述
- 做得好的
- 需要改進的
- 關鍵教訓（Lessons Learned）
- 下次改進 Action Items

### 觸發時機
- 每個項目完成後
- 重大故障修復後
- 季度/年度常規复盘

---

## QA Gate 交付清單

**未通過 QA Gate 嚴禁交付。**

```
□ Think: CEO 市場分析 + Researcher 調研報告
□ Plan: CEO 商業計劃 + PRD + Design + Architecture + Tech Lead 執行計劃
□ Pre-Build Documentation Gate: project docs baseline 已建立，PRD ↔ QA-TRACKER 已同步
□ Build: 所有 task 完成，代碼已提交，相關文檔已同步
□ Review: SA Reviewer APPROVED + UX Reviewer APPROVED
□ Test: QA 測試通過 + Performance Engineer 壓測通過
□ Ship: Release Manager 部署確認
□ Reflect: Retrospective 復盤報告完成
□ Security: 安全掃描通過
□ Feedback Loop: 所有問題已修復
```

---

## Related docs

- [Documentation index](00-index.md)
- [Subagent matrix](subagents.md)
- [Feedback loop](feedback-loop.md)
- [QA Gate](qa-gate.md)
- [Think / Plan examples](think-plan-examples.md)
