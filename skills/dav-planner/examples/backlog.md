# Backlog — 電商 M02-payment Module Sprint

> **本檔為範例**，由 dav-planner skill v2.3 產出。展示含 Module 欄位的 backlog 格式 + Module 級 sprint 規劃。
>
> 對應 skill：`dav-planner`（v2.3 加 Module 欄位範本 + Module 級 sprint）
>
> 對應模組：`M02-payment`（單 Module 完整 sprint）

---

## Backlog（Sprint 1：M02-payment 整體交付）

| US ID | 類型 | Module | 標題 | AC | 優先級 | SP | 狀態 | 依賴 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M02-US-201 | US | M02 | 信用卡付款 | 4 條 BDD | P0 | 8 | PENDING | — |
| M02-US-202 | US | M02 | 付款回呼更新訂單 | 3 條 BDD | P0 | 5 | PENDING | M02-US-201 |
| M02-US-203 | US | M02 | 付款失敗重試 | 3 條 BDD | P1 | 3 | PENDING | M02-US-201 |
| M02-DE-301 | DE | M02 | 修正付款 timeout 沒釋放 DB connection | — | P1 | 2 | PENDING | — |
| INT-M01-M02-01 | US | INT | 登入後付款完整流程 | 2 條 BDD | P0 | 5 | PENDING | M01-US-101, M02-US-201 |

**Sprint 總計**：4 個 M02 US + 1 個跨 Module INT + 1 個 M02 Bug；合計 23 SP。

---

## M02-US-201 詳細（信用卡付款）

- **對應 Module**: M02（payment）
- **負責 dev**: （派工後填入）
- **預估時間**: 8 SP
- **AC**:
  - **AC-1** (Given-When-Then): Given 用戶在結帳頁輸入有效信用卡 When 點擊付款 Then 建立付款單且呼叫第三方閘道
  - **AC-2** (Given-When-Then): Given 第三方閘道回傳成功 When 用戶等待 3 秒內 Then 訂單狀態更新為 PAID
  - **AC-3** (Given-When-Then): Given 第三方閘道 timeout When 超過 30 秒 Then 付款單狀態為 FAILED 且釋放 DB connection
  - **AC-4** (DoD): 探針 `M02-create-payment-returns-success-on-valid-card` 必通過；`REGRESSION_MODULE=M02 ./run_pipeline.sh M02-US-201` 必綠
- **依賴**: —
- **驗收方式**: 跑 `REGRESSION_MODULE=M02 ./run_pipeline.sh M02-US-201`；M02 內部所有探針全綠
- **為什麼這個優先**（dav-planner v2.3 新增）：P0 是因為這是 M02 Module 的入口；沒這個 US，M02 其他 US 無法測試；INT-M01-M02-01 也依賴它

## M02-US-202 詳細（付款回呼更新訂單）

- **對應 Module**: M02（payment）
- **負責 dev**: （派工後填入）
- **預估時間**: 5 SP
- **AC**:
  - **AC-1** (Given-When-Then): Given 第三方閘道回呼 POST 到 `/webhook/stripe` When 收到合法簽名 Then 觸發 `handleCallback` 並更新付款單狀態
  - **AC-2** (Given-When-Then): Given 同一回呼重複發送 3 次 When 處理回呼 Then 結果冪等（付款單狀態不變）
  - **AC-3** (DoD): 探針 `M02-payment-callback-is-idempotent` 必通過
- **依賴**: M02-US-201
- **驗收方式**: 跑回呼測試 + 探針全綠
- **為什麼這個優先**（dav-planner v2.3 新增）：P0 是因為沒有回呼處理，付款成功後訂單狀態不會更新；是 M02 最關鍵的「冪等性」測試

## M02-US-203 詳細（付款失敗重試）

- **對應 Module**: M02（payment）
- **負責 dev**: （派工後填入）
- **預估時間**: 3 SP
- **AC**:
  - **AC-1** (Given-When-Then): Given 用戶付款失敗 When 點擊「重試」 Then 用同一張卡再試一次
  - **AC-2** (Given-When-Then): Given 同一張卡連續失敗 3 次 When 第 3 次失敗 Then 鎖卡 1 小時
  - **AC-3** (DoD): 探針 `M02-payment-retry-blocks-after-3-failures` 必通過
- **依賴**: M02-US-201
- **驗收方式**: 跑重試探針
- **為什麼這個優先**（dav-planner v2.3 新增）：P1 是因為這是商業風險控制（避免暴力試卡），但不是 MVP 必要功能

## M02-DE-301 詳細（修正付款 timeout 沒釋放 DB connection）

- **對應 Module**: M02（payment）
- **負責 dev**: （派工後填入）
- **預估時間**: 2 SP
- **AC**:
  - **AC-1** (DoD): 探針 `M02-payment-timeout-releases-db-connection` 必通過
  - **AC-2** (DoD): regression test 在 timeout 情境下 DB pool 不會爆
- **依賴**: —
- **驗收方式**: 探針 + 壓力測試
- **為什麼這個優先**（dav-planner v2.3 新增）：P1 是因為這是已知 production 問題，不修會讓 M02 在高併發下 crash

## INT-M01-M02-01 詳細（登入後付款完整流程）

- **對應 Module**: INT（跨 M01 + M02）
- **負責 dev**: （需 2 個 dev 跨 Module 協作）
- **預估時間**: 5 SP
- **AC**:
  - **AC-1** (Given-When-Then): Given 用戶已登入且購物車有商品 When 進入結帳頁並完成付款 Then 訂單狀態變 PAID 且購物車清空
  - **AC-2** (DoD): 探針 `INT-M01-M02-checkout-full-flow` 必通過（跨 Module 整合測試）
- **依賴**: M01-US-101（用戶登入）, M02-US-201（信用卡付款）
- **驗收方式**: 跑 `REGRESSION_MODULE=INT ./run_pipeline.sh INT-M01-M02-01`
- **為什麼這個優先**（dav-planner v2.3 新增）：P0 是因為這是 user-facing 完整流程；商業價值最高；但因為跨 Module，依 dev-checker-loop v2.2 規則升級為新任務

---

## Module 級 Sprint 規劃（dav-planner v2.3 §4.3.2）

### 派工計劃

| dev | Module | 負責 US | 平行 / 順序 |
| --- | --- | --- | --- |
| dev-A | M02 | M02-US-201, M02-US-202, M02-US-203, M02-DE-301 | 順序（同 Module）|
| dev-B | INT | INT-M01-M02-01 | 順序（M02 + M01 都完成後才能開始）|

**為什麼 dev-B 等 dev-A 結束才開始**：INT-M01-M02-01 跨 Module，依 dev-checker-loop v2.2 規則，跨 Module 任務需獨立派工、不混在原 Module 循環內處理。

### regression-guard 執行計劃

```bash
# M02 內部驗證（每個 US 完成後跑）
REGRESSION_MODULE=M02 ./run_pipeline.sh M02-US-201

# M02 整體驗證（sprint 結束跑）
REGRESSION_MODULE=M02 ./run_pipeline.sh --all

# 跨 Module 整合驗證（INT 跑完後）
REGRESSION_MODULE=INT ./run_pipeline.sh INT-M01-M02-01
```

### dev-checker-loop 校驗計劃

- 每個 US 完成 → dev 標「等待校驗」→ checker 校驗 Module 內 → dev 自動修復
- 跨 Module issue（INT 任務發現）→ 升級為新任務，不在原 Module 循環內處理

### dav-submitter 交付計劃

| 完成時間 | 交付單位 | 交付檔案 |
| --- | --- | --- |
| M02-US-201 完成 | US 級 | `docs/deliverable/2026-XX-XX-m02-us-201-credit-card.md` |
| M02-US-202 完成 | US 級 | `docs/deliverable/2026-XX-XX-m02-us-202-callback.md` |
| ... | ... | ... |
| M02 全部 US 完成 | **Module 級** | `docs/deliverable/2026-XX-XX-m02-payment-module.md`（含 §9 Module 級總結）|
| INT 完成 | Module 級 | `docs/deliverable/2026-XX-XX-int-checkout-full-flow.md` |

---

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
| --- | --- | --- | --- |
| v1.0 | 2026-09-26 | 初始 Module 級 sprint（含 Module 欄位） | dav-planner v2.3 範例 |
