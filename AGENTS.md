# AGENTS.md - Developer Profile

_Developer Profile Session 啟動流程與工作區規範。_

---

## Session 啟動流程

### 步驟 1：讀取配置
```
1. 讀取 SOUL.md — 了解 Developer 身份與原則
2. 讀取 MEMORY.md — 加載長期記憶
3. 讀取 docs/00-index.md — 了解文檔結構
```

### 步驟 2：建立工作區（長期任務）
- 創建 `memory/YYYY-MM-DD.md`
- 創建 `docs/taskboard.md`（如有需要）
- 初始化 checkpoint（如任務需要中斷恢復）

### 步驟 3：判斷任務類型
```
長期任務?
  ├─ 是 → 執行 Orchestrator Subagent
  └─ 否 → 直接執行
```

---

## 長期任務識別

滿足以下任一條件視為長期任務：
- 超過 30 個 tool calls
- 需要 Phase 1/2/3/4 多階段
- 需要多個 Subagent 協作
- 任務時間預計超過 1 小時

---

## Orchestrator 觸發

```python
delegate_task(
    goal="初始化開發專案並建立 Task Board",
    context="""項目名稱: ...
用戶需求: ...""",
    role="orchestrator",
    toolsets=["terminal", "file", "web", "delegation"]
)
```

詳細文檔：`docs/subagents.md`

---

## 工作區規範

### 長期任務工作區
```
memory/YYYY-MM-DD.md  — 當前任務的記憶文件
docs/taskboard.md     — 任務面板
docs/checkpoint.md    — 斷點恢復點（長期任務）
```

### 文件路徑
- 基礎路徑：`/home/ubuntu/developer/`
- 用戶專案：`/home/ubuntu/developer/projects/<project-name>/`
- Profile：`~/.hermes/profiles/developer/`

### Profile 文件結構
```
developer/
├── SOUL.md          — 身份定位（~100 行）
├── AGENTS.md        — 啟動流程（~60 行）
├── MEMORY.md        — 長期記憶（~100 行）
└── docs/
    ├── 00-index.md      — 文檔索引
    ├── phases.md        — Phase 0~4 詳細流程
    ├── subagents.md     — Subagent 角色矩陣
    ├── failure-policy.md — 失敗處理機制
    ├── task-board.md    — Task Board 格式
    ├── qa-gate.md       — QA Gate 交付清單
    ├── pm.md            — PM 進度追蹤
    ├── checkpoint.md    — Checkpoint 機制
    ├── devops.md        — DevOps 規範
    └── feedback-loop.md — Feedback Loop
```

---

## Session 結束流程

### 長期任務結束前
1. 更新 Task Board 為 Done
2. 保存 checkpoint（如果有）
3. 確保所有 Subagent 已終止
4. 通知 Developer 任務完成

### 失敗場景
- 任何 Subagent 失敗 → 按 `docs/failure-policy.md` 處理
- 無法解決 → 升級並通知 Developer
