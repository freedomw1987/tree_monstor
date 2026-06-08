# crm-system 2026-06-09 — Companies → 新增 Quotation (multi-preset pattern)

## 觸發情境

David feedback 一句鐘「另外,Companies 中的Quotation 也要有一個新增Quotation的button」,要喺 company detail page 個 Quotations section header 加「+ 新增 Quotation」掣。

## 點解呢個唔只係重複之前嘅「新增 Deal」pattern

之前 deal card → quotation 嘅 `?dealId=` pattern 假設 **child 只係 1 個 preset**。但今次係:

- `Quotation` 同時 linked 兩個 parent(`Company` + `Deal`)
- 從 Company 入(冇 deal context)同從 Deal 入(有 deal context)係兩條 path
- **同一 page** (`/quotations`)要同時 support

呢個係**真實 multi-preset child page** pattern。

## 改動清單

### 1. `QuotationBuilder` 加 `initialCompanyId` prop

```diff
 interface QuotationBuilderProps {
   existing?: Quotation;
   initialDealId?: string;            // Day 7
+  initialCompanyId?: string;         // Day 10 (新加)
   onSaved: (q: Quotation) => void;
   onCancel: () => void;
 }

-export function QuotationBuilder({ existing, initialDealId, onSaved, onCancel }) {
+export function QuotationBuilder({ existing, initialDealId, initialCompanyId, onSaved, onCancel }) {
   const isEdit = !!existing;
-  const [companyId, setCompanyId] = useState(existing?.companyId ?? '');
+  // preset 優先 fallback 既有 value
+  const [companyId, setCompanyId] = useState(initialCompanyId ?? existing?.companyId ?? '');
   const [dealId, setDealId] = useState(initialDealId ?? '');
 }
```

**Mirror rule 重要**:
- Builder 個 `initialXxx` prop 永遠要對稱 — 如果已有 `initialDealId` 處理 deal preset,加 `initialCompanyId` 處理 company preset
- **唔好**靠 page 端硬塞(後者會做兩層 mapping,易錯)

### 2. `quotations.tsx` 統一讀兩個 preset

```diff
-const presetDealId = searchParams.get('dealId') ?? undefined;
+const presetDealId = searchParams.get('dealId') ?? undefined;
+const presetCompanyId = searchParams.get('companyId') ?? undefined;

 useEffect(() => {
-  if (presetDealId) setBuilderOpen(true);
-}, [presetDealId]);
+  if (presetDealId || presetCompanyId) setBuilderOpen(true);
+}, [presetDealId, presetCompanyId]);

 function closeBuilder() {
   setBuilderOpen(false);
-  if (presetDealId) {
+  if (presetDealId || presetCompanyId) {
     const next = new URLSearchParams(searchParams);
     next.delete('dealId');
+    next.delete('companyId');
     setSearchParams(next, { replace: true });
   }
 }
```

**唔好**分開兩個 useEffect / 兩個 close handler,會重複 code。

### 3. `quotations.tsx` pass 兩個 preset 入 builder

```diff
 <QuotationBuilder
   initialDealId={presetDealId}
+  initialCompanyId={presetCompanyId}
   onSaved={handleBuilderSaved}
   onCancel={closeBuilder}
 />
```

### 4. `company-detail.tsx` Quotations section 加「+ 新增 Quotation」掣

```diff
-          {/* Quotations */}
+          {/* Quotations — always render the header with a "+ 新增 Quotation"
+              entry point so Sales can quote this company from its detail
+              page even when there are no existing quotations yet. */}
           <Card>
-            <CardHeader>
+            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
               <CardTitle>Quotations ({quotations.length})</CardTitle>
+              <Button asChild size="sm" variant="outline">
+                <Link to={`/quotations?companyId=${id}`}>
+                  <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Quotation
+                </Link>
+              </Button>
             </CardHeader>
             <CardContent className="p-0">
               {quotations.length === 0 ? (
-                <p className="text-sm text-muted-foreground p-6 text-center">
+                <p className="text-sm text-muted-foreground p-6 text-center">
                   仲未有報價單 · 撳右上「新增 Quotation」開第一份
                 </p>
```

## 3 條 entry point path 而家全部接通

| 入口 | URL | Builder pre-fill |
|---|---|---|
| **Deals Kanban card** | `/quotations?dealId=Y` | deal 預填 |
| **Company detail** | `/quotations?companyId=X` | company 預填 |
| **Quotations nav / 「新報價」** | `/quotations` | (冇預填, 自己揀) |

## Verify 步驟

1. **Typecheck**: `cd apps/web && bun run typecheck` → 過
2. **Docker rebuild**: `docker compose up -d --build web` → built + Started
3. **Bundle verify**:
   ```bash
   curl http://localhost/ | grep -oE '/assets/[^"]+\.js' | head -1
   curl http://localhost/assets/index-XXX.js | grep "initialCompanyId"
   # 應該見到 1 個 match
   ```
4. **Manual UI test**: open company detail → 撳右上「+ 新增 Quotation」→ dialog 開 + 客戶 dropdown 預填

## Commit

```
feat(ux): wire Company → 新增 Quotation entry point
```

(commit `bfe0634`)

## 教訓

**當 child 同時 linked 多個 parent(例如 polymorphic relations / 多重 FK)**:
- Builder 個 `initialXxx` prop 一定要對稱
- Page 嘅 useEffect + close handler 統一處理多個 preset,**唔好**分開
- Close 嗰陣要 strip **全部** preset,避免 refresh re-open

**Audit verify**:
- 列出 entity 嘅所有 entry point URL
- 每個 URL 跑一次 audit: 撳過去會唔會 auto-open?會唔會 pre-fill 對應 field?
- 任何 entry 漏咗 affordance 即係 bug
