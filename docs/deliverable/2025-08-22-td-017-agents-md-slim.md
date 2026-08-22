# TD-017 交付摘要 — AGENTS.md 精簡重構

**日期**：2025-08-22
**Backlog ID**：TD-017（P1，3 SP）
**作者**：Agent
**狀態**：✅ 完成（但有 §2.7 fail-fast 自檢揭露一個小違規）

---

## 摘要

把 AGENTS.md 從 524 行精簡到 68 行（-87%），§2.1-§2.8 + §3 CHANGELOG 抽出去
`docs/sop/handbook/*.md` 一章一檔（9 個檔案），AGENTS.md 用相對路徑引用。
目的是讓大模型可穩記核心內容（萬事原則、提問紀律、SOP 範圍判斷、4 Gate 表格、引用索引）。

---

## 變更清單

| 檔案 | 改動 |
| --- | --- |
| `AGENTS.md` | 524 → 68 行（重寫） |
| `docs/sop/handbook/2.1-planning.md` | 新建（31 行）|
| `docs/sop/handbook/2.2-design.md` | 新建（40 行）|
| `docs/sop/handbook/2.3-execution.md` | 新建（27 行）|
| `docs/sop/handbook/2.4-reflection.md` | 新建（95 行）|
| `docs/sop/handbook/2.5-submission.md` | 新建（72 行）|
| `docs/sop/handbook/2.6-general-task.md` | 新建（54 行）|
| `docs/sop/handbook/2.7-violations.md` | 新建（36 行）|
| `docs/sop/handbook/2.8-suggester.md` | 新建（53 行）|
| `docs/sop/handbook/changelog.md` | 新建（46 行）|
| `tests/agents-md.bats` | 加 3 個 TD-017 AC 測試 + 修 SOUL-3 awk pattern |
| `docs/backlog.md` | 加 TD-017 條目 |

---

## 驗收證據

### Gate 1 (TDD) — 純文件改動，符合 gates.json Gate 1 `notes` 豁免

豁免但仍**加 3 個 regression 測試**保護未來不再膨脹。

### 依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 完整測試套件跑過

| 階段 | 通過 / 失敗 |
|---|---|
| 原始（TD-017 實作前）| 42 / 0 |
| After（TD-017 實作後） | 45 / 0 |
| Diff | +3 新探針（TD-017 AC-1/2/3），0 破壞 |

### 依 gates.json 規範，Gate 4 (reviewer) 需要：5 項手工檢查全綠

| 檢查項 | 結果 |
|---|---|
| AGENTS.md 行數 < 200（目標 ~150）| ✅ 68 行 |
| 9 個 handbook 檔案存在且非空 | ✅ 9/9 |
| AGENTS.md 含 9 個相對路徑引用 | ✅ 15 處引用 |
| SOUL 7 個 bullet 全部 verbatim 在 AGENTS.md | ✅ |
| bats 45/45 | ✅ |

---

## ⚠️ §2.7 SOP 違規自檢（誠實標記）

### 第 1 次跑 Gate 3 時發現問題

第一次跑 bats 後發現 `SOUL-1`、`SOUL-3`、`SOUL-4` **3 個測試失敗** — 我精簡 AGENTS.md 時**不小心刪掉了 SOUL「你是有承擔的」「Think Big」2 個 bullet**和「pi 不會讀 SOUL.md」註腳。

這是 §2.7 fail-fast 規範的**真實範例** — 違反「不可假裝通過」。幸好 bats 探針抓到。  
**修補動作**：補回缺的 2 個 SOUL bullet + 1 個註腳。

### 修補後修了一個測試邏輯

SOUL-3 測試的 awk pattern 是 `^> 註：` 太早結束，新版 AGENTS.md 把「> 註」放 §1 萬事原則後，導致它抓到 §1.5 的 2 個 V01/V02 bullet。

**修補動作**：把 awk pattern 改成 `^### 1\.5` 精準切割。

---

## 已知問題

| ID | 問題 | 處理 |
|---|---|---|
| O1 | AGENTS.md 精簡後**少了 §1「你是用戶好伙伴」bullet 之一的細節內容**（如「有時選項要有給用戶輸入的空間」這段已被併入但 SOUL-1 仍驗證通過） | 沒問題，bullet 完整保留 |

---

## 下一步建議（V20）

- **驗收方式**：
  1. 跑 `wc -l AGENTS.md` 看 ≤ 100 行
  2. 跑 `bats tests/agents-md.bats` 看 SOUL-1/3/4 全綠（防止再被砍）
  3. 跑 `bats tests/install.bats tests/agents-md.bats` 看 45/45
  4. 開 AGENTS.md 確認引用都對
- **預估時間**：< 10 分鐘
- **風險提示**：
  - ⚠️ **R1**：未來新增 SOP 章節時，要記得更新 handbook 並在 AGENTS.md 加引用 — 建議在 §2.0 加「新增 SOP 章節要同步更新 handbook」條款
  - ⚠️ **R2**：AGENTS.md 內的相對路徑引用是「硬連結」，未來如果 handbook 檔案重新命名要記得同步改引用

---

## 觀察

| # | 觀察 | 影響 |
| - | -- | -- |
| O2 | 精簡後 AGENTS.md 行數（68）遠低於目標（~150），代表我有過度精簡的傾向 | 提醒：精簡 ≠ 砍掉必要的，core 仍要保留 |
| O3 | SOUL bullet 是「必記」的不可刪內容，但 1.5 段 V01/V02 bullet 也是 — 兩者必須分清楚 | 建議：未來 AGENTS.md 開頭加「不可刪除的內容清單」 |