---
name: dav-technical-proposal
description: >-
  客戶交付型技術方案書製作。多輪提問釐清技術需求 → 產出 Technical Proposal（Project Background／Technical Solution／Implementation Plan 三大塊）工作版 ＋ 交付版，含架構圖（Mermaid 為正文基線，架構圖類另加 archify 互動圖），可按投標文件插章節、可另出 Word／PDF。成品自足（唔用引用叫客戶睇其他文件）＋ 術語表。不用於寫 Backlog（見同套 dav-planner）、寫 SOW（見同套 dav-think-sow）、寫代碼。
---

# Dav Technical Proposal

## TL;DR

1. **做什麼**：多輪提問（核心 9 維度必問 ＋ 觸發式補充）→ 成熟度 gate（涵蓋率／清晰度／可行性 3 維度 ≥2）→ 產出技術方案書工作版 ＋ 交付版（含架構圖；用戶要時出 Word／PDF）。
2. **何時觸發**：客戶／投標／售前要技術方案書；方案書要補章節或改版；要架構圖；要交 Word／PDF。
3. **SOP 路徑**：售前／交付文件段（獨立於規劃 → 設計 → 開發段）。
4. **關鍵紀律**：三大章節骨架必備、可插章節；未確認內容標「待確認」唔自己作；架構圖用 Mermaid ＋ archify 互動圖；成品自足、縮寫入術語表；交付版淨稿；Markdown 為 source of truth。
5. **必產出物**：`docs/proposal/<client>-<project>-<year>-technical-proposal.md`（工作版 ＋ 交付版 ＋ 圖檔；用戶要時加 `.docx`）。

## 觸發時機

- **客戶要技術方案書／投標技術文件／方案書要補章節或改版／要架構圖／要 Word 交付** → ✅ 必須
- **要拆 Backlog／寫 PRD／寫 SOW／寫代碼** → ❌ 見同套 `dav-planner`／`dav-designer`／`dav-think-sow`／`dav-developer` skill
- **純提問／純查資料** → ❌ 不觸發

## 流程（Step 1-6）

- **Step 1 定位交付格式與語言**：產出路徑／客戶與項目名／年份／語言；投標文件要帶入嘅章節 → `reference.md` §1
- **Step 2 多輪提問**：核心 9 維度必問 ＋ 觸發式補充維度；每輪 1 題、2-4 選項、⭐ 推薦放第 1；答案即落對應章節 → `reference.md` §2／§3
- **Step 3 成熟度 gate**：涵蓋率／清晰度／可行性 3 維度 ≥2 先寫；任一 = 0 繼續問 → `reference.md` §4
- **Step 4 產出方案書**：三大章節逐節寫（可插章節 → `reference.md` §5）；Technical Solution 章按圖種規則繪圖 → `diagrams.md`
- **Step 5 淨稿**：交付版刪待確認／內部註記／金額／外部依賴 → `delivery.md` §1
- **Step 6 自查＋出檔**：過 `reference.md` §9 ＋ `delivery.md` §4 自查 → 出 Markdown ＋ 圖檔（＋ Word／PDF → `delivery.md` §2）

## 規則 / 例外 / 限制

- **一次只問 1 題（V01）＋方案必標 ⭐ 推薦（V02）** — 例外：確認型問題可一次多個；限制：⭐ 必為第 1 個選項
- **三大章節骨架必備；可按投標文件插章節、條件式章節按規則出現、唔准虛構** — 例外：無；限制：缺任何一大塊 → 唔算完成稿；截圖冇來源 → 列「待補截圖清單」；遷移唔涉及 → 整節標「不適用」並講原因
- **架構圖只畫喺 Technical Solution 章、用 Mermaid 寫入正文；架構圖類預設加出 archify 互動圖（唔取代正文）**
  - 例外：流程圖／遷移圖、指定其他圖種、或未裝 archify → 只交 Mermaid；限制：與 Mermaid 節點名／分層一致 → `diagrams.md`
- **未確認內容唔自己作** — 例外：無；限制：效能數字／容量／排期／人數／授權 → 標「待確認」，工作版集中成清單
- **成品要自足，唔准用引用叫客戶去睇其他文件** — 例外：用戶明確要求摘要版；限制：範圍、流程、參數、限制、角色、數據流全部寫喺正文
- **縮寫入術語表（首次出現寫全稱、正文用過先留）；可比較嘅資料用表格** — 例外：無；限制：術語表覆蓋技術縮寫同工具／模型名；欄標題自我解釋、欄數 ≤6 → `reference.md` §5
- **語言跟客戶／報價文件；中文內文書面語** — 例外：用戶指定；限制：禁口語字眼、禁空泛形容詞
- **產出兩版（工作版 ＋ 交付版）** — 例外：用戶只想要一份 → 確認型問一次；限制：交付版剔走待確認與內部註記
- **Markdown 係 source of truth；Word／PDF 由 Markdown 產出，改稿要重出** — 例外：用戶只交一份 → 問一次；限制：唔准手改 docx 造成兩版唔一致
- **改規範自查行數上限（V03）** — 例外：無；限制：主檔 ≤50／子檔 ≤150／context ≤400；代碼品質走同套 `dav-developer` skill

## 交叉引用（純文字）

- 核心維度／成熟度／章節寫法與骨架擴充／條件式章節／自足性與術語表／書面語規範／內容自查 → 同套 `reference.md`
- 圖種對應／內容要求／Mermaid 防錯／匯出與可讀性量測／互動圖限制 → 同套 `diagrams.md`；交付版淨稿／Word 產出管線／改版同步清單／交付自查 → 同套 `delivery.md`
- 方案書 markdown 模板與實例拆解 → 同套 `templates/proposal-format.md`、`examples/proposal-example.md`
