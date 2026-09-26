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
   - **不自動停下**：提早完成不停，繼續找 Backlog 內能做的
   - **退出 trust 身份**：deadline 到 / 用戶叫停時退出，進入普通對話模式
   - **底線規則**：不可發外部指令、不可改不可逆文件（見 §規則）
5. **必產出物**：`docs/backlog.md` + `docs/trust-log.md` + `docs/need-you-help.md`（如有擔憂）+ `docs/deliverable/<...>.md`

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 用戶給「大目標 + Deadline」且明確說「trust mode」 | ✅ 必須 |
| 大型獨立功能（CRM、會員系統等）| ✅ 適合 |
| 已有清晰技術棧的擴展 | ✅ 適合 |
| 用戶可長時間不看對話 | ✅ 適合 |
| **沒給 deadline** | ❌ Agent 必須先問，不准啟動 |
| 需要即時互動的探索任務 | ❌ 走 dav-planner |
| 全新項目（無 backlog）| ❌ 先 dav-planner 探索 |
| 涉及金流 / 刪資料 / 生產操作 | ❌ 危險（見底線規則）|

## 流程（5 階段 SOP + 3 個 Trust 動作）

### Step 1：啟動條件驗證

- **動作**：確認「明確大目標 + 明確 Deadline」兩件事；缺 deadline 時停下問用戶
- **為什麼**：trust mode 是「放手讓 Agent 做」，沒 deadline 等於「無限責任」
- **產出**：對話中明示「Trust Mode 啟動 + 預估完成時間」
- **證據**：對話有「Trust Mode 啟動」+ deadline 字樣

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

### Step 4：擔憂跳過 + 認領下一個

- **動作**：對某 Backlog **有擔憂**時不執行，標 `⏸️ 待用戶確認`，寫 `docs/need-you-help.md`，**立即認領下一個**；Backlog 全做完仍不自動停下，繼續重訪 ⏸️ 跳過的、找漏網之魚，直到 deadline 到或用戶叫停
- **為什麼**：不悲觀停工、不停下來等用戶
- **產出**：`docs/need-you-help.md`（如有）+ 對話時間戳
- **證據**：need-you-help.md 存在（如有）；trust-log 有認領時間戳

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
| 提早完成不停下 | deadline 到或用戶叫停才停 | 不可「做完就交差」 |
| Backlog 全做完仍不自動停下 | deadline 到才停 | 必須繼續認領（重訪 ⏸️、找漏網） |
| 不可發外部指令 | N/A | 不寄 email / 課金 / 推送 / 刪線上資料 / 付費 API |
| 不可改不可逆文件 | N/A | 不 push master/main、不改 production |
| 退出 trust 後不再自動做事 | 用戶說「繼續 trust」可重啟 | 必須等用戶指示 |
| 退出後用戶問「為什麼這樣選」| ✅ 純對話解釋 | 不可重啟 trust |

## 底線規則（不可跨越）

| # | 規則 | 違反處理 |
|---|------|---------|
| 1 | 不可發外部指令（email / 課金 / 推送 / 刪線上資料 / 付費 API）| trust-log 強制記錄 + 停下等用戶 |
| 2 | 不可改不可逆文件（push master/main / 改 production）| trust-log 強制記錄 + 停下等用戶 |

## 結束邊界（核心新規範）

| 結束點 | 觸發 | Agent 動作 |
|--------|------|-----------|
| Deadline 到達 | 時間到 | 用 dav-submitter 提交 + `🏁 Trust Mode 已結束` |
| 用戶主動結束 | 「結束 trust」「停」| 同上 |
| Backlog 全做完 | N/A | **不結束**；繼續重訪 ⏸️、找漏網 |

**結束後**：
- ✅ 純對話回應、解釋、推翻舊決策
- ✅ 等用戶指示才做事
- ❌ 不可自主延伸（反省、加 Bug、改進）
- ❌ 不可自動讀 trust-log（除非被問）

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 | TMO-009 階段 4：LLM 注意力優化 |
| v1.x | — | （舊版 9 章節含 §5.5 / §9 結束邊界）| 詳見全域 SOP 變動歷史 v1.x |

---

**交叉引用**：
- Trust Log 完整範例 → 同套本 skill 子檔（`./examples.md`）
- SOP 完整 5 階段 → 見 monorepo 對應的規劃 ~ 提交文件（路徑由 monorepo 約定）
- 結束後行為 → 同上 examples.md
