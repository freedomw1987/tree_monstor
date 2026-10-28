# Dav Developer — 工作流程（Step 1／Step 2）

> 本檔為 `dav-developer` 嘅 Step 1（寫測試）＋ Step 2（開發令紅變綠）子檔；主檔只留指標。
> 探針／回歸／Reviewer 二審 → 同套 `./probes.md`；Gate 定義 → 同套 `./gates.md`。

## §1 Step 1：寫測試（TDD，先紅）

### 1.1 流程（6 步）

- **1 定位 backlog** — 動作：讀 monorepo 對應的 backlog 檔（路徑由 monorepo 約定），找目標任務
  （PENDING／in_progress）；為什麼：測試必對應 backlog item；產出：目標 US／DE／TECH ID；證據：對話有「目標 = X」
- **2 分析 AC** — 動作：讀每個任務的 AC（含 monorepo 對應的 AC 範本檔）；為什麼：AC 是驗收條件，測試必對應 AC；
  產出：AC 清單（Given／When／Then）；證據：每個 AC 都有對應測試用例
- **3 識別測試點** — 動作：從 AC 提取可測試的功能點；為什麼：避免測試過粗或漏 AC；產出：測試點清單
  （每個 AC ≥ 1）；證據：AC 數 ≤ 測試點數
- **4 選擇框架** — 動作：Agent 判斷項目類型（Frontend／Backend／Full-stack）並選對應框架；為什麼：不同類型有最佳框架，
  硬編碼會誤導；產出：選定框架清單（單元／集成／E2E）；證據：對話有「項目類型 = X／框架 = Y」
- **5 編寫測試** — 動作：建測試檔，遵循 Given-When-Then；為什麼：結構化測試易讀、易維護；
  產出：測試檔（`*.test.*`／`*_test.*`／`*.spec.*`）；證據：測試檔可獨立運行
- **6 放置＋更新 backlog** — 動作：按項目類型放對應目錄；`docs/backlog.md` 標記「測試已編寫」；
  為什麼：保持測試目錄約定、留下 audit trail；產出：測試檔到位 + backlog 標記；證據：backlog 對應 row 已標記

### 1.2 測試結構模板

每個測試含 Describing（測試目標）／Given（前置條件）／When（執行操作）／Then（預期結果）。

### 1.3 識別項目類型

- **Frontend**：入口 `index.html`／`App.js`／`main.tsx`；目錄 `src/components`／`src/pages`；依賴 react／vue／angular；
  測試目標 UI／交互／API Mock
- **Backend**：入口 `server.js`／`main.py`／`main.go`；目錄 `src/controllers`／`src/services`；依賴 express／django／gin；
  測試目標 API／數據庫／業務邏輯
- **Full-stack**：兩者都有；依賴混合；測試目標全部

### 1.4 Step 1 規則

- **測試先於實作（TDD）** — 例外：Bug 修復可後補；限制：新功能必先寫測試
- **每個 AC 至少 1 個測試** — 例外：不可分割的 AC 可多個；限制：不允許「AC 沒測試」
- **Given-When-Then 結構** — 例外：簡單斷言可用 assert；限制：行為測試必用 BDD
- **框架由 Agent 判斷** — 例外：用戶明確指定時可覆蓋；限制：不硬編碼
- **單元 + 集成 + E2E 三層考慮** — 例外：純 util 可只有單元；限制：E2E 不可少於 AC 數的 20%
- **測試必能獨立運行** — 例外：共用 fixture 例外；限制：不可有全局狀態依賴

## §2 Step 2：開發令紅變綠（Dev-Checker Loop）

### 2.1 Dev Agent 工作流程

- **1 領取任務** — 讀 `docs/backlog.md` → 篩選狀態 `PENDING` → 揀一個（按優先級／順序）→ 更新狀態為「進行中」；
  目的：確保每個任務只被一個 dev 處理，避免衝突
- **2 開發任務** — 讀對應 Module 嘅 PRD → 按 PRD 開發 → 參照本 skill 埋入探針 → 自我測試驗證；
  目的：按規格開發，並預留測試覆蓋
- **3 標記完成** — 更新狀態為「等待校驗」；如有發現問題則改為「需修復」；目的：將任務交給 checker 品質把關
- **4 處理修復任務** — 監控 backlog → 領取「需修復」任務 → 修復並更新回「等待校驗」→ 重複直到修復或達循環上限；
  目的：持續修復直到 checker 確認通過

### 2.2 Checker Agent 工作流程

- **1 監控 Backlog** — 持續讀 `docs/backlog.md` → 篩選「等待校驗」→ 如有新任務則開始校驗
- **2 全面校驗** — 功能正確性（對照 PRD）｜代碼品質（風格／安全性／可讀性）｜測試覆蓋｜Regression 探針是否正確運行
- **3 記錄問題** — 在 backlog 新增 Defect 條目 → 原任務狀態改為「需修復」→ 循環次數遞增
- **4 通過驗收** — 所有檢查通過 → 狀態改為「已完成」→ 記錄完成時間

### 2.3 Backlog 狀態機

`PENDING` → 進行中 → 等待校驗 →（需修復 → 等待校驗）→ 已完成；循環達上限 → 已放棄

- `PENDING`（未領取）→ 進行中；進行中（dev 處理中）→ 等待校驗；等待校驗（等 checker）→ 需修復／已完成
- 需修復（checker 發現問題）→ 等待校驗；已完成（通過驗收）→ —；已放棄（循環達上限）→ —

### 2.4 循環控制

- **0** 意義：問題剛被記錄；**1-19** 意義：正常修復循環中；**20** 意義：達到上限
- **達到 20 時**：在 backlog 標記「達到循環上限」→ 通知用戶需人工介入 → 停止自動修復（該問題不再自動處理）

### 2.5 協作默契

- **Dev 不干擾 Dev** — 同一時間只有一個 dev 處理同一任務
- **Checker 客觀公正** — 嚴格按照標準檢查，不妥協
- **循環有上限** — 避免無限修復，20 次上限保護
- **記錄清晰** — 每個問題都有明確的描述和追蹤

## §3 Module 感知（v2.2）

### 3.1 Module 定義

Module 定義在 `docs/system-design.md`，由 **dav-designer** skill 產出（5 條切割原則：功能內聚／低耦合／可獨立交付／
可獨立測試／粒度適中）。4 個屬性：Module 代碼（如 `M01`）、Module 名稱（如 `user-auth`）、包含檔案（如 `src/auth/*.ts`）、
Module 職責（如 認證／付款／訂單）。

### 3.2 Module 取得流程

1. dev Subagent 讀 `docs/system-design.md` 拿到 Module 列表（代碼 + 檔案 glob + 職責）
2. dev 領任務時對應到 Module（從 backlog.md 的「Module」欄位）
3. dev 開發時只動該 Module 的檔案（用 grep 過濾）
4. 探針跑時用 `REGRESSION_MODULE=M01` 限定

### 3.3 Module 未定義時 Fallback

- 讀 `docs/system-design.md` 找不到 Module 章節 → 整個 repo 視為單一 Module（fallback）
- 視為「Module = 整個 repo」，其他規則照樣適用（邊界 = repo 根目錄）
- 建議同時請 dav-designer 補上 Module 定義（下次設計時改）

### 3.4 為什麼要 Module 感知

平行化加速（一個 repo 多 Module 可同時派工）｜錯誤範圍隔離（壞一 Module 唔連累全 repo）｜
測試邊界清楚（跨 Module integration test 屬「跨 Module 任務」獨立處理）｜為下游鋪路（Module 由「設計紙」變「執行單位」）。

## §4 jev 整合（可選；Jev Oracle 本體在同套 `dav-jev-oracle` skill）

- **可用性偵測** — `jev-use` 唔喺 PATH → `JEV_AVAILABLE=false`，跳過 jev 步驟、降級為純 LLM 工作流程、**不 fail-fast**
- **校驗前快篩** — `JEV_AVAILABLE=true` 且 Module 檔案數 ≥ 5 → 用 `jev_judge` 批次評分可疑點
  （`noul`／`choice`／`score` 三類混合）找高風險點優先查；**只係輔助，不取代主動校驗**
- **校驗後驗證** — `JEV_AVAILABLE=true` → 用 `jev_judge`（`noul` 類型）驗證「校驗結論有冇遺漏風險」
- **escalate 處理** — `escalate: true`（信心不足）→ 標 ⚠️ 待確認 → 寫進校驗報告「⚠️ jev escalate 待確認」段 →
  **不在對話中自己猜答案**、等用戶最終確認

### jev 6 條規則

- **jev 軟性降級** — 例外：N/A；限制：`jev-use` 未安裝時跳過 jev 步驟、繼續原本工作、不中斷流程
- **jev escalate 降級為人類決策** — 例外：N/A；限制：信心不足時標 ⚠️ 待確認、寫進校驗報告段、不自己猜
- **jev 不取代主動校驗** — 例外：N/A；限制：jev 只能輔助；主動校驗仍必跑、不可省略
- **小 Module 跳過校驗前快篩**（輕量路徑 S2） — 例外：大 Module（≥5 檔）才觸發；限制：避免小任務過度 API call 成本
- **jev 內部失敗 fallback**（S3） — 例外：N/A；限制：內部錯誤（API key／網路／拋例外）視同不可用、走軟性降級、不 fail-fast
- **M-Step 3 必跑探針** — 例外：純錯字修正；限制：改檔後必跑 `bats tests/` 全綠
