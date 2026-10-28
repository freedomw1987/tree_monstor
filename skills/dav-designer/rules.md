# Dav Designer — 規則 / 例外 / 限制（完整版）

> 本檔為 `dav-designer` 嘅規則子檔；主檔只留每條規則嘅一句摘要 ＋ 指標。內容同主檔一致（搬位，零刪）。

## §1 必產文件 ＋ 自審 ＋ 簽核

- **必產 4 份文件 ＋ 自審報告；PRD.md 必含追溯矩陣（FR／US／畫面／原型檔案／狀態）**
  - 例外：只更新 X 可增量；既有 PRD 增量更新可補
  - 限制：不可只出 md 不出原型 html；新 PRD 不可缺；細節 → 同套 `./workflow.md`
- **進 Step 5 前必走 Step 4.5 自審 ＋ 用戶簽核**
  - 例外：用戶明確「跳過自審」可省
  - 限制：預設必走；未簽核不進 Step 5；自審 5 維度 → 同套 `./prototype-quality.md` §2

## §2 互動原型

- **互動原型依 Step 1 DoD 深度執行（Lite 只 Happy path／Full 五狀態）；原型必為單檔、高保真、用 Mock 資料**
  - 例外：預設 DoD-Lite；多畫面 Module 可拆多檔；要 wireframe 可降階；用戶要求接真實 API
  - 限制：DoD-Full 需用戶 Step 1 明確選；單檔 < 500 行；預設 HiFi（MidFi 需用戶指定）；原型階段禁止實際後端

## §3 架構 ＋ PRD 一致性

- **system-design.md 不可有真實程式碼；PRD md 與 html 須內容一致**
  - 例外：純文字示意（如 JSON 結構）允許；原型可加視覺化補充
  - 限制：禁止 import／class／function 範例；FR 編號、AC 條目、追溯矩陣需對齊

## §4 邊界 ＋ 術語

- **本 skill 不寫 Backlog / US（與 dav-planner 邊界）；術語一致（跟 dav-planner 術語表）**
  - 例外：N/A；專案層冇術語表 → 照常用詞
  - 限制：US／AC 由 dav-planner（§2.1）產；專案層有 `docs/glossary_list.md` → PRD／原型一律用入面嘅術語，唔好用同義詞

## §5 修改流程 ＋ 引用規範

- **修改本 skill 必走 v2.3 修改流程 ＋ 同時清規範偏差；純文字引用（v2.2）**
  - 例外：純錯字修正可跳過；用戶明確「只動 A 不動 B」；skill 子檔可用 markdown
  - 限制：≧ 3 行修改必走 M-Step 1-3；不可累積技術債；不寫跨 dir 路徑引用
