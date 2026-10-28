---
name: dav-trust
description: >-
  信任模式。用戶給「大目標 + deadline」後 Agent 自主完成 SOP 執行段（執行 → 反省 → 提交），中途不問問題（自己寫 trust-log 代答），deadline 到 / 用戶叫停時自動退出 trust
  身份。規劃 / 設計須在啟動前完成，trust 內不跑。冇 deadline、需即時互動的探索、危險操作唔用。
---
# Dav Trust

## TL;DR
1. **做什麼**：把「大目標 + Deadline」交俾 Agent 自主完成 → SOP 執行段（執行 → 反省 → 提交），中途所有代答寫入 `docs/trust-log.md`。
2. **何時觸發**：用戶明確說「trust mode 跑 X」／「自己做完再叫我」＋ 提供 deadline。
3. **預設 SOP 路徑**：啟動 → 執行（Gate 1/2/3）→ 反省 ＋ 提交（同套 `dav-reviewer` skill）→ 退出；**規劃／設計係前置條件**（trust 內不可跑）。
4. **關鍵紀律**：不問用戶（歧義／選型／命名自己決定 ＋ 寫 trust-log）／不自動停下（Step 4 三段接力）／deadline 到或叫停即退出。
5. **必產出物**：`docs/backlog.md` ＋ `docs/trust-log.md` ＋ `docs/need-you-help.md`（如有）＋ `docs/deliverable/<...>.md`。
6. **子檔導航**：啟動前檢查／拒絕啟動 → `./preflight.md`；續跑／叫停 → `./resume.md`；時間錨點 → `./time-anchor.md`；範例 → `./examples.md`。

## 觸發時機
- ✅ **觸發**：用戶給「大目標 + Deadline」且明確說「trust mode」；大型獨立功能；已有清晰技術棧的擴展；用戶可長時間不看對話。
- ❌ **不觸發**：冇 deadline 或 deadline 模糊（必須先問）；需即時互動嘅探索任務（走同套 `dav-planner` skill）；全新項目（無 backlog／無設計）；金流／刪資料／生產操作（危險）。

## 流程（SOP 執行段 ＋ 3 個 Trust 動作）
- **Step 1 啟動條件驗證 ＋ 時間錨點鎖死** — 確認「大目標 + Deadline」＋「既有 backlog（US 含 AC）」＋「設計覆蓋」；缺 deadline → 問一次（唯一允許嘅啟動前打斷）；缺
backlog／設計全缺 → **拒絕啟動**（唯一例外：用戶明確覆核 → trust-log 必記覆核）；通過後 `date` 查時間 → 鎖死 `START_TS` ＋ `DEADLINE_TS`，對話明示「Trust Mode 啟動
  ＋ 兩個錨點」。**為什麼**：冇 deadline = 無限責任；缺 backlog／設計 = 啟動即卡死。細節 → `./preflight.md` §2–3 ＋ `./time-anchor.md` §1
- **Step 2 SOP 執行段（3 階段，Agent 自主）** — §2.3 執行（Gate 1/2/3）→ §2.4 反省 → §2.5 提交；
  **不做** §2.1 規劃／§2.2 設計（需用戶互動、與「不問用戶」互斥）；Gate 4 審核 ＋ Gate 4.5 對帳係**人手觸發**嘅 `dav-reviewer` skill。
- **Step 3 代答寫進 Trust Log** — 任何歧義／技術選型／命名決定都寫 `docs/trust-log.md`（時間戳 ＋ 問題 ＋ 決策 ＋ 理由 ＋ 可推翻標記），trust 結束後用戶可審查、推翻。
- **Step 4 三段接力（L1 接力 → L2 重訪 → L3 擴量）** — **L1**：當前 Backlog 完成 → 立即認領下一個 PENDING；**L2**：全 PENDING 做完 → 重訪所有 ⏸️
待確認能否用「保守做法」補上（**因設計缺口而未實作嘅 ⏸️ 不在 L2 範圍**）；**L3**：仍剩時間 ＋ 已無 PENDING → **對齊 `docs/` 預先規劃**自主擴量（更新 backlog 標 `🆕 自主擴量` ＋
  trust-log）。
- **Step 5 退出 Trust Mode** — deadline 到／用戶叫停 → 同套 `dav-reviewer` skill 提交 → 輸出 `🏁 Trust Mode 已結束` → 退出 trust
身份（「暫停」＝只輸出 `⏸️ Trust Mode 已暫停（可續跑）`、**不退出身份**）。

## 規則 / 例外 / 限制
- **中途不問用戶問題** — 例外：缺 deadline／危險操作仍可問；限制：問之前先寫 trust-log 解釋為何要問
- **規劃／設計階段不得在 trust 內執行** — 例外：N/A；限制：需用戶互動、與「不問用戶」互斥；一律啟動前完成（遞延見 preflight.md §5）
- **執行期設計缺口只補最小技術契約** — 例外：N/A；限制：資料模型／API／技術棧／錯誤處理／檔案與模組結構／邊界清單寫 trust-log；不產原型、不等簽核
- **所有代答寫 trust-log** — 例外：N/A；限制：不可只在對話講、不寫 log
- **提早完成不停下／Backlog 全做完仍不自動停下** — 例外：deadline 到或用戶叫停才停；限制：依 Step 4 走 L1 → L2 → L3，不可「做完就交差」
- **L3 擴量來源限於 `docs/` 預先規劃** — 例外：N/A；限制：限 `docs/roadmap.md`／backlog 未跑項目／`docs/design.md` 延伸項目
- **L3 自主擴量必更新 backlog ＋ 必同步寫 trust-log** — 例外：N/A；限制：加 `🆕 自主擴量` 標記、事後可一鍵 reject；每個決策當下寫 log
- **L3 不可做危險／不可逆／外部指令** — 例外：違反 = 退出 trust mode；限制：同底線規則
- **deadline 是 L3 硬上限** — 例外：deadline 到自動停止；限制：剩餘 < 10% 主動收斂、不再啟動新 L3 項目
- **時間錨點須真實查時間** — 例外：N/A；限制：啟動／完成每 Backlog／L3 收斂／退出 4 個 checkpoint 必查 `date`；詳見 time-anchor.md
- **不可發外部指令／不可改不可逆文件** — 例外：N/A；限制：見底線規則 ① ②
- **中斷後續跑** — 例外：用戶說「繼續 trust」；限制：session 崩潰／context 壓縮 → 讀 trust-log 檔頭 checkpoint 重建狀態；已過 deadline → 收斂
- **用戶叫停立即收斂** — 例外：N/A；限制：先分流「結束」／「暫停」；序列見 resume.md §4
- **退出 trust 後不再自動做事** — 例外：用戶說「繼續 trust」可續跑（已過 deadline → 只能收斂）；限制：必須等用戶指示
- **底線規則（不可跨越）** — ①不可發外部指令（email／課金／推送／刪線上資料／付費 API）②不可改不可逆文件（push master/main／改 production）③不可擅自改
deadline；違反：trust-log 強制記錄 ＋ 停下等用戶
