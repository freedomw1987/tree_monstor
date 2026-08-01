# CRM-system Audit Log Implementation (verbatim)

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body. The general audit shape
> (action / actor / resource / ip / ua / createdAt) lives in SKILL.md;
> this file is the **crm-system-specific** AuditLog table + the long
> `prisma.auditLog.create({...})` example used to bootstrap the
> CRM project's audit coverage (Day 5 / Day 6 / Day 7).

---

## AuditLog Prisma model (verbatim, crm-system)

```prisma
model AuditLog {
  id           String      @id @default(cuid())
  actorId      String?
  actor        User?       @relation(fields: [actorId], references: [id], onDelete: SetNull)
  action       AuditAction
  resourceType String?     // "quotation" | "user" | "company" | etc
  resourceId   String?
  description  String?     // human-readable one-liner
  metadata     Json?       // before/after diff, IP, etc
  ipAddress    String?
  userAgent    String?
  createdAt    DateTime    @default(now())

  @@index([actorId, createdAt])
  @@index([action, createdAt])
  @@index([resourceType, resourceId])
  @@map("audit_logs")
}

// User model — add reverse relation
model User {
  // ... existing fields ...
  auditLogs    AuditLog[]
}
```

> **Migration** (Docker local dev 用 container DB): 見下方「Docker 內 postgres 嘅 migration trick」section — 喺 host 跑唔到 `prisma migrate dev` 因為 postgres 冇 expose port,要 `docker exec` 直接行 SQL + manual `_prisma_migrations` row insert。

---

## Long-form `prisma.auditLog.create` example (verbatim, crm-system Day 6)

```typescript
.post('/', async ({ body, set, userId, request }) => {
  const created = await prisma.company.create({ data: body as never });
  set.status = 201;
  await logEvent({                              // ← 3rd line: always after the mutation
    action: 'COMPANY_CREATED',
    actorId: userId ?? null,
    resourceType: 'company',
    resourceId: created.id,
    description: `Created company ${created.name}`,
    metadata: { name: created.name, status: created.status },
    request,                                    // ← real request → IP + UA captured
  });
  return created;
}, { /* body validation */ })
```

**Apply to every write handler**. Same shape for `PATCH` and `DELETE`:

```typescript
.patch('/:id', async ({ params, body, set, userId, request }) => {
  const updated = await prisma.company.update({ where: { id: params.id }, data: body as never });
  await logEvent({
    action: 'COMPANY_UPDATED',
    actorId: userId ?? null,
    resourceType: 'company',
    resourceId: params.id,
    description: `Updated company ${updated.name}`,
    metadata: { name: updated.name, fields: Object.keys(body as object) },
    request,
  });
  return updated;
})

.delete('/:id', async ({ params, set, userId, request }) => {
  const before = await prisma.<model>.findUnique({ where: { id: params.id }, select: { name: true } });  // ← snapshot before delete
  await prisma.<model>.delete({ where: { id: params.id } });
  if (before) {
    await logEvent({
      action: 'COMPANY_DELETED',
      actorId: userId ?? null,
      resourceType: 'company',
      resourceId: params.id,
      description: `Deleted company ${before.name}`,
      metadata: { name: before.name },
      request,
    });
  }
  return { success: true };
})
```

**Always add `userId, request` to the handler signature** — they're injected by `authContext` and `Elysia` core respectively. TypeScript will complain (Elysia d.ts noise, see `elysia-typescript-workarounds`), but `bun run` runtime ignores.

---

## Special case: status-change vs general update (quotation PATCH)

```typescript
.patch('/:id', async ({ params, body, set, userId, request }) => {
  const data = body as { title?: string; notes?: string; status?: string; taxRate?: number; /* etc */ };
  // ... build `update` object, validate, etc ...
  const before = await prisma.quotation.update({ where: { id: params.id }, data: update as never });
  if (data.taxRate !== undefined) await recalcQuotation(params.id);
  const refreshed = await prisma.quotation.findUnique({ where: { id: params.id }, include: { /* ... */ } });

  // Branch: status change vs general field update
  if (data.status && data.status !== before.status) {
    await logEvent({
      action: 'QUOTATION_STATUS_CHANGED',
      actorId: userId ?? null,
      resourceType: 'quotation',
      resourceId: params.id,
      description: `${before.number} status: ${before.status} -> ${data.status}`,
      metadata: { from: before.status, to: data.status, number: before.number },
      request,
    });
  } else {
    await logEvent({
      action: 'QUOTATION_UPDATED',
      actorId: userId ?? null,
      resourceType: 'quotation',
      resourceId: params.id,
      description: `Updated quotation ${before.number} (${before.company?.name ?? ''})`,
      metadata: { number: before.number, fields: Object.keys(data) },
      request,
    });
  }
  return refreshed;
})
```

**Why two actions** (not just `UPDATED`): auditors want to filter "all status changes last week" — collapsing them into generic UPDATES makes that hard. The frontend's badge colour (success for SENT, info for STATUS_CHANGED) is also tied to the action.

### 8b. Helper for the side-effect: status endpoint shortcut

Some apps expose `POST /quotations/:id/status` as a one-shot endpoint. Same pattern: capture before, mutate, log with from/to metadata.

---

## Day-N references

- Day 5 (2026-06-05): first implementation, AuditLog + AuditAction enum added via Docker-local migration trick.
- Day 6 (2026-06-06): added `MAN_DAY_ROLE_*`, `ACTIVITY_*`, `ATTACHMENT_*` via the append-only `ALTER TYPE ... ADD VALUE IF NOT EXISTS` pattern.
- Day 7 (2026-06-07): added `QUOTATION_STATUS_CHANGED` and per-route audit coverage sweep.