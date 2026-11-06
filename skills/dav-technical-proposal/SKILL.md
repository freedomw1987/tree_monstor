---
name: dav-technical-proposal
description: >-
  客戶交付型技術方案書製作。多輪提問釐清技術需求（一次一題、⭐ 推薦放第一）→ 產出 Technical Proposal（Project Background／Technical Solution／Implementation Plan 三大塊）工作版 ＋ 交付版。不用於寫 Backlog（見同套 dav-planner）、寫 SOW（見同套 dav-think-sow）、寫代碼。
---

# Dav Technical Proposal

## TL;DR

1. **做什麼**：多輪提問（核心 9 維度必問 ＋ 觸發式補充維度）→ 成熟度 gate（涵蓋率／清晰度／可行性 3 維度 ≥2）→ 產出技術方案書工作版 ＋ 交付版。
2. **何時觸發**：客戶／投標／售前要技術方案書（Technical Proposal）；已有方案書要補章節。
3. **SOP 路徑**：售前／交付文件段（獨立於規劃 → 設計 → 開發段）。
4. **關鍵紀律**：三大章節骨架必備；條件式章節按規則出現、唔虛構；未確認內容標「待確認」唔自己作；中文內文書面語。
5. **必產出物**：`docs/proposal/<client>-<project>-<year>-technical-proposal.md`（工作版）＋ `…-technical-proposal-delivery.md`（交付版）。

## 觸發時機

- **客戶要技術方案書／投標技術文件／方案書要補章節** → ✅ 必須
- **要拆 Backlog／寫 PRD** → ❌ 見同套 `dav-planner`／`dav-designer` skill
- **要寫 SOW／範圍聲明** → ❌ 見同套 `dav-think-sow` skill
- **要寫代碼／部署** → ❌ 見同套 `dav-developer` skill
- **純提問／純查資料** → ❌ 不觸發

## 流程（Step 1-5）

- **Step 1 定位交付格式與語言**：產出路徑／客戶與項目名／年份／語言（中文書面語）；參考 `reference.md` §1
- **Step 2 多輪提問**：核心 9 維度必問 ＋ 觸發式補充維度；每輪 1 題、2-4 選項、⭐ 推薦放第 1；答案即落對應章節；參考 `reference.md` §2／§3
- **Step 3 成熟度 gate**：涵蓋率／清晰度／可行性 3 維度 ≥2 先寫；任一 = 0 繼續問；參考 `reference.md` §4
- **Step 4 產出方案書**：三大章節逐節寫；條件式章節按 §6 規則出現；骨架參考 `templates/proposal-format.md`
- **Step 5 自查 ＋ 交付**：過 `reference.md` §9 自查清單 → 出工作版 ＋ 交付版 → 提示可銜接同套 `dav-planner`／`dav-think-sow` skill

## 規則 / 例外 / 限制

- **一次只問 1 題（V01）＋方案必標 ⭐ 推薦（V02）** — 例外：確認型問題可一次多個；限制：⭐ 必為第 1 個選項
- **三大章節骨架必備** — 例外：無；限制：缺任何一大塊 → 唔算完成稿
- **條件式章節按規則出現、唔准虛構** — 例外：無；限制：2.5 截圖冇來源 → 列「待補截圖清單」；2.6 遷移唔涉及 → 整節標「不適用」並講原因
- **未確認內容唔自己作** — 例外：無；限制：效能數字／容量／排期／人數／第三方授權 → 標「待確認」，工作版集中成清單
- **中文內文書面語** — 例外：用戶指定語言；限制：繁體書面語、禁口語字眼、專有名詞可保留英文
- **產出兩版（工作版 ＋ 交付版）** — 例外：用戶只想要一份 → 確認型問一次；限制：交付版剔走待確認與內部註記、保留 Assumption
- **技術內容要可驗證** — 例外：無；限制：寫「點解咁揀 ＋ 限制條件」，禁空泛形容詞（高性能／現代化／強化）
- **職能邊界** — 例外：用戶明確要求；限制：唔寫 Backlog／SOW／代碼
- **改規範自查行數上限（V03）** — 例外：無；限制：主檔 ≤50／子檔 ≤150／context ≤400；代碼品質走同套 `dav-developer` skill

## 交叉引用（純文字）

- 核心維度／成熟度／各章節寫法／條件式章節／書面語規範／待確認處理／自查清單 → 同套 `reference.md`
- 方案書 markdown 模板（工作版 ＋ 交付版）→ 同套 `templates/proposal-format.md`
- 實例拆解（通用化示例）→ 同套 `examples/proposal-example.md`
- Backlog／PRD／SOW／代碼 → 見同套 `dav-planner`／`dav-designer`／`dav-think-sow`／`dav-developer` skill
