# Subagent 角色矩陣

## 角色列表

| 角色 | Goal 關鍵字 | 核心職責 | 輸入 | 輸出 |
|------|-------------|----------|------|------|
| **Orchestrator** | `初始化開發專案` / `接管現有專案` | 任務協調、進度追蹤、依賴管理 | 用戶需求 | Task Board、階段報告 |
| **CEO** | `ceo 市場分析` / `ceo 商業計劃` | 市場機會、成本模型、營收策略、GTM | 用戶需求 | `docs/ceo-market-analysis.md` / `docs/ceo-business-plan.md` |
| **Researcher** | `前期調研` / `技術調研` | 技術可行性、競品分析、技術選型驗證 | 用戶需求 | 調研報告 |
| **Tech Lead** | `tech lead` / `技術負責人` | 綜合 BA/Design/SA，産出執行 plan | PRD + Design + Architecture | 執行計劃 |
| **BA** | `BA 商業分析` | 需求挖掘、用戶故事、PRD | 用戶原始需求 | `docs/prd.md` |
| **Designer** | `UI/UX 設計` | Wireframe、Design System | PRD | `docs/design.md` |
| **SA** | `SA 架構設計` | 系統架構、API 契約、技術選型 | PRD | `docs/architecture.md` |
| **Frontend** | `前端開發` | UI 實現、API 串接、響應式 | Architecture + Design | 前端代碼 |
| **Backend** | `後端開發` | API、Business Logic、DB | Architecture | 後端代碼 |
| **DevOps** | `DevOps 部署` | 環境、CI/CD、部署、監控 | Architecture | 部署配置、Pipeline |
| **Security Engineer** | `security scan` / `安全開發` | Security-first 開發、SAST/DAST | 代碼 | 安全報告 |
| **SA Reviewer** | `SA Code Review` | 架構合規、程式品質、安全 | 代碼 | Review 報告 |
| **UX Reviewer** | `ux review` / `ui 合規檢查` | 実装符合 design.md、截圖比對 | 代碼 + Design | UX 審查報告 |
| **QA** | `QA 測試` | 自動化測試、E2E、User Simulation | 代碼 + PRD | 測試報告 |
| **Performance Engineer** | `perf test` / `壓測` | Load testing、benchmark、瓶頸分析 | 代碼 | 壓測報告 |
| **Release Manager** | `release` / `部署上線` | 部署、rollback、monitoring、Smoke test | 代碼 | 部署確認 |
| **Retrospective** | `retrospective` / `復盤` | Post-mortem、經驗沉澱、更新 SOP | 項目結束 | 復盤報告 |
| **Tech Debt Tracker** | `tech debt` / `技術債` | 記錄、優先級排序 tech debt，規劃償還 | 代碼 | `docs/tech-debt.md` |
| **Documentation Engineer** | `api docs` / `自動文檔` | 代碼即文檔，API docs 自動生成 | 代碼 | `docs/api.md` |
| **Sprint Manager** | `sprint` / `里程碑` | 長期項目拆成 sprint，追蹤進度 | Task Board | `docs/sprint-<n>.md` |
| **Dependency Manager** | `dependency` / `依賴管理` | library 版本追蹤、security advisory | package.json/requirements.txt | 依賴報告 |
| **Context Manager** | `context` / `上下文管理` | 長時間任務 context 壓縮、總結 | 任務狀態 | context-summary.md |
| **Observability Monitor** | `monitor` / `監控` | 主動監控 subagent 健康、Zombie 檢測 | Process list | 健康報告 |

---

## Orchestrator Subagent

### 觸發方式
```python
delegate_task(
    goal="初始化開發專案並建立 Task Board",
    context="""
    項目名稱: [名稱]
    用戶需求: [需求描述]
    
    請執行:
    1. 建立 docs/ 目錄
    2. 建立 docs/taskboard.md (Task Board)
    3. 分析需求，拆解為初步 task 列表
    4. 派發 BA Subagent 開始需求分析
    5. 更新 Task Board
    """,
    role="orchestrator",
    toolsets=["terminal", "file", "web", "delegation"]
)
```

### 職責
- 創建並維護 Task Board (`docs/taskboard.md`)
- 派發 BA / SA / Designer / Frontend / Backend / DevOps
- 追蹤進度、管理依賴、處理失敗
- 定期向 Developer 主體彙報

---

## Model Tiering

根據任務複雜度選擇合適的 Model：

### 等級定義

| 等級 | 用途 | Model | Max Iterations |
|------|------|-------|----------------|
| **simple** | 格式化、簡單查錯、狀態更新 | gpt-4o-mini | 50 |
| **medium** | 一般開發、文件編寫 | gpt-5.5 | 300 |
| **complex** | 架構設計、複雜 Debug、多檔案重構 | gpt-5.5 + high reasoning | 500 |

### 使用範例
```python
# 簡單任務
delegate_task(
    goal="格式化代碼",
    context="...",
    model="gpt-4o-mini"  # 或使用 config default
)

# 複雜任務
delegate_task(
    goal="設計微服務架構",
    context="...",
    model="openai/gpt-5.5",
    reasoning_effort="high"
)
```

---

## 調度規則

### 任務依賴範例
```
A (BA) ──→ C (SA) ──┬──→ D (Frontend) ──→ F (整合)
         ↓            └──→ G (Backend)
B (Design) ────────→ E (Design System)
```

### 調度流程
1. 分析 task 依賴圖，確定並行度
2. 首批：所有無依賴的 task 同時派發
3. 每批完成後，檢查是否有 task 解除 Blocked
4. 持續直到所有 task 完成
