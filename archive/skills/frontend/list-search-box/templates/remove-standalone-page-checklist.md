# Remove Standalone Page — 3-Step Checklist

> 用戶講「menu 不用有」「拎走呢個 page」嘅時候,跟呢個 checklist 行。
> 由 pm-system 2026-06-09 拎出嚟 (拎走「全部缺陷」+ delete `BugsPage.tsx`)。

## 1. Layout.tsx 拎走 nav item

```diff
 const navItems: NavItem[] = [
   ...
-  { path: '/x', icon: SomeIcon, label: '全部 X', permissions: ['x.view'] },
   ...
 ]
```

## 2. App.tsx 拎走 route (保留 detail page route)

```diff
-import XPage from './pages/XPage'
 import XDetailPage from './pages/XDetailPage'
 ...
             <Route path="x/:id" element={<XDetailPage />} />
-            <Route path="x" element={<XPage />} />
```

**重要**: `XDetailPage` 嘅 route (`x/:id`) 必須保留。從 sub-list / 我的 X 跳過嚟仲要 work。

## 3. Delete `XPage.tsx` 死 code

```bash
cd frontend/src/pages/
rm XPage.tsx
```

**Why delete 唔 archive**: Archive 留喺 repo 變 dead code, 將來 grep 會撞。

---

## Cross-reference audit (Step 4 — 5 分鐘)

拎走 standalone page 之後, 必定 grep audit 呢啲地方:

### A. Back-link grep (XDetailPage 嘅所有 back-link 改去合理 destination)

```bash
grep -n "/x\b" frontend/src/pages/XDetailPage.tsx
```

**Default destination**: 改去「我的 X」(`/my-x`) — 從「我的」click row 入 detail, back 返「我的」最 natural。

**User-contextual destination**(進階, hold 住唔做): 用 `location.state.from` 或者 query string `?from=project` 攞 entry path, render 動態 back link。

```diff
-      navigate('/x')
+      navigate('/my-x')
```
```diff
-        <Link to="/x" className="btn-secondary inline-block">返回 X 列表</Link>
+        <Link to="/my-x" className="btn-secondary inline-block">返回 X 列表</Link>
```

### B. E2E test grep (拎走 route 會 break test)

```bash
grep -n "/x\b\|XPage" e2e/tests/*.spec.ts
```

**拎走 route 會 break**:
- `page.goto(`${FRONTEND}/x`)` 直接 break
- `test.skip` + deprecation comment 標住,**唔好默默 delete**
- 同時更新 `docs/QA-TRACKER.md`(紅線 11) + `docs/PRD.md` 標 US DEPRECATED

### C. TypeScript import cleanup

拎走 `import XPage from './pages/XPage'`, 否則 `tsc --noEmit` 會報錯 (雖然 patch tool 會 handle, 但 verify 一下)。

---

## 5 個 self-check 問題

跑 checklist 之後, 答呢 5 條問題:

1. **Layout.tsx** 嘅 nav item 拎走咗? (1 line delete)
2. **App.tsx** 嘅 route 拎走咗? `import XPage from './pages/XPage'` 同時拎走?
3. **`XPage.tsx`** 整個 file 刪咗? (唔係 archive)
4. **`XDetailPage.tsx`** 嘅 back-link 全部 updated? (grep verify)
5. **E2E tests** 引用 `/x` 嘅地方全部 `test.skip` + 標 deprecation?

5 個都係 ✓ 就 ship。如果任何一個 ✗, 即係 scope 漏咗, 唔好 ship。
