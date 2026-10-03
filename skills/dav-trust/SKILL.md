---
name: dav-trust
description: 信任模式。用戶給「大目標 + deadline」後 Agent 自主完成 SOP 5 階段，中途不問問題（自己寫 trust-log 代答），deadline 到 / 用戶叫停時自動退出 trust 身份。
---

# Dav Trust

## TL;DR

1. **做什麼**：把「大目標 + Deadline」交給 Agent 自主完成；Agent 走 SOP 5 階段（規劃→設計→執行→反省→提交），中途所有代答寫進 `docs/trust-log.md`。
2. **何時觸發**：用戶明確說「trust mode 跑 X」/「自己做完再叫我」+ 提供 deadline。
3. **預設 SOP 路徑**：啟動 trust → 規劃（dav-planner）→ 設計（dav-designer）→ 執行（4 Gate）→ 反省（dav-reflection）→ 提交（dav-submitter）→ 退出 trust。
4. **關鍵紀律**：
   - **不問用戶問題**：所有歧義、技術選型、命名 Agent 自己決定 + 寫 trust-log
   - **不自動停下**：提早完成不停，依 §Step 4 三段接力（L1 → L2 → L3）繼續做
   - **退出 trust 身份**：deadline 到 / 用戶叫停時退出，進入普通對話模式
   - **底線規則**：不可發外部指令、不可改不可逆文件（見 §規則）
   - **V04**（本 skill 新增，詳見 §規則 L3 邊界）— L3 擴量必須對齊 `docs/` 預先規劃（roadmap / backlog 未跑 / design 延伸）；不可無中生有
5. **必產出物**：`docs/backlog.md` + `docs/trust-log.md` + `docs/need-you-help.md`（如有擔憂）+ `docs/deliverable/<...>.md`

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 用戶給「大目標 + Deadline」且明確說「trust mode」 | ✅ 必須 |
| 大型獨立功能（CRM、會員系統等）| ✅ 適合 |
| 已有清晰技術棧的擴展 | ✅ 適合 |
| 用戶可長時間不看對話 | ✅ 適合 |
| **沒給 deadline 或 deadline 模糊** | ❌ Agent 必須先問、不准啟動 |
| 需要即時互動的探索任務 | ❌ 走 dav-planner |
| 全新項目（無 backlog）| ❌ 先 dav-planner 探索 |
| 涉及金流 / 刪資料 / 生產操作 | ❌ 危險（見底線規則）|

## 流程（5 階段 SOP + 3 個 Trust 動作）

### Step 1：啟動條件驗證 + 時間錨點鎖死

- **動作**：確認「明確大目標 + 明確 Deadline」兩件事；用 `date` 查系統時間 → 解析為絕對 deadline（跨午夜必須問用戶）→ 鎖死 `START_TS` + `DEADLINE_TS`
- **為什麼**：沒 deadline = 無限責任；附時間錨點 = deadline 可驗證、trust-log 可審查
- **產出**：對話中明示「Trust Mode 啟動 + START_TS + DEADLINE_TS」
- **證據**：對話有「Trust Mode 啟動」+ 兩個錨點字樣（完整紀律見 time-anchor.md）

### Step 2：SOP 5 階段（Agent 自主）

- **動作**：依序跑 §2.1 規劃（dav-planner）→ §2.2 設計（dav-designer）→ §2.3 執行（Gate 1-4）→ §2.4 反省（dav-reflection）→ §2.5 提交（dav-submitter）
- **為什麼**：完整 SOP 是品質保證
- **產出**：每階段產出物（backlog / design / tests / deliverable）
- **證據**：每階段都有對應檔案

### Step 3：代答寫進 Trust Log

- **動作**：任何歧義 / 技術選型 / 命名決定都寫 `docs/trust-log.md`（時間戳 + 問題 + 決策 + 理由 + 可推翻標記）
- **為什麼**：trust 結束後用戶可審查、推翻
- **產出**：`docs/trust-log.md` 新 row
- **證據**：trust-log.md 有對應記錄

### Step 4：三段接力（L1 接力 → L2 重訪 → L3 擴量）

- **動作**：依序執行三段接力，直到 deadline 到或用戶叫停
  - **L1 接力**：當前 Backlog 完成 → 立即認領下一個 PENDING（按優先級）
  - **L2 重訪**：Backlog 全 PENDING 都做完 → 重訪所有 ⏸️ 待確認，看能否用「保守做法」補上
  - **L3 擴量**：L1+L2 跑完仍剩時間 + Backlog 已無 PENDING → **對齊 `docs/` 預先規劃** 自主擴量（見 §規則 L3 邊界）
- **為什麼**：避免「提早完成就交差」；給 LLM 清楚的下一動作；對齊 docs 規劃保證擴量不越權
- **產出**：`docs/backlog.md` 更新 + `docs/trust-log.md` 新 row（每段動作當下寫）
- **證據**：trust-log 有對應三段時間戳；backlog 內 L3 項目標 `🆕 自主擴量`

### Step 5：退出 Trust Mode

- **動作**：deadline 到 / 用戶叫停 → `dav-submitter` 提交 → 對話輸出 `🏁 Trust Mode 已結束` → 退出 trust 身份
- **為什麼**：trust 結束後 Agent 必須進入普通對話模式，**不再自動做事**
- **產物**：最終 deliverable + 對話「Trust Mode 已結束」
- **證據**：對話有「Trust Mode 已結束」字樣

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 中途不問用戶問題 | 缺 deadline / 危險操作仍可問 | 用 `ask_user_question` 之前先寫 trust-log 解釋為何要問 |
| 所有代答寫 trust-log | N/A | 不可只在對話講、不寫 log |
| 提早完成不停下（走 §Step 4 三段接力）| deadline 到或用戶叫停才停 | 不可「做完就交差」 |
| Backlog 全做完仍不自動停下 | deadline 到才停 | L1 → L2 → L3 依序接力 |
| **L3 擴量來源限於 `docs/` 預先規劃** | N/A | 來源限 `docs/roadmap.md` / `docs/backlog.md` 未跑項目 / `docs/design.md` 延伸項目 |
| **L3 自主擴量必更新 `docs/backlog.md`** | N/A | 加 `🆕 自主擴量` 標記、事後可一鍵 reject |
| **L3 必同步寫 trust-log** | N/A | 每個自主決策當下寫 log，不可產出視而不見 |
| **L3 不可做危險 / 不可逆 / 外部指令** | 違反 = 退出 trust mode | 同底線規則 |
| **deadline 是 L3 硬上限** | deadline 到自動停止 | 剩餘 < 10% 主動收斂、不再啟動新 L3 項目 |
| **時間錨點須真實查時間**（v2.2 新增）| N/A | 啟動 / 完成每 Backlog / L3 收斂判斷 / 退出 4 個關鍵節點必查 `date`；詳見 time-anchor.md |
| 不可發外部指令 | N/A | 不寄 email / 課金 / 推送 / 刪線上資料 / 付費 API |
| 不可改不可逆文件 | N/A | 不 push master/main、不改 production |
| 退出 trust 後不再自動做事 | 用戶說「繼續 trust」可重啟 | 必須等用戶指示 |
| 退出後用戶問「為什麼這樣選」| ✅ 純對話解釋 | 不可重啟 trust |

## 底線規則（不可跨越）

| # | 規則 | 違反處理 |
|---|------|---------|
| 1 | 不可發外部指令（email / 課金 / 推送 / 刪線上資料 / 付費 API）| trust-log 強制記錄 + 停下等用戶 |
| 2 | 不可改不可逆文件（push master/main / 改 production）| trust-log 強制記錄 + 停下等用戶 |
| 3 | 不可擅自修改 deadline（v2.2 新增） | trust-log 強制記錄 `📝 deadline 變更`、由用戶觸發才可改 |

## 結束邊界（核心新規範）

| 結束點 | 觸發 | Agent 動作 |
|--------|------|-----------|
| Deadline 到達 | 時間到 | 用 dav-submitter 提交 + `🏁 Trust Mode 已結束` |
| 用戶主動結束 | 「結束 trust」「停」| 同上 |
| Backlog 全做完 | N/A | **不結束**；依 §Step 4 走 L1 → L2 → L3 三段接力 |
| L3 擴量跑完 `docs/` 預先規劃 | 停下來等 deadline | 不再啟動新 L3 項目 |
| deadline 剩餘 < 10% | 主動收斂、標 ⏸️ | 不再啟動新 L3 項目 |

**結束後**：
- ✅ 純對話回應、解釋、推翻舊決策
- ✅ 等用戶指示才做事
- ❌ 不可自主延伸（反省、加 Bug、改進）
- ❌ 不可自動讀 trust-log（除非被問）

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.2 | 2026-01-15 | 新增「時間錨點」能力：啟動鎖死 START_TS/DEADLINE_TS、4 個關鍵節點查時間、trust-log 用絕對時間戳；外移 time-anchor.md 子檔避免觸發 150 上限 | 用戶回饋「時間不準」；deadline 可驗證、trust-log 可審查；V03 Reviewer 二審通過 |
| v2.1 | 2026-01-15 | Step 4 升級為三段接力（L1 接力 → L2 重訪 → L3 擴量）| 用戶回饋「提早完成就交差」；L3 對齊 `docs/` 預先規劃；V03 Reviewer 二審通過 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 | TMO-009 階段 4：LLM 注意力優化 |

---
---

**交叉引用**：
- Trust Log 完整範例 → 同套本 skill 子檔（`./examples.md`）
- 時間錨點完整紀律（4 個 checkpoint + T5 trust-log / 絕對時間戳 / 跨午夜 / 時區）→ 同套本 skill 子檔（`./time-anchor.md`）
- SOP 完整 5 階段 → 見 monorepo 對應的規劃 ~ 提交文件（路徑由 monorepo 約定）
- 結束後行為 → 同上 examples.md

---

**⚠️ 主檔行數預警**：v2.2 已外移 time-anchor.md、避免觸發 150 上限；目前主檔 138 行（130-149 預警區，未觸 150 上限）。下次再加功能優先擴 time-anchor.md / examples.md。
