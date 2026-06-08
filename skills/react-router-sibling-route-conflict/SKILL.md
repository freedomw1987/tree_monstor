---
name: react-router-sibling-route-conflict
description: Diagnose and fix sibling route shadowing in react-router v6/v7 where a top-level path and a parent layout share the same prefix (e.g. /settings vs /settings/*). Covers the "two <Route path='/settings'>" trap, react-router v6 most-specific-match behavior, and smoke-test verification when TS passes but routing is wrong.
trigger: "two <Route path> with shared prefix / /settings vs /settings/* shadowing / sub-route not rendering / navigate to /settings shows blank layout / react-router picks wrong route / <Outlet> blank when child route exists"
version: 1
category: frontend
---

# React Router Sibling Route Conflict (v6/v7)

## Trigger Condition

Two `<Route>` elements with the same path or one being a prefix of the other:

```jsx
// BAD: shadowing trap
<Route path="/settings" element={<SettingsPage />} />
<Route path="/settings" element={<SettingsLayout />}>
  <Route path="users" element={<UsersTab />} />
  <Route path="tax" element={<TaxTab />} />
</Route>
```

Symptoms:
- `/settings` alone shows the *layout* (blank `<Outlet />`) instead of the legacy page
- `/settings/users` works fine
- TypeScript `tsc --noEmit` passes with zero errors
- Sometimes no console error at all (the "blank Outlet" is silent)

## Root Cause

**react-router v6/v7 picks the most-specific match, but two same-prefix `<Route>` declarations
make this fragile.** When you have:

1. `<Route path="/settings" element={<SettingsPage />} />` (legacy direct route)
2. `<Route path="/settings" element={<SettingsLayout />}>` (new layout)

The router walks routes in declaration order. For a URL like `/settings/users`:
- First route: matches `/settings` prefix but stops at `/users` (no `*` catch-all) → does NOT match
- Second route: matches `/settings` + nested `users` → renders

For a URL like `/settings`:
- First route: matches `/settings` exactly → renders `<SettingsPage />`
- Second route: matches `/settings` prefix but has no index → does NOT match (it requires a child)

**Result**: v6 *usually* does the right thing via most-specific match, but the behavior is order-
dependent and brittle. If you swap declaration order, blank `<Outlet />` appears. This is a
**fragile pattern** that you cannot rely on without a smoke test.

## Fix Patterns (pick one)

### Option A: Nested layout (recommended for new code)

Move everything under a single layout, no legacy duplicate:

```jsx
<Route path="/settings" element={<SettingsLayout />}>
  <Route index element={<SettingsPage />} />      {/* /settings = legacy tab */}
  <Route path="users" element={<UsersTab />} />
  <Route path="tax" element={<TaxTab />} />
  <Route path="pipelines" element={<PipelinesTab />} />
</Route>
```

Then change legacy `/settings` links to `/settings/pipelines` (or keep `/settings` as the default
tab via `<Route index>`).

### Option A2: Legacy direct route → `<Navigate>` (when you must keep a `/foo` default)

When the plan says "keep `/settings` as the legacy entry point that just renders the Pipeline
tab", you can't use `<Route index>` inside the layout (it would render alongside the 7-tab nav,
not in place of the user's old bookmark landing). Instead, make the bare path a redirect:

```jsx
{/* /settings (Pipeline config) — legacy direct route. We move the entry point
    INTO the layout at /settings/pipelines; the bare /settings now redirects
    so existing bookmarks / chat-shared links still land on Pipeline. */}
<Route path="/settings" element={<Navigate to="/settings/pipelines" replace />} />
<Route path="/settings" element={<SettingsLayout />}>
  <Route path="pipelines" element={<SettingsPage />} />
  <Route path="users" element={<UsersTab />} />
  <Route path="tax" element={<TaxTab />} />
</Route>
```

**CRITICAL: child page chrome cleanup.** When a page (e.g. `<SettingsPage />`) moves from
being a direct route (with its own `<h1>` + tab strip) to being a child of a layout that already
provides that chrome, you MUST strip the inner header / tab strip — otherwise the user sees
double UI. Common duplication:

- Page-level `<h1>` + description `<p>` → layout already has these
- Page-level "tab nav" (button strip or `<Tabs>`) → layout's `<Tabs>` is the new nav
- Page-level `<Card>` containing the section title → layout's section title covers it

Smoke-test check: visit each sub-route in browser, count how many `<h1>` / tab strips appear.
Two of the same chrome = bug.

### Option B: Order-dependent sibling (use when Option A breaks too many links)

Keep both routes, but put the more-specific one first and add explicit comments about the
invariant. **Test in browser before committing**.

```jsx
{/* ORDER MATTERS: more-specific /settings/* must come AFTER the bare /settings
    so react-router v6 most-specific match wins. Tested in browser smoke. */}
<Route path="/settings" element={<SettingsPage />} />
<Route path="/settings" element={<SettingsLayout />}>
  <Route path="users" element={<UsersTab />} />
  <Route path="tax" element={<TaxTab />} />
</Route>
```

### Option C: Avoid the conflict by renaming

Don't have `/settings` AND `/settings/*` — instead use `/admin/settings`, `/admin/settings/users`,
etc. This is the cleanest fix when refactor is acceptable.

## Diagnosis Steps

1. **Check `<Outlet>` content**: If `<SettingsLayout />` renders but `<Outlet />` is blank for
   `/settings/users`, the parent route matched but the child didn't.
2. **Check declaration order**: Reverse the two `<Route path="/settings">` and re-test — if
   behavior flips, you've confirmed the order-dependent bug.
3. **Inspect browser URL params** (DevTools → React DevTools → Router):
   - `useMatches()` shows which routes matched in what order
4. **Check for missing index route**: A layout route with no `<Route index>` shows blank Outlet
   for the exact-match URL.

## Verification (REQUIRED — TS is not enough)

After any fix:

1. **Browser smoke test all 3 cases**:
   - `GET /settings` → renders the legacy page (or default tab)
   - `GET /settings/users` → renders the Users tab inside the layout
   - `GET /settings/tax` → renders the Tax tab inside the layout
2. **Hard refresh** (Ctrl+Shift+R) to bypass any SWR/cache.
3. **Incognito mode** for cleanest test (no service worker / no cached JS).
4. **Check React DevTools → Components**: confirm `SettingsLayout` is in the tree, and `<Outlet>`
   has the expected child.

## Pitfalls

- **`tsc --noEmit` is NOT a smoke test for routing**. It passes for any valid JSX, including
  the shadowing trap. Don't claim "step done" based on TS alone.
- **Order-dependent behavior is fragile**. Future refactors that re-sort routes will silently
  break things. Always prefer Option A (nested layout) over Option B (sibling).
- **Handoff docs MUST call out routing invariants** when deferring smoke to a later step. The
  next session's agent won't know to verify.
- **Service workers can cache old JS** showing "blank Outlet" even after fix. Hard refresh.
- **`<Route path="*">` catch-all** (often used for 404) can mask a shadowing bug by redirecting
  to `/dashboard`. If you see a redirect to dashboard when you expected the layout, suspect
  shadowing.

## Related

- `react-router-v7-params-debug`: route *param* bugs (different class — params not arriving)
- `bun-elysia-react-vite-stack`: full-stack template where this pattern often appears in App.tsx
