# Dav Developer — 寫測試（TDD）

> 本檔為 `dav-developer` 的「Step 1 寫測試」子檔（取自原 `dav-developer` skill）。
> 寫測試要帶 `dav-developer` 嘅**嚴謹性**：fail-loud、紅嘅訊息要帶修復建議、禁用 watch／interactive。

## 流程（6 步）

- **1 定位 backlog**
  - 動作：讀 monorepo 對應的 backlog 檔（路徑由 monorepo 約定），找目標任務（PENDING／in_progress）
  - 為什麼：測試必對應 backlog item，避免「不知道測什麼」
  - 產出：目標 US／DE／TECH ID
  - 證據：對話有「目標 = X」
- **2 分析 AC**
  - 動作：讀每個任務的 AC（含 monorepo 對應的 AC 範本檔）
  - 為什麼：AC 是驗收條件，測試必對應 AC
  - 產出：AC 清單（含 Given／When／Then）
  - 證據：每個 AC 都有對應測試用例
- **3 識別測試點**
  - 動作：從 AC 提取可測試的功能點
  - 為什麼：避免測試過粗或漏 AC
  - 產出：測試點清單（每個 AC ≥ 1）
  - 證據：AC 數 ≤ 測試點數
- **4 選擇框架**
  - 動作：Agent 判斷項目類型（Frontend／Backend／Full-stack）並選對應框架
  - 為什麼：不同類型有最佳框架；硬編碼會誤導
  - 產出：選定框架清單（單元／集成／E2E）
  - 證據：對話有「項目類型 = X／框架 = Y」
- **5 編寫測試**
  - 動作：建測試檔，遵循 Given-When-Then
  - 為什麼：結構化測試易讀、易維護
  - 產出：測試檔（`*.test.*`／`*_test.*`／`*.spec.*`）
  - 證據：測試檔可獨立運行
- **6 放置＋更新 backlog**
  - 動作：按項目類型放對應目錄（見下方約定）；`docs/backlog.md` 標記「測試已編寫」
  - 為什麼：保持測試目錄約定、留下 audit trail
  - 產出：測試檔到位 + backlog 標記
  - 證據：backlog 對應 row 已標記

## 規則 / 例外 / 限制

- **測試先於實作（TDD）**
  - 例外：Bug 修復可後補
  - 限制：新功能必先寫測試
- **每個 AC 至少 1 個測試**
  - 例外：不可分割的 AC 可多個
  - 限制：不允許「AC 沒測試」
- **Given-When-Then 結構**
  - 例外：簡單斷言可用 assert
  - 限制：行為測試必用 BDD
- **框架由 Agent 判斷**
  - 例外：用戶明確指定時可覆蓋
  - 限制：不硬編碼
- **單元 + 集成 + E2E 三層考慮**
  - 例外：純 util 可只有單元
  - 限制：E2E 不可少於 AC 數的 20%
- **測試必能獨立運行**
  - 例外：共用 fixture 例外
  - 限制：不可有全局狀態依賴
- **純文字引用（v2.1）**
  - 例外：skill 子檔可用 markdown
  - 限制：不寫 `../` 或 `docs/` 跨檔連結

**測試結構模板**：每個測試含 Describing（測試目標）／Given（前置條件）／When（執行操作）／Then（預期結果）。

## 識別項目類型

- **入口文件**
  - Frontend：index.html, App.js, main.tsx
  - Backend：server.js, main.py, main.go
  - Full-stack：兩者都有
- **目錄結構**
  - Frontend：src/components, src/pages
  - Backend：src/controllers, src/services
  - Full-stack：兩者都有
- **依賴項**
  - Frontend：react, vue, angular
  - Backend：express, django, gin
  - Full-stack：混合
- **測試目標**
  - Frontend：UI/交互/API Mock
  - Backend：API/數據庫/業務邏輯
  - Full-stack：全部

## 與其他階段協作

- **dav-planner** → 提供 backlog 與 AC
- **本 skill Step 2** → 開發令紅變綠（見 `./develop.md`）
- **本 skill Step 4** → Reviewer 二審（見 `./review.md`）
