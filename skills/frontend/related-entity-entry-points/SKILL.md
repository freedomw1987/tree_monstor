---
name: related-entity-entry-points
description: Build the full UI flow that lets users navigate from a parent entity (Company, Deal, Order, Project) to a child entity (Deal, Quotation, LineItem, Task) and create it in place. Covers (1) detail-page "create child" buttons that always render, (2) useSearchParams-driven dialog auto-open + URL strip on close, (3) Kanban-card level actions for related counts, (4) the empty-state affordance rule, and (5) multi-preset child pages (entity linked to multiple parents). Trigger when user reports "I can see X but cannot create Y from it" or "I cannot find where to add Z" on any 1-to-many entity relationship. Class-level — covers CRM, ERP, e-commerce admin, project tools, anywhere parent-child entity UX exists.
tags: [frontend, react, entity-relation, ux, crm, sales, admin, react-router]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Related-Entity Entry Points

> **The "睇唔到 = 冇做" 鐵律 for parent → child UI flows.**
> If the backend has the relationship but the UI has no entry point, the
> user reports "I cannot do X from Y" — and the feature is effectively
> missing.

## 觸發時機

- 用戶講「我喺 X page 開唔到 Y」「喺 A 冇辦法跳去 B」「點解個 list 冇掣 add」呢類 feedback
- Schema 入面已有 `parent → child` 嘅 1-to-many 關係 (`Quotation.dealId String?` + `Deal.quotations Quotation[]`)
- 一個 entity 嘅 detail page 喺度,user 想喺度直接 add child
- 一個 Kanban / list 上面有「N 個 related items」顯示,但冇 click affordance
- 任何 cross-page 創建 flow 需要 preset 個 parent context (e.g. 從 Company 落 Deal 落 Quotation,中間要 pre-fill companyId / dealId)

## 4 個 sub-pattern (任何 SaaS 都會撞)

### Pattern 1 — Detail page 嘅 child section 永遠 render

```tsx
// ❌ ANTI-PATTERN: section 完全 hide 當冇 child
{deals.length > 0 && (
  <Card>
    <CardHeader><CardTitle>Deals ({deals.length})</CardTitle></CardHeader>
    {/* ... */}
  </Card>
)}
```

**後果**:用戶喺一間新公司完全見唔到 Deals section,冇 "+ 新增 Deal" 掣,零 affordance。David 撞過呢個 case 喺 `crm-system company-detail.tsx`(Day 9)。

```tsx
// ✅ FIX: section always render, 加 create 掣, empty state 用 hint 引導
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
    {deals.length === 0 ? (
      <p className="text-sm text-muted-foreground text-center py-8">
        暫未有 deal · 撳右上「新增 Deal」開第一個
      </p>
    ) : (
      <ul className="divide-y">{deals.map(...)}</ul>
    )}
  </CardContent>
</Card>
```

**規則**:
- Section 永遠 render,**唔好**用 `count > 0 && <Section/>` 嘅 conditional
- Header 右邊永遠有 "+ Create child" 掣(不論有冇 child)
- Empty state 用 hint text 提示點 create,唔好完全空白

### Pattern 2 — Child list page 接收 `?parentId=`,auto-open create dialog

```tsx
// /deals page 接收 ?companyId= 自動打開 create dialog 預填
import { useSearchParams } from 'react-router-dom';

export function DealsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const presetCompanyId = searchParams.get('companyId') ?? undefined;
  const [createOpen, setCreateOpen] = useState(false);

  // Auto-open on navigation
  useEffect(() => {
    if (presetCompanyId) setCreateOpen(true);
  }, [presetCompanyId]);

  // Strip query on close so refresh doesn't re-open
  function closeCreate() {
    setCreateOpen(false);
    if (presetCompanyId) {
      const next = new URLSearchParams(searchParams);
      next.delete('companyId');
      setSearchParams(next, { replace: true });
    }
  }

  return (
    <>
      <DealDialog
        open={createOpen}
        onOpenChange={(v) => (v ? setCreateOpen(true) : closeCreate())}
        companies={companies}
        defaultCompanyId={presetCompanyId ?? companies[0]?.id}
        onSaved={...}
      />
    </>
  );
}
```

**規則**:
- `useSearchParams` 攞 preset parent ID
- `useEffect` 自動 `setCreateOpen(true)` 一次
- `setSearchParams(next, { replace: true })` strip query(避免 history pollution)
- Dialog `defaultXxx` prop 食 preset — **唔好**將 dialog 開到 list page 嘅 main column,要用 `<Dialog>` modal 形式
- 對話框 (create) 嘅 `defaultCompanyId` 邏輯: `presetCompanyId ?? companies[0]?.id` (preset 優先,fallback 列表首個)

### Pattern 3 — Card-level action button

當 Kanban card / list row 顯示「📄 N quotations」呢類 related-count,**改做 clickable button**:

```tsx
// ❌ ANTI-PATTERN: 純文字,冇 affordance
{deal._count?.quotations > 0 && (
  <div className="text-[10px] text-muted-foreground">
    📄 {deal._count.quotations} quotation(s)
  </div>
)}

// ✅ FIX: button 永遠 show, navigate 去 child list page preset deal
import { FileText } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

function DealCard({ deal, onEdit }) {
  const navigate = useNavigate();
  const quoteCount = deal._count?.quotations ?? 0;
  return (
    <div onClick={() => onEdit(deal)} className="...">
      {/* ... title / value ... */}
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();  // 重要:避免 bubble 落去 card 嘅 onClick
          navigate(`/quotations?dealId=${deal.id}`);
        }}
        className={`... ${
          quoteCount > 0 ? 'text-muted-foreground' : 'text-primary font-medium'
        }`}
        title={quoteCount > 0 ? `已有 ${quoteCount} 份報價,撳再加一份` : '為此 deal 建立報價'}
      >
        <FileText className="h-3 w-3" />
        {quoteCount > 0 ? `${quoteCount} 份報價 · ＋` : '＋ 報價'}
      </button>
    </div>
  );
}
```

**規則**:
- 永遠 render(唔好 conditional hide 當 `count === 0`)
- `e.stopPropagation()` 避免 bubble 觸發 card 嘅 onClick(尤其 Kanban 入面,card 撳落去通常開 edit dialog)
- Count = 0 時用 primary color + 加粗做 CTA;Count > 0 時 muted
- Icon (`<FileText/>`) 助 affordance

### Pattern 4 — Grandchild page 接收 multi-preset, auto-open builder

```tsx
// /quotations page 同時支持 ?dealId= (從 Deal card 入) 同 ?companyId= (從 Company detail 入)
export function QuotationsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const presetDealId = searchParams.get('dealId') ?? undefined;
  const presetCompanyId = searchParams.get('companyId') ?? undefined;
  const [builderOpen, setBuilderOpen] = useState(false);

  useEffect(() => {
    if (presetDealId || presetCompanyId) setBuilderOpen(true);
  }, [presetDealId, presetCompanyId]);

  function closeBuilder() {
    setBuilderOpen(false);
    if (presetDealId || presetCompanyId) {
      const next = new URLSearchParams(searchParams);
      next.delete('dealId');
      next.delete('companyId');
      setSearchParams(next, { replace: true });
    }
  }

  return (
    <Dialog open={builderOpen} onOpenChange={(v) => (v ? setBuilderOpen(true) : closeBuilder())}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader><DialogTitle>建立新報價單</DialogTitle></DialogHeader>
        <QuotationBuilder
          initialDealId={presetDealId}
          initialCompanyId={presetCompanyId}
          onSaved={handleBuilderSaved}
          onCancel={closeBuilder}
        />
      </DialogContent>
    </Dialog>
  );
}
```

**規則**:
- Builder component 個 `initialDealId` / `initialCompanyId` prop 通常**已經有**(可能 Day 6/7 加咗,當時冇用),**但要對稱** — 加 `initialCompanyId` 對應已有 `initialDealId`
- `useEffect` 統一處理多個 preset,唔好分開
- Close 嗰陣要 strip **全部** preset,避免 refresh re-open
- 個 prop 個 useEffect seed 邏輯喺 component 入面已經 handle,page 只需要 pass through

## Pitfalls (David 撞過,後人必讀)

### 🚨 1. Empty state 唔好 hide section(鐵律 #1)

```tsx
// ❌ 致命: 新客戶 / 新 deal 完全冇 entry point
{deals.length > 0 && (
  <Card>...</Card>
)}
```

**Symptom**: 用戶 feedback「我喺呢度開唔到 deal」,debug 先發現 page source 連 section 都唔 render。
**Fix**: Always render,加 empty state hint。

### 🚨 2. Card click bubble 撞 sub-button onClick

Kanban card 通常有 `onClick={() => onEdit(deal)}` 開 edit dialog。Sub-button(quote count)嘅 onClick 一定要 `e.stopPropagation()`,否則 sub-button 撳落去會同時觸發 card edit + 跳去 child page。

```tsx
// ❌ double trigger
<button onClick={() => navigate('/quotations?dealId=' + deal.id)}>＋ 報價</button>

// ✅ stop propagation
<button onClick={(e) => {
  e.stopPropagation();
  navigate('/quotations?dealId=' + deal.id);
}}>＋ 報價</button>
```

### 🚨 3. URL preset 唔 strip → refresh re-open dialog

```tsx
// ❌ refresh 個 page 仲是會 auto-open dialog
useEffect(() => { if (presetDealId) setBuilderOpen(true); }, [presetDealId]);

// ✅ close 嗰陣 setSearchParams(..., { replace: true })
function closeBuilder() {
  setBuilderOpen(false);
  if (presetDealId) {
    const next = new URLSearchParams(searchParams);
    next.delete('dealId');
    setSearchParams(next, { replace: true });  // replace, 唔係 push
  }
}
```

`{ replace: true }` 重要,避免加 history entry 污染 back button。

### 🚨 4. Builder 個 `initialXxx` prop 已經有,但 page 冇 pass

常見情況:
- `QuotationBuilder` 已經有 `initialDealId?: string` prop(可能 Day 6/7 加咗,當時冇用)
- `quotations.tsx` page 從頭到尾寫 `<QuotationBuilder onSaved={...} onCancel={...} />`
- 用戶喺 deal page click "+ 報價" navigate 落 `/quotations?dealId=X`,dialog 打開但 deal **冇** 預填

**Fix 第一步**:`grep -n "initialDealId" quotation-builder.tsx` 確認 prop 已有,然後 page 加 `initialDealId={presetDealId}`。

### 🚨 5. `defaultCompanyId` 邏輯: preset 永遠優先

```tsx
// ❌ 個 page 寫死 companies[0]?.id, 個 preset 就 win 唔到
<DealDialog
  defaultCompanyId={companies[0]?.id}  // ← 寫死
  ...
/>

// ✅ preset 優先,fallback 列表首個
<DealDialog
  defaultCompanyId={presetCompanyId ?? companies[0]?.id}
  ...
/>
```

Reason: detail page 傳落嚟個 `?companyId=X` 一定係 user 真正想處理嗰間公司,冇理由 fallback 列表首個。

### 🚨 6. Link `asChild` pattern

`company-detail.tsx` 用 `<Button asChild>` + `<Link>` 包住,係 shadcn 標準做法,避免 button 內嵌 anchor 嘅 HTML 結構問題:

```tsx
<Button asChild size="sm" variant="outline">
  <Link to={`/deals?companyId=${id}`}>
    <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Deal
  </Link>
</Button>
```

**唔好**直接寫 `<Button onClick={() => navigate(...)}>` — 用 `<Link>` 喺 SEO、accessibility、Cmd+click 開新 tab 都 work。

### 🚨 7. Multi-preset 嘅 child page(同 page 收多個 ?parentId=)

**情境**: crm-system 嘅 `/quotations` 同時有兩個 entry point — Deal card 嘅「+ 報價」(`?dealId=Y`)同 Company detail 嘅「+ 新增 Quotation」(`?companyId=X`)。同一 page 兩種 preset。

**Anti-pattern**: 分開兩個 handler / 兩個 useEffect:

```tsx
// ❌ 雜亂, 重複
useEffect(() => { if (presetDealId) setOpen(true); }, [presetDealId]);
useEffect(() => { if (presetCompanyId) setOpen(true); }, [presetCompanyId]);
function close() {
  if (presetDealId) { /* strip dealId */ }
  if (presetCompanyId) { /* strip companyId */ }
}
```

**Fix**: 同一個 useEffect 同 close handler 同時處理多個 preset:

```tsx
// ✅ 統一
const presetDealId = searchParams.get('dealId') ?? undefined;
const presetCompanyId = searchParams.get('companyId') ?? undefined;

useEffect(() => {
  if (presetDealId || presetCompanyId) setBuilderOpen(true);
}, [presetDealId, presetCompanyId]);

function closeBuilder() {
  setBuilderOpen(false);
  if (presetDealId || presetCompanyId) {
    const next = new URLSearchParams(searchParams);
    next.delete('dealId');
    next.delete('companyId');
    setSearchParams(next, { replace: true });
  }
}
```

**Builder component** 都要 support 多個 preset prop:

```tsx
interface QuotationBuilderProps {
  initialDealId?: string;        // Day 7
  initialCompanyId?: string;     // Day 10 (新加)
  // ...
}
export function QuotationBuilder({ existing, initialDealId, initialCompanyId, ... }) {
  // preset 優先 fallback 既有 value
  const [companyId, setCompanyId] = useState(initialCompanyId ?? existing?.companyId ?? '');
  const [dealId, setDealId] = useState(initialDealId ?? '');
  // ...
}
```

**Mirror rule**: Builder 個 `initialXxx` prop 永遠要對稱 — 如果已有 `initialDealId` 處理 deal preset,加 `initialCompanyId` 處理 company preset,**唔好**靠 page 端硬塞(後者會做兩層 mapping,易錯)。

**Verify**: 列齊所有 entry point URL,跑 audit:
```
# Deal card → /quotations?dealId=Y    (preset dealId)
# Company detail → /quotations?companyId=X  (preset companyId)
# Quotations nav 「新報價」→ /quotations   (冇 preset, 自己揀)
```
每個 URL 都應該 trigger dialog auto-open 同 pre-fill 對應 field。

## Code Templates

完整 pattern code 喺:
- `templates/related-entity-entry-points-pattern.tsx` — 由 `crm-system` extract 嘅 4 pattern 全集

## 配套 references

- `references/crm-system-2026-06-06-companies-deals-quotations-flow.md` — 真實 session 入面點解 David 撞呢個問題、點樣修、同 verify 步驟
- `references/crm-system-2026-06-09-nav-to-fab.md` — Day 10 sidebar reorder + AI → FAB refactor
- `references/crm-system-2026-06-09-companies-to-quotation-shortcut.md` — Day 10 Companies → 新增 Quotation + multi-preset pattern discovery

## Audit Checklist (做完必跑)

| # | 檢查項 | 點 verify |
|---|---|---|
| 1 | Detail page 嘅 child section always render(冇 `{x.length > 0 && ...}`) | `grep "<Section"` 唔應該見到 conditional |
| 2 | Empty state 有 hint text 引導點 create | Visual inspect,或者 `grep "暫未有\|未有\|empty" page.tsx` |
| 3 | Child list page 有 `useSearchParams` 接 `?parentId=` | `grep "useSearchParams\|searchParams.get" page.tsx` |
| 4 | Sub-button (count action) 有 `e.stopPropagation()` | `grep "e.stopPropagation" page.tsx` |
| 5 | Close handler 有 `setSearchParams(..., { replace: true })` | `grep "replace: true" page.tsx` |
| 6 | Builder / create dialog 有 `initialXxx={presetXxx}` pass through | `grep "initialDealId={presetDealId\|initialCompanyId={presetCompanyId}" page.tsx` |
| 7 | Multi-preset child page:useEffect 同 close handler 統一處理多個 preset,唔分開 | `grep "presetDealId\|presetCompanyId" page.tsx` 應該都喺同一個 useEffect + closeBuilder |
| 8 | After build & deploy, fetch vite bundle 確認新 string bake 咗入 | `curl http://localhost/ \| grep "assets/.*\.js"` 然後 grep bundle 字串 |
| 9 | bun run typecheck 過 | foreground terminal |
| 10 | browser 手動行一遍 entry point navigation chain | open parent detail → 撳 create child → 撳 grandchild,confirm preset 都 work |

## 配套 skills

- `frontend/rwd-mobile-audit` — 任何 web app deliver 前嘅 mobile RWD check
- `archive/skills/case-history/crm-data-model` (archived) — Prisma schema 入面 parent-child FK 設計
- `frontend/react-router-v7-patterns` — `useParams` / `useSearchParams` 嘅 v7 quirk
- `frontend/kanban-worker`(若 future add) — Kanban drag-drop + side action 嘅 interaction

## 過去 session 教訓

- **2026-06-06 crm-system Day 10**: David feedback「喺 Companies 開唔到 Deals,喺 Deals 開唔到 Quotation」,debug 發現 detail page 用 `{deals.length > 0 && ...}` 完全 hide section,Deals Kanban card 上面個「📄 N quotation(s)」純文字冇 click affordance。Backend schema 一早已有齊 `Company → Deal → Quotation` 1-to-many chain。Fix 後 commit `696e0f4`。
- **2026-06-09 crm-system Day 10**: David feedback「Nav menu 順序變一下」+「AI Assistant 改為在右下角有一個 Fab Button」。反映出 entity-UX 嘅 5th 維度:**sidebar ↔ FAB 嘅 refactor 唔只係 aesthetic,係 product-positioning 決定**。Nav 順序由 storage-time 邏輯改做 sales-funnel 邏輯(誰先誰後 = user 嘅 mental model),AI 由 nav 抽做 FAB(why: 1 個 click 太多 steps,AI 應該 always-1-tap 喺每個 page 觸及)。詳見 `references/crm-system-2026-06-09-nav-to-fab.md`。
- **2026-06-09 crm-system Day 10**: David feedback「另外,Companies 中的Quotation 也要有一個新增Quotation的button」,發現 Quotation 同時有 `companyId` + `dealId` 兩個 FK,**同一 page** 要 support 兩個 entry point → **multi-preset child page pattern**。詳見 `references/crm-system-2026-06-09-companies-to-quotation-shortcut.md`。Fix 後 commit `bfe0634`。
- **2026-06-06 crm-system Day 11 reverse**(重要 — **推翻 P2/P3/P4 navigate pattern**,改用 P6 embedded modal):David 修正「Companies 點『新增 Deals / Quotation』唔好 navigate,直接彈 modal;Deals Card 點『+ 報價』都唔好 navigate,直接 inline QuotationBuilder」。**Lesson**:Pattern 2/3/4 嘅 `useSearchParams` + `setSearchParams` 方案**唔係 default**,只適合 user 想「去 child list page explore」嘅 case;**「user 留喺 parent 想 quick add」嘅 case 必須用 P6 embedded modal**(open useState + Dialog + preset prop)。**P6 嘅 trade-off**:Modal 內 component instance 仲喺 memory(state 可能 stale),要 ensure onCancel reset preset state;但**UX win 完全 cover** — David 嘅 mental model 係「我做完呢個 quick add 就走,唔想再 navigate 走 context」。詳見 sibling pattern 6。

---

## Sibling pattern 5 — Sidebar nav item 抽走改做 FAB

> **同 Pattern 1-4 不一樣嘅係**:呢個係 **product-level decision**(什麼應該常駐 sidebar vs 什麼應該做 floating action),唔係 **parent-child linking**。但兩者同屬「entity UX flow」umbrella,所以放埋一齊。

### 5a. Nav 順序按 mental model / workflow 排,唔按字母 / 模組

```tsx
// ❌ ANTI-PATTERN: 模組排序 (Products / Services 喺 Deal 之前,但 sales 唔 care catalogue 早過 pipeline)
const navItems = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/companies', label: 'Companies' },
  { to: '/quotations', label: 'Quotations' },  // ← 喺 deal 之前
  { to: '/products', label: 'Products' },
  { to: '/services', label: 'Services' },
  { to: '/deals', label: 'Deals' },             // ← 喺最後
  { to: '/ai', label: 'AI Assistant' },
];

// ✅ FIX: 按 user 嘅 mental workflow / 業務 funnel 排
//   Sales 嘅 mental model: 「見客戶 → 開 deal → 出報價 → 收錢」
//   所以 nav 順序應該係 funnel stage,唔係 CRUD module
const navItems = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/companies', label: 'Companies' },  // 客戶(Account)
  { to: '/deals', label: 'Deals' },          // Pipeline opportunity
  { to: '/quotations', label: 'Quotation' }, // 報價
  { to: '/products', label: 'Product' },     // Catalogue
  { to: '/services', label: 'Service' },     // Catalogue
  // AI Assistant 抽咗去 FAB, 唔再喺 nav 佔 slot
];
```

**規則**:
- 用「user mental workflow」做 nav 順序,唔用 storage / module 邏輯
- **Admin / Settings 永遠喺最後**(係 supporting function,唔係 main workflow)
- **重複 tab 嘅 related 項目(Products/Services 兩個 catalogue)放埋一齊**

### 5b. 咩 item 適合 sidebar,咩適合 FAB?

| 適合 **sidebar** | 適合 **FAB** |
|---|---|
| 經常切換嘅 page (Dashboard / list) | 從任何 page 都需要 1-tap 觸及 |
| 有多個 sub-page (User / Roles / Audit 都 admin) | 經常性 quick action 唔需要 navigate |
| 屬於 mental model 嘅 hierarchy | Cross-cutting utility(AI, Help, Search, New Item) |
| 用戶需要「區分目錄」嘅 scope | 觸及 global 而非 local context |

**判斷 test**:**一個新用戶 Day 1 開個 app,佢 expect 喺 sidebar 揾到邊樣嘢?** 啲 expect 喺 sidebar 嘅就 sidebar,其他就 FAB。

### 5c. FAB design spec (Material Design compliant)

```tsx
// /components/layout/ai-fab.tsx — 從 crm-system Day 10 抽出
import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Sparkles } from 'lucide-react';
import { cn } from '@/lib/utils';

function AiFab() {
  const navigate = useNavigate();
  const location = useLocation();
  const [showLabel, setShowLabel] = useState(false);

  // ⭐ Hide on self-page 避免 cover 主要 content
  if (location.pathname === '/ai') return null;

  return (
    <button
      type="button"
      onClick={() => navigate('/ai')}
      onMouseEnter={() => setShowLabel(true)}
      onMouseLeave={() => setShowLabel(false)}
      onFocus={() => setShowLabel(true)}
      onBlur={() => setShowLabel(false)}
      aria-label="開 AI Assistant"
      className={cn(
        // ⭐ Material Design spec: 56px circle = thumb-friendly + 唔 cover content
        'group fixed bottom-6 right-6 z-50 h-14 w-14 rounded-full',
        'bg-primary text-primary-foreground shadow-lg hover:shadow-xl',
        'flex items-center justify-center',
        // ⭐ Hover scale + active press feedback
        'transition-all hover:scale-105 active:scale-95',
        // ⭐ a11y: focus ring 4px (Tailwind focus:ring-4)
        'focus:outline-none focus:ring-4 focus:ring-primary/30'
      )}
    >
      {/* ⭐ Subtle pulse ring 吸睛但唔 noisy */}
      <span className="absolute inset-0 rounded-full bg-primary/40 animate-ping opacity-30" />
      <Sparkles className="relative h-6 w-6" />
      {/* ⭐ Tooltip label 喺 hover / focus 顯示 */}
      <span
        className={cn(
          'absolute right-full mr-3 whitespace-nowrap',
          'bg-foreground text-background text-xs font-medium px-2.5 py-1.5 rounded-md shadow-md',
          'transition-opacity',
          showLabel ? 'opacity-100' : 'opacity-0 pointer-events-none'
        )}
        aria-hidden="true"
      >
        AI Assistant
      </span>
    </button>
  );
}
```

**規則**:
- `fixed bottom-6 right-6 z-50` — Material 24px margin, z-50 比 main content 高但比 modal(z-100+)低
- 56px circle (`h-14 w-14`) — Material spec,FAB 標準
- `bg-primary` brand color + `Sparkles` icon = 「special / AI」視覺讀取
- `animate-ping` pulse ring 吸睛,`opacity-30` 避免太 noisy
- `aria-label` + `focus:ring-4` = keyboard a11y
- **Hide on self-page**: 已經喺 `/ai` 嗰陣唔 render,避免 cover chat composer

**位置**:`FAB 必須 render 喺 <main> 之外 / `<div className="min-h-screen">` 之內`,否則 main 嘅 `overflow-auto` 會 clip 個 fixed position。

### 5d. FAB 抽出嚟之後,route 仲要保留

```tsx
// App.tsx 嘅 route 唔可以刪 — 即使用戶淨係靠 FAB 入,直接 paste URL
// 都要 work
<Route path="/ai" element={<AiChatPage />} />
```

**Reason**: bookmark, share link, deep-link(從 email / Slack 跳入)都要 work。Route 同 nav 係**兩層** — nav 係 UI affordance,route 係 data integrity。

## Sibling pattern 5 — Sidebar nav item 抽走改做 FAB

> **同 Pattern 1-4 不一樣嘅係**:呢個係 **product-level decision**(什麼應該常駐 sidebar vs 什麼應該做 floating action),唔係 **parent-child linking**。但兩者同屬「entity UX flow」umbrella,所以放埋一齊。

## Sibling pattern 6 — Embedded quick-create modal(2026-06-06 David 修正)

> **David 修正訊號(2026-06-06)**:**「Companies 頁 click『新增 Deals』或『新增 Quotation』都不用 navigate 到相關 pages,彈出相關 Modal 給用戶填就是」**。
> 同樣:Deals Kanban 上面 Deal Card 嘅「新增 Quotation」button 都唔好 navigate,直接 mount `<QuotationBuilder>` modal。

**Why this matters**(原 pattern 2/3/4 嘅問題):
- 用戶 click 個 button 嘅 mental model 係「填表 → 提交 → 搞掂」,**唔係**「跳去第二個 page → 重新對齊 context → 搵 create 掣」
- 跳去 `/deals?companyId=X` 之後 user 喺 Deals page 嘅 Kanban view 入面,**有冇 child quotation count 顯示** 呢類 context 會被遮蔽
- Mobile / RWD 嘅時候 navigate 成本高(modal 同 screen 同 horizontal jump 嘅 friction 差異)
- Pattern 2/3/4 適合「我要去 child list page 一次過睇多個 + 順手 create」嘅 use case;**embedded modal 適合「我 focus 喺 parent detail,純粹想加多個 child」嘅 use case**。**兩者都係 legitimate**,要按 use case 揀。

**Compare pattern**:

| Pattern | 觸發 UX | User mental model | 用例 |
|---|---|---|---|
| **P2/P3/P4 navigate** | 撳 button → 跳去 child list page → 自動開 dialog | 「我反正都要去 child page 一次」 | Sales 週報要檢視所有 deals 嘅 quotations |
| **P6 embedded modal** | 撳 button → parent page 開 dialog overlay → 填 → 關 | 「我 focus 喺呢間公司,加多個 deal」 | 銷售跟進緊客戶 detail 時 quick add |

**P6 implementation template**(crm-system 2026-06-06 reference):

```tsx
// /pages/company-detail.tsx
import { useState } from 'react';
import { DealDialog } from '@/components/deal-dialog';
import { QuotationBuilder } from '@/components/quotation-builder';

export function CompanyDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [dealDialogOpen, setDealDialogOpen] = useState(false);
  const [quotationBuilderOpen, setQuotationBuilderOpen] = useState(false);

  return (
    <div>
      {/* ... company header ... */}

      {/* Deals section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Deals ({deals.length})</CardTitle>
          {/* ✅ Embedded modal, 唔好 navigate */}
          <Button
            size="sm"
            variant="outline"
            onClick={() => setDealDialogOpen(true)}     // ← onClick, 唔係 Link
          >
            <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Deal
          </Button>
        </CardHeader>
        {/* ... deals list ... */}
      </Card>

      <DealDialog
        open={dealDialogOpen}
        onOpenChange={setDealDialogOpen}
        defaultCompanyId={id}                          // ← preset 用 prop
        onSaved={() => queryClient.invalidateQueries(['companies', id])}
      />

      {/* Quotations section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Quotations ({quotations.length})</CardTitle>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setQuotationBuilderOpen(true)}
          >
            <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Quotation
          </Button>
        </CardHeader>
        {/* ... quotations list ... */}
      </Card>

      <Dialog open={quotationBuilderOpen} onOpenChange={setQuotationBuilderOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader><DialogTitle>建立新報價單</DialogTitle></DialogHeader>
          <QuotationBuilder
            initialCompanyId={id}                      // ← preset
            onSaved={() => queryClient.invalidateQueries(['companies', id])}
            onCancel={() => setQuotationBuilderOpen(false)}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
}
```

**DealCard 上面嘅 embedded button**(`/deals` Kanban 入面,對應 crm-system 2026-06-06 deal 內嵌 quotation):

```tsx
// /components/deal-card.tsx
function DealCard({ deal, onEdit, onAddQuotation }) {
  return (
    <div onClick={() => onEdit(deal)} className="cursor-pointer">
      {/* ... deal info ... */}

      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();                        // ← 唔好 trigger card 嘅 onEdit
          onAddQuotation(deal.id);                    // ← parent page 開 modal
        }}
        className="..."
      >
        <FileText className="h-3 w-3" /> ＋ 報價
      </button>
    </div>
  );
}

// /pages/deals.tsx (Kanban 嘅 page)
export function DealsPage() {
  const [quotationBuilderOpen, setQuotationBuilderOpen] = useState(false);
  const [quotationPresetDealId, setQuotationPresetDealId] = useState<string>();

  function openAddQuotation(dealId: string) {
    setQuotationPresetDealId(dealId);
    setQuotationBuilderOpen(true);
  }

  return (
    <>
      <KanbanBoard
        deals={deals}
        onAddQuotation={openAddQuotation}             // ← pass down handler
      />

      <Dialog open={quotationBuilderOpen} onOpenChange={setQuotationBuilderOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <QuotationBuilder
            initialDealId={quotationPresetDealId}      // ← preset
            onSaved={() => queryClient.invalidateQueries(['deals'])}
            onCancel={() => setQuotationBuilderOpen(false)}
          />
        </DialogContent>
      </Dialog>
    </>
  );
}
```

**P6 vs P2/P3/P4 揀邊個 decision tree**:

```
User click 個 button 之後...
    ↓
佢 留喺 parent page 嘅 context 仲有用嗎?
    ├─ Yes (e.g. 佢喺 company detail 睇緊 contact list, 想順手 add deal)
    │  → ✅ P6 embedded modal
    │     (preserves context, fastest path)
    │
    └─ No (e.g. 佢完咗 parent 嘅事, 想轉去 child page 一次過處理多個)
       → P2/P3/P4 navigate (URL params preset)
         (user wants list-view context, not parent context)
```

**常用 default rule**:**「user 留喺 parent 嘅時間仲有幾耐?」**
- < 30s → **P6 embedded**(佢做完 quick add 就走)
- > 30s → **P2/P3/P4 navigate**(佢會想 explore child list, single-page 對佢嚟講反而不順)

**2 個 pitfalls(P6 必須避)**:

1. **Modal 唔好 inline 喺 list 中間**:用 `<Dialog>` + `<DialogContent>` 包住,`<DialogContent>` 入面先放 component。**唔好**直接將 component 喺 list column 攤開,會撞 scroll / sticky header 問題。
2. **Modal `onCancel` 一定要 reset preset state**,避免下次打開 modal 仲殘留舊 preset:
   ```tsx
   onCancel={() => {
     setQuotationBuilderOpen(false);
     setQuotationPresetDealId(undefined);    // ← 重要
   }}
   ```

## 配套 skills / references / templates

- **Templates**:
  - `templates/related-entity-entry-points-pattern.tsx` — 4 個 entry-point patterns
  - `templates/fab-component.tsx` — 完整 FAB 模板(可改 path / icon / size)
- **References**:
  - `references/crm-system-2026-06-06-companies-deals-quotations-flow.md` — Day 10 parent-child flow fix
  - `references/crm-system-2026-06-09-nav-to-fab.md` — Day 10 sidebar ↔ FAB refactor + sales-funnel nav order
  - `references/crm-system-2026-06-09-companies-to-quotation-shortcut.md` — Day 10 multi-preset child page pattern
  - `references/crm-system-2026-06-11-embedded-modal-replaces-navigate.md` — Day 11 P6 pattern addition + reversal of P2/P3/P4 as default
