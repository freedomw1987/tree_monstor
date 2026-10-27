---
name: dav-designer
description: 在 SOP「設計」階段使用。讀取 monorepo 對應的 backlog 檔，依 PENDING 狀態項目輸出/更新 DESIGN.md、system-design.md、按模組拆分 PRD（md）+
強制追溯矩陣，並為每個模組產出可即點即試的互動 HTML 原型（高保真，DoD 含 5 種狀態）。原型出爐前必走「設計自審」請用戶簽核。**不適用於**：純開發實作、純測試撰寫、純回顧。
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

- **SOP 進入 §2.2 設計 Gate**
  - 觸發：✅ 必須
- **用戶說「幫我設計 / 規劃 / 拉架構」**
  - 觸發：✅ 必須
- **用戶說「畫個原型 / 做 wireframe / mockup」**
  - 觸發：✅ 必須
- **用戶說「更新 PRD / DESIGN」**
  - 觸發：✅ 觸發本 skill 增量更新
- **純開發實作（寫 code / 跑測試）**
  - 觸發：❌ 不觸發，請走 dav-developer
- **純回顧 / sprint 結束反省**
  - 觸發：❌ 不觸發，請走 dav-submitter（Step 3.5 反省）
- **純諮詢 / 問問題**
  - 觸發：❌ 不觸發

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
- **Module 邊界即測試邊界**（v2.3）：system-design.md 的 Module 邊界 = dav-developer 未來的執行邊界（探針不跨 Module）。
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

- **必產 4 份文件 + 自審報告** — 例外：用戶明確「只更新 X」可增量；限制：不可只出 md 不出原型 html
- **PRD.md 必含追溯矩陣** — 例外：既有 PRD 增量更新可補；限制：新 PRD 不可缺
- **進 Step 5 前必走 Step 4.5 自審 + 用戶簽核** — 例外：用戶明確「跳過自審」可省；限制：預設必走
- **互動原型依 Step 1 DoD 深度執行** — 例外：預設 DoD-Lite（只 Happy path）；限制：DoD-Full 需用戶 Step 1 明確選
- **HTML 原型必為單檔** — 例外：多畫面 Module 可拆多檔；限制：單檔 < 500 行
- **必用高保真視覺** — 例外：用戶明確要求 wireframe 可降階；限制：預設 HiFi，MidFi 需用戶指定
- **必用 Mock 資料** — 例外：用戶要求接真實 API 可例外；限制：原型階段禁止實際後端
- **system-design.md 不可有真實程式碼** — 例外：純文字示意（如 JSON 結構）允許；限制：禁止 import / class / function 範例
- **PRD md 與 html 須內容一致** — 例外：原型可加視覺化補充；限制：FR 編號、AC 條目、追溯矩陣需對齊
- **與 dav-planner 邊界：本 skill 不寫 Backlog / US** — 例外：N/A；限制：US / AC 由 dav-planner（§2.1）產
- **術語一致（跟 dav-planner 術語表）** — 例外：專案層冇術語表 → 照常用詞；限制：專案層有 `docs/glossary_list.md` → PRD / 原型一律用入面嘅術語，唔好用同義詞
- **修改本 skill 必走 v2.3 修改流程** — 例外：純錯字修正可跳過；限制：≧ 3 行修改必走 M-Step 1-3
- **修改同時必清規範偏差** — 例外：用戶明確「只動 A 不動 B」例外；限制：不可累積技術債
- **純文字引用（v2.2）** — 例外：skill 子檔可用 markdown；限制：不寫跨 dir 路徑引用

---

**交叉引用（純文字）**：
- Step 1-5 流程細節（含 Module / 原型規範二表）→ 同套 `workflow.md`
- 互動原型品質細節（DoD 5 狀態 / 自審 5 維度 / 矩陣模板）→ 同 skill 子檔 `prototype-quality.md`
- 規劃技巧（多輪提問 / INVEST AC / DoD）→ 見同套 dav-planner skill（需同套安裝，§2.1 規劃階段）
- Module 完整生命週期範例 → 見本 skill 的 `examples/system-design.md`
- 完整 SOP §2.1-§2.5 → 見 monorepo 對應的 handbook 目錄（路徑由 monorepo 約定）
