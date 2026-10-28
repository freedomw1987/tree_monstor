# Dav Reviewer — 交付流程（Step 4–5）

> 本檔為 `dav-reviewer` skill 嘅「交付摘要 ＋ 更新文檔／backlog」流程子檔；主檔只留指標。
> 審核流程（Gate 4）→ 同套 `./review.md`；需求對帳（Gate 4.5）→ 同套 `./workflow.md`；兩道 Gate 定義 → 同套 `./gates.md`。

## §1 Step 4：寫交付摘要（兩層產出物）

- **先確認交付範圍** — 對應 Backlog item（US／DE／TECH／SPIKE ID）、Sprint／Module、收集變更清單（檔案、測試、文檔）；
  對話明示「Backlog = X、Module = Y」（交付單位 4 級 → 見 §5.1）
- **對話摘要** — 90 秒內可讀，讲「做了什麼／**為什麼**／下一步」；「為什麼」獨立一段、唔混喺「做了什麼」；含 emoji 標記；限制：不超過 200 行對話
- **Markdown 詳錄** — 套用同 skill 子檔 `./templates/deliverable-template.md`（含 `## 1.2 為什麼做這個改動`、
  `## 2.4 改動背後的理由`、`## 8. 反思`、`## 3.1 需求對帳` 段）→ 寫入 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`
  （日期 ISO、slug kebab-case）→ 詳錄係 audit trail（反思 ＋ 判斷理由）
- **v2.1 必含「為什麼」三問** — 「為什麼做這個改動／為什麼這個設計／為什麼放棄其他選項」；例外：緊急修復可簡為一句話；
  限制：對話摘要 ＋ Markdown §1.2 ＋ §2.4 都必含

### 1.1 反省（Step 3.5，併入交付摘要末段）

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

## §2 Step 5：更新受影響文檔 ＋ `docs/backlog.md`

> **為什麼要呢一步**：交付摘要如果只講「做了什麼」而唔同步文檔 → 文件同實作就會漂移（repo 最怕嘅一類問題）
> → 交付時一併把受影響嘅文件拉返同實作一致。

- **更新受影響嘅專案文檔** — 只改**真係受本次改動影響**嘅文件（README／`docs/system-design.md`／
  `docs/glossary_list.md`／skill 規格／SOP handbook…）→ 例外：冇受影響文檔 → 對話講明；限制：唔准「文件同實作唔一致」
- **更新 `docs/backlog.md`** — 更新本次 US 嘅狀態；**完成（done）嘅 row 要移出**
  （記錄去交付摘要 ＋ 需求錨點 ＋ git history）；backlog 只剩未完成（todo／doing／⏸️）row
  → 規則見同套 `dav-planner` skill 嘅 backlog 規則 §4.5
- **記錄更新咗乜** — 交付摘要 §8 加一段「本次更新咗邊啲文件（路徑 ＋ 點解）」→ 對話亦要提
- **保留 vs 歸檔策略**（交付摘要只留最近一次、ac／req／reconcile 歸檔）→ 見下面 §4

## §3 交付規則（例外／限制）

- **兩層交付物（對話 ＋ Markdown，v2.0 起不寫 HTML）＋ Markdown 必含 8 段（含反思末段）** — 例外：小任務可精簡次要段；限制：§1／§2／§3／§5／§6／§8 不可少
- **反思併進 `## 反思` 段（v2.0）** — 例外：v1.7.1／v1.8／v1.9 獨立反思檔保留；限制：未來不寫獨立反思檔
- **V01 對話一次只談一個任務；V02 下一步建議必標推薦** — 例外：N/A；限制：不可同時交收多個任務
- **Module 級交付可觸發（v2.2）** — 例外：預設 US 級交付；限制：Module 級需在對話明示「Module 級交付」；細節 → 見下面 §5
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

- **保留**（仲有用／現行規範）：`docs/sop/`（handbook ＋ gates.json 機器可讀副本）、`docs/ci/`（CI SOP ＋ 漂移白名單）、
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

## §5 Module 級交付差異

> 引用：主檔 `SKILL.md` 規則「Module 級交付可觸發（v2.2）」；理由：差異多（Backlog ID 格式／探針綁定／§9 總結）→ 屬「進階場景」。

### 5.1 適用情境 ＋ 交付單位

- **交付單位 4 級**：單個 US（1 個 AC 套件）｜單個 Module（Module 內所有 US 集合）｜多個 Module（＋ cross-module integration）｜
  整個 repo / sprint 結束（整個交付歷史）—— 後三級用 Step 3.5 微總結
- **觸發情境**：整個 Module 完成（內所有 US 驗收完 ＋ Module 級整合測試通過）／Module 級里程碑（未全部交付但達可發佈狀態）／Module 重構完成（技術債清理 ＋ 探針重寫）

### 5.2 四個差異

- **1. Backlog ID 格式** — US 級：`US-101`／`DE-201`／`TECH-03`／`SPIKE-04`；Module 級：`<MODULE_CODE>-<US_ID>`（如 `M01-US-101`）；
  多 US 同 Module 交付：在 §2.1-2.3 用 `M01 多 US 集合` 代表，避免重複列每個 US 的改動
- **2. Module 邊界即測試邊界** — Module 內所有探針必含 Module prefix（如 `M01-user-login-returns-correct-data`，v2.8 dav-developer 規則）；
  跨 Module integration test 用 `INT-<M01>-<M02>-<description>` 標記；交付時必列 Module 內探針清單 ＋ Module 級整合測試結果
- **3. deliverable.md 命名** — US 級 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`；Module 級
  `docs/deliverable/<YYYY-MM-DD>-<module>-<slug>.md`
  （例：US 級 `2026-09-26-m01-us-101-login.md`、Module 級 `2026-09-26-m01-auth-module.md`）
- **4. Module 交付有「第 9 段」** — US 級 deliverable 是 8 段（§1-§8）；Module 級多加 §9「Module 級總結」：
  9.1 多 US 間關聯（依賴關係：邊啲互相依賴、邊啲可獨立交付）｜9.2 跨 Module 遺留問題（如 `INT-M01-M02-checkout-flow` 未跑）｜
  9.3 Module 級技術債（本次未修 ＋ 跨 sprint 的）｜9.4 Module 級指標（探針總數／覆蓋率／LOC／變動歷史）｜9.5 Module 級下一步（vs US 級小行動）

### 5.3 Module 級 vs US 級交付對照

- **對應 Backlog**：US 級 1 個 US；Module 級 Module 內多 US｜**段數**：US 級 8 段；Module 級 8 ＋ 1（§9）
- **檔案命名**：US 級 `<date>-<slug>.md`；Module 級 `<date>-<module>-<slug>.md`
- **對話摘要**：US 級 ≤ 90 秒；Module 級可至 200 秒（多 US 需說明關聯）
- **反思層級**：US 級 6 維度；Module 級 6 維度 ＋ Module 級 6 維度（重複 12 項）
- **下一步**：US 級 US 級優先；Module 級 Module 級優先 ＋ US 級優先

### 5.4 Module 級反思（§8 內嵌）

Module 級反思在 US 級反思之上再加 Module 級 6 維度：① UX/UI 一致性 → Module 邊界一致性（內部 API 統一、錯誤碼統一）；
② RWD → 不適用 Module 級（除非 Module 含 UI）；③ 技術債 → Module 內部 ＋ 跨 Module 依賴的技術債；
④ 可維護性 → Module 內聚度（dav-designer 5 條原則驗證）；⑤ 測試覆蓋率 → Module 級覆蓋率（vs US 級單檔）；
⑥ 需求對齊 → Module 職責對齊 system-design.md 定義
