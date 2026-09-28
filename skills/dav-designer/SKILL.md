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
5. **必產出物**：`DESIGN.md` + `system-design.md` + `docs/prd/<序號-module>.md`（含追溯矩陣）+ `docs/prd/<序號-module>.html`（**互動原型**）+ 自審報告（對話產出）

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

### Step 1：讀取 backlog 並標定範圍 + 詢問 DoD 深度

- **動作**：讀取 monorepo 對應的 backlog 檔，篩選 `status = PENDING` 的項目；依功能內聚性分群為 Module。**同時詢問用戶每個 Module 的 DoD 深度（DoD-Lite / DoD-Full）**。
- **為什麼**：避免一次處理全部 backlog 導致設計過廣；DoD 深度在 Step 1 一次問清，避免 Step 5 再打斷流程。
- **產出**：Module 清單（含 Module 名稱 / backlog IDs / **DoD 深度**）。
- **DoD 深度選項**（Step 1 必問一次）：

  | 模式 | 必含狀態 | 適用場景 |
  |------|----------|----------|
  | ⭐ **DoD-Lite（預設）** | Happy path | 玩具 / 內部工具 / 簡單模組 |
  | **DoD-Full** | Happy + Loading + Empty + Error + Edge | 正式產品 / 對外功能 / 複雜模組 |

- **證據**：對話中明確列出「本次處理 Module X（含 backlog #A, #B）— DoD-Lite / DoD-Full」。

### Step 2：UX/UI 規劃（DESIGN.md）

- **動作**：依 Stitch 規範編寫 / 更新 monorepo 對應的 DESIGN.md，描述畫面結構、互動流程、元件風格。
- **為什麼**：UX/UI 是 PRD 原型的視覺 / 互動來源；沒有規範會讓原型風格漂移。
- **產出**：DESIGN.md（含畫面樹、互動流程、元件庫）。
- **證據**：檔案存在且涵蓋本次所有 Module 的畫面。

### Step 3：系統架構設計（system-design.md）

- **動作**：定義技術棧、系統組成部件（前端 / 後端 / DB / 第三方服務），並依 Module 劃分系統邊界。**禁止**出現真實 / 示範程式碼。
- **為什麼**：架構設計只描述「為什麼這樣切」與「怎麼互動」，實作留給開發階段。
- **產出**：system-design.md（含技術棧、模組邊界圖（純文字）、資料流）。
- **證據**：同步更新 monorepo 對應的 backlog 檔，給每個 User Story 標上 Module 與 Story Point。

### Step 4：模組 PRD（md，含追溯矩陣）

- **動作**：為每個 Module 產出 `docs/prd/<序號-module-name>.md`，含 **FR 清單**、**驗收條件 AC**、**依賴關係**，**強制**附「追溯矩陣」段落（模板見子檔）。
- **為什麼**：追溯矩陣建立「需求 ↔ 設計 ↔ 原型 ↔ 狀態」四向鏈，避免幽靈畫面（設計做但沒對應 US）或幽靈需求（US 有但沒設計）；改 US 時能秒查影響範圍。
- **產出**：`docs/prd/<序號-module>.md`（每 Module 一份）。
- **追溯矩陣**：必含 `FR / US / 畫面 / 原型檔案 / 狀態` 五欄，缺欄視為 PRD 不完整（模板見 prototype-quality.md §4）。
- **證據**：每 Module 都有獨立 md 檔、FR 編號連續無跳號、追溯矩陣每一列都有對應 US。

### Step 4.5：設計自審 + 用戶簽核（必走，不可跳）

- **動作**：Step 5 之前，Agent 跑 5 維度自審（一致性 / 可達性 / 錯誤 / 空狀態 / 效能），產出「自審報告」請用戶簽核。**未簽核不進 Step 5**。
- **為什麼**：原型做完才發現問題，代價是改 3 個檔；現在自審成本 0，效益最高。
- **產出**：對話中的「自審報告」（格式見 prototype-quality.md §3）+ 用戶明確「簽核 / 退回修改」。
- **證據**：對話出現「自審報告：5 維度全綠 / 待修 X」+ 用戶回應「簽核 / 退回」。
- **詳細維度檢查清單**：見 prototype-quality.md §2（5 維度各檢查什麼、不通過時怎麼辦）。

### Step 5：互動 HTML 原型（取代靜態 PRD html）

- **動作**：依 Step 1 選定的 **DoD 深度**（DoD-Lite / DoD-Full），為每個 Module 產出 `docs/prd/<序號-module-name>.html`（**單檔 HTML**，內嵌 CSS + JS）。
- **為什麼**：原型是「可即點即試的 PRD」，讓用戶在瀏覽器直接走完整流程，驗收 UX 後才進開發。
- **產出**：`docs/prd/<序號-module>.html`（單檔、無 build tool、雙擊即開）。
- **DoD 深度對照**：依 Step 1 選定的 DoD 深度（Lite / Full）實作，詳細見 prototype-quality.md §0-§1。
- **證據**：
  - ✅ 必做狀態全實作（依 Step 1 選定的 DoD 深度）
  - ✅ 檔案 < 500 行（避免過度複雜；超量必拆分為多頁）
  - ✅ 內嵌 README 區塊（HTML 開頭 `<section class="prototype-readme">`）說明「點哪裡試什麼」

**原型必含規範**：

| 必含項 | 說明 |
|--------|------|
| **頁面切換** | 多頁 Module 需有 SPA 式切換（hash router 或顯示 / 隱藏） |
| **按鈕點擊** | 所有 CTA 必須有實際反應（切頁、開 modal、顯示 toast） |
| **表單互動** | input / select / checkbox 改變需即時反映 UI |
| **Mock 資料** | 用 JSON 常數或 JS 變數，不用真實 API / 後端 |
| **高保真視覺** | 配色 / 字型 / 間距接近最終產品；避免灰階 wireframe 風格 |

**原型禁止項**：

| 禁止 | 原因 |
|------|------|
| 真實後端 API 呼叫 | 原型階段不應有後端依賴 |
| 假資料寫死「使用者看不到的隱藏欄位」| 容易誤導為「真實功能已實作」 |
| 外部 build tool（webpack / vite / npm 依賴）| 違反「雙擊即開」紀律 |
| 跨檔依賴（多 .css / 多 .js）| 單檔獨立原則；外部 CSS / JS 用 CDN 例外 |

**互動複雜度判斷**：≤ 3 畫面單頁切換 / 4-7 畫面 hash router / > 7 畫面拆多檔。

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

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.2 | 2026-09-26 | +DoD 彈性化（DoD-Lite 預設 / DoD-Full 選用）+ Step 1 一次詢問 | Jevons 反思：避免 DoD 過重變成技術債 |
| v2.1 | 2026-09-26 | +Step 4.5 設計自審 + 用戶簽核 + 5 維度檢查 | 用戶決策：設計驗證環節 |
| v2.1 | 2026-09-26 | +PRD.md 強制追溯矩陣（FR ↔ US ↔ 畫面 ↔ 原型 ↔ 狀態）| 用戶決策：避免幽靈畫面 / 幽靈需求 |
| v2.1 | 2026-09-26 | +原型 DoD 5 種狀態（happy / loading / empty / error / edge）| 用戶決策：原型完成定義嚴謹化 |
| v2.1 | 2026-09-26 | +與 dav-planner 邊界規則（互不寫 US / Backlog）| 用戶提問確認：避免職責衝突 |
| v2.1 | 2026-09-26 | 拆 `prototype-quality.md` 子檔，SKILL.md 控 < 150 行 | 套用 150 行上限 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 + 新增 §5 互動 HTML 原型 | TMO-009 階段 5 + 用戶決策 |
| v1.x | — | （舊版「Backlog 分析 + UX/UI + 架構 + PRD」雙 §3 結構）| 用戶體驗不佳 |

---

**交叉引用（純文字）**：
- 規劃技巧（多輪提問 / INVEST AC / DoD）→ 見同套 dav-planner skill（需同套安裝，§2.1 規劃階段）
- 互動原型品質細節（DoD 5 狀態 / 自審 5 維度 / 矩陣模板）→ 見同 skill 子檔 `prototype-quality.md`
- 完整 SOP §2.1-§2.5 → 見 monorepo 對應的 handbook 目錄（路徑由 monorepo 約定）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）