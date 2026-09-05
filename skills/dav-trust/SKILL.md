---
name: dav-trust
description: 當用戶提供「大目標 + 時間 deadline」並希望 Agent 自主完成、中間不打擾、由 Agent 代答所有中間問題時使用。Agent 走 SOP 5 階段（規劃→設計→執行→反省→提交），代答寫進 docs/trust-log.md，完成後用戶驗收。提早完成或 deadline 到達時自動停下，**結束後 Agent 退出 trust 身份、進入普通對話模式、不再自動做事**。
---

## 1. 什麼是 dav-trust

信任模式：把「大目標 + Deadline」交給 Agent，Agent 自主完成從拆解到提交的全流程。

**核心承諾**：
- ✅ 不會中途問問題（設計歧義、技術選型、命名都自己決定）
- ✅ 所有代答有時間戳 + 理由 + 可推翻標記
- ✅ 到 deadline **或提早完成**時自動停下，輸出 `🏁 Trust Mode 已結束`
- ✅ 結束後退出 trust 身份、進入普通對話模式（見 §9）
- ✅ 對 Backlog 有擔憂時**跳過不執行**，記錄到 `docs/need-you-help.md`，**不停下來等用戶**（見 §5.5）

## 2. 適用場景

| ✅ 適用 | ❌ 不適用 |
|--------|----------|
| 大型獨立功能（CRM、會員系統等） | 需要即時互動的探索任務 |
| 已有清晰技術棧的擴展 | 全新項目（先 dav-planner 探索） |
| 用戶可長時間不看對話 | 涉及金流、刪資料、生產操作 |

## 3. 啟動條件

必須明確兩件事，缺一不可：

1. **大目標**：要做什麼（可模糊但不可無）
2. **Deadline**：明確時間（例「2 小時」「今天下班前」）

> ⚠️ 沒給 deadline 時，Agent 必須主動詢問後才啟動。

## 4. 工作流程（SOP 5 階段）

每階段遇到任何問題，**Agent 自己決定 + 寫 trust-log**，禁止呼叫 `ask_user_question`。

| 階段 | 動作 | 觸發 skill |
|------|------|-----------|
| 1. 規劃 | 拆 Backlog、寫 `docs/backlog.md` | `dav-planner` |
| 2. 設計 | 寫 `docs/design.md`、`docs/system-design.md` | `dav-designer` |
| 3. 執行 | Gate 1-4 逐個通過 | `tdd-test-writer`、`regression-guard`、`dev-checker-loop` |
| 4. 反省 | 6 維度檢查、補技術債 | `dav-reflection` |
| 5. 提交 | 對話摘要 + Markdown + HTML | `dav-submitter` |

## 5. Trust Log 規範

- **路徑**：`docs/trust-log.md`
- **觸發**：任何代答決定
- **時機**：決定做出**當下**立刻寫，不延遲
- **格式**：問題 / 決策 / 理由 / 可推翻 — 完整範本見 [[examples.md]]

## 5.5 擔憂處理 & 自動認領 ⭐ 新規範

### 5.5.1 自動認領原則

- **主軸**：`docs/backlog.md` 裏的 Backlog
- **順序**：優先級 P0 → P1 → P2 → P3；同優先級按 Story Points 小→大
- **不留白**：即使時間看起來不夠做完全部，繼續認領下一個能做的
- **不停下來等**：不因為「時間不夠」就悲觀停工
- **時間追蹤**：每階段記時間戳；剩餘 < 20% 自動縮小範圍

### 5.5.2 擔憂跳過機制

Agent 對某 Backlog **有擔憂**（技術風險、依賴不穩、業務不確定）時：

1. **不執行**那個 Backlog，標為 `⏸️ 待用戶確認（擔憂）`
2. 寫入 `docs/need-you-help.md`（首次創建，後續 append）
3. **立即認領下一個** Backlog
4. 最終交付把 need-you-help.md 列入輸出物

### 5.5.3 need-you-help.md 格式

每條記錄包含：Backlog ID、具體擔憂、影響範圍、用戶抉擇（繼續做 / 改設計 / 跳過）。完整範本 → [[examples.md]]

## 6. Deadline 處理

### 6.1 時間內完成

走完整 5 階段，submission 標註「✅ 全部完成」。

### 6.2 時間到未完成

立即停止、跳過階段 4、用 `dav-submitter` 提交（含已完成 / 未完成清單）、trust-log 寫「⏰ Deadline 到達」。

### 6.3 提早完成（早於 deadline）⚠️ 不延伸工作

所有 Backlog ✅ 完成時：
1. **立即**提交，標註「提早 X 分鐘」
2. **不要**主動加做（測試改進、重構、新功能）
3. 直接進入 §9 結束邊界

## 7. 底線規則（不可跨越）

| # | 規則 |
|---|------|
| 1 | **不可發出外部指令**：不寄 email、課金、推送通知、刪線上資料、呼叫付費 API |
| 2 | **不可修改不可逆文件**：不直接 push master/main、不改 production |

違反處理：trust-log 強制記錄 + 停下來等用戶。

## 8. 輸出物

| 文件 | 必填 |
|------|------|
| `docs/backlog.md` | ✅ |
| `docs/design.md`、`docs/system-design.md` | 視需要 |
| `docs/trust-log.md` | ✅ |
| `docs/need-you-help.md` | ⚠️ 有擔憂時才生成 |
| `docs/deliverable/<date>-<slug>.{md,html}` | ✅ |

## 9. Trust Mode 結束邊界 ⭐

> **這是 trust mode 最重要的一條新規範** — Agent 必須明確知道何時停止，以及停止後怎樣回應用戶。

### 9.1 三種結束點

- ✅ **提早完成**（見 §6.3）
- ⏰ **Deadline 到達**（見 §6.2）
- 🛑 **用戶主動結束**：「結束 trust mode」「停」

### 9.2 結束時必做 3 動作

1. 用 `dav-submitter` 提交最終交付
2. 對話明確輸出 `🏁 Trust Mode 已結束`
3. trust-log 寫最終記錄（結束時間 + 原因）

### 9.3 結束後的 Agent 行為 ⭐ 核心新規範

**Agent 自動退出 trust 身份，進入普通對話模式：**

| ❌ 不再做 | ✅ 改為 |
|----------|--------|
| 自主做事、寫代碼 | 等用戶指示 |
| 自動讀 trust-log | 只在被問時參考 |
| 代答新問題 | 純對話回應 |
| 自動延伸工作（反省、加 Bug、修改進） | **必須等用戶明確指示** |
| 用戶問「為什麼這樣選？」 | ✅ 純對話解釋 |
| 用戶推翻某條決策 | ✅ 改並標「事後修改（用戶指示）」 |
| 用戶要加新任務 | 🚀 啟動新 trust mode，或保持普通對話 |

### 9.4 重新進入

用戶說「繼續 trust mode」或「新任務用 trust mode 跑 X 分鐘」即重啟。

---

**範本、結束後行為對照表、反模式**：→ [[examples.md]]
