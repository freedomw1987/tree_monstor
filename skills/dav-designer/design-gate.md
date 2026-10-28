# Dav Designer — Design Gate（設計階段）

> 本檔係設計階段嘅規則本體（2026-10-28 起由 `docs/sop/handbook/` 搬入本 skill）。
> ⚠️ **只適用於非 trust 嘅開發編程任務路徑** —— trust 進行中唔跑設計階段：設計係 trust 嘅啟動前置條件（含用戶簽核），
> 必須喺 trust 啟動前完成；trust 內只跑執行 → 反省 → 提交（見同套 `dav-trust` skill）。

## 設計目標

用戶有可能想做一項好大的工作任務，所以你為他計劃如何去執行，並給用戶確認；
**務必使用本 skill（`/skill:dav-designer`）**；

## fail-fast Design Gate — 設計 gate（必須通過才能進入執行階段）

- **觸發**：本 skill 走完 Step 1-5（Step 4.5 自審 ＋ 用戶簽核係 Step 5 嘅前置）
- **通過條件**：
  1. 產出以下文檔（依任務範圍，唔係每次都要全部）：
     - `docs/DESIGN.md` — UX/UI 規劃（含 RWD 考量）
     - `docs/system-design.md` — 系統架構設計
     - `docs/prd/<feature>.md` — 各功能 PRD
  2. **Story Point 估算（Fibonacci）**：每個 US 估算 1 / 2 / 3 / 5 / 8 / 13；用嚟判斷 Module 批次大小（**冇 sprint 容量／velocity**）
     - **規模對照（用於估算時參考）**：
       - **1** — 規模：微；參考工作量：數分鐘；典型例子：改 typo／加 log／改一個常數
       - **2** — 規模：小；參考工作量：數十分鐘–1 小時；典型例子：改一個 function／加 1 個 unit test
       - **3** — 規模：中；參考工作量：半日；典型例子：加一個 component／改一個模組嘅 API
       - **5** — 規模：大；參考工作量：1–2 日；典型例子：重構一個模組／跨 3–5 個檔案改動
       - **8** — 規模：超大（XL）；參考工作量：3–5 日；典型例子：新建一個子系統／跨模組整合
       - **13** — 規模：巨大（XXL）；參考工作量：1–2 週；典型例子：完整新功能模組／大型重構
       - **>13** — 規模：應拆分；參考工作量：超過 1 個 Module 批次就該拆 Module；典型例子：拆成 US-A（5）＋ US-B（8）
     - **不確定時往上估算**（vs. 往下）—— 過度樂觀係 SOP 違規嘅最常見源頭
  3. **Module 批次拆分**：**1 個批次 = 1 個完整 Module**（Module 切割見 Step 1）；批次內 US 集合 = 該 Module 嘅 US；
     批次先後順序按依賴排（見同套 `workflow.md` Step 1）
  4. **用戶明確確認**「OK 計劃完成，可以進入執行階段」才可進入下一階段
- **不通過 = 不可進入執行階段**
- **「假裝通過」視為失敗**（見同套 `dav-router` skill 嘅違規回報規則）：
  - ❌ 沒產出 `docs/DESIGN.md`／`system-design.md`／PRD 就聲稱「計劃完成」
  - ❌ 沒做 Story Point 估算就拆 Module 批次
  - ❌ 用戶沒明確確認就跳到執行階段
