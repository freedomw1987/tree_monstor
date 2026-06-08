---
name: patch-route-field-silently-dropped
description: >-
  Diagnose HTTP routes where a field appears to save but disappears after
  refresh, OR the request returns 502/500 because a Prisma relation key is
  silently stripped. Common cause: validation schema vs Prisma model name
  mismatch, especially when the frontend's TypeScript type and the backend's
  Prisma relation use different names (e.g. `manDays` vs `manDayLines`).
---

# Patch Route Field Silently Dropped

## Trigger
A frontend sends `PATCH /api/resource/:id` (or `POST` for a new resource) with new fields, the data appears to save (no error), but after refresh the field is empty or reverted. **Variant:** the same root cause manifests as HTTP 502 when the dropped field is a Prisma relation (e.g. nested `{ create: [...] }`) and a typed Prisma `include` consumer fails downstream.

## Most Common Root Causes

1. **Validation schema too narrow** — Elysia/JSON schema only lists old fields; new fields are silently dropped before reaching the handler.
2. **Prisma schema missing field** — Field doesn't exist in the model, so it's ignored or throws a cryptic Prisma error.
3. **Type mismatch** — Frontend sends ISO string `"2026-05-16T08:00:00.000Z"` but Prisma expects `DateTime`; no explicit conversion means Prisma may reject or ignore.
4. **Frontend type name vs Prisma relation name** — The frontend's TypeScript type uses one field name (`manDays`), the backend's Prisma relation uses another (`manDayLines`). The validator's key is the Prisma name, so the client must send the Prisma name on the wire even if the local type uses a different name. (See "When the Dropped Field Is a Prisma Relation" below for the full case study.)

## Diagnostic Checklist

- [ ] Does the PATCH/POST route's validation schema include the new field?
  - Elysia: `body: t.Object({ title: ..., newField: t.Optional(t.String()) })`
- [ ] Does Prisma schema have the field?
  - `model Resource { newField DateTime? }`
- [ ] Does the handler convert the field before passing to Prisma?
  - `data.newField = newField ? new Date(newField) : null`
- [ ] Does the Prisma `update` actually receive the field in `data`?
  - Add temporary `console.log` or return the updated record to inspect.
- [ ] **For nested relation creates**: does the wire key in the JSON payload match the validator's key exactly? If the client type uses `manDays` but the validator declares `manDayLines`, the client is sending `manDays` and Elysia is silently stripping it.
  - Inspect the validator declaration in the route file and the API client's `create`/`update` type definition side-by-side.

## When the Dropped Field Is a Prisma Relation → HTTP 502, Not Silent Drop

**Different symptom, same root cause.** If the field the Elysia `t.Object` validator strips is **the key a Prisma `create()` uses to nest a 1:N or 1:1 relation** (`{ create: [...] }` or `{ connect: { id } }`), the request can fail with **HTTP 502** instead of a silent save. The Prisma client throws because the relation is missing from the typed body, the route handler crashes, and Elysia returns 502 from the upstream (or the Bun process logs an unhandled rejection).

**Real case (crm-system 2026-06-06)**: Frontend `QuickCreateServiceDialog` sends `manDayLines: manDays` (the Prisma relation name) in the POST /services body. Backend route at `apps/api/src/routes/service.ts` declares the validator as:

```ts
body: t.Object({
  name: t.String(),
  description: t.Optional(t.String()),
  category: t.Optional(t.String()),
  unitPrice: t.Number(),
  currency: t.Optional(t.String()),
  status: t.Optional(t.Union([t.Literal('ACTIVE'), t.Literal('ARCHIVED'), t.Literal('DRAFT')])),
  sortOrder: t.Optional(t.Number()),
  manDayLines: t.Optional(t.Array(t.Object({
    role: t.String({ minLength: 1 }),
    dayRate: t.Number(),
    days: t.Number(),
    sortOrder: t.Optional(t.Number()),
  }))),
}),
```

Looks correct. The handler does `prisma.service.create({ data: { ...body, manDayLines: { create: body.manDayLines ?? [] } } })`. **But the frontend API client was originally typed with `manDays` instead of `manDayLines`** (because that's the field name in the local `Service` type). When the request hit the validator, the unknown `manDays` key was silently stripped, `body.manDayLines` was `undefined`, and the relation `create: []` block was empty. Prisma then created a `Service` with no `manDayLines` relation attached — no error, no 502 in this specific config, but the man-day lines were silently missing from the response. **In a stricter setup** (e.g. when the relation is non-optional in the validator, or when a downstream typed `include` consumer expects the array shape), the same shape manifests as a 502 because the typed Prisma body can't satisfy the contract.

**The fix has TWO halves** — both must be done:

1. **Wire key must match validator key exactly.** When the frontend's TypeScript type uses one name (`manDays`) and the backend's Prisma relation uses another (`manDayLines`), the JSON payload key MUST be the validator's name. The cleanest pattern is to widen the API client's `create`/`update` input type to accept the validator name, and have the consumer code localise that name back to the `Service` type field after the round-trip:

```ts
// apps/web/src/lib/api.ts — service API client
create: (data: {
  name: string;
  description?: string;
  category?: string;
  unitPrice?: number;
  currency?: string;
  status?: 'ACTIVE' | 'ARCHIVED' | 'DRAFT';
  sortOrder?: number;
  /** Wire-format key for the backend validator — must be `manDayLines`
   *  (Prisma relation name) on POST /services. */
  manDayLines?: Array<{ role: string; dayRate: number; days: number }>;
}) => request<Service>('/services', { method: 'POST', body: JSON.stringify(data) }),

// apps/web/src/components/quick-create-service-dialog.tsx
const created = await servicesApi.create({
  name: name.trim(),
  category: category.trim() || undefined,
  status,
  currency,
  unitPrice: total,
  manDayLines: manDays,   // ← wire key matches validator; local var is still `manDays`
});
// Backend returns `manDayLines` in the include — localise back to the `Service` type field:
const manDaysFromResponse = (created as Service & { manDayLines?: ServiceManDay[] }).manDayLines;
const normalised: Service = {
  ...created,
  manDays: created.manDays ?? manDaysFromResponse ?? [],
};
onCreated(normalised);
```

2. **Add `category` and `status` (and any other "obvious" optional fields) to the validator** when the route starts accepting them, even if the current client doesn't send them. Otherwise the next client that wants to send them will hit the same silent-strip pitfall.

## How to Tell Silent-Strip from Genuine Validation Error

- Elysia **genuine validation error** → HTTP 422 with a body like `{"type":"validation","on":"body","property":"/foo","message":"Expected required property"}`. The client sees the 422 and the offending field.
- Elysia **silent strip** (this whole skill) → HTTP 200/201/204 with a 200-shaped response, BUT the saved entity is missing the field/relation. The 502 variant shows up only when a downstream consumer (typed Prisma body, relation `include`, or a stricter schema) fails because of the missing data.

If you ever see HTTP 200 but the data isn't where it should be, **search the validator body for the field name** — it's almost always spelled differently between validator and Prisma/client. A `git grep` for the field on both sides of the wire is the fastest check.

## Prevention Rule

> When adding any new field to a PATCH/POST route, check BOTH:
> 1. Validation schema lists the field
> 2. Prisma `data` object includes the field with correct type conversion
> 3. The JSON wire key in the client matches the validator's key — especially for Prisma relations where the Prisma name and the client type name often differ (e.g. `manDayLines` on the wire, `manDays` in the local type)

Do NOT assume that because the DB schema supports it, the API route will automatically pass it through.

## Example Fix

```ts
// BEFORE (openAt/closeAt silently dropped)
body: t.Object({ title: t.Optional(t.String()) })
return prisma.quiz.update({ where: { id }, data: body })

// AFTER
body: t.Object({
  title: t.Optional(t.String()),
  openAt: t.Optional(t.String()),
  closeAt: t.Optional(t.String()),
})
const { title, openAt, closeAt, ...rest } = body
const data: any = { ...rest }
if (title !== undefined) data.title = title
if (openAt !== undefined) data.openAt = openAt ? new Date(openAt) : null
if (closeAt !== undefined) data.closeAt = closeAt ? new Date(closeAt) : null
return prisma.quiz.update({ where: { id }, data })
```

## Related

- `polymorphic-line-items` — covers the `manDayLines` vs `manDays` name mismatch from a domain perspective (Prisma relation naming + frontend type convention); pairs with this skill for the validator-layer fix.
- `prisma-relation-debugging` — different but adjacent: when the relation field is declared in the schema but the code uses scalar shorthand instead of `{ connect: { id } }`.

## Mirror-Image Pitfall: Response Side Field-Name Drift (2026-06-06 crm-system)

**The above covers the *request* side** (frontend → backend wire key must match the validator). There is a **mirror-image pitfall on the response side** that catches you the same way.

**Symptom:** A Prisma relation is correctly included on the response (`include: { manDayLines: true }`), and the JSON key in the response body is `manDayLines` (Prisma preserves the camelCase model name). But the frontend's TypeScript type uses `manDays`. The API client's `request<T>` generic is a **type-only cast** — it does not transform the response. So at runtime, `service.manDays` is `undefined` even though `service.manDayLines` is populated.

**Failure modes (depending on whether the component has defensive code):**

| Defensive code present? | Symptom |
|---|---|
| **No** (`service.manDays.map(...)`) | `Uncaught TypeError: Cannot read properties of undefined (reading 'map')` at the consumer site |
| **Yes** (`service.manDays?.length ?? 0`) | Silently renders "0 個 man-day role" — looks like the data is missing, not a code bug |
| **Yes** (`service.manDays?.reduce(...)`) | Same — silently 0 days total |

This is exactly the trap I hit twice in one session (crm-system Day 9, 2026-06-06): first a list page silently rendered "0 個 man-day role" because the `?.length ?? 0` swallowed the missing field; then a detail page crashed with `Cannot read 'map'` because the `useEffect` was non-defensive. **Two pages, same root cause, opposite symptoms.**

### The fix: normalise at the API client boundary, not in every component

Add a `normaliseService` (or equivalent per-resource) helper inside the `lib/api.ts` API client, and pipe it through **every entry point** that returns the resource (`list`, `get`, `create`, `update`). The helper does a single field rename so the rest of the frontend only ever sees the canonical `Service` type field name:

```ts
// apps/web/src/lib/api.ts
function normaliseService<T extends { manDays?: unknown; manDayLines?: unknown }>(s: T): T {
  const manDaysFromWire = (s as { manDayLines?: ServiceManDay[] }).manDayLines;
  if (manDaysFromWire !== undefined) {
    return { ...s, manDays: manDaysFromWire as ServiceManDay[] };
  }
  return s;
}
export const servicesApi = {
  list: (params) =>
    request<...>('/services?...').then((r) => {
      const items = Array.isArray(r) ? r : r.items;
      return items.map(normaliseService);
    }),
  get: (id) => request<Service>(`/services/${id}`).then(normaliseService),
  create: (data) => request<Service>('/services', { ... }).then(normaliseService),
  update: (id, data) => request<Service>(`/services/${id}`, { ... }).then(normaliseService),
};
```

After this, **every component** that reads `service.manDays` works without defensive `?? []` / `?.length` because the API boundary has guaranteed the field is present (or `undefined` if the backend response truly lacks it — at which point `service.manDays` being `undefined` is the same `undefined` it always was, and the consumer can decide whether to defensive-fallback).

### Defensive code inside components: keep, don't remove

Even with the boundary normaliser, **keep the belt-and-suspenders** in components:

```tsx
// service-detail.tsx useEffect — defensive
setManDays((service.manDays ?? []).map((m) => ({ role: m.role, dayRate: m.dayRate, days: m.days })));
```

Reasons:
- The normaliser assumes the wire field name is one of the known alternatives (`manDays` or `manDayLines`). If Prisma changes its naming policy and returns something new, the component still doesn't crash.
- Future contributors might add a new code path that bypasses the API client (e.g. a WebSocket subscription returning a different shape).
- The cost is one `?? []` per consumer; the benefit is never debugging this at 3am.

### Diagnostic checklist (response side)

- [ ] Does the backend route use `include: { <relation>: true }` for any relation the frontend reads?
- [ ] Does the JSON response actually contain the expected key? (Check via `curl` + `jq .items[0] | keys`, not just the type definition.)
- [ ] Does the frontend's TypeScript field name match the **wire key**? If not, where is the rename happening? (It should be at the API client boundary, not in every consumer.)
- [ ] For any field that's optional on the wire (e.g. an endpoint that doesn't `include` the relation), does every consumer handle `undefined` defensively?

### The "include-miss" trap: route returns the resource but omits a relation the UI reads (2026-06-09 crm-system)

**Class of bug**: The same as the response-side drift above, but **the wire key is correct (Prisma name) and the backend `include` is the one that's missing**. The route's Prisma `findMany` / `findUnique` doesn't `include: { stage: true }` (or whichever relation), so the JSON response has no `stage` key at all. The frontend type expects `stage`, the code uses `deal?.stage?.id`, gets `undefined`, and silently falls through to a default — and the user sees a confusing "always shows X" bug.

**Real case (crm-system 2026-06-09)**: A `GET /deals/kanban` route returns stages with nested deals for the Kanban board. The route's `prisma.deal.findMany` has:

```ts
include: {
  company: { select: ... },
  owner: { select: ... },
  _count: { select: { quotations: true } },
  // ❌ 冇 stage! 跟住個 bucket.map((s) => ({ stage: s, deals: deals.filter(d => d.stageId === s.id) }))
  //    只係用 stageId 做 filter, 但 SELECT 出嚟嘅 deal 唔帶 stage object 返出嚟
}
```

On the frontend, the edit dialog has:
```tsx
const [stageId, setStageId] = useState(deal?.stage?.id ?? stages[0]?.id ?? '');
```

Because `deal.stage` is `undefined`, the dropdown **always shows the first stage** (Lead in the crm-system seed). **Every deal's edit dialog shows Lead**, no matter where the card sits on the Kanban board. Two compounding symptoms:

1. **Wasted backend work**: The route's bucket-filter logic still works (uses `d.stageId` from the `where` clause or an explicit `select`), so the cards render in the right columns. The user sees the right placement.
2. **Silent UI fallback in the editor**: But the editor dialog lies about the deal's current stage, so the user has to re-pick it on every edit. Worse: the form's `stageChanged = stageId !== deal.stage?.id` check (used to decide whether to call the `moveStage` endpoint) **always evaluates `true`** when `deal.stage` is `undefined`, so every save triggers an unnecessary stage move. The `deal?.stage?.id` comparison is asymmetric: `undefined !== 'some-id'` is `true` regardless.

**Why this is sneakier than the write-side silent drop**: The route returns 200. The data is "there" (cards render in correct columns via `stageId` filter). The TypeScript types already declare `stage?: {...}` (it was added when the editor was built). The only thing missing is the `include` clause. There's no error, no warning, no console log — just a quietly wrong editor.

**How to detect it during code review (one grep)**:

```bash
# Match every consumer that reads the missing relation
rg "deal\.stage\.|deal\?\.stage" apps/web/src
# Then check the backend route's Prisma `include`:
rg -A 12 "kanban.*async" apps/api/src/routes/deal.ts
# Look for `include:` block — confirm it lists the relation you're using on the frontend
```

**The fix** (one line — add the missing include):

```ts
const deals = await prisma.deal.findMany({
  where,
  orderBy: { createdAt: 'desc' },
  include: {
    company: { select: { id: true, name: true, ... } },
    owner: { select: { id: true, name: true, email: true } },
    stage: { select: { id: true, name: true, probability: true, color: true } },  // ← add
    _count: { select: { quotations: true } },
  },
});
```

**Why the route worked at all without `include: { stage: true }`**: Prisma's `where: { stageId: 'X' }` clause still works — it filters by column. The relation is loaded only when explicitly included. The route's bucket logic (filter deals into per-stage arrays) was using `d.stageId` from the raw row, not `d.stage.id`, so the placement logic kept working. The `include` omission only became visible when the frontend started reading `d.stage` for an unrelated feature (the edit dialog).

**Prevention rule (the 1-line version)**:

> **Whenever you add a `?._relation_` reference on the frontend, grep the backend route's `include:` block for that relation name. If it's not there, the field is `undefined` and your `?? fallback` will lie.**

For crm-system specifically, a "Kanban endpoint" should always include:

- `stage` (for edit dialogs and re-ordering)
- `owner` (for owner column display)
- `_count` for all child relations the card UI might surface

Build this into the endpoint template so a future engineer doesn't have to remember.

**Distinction from `manDayLines` / `manDays` (the wire-side drift)**: That bug was a **naming mismatch** (Prisma uses one name, frontend type uses another). This bug is a **missing field** (Prisma doesn't send it at all; the frontend receives a missing key, not a renamed one). The fix is the same shape (add the missing `include` or `select` clause) but the symptom is different: wire-side drift usually produces "data missing from a save" (write) or "0 items rendered" (read, defensive code), whereas include-miss usually produces "always shows the default" (read, with `?? fallback`).

### Prevention rule (both directions)

> **Wire keys belong in the API client, not in components.** When the backend's Prisma model name and the frontend's TypeScript field name differ (very common for camelCased Prisma relations), do the rename ONCE in `lib/api.ts` (or whatever typed-client file the project uses), inside the wrapper for that resource. Components should never need to know the wire format exists.

This pairs with the request-side rule above: the **request path** uses the wire key (Prisma relation name) in the validator; the **response path** does the same and normalises back at the boundary. Two sides of the same wire-format coin, both fixable in the same file.

### Concrete recipe: when you hit this pitfall

1. `curl -fsS http://localhost:3001/api/services/<id>` (with auth) and inspect the raw response keys. If `manDayLines` is present but the frontend type is `manDays`, you've found it.
2. Add or update the `normaliseX` helper in the API client — typically a 5-line field rename.
3. Wire it into `list`/`get`/`create`/`update` (whichever exist for this resource).
4. **Run the full test**: create, list, get, update each in turn. The create response includes the relation; the update response might not (depending on whether the route adds `include` to its return); the get response should. Each entry point's normaliser path should be exercised.
5. Remove the now-redundant inline `manDaysFromResponse`/`manDayLines ?? manDays` normalisations in individual components (e.g. `QuickCreateServiceDialog` was doing this inline; with the boundary normaliser it can be deleted).

**Anti-pattern to watch for**: someone (you, in a previous turn) may have already added defensive code like `service.manDays?.length ?? 0` in three different pages because the boundary wasn't fixed. Those workarounds then **hide** the real bug (silent "0 個 man-day role" instead of a crash). When you find the boundary fix, leave the `?? []` as belt-and-suspenders, but no longer rely on it.
