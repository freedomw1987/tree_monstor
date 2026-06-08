---
name: frontend-backend-integration
description: Discipline for writing frontend code that wraps backend endpoints — verify wire shape against backend source (not plan/spec doc), handle prefill races, refactor pages into tabbed layouts without double chrome, wire URL-driven Tabs.
trigger: "writing a new API client wrapper / refactoring a page into a tabbed layout / pre-filling a form from a network call / collapsing sidebar nav / when a Plan doc and the actual backend disagree on field names / 'add a Settings tab' / 'move pages into a layout'"
version: 1
category: software-development
---

# Frontend-Backend Integration Discipline

When writing frontend code that integrates with a backend API, the most common class of bug is **wire shape drift** — the client wrapper uses field names/types that the backend doesn't actually return/accept. The Plan/spec doc is a wish list, not a contract; the backend code is the contract.

## Core Principle: Read Backend Source First

Before writing any `api.ts` wrapper method, open the corresponding backend route file and verify:

1. **Field names** in the request body and response payload (exact spelling, case)
2. **Field types** (number vs string, array vs object, nullable vs required)
3. **Auth requirements** (which permission, anonymous vs authed)
4. **Status codes** for success/error paths

```bash
# Quick wire-shape scan of a backend route
cat apps/api/src/routes/<feature>.ts | grep -A 20 "GET\|PUT\|POST\|.use(requirePermission"
```

**Why this matters**: A Plan doc written 2 days ago may have been reworded, the backend may have been refactored, or the implementer may have used different vocabulary. The 60 seconds of grep saves a runtime bug that would have been caught at code-review time anyway. Plan docs are spec; backend source is truth. (User's standing rule from 2026-06-04: "後端 API 答案為最終依歸".)

## Reference Docs (Specific Patterns)

- `references/url-driven-tabs.md` — shadcn `<Tabs>` with URL as source of truth
- `references/form-prefill-race.md` — the user-touched flag pattern for auto-prefill from network call
- `references/layout-refactor-chrome.md` — wrapping pages in a Layout: strip inner chrome, plan backward-compat Navigate redirects

## Workflow (Frontend ↔ Backend)

1. **Plan stage**: Agree on URL structure, response shape, auth. Write to Plan doc.
2. **Backend implementation first**: route handler + audit log + tests.
3. **Frontend client wrapper**: BEFORE writing, grep the backend route file for the actual field names. Run `tsc --noEmit` after.
4. **Frontend UI**: Wire the wrapper to UI components.
5. **Smoke test**: Browser, verify the network round-trip end-to-end. Don't trust "the build passes" alone.

## Pitfalls

- **Plan doc ≠ wire shape** — Plan may say `defaultTaxRate`, backend says `rate`. Always grep the backend route file before committing the client wrapper. (crm-system Day 14.7 Step 7 caught this at code-review time before any PUT was sent; runtime would have 400'd on a Zod validation error.)
- **LSP stale after sibling subagent edits** — When two subagents edit the same file, LSP can show ghost "duplicate identifier" errors. The real `tsc --noEmit` is the source of truth; rerun it.
- **Wrapping a page in a Layout doubles the chrome** — If the page has its own `<h1>` or tab strip and the Layout also has one, you'll render twice. Strip the inner chrome at the wrap step, not defer to "later".
- **NavLink inside Radix Tabs controlled mode** — Radix warns about missing triggers. Use TabsTrigger + onClick → navigate() instead. Trade-off: middle-click "open in new tab" doesn't work on tab buttons (still works on direct URLs).
- **Auto-prefill clobbers user input** — A `useEffect(() => setState(serverValue), [])` overwrites a value the user typed before the network response returned. Use the `userTouched` flag pattern (see `references/form-prefill-race.md`).

## When the Plan/Design Doc is Out of Sync

Three recovery options, in increasing cost:

1. **Patch the client wrapper to match backend** (cheapest — backend already shipped, user data is at stake).
2. **Patch the backend to match the Plan** (only if no real users yet, AND the wire shape hasn't been documented in API.md).
3. **Update the Plan doc to reflect the backend reality** (always do this last — the Plan doc is the "lie" that's causing the drift; fixing the doc prevents the next agent from making the same mistake).

For shipped features with users, default to (1) + (3). For new features in development, (1) is fine if the backend just landed, (2) is fine if it caught early.

## Related Skills

- `dev-task-memory` — state persistence for multi-step refactors
- `patch-corruption-recovery` — when patches corrupt files during a refactor
