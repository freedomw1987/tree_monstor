---
name: dav-think-sow
description: >-
  在售前／交付階段使用。透過多輪提問釐清項目範圍，產出 SOW Details 內容（產品功能描述、服務工作項、Assumption），中文內文一律用書面語。不用於寫 Backlog／PRD、代碼、純提問。
---

# Dav Think SOW

## TL;DR

1. **做什麼**：多輪提問 6 核心維度 → 成熟度 gate → 產出 SOW Details 內容（Item 編號 ＋ Item 名 ＋ Description ＋ Assumption ＋ Out of scope）。
2. **何時觸發**：寫 SOW／範圍聲明；報價要掛 `<Ref. to SOW Detail - Item N>`；補寫假設或數量上限。
3. **SOP 路徑**：售前／交付文件段（獨立於規劃 → 設計 → 開發 → 交付段）。
4. **關鍵紀律**：V01 一次一題、V02 推薦放第一、Item 編號同報價雙向對齊、數量上限必寫、金額唔碰、SOW 內文用書面語、自家產品拆授權／部署調試。
5. **必產出物**：`docs/sow/<client>-<project>-<year>-sow.md`（工作版）＋ `-delivery.md`（交付版）＋ **同名 `.xlsx`（必出）**。

## 觸發時機

- **要寫 SOW／SOW Details／範圍聲明**；**報價要掛 `<Ref. to SOW Detail - Item N>`** → ✅ 必須
- **已有 SOW 要補 Assumption／數量上限／Item 編號** → ✅ 必須
- **要拆 Backlog／寫 PRD** → ❌ 見同套 `dav-planner`／`dav-designer` skill
- **要寫代碼／部署／純提問／純查資料** → ❌ 不觸發（代碼見同套 `dav-developer` skill）

## 流程（Step 1-5）

- **Step 1 定位交付格式與語言**：語言（跟目標客戶／報價文件；中文用書面語）＋ 產出路徑；**Excel 預設必出**（除非用戶明確只要 md）；參考 `reference.md` §6／§7／§8
- **Step 2 多輪提問**：6 核心維度必問 ＋ 觸發咗嘅補充維度；每輪 1 題、2-4 選項、⭐ 推薦放第 1；答案即落點；參考 `reference.md` §1／§2
- **Step 3 成熟度 gate**：涵蓋率／清晰度／可行性 3 維度 ≥2 先寫；任一 = 0 繼續問；參考 `reference.md` §3
- **Step 4 生成 SOW 內容**：按 Item 類型寫（做咩 ＋ 包含咩 ＋ 數量上限）；自家產品拆授權／部署調試兩個 Item；模組型用 A./B./C./D. 分塊寫入 Description；參考 `templates/sow-format.md`
- **Step 5 自查 ＋ 交付**：過 `reference.md` §9 自查清單 → 出工作版 ＋ 交付版 ＋ **Excel `.xlsx`（§6）**；三份一齊交付

## 規則 / 例外 / 限制

- **一次只問 1 題（V01）＋方案必標 ⭐ 推薦（V02）** — 例外：確認型可一次多個；限制：V02 必為第 1 個選項
- **6 核心維度必問** — 例外：用戶已提供完整範圍文件；限制：缺 1 個 → 涵蓋率 ≤1
- **每 Item 必含「做咩 ＋ 包含咩」；服務 Item 必含量上限；自家產品必拆授權＋部署調試** — 例外：無；限制：寫唔出上限 → 標「待確認」，唔准自己作；自家產品混寫同一 Item → 交付前必拆
- **Assumption 三類必寫 ＋ 通用排除條款**（環境／計算基準／商業假設／未列明事項）— 例外：純產品功能型可簡化；限制：唔准只寫「客戶提供環境」；必附未列明服務排除條款（§5）
- **語言跟目標客戶／報價文件；SOW 中文內文一律書面語** — 例外：用戶指定語言；限制：唔准口語字眼（對照 `reference.md` §8 清單）、唔准中英無規則夾雜
- **Excel 預設必出，跟用戶 Excel template；Item 編號同報價雙向對齊** — 例外：用戶明確只要 md（對話註明）；
  限制：三 sheet（`Quotation`／`SOW Details`／`SOW Details CN`）、`SOW Details*` 只有 `#`／`Item`／`Description`／`Mandays`、
  兩邊皆**刪 `Module` 欄**、`Mandays` 留空、`Quotation` 用 `<Ref. to SOW Detail - Item N>`；編號／欄位唔一致 → 先問用戶
- **金額與定價唔由本 skill 決定** — 例外：用戶明確要求；限制：只寫工作量（mandays）同數量上限
- **改規範自查行數上限（V03）** — 例外：無；限制：主檔 ≤50／子檔 ≤150／context ≤400；代碼品質走同套 `dav-developer` skill

## 交叉引用（純文字）

- 6 維度／補充維度／成熟度／Item 類型寫法／Assumption／書面語規範／Excel 寫入／自查清單 → 同套 `reference.md`
- SOW markdown 模板 → 同套 `templates/sow-format.md`；實例拆解 → 同套 `examples/sow-details-example.md`
- Backlog／PRD／代碼 → 見同套 `dav-planner`／`dav-designer`／`dav-developer` skill
