---
name: dav-designer
description: 在 SOP「設計」階段使用。讀取 monorepo 對應的 backlog 檔，依 PENDING 狀態項目輸出/更新 DESIGN.md、system-design.md、按模組拆分 PRD（md）+ 強制追溯矩陣，並為每個模組產出可即點即試的互動 HTML 原型（高保真，DoD 含 5 種狀態）。原型出爐前必走「設計自審」請用戶簽核。**不適用於**：純開發實作、純測試撰寫、純回顧。
---

# Dav Designer

## TL;DR

1. **做什麼**：在設計階段把 monorepo 對應的 backlog 拆解到 UX/UI、技術架構、模組 PRD 三層文件，並為每個模組產出**可即點即試的互動 HTML 原型**（取代靜態 PRD html）。
2. **何時觸發**：SOP §2.2 設計 Gate 或用戶明確要求「設計 / 規劃 / 拉架構 / 畫原型」。
3. **SOP 路徑**：§2.6 一般任務（設計本身不寫程式碼、不跑測試，屬輔助產出）。
4. **關鍵紀律**：
   - **V01**：一次一個問題，模組多時依序處理
   - **V02**：方案必標推薦
   - **V03**：本 skill 修改必走 Reviewer 二審
   - **互動原型先於實作**：未走 Step 4.5 自審 + 用戶簽核，不得進入 Step 5 產原型
5. **必產出物**：`DESIGN.md` + `system-design.md` + `docs/prd/<序號-module>.md`（含追溯矩陣）+ `docs/prd/<序號-module>.html`（**互動原型**）+
   自審報告（對話產出）

## 觸發時機

| 情境 | 觸發 |
|------|------|
| SOP 進入 §2.2 設計 Gate | ✅ 必須 |
| 用戶說「幫我設計 / 規劃 / 拉架構」 | ✅ 必須 |
| 用戶說「畫個原型 / 做 wireframe / mockup」 | ✅ 必須 |
| 用戶說「更新 PRD / DESIGN」 | ✅ 觸發本 skill 增量更新 |
| 純開發實作（寫 code / 跑測試） | ❌ 不觸發，請走 dav-developer / tdd-test-writer |
| 純回顧 / sprint 結束反省 | ❌ 不觸發，請走 dav-reflection |
| 純諮詢 / 問問題 | ❌ 不觸發 |

## 流程（6 步）

> 跑 Step 1-5 時逐條查 `workflow.md` 的細節；本檔只留「Step 簡介 + 產出 + 參考」。

### Step 1：讀取 backlog + Module 切割 + DoD 深度

- **產出**：Module 清單（Module 名稱 / backlog IDs / **DoD 深度**）。
- **參考**：`workflow.md` Step 1（含 Module 目的、切割原則 5 條、DoD-Lite / DoD-Full 對照）。

### Step 2：UX/UI 規劃（DESIGN.md）

- **產出**：`DESIGN.md`（畫面樹、互動流程、元件庫）。
- **參考**：`workflow.md` Step 2。

### Step 3：系統架構設計（system-design.md）

- **產出**：`system-design.md`（技術棧、模組邊界圖、資料流）；同步更新 backlog 給每個 US 標上 Module 與 Story Point。
- **Module 邊界即測試邊界**（v2.3）：system-design.md 的 Module 邊界 = dev-checker-loop / regression-guard 未來的執行邊界（探針不跨 Module）。
- **參考**：`workflow.md` Step 3。

### Step 4：模組 PRD（md，含追溯矩陣）

- **產出**：`docs/prd/<序號-module>.md`（每 Module 一份，含 FR / AC / 依賴 / **追溯矩陣**）。
- **追溯矩陣必含 5 欄**：FR / US / 畫面 / 原型檔案 / 狀態（模板見 `prototype-quality.md` §4）。
- **參考**：`workflow.md` Step 4。

### Step 4.5：設計自審 + 用戶簽核（必走，不可跳）

- **產出**：對話中「自審報告：5 維度全綠 / 待修 X」+ 用戶明確「簽核 / 退回」。
- **未簽核不進 Step 5**。
- **參考**：`workflow.md` Step 4.5；自審 5 維度細節見 `prototype-quality.md` §2。

### Step 5：互動 HTML 原型（取代靜態 PRD html）

- **產出**：`docs/prd/<序號-module>.html`（單檔、內嵌 CSS + JS、雙擊即開）。
- **依 Step 1 DoD 深度執行**（Lite / Full），品質細節（DoD 5 狀態、自審 5 維度）見 `prototype-quality.md`。
- **參考**：`workflow.md` Step 5（含原型必含 / 禁止二表）。

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 必產 4 份文件 + 自審報告 | 用戶明確「只更新 X」可增量 | 不可只出 md 不出原型 html |
| PRD.md 必含追溯矩陣 | 既有 PRD 增量更新可補 | 新 PRD 不可缺 |
| 進 Step 5 前必走 Step 4.5 自審 + 用戶簽核 | 用戶明確「跳過自審」可省 | 預設必走 |
| 互動原型依 Step 1 DoD 深度執行 | 預設 DoD-Lite（只 Happy path）| DoD-Full 需用戶 Step 1 明確選 |
| HTML 原型必為單檔 | 多畫面 Module 可拆多檔 | 單檔 < 500 行 |
| 必用高保真視覺 | 用戶明確要求 wireframe 可降階 | 預設 HiFi，MidFi 需用戶指定 |
| 必用 Mock 資料 | 用戶要求接真實 API 可例外 | 原型階段禁止實際後端 |
| system-design.md 不可有真實程式碼 | 純文字示意（如 JSON 結構）允許 | 禁止 import / class / function 範例 |
| PRD md 與 html 須內容一致 | 原型可加視覺化補充 | FR 編號、AC 條目、追溯矩陣需對齊 |
| 與 dav-planner 邊界：本 skill 不寫 Backlog / US | N/A | US / AC 由 dav-planner（§2.1）產 |
| 修改本 skill 必走 v2.3 修改流程 | 純錯字修正可跳過 | ≧ 3 行修改必走 M-Step 1-3 |
| 修改同時必清規範偏差 | 用戶明確「只動 A 不動 B」例外 | 不可累積技術債 |
| 純文字引用（v2.2）| skill 子檔可用 markdown | 不寫跨 dir 路徑引用 |

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.5 | 2026-09-26 | 自包含化：搬入 `examples/system-design.md`（原 monorepo 範例總目錄內的 docs 子目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/system-design.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.4 | 2026-09-26 | 拆檔：主檔瘦身到 ~75 行，Step 1-5 全剖細節 → `workflow.md` | 達 150 行上限；與 dav-planner v2.2 拆檔哲學一致 |
| v2.3 | 2026-09-26 | +Module 目的與切割原則（Step 1）+ Module 邊界即測試邊界（Step 3）| 用戶決策：Module 為「可獨立開發 / 增減 / 測試」的功能單位 |

---
---

**交叉引用（純文字）**：
- Step 1-5 流程細節（含 Module / 原型規範二表）→ 同套 `workflow.md`
- 互動原型品質細節（DoD 5 狀態 / 自審 5 維度 / 矩陣模板）→ 同 skill 子檔 `prototype-quality.md`
- 規劃技巧（多輪提問 / INVEST AC / DoD）→ 見同套 dav-planner skill（需同套安裝，§2.1 規劃階段）
- Module 完整生命週期範例 → 見本 skill 的 `examples/system-design.md`
- 完整 SOP §2.1-§2.5 → 見 monorepo 對應的 handbook 目錄（路徑由 monorepo 約定）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
