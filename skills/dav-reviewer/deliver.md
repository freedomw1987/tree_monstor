# Dav Reviewer — 交付流程（Step 4–5）

> 本檔為 `dav-reviewer` skill 嘅「交付摘要 ＋ 更新文檔／backlog」流程子檔；主檔只留指標。
> 審核流程（Gate 4）→ 同套 `./review.md`；需求對帳（Gate 4.5）→ 同套 `./workflow.md`；兩道 Gate 定義 → 同套 `./gates.md`。

## §1 Step 4：寫交付摘要（兩層產出物）

- **先確認交付範圍** — 對應 Backlog item（US／DE／TECH／SPIKE ID）、Sprint／Module、收集變更清單（檔案、測試、文檔）；
  對話明示「Backlog = X、Module = Y」（交付單位 4 級 → 見同套 `./templates/module-delivery.md`）
- **對話摘要** — 90 秒內可讀，讲「做了什麼／**為什麼**／下一步」；「為什麼」獨立一段、唔混喺「做了什麼」；含 emoji 標記；限制：不超過 200 行對話
- **Markdown 詳錄** — 套用同 skill 子檔 `./templates/deliverable-template.md`（含 `## 1.2 為什麼做這個改動`、
  `## 2.4 改動背後的理由`、`## 8. 反思`、`## 3.1 需求對帳` 段）→ 寫入 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`
  （日期 ISO、slug kebab-case）→ 詳錄係 audit trail（反思 ＋ 判斷理由）
- **v2.1 必含「為什麼」三問** — 「為什麼做這個改動／為什麼這個設計／為什麼放棄其他選項」；例外：緊急修復可簡為一句話；
  限制：對話摘要 ＋ Markdown §1.2 ＋ §2.4 都必含

### 1.1 反省（Step 3.5，併入交付摘要末段）

- **觸發時機（三層級）**：**US 級** — 每個 US 完成驗收後輕量反省（Agent 自動執行）；
  **Sprint 級** — 每個 Sprint 結束後標準反省（Agent ＋ 用戶共同檢視）；**Module 級** — 每個功能模組交付後深度反省（Agent ＋ 用戶共同檢視）
  （trust mode 進行中：Agent 自動完成 ＋ 待決事項寫 need-you-help 檔，視為通過）
- **判斷層級**（US／Sprint／Module）→ 逐項檢查 **6 維度**（UX/UI 一致性／RWD／技術債／可維護性／測試覆蓋率／需求對齊）
- **每個 ❌ 必含「根因 ＋ 建議」** → 產出 Action Items（動作 ＋ 類型 ＋ 驗收條件 ＋ 預估）
- **US 級只檢查關鍵 2 維度**（需求對齊 ＋ 測試覆蓋率）；**Sprint／Module 級做全 6 維度**
- 清單 → 同 skill 子檔 `./templates/reflection-checklist.md`；三級別模板 → `./templates/reflection-templates.md`

### 1.2 誠實標註 ＋ 下一步

- **已知問題**（第 5 節）誠實填寫（含 pre-existing）— 限制：不可「假完成」
- **下一步建議**（第 6 節）必含 **3 項**（驗收方式／預估時間／風險提示）— 例外：緊急修復可精簡；限制：不可只寫「待續」

### 1.3 需求對帳段（§3.1）

- 取 Gate 4.5 嘅對帳表填入 §3.1（需求 ID／狀態／實作位置／證據／覆蓋率）
- 對帳有「部分實作／未實作」、缺對帳段、R-ID 未覆蓋、降級未標註 → 交付狀態**不得**標「✅ 完成」
  → 只能「⚠️ 部分完成」＋ 待補清單
- **未觸發審核**（用戶冇叫 review）→ §3.1 段仍然必填（寫明「未做需求對帳（Gate 4.5 未觸發）」）＋ 狀態不得標「✅ 完成」（D8 硬閘）

### 1.4 fail-fast Reflection Gate — 反省 ＋ backlog 更新（必須通過先算交付完成）

- **通過條件**：
  1. **反思併進 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md` 末段**「## 反思」（唔再獨立成檔）
  2. 每個 ❌ 都有「**根因 ＋ 建議**」（可執行性）
  3. 每個 Action Item 都填滿「**動作 ＋ 類型 ＋ 驗收條件 ＋ 預估**」
  4. **更新 `docs/backlog.md`** —— 問題清單轉化為：技術債問題 → Technical Debt（TECH）｜Bug → Defects（DE）｜缺失功能 → User Story（US）｜需研究 → Spike
  5. **用戶參與確認**（Sprint／Module 級必參與；US 級可 Agent 自動；**trust mode 進行中：由 Agent 自動完成 ＋ 待決事項寫 need-you-help 檔，視為通過**）
- **「假裝通過」視為失敗**（見同套 `dav-router` skill 嘅違規回報規則）：
  - ❌ 交付 deliverable 但沒反思末段
  - ❌ 更新 `docs/backlog.md` 但 deliverable 沒對應嘅 Action Items
  - ❌ Action Items 缺「驗收條件」或「預估」
  - ❌ 問題清單嘅 ❌ 沒「根因 ＋ 建議」
  - ❌ Sprint／Module 級別沒用戶參與確認（trust mode 進行中除外）

### 1.5 提交前 Self-Check 清單（V19 — Agent 必逐項 ✅）

- [ ] 對話摘要 ≤ 90 秒可讀完
- [ ] Markdown 含「**Backlog ID**」欄位（US／DE／TECH／Spike 每個提交都要對應）
- [ ] Markdown 含「**變更清單**」具體到檔案
- [ ] Markdown 含「**測試 / 驗收證據**」（Gate 1／2／3 必有 output；Gate 4 如本次觸發咗審核先有，未觸發 → 標明「未做審核」）
- [ ] Markdown 含「**已知問題**」區塊（誠實標註，不可假完成）
- [ ] Markdown 含「**下一步建議**」區塊（驗收方式／預估時間／風險提示 — V20）
- [ ] 反思（Reflection）併進 Markdown 末段「## 反思」
- [ ] 對應 `docs/backlog.md` 已更新
- [ ] **本次受影響嘅專案文檔已更新**（只改真係受影響嘅；冇 → 標明「本次無受影響文檔」）
- [ ] 本次 US 有需求錨點時：已含「3.1 需求對帳」段，且**交付狀態與對帳結果一致**（有 ⚠️／❌ → 不得標「✅ 完成」）

> 未通過 self-check = 不可提交，必須補完。
> Sprint／Module 級別嘅總結交由 §1.1 反省處理，唔好重複。

## §2 Step 5：更新受影響文檔 ＋ `docs/backlog.md`

> **為什麼要呢一步**：交付摘要如果只講「做了什麼」而唔同步文檔 → 文件同實作就會漂移（repo 最怕嘅一類問題）
> → 交付時一併把受影響嘅文件拉返同實作一致。

- **更新受影響嘅專案文檔** — 只改**真係受本次改動影響**嘅文件（README／`docs/system-design.md`／
  `docs/glossary_list.md`／skill 規格／SOP 規則（各 skill 內嘅規則本體）…）→ 例外：冇受影響文檔 → 對話講明；限制：唔准「文件同實作唔一致」
- **更新 `docs/backlog.md`** — 更新本次 US 嘅狀態；**完成（done）嘅 row 要移出**
  （記錄去交付摘要 ＋ 需求錨點 ＋ git history）；backlog 只剩未完成（todo／doing／⏸️）row
  → 規則見同套 `dav-planner` skill 嘅 backlog 規則 §4.5
- **記錄更新咗乜** — 交付摘要 §8 加一段「本次更新咗邊啲文件（路徑 ＋ 點解）」→ 對話亦要提
- **保留 vs 歸檔策略**（交付摘要只留最近一次、ac／req／reconcile 歸檔）→ 見下面 §4

## §3 交付規則（例外／限制）

- **兩層交付物（對話 ＋ Markdown，v2.0 起不寫 HTML）＋ Markdown 必含 8 段（含反思末段）** — 例外：小任務可精簡次要段；限制：§1／§2／§3／§5／§6／§8 不可少
- **反思併進 `## 反思` 段（v2.0）** — 例外：v1.7.1／v1.8／v1.9 獨立反思檔保留；限制：未來不寫獨立反思檔
- **V01 對話一次只談一個任務；V02 下一步建議必標推薦** — 例外：N/A；限制：不可同時交收多個任務
- **Module 級交付可觸發（v2.2）** — 例外：預設 US 級交付；限制：Module 級需在對話明示「Module 級交付」；細節 → 同套 `./templates/module-delivery.md`
- **術語一致（跟專案層術語表）** — 例外：專案層冇術語表 → 照常用詞；限制：專案層有 `docs/glossary_list.md` → 交付摘要同對話一律用入面嘅術語
- **交付摘要只留最近一次**（見 §4）— 例外：`⏸️` 暫停要留；引用鏈要留低；限制：移出前先 commit

## §4 保留 vs 歸檔策略

> 引用：主檔 `SKILL.md` Step 4（寫交付摘要）＋ Step 5（更新 Backlog）＋ 規則表。
> **做法**：完成嘅記錄靠 git history（可追溯），文件樹只留「仲有用」嘅；⚠️ **刪之前先 commit**。

### 4.1 交付摘要：只留最近一次

- **位置**：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`；**保留**：只留最近一次，舊嘅刪（靠 git history）
- **例外（要留低）**：嗰次交付嘅引用鏈 → `docs/req/<US>-requirement.md` ＋ `docs/reconcile/<US>-reconcile.md`
- **點解要留引用鏈**：文件漂移檢查嘅 **D8 硬門檻**（窗內要有交付摘要可對帳）靠佢；唔留 → 檢查件數為 0 → fail-closed 紅

### 4.2 Backlog：只留未完成

- `docs/backlog.md` 只留 **未完成**（`todo`／`doing`／`⏸️`）嘅 row；**完成（done）嘅 row 要移出**（記錄去交付摘要 ＋ 需求錨點 ＋ git history）
- 每次更新 backlog 都要順手檢查：有冇已完成 row 殘留 → 有就移出；規格細節 → 見同套 `dav-planner` skill

### 4.3 `docs/` 保留 vs 歸檔（全局判斷）

- **保留**（仲有用／現行規範）：`docs/ci/`（CI SOP ＋ 漂移白名單）、**各 skill 內嘅 SOP 規則本體**（規劃／設計／執行／反省 ＋ 提交）、
  `docs/cleanup/`（減磅工具）、`docs/glossary_list.md`（術語表）、`docs/DESIGN.md`、`docs/system-design.md`（設計／架構依據）、
  `docs/install-reference.md`、`docs/need-you-help.md`、`docs/trust-log.md`（活躍檔）、`docs/ac/README.md`（AC 範本）
  ＋ **未完成 US 嘅** ac／req／reconcile、**最近一次交付摘要 ＋ 佢嘅引用鏈**
- **歸檔**（靠 git history，刪之前先 commit）：已完成 US 嘅 `docs/ac/<US>.md`、`.html`、對應 `docs/req/`、`docs/reconcile/`；
  已交付專案嘅 `docs/prd/<...>.md`；除最近一次外嘅 `docs/deliverable/*.md`
- **點解**：文件樹愈積愈大 → agent 每次都要重讀已完嘅嘢，浪費時間同 token；而 git history 已經完整保留咗「當時做咗乜」

### 4.4 執行次序（每次交收）

1. 寫新交付摘要（`docs/deliverable/<date>-<slug>.md`）
2. **先 commit**（內容入 git history）
3. 刪舊交付摘要（保留新嗰次 ＋ 佢嘅引用鏈）
4. 歸檔已完成 US 嘅 ac／req／reconcile（保留未完成嘅）
5. 更新 `docs/backlog.md`：移出完成 row、留低未完成 row
6. 跑本專案嘅檢查（文件漂移檢查會驗 D1／D6／D7／D8 一致 → 有漏就會紅）

> **Module 級交付差異 ＋ 第 9 段模板** → 同套 `./templates/module-delivery.md`（進階場景，唔係每次交收都要讀）。
