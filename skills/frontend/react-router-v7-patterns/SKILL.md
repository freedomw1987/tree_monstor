---
name: react-router-v7-patterns
description: |
  React Router v7 patterns and pitfalls for nested-route SPA refactors.
  Class-level lessons from 2026-06-07 crm-system Day 14.7 (Settings tabs):
  URL as source of truth, <Navigate> query string drop, Layout chrome
  double-render, controlled Tabs vs URL sync, useSearchParams + component
  reuse race. Use when refactoring top-level routes into nested sub-routes,
  building a tabbed settings/admin layout, or debugging "the URL says X
  but the page shows Y" symptoms.
trigger: |
  Building / refactoring nested-route sub-tabs (e.g. /settings/users,
  /settings/roles, ...), sub-route redirect chains, Tabs/TabList with
  state driven by URL, useSearchParams + react-router v7 component reuse,
  any "URL changed but UI didn't" bug report, backward-compat <Navigate />
  redirects in React Router v7.
category: frontend
---


Last-verified: 2026-07-28
# React Router v7 Patterns & Pitfalls

Class-level lessons from `crm-system` Day 14.7 (2026-06-07) — refactored
5 top-level admin routes into a single `/settings/*` sub-route tree with
7 tabs. Hit 4 distinct v7-specific gotchas. None of them are project-
specific — they apply to any nested-route refactor on React Router 6.4+
(data router) and v7. Patterns 5-6 fold in two sibling lessons from the
same class: sibling-route shadowing and route-param access.

## The patterns

### 1. URL is the source of truth for tab/segment UIs

**Symptom**: Tab nav with state, you click a tab, URL changes, but the
`<Tabs>` component still shows the old tab as active. Or: user opens
`/settings/users` deep link, page renders Users content but tab "Pipelines"
is highlighted.

**Root cause**: `<Tabs value={...} onValueChange={...}>` is controlled by
local state, but the active state should be derived from the URL (for
deep linking + browser back/forward).

**Pattern** (the URL drives everything):

```tsx
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

const TABS = [
  { value: 'pipelines', label: 'Pipelines' },
  { value: 'users',     label: 'Users' },
  { value: 'roles',     label: 'Roles' },
  // ...
] as const;

export function SettingsLayout() {
  const location = useLocation();
  const navigate = useNavigate();

  // Derive active from URL — not local state.
  const currentTab: string = (() => {
    const m = location.pathname.match(/^\/settings\/([^/]+)/);
    const seg = m?.[1];
    return TABS.some(t => t.value === seg) ? seg : 'pipelines';
  })();

  return (
    <Tabs value={currentTab} onValueChange={(next) => navigate(`/settings/${next}`)}>
      <TabsList>
        {TABS.map(t => (
          <TabsTrigger key={t.value} value={t.value}>{t.label}</TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
  );
}
```

**Anti-pattern** (NavLink inside controlled Tabs):
```tsx
// ❌ Radix <Tabs> in controlled mode requires <TabsTrigger value=…>
//    children that match the active `value`. Mixing NavLinks inside a
//    controlled Tabs makes Radix warn about missing triggers.
<Tabs value={currentTab}>
  {TABS.map(t => <NavLink to={`/settings/${t.value}`}>{t.label}</NavLink>)}
</Tabs>
```

The trade-off: middle-click "open in new tab" on the tab strip doesn't
work because the trigger is a `<button>`, not an `<a>`. Acceptable for
in-app nav; deep links from bookmarks/email still work via direct URL.

### 2. `<Navigate />` DROPS the query string — chain to the new URL directly

**Symptom**: Click a Link with a query string, the route has a backward-
compat `<Navigate replace to="/new-path" />`, and the destination loses
the query string. (Caught live in `crm-system` 2026-06-07, commit
`5018578`.)

```tsx
// Step 7: cross-link built assuming /audit was the canonical path
<Link to="/audit?action=SYSTEM_CONFIG_UPDATED">View audit log</Link>

// Step 8: moved /audit to /settings/audit, /audit became a <Navigate>
<Route path="/audit" element={<Navigate to="/settings/audit" replace />} />

// Result: clicking the link navigates to /settings/audit (no ?action=)
// — react-router v7 <Navigate> drops the query string by default.
```

**Fix** — point the link at the new path directly so the query string
survives the route change without a redirect:

```tsx
// ✅ Link directly to the new canonical path
<Link to="/settings/audit?action=SYSTEM_CONFIG_UPDATED">View audit log</Link>
```

**Detection signal**: any `<Link to="/old-path?...">` where `/old-path` is
now a `<Navigate />` redirect — the query string will be silently dropped.

**Workaround if you can't update the link source** (e.g. third-party URL):
use `<Navigate to="/new-path" state={location.state} />` and have the
destination component read `useLocation().state` to recover the query
string. Or rewrite the redirect to preserve the search:
```tsx
<Route path="/audit" element={
  <Navigate to={(loc) => ({ pathname: '/settings/audit', search: loc.search })} replace />
} />
```
(But fixing the link source is almost always simpler.)

### 3. Layout chrome double-render when a child page already has its own header

**Symptom**: You wrap a top-level page (`<SettingsPage />`) inside a new
Layout (`<SettingsLayout />`) that has its own header + tab strip. The
result is two h1's and two tab strips — visual mess.

**Cause**: The child page (designed for top-level rendering) already has
its own `h1` and tab nav. The new Layout adds another. Both render.

**Decision tree** when wrapping a child:

| Case | What to do |
|------|------------|
| Child's header duplicates the new Layout's header | Strip from the child; keep the child as a body-only default-export wrapper for backward compat (import in App.tsx) |
| Child's tab nav is for sub-section switching within that page (e.g. inner A/B/C tabs inside the Users page) | Keep the inner tabs — they're scoped to the child, not the parent Layout |
| Child's tab nav was the parent's entry point (e.g. Settings tabs that now live in SettingsLayout) | Strip the tab nav from the child — Layout owns it now |

**Pattern** — mark stripped content with a "Step N note" comment so
future readers don't re-add it:

```tsx
// **Day 14.7 Step 6 note**: This page is now rendered as a CHILD of
// <SettingsLayout /> at /settings/pipelines. The Layout already provides
// the page header + 7-tab nav, so the inner header + button-style tab
// strip that lived here in Day 11/12 has been removed (would otherwise
// render twice). Step 8 will extract the per-tab pages into their own
// files (settings-pipelines.tsx etc.) and this file can shrink to a
// re-export.
return (
  <div className="space-y-6">
    {/* Header + tab strip are rendered by <SettingsLayout /> (Step 6). */}
    <Card>...</Card>
  </div>
);
```

**Bonus**: bake the "Layout owns chrome" decision into a doc-level ADR
(`docs/architecture/NNNN-settings-tabbed-layout.md`) so the next refactor
on the same page knows the history.

### 4. `useSearchParams` + component-reuse race (read URL only on mount)

**Symptom**: A page uses `useState(searchParams.get('x') ?? '')` to
seed an input from the URL. First navigation: works. Subsequent
in-app navigation to the same page with a different query string: the
URL changes but the input keeps the old value.

**Root cause**: React Router v7 (and v6.4+ data router) reuses the
existing component instance for in-app navigation — it does NOT remount.
The `useState(...)` initializer runs only on the first mount. The
URL changes, but the component is still mounted with the old state.

```tsx
// ❌ Reads URL only on first mount
const [searchParams] = useSearchParams();
const [action, setAction] = useState<string>(searchParams.get('action') ?? '');
```

**Fix** — sync URL → state via `useEffect` keyed on `searchParams`:

```tsx
// ✅ Always reflects the current URL
const [searchParams] = useSearchParams();
const [action, setAction] = useState<string>(searchParams.get('action') ?? '');
useEffect(() => {
  setAction(searchParams.get('action') ?? '');
  setActorId(searchParams.get('actorId') ?? '');
  setSearch(searchParams.get('resourceId') ?? '');
}, [searchParams]);
```

**Trade-off**: the `useEffect` will fire on every URL change, even
unrelated ones (e.g. user changes another query param). For filter
forms this is fine — you WANT the inputs to mirror the URL. For
transient UI state (e.g. a modal that's open) this is wrong — use
`useState` with the URL initial value but DON'T sync back.

**Detection signal**: any `useState(searchParams.get(...))` pattern in
a page that can be navigated to from multiple in-app links. Audit
every `useSearchParams` consumer when adding a new cross-link to the
page.

### 5. Sibling route shadowing — `/x` direct route vs `/x/*` layout with the same path

**Symptom**: two `<Route>` declarations share a path (a legacy direct
route AND a new layout):

```jsx
// ❌ shadowing trap
<Route path="/settings" element={<SettingsPage />} />
<Route path="/settings" element={<SettingsLayout />}>
  <Route path="users" element={<UsersTab />} />
</Route>
```

`/settings` shows a blank `<Outlet />` (or the wrong page), `/settings/users`
may work fine, `tsc --noEmit` passes, and there's often no console error.

**Root cause**: v6/v7 picks the most-specific match, but two same-prefix
declarations make the result **declaration-order-dependent and brittle** —
swap the order and behavior flips. A layout route with no `<Route index>`
renders a blank Outlet for the exact-match URL.

**Fixes, in order of preference**:

1. **Single nested layout** — everything under one `<Route path="/settings">`
   with `<Route index>` (or a bare-path `<Navigate>` above the layout, as in
   the redirect recipe below) as the default tab. No duplicate sibling.
2. **Rename** to avoid the shared prefix entirely (`/admin/settings/...`).
3. **Order-dependent siblings only as a last resort** — keep the bare route
   BEFORE the layout, comment the invariant loudly, and browser-smoke-test
   before committing.

**Diagnosis steps**:

- Blank `<Outlet>` for `/settings/users` → parent matched, child didn't.
- Reverse the two declarations and re-test — behavior flip confirms the
  order-dependent bug.
- `useMatches()` (React DevTools) shows which routes matched in what order.
- No `<Route index>` in the layout → blank Outlet on the exact-match URL.
- A `<Route path="*">` 404 catch-all can MASK shadowing by redirecting to
  the dashboard — an unexpected dashboard redirect is a shadowing signal.

**Verification (required — TS is not a smoke test for routing)**: browser-visit
the bare path, each sub-route, hard refresh (service workers cache old JS),
and confirm in React DevTools that the layout is in the tree with the expected
Outlet child. If a handoff defers the smoke test to a later step, the handoff
doc MUST call out the routing invariant.

### 6. Route params are hooks, not props (`useParams()`)

**Symptom**: URL params (`:token`, `:email`, `:id`) are `undefined` in the
component, so API calls silently send empty values (e.g. reset-password
request body missing the token).

**Root cause**: code written in the old style expects params as props
(`function ResetPassword({ token })`). In v6/v7 route params are only
available via the hook:

```jsx
import { useParams } from 'react-router-dom';
function ResetPassword() {
  const { token } = useParams();
}
// Route stays prop-free: <Route path="/reset/:token" element={<ResetPassword />} />
```

**URL-encoded params need decoding** — an `:email` segment arrives
percent-encoded; apply `decodeURIComponent(email ?? '')` before use.

**Diagnosis when the fix "doesn't take"**:

1. Instrument fetch in the console to see what's actually sent:
   `window._fetch = window.fetch; window.fetch = (...a) => { console.log('FETCH:', a[0], a[1]?.body); return window._fetch(...a); }`
2. Confirm the deployed bundle is the new one (`dist/index.html` JS hash
   changed; compiled JS contains `useParams`).
3. Test in incognito / with "Disable cache" — stale JS is the usual reason
   a correct fix appears broken.

**Verification**: the fetch body contains the full params
(`{token: "abc123", password: "xxx"}`, not `{password: "xxx"}`).

## Decision: when to use Navigate vs re-pointing the Link

For backward compat with old bookmarks/chat-shared links, you have two
options when a top-level route becomes a sub-route:

| Approach | Pros | Cons |
|----------|------|------|
| `<Navigate replace to="/new-path" />` on the old path | Smallest change; one Route per old path | Query strings drop silently (pattern 2). If you have cross-page deep links with query strings, fix them. |
| Re-point every Link/redirect source to the new path | Query strings survive | More files to touch; risk missing one in an external doc/email |

Rule of thumb: if the old path has no query strings in any cross-link
(only the user's bookmarks), Navigate is fine. If there's at least one
`<Link to="/old?x=...">` anywhere in the codebase, either fix the
link or use the `Navigate to={(loc) => ...}` pattern to preserve
`loc.search`.

## Backward compat redirect chain (concrete recipe)

When collapsing 5 top-level routes into 1 sub-route tree:

```tsx
// App.tsx — keep the 5 old routes as <Navigate />, drop new sub-routes
// under one Layout.
<Route path="/users"        element={<Navigate to="/settings/users"        replace />} />
<Route path="/roles"        element={<Navigate to="/settings/roles"        replace />} />
<Route path="/ai-config"    element={<Navigate to="/settings/ai"           replace />} />
<Route path="/man-day-roles" element={<Navigate to="/settings/man-day"   replace />} />
<Route path="/audit"        element={<Navigate to="/settings/audit"       replace />} />

<Route path="/settings" element={<SettingsLayout />}>
  <Route path="pipelines" element={<SettingsPage />} />
  <Route path="users"     element={<UsersPage />} />
  <Route path="roles"     element={<RolesPage />} />
  <Route path="ai"        element={<AiConfigPage />} />
  <Route path="man-day"   element={<ManDayRolesPage />} />
  <Route path="tax"       element={<SettingsTaxPage />} />
  <Route path="audit"     element={<AuditPage />} />
</Route>
```

**Don't forget**: the `<Layout>` route also needs `<Route path="/settings" element={<Navigate to="/settings/pipelines" replace />} />` ABOVE it for users who bookmark `/settings` (not `/settings/anything`).

**Audit** (after committing): grep for `to="/users"`, `to="/roles"`,
`to="/audit"`, `to="/ai-config"`, `to="/man-day-roles"` in your codebase.
Each one is a `<Link>` that will hit a `<Navigate>` — verify none of
them carry query strings (or fix them per pattern 2).

## Worked example: crm-system Day 14.7 (2026-06-07)

Refactored 5 admin pages (Users / Roles / AI / Man-day / Audit) from
top-level routes into `/settings/<tab>` sub-routes under a 7-tab
SettingsLayout. Hit all 4 patterns in one feature:

1. **URL as source of truth** — Tab nav driven by `useLocation().pathname`,
   click handler calls `navigate('/settings/<tab>')`. Caught on first
   commit when Radix warned about missing triggers; switched from
   NavLink-as-trigger to TabsTrigger + onClick.

2. **Navigate drops query string** — Discovered during Step 12 E2E
   smoke. Settings → Tax → "View audit log" link pointed to
   `/audit?action=SYSTEM_CONFIG_UPDATED` but `/audit` was now a
   `<Navigate>` → query string dropped → audit page rendered unfiltered.
   Fixed in 1-line commit `5018578` (point link at `/settings/audit?action=...`).

3. **Layout chrome double-render** — `SettingsPage` (the Pipeline
   config page) had its own h1 + button-style tab strip. After wrapping
   in `SettingsLayout`, both rendered. Stripped the inner header + tab
   strip from SettingsPage; SettingsLayout now owns chrome. Step 8
   will extract the body into `settings-pipelines.tsx`.

4. **useSearchParams + component reuse race** — `AuditPage`'s
   `useState(searchParams.get('action') ?? '')` was correct on first
   mount but stale on subsequent in-app navigation. A sibling agent
   caught this and added `useEffect([searchParams])` to sync URL →
   state. Picked up that WIP in Step 7. See
   `dev-task-memory/references/subagent-wip-pickup-recipe.md` for the
   pickup recipe (this kind of cross-session WIP is a common pattern).

## Related

- `dev-task-memory` — when sibling agents leave WIP in your working
  tree (like the `useEffect` fix in pattern 4), this is the WIP-pickup
  recipe: read the diff, validate the change, don't blindly revert.
- `regression-guard` — for the "Plan doc wording vs backend wire
  shape" anti-pattern that caused the Step 5/7 wire-shape bug; the
  tab refactor itself doesn't generate regression-guard entries, but
  every `<Navigate>` redirect you add is a candidate for one if it
  ever drops a query string that mattered.
- `bun-elysia-react-vite-stack` — bootstrap a project that uses this
  pattern. The SettingsLayout in the Day 11 settings page can be
  ported directly.
