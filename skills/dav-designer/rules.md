# Dav Designer — 規則 / 例外 / 限制（完整版）

> 本檔為 `dav-designer` 嘅規則子檔；主檔只留每條規則嘅一句摘要 ＋ 指標。

## §1 必產文件 ＋ 自審 ＋ 簽核

- **必產 4 份文件 ＋ 自審報告；PRD.md 必含追溯矩陣（FR／User Story／Surface／畫面路由／Demo 步驟／狀態）**
  - 例外：只更新 X 可增量；既有 PRD 增量更新可補
  - 限制：不可只出 md 不出 demo app；新 PRD 不可缺；細節 → 同套 `./workflow.md`
- **進 Step 5 前必走 Step 4.5 自審 ＋ 用戶簽核**
  - 例外：用戶明確「跳過自審」可省
  - 限制：預設必走；未簽核不進 Step 5；自審 6 維度 → 同套 `./prototype-quality.md` §2

## §2 系統 demo 原型

- **原型單位 = Surface（唔再係 Module）；產出一個 demo app，唔再逐 Module 出孤島 html**
  - 例外：同一 Module 唔重複開 app；CLI 專案用 `cli-terminal` Surface
  - 限制：stack 固定 React + Tailwind + shadcn/ui + HashRouter + zustand；一個 app 內多 Surface 分區；細節 → 同套 `./system-prototype.md`
- **demo app 必交 build 綠 ＋ 單檔 `dist/index.html` ＋ demo 路線行得通 ＋ 至少 1 條跨 Surface 資料流**
  - 例外：預設 DoD-Lite；用戶要求 wireframe 可降階；用戶要求接真實 API
  - 限制：原型階段禁止實際後端；build 後唔准依賴外部 CDN；單檔必須雙擊即開
- **演練 demo app 唔好污染主 repo**
  - 例外：用戶明確要立項（開票做真產品）先落主 repo
  - 限制：只係驗證／示範 → 建喺 `/tmp` 或獨立目錄；唔准為 demo 開 backlog 票、改 PRD／DESIGN／system-design（避免由「驗證 skill」變成「真做產品」）

## §3 架構 ＋ PRD 一致性 ＋ demo app 邊界

- **system-design.md 不可有真實程式碼；PRD md 與 demo app 內容一致**
  - 例外：純文字示意（如 JSON 結構）允許
  - 限制：禁止 import／class／function 範例（design-gate 定義）；FR 編號、AC 條目、追溯矩陣需對齊
- **demo app 係設計期原型：可寫前端 code，但唔寫 production 後端／真實業務邏輯／真實 API**
  - 例外：N/A
  - 限制：production 實作由 `dav-developer` skill 另起；唔准將 mock 標成真實功能

## §4 邊界 ＋ 術語

- **本 skill 不寫 Backlog / US（與 dav-planner 邊界）；術語一致（跟 dav-planner 術語表）**
  - 例外：N/A；專案層冇術語表 → 照常用詞
  - 限制：US／AC 由 dav-planner（規劃階段）產；專案層有 `docs/glossary_list.md` → PRD／demo app 一律用入面嘅術語，唔好用同義詞

## §5 修改流程 ＋ 引用規範

- **修改本 skill 必走 v2.3 修改流程 ＋ 同時清規範偏差；純文字引用（v2.2）**
  - 例外：純錯字修正可跳過；用戶明確「只動 A 不動 B」；skill 子檔可用 markdown 連結
  - 限制：≧ 3 行修改必走 M-Step 1-3；不可累積技術債；不寫跨 dir 路徑引用
