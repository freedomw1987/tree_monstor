# Layout Refactor: Strip Inner Chrome + Backward-Compat Redirects

When moving an existing page into a new layout (e.g. wrapping 5 admin pages in a tabbed SettingsLayout), three things tend to break:

## Pitfall 1: Double chrome

If the page has its own `<h1>` and tab strip, and the new layout also has one, you'll render twice. Strip the inner chrome **at the wrap step**, don't defer to a later cleanup. Examples of inner chrome to strip:

| Page-level chrome | Layout already has it? | Action |
|-------------------|------------------------|--------|
| Page `<h1>` "System Settings" | Layout has `<h1>` 系統設置 | Remove page's h1 |
| Page-level button-style tab strip | Layout has shadcn `<Tabs>` | Remove page's tab strip |
| Page-level breadcrumb | Layout has its own nav | Remove page's breadcrumb |
| Page-level "back to list" link | Layout has a TabsList as the nav | Remove page's back link |

Mark the removal in the file with a comment pointing to the wrap step (e.g. "Header + tab strip are rendered by `<SettingsLayout />` (Day 14.7 Step 6). Step 8 will extract this page's body into settings-pipelines.tsx"). The comment helps future readers understand why the inner chrome is gone and prevents them from "fixing" it back.

## Pitfall 2: Bookmarks break

When the URL changes (e.g. `/users` → `/settings/users`), existing bookmarks, chat-share links, and email links will 404. Add `<Navigate replace />` redirects from the old URLs:

```tsx
{/* Day 14.7 Step 8 — 5 admin pages moved under /settings/*.
    Top-level direct routes are now <Navigate /> backward-compat
    redirects (so existing bookmarks, chat-share links, and any
    other deep links from before today still land on the right page). */}
<Route path="/users" element={<Navigate to="/settings/users" replace />} />
<Route path="/roles" element={<Navigate to="/settings/roles" replace />} />
<Route path="/audit" element={<Navigate to="/settings/audit" replace />} />
{/* etc — one per moved route */}
```

`<Navigate replace />` (with `replace`) updates the browser history so the back button doesn't trap the user at the redirect URL.

**Don't** redirect from the *new* URL (e.g. `/settings/users` should not redirect to `/users`). The new URL is canonical; the old URL is the backward-compat shim.

**Don't** skip the `replace` prop — without it, the user's back button goes to the redirect URL, then immediately redirects forward again, which is a confusing UX loop.

## Pitfall 3: Sidebar nav still advertises the old URLs

If the sidebar nav still has 5 separate `Users / Roles / Audit / AI / Man-day` links, the user can still reach those pages (via the redirects), but the layout goal ("single System Settings entry") is undermined. Plan the sidebar collapse as a **separate commit/step** (not part of the page-wrap), so each commit has a clear responsibility:

- Commit A: wrap 5 pages in SettingsLayout + add 5 Navigate redirects (Step 8)
- Commit B: collapse 5 sidebar links into 1 System Settings entry (Step 10)

## Sidebar collapse trade-off

When collapsing 5 admin links into 1, decide which (if any) sub-feature is "high-frequency" enough to keep a 1-click path. For audit log, the trade-off was:

- Primary: 2-click path (Settings → Audit tab)
- Cross-link: Tax tab → "View audit log" link (pre-filters to `SYSTEM_CONFIG_UPDATED`)
- Direct URL: `/settings/audit` (bookmarkable)

Document the trade-off in the commit message so future reviewers understand the UX decision and don't reflexively "fix" the missing sidebar link.

## What stays untouched (the rule of least surprise)

When wrapping pages in a layout, these typically stay the same and should NOT be changed at the wrap step:

- API calls and data fetching (the page already knows its data)
- Form state and validation
- Component-specific business logic

**Save page-internal cleanup for a follow-up commit.** The wrap step should be a 1-commit, low-blast-radius change: add the layout, strip the inner chrome, add the redirects. Don't also refactor the page's data loading or rename internal components — those are separate concerns.

## See also

- crm-system Day 14.7 Step 6 (commit 72e13a2) — SettingsLayout stub + first inner-chrome strip
- crm-system Day 14.7 Step 8 (commit 8161cbd) — 5 page wrap + 5 backward-compat Navigate redirects
- crm-system Day 14.7 Step 10 (commit 6146aea) — sidebar collapse to single 系統設置 entry
