---
name: dev-checker-loop
description: 雙 Subagent 工作循環：dev 開發任務、checker 校驗質量，確保出品避免低級錯誤。適用於大型項目、嚴格品質要求、或 V03 SOP 修改提案。
---

# Dev-Checker Loop

## TL;DR

1. **做什麼**：兩個 Subagent 循環協作 — **dev** 領任務開發（含 regression-guard 探針）→ 標記「等待校驗」→ **checker** 全面校驗 → 發現問題由 dev 自動修復 → 重複循環直到終止條件。
2. **何時觸發**：大型項目、嚴格品質要求、V03 SOP 修改提案、用戶指定 dev-checker-loop。
3. **預設 SOP 路徑**：§2.3 Gate 4 reviewer gate（在 Gate 1/2/3 後）。
4. **關鍵紀律**：
   - **dev 必含探針**：保留 regression-guard 探針（見同套 regression-guard skill，需同套安裝）
   - **問題必記錄**：checker 發現的問題必寫進對話 / log，不口頭講
   - **20 次循環上限**：任一問題超過 20 次循環未解即中斷
   - **純文字引用**：skill 內不放跨檔 markdown 連結
5. **必產出物**：校驗報告（含問題清單、修復紀錄）+ dev 修復後代碼

## 觸發時機

| 情境 | 觸發 |
|------|------|
| V03 SOP 修改提案 | ✅ 必須（Reviewer 二審）|
| 大型項目多人協作 | ✅ 適合 |
| 嚴格品質要求 | ✅ 適合 |
| 大規模重構（如本次 TMO-009）| ✅ 適合 |
| 純提問 / 不需開發 | ❌ 不觸發 |
| 簡單任務（單檔修改）| ❌ 不適合（成本過高）|

## 流程（5 步）

### Step 1：dev 領取任務（Module 級派工）

- **動作**：dev Subagent 從 `docs/backlog.md` 領 PENDING 任務，讀 `docs/system-design.md` 拿到 **Module 綁定**（任務的 Module 欄位）；更新為 `in_progress`
- **為什麼**：避免兩個 dev 同時搶同一任務；Module 綁定讓不同 Module 可平行派工
- **產出**：backlog 狀態更新 + Module 邊界記錄（哪個 dev 負責哪個 Module）
- **證據**：backlog.md 有對應 row 標記 + dev 持有的 Module 清單

### Step 2：dev 開發（含 Module 邊界）

- **動作**：依 `docs/system-design.md` 的 Module 邊界開發（檔案變動不得跨 Module，詳見「Module 感知邏輯」章節）；保留 regression-guard 探針（探針名稱必含 Module prefix，如 `M01-user-login-returns-correct-data`）；完成後標記「等待校驗」
- **為什麼**：探針是後續校驗的依據；Module 邊界讓錯誤不外洩
- **產出**：Module 內代碼 + 探針（帶 Module prefix）+ 標記
- **證據**：探針可運行（只檢 Module 內） + backlog 標記

### Step 3：checker 全面校驗（Module 級校驗）

- **動作**：checker Subagent 監控 backlog，發現「等待校驗」→ 校驗範圍限定 Module 邊界內（功能正確性、代碼品質、測試覆蓋、regression-guard 探針）→ 發現問題記錄
- **為什麼**：避免低級錯誤、確保品質；Module 邊界內校驗避免「跨 Module 越權」
- **產出**：校驗報告（問題清單 + 分級 P0/P1/P2 + Module 標註）
- **證據**：報告存在 + 問題清單完整 + 問題屬單 Module 或標「跨 Module」

### Step 4：dev 自動修復（Module 內修復）

- **動作**：dev 自動領取「需修復」狀態的問題、**在 Module 邊界內修復**、重跑探針、再標記「等待校驗」；需跨 Module 修復 = 升級為新任務
- **為什麼**：自動化循環、不停下來等人；Module 邊界避免修復波及無關 Module
- **產出**：Module 內修復後代碼
- **證據**：探針全綠（限 Module） + backlog 更新

### Step 5：循環直至終止

- **動作**：依終止條件判斷（用戶手動 / 全部完成 / 20 次循環上限）；滿足即停止
- **為什麼**：避免無限循環、避免過度迭代
- **產出**：最終報告（總循環數、問題修復率、剩餘風險）
- **證據**：對話有「Loop 結束」+ 最終報告

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| dev 必含 regression-guard 探針 | N/A | 探針缺失 = 開發未完成 |
| checker 問題必寫進報告 | 口頭回應不算 | 不可「已修」不記錄 |
| 任一問題最多 20 次循環 | 用戶延長可放寬 | 超過則中斷、回報用戶 |
| dev 領取後必更新 backlog 狀態 | N/A | 避免「兩個 dev 搶任務」|
| 純文字引用（v2.1）| skill 子檔可用 markdown | 不寫 `../` 或 `docs/` 跨檔連結 |
| 不可繞過校驗 | 用戶指定可跳過 | 預設 Gate 4 必跑 |
| **Module 邊界即測試邊界**（v2.2 新增）| Module 邊界未定義時 fallback 到「整個 repo」 | 探針不得跨 Module 檢查 |
| **dev 改檔不得跨 Module**（v2.2 新增）| 需跨 Module = 升級為新任務、不在原 Module 循環內處理 | 避免 Module 閃連修改 |
| **探針必含 Module 標註**（v2.2 新增）| Module 未定義時可省略 prefix | 探針名稱必含 Module 代碼（如 `M01-user-login-returns-correct-data`）|

## Module 感知邏輯（v2.2 新增）

dev-checker-loop v2.2 起支援 **Module 級派工**。Module 定義在 `docs/system-design.md`，由 dav-designer 產出。

**核心規則**（詳見 [`module-rules.md`](./module-rules.md)）：

1. **派工綁 Module**：dev 領任務時必綁 Module；同 Module 順序、不同 Module 平行
2. **改檔不得跨 Module**：需跨 Module = 升級為新任務
3. **探針必含 Module prefix**：`M01-user-login-returns-correct-data`；CI 用 `REGRESSION_MODULE=M01` 限定
4. **校驗限 Module 內**：跨 Module issue 標記、升級

**Fallback**：讀不到 system-design.md Module 章節 → 整個 repo 視為單一 Module（`M00`）。

## 核心角色

| 角色 | 職責 |
|------|------|
| **dev** | 領取任務 → 依 DESIGN.md / system-design.md / PRD 開發 → 保留探針 → 標記「等待校驗」 |
| **checker** | 監控 backlog → 發現「等待校驗」→ 全面校驗 → 問題記錄 → dev 自動修復 |

## 循環終止條件

| 條件 | 說明 |
|------|------|
| **用戶手動終止** | 由用戶決定何時停止 |
| **所有任務完成** | backlog 為空且所有狀態為「已完成」 |
| **循環上限** | 任一問題超過 20 次循環仍未解決則中斷 |

## 變動歷史

完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)。本檔僅保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 9：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |

---
---

**交叉引用（純文字）**：
- 工作流程詳解 → 同套本 skill 子檔（`./workflow.md`）
- regression-guard 探針規則 → 見同套 regression-guard skill（需同套安裝）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
