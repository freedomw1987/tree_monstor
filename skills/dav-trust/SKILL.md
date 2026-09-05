---
name: dav-trust
description: 當用戶提供「一個大目標 + 時間 deadline」並希望 Agent 自主完成整個任務、中間不打擾用戶、由 Agent 自行代答所有中間問題時使用。Agent 走完整 SOP 5 階段（規劃 → 設計 → 執行 → 反省 → 提交），所有代答決定寫進 docs/trust-log.md，完成後用戶一次性驗收。
---

## 1. 什麼是 dav-trust

信任模式（Trust Mode）：用戶把「**大目標 + Deadline**」交給 Agent，Agent 在不打擾用戶的前提下，自主完成從需求拆解到成果提交的全流程。

**核心承諾**：
- ✅ Agent 不會中途問問題（即使遇到設計歧義、技術選型、命名也自己決定）
- ✅ Agent 所有代答決定都有時間戳記錄，用戶最後可逐一檢視、推翻或接受
- ✅ 到 deadline 自動停下，無論完成度多少都誠實提交

## 2. 適用場景

| ✅ 適用 | ❌ 不適用 |
|--------|----------|
| 大型獨立功能（CRM、會員系統、後台等） | 需要用戶即時互動的探索性任務 |
| 已有清晰技術棧的項目擴展 | 第一次接觸的全新項目（要先用 dav-planner 探索） |
| 用戶可長時間不查看對話 | 涉及真金白銀、刪資料、生產環境操作 |
| 截止時間明確的工作（Demo、Sprint、比賽） | 沒有 deadline 的長期迭代 |

## 3. 啟動條件

Agent 必須在對話中**明確確認兩件事**，缺一不可：

1. **大目標**：用戶說清楚「要做什麼」，可模糊但不可無
2. **Deadline**：明確時間（例如「2 小時」「今天下班前」），Agent 會換算成截止 ISO 時間戳

> ⚠️ 若用戶只給大目標沒給時間，Agent 必須主動詢問 deadline 後再啟動。

## 4. 工作流程（嚴格 SOP 5 階段）

每階段遇到任何問題，**Agent 自己決定 + 寫 trust-log**，**禁止**呼叫 `ask_user_question` 問用戶。

### 階段 1：規劃（dav-planner）

- 自主把大目標拆解成 Backlog 項目（User Story / Defect / Tech Debt / Spike）
- 寫入 `docs/backlog.md`，每項必須有 AC（驗收標準）與 Story Points

### 階段 2：設計（dav-designer）

- 產出或更新 `docs/design.md`（UX/UI）、`docs/system-design.md`（架構）
- 按模組拆解 PRD，分配 Sprint 與 Module

### 階段 3：執行（Gate 1-4 速查表）

| Gate | 名稱 | 觸發 |
|------|------|------|
| **Gate 1** | TDD | `/skill:tdd-test-writer` |
| **Gate 2** | lint / syntax | 語言對應工具 |
| **Gate 3** | regression | `/skill:regression-guard` |
| **Gate 4** | reviewer | `/skill:dev-checker-loop` + playwright（UI 任務） |

每個 Backlog 項目都必須通過 4 個 Gate 才算完成。

### 階段 4：反省（dav-reflection）

- 對已完成項目做 6 維度檢查（User Story / Sprint / Module 層級）
- 產出反省報告，更新 `docs/backlog.md`（補技術債、新 Backlog）

### 階段 5：提交（dav-submitter）

- 簡單對話摘要（90 秒可讀完）
- Markdown 詳錄：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`
- HTML 視覺化版：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.html`

## 5. Trust Log 規範

### 5.1 路徑與觸發

- **路徑**：`docs/trust-log.md`
- **觸發**：任何階段遇到需要「代答」的問題時
- **時機**：**決定做出當下**立刻寫，**不延遲到後面補**

### 5.2 記錄格式

```markdown
# Trust Log — <大目標簡述>

> 啟動時間: <ISO>
> Deadline:   <ISO>

---

## YYYY-MM-DD HH:MM — <階段名>

**問題**：<用戶沒指定什麼>
**決策**：<Agent 選了什麼>
**理由**：<為什麼這樣選>
**可推翻**：✅ / ❌（底線規則不可推翻）
```

> 完整範例見 [[examples.md]]

## 6. Deadline 處理

### 6.1 時間內完成

走完整 5 階段，最終 submission 標註「✅ 全部完成」。

### 6.2 時間到未完成（自動停）

1. **立即停止**所有執行工作
2. 跳過階段 4 反省
3. 用 dav-submitter 提交，標註已完成 / 未完成的 Backlog
4. 在 trust-log 寫最終記錄：「⏰ Deadline 到達，自動停止」

### 6.3 時間追蹤

- 每階段開始記錄時間戳
- 剩餘時間 < 20% 時，主動縮小範圍（把 Backlog 標為「不在此次範圍」）

## 7. 底線規則（不可跨越）

| # | 規則 | 違反處理 |
|---|------|---------|
| 1 | **不可發出外部指令**：不能寄 email、課金、推送通知、刪除線上資料、呼叫付費 API | trust-log 強制記錄 + 停下來等用戶 |
| 2 | **不可修改不可逆文件**：不修改已 production 的檔案、不直接 push master / main | 必須先 commit 到分支，由用戶手動 merge |

## 8. 輸出物清單

| 文件 | 必填 | 用途 |
|------|------|------|
| `docs/backlog.md` | ✅ | 任務拆解 |
| `docs/design.md` | 視需要 | UX/UI 設計 |
| `docs/system-design.md` | 視需要 | 系統架構 |
| `docs/trust-log.md` | ✅ | 所有代答決定 |
| `docs/deliverable/<date>-<slug>.md` | ✅ | Markdown 交付摘要 |
| `docs/deliverable/<date>-<slug>.html` | ✅ | HTML 視覺化版 |

## 9. 注意事項

- **不要假裝完成**：未做的 Backlog 必須明確標註，不可偽造 ✅
- **不要省略 trust-log**：每個代答都要有記錄，這是用戶驗收的依據
- **不要超出底線**：底線規則是硬約束，無論時間多緊都不破例
- **保持時間觀念**：剩餘時間 < 20% 時主動收斂範圍

---

**範本與代答類別**：→ [[examples.md]]
