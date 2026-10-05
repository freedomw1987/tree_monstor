# M02-payment Module 完整交付

> **本檔為範例**，由 dav-submitter skill v2.2 產出。展示 Module 級交付語法 + §9 Module 級總結。
>
> 對應 skill：`dav-submitter`（v2.2 加 Module 級交付語法）
>
> **交付日期**: 2026-09-26
> **對應 Backlog**: M02-US-201, M02-US-202, M02-US-203, M02-DE-301
> **Sprint / Module**: Sprint 1 / M02-payment
> **交付狀態**: ✅ 完成（Module 級交付）
>
> **本檔為範例**，由 dav-submitter skill v2.2 產出。展示 Module 級交付語法 + §9 Module 級總結。

---

## 1. 這次完成什麼

本 sprint 完整交付 M02-payment Module 的 4 個 US + 1 個 Bug 修復，建立電商信用卡付款的完整功能（建立付款單、第三方閘道整合、付款回呼、付款失敗重試）。

**關鍵成果**：

- ✅ M02-US-201：信用卡付款（建立付款單 + 呼叫第三方閘道）
- ✅ M02-US-202：付款回呼更新訂單（冪等處理）
- ✅ M02-US-203：付款失敗重試（連續 3 次失敗鎖卡）
- ✅ M02-DE-301：修正付款 timeout 沒釋放 DB connection
- ✅ 3 個 M02 探針 + 1 個 INT 探針全綠

### 1.2 為什麼做這個改動（v2.1 新增）

- **問題/脈絡**：電商 MVP 沒有付款功能，用戶無法完成交易；M04 checkout 流程卡在 M02 缺位
- **為什麼選這個解法**：
  - 為什麼 Module 切割出 M02（vs 全部塞進 M04 checkout）：dav-designer v2.6 5 條原則驗證「功能內聚 + 可獨立交付」
  - 為什麼用 event bus 通知 M03（vs 直接 import）：避免 M02 / M03 互相依賴、可獨立部署
  - 為什麼冪等處理付款回呼（vs 不處理）：第三方付款閘道會重試回呼、不冪等會重複扣款
- **成功怎麼看**：
  - M02 Module 探針全綠（3 個）+ INT 探針綠（1 個）
  - production 用戶可順利完成付款流程
  - M02 故障不連累 M01 / M03 / M04（Module 隔離生效）

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
| --- | --- |
| `src/payment/PaymentService.ts` | M02 對外 interface |
| `src/payment/PaymentServiceImpl.ts` | M02 實作（含 retry / idempotency / connection 釋放）|
| `src/payment/models/Payment.ts` | 付款單 model |
| `src/payment/models/PaymentStatus.ts` | 狀態 enum |
| `src/payment-gateway/GatewayAdapter.ts` | 第三方閘道 adapter interface |
| `src/payment-gateway/StripeAdapter.ts` | Stripe mock 實作 |
| `probes/M02-credit-card-payment.test.ts` | 3 個 Module 內探針 |
| `probes/M02-payment-callback.test.ts` | 2 個 Module 內探針（冪等 + 簽名驗證）|
| `probes/INT-M01-M02-checkout.test.ts` | 1 個跨 Module 整合探針 |

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
| --- | --- |
| `src/event-bus/index.ts` | +`payment.success` / `payment.failed` event type |
| `db/schema.sql` | +`payments` table（含 `gateway_ref` 唯一索引，支援冪等）|

### 2.3 刪除檔案（如有）

| 檔案路徑 | 刪除原因 |
| --- | --- |
| `src/legacy/old-payment.ts` | M02 舊版（重構成 Module 邊界內乾淨版本）|

### 2.4 改動背後的理由（v2.1 新增）

| 改動 | 為什麼這樣設計 | 放棄的選項 |
| --- | --- | --- |
| **PaymentService 用 interface 對外** | 易測試（M04 可 mock）、易替換（換閘道不影響）、易演進（內部 refactor 不影響外部）| 對外暴露 class（M04 會 import 整個 class，耦合度高；測試難）|
| **冪等處理付款回呼** | 第三方付款閘道會重試回呼（網路不穩）、不冪等會重複扣款（商業災難）| 用 transaction 處理（無法保證跨 process 冪等；用 unique index 是更強保證）|
| **DB connection 在 finally 釋放** | 高併發下 timeout 會堆積 connection、最終 crash（DE-301 的根因）| 用 middleware 釋放（不好寫、跨 function 時容易漏；finally 是顯而易見的釋放點）|
| **event bus 而非直接 import M03** | M02 不應該依賴 M03 內部；event bus 讓 M03 故障不影響 M02 | 直接 `import { OrderModel } from 'src/order'`（破壞 Module 邊界、測試時要 mock M03）|

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
| --- | --- | --- | --- |
| M02-US-201 AC-1 | 有效信用卡建立付款單 | ✅ | `M02-create-payment-returns-success-on-valid-card` 探針 |
| M02-US-201 AC-2 | 第三方成功後更新訂單為 PAID | ✅ | INT 探針 `INT-M01-M02-checkout-full-flow` |
| M02-US-201 AC-3 | Timeout 釋放 DB connection | ✅ | `M02-payment-timeout-releases-db-connection` 探針 |
| M02-US-202 AC-2 | 同一 callback 重複 3 次結果冪等 | ✅ | `M02-payment-callback-is-idempotent` 探針 |
| M02-US-203 AC-2 | 連續失敗 3 次鎖卡 | ✅ | `M02-payment-retry-blocks-after-3-failures` 探針 |
| M02-DE-301 | DB connection 釋放 | ✅ | 壓力測試 + `M02-payment-timeout-releases-db-connection` 探針 |
| INT-M01-M02-01 AC-1 | 登入後付款完整流程 | ✅ | INT 探針 |

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
| --- | --- | --- |
| M02 單元測試 | 5 / 5 | 全綠 |
| M02 整合測試（Module 內）| 3 / 3 | 全綠 |
| INT 整合測試（跨 Module）| 1 / 1 | 全綠 |
| 回歸測試（REGRESSION_MODULE=M02）| 5 / 5 | 全綠 |

## 5. 已知問題 / 限制

| 問題 | 嚴重性 | 已記錄位置 |
| --- | --- | --- |
| M02 不支援部分退款（只有全額退款）| P1 | TECH-501 backlog |
| Stripe mock 沒實作 webhook signature 真實驗證（用 hardcoded `valid_signature`）| P2 | TECH-502 backlog |
| event bus 沒實作 retry / dead letter queue（M03 消費失敗會掉訊息）| P1 | TECH-503 backlog |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **執行 Sprint 2：M03-order Module 完整交付** — 解鎖 INT-M01-M02-02（登入後付款 + 訂單歷史）
   - **為什麼這個優先**：M03 是 M02 的下游 consumer，目前 event bus 沒 retry、TECH-503 P1 問題要靠 M03 完整測試才能驗證
2. **修正 TECH-503（event bus retry / dead letter queue）** — 避免 M03 故障時 M02 訊息掉
   - **為什麼這個優先**：production 風險高、目前是 P1 已知問題

### 6.2 下一個 Sprint 考慮

- [ ] M03-order Module 完整交付（BACKLOG: M03-*）
- [ ] TECH-501（M02 部分退款）
- [ ] TECH-503（event bus retry）
- [ ] INT-M01-M02-02（登入後付款 + 訂單歷史）

### 6.3 長期方向（Think Big）

- 把 event bus 抽成獨立 Module（目前散落在各 Module 內）
- 引入 OpenTelemetry 觀測 Module 間 trace（解決 Module 邊界帶來的 debug 難度）

## 7. 相關文檔連結

- [Backlog 對應項目](./docs/backlog.md)
- [系統設計](./docs/system-design.md)
- [M02 探針](./probes/)
- [dev-checker-loop 校驗清單](./checklist.md)

## 8. 反思（Reflection 末段，v2.0 新：併入此處）

### 8.1 6 維度檢查（US 級）

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | ✅ | 付款流程錯誤訊息風格統一（M02 Module 內）|
| 2 | RWD 響應式設計 | ✅ | 不適用（M02 是後端 Module）|
| 3 | 技術債 | ⚠️ | TECH-501 / TECH-502 / TECH-503 三條已知 |
| 4 | 可維護性 | ✅ | Module 內聚度高、對外 interface 清晰 |
| 5 | 測試覆蓋率 | ✅ | 5 / 5 探針全綠、覆蓋率 ~85% |
| 6 | 需求對齊 | ✅ | 對齊 system-design.md 的 M02 職責定義 |

### 8.2 問題清單（每個 ❌ 必含「根因 + 建議」）

- ⚠️ [P1] M02 不支援部分退款 — 根因：MVP 範圍沒包含；建議：TECH-501 排入 Sprint 3
- ⚠️ [P2] Stripe mock 沒實作 webhook signature 真實驗證 — 根因：測試環境不需；建議：TECH-502 排入 Sprint 3
- ⚠️ [P1] event bus 沒 retry / dead letter queue — 根因：MVP 簡化；建議：TECH-503 立即修（P1 已知問題）

### 8.3 Action Items（每個填滿「動作 + 類型 + 驗收標準 + 預估」）

| # | 動作 | 類型 | 驗收標準 | 預估 |
| - | --- | --- | --- | --- |
| 1 | 執行 Sprint 2：M03-order 完整交付 | Sprint | M03 所有 US 完成、探針全綠 | 13 SP |
| 2 | 修 TECH-503 event bus retry | TECH | 訊息失敗 retry 3 次後入 dead letter queue | 5 SP |
| 3 | 修 TECH-501 部分退款 | TECH | 探針 `M02-partial-refund` 通過 | 8 SP |
| 4 | 修 TECH-502 Stripe signature 驗證 | TECH | 探針 `M02-stripe-signature-verification` 通過 | 3 SP |

### 8.4 Reviewer 二審結果（V03 紀律）

- Verdict：✅ PASS
- 問題數：P0=0、P1=2（已記錄在 TECH backlog）、P2=1
- 連結 Reviewer 原路徑：N/A（本 sprint 為開發任務，非 SOP 修改）

## 9. Module 級總結（v2.2 新增：Module 級交付專用）

### 9.1 多 US 間關聯

```
M02-DE-301 → M02-US-201（修完 DB connection 才能正確做付款）
M02-US-201 → M02-US-202 → M02-US-203（順序依賴）
```

4 個 US 都集中在 M02 Module 內、可單獨交付（順序或平行），INT 跨 Module 任務不在本 sprint。

### 9.2 跨 Module 遺留問題

| 問題 | 影響 | 升級為 |
| --- | --- | --- |
| INT-M01-M02-01 整合測試只驗證 happy path | 沒測跨 Module 失敗情境 | 待 Sprint 2 加入負面測試 |

### 9.3 Module 級技術債

| 技術債 | 跨 sprint | 影響範圍 |
| --- | --- | --- |
| TECH-501 部分退款 | 是 | M02 |
| TECH-502 Stripe signature 真實驗證 | 是 | M02 + INT |
| TECH-503 event bus retry | 是 | 全 repo（影響 M02 / M03 / M04）|

### 9.4 Module 級指標

| 指標 | 數值 |
| --- | --- |
| 探針總數 | 5（4 個 M02 + 1 個 INT）|
| Module 大小（LOC）| ~800 |
| 變動歷史 | 本次 sprint 第 1 版 |
| 測試覆蓋率 | ~85% |
| Module 內聚度 | 高（dav-designer 5 條原則驗證通過）|
| Module 耦合度 | 低（對外 interface、無直接 import M01 / M03）|

### 9.5 Module 級下一步

1. **Sprint 2 派 M03-order**：M03 是 M02 的下游 consumer，需先把 M03 交付完整才能驗證跨 Module 流程
2. **修 TECH-503 event bus retry**：影響全 repo，是其他 Module 的隱性風險
3. **M04 checkout 編排**：M04 需 M01 + M02 + M03 都完成後才能完整測試

---

**產生者**: Agent (透過 dav-submitter skill v2.2)
**產生時間**: 2026-09-26 12:00
