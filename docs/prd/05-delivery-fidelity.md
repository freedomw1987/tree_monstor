# PRD-05: Delivery Fidelity — 需求錨點 + 需求對帳 + 文件漂移探針

**版本**：v1.0
**日期**：2026-10-26
**Backlog**：TMO-071 / TMO-072 / TMO-073
**SOP 版本**：v2.2（當時值；該版本號軌已於 2026-10-26 隨 `AGENTS.md` §2 移除。四道大 Gate 定義不動；新增 §2.3 內嵌子關卡「Gate 4.5 需求對帳」）
**階段數**：3 階段（錨點 → 對帳 → 探針），每階段獨立可交付

---

## 背景

使用者回報的核心問題：**「用戶提出需求，到最後 AI 出來的成果對不上」**。追查後確認其中一個成因是
「流程中過了幾份文件，文件翻譯上出落差」。

現況 pipeline 的需求資訊流（每跳都是「讀 A → 用自己的話重寫 B」）：

```
用戶口述 → backlog 表格（AC 摘要）→ docs/ac/*.md（Given/When/Then）→ docs/prd/*（PRD 敘述）
        → 測試（只讀 backlog 摘要）→ 實作 → deliverable（Agent 自我敘述）
```

三個結構性缺口：

| # | 缺口 | 現況證據 |
|---|------|----------|
| 1 | **沒有根節點** | 用戶原話沒被保存成資產，越到後面越靠推導；最上游的「原話」只存在於對話記憶裡 |
| 2 | **沒有對帳** | 交付摘要是執行任務的同一個 Agent 自己寫的 = 自己評自己，無第三方比對 |
| 3 | **沒有機械防線** | `docs/ac/US-M71.md` 狀態仍是 PENDING，但它對應的 TMO-021 在 backlog 已是 done — 同一件事兩份文件各說各話 |

## 目標

1. 讓**用戶原話**成為可攜、可追溯的資產（錨點），全鏈路以它為準
2. 讓**成果對不對得上需求**由獨立第三方判定（對帳），且對不上時**擋下**「✅ 完成」
3. 讓**字面層漂移**在 CI 被機械抓出（探針），不靠 AI 自省

## 範圍

### In Scope

| 階段 | 內容 | Backlog | SP |
|------|------|---------|-----|
| 階段 1 | 需求錨點檔格式 + dav-planner 產出規則 | TMO-071 | 3 |
| 階段 2 | `dav-reconciler` skill + 對帳表格式 + 硬門檻 + 交付狀態降級規則 | TMO-072 | 5 |
| 階段 3 | `check-doc-drift.sh` + `tests/doc-drift.bats` + CI 步驟 | TMO-073 | 5 |

### Out of Scope（明確不做，避免膨脹）

| 不做 | 理由 |
|------|------|
| 方案 B（SSOT 收斂成單一 spec 檔）| 先用 A+C 量到落差率再決定；B 會改 4 支 skill 契約，影響面大 |
| 需求覆蓋率「門檻」（< 門檻即紅）| 存量 US 覆蓋率從 0% 起步，會一片紅；先只做 8 類字面對帳 |
| 回補存量 US 的錨點檔 | 一次性大爆炸；存量靠白名單豁免 |
| 新增 `gates.json` 的 gate 編號 | schema 的 `id` 只允許 `^gate-[0-9]+$`；Gate 4.5 定位為 §2.3 內嵌子關卡（見 §7 ADR-D1） |
| 對帳的「語意自動比對」| 語意判斷交給獨立 subagent；機械層只保證覆蓋率與格式 |

---

## FR-01：需求錨點檔（TMO-071）

### 檔案契約

- **路徑**：`<project>/docs/req/<US-ID>-requirement.md`（`<US-ID>` 與 `docs/ac/<US-ID>.md` 同名）
- **產生者**：`dav-planner`（§2.1 產 US 時同 turn 產生）
- **消費者**：`dav-designer`（設計時讀）、`dav-developer`（測試對應）、`dav-reconciler`（對帳基準）、
  `check-doc-drift.sh`（D6 檢查存在性；D7 檢查對帳表的 R-ID 覆蓋）

### 固定結構（4 段，段落標題為契約的一部分）

```markdown
# <US-ID> 需求錨點

> US: <US-ID> | 建立: <YYYY-MM-DD> | 來源: <對話摘要 / issue 連結 / 使用者原話>

## 用戶原話（唯讀）

- R1: 「<用戶原話逐字，不加改寫>」
- R2: 「<…>」

## 澄清後驗收句

- R1: <把 R1 轉成可驗收的一句話>
- R2: <…>

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
```

### R-ID 規則（跨檔追溯的唯一鍵）

| 規則 | 說明 |
|------|------|
| 格式 | `R<n>`，n 從 1 起連續 |
| 唯一 | 同一錨點檔內不可重複、不可跳號 |
| 一對一 | 「用戶原話」與「澄清後驗收句」同 R-ID 對應 |
| 唯讀 | 執行階段（設計 / 實作 / 對帳）**不得改寫**「用戶原話」段；補充澄清只能寫進「澄清後驗收句」並在「變更歷史」留痕 |
| 不可刪 | 已存在的 R-ID 不可刪除（需求被砍掉也要留 R-ID 並標註「已作廢」） |

### 存量處理

存量 US **不回補**。已存在 `docs/ac/<US-ID>.md` 但無對應錨點檔 → 記為豁免項（探針輸出為 WHITELIST，不紅）。

---

## FR-02：需求對帳（TMO-072）

### 觸發點與順序

```
§2.3 執行段結束 → 【Gate 4.5 需求對帳】 → §2.4 反省 → §2.5 提交
```

**為什麼在反省之前**：對帳是「事實比對」（需求句 ↔ 程式碼），反省是「觀點評析」（做得對不對）。
順序反了會讓反省建立在未經驗證的「已完成」前提上。

### 執行者

- **主路徑**：由**未參與實作的獨立 subagent** 執行（避免自證清白）
- **降級路徑**：環境無 subagent 能力時，由執行 Agent 自我對帳 → 對帳檔與交付摘要**必須**標註
  「⚠️ 對帳降級（無獨立 subagent）」，且不得宣告對帳通過的硬門檻

### 對帳者拿到的輸入（刻意做少）

| 給 | 不給（理由） |
|----|--------------|
| 錨點檔全文（需求原話 + 驗收句）| 實作過程自述（避免被引導成「照著我說的寫」）|
| 最終變更清單（檔案 + diff）| 執行者的完成宣告（自評不採信）|
| 專案既有的需求相關文件（AC 範本 / backlog 該列）| — |

### 對帳表格式（`docs/reconcile/<US-ID>-reconcile.md`）

```markdown
# <US-ID> 需求對帳表

> 對帳者: <subagent 名稱> | 對帳時間: <YYYY-MM-DD> | 錨點: docs/req/<US-ID>-requirement.md

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | … | ✅ 已實作 | path:line | 測試名 / 指令 | |
| R2 | … | ⚠️ 部分實作 | path:line | — | 缺 X 條件 |
```

- **狀態值**：`✅ 已實作` / `⚠️ 部分實作` / `❌ 未實作` / `🚫 已作廢`（4 種；已作廢者仍須列出，但不列入交付狀態判定）
- **覆蓋率**：表內**必須含錨點的全部 R-ID**（漏一條即為對帳不完整 → 探針可抓）
- **空狀態 fail-closed**（設計自審修正 C2）：錨點檔存在但**需求句數 = 0**（無任何 R-ID）→ 視為對帳失敗，
  不得視為「無需對帳」；對帳者必須回報「錨點無需求句」並由人補正錨點
- **實作位置**：要具體到檔案（可加行號 / 函式名），不得只寫「已完成」

### 硬門檻（寫進 `dav-submitter` 規則）

| 對帳結果 | 允許的交付狀態 |
|----------|----------------|
| 全部 R-ID = ✅ 已實作（🚫 已作廢不計入）| 可標「✅ 完成」 |
| 任一 R-ID = ⚠️ 或 ❌ | **不得**標「✅ 完成」；只能標「⚠️ 部分完成」並列出待補清單（全數 ❌ 時可標「❌ 未完成」）|
| 對帳缺失 / R-ID 未覆蓋 / 對帳降級未標註 | **不得**標「✅ 完成」 |

---

## FR-03：文件漂移探針（TMO-073）

### 腳本

- **路徑**：`scripts/ci/check-doc-drift.sh`（wrapper；實作邏輯用 **python3**，設計自審修正 C3）
- **實作選型理由**（C3）：D1/D2 需解析 Markdown 表格列、AC 編號、US-ID 對應 —— bash 做表格解析易錯且脆弱；
  repo 既有 CI 依賴已含 python3（既有 `check-python-heredocs.sh` 探針即證），故實作用 python3，shell 僅作薄 wrapper
- **rc 契約**：`0` = 無違規（含全部被白名單豁免）｜`1` = 有違規｜`2` = 用法 / 環境錯誤
- **輸出格式**（每行一項，供 CI 與人眼閱讀）
  - 違規：`DRIFT <類> <鍵>: <說明>`
  - 豁免：`WHITELIST <類> <鍵>: <理由>`（**必須輸出，不得靜默跳過**）

### 8 類檢查（D1..D8）

| 類 | 檢查 | 抓什麼 |
|----|------|--------|
| **D1** | `docs/ac/<US-ID>.md` 的狀態 vs `docs/backlog.md` 該 US 列的狀態 | 同一 US 兩份文件狀態不同步 |
| **D2** | AC 編號連續且唯一：`docs/ac/<US-ID>.md` 的 `AC01..ACn` 連續、不重複 | AC 被刪改 / 編號漂移 |
| **D3** | `docs/prd/*.md` 追溯矩陣的 US ID 集合 ⊆ backlog 的 US ID 集合 | 引用幽靈 US（不存在的 ID） |
| **D4** | `docs/deliverable/*.md`「變更清單」提到的檔案真的存在 | 交付摘要寫了沒做的檔案 |
| **D5** | `docs/ac/<US-ID>.md` vs `docs/ac/<US-ID>.html` 的狀態一致 | 雙份真相不同步 |
| **D6** | `docs/ac/<US-ID>.md` ↔ `docs/req/<US-ID>-requirement.md` 對應關係 | AC 有但無需求錨點（需求無根節點）|
| **D7** | 對帳表覆蓋錨點的全部 R-ID + 狀態值合法；已交付（backlog `done`）的 US 必須有對帳表 | 對帳漏需求句 / 狀態值亂寫 / 交付未對帳 |
| **D8** | 交付摘要（`date >= from-date`）若對應有錨點的 US，必需含「需求對帳」段；且對帳有 ⚠️/❌ 時**不得**標「✅ 完成」 | 交付狀態與對帳結果矛盾 / 漏對帳段 |

> **D2 為何不做「backlog AC 摘要 vs AC 標題同字」比對**（設計自審修正 C1）：backlog 欄位是**壓縮摘要**
> （例如「6 條 BDD」），本來就不等於 AC 標題全文，字面比對必然誤紅 → 該做法會製造大量假紅。
> 改以「AC 編號」為比對鍵：編號結構化、不可自由改寫，適合機械驗。
> 代價：D2 抓不到「編號沒變但描述被改寫」的語意漂移 → 該層由 FR-02 對帳（語意層）負責。
>
> **US-ID 解析規則**（設計自審修正 C4）：AC 檔與 backlog 列的對應鍵支援兩種形式——
> `US-<編號>` 與 `TMO-<編號>`（本次新 AC 檔用後者）；以檔名 stem 作為 key，兩邊皆以 key 比對，不做前綴假設。

### 白名單

- **檔案**：`docs/ci/drift-whitelist.txt`（每行：`<類>#<鍵>#<理由>`；`#` 開頭為註解）
- **規則**：豁免必須帶理由；理由為空 → 視為無效白名單（腳本 rc=2，fail-closed）
- **禁止**：不得以「白名單」名義關閉整類檢查（腳本會檢查是否有 `D1#*` 這類通配全類豁免 → rc=2）

### 探針與 CI

- **探針**：`tests/doc-drift.bats`（DD 系列：rc 契約 / 8 類各自能抓 / 白名單必須輸出理由 / 無效白名單 fail-closed /
  通配全類豁免被拒 / **突變測試**：故意破壞 → 探針必須變紅）
- **CI**：`.github/workflows/ci.yml` 加一步呼叫該腳本；**不得** `continue-on-error` / `|| true`（否則是假綠）

---

## 整合面（要動的既有檔案）

| 檔案 | 改動 | 觸發 |
|------|------|------|
| `skills/dav-planner/SKILL.md` | Step 4 增列「同步產出錨點檔」+ R-ID 規則 | V03 二審 |
| `skills/dav-planner/backlog-rules.md` | §4.6 產出 SOP 增列錨點檔 | V03 二審 |
| `skills/dav-submitter/SKILL.md` | 交付模板加「需求對帳」段 + 狀態降級規則 | V03 二審 |
| `skills/dav-submitter/SKILL.md`（v2.6 併入反省 Step 3.5） | 說明「對帳先於反省」的順序 | V03 二審 |
| `skills/dav-reconciler/`（新） | SKILL.md（≤150 行）+ `reconcile-format.md` + `examples.md` | 新建 |
| `docs/sop/handbook/2.3-execution.md` | 新增「Gate 4.5 需求對帳」段落 | V03 二審 |
| `docs/sop/handbook/2.4-reflection.md` | 前置說明（對帳 → 反省） | V03 二審 |
| `AGENTS.md` §2.3（已於 2026-10-26 移除）| Gate 速查表加 Gate 4.5 一列 | V03 二審 |
| `docs/sop/gates.json` | **不動**（見 §7 ADR-D1） | — |
| `docs/ac/README.md` | 命名規範補 `TMO-<nnn>` 形式（本次新 AC 檔用此形） | — |
| `scripts/ci/check-doc-drift.sh` + `tests/doc-drift.bats` + `.github/workflows/ci.yml` | 探針與 CI | Gate 1/2/3 |

### 主檔行數預檢（原 V03.5；2026-10-26 起併入 `AGENTS.md` §1.5 的 V03）

| 檔 | 現況 | 預估 | 上限 |
|----|------|------|------|
| `AGENTS.md` | 112 行 | **121 行**（當時實際；現 35 行）| 150 |
| `skills/dav-planner/SKILL.md` | 129 行 | **140 行**（實際） | 150 |
| `skills/dav-submitter/SKILL.md` | 現況 | +6 | 150 |
| `skills/dav-reconciler/SKILL.md` | 新建 | **120 行**（實際） | 150 |

---

## 追溯矩陣

| FR | User Story | 對應畫面 | 原型檔案 | 狀態 |
|----|-----------|----------|----------|------|
| FR-01 需求錨點檔 | TMO-071 | N/A（無 UI：純文件契約）| N/A | ✅ 已實作（2026-10-26）|
| FR-02 需求對帳 | TMO-072 | N/A（無 UI：CLI / 對話產出）| N/A | ✅ 已實作（2026-10-26）|
| FR-03 漂移探針 | TMO-073 | N/A（無 UI：CI 腳本）| N/A | ✅ 已實作（2026-10-26）|

> **畫面 / 原型 N/A 的理由**：本模組全為 CLI + Markdown + CI 腳本，無任何使用者介面或互動原型需求
> （DoD-Lite 僅指 Happy path；此處連 Happy path 畫面都不存在）。依 dav-designer Step 2 / Step 5 規則，
> DESIGN.md 與 `docs/prd/05-*.html` **不產出**，並在設計自審報告中記錄原因。

---

## 7. 架構決策記錄（ADR）

### ADR-D1：Gate 4.5 不進 `gates.json`

- **狀態**：Accepted（2026-10-26）
- **背景**：`docs/sop/gates.json` 的 schema 限定 gate `id` 符合 `^gate-[0-9]+$`（整數），而「需求對帳」是排在 Gate 4 之後、
  §2.4 之前的**子關卡**，不是第五道大 Gate。gates.json v1.1.0 曾移除 Gate 5（RSI 機制歸檔）——那是「整道 Gate 從流程上消失」，
  與本案的「在同一階段內加一道子關卡」性質不同。
- **決策**：Gate 4.5 定義寫在 `docs/sop/handbook/2.3-execution.md`（§2.3 內嵌子關卡）。`gates.json` 本次**不動**。
  （2026-10-26 更新：`AGENTS.md` 已不再內嵌 Gate 速查表，Gate 4.5 的登記點改為 handbook §2.3 ＋ `skills/dav-reconciler/SKILL.md`）
- **代價**：`gates.json` 不再是「所有關卡的 single source of truth」。
  （2026-10-26 更新：四道大 Gate 的**定義本體**已改由各自承載它的 skill 負責，`gates.json` 為機器可讀副本；
  子關卡的定義本體在 handbook §2.3。）
  接受此代價：動 schema（放寬 id 格式）代價更高，且會讓「Gate 5 曾被移除」的歷史更難辨識。
- **影響**：handbook §2.3 + 承載它的 `skills/dav-reconciler/SKILL.md` 必須同步（V03 二審項；2026-10-26 起 AGENTS.md 不再內嵌速查表）。

### ADR-D2：對帳表獨立成 `docs/reconcile/<US-ID>-reconcile.md`

- **決策**：對帳表不併入 deliverable，而是獨立檔；deliverable 內只放「需求對帳」摘要段 + 連結。
- **理由**：① 對帳是「對特定 US 的可覆核紀錄」，需能獨立重跑、獨立被探針檢查；② 併入 deliverable 會讓交付摘要膨脹且難以機械驗 R-ID 覆蓋率；
  ③ 與 `docs/ac/`、`docs/prd/` 的「一個 US 一份」慣例一致。
- **代價**：多一個文件類型（docs/ 從 4 類到 5 類）。

### ADR-D3：漂移探針的白名單採 fail-closed

- **決策**：白名單每行必須含理由；理由為空 → 腳本 rc=2（不是「忽略該行」）；不允許 `<類>#*` 全類豁免。
- **理由**：白名單是最容易被當成「關掉檢查」的後門；fail-closed 讓「忘了寫理由」變成紅燈而非靜默豁免。
- **代價**：新增白名單項時要多寫一行理由（小負擔，刻意設計）。

---

## Story Point 估算

| 階段 | 工作項 | SP |
|------|-------|-----|
| 1 | 錨點格式 + dav-planner 規則 + 範例 + 探針 | 3 |
| 2 | dav-reconciler skill + 對帳表格式 + submitter 硬門檻 + 探針 | 5 |
| 3 | 漂移腳本 + 8 類檢查 + 白名單 + 探針 + CI | 5 |
| **合計** | | **13** |

## 風險與緩解

| 風險 | 緩解 |
|------|------|
| 「唯讀」靠約定不靠機械鎖 | R-ID 化讓「有沒有被改過」在對帳時可被第三方比對；變更歷史留痕 |
| 對帳 subagent 被實作自述引導 | 對帳者輸入刻意做少（只給錨點 + diff） |
| 硬門檻讓過去標「✅ 完成」的項被降級 | 屬預期收緊；過渡期白名單只豁免「探針類」，不豁免「對帳硬門檻」 |
| D2 比對誤紅（格式變動）| 比對前正規化 + 白名單（須帶理由） |
| 存量 US 無錨點 → 覆蓋率 0% | 誠實揭露於交付摘要；不假裝覆蓋 |
| 對帳本身增加流程耗時 | 對帳只跑「本次 US 的 R-ID 數量」，通常 < 10 條 |

## DoD

### 階段 1（TMO-071）

- [x] `docs/req/` 至少 1 份範例錨點檔，4 段結構齊全、R-ID 連續（實際產 3 份：TMO-071/072/073）
- [x] dav-planner 規則已登錄（純文字引用，不綁死路徑）→ `skills/dav-planner/SKILL.md` v2.7 + `backlog-rules.md` §4.7
- [x] `bats tests/doc-drift.bats` 相關探針綠（DOC-DRIFT-001..007）

### 階段 2（TMO-072）

- [x] `skills/dav-reconciler/` 主檔 ≤150 行（120 行）、frontmatter 齊全、5 段導航、純文字引用
- [x] 對帳表格式 + 硬門檻規則已登錄（dav-submitter v2.5 + `template.md` §3.1）
- [x] handbook §2.3 / §2.4 已登錄 Gate 4.5（`gates.json` 刻意不動，見 ADR-D1）；2026-10-26 起改由 `skills/dav-reconciler/SKILL.md` 承載
- [x] 探針綠（2026-10-27 減法後檔名：`skills/dav-reconciler/tests/doc-drift.bats`）

### 階段 3（TMO-073）

- [x] `scripts/ci/check-doc-drift.sh` rc 契約正確、8 類檢查皆能抓到（DOC-DRIFT-009..037）
- [x] `tests/doc-drift.bats` 全綠（含突變測試 + mutant 表登錄 DD-M1 / DD-M2 / DD-M3 / DR-M1；**不寫死條數**，避免每次加探針就要回來改一次）
- [x] CI 步驟存在且不得假綠（DOC-DRIFT-022 守護；CI 顯式帶 `--from-date` 讓門檻放寬可見）

### 整體

- [x] 3 個 US 全部 done，backlog 更新（**第 6 輪對帳通過後才翻**——依 `reconcile-format.md` §7 硬門檻：7/7 全 ✅）
- [x] V03 Reviewer 二審完成（diff + verdict 並呈用戶）→ 第 1 輪 request-changes（1 P0 / 4 P1 / 10 P2 / 5 P3）
  → 已修；第 2 輪 request-changes（1 P0 / 3 P1 / 6 P2 / 6 P3）→ 已修（見全域 changelog v2.11 二審結論節）
- [x] `bats tests/` 全套不退化（baseline 47 紅 → 47 紅，差異僅 flaky tmp 路徑）

> **PRD 狀態由對帳結果決定，不由執行者自評**：本 PRD 的「追溯矩陣狀態 / DoD 勾選」若與 backlog、對帳表、
> changelog 任一處不一致，D 系列探針會抓（目前 D7 已覆蓋「已交付必對帳」與「對帳表 R-ID 覆蓋」）。

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-10-26 | v1.0 | 初版建立（Delivery Fidelity PRD）| Agent |
