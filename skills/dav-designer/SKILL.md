---
name: dav-designer
description: >-
  在 SOP「設計」階段使用：讀取 monorepo 對應的 backlog 檔，依 PENDING 項目輸出／更新 DESIGN.md、system-design.md、按模組拆分
  PRD（md）＋強制追溯矩陣，並為每個模組產出可即點即試的互動 HTML 原型（高保真、DoD 含 5 種狀態）；原型出爐前必走「設計自審」請用戶簽核。不適用於：純開發實作、純測試撰寫、純回顧。
---

# Dav Designer

## TL;DR

1. **做什麼**：把 backlog 拆成 UX/UI、系統架構、模組 PRD 三層文件 ＋ 每模組互動 HTML 原型（取代靜態 PRD html）。
2. **何時觸發／SOP 路徑**：SOP 設計 Gate，或用戶要求「設計 / 規劃 / 拉架構 / 畫原型」；一般任務（設計本身不寫程式碼、不跑測試，屬輔助產出）。
3. **關鍵紀律**：V01 一次一個問題；V02 方案必標推薦；V03 改規範自查行數上限（代碼品質把關走同套 `dav-developer` skill）；互動原型先於實作（未過 Step 4.5 簽核不得入 Step 5）。
4. **必產出物**：`DESIGN.md` ＋ `system-design.md` ＋ `docs/prd/<序號-module>.md`（含追溯矩陣）＋ `docs/prd/<序號-module>.html`（互動原型）＋
自審報告（對話產出）。

## 觸發時機

- **SOP 進入設計 Gate**，或用戶說「幫我設計 / 規劃 / 拉架構」／「畫個原型 / 做 wireframe / mockup」 → ✅ 必須
- **用戶說「更新 PRD / DESIGN」** → ✅ 觸發本 skill 增量更新
- **純開發實作（寫 code / 跑測試）** → ❌ 走 dav-developer；**純回顧（Module 批次結束反省）** → ❌ 走 dav-reviewer（Step 3.5 反省）；**純諮詢 / 問問題** → ❌
不觸發

## 流程（6 步）

- **Step 1 讀 backlog ＋ Module 切割 ＋ 批次清單 ＋ DoD 深度** → Module 清單 ＋ 批次清單；細節見 [`workflow.md`](./workflow.md) Step 1
- **Step 2 UX/UI 規劃** → `DESIGN.md`（畫面樹、互動流程、元件庫）；細節見 [`workflow.md`](./workflow.md) Step 2
- **Step 3 系統架構設計** → `system-design.md`（技術棧、模組邊界圖、資料流）＋ backlog 每個 US 標 Module／Story Point；細節見
[`workflow.md`](./workflow.md) Step 3
- **Step 4 模組 PRD** → `docs/prd/<序號-module>.md`（FR / AC / 依賴 / 追溯矩陣 5 欄）；細節見 [`workflow.md`](./workflow.md) Step 4
- **Step 4.5 設計自審 ＋ 用戶簽核（必走）** → 自審報告 ＋ 用戶「簽核／退回」；未簽核不進 Step 5；細節見 [`workflow.md`](./workflow.md) Step 4.5 ＋
[`prototype-quality.md`](./prototype-quality.md) §2
- **Step 5 互動 HTML 原型** → `docs/prd/<序號-module>.html`（單檔、內嵌 CSS ＋ JS、雙擊即開），依 Step 1 選定 DoD 深度；細節見
[`workflow.md`](./workflow.md) Step 5；**Design Gate 通過條件 → 同套 [`design-gate.md`](./design-gate.md)**

## 規則 / 例外 / 限制

- **必產 4 份文件 ＋ 自審報告；PRD.md 必含追溯矩陣；進 Step 5 前必走 Step 4.5 自審 ＋ 用戶簽核** — 例外／限制 → 同套 `./rules.md` §1
- **互動原型依 Step 1 DoD 深度執行；原型必為單檔、高保真、用 Mock 資料** — 例外／限制 → 同套 `./rules.md` §2
- **system-design.md 不可有真實程式碼；PRD md 與 html 須內容一致** — 例外／限制 → 同套 `./rules.md` §3
- **本 skill 不寫 Backlog / US；術語一致（跟 dav-planner 術語表）** — 例外／限制 → 同套 `./rules.md` §4
- **修改本 skill 必走 v2.3 修改流程 ＋ 清規範偏差；純文字引用（v2.2）** — 例外／限制 → 同套 `./rules.md` §5

## 交叉引用

- 規則／例外／限制完整版 → 同套 [`rules.md`](./rules.md)；Step 1-5 流程細節 → 同套 [`workflow.md`](./workflow.md)；原型品質細節 → 同 skill 子檔 [`prototype-quality.md`](./prototype-quality.md)
- 規劃技巧（多輪提問／INVEST AC／DoD）→ 見同套 dav-planner skill；Module 完整生命週期範例 → 見本 skill 的
[`examples/system-design.md`](./examples/system-design.md)；Design Gate（設計 gate）通過條件 → 同套 [`design-gate.md`](./design-gate.md)
