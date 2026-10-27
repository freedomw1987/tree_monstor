---
name: dav-planner-backlog-rules
description: dav-planner 的「Backlog 編寫規則」附件（v2.2 拆分自主檔）。含 INVEST / AC / 表格欄位 / 類型 / 更新規則 / AC 範本生成 SOP。
---

# Dav Planner — Backlog 規則（§4 完整版）

> 本檔為 dav-planner 的 Backlog 編寫規則附件，於產出 Backlog 前查閱。主檔在 `SKILL.md`。

## §4.1 INVEST 原則 + AC 格式

**INVEST**：Independent 獨立｜Negotiable 可協商｜Valuable 有價值｜Estimable 可估算｜Small 小｜Testable 可測試。

**AC 範本**：Given-When-Then 3 條以上 BDD 格式 + DoD 技術視角 checklist（4-6 項）。

## §4.3 Backlog 編寫方式

- 表格欄位：US ID / 類型 / 標題 / **Module（v2.3 新增）** / AC / 優先級 / Story Point / 狀態 / 依賴
- 詳細段：放在表格下方（## TMO-XXX 詳細）
- 既有 US 不主動遷移；新 US 走新格式
- **「依賴」欄／「業務規則」行嘅來源**：由 §3「業務邏輯與依賴」維度填入（問完就要寫落文件）

### §4.3.1 Module 欄位範本（v2.3 新增）

> v2.3 起：Backlog 表格加 `Module` 欄位，讓 dav-designer 的 Module 定義能直接被 dav-developer 派工用、dav-developer 探針也能綁 Module。

**Backlog 表格範本（含 Module 欄位）**：

```markdown
#
# Backlog

| US ID | 類型 | Module | 標題 | AC | 優先級 | Story Point | 狀態 | 依賴 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M01-US-101 | US | M01 | 用戶登入 | 3 條 BDD | P0 | 3 | PENDING | — |
| M01-US-102 | US | M01 | 忘記密碼 | 3 條 BDD | P0 | 5 | PENDING | M01-US-101 |
| M02-US-201 | US | M02 | 付款閘道 | 4 條 BDD | P0 | 8 | PENDING | — |
| M02-US-202 | US | M02 | 退款流程 | 3 條 BDD | P1 | 5 | PENDING | M02-US-201 |
| INT-M01-M02-01 | US | INT | 登入後付款 | 2 條 BDD | P0 | 5 | PENDING | M01-US-101, M02-US-201 |
| DE-301 | DE | M01 | 修正登入 token 過期 | — | P1 | 2 | PENDING | — |
| TECH-401 | TECH | M02 | 付款 API 重構為 async | — | P2 | 8 | PENDING | — |
```

**Module 代碼規則**（v2.3 沿用 dav-designer / dav-developer 共識）：

- **`M<NN>`**
  - 語義：單一 Module
  - 範例：`M01`、`M02`、`M10`
- **`M<NN>-M<NN>`**
  - 語義：多 Module 關聯（跨 Module 邊界）
  - 範例：`INT-M01-M02`
- **`INT-<Mxx>-<Myy>`**
  - 語義：Integration test Module（跨 Module）
  - 範例：`INT-M01-M02-01`
- **未定義**
  - 語義：Module 未切割 fallback = `M00`（整個 repo）
  - 範例：`M00-US-XXX`

**US ID 規則**（與 Module 欄位一致）：

- `M01-US-101`：Module M01 的 US 編號 101
- `INT-M01-M02-01`：跨 M01 / M02 的 Integration US 編號 01
- `DE-301` / `TECH-401`：跨 Module 的 Bug / 技術債（不綁 Module）
- 不寫 Module 欄位 = `M00` fallback

**AC 段範本**（v2.3 沿用 INVEST + Given-When-Then；**完整可抄範例**見同套本 skill 子檔 `./examples/backlog.md`）：

```
# <US-ID> 詳細

- **對應 Module**: <Module 代碼（名稱）>
- **負責 dev**: （派工後填入）
- **預估時間**: <N> SP
- **AC**: 3 條以上 Given-When-Then + DoD（技術視角 checklist）
- **業務規則**: —（有計算 / 狀態 / 權限 / 冪等規則時必填；冇就寫 N/A。來源：§3「業務邏輯與依賴」維度）
- **依賴**: —
- **驗收方式**: 跑 `REGRESSION_MODULE=<M> ./run_pipeline.sh <US-ID>`
- **為什麼這個優先**: <一句講清優先級理由>
```

### §4.3.2 Module 級 sprint 規劃（v2.3 新增）

> dav-designer v2.3 規範 + dav-developer v2.2 + dav-developer v2.10 共同鋪路下，backlog 規劃可以 Module 級而非純 US 級。
> 1 個 sprint 交付 1 個 Module（M01）；dav-submitter v2.2 Module 級交付語法記錄；dav-developer v2.2 用 Module 級派工；
> dav-developer v2.10 用 `REGRESSION_MODULE=M01` 跑全 Module 探針。
> **為什麼 Module 級 sprint**：平行化加速（M01 / M02 兩個 dev 同時做）｜錯誤範圍隔離｜探針邊界清楚（`REGRESSION_MODULE` 限定）。

**Module 級 sprint 範本**（完整範例見同套本 skill 子檔 `./examples/backlog.md`「Module 級 Sprint 規劃」節）：

```markdown
#
# Sprint 1（Module M01 整體交付）

| US ID | 類型 | Module | 標題 | 優先級 | SP | 狀態 |
| --- | --- | --- | --- | --- | --- | --- |
| M01-US-101 | US | M01 | 用戶登入 | P0 | 3 | PENDING |
| M01-DE-301 | DE | M01 | 修正登入 token 過期 | P1 | 2 | PENDING |
```

## §4.4 類型混合管理

- 類型：User Story（新功能）/ Defects（Bug）/ Technical Debt（技術債）/ Spike（研究）
- 頂部精細、底部粗略（Granularity）

## §4.5 Backlog 更新規則

- 每一個項目目錄只有並唯一有一份 `docs/backlog.md`
- 每次新 Backlog item 填到表格最下方，不估算 / Sprint / Module，預設 PENDING
- **只保留未完成**：backlog.md 只留 **未完成**（`todo`／`doing`／`⏸️`）嘅 row；
  **完成（done）嘅 row 要移出**（唔留喺 backlog）
  - 完成嘅記錄去邊：交付摘要（`docs/deliverable/<...>.md`，含做咗乜 ＋ 對帳段）＋
    該 US 嘅需求錨點（`docs/req/`）＋ 該 US 嘅 AC（`docs/ac/`）＋ git history
  - **點解**：backlog 係「仲要做嘅嘢」清單；完成嘅 row 留低只會令 backlog 愈滾愈大、
    令 agent／用戶每次都要重讀已完嘅嘢（浪費時間同 token）
  - 每次更新 backlog 都要順手檢查：有冇已完成嘅 row 殘留 → 有就移出（並喺交付摘要記低）

## §4.6 AC 範本生成 SOP（v1.8 新增，含 HTML）

- **生成時機**：用戶確認新 US 後、寫進 backlog.md 之前
- **生成順序（同 turn）**：先 .md → 再 .html → 最後更新 backlog.md
- **為什麼同 turn**：避免 .md 與 .html 不同步
- **過渡期規則**：既有 US（§4.3.2 之前）不主動生成 AC 範本
- **自我檢查清單**：5 項（檔案存在 / 連結路徑 / CSS 媒體查詢）—— 詳見同套本 skill 子檔（`./examples/backlog.md`）

## §4.7 需求錨點檔生成 SOP（v2.7 新增）

> **為什麼需要**：需求在 pipeline 裡會被抄寫多次（backlog 摘要 → AC → PRD → 測試 → 交付摘要），
> 每抄一次掉一層，最後成果與需求對不上。錨點檔把**用戶原話**存成資產，作為全鏈路的根節點。

### 檔案契約

- **路徑**：`docs/req/<US-ID>-requirement.md`（`<US-ID>` 與 `docs/ac/<US-ID>.md` 同名）
- **產生時機**：用戶確認新 US 後、寫進 backlog.md 之前（與 AC 範本同 turn）
- **產生順序（同 turn）**：AC .md → AC .html → 錨點檔 → 更新 backlog.md
- **過渡期規則**：既有 US **不回補**（避免一次性大爆炸；缺錨點以白名單豁免）

### 固定結構（4 段；段落標題是契約的一部分）

```markdown
# <US-ID> 需求錨點

> US: <US-ID> | 建立: <YYYY-MM-DD> | 來源: <對話摘要 / issue 連結>

## 用戶原話（唯讀）

- R1: 「<用戶原話逐字，不加改寫>」

## 澄清後驗收句

- R1: <把 R1 轉成可驗收的一句話>

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
```

### R-ID 規則（跨檔追溯的唯一鍵）

- **格式**
  - 說明：`R<n>`，n 從 1 起連續
- **唯一**
  - 說明：同一錨點檔內不可重複、不可跳號
- **一對一**
  - 說明：「用戶原話」與「澄清後驗收句」同 R-ID 對應
- **唯讀**
  - 說明：後續階段（設計 / 實作 / 對帳）**不得改寫**「用戶原話」段；澄清只能寫進「澄清後驗收句」並在「變更歷史」留痕
- **不可刪**
  - 說明：已存在的 R-ID 不可刪除（需求被砍掉也要留 R-ID 並標註「已作廢」）——對帳時記為 🚫 已作廢（仍須列出，但不列入交付狀態判定）

### 自我檢查清單（5 項）

1. 檔案存在於 `docs/req/` 且檔名 = `<US-ID>-requirement.md`
2. 4 段結構齊全（`## 用戶原話（唯讀）` / `## 澄清後驗收句` / `## 變更歷史` + 標題）
3. R-ID 從 R1 起連續、無重複
4. 驗收句的 R-ID 集合 = 原話的 R-ID 集合
5. 原話為**逐字**（不得加「我認為」「應該」等 AI 口吻修飾）
## §4.9 術語表（Glossary）規格

> **做咩**：規劃階段收集需求時，順手把「專案／領域專屬術語」整理成一份 **A-Z 術語表**，
> 放喺專案層 `docs/glossary_list.md` → 之後每個階段（設計 / 執行 / 驗收 / 交付）同用戶
> **用同一套詞語**：減少「同一件事兩種叫法」嘅理解落差，亦令 LLM 唔使每個階段重新對齊用語。
> （術語表細、A-Z、每條一句 → 讀入成本低，係「減低重新理解」嘅前提。）

### 產出條件

- **專案有 ≥ 3 條「專屬術語」先產**；少過 3 條 → 唔好開檔（寫入相關 US 詳細段就得）
- 冇專屬術語嘅專案 → **唔好**為齊全而開空檔（淨係 context 負擔）

### 收錄標準（Domain-Specific）

- **專案／領域專屬術語（例：付款閘道、狀態機、`Jev Oracle`、探針命名規則）**
  - 不收錄：通用詞（用戶、系統、資料庫、API、錯誤）
- 同一件事嘅**第二種叫法**（別名）→ 記低並指定統一用邊個
  - 不收錄：一次性描述、句子、需求細節
- **縮寫 ＋ 英文全名**
  - 不收錄：同義重複詞（只記一個 ＋ 同義寫法欄）

### 格式（A-Z 排序 ＋ 簡潔定義）

```markdown
# <專案名> Glossary（術語表）

> A-Z 排序 ｜ 用途：各階段同用戶用同一套詞語 ｜ 來源：規劃階段提問整理

| 術語 | 定義（一句，≤ 40 字）| 同義寫法（同一件事嘅其他講法）|
|------|----------------------|------------------------|
| AC（驗收條件）| 一條 US 嘅可驗收行為描述（Given-When-Then）| — |
| Backlog（待辦清單）| 本專案所有 US／DE／TECH／Spike 嘅總表 | 待辦、任務清單 |
```

> ⚠️ **「術語」欄 = 應該用嘅**（英文 key ＋ 中文對照）；**「同義寫法」欄 = 同一件事嘅其他講法**
> （可以咁理解，但唔會另立新詞）；**會指錯嘢嘅寫法另列「勿用寫法」清單，唔好混喺呢欄**。
> ⚠️ **兩欄互斥**：任何字串只准出現喺其中一欄。

### 排序規則

- 英文術語按 **A-Z**（大寫唔敏感）；中文術語按**拼音**（或統一用英文術語做 key、中文對照放術語欄括號）
- 新增／改名 → **插入正確位置**，唔好 append 喺尾

### 維護規則

- **已存在 `docs/glossary_list.md` → 合併更新**（保留既有術語、A-Z 插入新詞），**唔好覆蓋重寫**
  ——覆蓋會令之前各階段用過嘅用語失效，直接打爛「跨階段一致」呢個目的
- 規劃階段建立；**其他階段發現新專屬術語 → 直接加落同一張表**（A-Z 插入），唔好各自發明叫法
- 術語改名 → 同步改引用該詞嘅文件（PRD / AC / 交付摘要）
- 唔准喺表內寫長篇說明或例子 → 例子留喺 PRD / AC
