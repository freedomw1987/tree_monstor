---
name: react-html5-drag-drop-pitfalls
description: Build correct HTML5 drag-and-drop in React (Kanban, sortable lists, file drop zones). Covers the most common silent-failure mode — forgetting `e.dataTransfer.setData` in `onDragStart` — and the matching `onDragOver` + `e.preventDefault` rules that make a column a valid drop target. Trigger when building kanban, Trello-style boards, sortable lists, file upload dropzones, or any UI that uses `draggable={true}` on an element and expects a drop handler to fire on another.
---

# React HTML5 Drag-and-Drop Pitfalls

> **The browser's native HTML5 DnD API is the de-facto choice for kanban/sortable/file-drop in React (no extra dep), but it has 4 specific silent-failure modes that don't show up as errors in the console.** This skill covers the 4 anti-patterns and their fixes, plus the verified-working shape of a kanban card + column.

## When to use

- Building a Kanban board (Trello-style, jira-style, sales-pipeline)
- Building a sortable list (drag to reorder rows, or to a trash icon)
- Building a file upload dropzone (drag files into a folder icon)
- Building a cross-pane move UI (e.g. drag a "deal" from a list into a "favorites" pane)
- Anywhere you write `draggable={true}` on a React element and expect a sibling/parent's `onDrop` to fire

## The 4 silent-failure modes

### Pitfall 1 — Forgetting `e.dataTransfer.setData` in `onDragStart`

**Symptom**: Drag looks fine, the column highlights on `onDragOver`, the drop handler fires, but the drop handler reads `e.dataTransfer.getData('text/deal-id')` and gets an empty string. The `if (dealId) onDrop(dealId)` early-return skips the actual move. The card **visually moved** (optimistic update) but server never received the request → `onSettled` reverts it.

**Why it's silent**: There's no console error, no React warning, no visible UI signal that the drop was rejected. The user sees a flickering "moved and snapped back" behavior and concludes "the drag-drop is broken" — which is exactly David's report on crm-system Day 9.

**Fix** — set the data on drag start, read it on drop:

```tsx
function DealCard({ deal, onDrop, ... }) {
  return (
    <div
      draggable
      onDragStart={(e) => {
        // ⭐ Set the payload here, on the SOURCE. The drop target has
        // no other way to know which element was dragged unless you
        // encode the identity in the dataTransfer.
        e.dataTransfer.setData('text/deal-id', deal.id);
        // 'move' instead of 'copy' avoids "+" cursor on drop targets
        e.dataTransfer.effectAllowed = 'move';
      }}
      onDragEnd={() => setDragging(false)}
    >
      {/* ... */}
    </div>
  );
}

function KanbanColumn({ onDrop, ... }) {
  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();   // ⭐ Without this, onDrop will NOT fire
        setDragOver(true);
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragOver(false);
        const dealId = e.dataTransfer.getData('text/deal-id');
        if (dealId) onDrop(dealId);
      }}
    >
      {/* ... */}
    </div>
  );
}
```

**Two more gotchas in the same area**:

1. **`effectAllowed = 'move'`** is optional but recommended. Without it, some browsers show a "+" cursor on drop targets, suggesting "copy" which is confusing.
2. **`onDragEnd`** should clear any local drag-state flags (e.g. `setDragging(false)`) so that the card's "click" handler doesn't fire after the drop. Use a `dragging` state ref/flag to gate the click:
   ```tsx
   onClick={() => { if (!dragging) onEdit(deal); }}
   ```

### Pitfall 2 — Forgetting `e.preventDefault()` in `onDragOver`

**Symptom**: Drop targets don't fire `onDrop` at all. The `onDragOver` event fires, the highlight toggles, but the mouse release does nothing.

**Why**: The HTML5 DnD spec requires the drop target to **explicitly opt-in** by calling `preventDefault()` on the `dragover` event. If the target doesn't, the browser treats it as "not a valid drop target" and the `drop` event never fires.

**Fix** (same code as above — the `onDragOver` handler must call `e.preventDefault()`):

```tsx
onDragOver={(e) => {
  e.preventDefault();   // ⭐ without this, drop is silently blocked
  setDragOver(true);
}}
```

If you need to differentiate between "valid drop target" and "currently hovering but invalid" (e.g. for visual feedback), use `e.dataTransfer.dropEffect`:

```tsx
onDragOver={(e) => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';   // ⭐ signals the drop is allowed
  setDragOver(true);
}}
```

### Pitfall 3 — Click handler bubbles up through the draggable element

**Symptom**: On a Kanban card that has both `onClick={openEditDialog}` AND a sub-button (e.g. "＋ 報價" or "📄 N quotations"), clicking the sub-button fires BOTH handlers — the sub-button's `navigate(...)` AND the card's `openEditDialog(...)`.

**Fix** — call `e.stopPropagation()` on the inner button's click:

```tsx
function DealCard({ deal, onEdit }) {
  const navigate = useNavigate();
  return (
    <div onClick={() => onEdit(deal)} className="...">
      <h3>{deal.title}</h3>
      <button
        onClick={(e) => {
          e.stopPropagation();   // ⭐ critical — without this, both handlers fire
          navigate(`/quotations?dealId=${deal.id}`);
        }}
      >
        ＋ 報價
      </button>
    </div>
  );
}
```

Related: also `e.preventDefault()` on the inner button if it's a `<button type="submit">` inside a `<form>`, or `<a>` inside another `<a>` (HTML doesn't allow nested anchors).

### Pitfall 4 — `useState dragOver` flag stuck on after drop

**Symptom**: A drop happens, the visual highlight (e.g. `border-primary bg-primary/5`) stays on the column even after the user moves their mouse away. Reloading the page fixes it.

**Why**: `onDragLeave` fires when the cursor leaves an element OR a child element, which causes flickering. The cleanest fix is to also call `setDragOver(false)` in the `onDrop` handler (since you no longer need the highlight after a drop), and to track drag state via the card's `dragging` flag rather than the column's `dragOver` flag.

**Fix** — clear in three places:

```tsx
const [dragOver, setDragOver] = useState(false);

onDragOver={(e) => {
  e.preventDefault();
  setDragOver(true);
}}
onDragLeave={() => setDragOver(false)}
onDrop={(e) => {
  e.preventDefault();
  setDragOver(false);          // ⭐ clear here too, since drop ends the drag
  const dealId = e.dataTransfer.getData('text/deal-id');
  if (dealId) onDrop(dealId);
}}
```

Or, use the card's `dragging` state (already set in `onDragStart` and cleared in `onDragEnd`) to drive the visual: if the card is `dragging`, fade the source card; if the column has any dragging card over it, highlight. This decouples the "is hovering" state from per-card hover events.

## Diagnostic checklist (when drag-drop "doesn't work")

| # | Check | What to grep / test |
|---|---|---|
| 1 | `onDragStart` has `e.dataTransfer.setData(...)`? | `rg "setData" path/to/card.tsx` |
| 2 | `onDragOver` has `e.preventDefault()`? | `rg "preventDefault" path/to/column.tsx` |
| 3 | Drop handler reads `getData` with the SAME key set in (1)? | Compare `setData('text/X', ...)` and `getData('text/X')` strings |
| 4 | `onDrop` is on the column / container, not on individual children? | Visual inspect; `onDrop` on a child only fires if the cursor is exactly on that child |
| 5 | Inner buttons have `e.stopPropagation()`? | `rg "stopPropagation" path/to/card.tsx` |
| 6 | The draggable element's parent isn't `pointer-events: none`? | DevTools → Computed style on the draggable's parents |
| 7 | The draggable element isn't inside a `position: fixed` overlay that intercepts events? | Visual inspect + z-index review |
| 8 | Mobile / touch devices: HTML5 DnD doesn't work — use `@dnd-kit` or a custom touch handler | Test in DevTools device emulation mode |

## Pitfall 5 — HTML5 DnD doesn't work on touch devices

**Symptom**: Drag-drop works on desktop but is completely non-functional on iPad / iPhone / Android. No events fire.

**Why**: HTML5 Drag-and-Drop API has very limited / inconsistent support on touch devices. iOS Safari has had support for some events since iOS 13 but it's patchy; Android Chrome blocks it by default. For touch-required UIs, you need a library:

- **`@dnd-kit/core` + `@dnd-kit/sortable`** — React-first, supports pointer/touch/keyboard, ~12KB
- **`react-dnd`** with `react-dnd-html5-backend` — older, more mature, larger
- **Custom touch handlers** — `onTouchStart` / `onTouchMove` / `onTouchEnd` with manual hit-testing

**Rule of thumb**: If David says "I want to use this on iPad when I'm at a customer meeting" and the UI is a kanban, **do not use raw HTML5 DnD**. Use `@dnd-kit` or ship a "tap to assign stage" modal as a fallback.

## Verified working Kanban pattern (crm-system, 2026-06-09)

```tsx
// DealCard.tsx
function DealCard({ deal, disabled, onEdit }) {
  const [dragging, setDragging] = useState(false);
  const navigate = useNavigate();
  const quoteCount = deal._count?.quotations ?? 0;

  return (
    <div
      draggable={!disabled}
      onDragStart={(e) => {
        e.dataTransfer.setData('text/deal-id', deal.id);
        e.dataTransfer.effectAllowed = 'move';
        setDragging(true);
      }}
      onDragEnd={() => setDragging(false)}
      onClick={() => { if (!dragging) onEdit(deal); }}
      className="p-2.5 rounded border bg-card hover:border-primary cursor-grab"
    >
      <h4>{deal.title}</h4>
      <p>{formatCurrency(deal.value, deal.currency)}</p>
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          navigate(`/quotations?dealId=${deal.id}`);
        }}
      >
        <FileText className="h-3 w-3" />
        {quoteCount > 0 ? `${quoteCount} 份報價 · ＋` : '＋ 報價'}
      </button>
    </div>
  );
}

// KanbanColumn.tsx
function KanbanColumn({ stage, deals, onDrop, isMoving, onEdit }) {
  const [dragOver, setDragOver] = useState(false);
  return (
    <div
      className={`w-72 shrink-0 rounded-lg border ${
        dragOver ? 'border-primary bg-primary/5' : 'border-border'
      }`}
      onDragOver={(e) => {
        e.preventDefault();
        setDragOver(true);
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragOver(false);
        const dealId = e.dataTransfer.getData('text/deal-id');
        if (dealId) onDrop(dealId);
      }}
    >
      {/* cards rendered here */}
    </div>
  );
}
```

## Smoke test (E2E for the drag-drop, via Python since `file://` blocks `browser_*`)

```python
import urllib.request, json
token = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/auth/login',
  data=json.dumps({'email':'admin@crm.local','password':'admin123'}).encode(),
  headers={'Content-Type':'application/json'})).read())['token']

# 1. Get the current kanban
data = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/deals/kanban',
  headers={'Authorization': f'Bearer {token}'})).read())

# 2. Find a deal + a target stage
deal = next(d for b in data['buckets'] for d in b['deals'] if d['title'] == 'Globex')
target = next(s for b in data['buckets'] if b['stage']['name'] == 'Qualified' for s in [b['stage']])

# 3. Simulate the drag-drop server call (PATCH /deals/:id/stage)
req = urllib.request.Request(
  f"http://localhost/api/deals/{deal['id']}/stage",
  data=json.dumps({'stageId': target['id']}).encode(),
  headers={'Content-Type':'application/json', 'Authorization': f'Bearer {token}'},
  method='PATCH',
)
result = json.loads(urllib.request.urlopen(req).read())
print(f"PATCH result: stage={result['stage']['name']}, status={result['status']}")

# 4. Re-fetch to confirm persistence
data2 = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/deals/kanban',
  headers={'Authorization': f'Bearer {token}'})).read())
deal2 = next(d for b in data2['buckets'] for d in b['deals'] if d['title'] == 'Globex')
print(f"After reload: stage={deal2['stage']['name']}, in bucket={[b['stage']['name'] for b in data2['buckets'] if any(dd['id']==deal2['id'] for dd in b['deals'])]}")
# Expected: stage='Qualified', in bucket=['Qualified']
```

If step 3 succeeds and step 4 shows persistence, the **server-side** is working. If the user still sees the card "snap back" in the UI, the bug is on the client side (Pitfall 1 or 4 — check `setData` and `onDragEnd` state cleanup).

## Why this is a class-level skill (not bundled with `kanban-worker` or similar)

- The 5 pitfalls are browser API gotchas, not React state or backend issues
- They apply equally to: kanban, sortable list, file dropzone, draggable widget on a dashboard
- A future session will hit Pitfall 1 every time, because `setData` is the single most "obvious to forget" line in HTML5 DnD — React's synthetic events don't make it salient, and there's no TypeScript type that flags a missing `setData` as a compile error
- The pattern is durable: HTML5 DnD has been stable since 2010, no major API changes expected
- `@dnd-kit` is the de-facto replacement on touch-required projects, but on desktop-first React apps, raw HTML5 DnD still wins on bundle size and zero-dep simplicity

## Related skills

- `frontend/related-entity-entry-points` — Kanban-card "＋ 報價" sub-button pattern (Pattern 3, same domain)
- `frontend/rwd-mobile-audit` — if drag-drop needs to work on iPad/mobile, this is the trigger for `@dnd-kit`
- `devops/bun-elysia-react-vite-stack` — full-stack context, crm-system kanban endpoint patterns
