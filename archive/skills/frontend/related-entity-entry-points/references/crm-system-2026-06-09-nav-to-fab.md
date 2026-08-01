# crm-system 2026-06-09 — Sidebar reorder + AI → FAB

## 觸發情境

David feedback 一句鐘「Nav menu 順序變一下」+「AI Assistant 改為在右下角有一個 Fab Button」,要求:

1. **Nav 順序**:
   ```
   1. Dashboard
   2. Companies
   3. Deals
   4. Quotation
   5. Product
   6. Service
   ```
2. **AI Assistant 從 nav 抽走** → 整個 route `/ai` 仲喺度(page 唔刪),但 nav 唔再 link,改喺 viewport 右下角整個 FAB

## 點解呢個唔只係 aesthetic,係 product decision

呢個係**sidebar ↔ FAB positioning 嘅 product-level 決定**:
- 順序 = user mental model
- 邊樣嘢做 FAB = cross-cutting utility vs main workflow

**教訓**:
- 任何「Sidebar 排乜 / 乜嘢應該做 FAB」嘅 question,先問「user 嘅 mental workflow 係點」,再問「乜嘢應該 1-tap global 觸及」,最後先 code。

## 改動清單

### `apps/web/src/components/layout/app-layout.tsx`

```diff
 const navItems = [
   { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
   { to: '/companies', label: 'Companies', icon: Building2 },
-  { to: '/quotations', label: 'Quotations', icon: FileText },
-  { to: '/products', label: 'Products', icon: Package },
-  { to: '/services', label: 'Services', icon: Briefcase },
-  { to: '/deals', label: 'Deals', icon: KanbanSquare },
-  { to: '/ai', label: 'AI Assistant', icon: MessageSquare },
+  { to: '/deals', label: 'Deals', icon: KanbanSquare },
+  { to: '/quotations', label: 'Quotation', icon: FileText },
+  { to: '/products', label: 'Product', icon: Package },
+  { to: '/services', label: 'Service', icon: Briefcase },
 ];
```

**Sales funnel ordering**:
- Dashboard (overview)
- Companies (accounts)
- Deals (pipeline opportunities)
- Quotations (proposals)
- Products / Services (catalogue)

### AI Assistant → FAB (新 component `AiFab`)

```tsx
// 加喺 <AppLayout> 嘅最外層 div 入面, <main> 之外
function AiFab() {
  const navigate = useNavigate();
  const location = useLocation();
  const [showLabel, setShowLabel] = useState(false);
  // Hide on self-page
  if (location.pathname === '/ai') return null;
  return (
    <button
      type="button"
      onClick={() => navigate('/ai')}
      onMouseEnter={() => setShowLabel(true)}
      onMouseLeave={() => setShowLabel(false)}
      aria-label="開 AI Assistant"
      className={cn(
        'group fixed bottom-6 right-6 z-50',
        'h-14 w-14 rounded-full',
        'bg-primary text-primary-foreground shadow-lg hover:shadow-xl',
        'flex items-center justify-center',
        'transition-all hover:scale-105 active:scale-95',
        'focus:outline-none focus:ring-4 focus:ring-primary/30'
      )}
    >
      <span className="absolute inset-0 rounded-full bg-primary/40 animate-ping opacity-30" />
      <Sparkles className="relative h-6 w-6" />
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

**設計決策**:
- 56px (Material Design FAB spec) — thumb-friendly
- `bottom-6 right-6` = 24px margin
- `z-50` 比 main content 高但比 modal (z-100+)低
- `Sparkles` icon + primary brand color = 「AI / special」視覺讀取
- `animate-ping` pulse ring 吸睛,`opacity-30` 避免 noisy
- Hide on self-page (`/ai`) 避免 cover chat composer
- 必須 render 喺 `<main>` 之外,否則 main 嘅 `overflow-auto` clip 個 fixed position

### `App.tsx` 嘅 route **唔刪**

```tsx
<Route path="/ai" element={<AiChatPage />} />
```

**Reason**: bookmark, share link, deep-link(從 email / Slack 跳入)都要 work。Route 同 nav 係**兩層** — nav 係 UI affordance,route 係 data integrity。

## Verify 步驟

1. **Typecheck**: `cd apps/web && bun run typecheck` → 過
2. **Docker rebuild**: `docker compose up -d --build web` → built + Started
3. **HTTP smoke**: `curl http://localhost/health` → 200
4. **Bundle verify**: `curl http://localhost/ | grep -oE '/assets/[^"]+\.js'` → 攞 JS path,再 grep 個 file 確認:
   - `bottom-6 right-6` 出現 1 次(FAB)
   - `新增 Deal` / `＋ 報價` 等新 string 全部 baked-in
   - Nav order `dashboard → companies → deals → quotations → products → services`
5. **Manual UI test**: 開 browser 睇:
   - Nav 6 個項目,順序對
   - AI Assistant 唔再喺 nav
   - 右下角 56px 圓形 primary 顏色 FAB
   - Hover FAB → 「AI Assistant」tooltip slide in
   - 撳 FAB → 跳去 `/ai`
   - 喺 `/ai` 個 page → FAB 自動隱藏

## Commit

```
feat(nav): reorder to sales-funnel + add AI Assistant FAB
```

(commit `eb543fc`)

## Side lesson: FAB 同 sidebar 嘅 positioning test

| 適合 sidebar | 適合 FAB |
|---|---|
| 經常切換嘅 page (Dashboard / list) | 從任何 page 都需要 1-tap 觸及 |
| 有多個 sub-page (User / Roles / Audit 都 admin) | 經常性 quick action 唔需要 navigate |
| 屬於 mental model 嘅 hierarchy | Cross-cutting utility(AI, Help, Search, New Item) |
| 用戶需要「區分目錄」嘅 scope | 觸及 global 而非 local context |

**判斷 test**:**一個新用戶 Day 1 開個 app,佢 expect 喺 sidebar 揾到邊樣嘢?** 啲 expect 喺 sidebar 嘅就 sidebar,其他就 FAB。
