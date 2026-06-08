# 2026-06-06 crm-system — Cross-page flow entry points (Day 10+)

David 兩次都喺同一個 lesson catch 我:**backend 嘅 relation 唔等於 UI 嘅 affordance**。今次係 Company → Deal → Quotation 個 3-step flow, schema 完全 wired,但 user 由 A page 冇辦法去到 B page。

## 對應 incident 1: Day 7 polymorphic refactor (2026-06-05)

- 改咗 schema, 加咗 `/services` page, 加咗 `/roles` page, Quotation Builder 改咗揀 product/service radio
- David 即時講「我見不到有這些功能」 — 因為個 admin nav 冇 link, 個 side menu 冇 new entries
- **教訓**: Backend 改咗 ≠ user 見到。Frontend page 必須 surface 出嚟, 否則 = 冇做。
- 詳見 `polymorphic-line-items` skill 入面「⚠️ Backend-only polymorphic refactor = invisible to user」section

## 對應 incident 2: Day 10+ Company→Deal→Quotation flow (2026-06-06)

- Backend `Company → Deal` 一對多, `Deal → Quotation` 一對多, `Quotation.dealId: String?` 全部有
- David 喺 Companies page 揀公司 → 冇掣去開 deal
- 喺 Deals Kanban → 冇掣去開 / 加 quotation
- **教訓** (呢個 incident 嘅 specific lesson): 即使 page 本身有 surface (公司 detail 顯示 deals, deal card 顯示 quote count), 如果**冇 clickable entry point** 去 next step, user 仍然係 stuck

## David 揀咗嘅 fix path: Path A — 加 link, navigate 落 existing flow

**4 個 reasons 揀 Path A 而唔係 build 專用 dialog / 拆 flow**:
1. Create dialogs (DealDialog, QuotationBuilder) **已經存在**, 唔需要重複 build
2. 唔打斷 user 嘅 mental model (Sales 喺 company 落 deal, 然後 deal 落 quotation, 兩個 flow 一致)
3. URL query string 係 shareable / refresh-safe
4. 改動範圍細 (3 個 page + 1 個 component prop 對齊), risk 低

## 5 步實作 recipe (可重用)

呢個 pattern 適用於任何「A page → B page → C page」chain 入面 B 個 next-step 入口缺嘅情況。

### Step 1: 源頭 page 必須 always render section header 加 + 掣

```tsx
// ❌ 原本 — 新公司連 entry 都見唔到 (用 deals.length > 0 && 包晒)
{deals.length > 0 && (
  <Card><CardHeader><CardTitle>Deals ({deals.length})</CardTitle></CardHeader>...</Card>
)}

// ✅ 改 — 永遠 render, 冇 deal 就 show empty state + 掣
<Card>
  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
    <CardTitle>Deals ({deals.length})</CardTitle>
    <Button asChild size="sm" variant="outline">
      <Link to={`/deals?companyId=${id}`}>
        <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Deal
      </Link>
    </Button>
  </CardHeader>
  <CardContent className="p-0">
    {deals.length === 0 ? <EmptyState /> : <DealList />}
  </CardContent>
</Card>
```

### Step 2: 中間 page 接 query, auto-open dialog, pass defaultX

```tsx
import { useNavigate, useSearchParams } from 'react-router-dom';
const [searchParams, setSearchParams] = useSearchParams();
const presetCompanyId = searchParams.get('companyId') ?? undefined;

useEffect(() => {
  if (presetCompanyId) setCreateOpen(true);
}, [presetCompanyId]);

function closeCreate() {
  setCreateOpen(false);
  if (presetCompanyId) {
    const next = new URLSearchParams(searchParams);
    next.delete('companyId');
    setSearchParams(next, { replace: true });  // replace: true 避免污染 history stack
  }
}

<DealDialog
  open={createOpen}
  onOpenChange={(v) => (v ? setCreateOpen(true) : closeCreate())}
  companies={companies}
  stages={kanban?.buckets.map((b) => b.stage) ?? []}
  defaultCompanyId={presetCompanyId ?? companies[0]?.id}  // preset 優先
  onSaved={() => qc.invalidateQueries({ queryKey: ['deals-kanban'] })}
/>
```

### Step 3: Kanban card / list item 嘅 inline CTA 改成 navigate button

```tsx
function DealCard({ deal, disabled, onEdit }) {
  const navigate = useNavigate();
  const quoteCount = deal._count?.quotations ?? 0;
  return (
    <div onClick={onEdit} ...>  // 維持原本 drag-to-edit 行為
      ...
      {/* 原本係 inert text「📄 N quotation(s)」, 改成 button */}
      <button
        type="button"
        onClick={(e) => { e.stopPropagation(); navigate(`/quotations?dealId=${deal.id}`); }}
        className={quoteCount > 0
          ? 'text-muted-foreground hover:text-foreground'
          : 'text-primary font-medium'  // 0 quote 用 primary color = visual CTA
        }
      >
        <FileText className="h-3 w-3" />
        {quoteCount > 0 ? `${quoteCount} 份報價 · ＋` : '＋ 報價'}
      </button>
    </div>
  );
}
```

### Step 4: 落 page 一樣 pattern, 接 query, pass initialX 入 form/builder

```tsx
// pages/quotations.tsx
const [searchParams, setSearchParams] = useSearchParams();
const presetDealId = searchParams.get('dealId') ?? undefined;

useEffect(() => {
  if (presetDealId) setBuilderOpen(true);
}, [presetDealId]);

function closeBuilder() {
  setBuilderOpen(false);
  if (presetDealId) {
    const next = new URLSearchParams(searchParams);
    next.delete('dealId');
    setSearchParams(next, { replace: true });
  }
}

<QuotationBuilder
  initialDealId={presetDealId}  // ← 已有 prop
  onSaved={handleBuilderSaved}
  onCancel={closeBuilder}
/>
```

### Step 5: 確認 form / builder component 本身接受 `initialX` prop

```tsx
// quotation-builder.tsx 已經有呢個 prop (Day 8 加咗嘅)
interface QuotationBuilderProps {
  existing?: Quotation;
  initialDealId?: string;  // ← 啱用
  onSaved: (q: Quotation) => void;
  onCancel: () => void;
}
```

**如果 component 冇呢個 prop** — 必須加返。**唔好喺 page level hack 預填 state**, 因為 component 入面 form logic 唔識個 initial value, 會係 user submit 先知預填失敗。

## 3 個 invariant (通用, 任何 cross-page prefill)

1. **URL 係 source of truth, not state** — 用 query string 而唔係 redux / context, 因為 share-link / refresh 都要 work
2. **`useSearchParams` + `useEffect` 開 dialog + `setSearchParams replace:true` 關 dialog** — 一個 mount/close cycle 完整 round-trip
3. **preset value 優先 fallback** — `defaultCompanyId={presetCompanyId ?? companies[0]?.id}` 即係 navigate 落嚟 preset 贏, 手動 navigate 落嚟 fallback 第一個

## Warning — query string KEY 必須 match destination prop name

喺呢個 crm-system 個案, Company → Deal 傳 `?companyId=`, Deal → Quotation 傳 `?dealId=`, 因為 2 個 page 入面個 page 自身已經 support `defaultCompanyId` / `initialDealId` 兩個唔同嘅 prop 配對。

**Generic flow 入面, query string 嘅 KEY 必須 match destination page 預期接受嘅 prop name**, 例如:
- 如果 `pages/quotations.tsx` 嘅 `QuotationBuilder` 係 `initialCustomerId` 唔係 `initialDealId`, 個 query string 就要用 `?customerId=`, 唔可以照搬 `?dealId=`
- Code review 點 catch: `rg "useSearchParams|searchParams\\.get" pages/ scripts/` 對比 `lib/api.ts` 嘅 typed interface 嘅 prop 名, mismatch = silent bug

## 4-layer delivery checklist (cross-feature, 唔只 cross-page)

任何 feature 涉及多個 model / 多個 page 嘅關係,**4 個 layer 必須同 ship, 唔可以 split commit**:

1. **Schema** (Prisma model + relation + migration)
2. **Backend routes** (POST/PATCH/GET endpoint + typed client in `lib/api.ts`)
3. **Frontend pages** (新 page + `App.tsx` route + nav link)
4. **Cross-page entry points** (源 page 嘅 + 掣 + 中間 page 接 query + 落 page 接 query — 上面 5 步 recipe)

**冇 entry point (Layer 4) = Layer 1-3 對 user 嚟講完全 invisible**。"`睇唔到 = 冇做`" 鐵律, David 兩次都喺呢度 catch 我。

**冇 nav link / 冇 side menu entry = 冇做**。即使新 page 寫咗, `App.tsx` 冇 route + nav component 冇 `<NavLink>`, user 永遠去唔到。

## Detection: 點樣 audit 一個 project 嘅 cross-page flow 完整性

```bash
# 1. 攞齊所有 schema 嘅 relation
grep -E "@relation|onDelete|onUpdate" packages/db/prisma/schema.prisma | head -50

# 2. 對比 frontend 有冇 surface 任何 navigable entry point
#    (Button asChild + Link to="..." 配 query string)
rg "asChild.*Link to=" apps/web/src/

# 3. 對比 dialogs / builders 入面有冇 initial* / default* prop
rg "interface.*Props" apps/web/src/components/ | grep -E "Dialog|Builder|Form"
```

如果 step 1 有 relation, step 2 冇 entry point, step 3 冇 prop = 你撞緊呢個 lesson。**Fix 順序**: 先 step 3 (確認 component 接受 prop), 再 step 2 (page 接 query), 最後 step 1 (源 page 加 link)。

## 通用 4-step checklist (從 pattern 抽出)

| Step | 動作 | 通用 file pattern |
|------|------|------------------|
| 1 | Source page: section header 加 button navigate | `pages/<a>.tsx` 或 `pages/<a>-detail.tsx` |
| 2 | Intermediate page: 攞 `?presetId=`, auto-open create dialog, pass `defaultX` | `pages/<b>.tsx` |
| 3 | Intermediate page: close dialog strip query | `pages/<b>.tsx` `closeXxx()` helper |
| 4 | Leaf page: 攞 `?presetId=`, auto-open create/edit dialog, pass `initialX` | `pages/<c>.tsx` (例如 quotation-builder.tsx) |

每個 step 入面都要:
- typecheck pass (`bun run typecheck` exit 0)
- import 加晒 (`useSearchParams`, `useNavigate`, `Plus` icon 等)
- 唔好喺 page 級 hack 預填 state — 一律用 component 嘅 typed prop

## 對 crm-system commit history 嘅 reference

| Commit | 改咗 | 解決 |
|--------|------|------|
| `eb81f42` Day 7 polymorphic | schema + services page + roles page | Day 7 嘅 4-layer issue (冇 nav link) — 冇 fix, David 投訴過 |
| `cf40f5d` Day 9 Service/Quotation include | 修 backend include | 冇 surface new fields 喺 UI |
| `696e0f4` Day 10+ cross-page flow | company-detail + deals + quotations 接 query string | 呢個 incident 嘅 fix |

`696e0f4` 嘅 diff 統計: `+93 / -23`, 改動極細但 user-visible 改善極大 — 因為全部都係 layer 4 entry points, 唔係新功能。
