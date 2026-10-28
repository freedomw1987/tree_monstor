---
name: dav-planner-backlog-format
description: dav-planner 的「Backlog 格式範本」附件。含表格欄位範本、AC 段範本、Module 欄位填法、需求錨點檔固定結構範本、術語表格式範本。規則語意見同套 `backlog-rules.md`。
---

# Dav Planner — Backlog 格式範本

> 本檔只放「可直接抄落 `docs/` 嘅格式範本」；規則語意（欄位意思、生成時機、限制）留喺同套 `backlog-rules.md`。

## §4.3.1 Backlog 表格範本（含 Module 欄位）

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

## §4.3.1 AC 段範本

> 沿用 INVEST ＋ Given-When-Then；**完整可抄範例**見同套 `examples/backlog.md`。

```markdown
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

## §4.3.2 Module 欄位填法（planner 不預設）

> Module 內容由 `dav-designer` Step 1 切割、Step 3 回填 backlog；planner 階段一律 `M00`（未定義）。
> 批次清單（**1 批次 = 1 Module**）由設計階段產出 —— planner 唔另開 sprint／批次表。

| 情況 | Module 欄填法 |
| --- | --- |
| 設計期未切割（planner 階段） | `M00`（未定義） |
| 已切割 | `M01`（單一 Module）｜`INT`（跨 Module 整合）｜`DE-301`／`TECH-401`（唔綁 Module） |

## §4.7 需求錨點檔固定結構範本

> 段落標題係契約的一部分（4 段）；R-ID 規則見同套 `backlog-rules.md` §4.7。

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

## §4.9 術語表格式範本

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
