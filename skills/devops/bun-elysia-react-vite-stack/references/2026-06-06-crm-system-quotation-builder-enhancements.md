# 2026-06-06 crm-system — Quotation Builder enhancements (Day 10)

David feedback chain (兩個 user-visible bugs, 一個 server-side enhancement):

## Bug 1: Autocomplete dropdown 透底 (quick fix path)

**症狀**: Quotation Builder 加 Product/Service 嘅 autocomplete dropdown, dropdown panel 完全透明, 後面嘅 `備註` textarea + `Subtotal`/`Tax`/`Total` card 全部透出嚟。

**根因**: `apps/web/src/components/quotation-builder.tsx` 用咗 `bg-popover` class 喺 line 656 + 749 (兩個 dropdown panel), 但 `tailwind.config.js` 嘅 `theme.extend.colors` 冇 `popover` token — Tailwind JIT silently omit, 結果 `<div class="bg-popover ...">` 出嚟冇 background-color。

**David 揀咗 Path B (component-local fix)**:
```tsx
// 唔改 config, 直接喺 quotation-builder.tsx 兩個 panel 改 class
- <div className="absolute z-50 top-full mt-1 left-0 right-0 max-h-60 overflow-y-auto bg-popover border rounded shadow-lg">
+ <div className="absolute z-50 top-full mt-1 left-0 right-0 max-h-60 overflow-y-auto bg-white border border-border rounded shadow-lg">
```
`bg-white` 配 `border-border` (config 入面 `border` token 已經有) 即係白底實心, 同 shadcn `popover.DEFAULT` `hsl(0 0% 100%)` 視覺上一致。

**Patch 出嚟之後 (重要)**:
- **`bg-popover` 漏 token 會 silently 影響成個 app 嘅所有 popover / dropdown**, 不只 quotation builder。Plan 階段我同 David 確認咗將來其他位可能撞同一個 bug, 提議 grep 全部 `bg-popover` occurrence 一次。
- 同類陷阱仲有 `bg-card-foreground` / `text-popover-foreground` / `text-muted-foreground` 等。config 一漏全部 silently transparent / 顏色 fallback。

**Patch 詳細**: 見 `bun-elysia-react-vite-stack` skill 嘅「⚠️ shadcn-style token 唔可以漏」 pitfall + 「### Quick fix 路徑之後必須 grep 全部 other occurrences」section。

## Enhancement 1: Quick-create modal 升級做 full form

**David 原文**: 「最好 Quotation Builder 中的 "新增新Service" 的 modal 是可以用到 "Service 頁面" 的, 因為想加新完之後就不用去Service頁再入man day. 同理, Product也是」

**User mental model**: 「我喺 quotation 度搞掂晒呢條 line item」, 唔想 navigate 兩次。

**之前嘅 design 失敗**: `quotation-builder.tsx` 入面嘅 `QuickCreateServiceDialog` / `QuickCreateProductDialog` 兩個 inline modal 只攞 2-3 個 field:
- Service: `name` + `unitPrice` (冇 description, 冇 currency, **冇 man-day breakdown**)
- Product: `name` + `sku` + `unitPrice` (冇 description, 冇 category, 冇 currency, 冇 costPrice)

User 用完呢個 modal 之後要 navigate 去 `/services` 編輯 man-day, 或者 `/products` 加 category — 違反 single-source-of-truth 嘅精神。

**Plan**: David 揀 Plan A — 抽出共用 component, 兩個地方用 (Quotation Builder autocomplete + Services/Products page), 唔重複 code。

### Files created
1. `apps/web/src/components/quick-create-service-dialog.tsx` (242 行)
   - 對齊 `pages/services.tsx` 嘅 `CreateServiceDialog` form body
   - Inputs: name (required, pre-fill 從 `defaultName`) + description (SOW textarea) + currency (HKD/USD/CNY/EUR/GBP) + **man-day rows (add/remove, role + dayRate + days, start with ONE empty row)**
   - unitPrice **auto-calculated** = Σ(dayRate × days)
   - Submit: `servicesApi.create({ name, description, currency, unitPrice: total, manDays })`
   - On success: normalize `manDayLines` (Prisma field) → `manDays` (frontend type) before `onCreated`
2. `apps/web/src/components/quick-create-product-dialog.tsx` (237 行)
   - Inputs: name (pre-fill) + SKU (required, auto-uppercase) + description + category + currency + unitPrice (required) + costPrice (optional)
   - **Inventory / stockQuantity / lowStockThreshold 唔包入 quick-create** — 留返去 `/products` 完整 form
   - Submit: `productsApi.create({ name, sku, description, category, unitPrice, costPrice, currency })`
   - 400 error (e.g. duplicate SKU) inline display 個 backend message

### Files modified
- `apps/web/src/components/quotation-builder.tsx`: 移除本地 `QuickCreateServiceDialog` (line 797-917, ~120 行) + `QuickCreateProductDialog`, import 新共用 component。`LineItemRow` 嘅 `onCreateService: (s: Service) => void` / `onCreateProduct: (p: Product) => void` signature 不變, subagent 改動乾淨。
- `apps/web/src/pages/services.tsx`: 移除本地 `CreateServiceDialog` (line 147-305, 158 行), 改用新共用 component。File 從 305 行瘦到 148 行。

### Type contract 改動
- `LineItemRow` 嘅 `onCreate*` 簽名: 之前係 `(p: { name; unitPrice }) => Promise<Product>` / `(s: { name; unitPrice }) => Promise<Service>`, David 同意改做 `(p: Product) => void` / `(s: Service) => void` — dialog 自己 call `servicesApi.create` / `productsApi.create`, parent 淨係 update state。**好處**: 將來 quick-create 改 logic, parent 完全唔 touch。

### Backend response normalization 陷阱
Backend `POST /services` 個 Prisma include 係 `manDayLines`, 但 frontend 嘅 `Service` type 用 `manDays`. 兩個 mismatch 要喺 dialog 出口 normalize:
```typescript
const manDaysFromResponse = (created as Service & { manDayLines?: ServiceManDay[] }).manDayLines;
const normalised: Service = {
  ...created,
  manDays: created.manDays ?? manDaysFromResponse ?? [],
};
onCreated(normalised);
```
**唔做呢個 normalization 嘅後果**: `applyService` 嘅 `service.manDays` 讀出 `undefined` → `manDaySnapshot` 變空 array, quotation detail 個 SOW breakdown display `0 個 role breakdown`, David 又會問「我啲 man-day 去咗邊」。

## Subagent timeout 接管 (參考 `subagent-timeout-recovery` skill)

派 subagent 做呢個 task, 600s timeout + 63 API calls 用晒。**事後追查**: 核心 file 改動 (2 新 component + 2 file modified) 喺前 ~30 calls 完成, 之後 ~33 calls 喺 typecheck 階段反覆 fix (subagent 撞一個 type error → cast → 下一個 type error → 再 cast → 連環)。

**早期 stop 指標** (下次類似的任務):
- API calls > 50 而且 subagent 仲喺跑 `tsc --noEmit` 反覆 verify
- subagent log 顯示重複 `error TSxxxx:` > 3 個唔同 error
- 核心 file 改動已經完成 (4/4 file modified)

**呢次嘅 recovery 結果**:
- 我手動跑 `cd apps/web && bun run typecheck` → exit_code 0 ✅
- 兩個新 component 內容手動抽查完整, 包括 `ApiError` import (lib/api.ts line 18 export 咗), `Dialog` 系列 UI imports, normalize `manDayLines → manDays` 邏輯
- 總時間: 接報到 done ~5 分鐘, 比起再派 subagent (可能再撞 600s) 慳好多

**預防 rule for next delegation**:
- 「typecheck 跑一次 fail 就報告, 唔好 chase 連環 cast」
- 「用 `terminal(timeout=120)` 跑 `bun run typecheck`, 唔好 background」
- 「API calls 超過 50 主動 stop」

## Verification status (David 手動 smoke, 冇做)

- typecheck pass ✅ (bun run typecheck exit 0)
- 未做: 瀏覽器 E2E smoke (Quotation Builder → 加 Service → quick-create → 入 man-day → submit → SOW breakdown 顯示)
- 提咗 David refresh 試, 任何 bug 報返
