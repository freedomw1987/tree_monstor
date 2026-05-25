# AGENTS.md - Developer Profile

_Developer Profile Session 啟動流程與工作區規範。_

---

## Session 啟動流程

### 步驟 0：確認 Goal（第一件事）
```
抵達房間，第一句話是：
「🎯 Goal: [用戶需求簡述]」

把 goal 寫在 checkpoint 或 session 頂部，
這個 goal 是北極星，整個 session 不能偏離。
```

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

### 觸發 Clarify 的時機

用 `clarify` 工具問用戶的場景：
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

---

## Orchestrator 觸發

### 每次觸發前必須 echo goal
```
╔══════════════════════════════════════════╗
║  🎯 ORCHESTRATOR GOAL ECHO              ║
╠══════════════════════════════════════════╣
║  原始目標: [從 checkpoint/記憶讀取]      ║
║  當前任務: [subagent 即將做的事]         ║
║  偏離檢查: ✅ 對齊 / ❌ 偏離 → 停止       ║
╚══════════════════════════════════════════╝
```

**如果偏離了**：先回到原始 goal，確保 subagent 的 goal 真的服務於原始目標。

```python
delegate_task(
    goal="初始化開發專案並建立 Task Board",
    context="""項目名稱: ...
用戶需求: ...
當前階段: Think
原始目標: [粘貼這裡，確保 subagent 知道]""",
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
docs/context-summary.md — 長期任務 context 總結
docs/checkpoint.md    — 斷點恢復點（長期任務）
```

### 文件路徑
- 基礎路徑：`/home/ubuntu/developer/`
- 用戶專案：`/home/ubuntu/developer/projects/<project-name>/`
- Profile：`~/.hermes/profiles/developer/`

### Profile 文件結構
```
developer/
├── SOUL.md              — 身份定位、核心原則（Think/Plan/Build...）
├── AGENTS.md            — 啟動流程、互動模式
├── MEMORY.md            — 長期記憶
├── docs/
│   ├── 00-index.md      — 文檔索引
│   ├── phases.md        — Think→Plan→Build→Review→Test→Ship→Reflect
│   ├── subagents.md     — Subagent 角色矩陣（18 個）
│   ├── failure-policy.md — 失敗處理機制
│   ├── task-board.md    — Task Board 格式
│   ├── qa-gate.md       — QA Gate 交付清單
│   ├── pm.md            — PM 進度追蹤
│   ├── checkpoint.md    — Checkpoint 機制
│   ├── devops.md        — DevOps 規範
│   └── feedback-loop.md — Feedback Loop
└── skills/
    ├── auto-doc-gen/    — API 文檔自動生成
    ├── context-summarizer/ — Context 壓縮
    └── tech-debt-register/  — 技術債追蹤
```

---

## Session 結束流程

### 長期任務結束前
1. 更新 Task Board 為 Done
2. 保存 checkpoint（如果有）
3. 寫入 context-summary.md（如有需要）
4. 確保所有 Subagent 已終止
5. 通知 Developer 任務完成

### 失敗場景
- 任何 Subagent 失敗 → 按 `docs/failure-policy.md` 處理
- 無法解決 → 升級並通知 Developer