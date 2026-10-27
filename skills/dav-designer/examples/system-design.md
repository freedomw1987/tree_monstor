# System Design — 電商付款模組設計

> **本檔為範例**，由 dav-designer skill v2.6 產出。展示 Module 切割 + 邊界定義的標準格式。
>
> 對應 skill：`dav-designer`（v2.6 加 Module 切割原則 + Module 邊界即測試邊界）
>
> 對應模組：`M02-payment`

---

## 1. 業務背景

電商平台支援多種付款方式（信用卡 / 第三方支付 / 貨到付款）。本文件聚焦 **信用卡付款** 的設計。

**核心需求**：

- 用戶在結帳頁輸入信用卡 → 點擊付款 → 系統建立付款單 → 呼叫第三方付款閘道 → 接收回呼 → 更新訂單狀態
- 需支援付款失敗重試、退款、付款超時取消

## 2. Module 切割（dav-designer v2.6 核心）

### 2.1 Module 列表

- **M01**
  - Module 名稱：user-auth
  - 職責：用戶登入、註冊、Token
  - 包含檔案：`src/user-auth/*`
- **M02**
  - Module 名稱：payment
  - 職責：付款單建立、第三方閘道 adapter、付款回呼
  - 包含檔案：`src/payment/*` + `src/payment-gateway/*`
- **M03**
  - Module 名稱：order
  - 職責：訂單 CRUD、訂單狀態流轉
  - 包含檔案：`src/order/*`
- **M04**
  - Module 名稱：checkout
  - 職責：結帳流程整合（M01 + M02 + M03 編排）
  - 包含檔案：`src/checkout/*`

### 2.2 Module 切割原則驗證（dav-designer v2.6 規範）

- **功能內聚**
  - M02 驗證：✅ M02 只負責「付款」，不含登入、不含訂單 CRUD
- **低耦合**
  - M02 驗證：✅ M02 對外暴露 `PaymentService` interface，不直接 import M03 的 Order model
- **可獨立交付**
  - M02 驗證：✅ M02 完成後可單獨上線（不需等 M03）
- **可獨立測試**
  - M02 驗證：✅ M02 內測試可用 mock 第三方閘道、不需 M01 / M03
- **粒度適中**
  - M02 驗證：✅ M02 約 800 LOC（不大不小）

### 2.3 Module 邊界（含 / 不含）

**M02 包含**：

```src
/payment/

├── PaymentService.ts           # 對外 interface
├── PaymentServiceImpl.ts       # 實作
├── models/
│   ├── Payment.ts              # 付款單 model
│   └── PaymentStatus.ts        # 狀態 enum
└── PaymentService.test.ts      # Module 內測試

src/payment-gateway/
├── GatewayAdapter.ts           # 第三方閘道 adapter
├── StripeAdapter.ts            # Stripe 實作（mock）
└── GatewayAdapter.test.ts
```

**M02 不包含（跨 Module，需透過 interface）**：

- `src/user-auth/*` → M01
- `src/order/*` → M03
- `src/checkout/*` → M04（編排者）

## 3. Module 對外 interface

```typescript
// M02 PaymentService.ts

interface PaymentService {
  createPayment(input: CreatePaymentInput): Promise<Payment>;
  getPaymentStatus(paymentId: string): Promise<PaymentStatus>;
  cancelPayment(paymentId: string): Promise<void>;
  handleCallback(callbackData: GatewayCallback): Promise<PaymentStatus>;
}
```

**M02 對外的承諾**：

- `createPayment`：30 秒內回傳付款單
- `handleCallback`：冪等（同一 callback 重複呼叫結果一致）
- 不暴露內部 Stripe 細節（封裝在 GatewayAdapter）

## 4. 跨 Module 互動

- **結帳觸發付款**
  - 來源 → 目標：M04 → M02
  - 通訊方式：function call（同步）
- **付款成功更新訂單**
  - 來源 → 目標：M02 → M03
  - 通訊方式：event bus（非同步，避免 M02 直接呼叫 M03）
- **付款需登入**
  - 來源 → 目標：M01 → M02
  - 通訊方式：token 驗證（在 M04 編排層做）

## 5. Module 級資料模型

```typescript
// M02 內部的 model

type Payment = {
  id: string;
  orderId: string;          // FK 指向 M03，但不 join
  amount: number;
  status: PaymentStatus;
  gatewayRef?: string;      // 第三方付款閘道的 reference
  createdAt: Date;
  updatedAt: Date;
};

enum PaymentStatus {
  PENDING = 'PENDING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
  REFUNDED = 'REFUNDED',
}
```

## 6. Module 級錯誤碼

- **`PAYMENT_001`**
  - 場景：付款單建立失敗（DB 錯誤）
  - HTTP 對應：500
- **`PAYMENT_002`**
  - 場景：第三方閘道 timeout
  - HTTP 對應：504
- **`PAYMENT_003`**
  - 場景：用戶取消付款
  - HTTP 對應：200 (含 cancelled 狀態)
- **`PAYMENT_004`**
  - 場景：付款單不存在
  - HTTP 對應：404

## 7. 為什麼這樣切割（dav-designer v2.6 「為什麼」溝通）

- **為什麼 M02 不包含 checkout？**
  - 理由：
    M04 checkout 係「編排者」，呼叫 M01 + M02 + M03 完成結帳。若 M02 包含 checkout：M02 嘅「付款」職責會被稀釋、測試 M02 變數增加（要 mock checkout）、M02
    無法獨立交付
  - 放棄嘅做法：把 checkout 一併放進 M02
- **為什麼 M02 用 event bus 通知 M03？**
  - 理由：
    M02 唔應該 import M03 嘅 Order model；改用 event bus → M02 / M03 可獨立部署、M03 故障時 M02 仍可運作（訊息會 retry）、介面更乾淨（M02 只 emit
    event，唔需知道誰消費）
  - 放棄嘅做法：直接 `import { OrderModel } from 'src/order'`（破壞 Module 邊界、測試時要 mock M03）
- **為什麼 M02 對外是 interface 不是 class？**
  - 理由：易測試（M04 可 mock `PaymentService`）、易替換（未來換付款閘道不影響 M04）、易演進（M02 內部 refactor 不影響外部）
  - 放棄嘅做法：對外暴露 class（M04 會 import 整個 class，耦合度高；測試難）

## 8. 變動歷史

- **v1.0**
  - 日期：2026-09-26
  - 變動：初始 Module 切割（M02-payment + M01-M04 邊界）
  - 為什麼：dav-designer v2.6 範例
