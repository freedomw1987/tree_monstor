---
name: dav-designer
description: >-
  在 SOP「設計」階段使用：讀取 monorepo 對應的 backlog 檔，依 PENDING 項目輸出／更新 DESIGN.md、system-design.md、按模組拆分
  PRD（md）＋強制追溯矩陣，並產出**系統 demo 原型 app**（原型單位 = Surface：每個介面載體一條 route、React + Tailwind +
  shadcn/ui、共用 mock store、內置 demo 路線）；原型出爐前必走「設計自審」請用戶簽核。不適用於：純開發實作、純測試撰寫、純回顧。
---

# Dav Designer

## TL;DR

1. **做什麼**：backlog → UX/UI、系統架構、模組 PRD 三層文件 ＋ **一個系統 demo 原型 app**（唔再逐 Module 出孤島 html）。
2. **何時觸發／SOP 路徑**：SOP 設計 Gate，或用戶要求「設計 / 規劃 / 拉架構 / 畫原型 / 做 demo」；一般任務（設計唔寫 production code）。
3. **關鍵紀律**：V01 一次一個問題；V02 方案必標推薦；V03 改規範自查行數上限（代碼品質把關走同套 `dav-developer` skill）；demo app 先於實作（未過 Step 4.5 簽核不得入 Step 5）。
4. **必產出物**：`DESIGN.md` ＋ `system-design.md` ＋ `docs/prd/<序號-module>.md`（含追溯矩陣）＋ **demo app**（`prototype/<slug>/`）
自審報告（對話產出）＋ build 出單檔 `dist/index.html`（拎得走）。
5. **原型單位 = Surface**（`web-admin`／`mobile-app`／`tablet-app`／`cli-terminal`），唔再 = Module；
每 Surface 一條 route，共用 design tokens ＋ 單一 mock store。

## 觸發時機

- **SOP 進入設計 Gate**，或用戶說「幫我設計 / 規劃 / 拉架構」／「畫原型 / 做 demo / mockup」 → ✅ 必須
- **用戶說「更新 PRD / DESIGN」** → ✅ 觸發本 skill 增量更新
- **純開發實作（寫 production code / 跑測試）** → ❌ 走 dav-developer；**純回顧（批次結束反省）** → ❌ 走 dav-reviewer；**純諮詢** → ❌ 不觸發

## 流程（6 步）

- **Step 1 backlog ＋ Module 切割 ＋ Surface 映射 ＋ DoD 深度** → 三份清單；細節見 [`workflow.md`](./workflow.md) Step 1
- **Step 2 UX/UI ＋ 系統 Shell ＋ Design Tokens** → `DESIGN.md`；細節見 [`workflow.md`](./workflow.md) Step 2
- **Step 3 系統架構** → `system-design.md`（Module／Surface 邊界）＋ backlog 標 Module／故事點；見 [`workflow.md`](./workflow.md) Step 3
- **Step 4 模組 PRD** → `docs/prd/<序號-module>.md`（含追溯矩陣）；細節見 [`workflow.md`](./workflow.md) Step 4
- **Step 4.5 設計自審 ＋ 用戶簽核（必走）** → 6 維自審報告 ＋ 用戶「簽核／退回」；未簽核不進 Step 5；細節見 [`workflow.md`](./workflow.md) Step 4.5
- **Step 5 系統 demo 原型 app** → `prototype/<slug>/`（React + Tailwind + shadcn/ui，每 Surface 一條 route）；規格見 [`system-prototype.md`](./system-prototype.md)

## 規則 / 例外 / 限制

- **必產 4 份文件 ＋ 自審報告；PRD.md 必含追溯矩陣；進 Step 5 前必走自審 ＋ 簽核** → 同套 `./rules.md` §1
- **原型單位 = Surface；demo app 必 stack 合規 ＋ build 綠 ＋ 單檔拎得走 ＋ demo 路線行得通** → 同套 `./rules.md` §2
- **demo app 係設計期原型：唔寫 production 後端／真實業務邏輯** → 同套 `./rules.md` §3
- **本 skill 不寫 Backlog / US；術語一致** → 同套 `./rules.md` §4
- **修改本 skill 必走 v2.3 修改流程 ＋ 清規範偏差；純文字引用** → 同套 `./rules.md` §5

## 交叉引用

- 規則完整版 → 同套 [`rules.md`](./rules.md)；流程細節 → 同套 [`workflow.md`](./workflow.md)
- 原型品質（狀態／自審）→ 同套 [`prototype-quality.md`](./prototype-quality.md)
- 系統 demo app 規格（Surface／stack／demo 路線）→ 同套 [`system-prototype.md`](./system-prototype.md)
- Design Gate 通過條件 → 同套 [`design-gate.md`](./design-gate.md)；規劃技巧 → 見同套 dav-planner skill
- Module 生命週期範例 → 見本 skill 的 [`examples/system-design.md`](./examples/system-design.md)
