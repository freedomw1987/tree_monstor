# dev-checker-loop Checklist — M02-payment 校驗清單

> **本檔為範例**，由 dev-checker-loop skill v2.2 產出。展示 Module 級校驗清單。
>
> 對應 skill：`dev-checker-loop`（v2.2 加 Module 級派工 / Module 邊界 / Module 級校驗）
>
> 對應模組：M02-payment（M02-US-201 完成後）

---

## 校驗範圍

**M02-payment Module**：

- 包含檔案：`src/payment/*` + `src/payment-gateway/*`
- 不包含檔案：`src/user-auth/*`（M01）、`src/order/*`（M03）、`src/checkout/*`（M04）
- 本次校驗 US：M02-US-201

---

## checker 校驗清單（5 步）

### ✅ Step 1：確認派工範圍

- [ ] dev-A 已被指派 M02 Module（M02-US-201）
- [ ] dev-A 持有 Module 邊界檔案清單
- [ ] dev-A 沒有跨 Module 改檔（`git diff --stat` 確認只有 `src/payment/*` + `src/payment-gateway/*` 改動）

### ✅ Step 2：確認探針

- [ ] 探針名稱含 Module prefix（`M02-`）
- [ ] 探針檔案在 `probes/` 目錄下
- [ ] 探針可獨立運行（`REGRESSION_MODULE=M02 ./run_pipeline.sh M02-US-201`）
- [ ] 探針全綠（4 個探針：成功 / 失敗 / timeout / connection 釋放）

### ✅ Step 3：校驗功能正確性（Module 內）

- [ ] **AC-1 對應的代碼存在**：`grep -r "createPayment" src/payment/PaymentServiceImpl.ts`
- [ ] **AC-1 的探針全綠**：`M02-create-payment-returns-success-on-valid-card` ✅
- [ ] **AC-2 的代碼存在**：`grep -r "handleCallback" src/payment/PaymentServiceImpl.ts`
- [ ] **AC-3 的代碼存在**：`grep -r "finally" src/payment/PaymentServiceImpl.ts`（finally 釋放 DB connection）

### ✅ Step 4：校驗代碼品質（Module 內）

- [ ] 無 `console.log` 殘留
- [ ] 無 `TODO` / `FIXME` 在 production code
- [ ] 無 hardcoded 密鑰（Stripe API key 應在 env var）
- [ ] 函數長度 ≤ 50 行
- [ ] 檔案長度 ≤ 300 行

### ✅ Step 5：校驗 regression-guard 探針

- [ ] 探針命名具體（避免 `test1`）
- [ ] 粒度適中（每個 AC 1-2 個探針、不過粗不過細）
- [ ] 失敗時有 `suggestion` 欄位
- [ ] 探針 CI 跑得通（`run_pipeline.sh` 沒卡住）

---

## 發現的問題

### P0（必修，擋 merge）

（無）

### P1（強烈建議修）

| 問題 | 位置 | 建議 |
| --- | --- | --- |
| `PaymentServiceImpl.ts` 的 `createPayment` 函數 78 行 | src/payment/PaymentServiceImpl.ts | 拆成 `validateInput` + `createPaymentRecord` + `callGateway` 三個 private 函數 |

### P2（nice-to-have）

| 問題 | 位置 | 建議 |
| --- | --- | --- |
| 探針 `M02-create-payment-fails-on-invalid-card` 沒測試「錯誤訊息內容」 | probes/M02-credit-card-payment.test.ts | 加 `actual: err.message` 檢查訊息含「card declined」 |

---

## 跨 Module 問題（如有發現）

### INT-M01-M02-01（跨 Module 整合測試）

- [ ] 已建立 `INT-M01-M02-checkout-full-flow` 探針
- [ ] 探針在 M01 + M02 都完成後才會跑
- [ ] 失敗時不視為 M02 失敗、視為 INT 失敗 → 升級為新任務

> dev-checker-loop v2.2 規則：**跨 Module issue 標記後升級為新任務，不在原 Module 循環內處理**。

---

## 為什麼這個 checklist 對應 SOP §2.3 Gate 4（Reviewer Gate）

依 gates.json 規範，Gate 4 是 Reviewer Gate，需做以下事：

1. **確認範圍（Module 邊界）**：本 checklist Step 1 確認派工範圍、Step 3-4 校驗限 Module 內
2. **校驗探針**：本 checklist Step 5 確認探針品質
3. **標記問題分級**：本 checklist「發現的問題」段 P0/P1/P2 分級
4. **跨 Module 問題處理**：本 checklist「跨 Module 問題」段標記 + 升級為新任務

完成本 checklist 後，dev-checker-loop 才會進入 Step 4（dev 自動修復），最後跑 dav-submitter 產出 deliverable。

---

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
| --- | --- | --- | --- |
| v1.0 | 2026-09-26 | 初始 M02 Module 級校驗清單 | dev-checker-loop v2.2 範例 |
