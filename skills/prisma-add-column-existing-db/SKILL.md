---
name: prisma-add-column-existing-db
description: Add a new column to an existing Prisma model when the database is already in production and you cannot run prisma migrate reset
category: backend
---


Last-verified: 2026-07-28
# Add New Column to Existing Prisma Model (Production Database)

## Problem
You need to add a new field to an existing Prisma model, but running `prisma migrate dev` fails because:
- The database already exists with data
- `prisma migrate dev` would reset the database (data loss)
- `prisma migrate deploy` only works with already-applied migrations

## Root Cause
When you add a new relation field to an existing model, Prisma validates that the opposite relation exists. If it doesn't, schema validation fails before any migration can run.

## Solution: Manual SQL + Prisma Schema Sync

### Step 1: Update Prisma Schema
Add the new field AND the opposite relation on the related model:

```prisma
// In Attachment model
project     Project? @relation(fields: [projectId], references: [id])
projectId   String?  @map("project_id")

// In Project model — must add opposite side
attachments Attachment[]
```

### Step 2: Run Prisma Format
```bash
bunx prisma format
```

### Step 3: Add Column Manually (via Bun script)
Since you can't use `psql` directly, create a migration script:

```ts
// migrate-add-column.ts
import { prisma } from './src/utils/prisma'
await prisma.$executeRaw`ALTER TABLE attachments ADD COLUMN project_id TEXT`
console.log('done')
```

Run with:
```bash
bun migrate-add-column.ts
```

### Step 4: Build and Deploy
```bash
bun build src/index.ts --outdir=dist --target=bun
docker cp dist/index.js pm-system-backend-1:/app/dist/index.js
docker restart pm-system-backend-1
```

## Key Insight
Prisma schema and database schema must be kept in sync manually for production databases that cannot be reset. The schema changes first (to pass validation), then the SQL column is added via a raw query.

## Trigger Conditions
- Existing production PostgreSQL database
- Cannot run `prisma migrate reset` (data loss)
- Adding optional relation field to existing model
- `psql` not available in container