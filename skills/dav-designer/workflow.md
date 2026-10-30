---
name: dav-designer-workflow
description: dav-designer 的「6 步流程細節」附件。含 Step 1 backlog + Module + Surface 映射、Step 2-5 各步細節、demo app 產出要求。
---

# Dav Designer — Workflow（6 步流程細節）

> 本檔為流程細節附件，跑 Step 1-5 時逐條查閱。主檔在 `SKILL.md`。原型品質（狀態／自審）→ 同套 `prototype-quality.md`；系統 demo app 規格 → 同套 `system-prototype.md`。

## Step 1：讀 backlog ＋ 切 Module ＋ 映射 Surface ＋ 問 DoD 深度

- **動作**：讀 monorepo 對應的 backlog 檔，篩 `status = PENDING`；依功能內聚性分群為 Module；**把每 Module 映射到 Surface**；問用戶每個 Surface 嘅 DoD 深度。
- **為什麼**：避免一次處理全部 backlog 令設計過廣；Surface 映射決定 demo app 分區，Step 1 唔問清，Step 5 要返工。
- **產出**：Module 清單（名稱／backlog IDs／DoD 深度）＋ **Surface 清單** ＋ Module→Surface 對應 ＋ **批次清單**。

**Module 切割原則**（目的：可按 Module 獨立開發／增減／測試）：

- **功能內聚** — 一 Module 只做一件事；❌ 反例：「用戶 + 訂單 + 支付」同一 Module
- **低耦合** — 互動經明確介面，不共用內部狀態；❌ 反例：A 直接讀 B 嘅 DB table
- **可獨立交付** — 移除某 Module，其他仍跑得；❌ 反例：移除「認證」全崩
- **可獨立測試** — 有 mock 介面就能單獨測；❌ 反例：要起完整後端先測到前端
- **粒度適中** — 1 Module ≈ 3-15 US；❌ 反例：整個後端當一 Module

**Surface 映射（v2.6 新增）**：

- **Surface = 介面載體**（`web-admin`／`mobile-app`／`tablet-app`／`cli-terminal`），唔等於 Module。
- **同一 Module 可落多個 Surface**（例：「落單」手機有、後台都有）→ 兩邊都要畫，唔准只畫一邊。
- **一個 Surface 可裝多個 Module**（例：後台 = 訂單 + 客戶 + 報表）→ 唔重複開多個 app。
- **Surface 清單格式**：surface 名 ＋ 承載嘅 Module ＋ 外殼（桌面寬版／手機框／終端）＋ 該 Surface 嘅 DoD 深度。
- **CLI 專案**：冇 GUI → 全系統一個 `cli-terminal` Surface，用假終端 view 呈現。
- **DoD 深度選項**（Step 1 必問一次，逐 Surface 問）：⭐ **DoD-Lite**（預設；只 Happy path）／**DoD-Full**（Happy + Loading + Empty + Error + Edge）。
- **證據**：對話列明「2 個 Surface：web-admin（M01, M02）、mobile-app（M03）；web-admin = DoD-Full、mobile-app = DoD-Lite」。

**批次 = 1 Module**：

- **唯一批次單位**：1 批次 = 1 完整 Module；冇 sprint 層、冇 velocity。
- **批次清單**：Module 名／backlog IDs／DoD 深度／先後次序；次序按依賴排，冇依賴按 P0→P3，可平行者標「可平行」。
- **為什麼**：批次 = 交付 = 測試 = 回報邊界，四重合一 → 單 Module 探針、單 Module 交付摘要、單 Module 回顧。
- **INT US 歸屬**：跨 Module 整合測試掛喺後完成嗰個 Module 嘅批次。
- **證據**：對話列明「批次 1 = M01（含 #A, #B）→ 批次 2 = M02」。

## Step 2：UX/UI ＋ 系統 Shell ＋ Design Tokens（DESIGN.md）

- **動作**：寫 DESIGN.md：畫面樹、互動流程、元件庫（揀用邊啲 shadcn/ui 組件）、**design tokens**（色／字／間距／圓角／陰影，寫實數值）、
**每個 Surface 嘅 shell 規格**（桌面 sidebar+topbar／手機 header+bottom tab／終端 prompt+output）、
**畫面地圖**（route → Module → Surface）。
- **為什麼**：tokens ＋ shell 係跨 Surface 視覺一致嘅唯一來源；冇就每個 Surface 各自漂移，demo 唔似一個系統。
- **產出**：DESIGN.md。
- **證據**：tokens 段有具體變數值；每 Surface 有 shell 描述；畫面地圖覆蓋全部 Module。

## Step 3：系統架構設計（system-design.md）

- **動作**：定義技術棧、系統組成部件（前端／後端／DB／第三方服務），劃 **Module 邊界** ＋ **Surface 邊界**（邊個 Surface 用邊套 UI 組件／邊套 API）。**禁止**真實／示範程式碼。
- **為什麼**：架構只描述「點解咁切」同「點互動」，實作留俾開發階段。
- **Module 邊界 = 測試邊界**：探針只針對該 Module 嘅介面與內部狀態，唔跨 Module 檢查（避免一個 Module 壞掉牽扯其他 Module 綠／紅燈）。
- **產出**：system-design.md（技術棧、Module／Surface 邊界圖（純文字）、資料流）。
- **證據**：同步更新 backlog 檔，給每個 US 標 Module 與 Story Point；按實際依賴校正批次次序（Step 1 定、Step 3 校正）。

## Step 4：模組 PRD（md，含追溯矩陣）

- **動作**：每 Module 一份 `docs/prd/<序號-module-name>.md`，含 **FR 清單**、**驗收條件 AC**、**依賴關係**，**強制**附追溯矩陣。
- **為什麼**：追溯矩陣建立「需求 ↔ 設計 ↔ demo app ↔ 狀態」四向鏈，攔幽靈畫面（設計做但無對應 US）同幽靈需求（US 有但無設計）；改 US 時秒查影響範圍。
- **追溯矩陣欄位**：`FR / User Story / Surface / 畫面路由 / Demo 步驟 / 狀態`（缺欄視為 PRD 不完整；模板見同套 `prototype-quality.md` §4）。
- **產出**：`docs/prd/<序號-module>.md`（每 Module 一份）。
- **證據**：每 Module 獨立 md 檔、FR 編號連續無跳號、矩陣每列都有對應 US ＋ Surface ＋ route。

## Step 4.5：設計自審 + 用戶簽核（必走，不可跳）

- **動作**：Step 5 之前跑 6 維度自審（一致性／可達性／錯誤處理／空狀態／效能預感／整合性），產出自審報告請用戶簽核。**未簽核不進 Step 5**。
- **為什麼**：原型做完先發現問題，代價係改幾個檔；自審成本 0，效益最高。
- **產出**：對話中的自審報告 ＋ 用戶明確「簽核 / 退回修改」。
- **證據**：出現「自審報告：6 維度全綠 / 待修 X」+ 用戶回應「簽核 / 退回」。
- **維度清單** → 同套 `prototype-quality.md` §2。

## Step 5：系統 demo 原型 app

- **動作**：按 Step 1 選定嘅 Surface 清單 ＋ DoD 深度，產出 `prototype/<slug>/`
（Vite + React + TS + Tailwind + shadcn/ui + HashRouter + zustand）：每 Surface 一條 route、共用 tokens ＋ 單一 mock store、
內置 demo 路線面板、build 出單檔 `dist/index.html`。
- **為什麼**：原型係「拎得走就 demo 嘅系統」，唔再係逐 Module 孤島；跨 Surface 資料流（手機落單 → 後台見到）係 demo 最強武器。
- **產出**：demo app 專案 ＋ `dist/index.html`（單檔、雙擊即開）。
- **完整規格**（stack／scaffold／目錄／demo 路線／驗收關鍵字）→ 同套 `system-prototype.md`。
- **證據**：`npm run build` 綠；`dist/index.html` 存在且雙擊即開；demo 路線逐步行得通；至少 1 條流程跨 Surface 串連（A Surface 寫入 → B Surface 讀到）。
