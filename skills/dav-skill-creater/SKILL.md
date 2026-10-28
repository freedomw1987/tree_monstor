---
name: dav-skill-creater
description: >-
  從用戶對話或操作中提煉可重複應用的概念，產出新 skill（frontmatter + 「任務導航」4 段結構 + 純文字引用）到 `skills/<name>/SKILL.md`；亦對「修改既有 skill」生效：任何 skill
  檔案修改都要遵守本 skill 規範（4 段結構 + 純文字引用 + 行數上限：主檔 ≤50／子檔 ≤150／context ≤400 + frontmatter 必填）。
---
# Dav Skill Creator

## TL;DR
1. **做什麼**：提煉可重複應用嘅概念 → 產出新 skill（frontmatter + 4 段導航）→ 存進 `skills/<name>/SKILL.md`；**亦係「修改既有 skill」嘅規範權威**（v2.3）。
2. **何時觸發**：用戶話「做 skill」／對話出現可重複應用嘅模式；或**任何** `skills/<name>/SKILL.md` 被改動。
3. **預設 SOP 路徑**：§2.6 一般任務（skill 係輔助元工具，唔使走完整 SOP）。
4. **關鍵紀律**：概念提煉 ≠ 操作記錄；**行數硬門檻**（主檔 ≤50／子檔 ≤150／context ≤400，樣例／模板除外）；唔記變動歷史；表格禁令；純文字引用；frontmatter 必填。
5. **必產出物**：`skills/<name>/SKILL.md`（frontmatter + 4 段結構 + ≤50 行）＋ 必要支援子檔（每支 ≤150 行）。

## 觸發時機
- **用戶說「這是一個 skill」「做 skill」／Agent 偵測到對話具備重複應用潛力／對話出現「下次也這樣做」「之後再遇到」** → ✅ 必須（新建；後兩者先詢問用戶）
- **用戶說「修改 skill」「改一下 SKILL.md」／任何 `skills/<name>/SKILL.md` 被改動／既有 skill 探針 fail** → ✅ 必須（走修改流程 M-Step 1-3 修齊，唔准單純跳過）
- **純提問／唔需重複應用／用戶明說「這不用記」** → ❌ 不觸發

## 流程（新建 5 步）
- **Step 1 提煉概念**：對話／操作 → 概念草稿（工作描述 + 步驟 + 每步目的 + 想要效果）；證據：2-3 句講得出「下次遇到 X，會這樣做」
- **Step 2 與用戶確認**：問 1) 名稱（kebab-case）2) 使用場景描述 3) 必含規則；證據：對話有三項確認
- **Step 3 設計 4 段結構**：TL;DR / 觸發時機 / 流程 / 規則；證據：4 個 `## <段>` 標題齊
- **Step 4 寫入 + 自驗收**：含 frontmatter；過 50 行必拆子檔（內容留子檔、主檔只留指標）；再自查 5 項（frontmatter 齊、4 段齊、主檔 ≤50 行、純文字引用、description
一句話）；證據：5 項全綠 ＋ 主檔 ≤50 行

## 流程（修改既有 skill — v2.3）
- **M-Step 1 讀舊版 + 評估偏差**：列出規範偏差（行號 / 違反邊條 / 建議改法）
- **M-Step 2 套用變更**：同時修正偏差清單所有項（唔准「修 A 留 B」）
- **M-Step 3 自驗收 + 探針驗證**：`bats tests/skill-size.bats` ＋ 該 skill 自帶探針全綠

## 規則 / 例外 / 限制
- **行數硬門檻（v2.11）**：主檔 ≤50 行／子檔 ≤150 行／單 skill context ≤400 行；`example`／`template`／`fixture`／`PoC` 檔除外 —
例外：無；限制：超標必先減法再拆檔，**唔准靠改名喺例外口徑下逃避**
- **frontmatter 必含 `name` + `description`**（一句話：做什麼 + 何時用 + 何時不用）；名稱必 kebab-case — 例外：N/A；限制：唔接受空 frontmatter、唔接受空格／中文名
- **4 段任務導航（v2.9）** — 例外：極簡 skill 可只有 TL;DR + 流程；限制：**唔寫變動歷史段**
- **純文字引用（v2.1/v2.2）** — 例外：skill 子檔之間可用 markdown 連結；限制：不寫跨 dir 連結／跨目錄讀檔引用（跨 skill 只可以寫「見同套 `<skill>` skill」）
- **表格禁令（v2.10）** — 例外：本 skill 嘅格式範本碼 block；限制：skill 內 ＋ **生成嘅 markdown** 一律用列表
- **唔記變動歷史（v2.9）** — 例外：N/A；限制：唔寫變動歷史段、唔准新增 `CHANGELOG.md`
- **修改既有 skill 必走 M-Step 1-3**（v2.3）— 例外：純錯字修正可跳過；限制：改 ≧3 行必走
- **修改同時必清規範偏差、修改後必跑探針**（v2.3）— 例外：用戶明說「只修 A 不動 B」；限制：唔准累積偏差；退探＝修改失敗

## 交叉引用（純文字）
- 完整編寫準則（4 段結構、可讀性原則、反模式、純文字引用、行數限制 v2.11、表格禁令、變動歷史禁令）→ 見同套本 skill 子檔 [`editor-guide.md`](./editor-guide.md)
- 規劃技巧（V01/V02 提問紀律）→ 見同套 dav-planner skill；SOP 完整流程（§2.1-§2.5）→ 見 monorepo 對應的 handbook 目錄
