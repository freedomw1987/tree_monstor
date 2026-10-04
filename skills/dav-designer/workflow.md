---
name: dav-designer-workflow
description: dav-designer 的「6 步流程細節」附件（v2.4 拆分自主檔）。含 Step 1 backlog + Module + DoD、Step 2-5 各步細節、Step 5 互動原型必含 / 禁止二表。
---

# Dav Designer — Workflow（6 步流程細節）

> 本檔為 dav-designer 的流程細節附件，跑 Step 1-5 時逐條查閱。主檔在 `SKILL.md`。
>
> **注意**：互動原型的「品質細節（DoD 5 狀態 / 自審 5 維度 / 矩陣模板）」位於同套 `prototype-quality.md`，本檔只放「流程層」內容（做什麼、為什麼、產出、證據）。

## Step 1：讀取 backlog 並標定範圍 + 詢問 DoD 深度

- **動作**：讀取 monorepo 對應的 backlog 檔，篩選 `status = PENDING` 的項目；依功能內聚性分群為
  Module。**同時詢問用戶每個 Module 的 DoD 深度（DoD-Lite / DoD-Full）**。
- **為什麼**：避免一次處理全部 backlog 導致設計過廣；DoD 深度在 Step 1 一次問清，避免 Step 5 再打斷流程。
- **產出**：Module 清單（含 Module 名稱 / backlog IDs / **DoD 深度**）。

**Module 目的與切割原則**（v2.3 新增）：

Module 是**功能層級的內聚單位**，dav-designer 用它把大項目切成「可獨立交付的小項目」。建立 Module 不是為了分類，是為了達成三個目的：

1. **可按 Module 獨立開發**：每個 Module 可被不同開發者 / 不同時間切片，Module 間只透過明確定義的介面互動。
2. **可按 Module 增減**：新增或移除 Module 時，對項目全體影響最小（其他 Module 不需要重寫，只調整連接處）。
3. **可按 Module 測試**：dev-checker-loop 與 regression-guard 可針對單一 Module 跑探針、跑校驗；測試粒度與 Module 對齊，不會「測了整個系統卻不知道是哪個 Module
   壞掉」。

**切割原則**（依上述目的倒推）：

| 原則 | 說明 | 反例 |
|------|------|------|
| **功能內聚** | 一個 Module 只做一件事或一類緊密相關的事 | ❌ 「用戶 + 訂單 + 支付」塞同一 Module |
| **低耦合** | Module 間互動透過明確介面（API / 事件 / 資料契約），不共用內部狀態 | ❌ Module A 直接讀 Module B 的 DB table |
| **可獨立交付** | 移除某 Module 後，其他 Module 仍能編譯 / 運行（雖可能缺功能）| ❌ 移除「認證」整個系統崩潰 |
| **可獨立測試** | 有 mock 介面就能單獨跑該 Module 的測試，不依賴整個系統起起來 | ❌ 必須啟動完整後端才能測前端 |
| **粒度適中** | 1 個 Module ≈ 3-15 個 User Story；太小（1-2 US）變成分類標籤，太大（20+ US）失去「獨立交付」意義 | ❌ 把整個後端當一個 Module |

**DoD 深度選項**（Step 1 必問一次）：

  | 模式 | 必含狀態 | 適用場景 |
  |------|----------|----------|
  | ⭐ **DoD-Lite（預設）** | Happy path | 玩具 / 內部工具 / 簡單模組 |
  | **DoD-Full** | Happy + Loading + Empty + Error + Edge | 正式產品 / 對外功能 / 複雜模組 |

- **證據**：對話中明確列出「本次處理 Module X（含 backlog #A, #B）— DoD-Lite / DoD-Full」。

## Step 2：UX/UI 規劃（DESIGN.md）

- **動作**：依 Stitch 規範編寫 / 更新 monorepo 對應的 DESIGN.md，描述畫面結構、互動流程、元件風格。
- **為什麼**：UX/UI 是 PRD 原型的視覺 / 互動來源；沒有規範會讓原型風格漂移。
- **產出**：DESIGN.md（含畫面樹、互動流程、元件庫）。
- **證據**：檔案存在且涵蓋本次所有 Module 的畫面。

## Step 3：系統架構設計（system-design.md）

- **動作**：定義技術棧、系統組成部件（前端 / 後端 / DB / 第三方服務），並依 Module 劃分系統邊界。**禁止**出現真實 / 示範程式碼。
- **為什麼**：架構設計只描述「為什麼這樣切」與「怎麼互動」，實作留給開發階段。
- **Module 邊界是測試邊界**（v2.3 新增）：system-design.md 中的 Module 邊界就是未來 dev-checker-loop 與 regression-guard 的執行邊界 — 探針只針對該
  Module 的介面與內部狀態，不會跨 Module 檢查（避免一個 Module 壞掉牽扯其他 Module 的綠燈 / 紅燈）。
- **產出**：system-design.md（含技術棧、模組邊界圖（純文字）、資料流）。
- **證據**：同步更新 monorepo 對應的 backlog 檔，給每個 User Story 標上 Module 與 Story Point。

## Step 4：模組 PRD（md，含追溯矩陣）

- **動作**：為每個 Module 產出 `docs/prd/<序號-module-name>.md`，含 **FR 清單**、**驗收條件 AC**、**依賴關係**，**強制**附「追溯矩陣」段落（模板見子檔）。
- **為什麼**：追溯矩陣建立「需求 ↔ 設計 ↔ 原型 ↔ 狀態」四向鏈，避免幽靈畫面（設計做但沒對應 US）或幽靈需求（US 有但沒設計）；改 US 時能秒查影響範圍。
- **產出**：`docs/prd/<序號-module>.md`（每 Module 一份）。
- **追溯矩陣**：必含 `FR / US / 畫面 / 原型檔案 / 狀態` 五欄，缺欄視為 PRD 不完整（模板見 prototype-quality.md §4）。
- **證據**：每 Module 都有獨立 md 檔、FR 編號連續無跳號、追溯矩陣每一列都有對應 US。

## Step 4.5：設計自審 + 用戶簽核（必走，不可跳）

- **動作**：Step 5 之前，Agent 跑 5 維度自審（一致性 / 可達性 / 錯誤 / 空狀態 / 效能），產出「自審報告」請用戶簽核。**未簽核不進 Step 5**。
- **為什麼**：原型做完才發現問題，代價是改 3 個檔；現在自審成本 0，效益最高。
- **產出**：對話中的「自審報告」（格式見 prototype-quality.md §3）+ 用戶明確「簽核 / 退回修改」。
- **證據**：對話出現「自審報告：5 維度全綠 / 待修 X」+ 用戶回應「簽核 / 退回」。
- **詳細維度檢查清單**：見 prototype-quality.md §2（5 維度各檢查什麼、不通過時怎麼辦）。

## Step 5：互動 HTML 原型（取代靜態 PRD html）

- **動作**：依 Step 1 選定的 **DoD 深度**（DoD-Lite / DoD-Full），為每個 Module 產出 `docs/prd/<序號-module-name>.html`（**單檔 HTML**，內嵌
  CSS + JS）。
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
