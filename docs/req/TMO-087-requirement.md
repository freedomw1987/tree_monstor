# TMO-087 需求錨點

> US: TMO-087 | 建立: 2026-10-27 | 來源: 用戶指示（dav-planner 產出專案術語表）

## 用戶原話（唯讀）

- R1: 「我想繼續優化dav-planner skill, 我收集完用戶需求時，您可以整理到一份項目的glossary_list.md，
  裡面會有以下的東西： Key Characteristics of a Glossary
  • Alphabetical Order: Terms are always arranged in strict A-to-Z order to make lookup fast and
  intuitive.
  • Domain-Specific: Unlike a general dictionary, a glossary focuses narrowly on a single subject,
  industry, project, textbook, or thesis.
  • Concise Explanations: Entries typically provide brief, direct definitions rather than full
  etymologies or extensive usage examples.
  • Placement: They usually appear at the very end of a book, report, or manual, or on a dedicated
  page of a website.」
- R2: 「目的是為了之後項目其他階段都可以使得參與用戶和LLM 都可以有一致的語言，避免了認知的差異，
  也可以減低大模型重新理解」

## 澄清後驗收句

- R1: `dav-planner` 收集完用戶需求後，要產出一份**專案層**術語表 `docs/glossary_list.md`，
  並且寫齊用戶列嘅 4 個特性：**A-Z 排序**、**領域／專案專屬**（唔收通用詞）、
  **簡潔定義**（一句）、**位置**（專用頁 —— 唔塞入 SKILL.md，避免每個 skill 觸發都帶成本）。
- R2: 術語表嘅目的係「跨階段一致用語」→ **之後每個階段（設計 / 執行 / 驗收 / 交付）都要讀同一份**，
  唔准各自發明叫法；並要有**維護規則**（新術語點加入、點樣保持 A-Z）。

## 背景（非用戶原話；係實作時嘅實測）

| 事實 | 來源 |
|---|---|
| 專案層 `docs/` 已有 backlog.md / DESIGN.md / system-design.md / req/ / ac/ / prd/ 等產物，但**冇術語表** | 讀 `docs/` |
| 各 skill 早已用「寫到 docs/」嘅方式提專案層檔案（`docs/backlog.md`、`docs/system-design.md`）→ 術語表沿用同一層級即可 | 讀 dav-designer / dev-checker-loop / dav-submitter |
| 上下文成本是硬約束（本 repo 2026-10-27 先做完一輪 context 瘦身）→ 術語表必須**細 + 一句一條**，唔可以變成第二本手冊 | `docs/ci/`（TMO-082/083 記錄）|

## 執行約束（repo 既有規則，唔屬驗收句）

- 修改 skill → 依 `dav-skill-creater` v2.3 修改流程（M-Step 1-3）
- 改 skill 屬規範改動 → 依 `AGENTS.md` §1.5 **V03 走獨立 Reviewer 二審**
- 文檔行數限制（v2.8）：主檔 ≤150／子檔 ≤300／context ≤700
- 純文字引用（v2.2）：提專案層路徑要同其他 skill 現有寫法一致（寫法：`docs/xxx.md` 純文字）

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶指示逐字整理成錨點（含用戶列出嘅 4 個 glossary 特性）|
