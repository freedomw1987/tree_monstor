---
name: dav-technical-proposal-diagrams
description: dav-technical-proposal 的「架構圖能力」附件：圖種對應章節、每張圖嘅內容要求、Mermaid 語法防錯規則、圖檔匯出與可讀性量測、互動式架構圖嘅實作限制。
---

# Dav Technical Proposal — 架構圖

> 本檔承載「做架構圖」嘅能力：邊一節要畫邊種圖、點寫先渲染得出、圖檔點交付、互動圖有咩限制。
> 產出位置：**只喺 Technical Solution 章**（架構／操作流程／基礎設施／遷移），唔散落喺背景同實施章節。
> 兩條路線：**基線＝Mermaid 寫入正文**（零依賴、任何環境跑得）；**升級＝互動式架構圖**（見 §5，需另裝外部 skill）。

## §1 圖種對應（**有內容先畫**）

- **2.1 System Technical Architecture** — 系統架構圖（`graph TB` 分層）：分層（前端／後端／整合／基建）、組件關係、對外接口、資料流；資料流可另附 `sequenceDiagram` 時序圖（同一節最多一張）
- **2.2.1 User Surface** — 主要操作流程圖（方向按可讀性定）：每類使用者嘅入口 → 主要操作 → 結果；只畫主路徑，唔畫所有分支
- **2.4 Infrastructure Requirement** — 基礎設施拓撲圖（`graph TB`）：環境邊界、負載平衡／應用／資料區、網絡區段、第三方服務
- **2.6.3 Migration Process** — 遷移流程圖（方向按可讀性定）；需要講清對賬時序先用 `sequenceDiagram`，唔好兩種都畫
- **2.3 Non Functional Requirement** — 可選：容量／流量模型圖；冇量化資料就唔畫
- **流程圖方向（Word／PDF 可讀性）** — 節點 ≤4 用 `graph LR`；節點 ≥5 用 `graph TB`
  - 或用多個 `subgraph`（內設 `direction TB`）分欄，令長鏈變成 2–3 欄
  - 輸出比例唔好超過 3:1，否則喺 A4 直度會變成睇唔清嘅扁條
  - 字級用 `%%{init: {"themeVariables": {"fontSize": "22px"}}}%%` 加大
- **唔畫嘅情況** — 冇資料／資料未確認／只為「睇落完整」→ 唔畫；喺該節寫明「圖待補：需要咩資料先畫得」

## §2 每張圖嘅內容要求（逐項過）

- **有標題** — 圖前一行寫 `- **圖 N — <圖名>**`（用列表項，唔好寫成淨一行粗體），序號跟章節順序（圖 1、圖 2…），交付版引用得到
- **有圖例** — 節點按類型著色（前端／後端／整合／基建／外部），並於圖下用一行講明顏色含義
- **節點名同正文一致** — 圖上嘅模組名、系統名一定要同 2.2.2／2.4 正文用同一個名，唔准圖文兩套名
- **節點標籤＝名稱 ＋ 職責** — 唔好淨寫名；`["交易對賬服務<br/>逐筆對賬與差異標記"]`
- **邊有方向** — 箭頭標資料流方向；可選／非同步路徑用虛線 `-.->`
- **圖唔代替文字** — 圖後保留文字解說段（架構圖後要有「資料流」說明）
- **圖上唔涉密** — 唔寫密碼、連線字串、內網 IP、機房機號、客戶真實識別資料
- **責任邊界要入圖** — 邊個服務商、邊啲喺邊個平台納管，圖例或節點要講明（改咗邊界，圖要同步改）

## §3 Mermaid 語法防錯（渲染炸點，逐條避）

- **括號**：文字含 `(` `)` → 整句用雙引號包住，例 `A["交易服務（核心）"]`；資料庫柱體寫 `pg[("PostgreSQL 15")]`
- **引號**：文字入面唔好用英文雙引號 → 改用「」『』
- **數字加點**：文字唔好寫 `1. 感知`（會被當 list 語法）→ 寫 `1.感知`／`① 感知`／`(1) 感知`
- **subgraph**：一律 `subgraph fe["前端層"]`（ID ＋ 引號顯示名）；引用時用 ID `fe`，唔用顯示名
- **節點 ID**：只用英數字 ＋ 底線；唔用 `end`、`graph`、`class`、`subgraph` 做 ID
- **換行**：節點內換行用 `<br/>`，唔好直接斷行；**唔好用 `<>` 做佔位符**（`<` 會被當 HTML 標籤）
- **箭頭**：`-->` 主流程、`-.->` 可選／非同步、`==>` 主幹強調；邊上標籤寫 `-->|交易資料|`
- **著色**：統一用 `classDef` ＋ `class`／`:::`；文字唔用 emoji；中文標籤避免用半角 `:`（同標籤語法衝突）
- **驗證**：出圖後必須確認渲染 —— 有 Mermaid CLI 就 `mmdc -i x.mmd -o x.svg`；冇就逐項對上面 8 條，並喺交付自查打勾

## §4 圖檔匯出、可讀性同交付（Mermaid 基線）

- **真相係 code block** — 方案書 md 內嵌 ` ```mermaid ` 碼 block（Obsidian／GitHub／VS Code 直接渲染、可 diff、可版本控制）
- **PNG 同 SVG 要同一版面** — 先出 SVG 讀佢嘅 `viewBox` 尺寸，再用同一尺寸出 PNG（`-w W -H H`）；唔同視窗渲染會令 PNG 同 SVG 版面唔一樣（同一張圖兩個版本）
- **`sequenceDiagram` 嘅字級調唔郁版面** — `fontSize`／`actorFontSize` 唔會改變 Mermaid 嘅版面量度；時序圖要清就要收窄節點、訊息文字、間距，唔係加字級
- **可讀性要量** — 實際字級 ≈ `字級 ÷ 畫布寬度 × 頁寬(in) × 72`；直向頁下限 6pt、橫向頁下限 8pt；低過就要收標籤或改版面
- **按長寬比揀頁向** — 闊圖（長寬比 >1.3）放橫向頁，瘦高圖放直向頁；Word 產出時頁向處理見 `delivery.md` §2
- **圖檔位置與命名** — `docs/proposal/assets/<client>-<project>/`，檔名同「圖 N」對應；交付版圖下註明「圖檔：`assets/<client>-<project>/<name>.png`」
- **交稿前驗一致** — 由 Markdown 重新渲染，比對資產（MD5 或 viewBox 比例），確認圖唔係舊版殘留
- **冇 CLI 嘅環境唔阻礙交付** — 保留 code block，並於交付說明提「圖檔需於具 Mermaid CLI 嘅環境匯出」
- **唔准** 用 ASCII 框圖代替（讀唔到、唔可 diff、版本追蹤差）

## §5 互動式架構圖（archify；架構圖類預設加出）

- **定位** — 正文永遠以 Mermaid code block 為準（§4）；互動 HTML 係**加碼**，唔係替代
- **預設做邊啲** — 2.1 系統架構圖、2.4 基礎設施圖 → **預設加出**互動圖；2.2.1／2.6.3 → 用戶要求先做
- **工具** — 外部 skill `archify`（開源、Apache-2.0、v3.2.x）；零依賴 Node CLI；未裝唔影響本 skill 運作
- **圖種對應** — 系統架構、部署拓撲 → `architecture`；操作流程、遷移流程 → `workflow`，講時序先用 `sequence`
- **輸入** — Mermaid 係節點名／分層／連線嘅**唯一真相**：先寫 Mermaid，再照同一組名寫 Archify JSON（要人手改寫成 JSON，唔係自動轉）
- **指令** — `node <archify>/bin/archify.mjs finalize <type> <candidate.json> <output.html> --quality showcase --json`
  - 通過 receipt = 內建 validate ＋ deliver ＋ strict check ＋ browser-check 四道閘（比 §3 手動防錯可靠）
  - 每次重出用新 `--out-dir .archify/<type>-<slug>-<時間戳>/review-<n>`，唔好覆蓋舊證據
- **showcase 有版面上限** — 節點標籤要短（標籤約 ≤22 字、副標題約 ≤40 字），細節放去卡片；標籤太長會觸發 `component-label-overflow`，畫布太闊會觸發 `composition/desktop-readability`（縮標籤令畫布收窄）
- **修法係 edit-in-place** — 收到診斷只改診斷指到嘅節點／連線／文字，唔好推倒重寫候選檔；改完再跑同一條 finalize
- **語言要跟方案書** — `meta.locale` 同候選檔文字用同方案書語言，唔好中文正文配英文互動圖
- **產出** — 獨立 HTML 檔放 `docs/proposal/assets/<client>-<project>/`；交付版於圖下註明檔名，並保留同一張 Mermaid code block
- **客戶要圖片／PDF** — 用 archify 內建匯出，或 `mmdc` 由同一張 Mermaid 匯出；**兩者擇一**，唔好兩套內容
- **未裝時** — 唔阻礙交付：維持 Mermaid 基線，並於交付說明提「可另裝 `archify` skill 升級為互動架構圖（開源、Apache-2.0）」
- **安裝（pi 讀 `~/.agents/skills/`）**
  - `npx -y skills@latest add https://archify.si --skill archify --agent claude-code --global --copy --yes`
  - 再複製 `~/.claude/skills/archify` 去 `~/.agents/skills/archify`
  - 或直接取 GitHub 嘅 `archify/` 資料夾落 `~/.agents/skills/archify`
  - 驗證：`node ~/.agents/skills/archify/bin/archify.mjs doctor`
- **邊界** — 互動 HTML 唔取代正文；節點名、分層、連線必須同 Mermaid 一致，唔一致以正文為準並重出互動圖；互動圖唔帶未確認數字

## §6 圖相關自查（併入交付前自查清單）

- 每張圖都有「圖 N — 名稱」標題，序號連續、無重複
- 圖種同章節對：2.1 架構圖／2.2.1 流程圖／2.4 部署圖／2.6.3 遷移流程圖
- 節點名同正文一致；每個節點有職責；圖後有文字解說；責任邊界同正文一致
- §3 語法防錯 8 條逐項過；已用 Mermaid CLI 渲染驗證（若環境有）
- 圖內文字量測過可讀性（直向 ≥6pt、橫向 ≥8pt）；PNG 同 SVG 版面一致
- 圖上無秘密資料；圖內無未確認數字（未確認就唔畫，唔喺圖上標待確認）
- 交付版圖檔路徑存在（若已匯出）
- 有互動圖時：Mermaid 與互動圖內容一致；互動圖語言同正文一致；交付版兩者都有指向
