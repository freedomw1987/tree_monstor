# URL-Driven Tabs (shadcn `<Tabs>` with react-router)

When the URL is the source of truth for which tab is active (e.g. `/settings/users`, `/settings/roles`), use `TabsTrigger` + `onValueChange → navigate()` instead of `NavLink` inside a controlled `<Tabs>`.

## Why not NavLink inside controlled Tabs

```tsx
// ❌ Radix warns: "Missing TabsTrigger for value X"
<Tabs value={currentTab}>
  <TabsList>
    <NavLink to="/settings/users">Users</NavLink>
    <NavLink to="/settings/roles">Roles</NavLink>
  </TabsList>
</Tabs>
```

`<Tabs>` in controlled mode expects `<TabsTrigger value="...">` children whose `value` matches the active state. Mixing NavLinks makes Radix warn about missing triggers, and the active styling won't follow the route change on browser back/forward.

## The working pattern

```tsx
import { useNavigate, useLocation } from 'react-router-dom';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

const TABS = [
  { value: 'users', label: 'Users' },
  { value: 'roles', label: 'Roles' },
  // ...
] as const;

type TabValue = (typeof TABS)[number]['value'];

function isTabValue(seg: string | undefined): seg is TabValue {
  return !!seg && (TABS.map(t => t.value) as readonly string[]).includes(seg);
}

function SettingsLayout() {
  const location = useLocation();
  const navigate = useNavigate();

  // URL → current tab
  const currentTab: TabValue = (() => {
    const m = location.pathname.match(/^\/settings\/([^/]+)/);
    const seg = m?.[1];
    return isTabValue(seg) ? seg : 'users'; // fallback
  })();

  // User click → URL change → useLocation re-derives currentTab
  const handleTabChange = (next: string) => {
    if (isTabValue(next) && next !== currentTab) {
      navigate(`/settings/${next}`);
    }
  };

  return (
    <Tabs value={currentTab} onValueChange={handleTabChange}>
      <TabsList>
        {TABS.map(t => (
          <TabsTrigger key={t.value} value={t.value}>
            {t.label}
          </TabsTrigger>
        ))}
      </TabsList>
      <Outlet />
    </Tabs>
  );
}
```

## Trade-off

`TabsTrigger` renders as a `<button>`, not an `<a>`. Middle-click "open in new tab" doesn't work on the tab nav. The URL itself is still a real URL, so:

| Action | Works? |
|--------|--------|
| Bookmark | ✅ |
| Direct navigation | ✅ |
| Right-click "Copy link" | ✅ |
| Browser back/forward | ✅ |
| Middle-click on tab button | ❌ |

For "settings-like" tabs (in-app navigation only), this is acceptable. For primary navigation, keep using `NavLink` and skip the Tabs component.

## When to use this pattern

- Sub-route tabs under a parent layout (e.g. `/settings/*`, `/admin/*`)
- Deep-linkable views (sharing a URL should land on the same tab)
- Browser back/forward should navigate between tabs

## When NOT to use this pattern

- Single-page modals or step wizards (use a state machine, not URL)
- Tabs whose state shouldn't be shareable (e.g. a "Recently viewed" tab strip)

## See also

- crm-system Day 14.7 Step 6 (commit 72e13a2) — first use of this pattern
- shadcn/ui Tabs (uses @radix-ui/react-tabs under the hood)
