# Module Lifecycle Example — 電商付款 Module（M02）

> **本目錄用途**：示範一個 Module 從「設計 → 規劃 → 派工 → 驗證 → 交付」的完整生命週期。
>
> 本範例是一個**虛構電商**的 `M02-payment` Module；目的是展示 SOP 5 階段在單 Module 上的完整應用，**不是真實運行的代碼**。
>
> 適用對象：想看 dav-designer / dav-planner / dev-checker-loop / regression-guard / dav-submitter 5 個 skill 怎麼在真實專案協作的開發者 / Agent。

## 為什麼要做這個範例

- **連環 SOP 的價值只在完整流程中顯現**：每個 skill 看起來獨立（v2.6 Module 切割 / v2.2 Module 派工 / v2.10 Module 探針 / v2.2 Module 交付），但**只有走完一輪才看得到** 5 個 skill 是怎麼「無縫對接」
- **Learn-by-doing**：光看 skill 主檔會覺得抽象；本範例讓你看到具體的 system-design.md / backlog.md / 探針 / deliverable.md 應該長怎樣
- **基準測試**：未來新增 / 修改 skill 時，可以拿本範例當「驗證素材」，看新 skill 對一個完整 Module 流程是否有效

## 5 階段檔案對應

| SOP 階段 | 範例檔案 | 對應 skill | 預期效果 |
| --- | --- | --- | --- |
| **§2.2 設計** | [`docs/system-design.md`](./docs/system-design.md) | dav-designer v2.6 | 看到 Module 切割 + 邊界怎麼定義 |
| **§2.1 規劃** | [`docs/backlog.md`](./docs/backlog.md) | dav-planner v2.3 | 看到 backlog 表格 Module 欄位 + Module 級 sprint |
| **§2.3 執行（Gate 1-3）** | [`probes/`](./probes/) | regression-guard v2.10 | 看到 Module prefix 探針怎麼寫 + `REGRESSION_MODULE` 怎麼用 |
| **§2.3 執行（Gate 4）** | [`checklist.md`](./checklist.md) | dev-checker-loop v2.2 | 看到 Module 級派工 / Module 內校驗 / 不得跨 Module 改檔 |
| **§2.5 交付** | [`deliverable-sample.md`](./deliverable-sample.md) | dav-submitter v2.2 | 看到 Module 級交付語法 + §9 Module 級總結 |

## 範例專案簡介：電商付款 Module（M02）

**業務場景**：用戶在結帳頁選擇信用卡付款 → 跳轉到第三方付款閘道（Stripe mock） → 回呼更新訂單狀態。

**Module 邊界**：

```
M02-payment
├── src/
│   ├── payment/           # 核心付款邏輯
│   ├── payment-gateway/   # 第三方閘道 adapter
│   └── payment.test.ts    # Module 內測試
└── NOT include:           # 跨 Module
    ├── src/order/         # → M03-order
    └── src/user-auth/     # → M01-user-auth
```

**2 個核心 US**：

| US ID | Module | 標題 | 優先級 |
| --- | --- | --- | --- |
| M02-US-201 | M02 | 信用卡付款 | P0 |
| M02-US-202 | M02 | 付款回呼更新訂單 | P0 |
| INT-M01-M02-01 | INT | 登入後付款（跨 Module） | P0 |

## 怎麼用本範例

1. **從頭讀**：依序讀 `docs/system-design.md` → `docs/backlog.md` → `probes/` → `checklist.md` → `deliverable-sample.md`，感受 5 階段的連貫性
2. **拿來驗證 skill**：用某個 skill 跑本範例的對應階段，看 skill 輸出和範例輸出的差距
3. **複製起點**：複製本目錄到新 repo、改成自己的業務，從範例的骨架開始設計 Module

## 檔案結構

```
module-lifecycle/
├── README.md                    # 本檔
├── docs/
│   ├── system-design.md         # dav-designer 產出：Module 切割 + 邊界
│   ├── backlog.md               # dav-planner 產出：含 Module 欄位
│   └── ac-templates.md          # AC 範本（Given-When-Then）
├── probes/
│   ├── M02-credit-card-payment.test.ts    # Module 探針範例
│   ├── M02-payment-callback.test.ts
│   └── INT-M01-M02-checkout.test.ts       # 跨 Module 整合探針
├── checklist.md                 # dev-checker-loop Gate 4 檢查清單
└── deliverable-sample.md        # dav-submitter v2.2 Module 級交付範例
```

## 為什麼本範例只展示骨架

本範例**不是完整的可運行程式碼**：

- **沒有真實框架**：src/ 是空的，因為本範例只展示**SOP 5 階段的文件產出**，不是要教你寫 TypeScript
- **沒有真實 CI**：checklist.md 是 dev-checker-loop 的產出物，但實際跑要靠 dev / checker 兩個 subagent；本範例只展示 checklist 的格式
- **沒有真實測試**：probes/ 是回歸探針的格式範例，沒有對應的 production code

如果要看**可運行**的範例，請參考 monorepo 自己的 CI（`.github/workflows/`）。

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
| --- | --- | --- | --- |
| v1.0 | 2026-09-26 | 建立 Module 範例專案骨架（5 階段對應 5 skill） | 用戶選 4 個後續任務之一；讓 SOP 5 階段有「連環展示素材」|
