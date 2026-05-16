---
name: patch-route-field-silently-dropped
description: Diagnose PATCH routes where a field appears to save but disappears after refresh — common cause is validation schema vs Prisma model mismatch.
---

# Patch Route Field Silently Dropped

## Trigger
A frontend sends `PATCH /api/resource/:id` with new fields, the data appears to save (no error), but after refresh the field is empty or reverted.

## Most Common Root Causes

1. **Validation schema too narrow** — Elysia/JSON schema only lists old fields; new fields are silently dropped before reaching the handler.
2. **Prisma schema missing field** — Field doesn't exist in the model, so it's ignored or throws a cryptic Prisma error.
3. **Type mismatch** — Frontend sends ISO string `"2026-05-16T08:00:00.000Z"` but Prisma expects `DateTime`; no explicit conversion means Prisma may reject or ignore.

## Diagnostic Checklist

- [ ] Does the PATCH route's validation schema include the new field?
  - Elysia: `body: t.Object({ title: ..., newField: t.Optional(t.String()) })`
- [ ] Does Prisma schema have the field?
  - `model Resource { newField DateTime? }`
- [ ] Does the handler convert the field before passing to Prisma?
  - `data.newField = newField ? new Date(newField) : null`
- [ ] Does the Prisma `update` actually receive the field in `data`?
  - Add temporary `console.log` or return the updated record to inspect.

## Prevention Rule

> When adding any new field to a PATCH route, check BOTH:
> 1. Validation schema lists the field
> 2. Prisma `data` object includes the field with correct type conversion

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
