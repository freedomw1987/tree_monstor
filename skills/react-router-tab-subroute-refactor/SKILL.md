---
name: react-router-tab-subroute-refactor
description: Consolidate multiple top-level pages into one URL-prefix with N child sub-routes + a shared tab-nav layout. React Router v6/v7 + shadcn Tabs (Radix) + Tailwind. Use when "wrap X, Y, Z into tabs", "settings has too many nav links", "sub-route tab navigation", or refactoring an admin page cluster.
trigger: "wrap multiple pages into tabs / sub-route tab nav / consolidate admin pages / settings has too many nav links / 一個 URL 切換多個 sub-page"
category: frontend
---


Last-verified: 2026-07-28
# React Router Sub-Route Tab Refactor

Pattern for: N sibling pages (Users / Roles / AI / Tax / Audit …) at
top-level URLs (`/users`, `/roles`, …) → consolidate into one prefix
(`/settings/*`) with a tab-nav layout that wraps an `<Outlet />`.

Why: deep linking, browser back/forward, and "open in new tab" all
work because the **URL is the source of truth** (not component state).
Step-down in Day 11 / Day 14 crm-system: `/users`, `/roles`, `/audit`,
`/ai-config`, `/man-day-roles` → 7 sub-tabs under `/settings/*`.

## When to use

- 3+ top-level pages share an admin/system/management context
- They should be reachable as `/parent/child1`, `/parent/child2`, …
- The user wants a tab strip (not a sidebar, not a dropdown)
- Each child is independent (no cross-tab state) and has its own route
- You have `@radix-ui/react-tabs` (or shadcn `Tabs`) in deps

## When NOT to use

- Pages have very different layouts (e.g. Dashboard + a settings
  cluster) → keep top-level
- 2 pages only → not worth a layout file, just use a NavLink row
- Cross-tab state is required (e.g. wizard-style) → use a single
  page with controlled state, not sub-routes
- Mobile-first design where 7 tabs would overflow → consider
  a select / drawer instead

## Recipe (6 steps, in order)

### 1. Install shadcn Tabs (if missing)

```bash
# shadcn CLI
npx shadcn@latest add tabs

# OR hand-write (if @radix-ui/react-tabs is already in package.json):
# src/components/ui/tabs.tsx — copy the shadcn Tabs wrapper, ~50 lines
# (Tabs / TabsList / TabsTrigger / TabsContent around Radix primitives)
```

**Pitfall**: Don't `npx shadcn@latest add tabs` blindly — check
`package.json` first. If `@radix-ui/react-tabs` is already there,
just write the wrapper. The shadcn CLI is a copy-paste generator,
not magic.

### 2. Create the layout component

```tsx
// components/<parent>-layout.tsx
import { useCallback } from 'react';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

const TABS = [
  { value: 'tab-a', label: 'Tab A' },
  { value: 'tab-b', label: 'Tab B' },
  // ...
] as const;
type TabValue = (typeof TABS)[number]['value'];

export function ParentLayout() {
  const location = useLocation();
  const navigate = useNavigate();
  const currentTab: TabValue = (() => {
    const m = location.pathname.match(/^\/parent\/([^/]+)/);
    const seg = m?.[1];
    return TABS.some((t) => t.value === seg) ? (seg as TabValue) : TABS[0].value;
  })();
  return (
    <div className="space-y-6">
      {/* Header + Tabs chrome */}
      <Tabs value={currentTab} onValueChange={(v) => navigate(`/parent/${v}`)}>
        <TabsList>
          {TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>{t.label}</TabsTrigger>
          ))}
        </TabsList>
      </Tabs>
      <Outlet />
    </div>
  );
}
```

**Critical: TabsTrigger + onClick, NOT NavLink inside Tabs.**
Radix `<Tabs>` in controlled mode requires `<TabsTrigger value=…>`
children that match the active value; mixing `<NavLink>` triggers
Radix console warnings about missing triggers. The trade-off:
`<TabsTrigger>` is a `<button>`, so middle-click "open in new tab"
doesn't work on the tab strip. Acceptable because deep links from
bookmarks / chat / email still hit the right sub-route directly.

### 3. Update `App.tsx` (or router config)

```tsx
// 1) Add the layout at the parent prefix
<Route path="/parent" element={<ParentLayout />}>
  <Route path="tab-a" element={<TabAPage />} />
  <Route path="tab-b" element={<TabBPage />} />
  {/* ... */}
</Route>

// 2) Redirect any legacy /parent direct route
<Route path="/parent" element={<Navigate to="/parent/tab-a" replace />} />
```

**Critical: legacy direct-route redirect.** If the old top-level URL
was `/users` and the new entry is `/settings/users`, the old route
becomes `<Navigate to="/settings/users" replace />` so bookmarks
don't 404.

### 4. Audit for double chrome (the most-missed pitfall)

**If the original top-level page had its own header + tab strip,
removing it is Step 4 — NOT a later step.** The original page
(`/settings` = `SettingsPage` in crm-system) had:

```tsx
<div>
  <h1>系統設置</h1>
  <p>description</p>
</div>
<div className="border-b flex gap-1">
  <button>Pipeline</button>  {/* old tab strip */}
  <button disabled>Tax rate</button>
</div>
```

After the refactor, `<SettingsLayout />` renders the same header
+ TabList. **If the inner page still renders its own header + tab
strip, the user sees them twice.** Always audit and remove.

**Rule**: any page becoming a child of a tab layout must lose
its own page header + any local tab strip / nav row.

### 5. Wrap existing pages as children (or keep as-is for incremental)

**Incremental approach** (recommended for > 3 tabs):
- Step N: 1-2 real tabs + the rest as `<Placeholder step="Step N+2" />`
- Step N+1: fill 2 more
- Step N+2: fill the last

This lets the layout ship before all children are written, so the
tab nav is testable independently.

```tsx
<Route path="tax" element={
  <SettingsTabPlaceholder
    title="Tax Rate"
    description="…"
    step="Step 7" />
} />
```

### 6. Verify

```bash
bunx tsc --noEmit          # 0 errors
# Manual / browser smoke (per SOUL.md 紅線 10):
#   1. /parent → redirects to /parent/tab-a, tab "Tab A" highlighted
#   2. Click Tab B → URL is /parent/tab-b, Tab B highlighted
#   3. Browser back → /parent/tab-a
#   4. Hard reload on /parent/tab-b → Tab B is the active tab
#   5. No "double header" — original page's h1 + tab strip are gone
```

## Sub-route conflict pre-check (the silent killer)

React Router v6/v7 picks the **most-specific** path when multiple
routes match. So if you have BOTH:

```tsx
<Route path="/settings" element={<SettingsPage />} />              {/* legacy */}
<Route path="/settings" element={<SettingsLayout />}>              {/* new */}
  <Route path="users" element={…} />
</Route>
```

The exact match `/settings` → `SettingsPage`; the prefix match
`/settings/users` → `SettingsLayout > UsersPage`. **This works
without conflict.** But once you change `/settings` to
`<Navigate to="/settings/users" />`, the Navigate fires
immediately, no double-mount risk.

If you keep the legacy direct route AND want the new tabs to be
the chrome for it: you're fighting the router. Just redirect.

## Anti-patterns

- ❌ **NavLink inside a controlled `<Tabs>`.** Radix will warn,
  and the active state will desync on browser back.
- ❌ **Forgetting to remove the page's inner header + tab strip.**
  Causes double chrome (the silent Step 12 smoke-test failure).
- ❌ **Using `?tab=users` query-string instead of `/settings/users`.**
  Loses deep-link clarity and breaks back/forward ergonomics.
- ❌ **Putting the Tabs inside each child page instead of the
  layout.** Means each page re-renders the whole TabsList; URL
  syncing is per-page, easy to drift.
- ❌ **Adding `useMatch` for active detection when `useLocation`
  + regex is enough.** `useMatch` returns null for the parent
  path (matches only leaves), so the regex approach is simpler.

## Worked example (2026-06-07, crm-system Step 6)

5 top-level pages (`/users`, `/roles`, `/ai-config`, `/man-day-roles`,
`/audit`) + 1 new (`/settings/tax`) + 1 existing (`/settings` Pipeline)
→ 7 tabs under `/settings/*`.

Files touched (4):
- `components/ui/tabs.tsx` (new) — shadcn Tabs wrapper
- `components/settings-layout.tsx` (Step 5 stub → Step 6 full)
- `App.tsx` — legacy `/settings` → Navigate, 7 child routes
- `pages/settings.tsx` — removed inner header + button-tab strip

Commit: `72e13a2`, 4 files / +158 −46. TS tsc 0 errors. Browser
smoke deferred to Step 12 (final integration step).

Plan-execution deviation: Plan JSON said "保留 `/settings` legacy
direct route" but that was incompatible with "7-tab nav lives at
`/settings`". Picked deviation: `/settings` → `<Navigate>` to
`/settings/pipelines`. Documented in code comment + commit body
+ report. See `dev-task-memory/references/plan-execution-deviation-protocol.md`.

## Related

- `dev-task-memory/SKILL.md` — resume workflow (state file surfaces
  this skill on the next day)
- `dev-task-memory/references/plan-execution-deviation-protocol.md` —
  handling the plan-contradiction case
- `bun-elysia-react-vite-stack` — project bootstrap pattern that
  produces the `<Tabs>` / `<Card>` / `<Button>` / `<Input>` shadcn
  primitives this skill consumes
- SOUL.md 紅線 10 — "冇 user-visible UI = 冇做", audit step 4
  (double chrome) is the Step 12 failure mode
