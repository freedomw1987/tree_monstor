---
name: elysia-route-conflict-debug
description: Debug Elysia.js route conflicts — server fails to start with "different parameter name" error, or requests hit wrong handler.
tags: [debugging, elysia, route, bun]
metadata:
  hermes:
    tags: [debugging, elysia, route, bun]
    related_skills: [elysia-typescript-workarounds, systematic-debugging]
---
# Elysia Route Conflict Debug

## Symptom

Server fails to start with:
```
error: Cannot create route "/api/quiz/:quizId/attempts" with parameter "quizId" 
because a route already exists with a different parameter name ("id") in the same location
```

Or: Requests go to the wrong handler (e.g. `/:id` handles requests that should go to `/:quizId/attempts`).

## Root Cause

Elysia uses memoirist router. Within a single route group (prefix), ALL routes MUST use the same parameter name at each path level.

**FAILS:**
```ts
// In same route group with prefix "/api/quiz"
.get("/:id", ...)              // param = "id"
.get("/:quizId/attempts", ...) // param = "quizId" — CONFLICT at /:level
.get("/:id/attempts", ...)    // same level different name — CONFLICT
```

**OK (same param name throughout):**
```ts
.get("/:id", ...)
.get("/:id/attempts", ...)     // "id" — OK
.get("/:id/questions", ...)    // "id" — OK
```

## Diagnosis

1. Find ALL route definitions in the affected route file
2. Check every `/:paramName` usage at each path level
3. Identify any inconsistent param names at the same path segment

```bash
grep -n "/:" src/routes/quiz.ts
```

## Fix

Rename all params at conflicting levels to the SAME name. Pick the simplest name (usually `id`).

```ts
// Before
.get("/:quizId/attempts", ...)
.get("/:id/attempts", ...)

// After — all use :id
.get("/:id/attempts", ...)
```

Also update the handler body to use the consistent param name:
```ts
// Before
if (!(await canManageQuiz(params.quizId, authenticatedUser))) {
  const attempts = await prisma.quizAttempt.findMany({
    where: { quizId: params.quizId },  // quizId
  })

// After
if (!(await canManageQuiz(params.id, authenticatedUser))) {
  const attempts = await prisma.quizAttempt.findMany({
    where: { quizId: params.id },  // id
  })
```

And update the params schema:
```ts
// Before
{ params: t.Object({ quizId: t.String() }) }
// After
{ params: t.Object({ id: t.String() }) }
```

## Elysia Route Chaining Syntax — Missing `)` Closures

When inserting new routes between existing chains, each route's parameter object must be closed with `)` before chaining another method.

**FAILS (missing closing `)` before `.post()`):**
```ts
.get("/:id/attempts",
  { params: t.Object({ id: t.String() }) },
  async (ctx) => { ... }
)
.post("/:quizId/submit-assignment", ...)  // ❌ Missing ) to close .get() chain
```

**OK (explicit closing `)` after each route):**
```ts
.get("/:id/attempts",
  { params: t.Object({ id: t.String() }) },
  async (ctx) => { ... }
)
.post("/:quizId/submit-assignment", ...)  // ✅ .get() chain properly closed
```

**Diagnosis:**
```bash
# Find all route chain closings — only the LAST one should be at router level
grep -n "^  );" src/routes/quiz.ts | tail -10

# If you see only ONE `);` at the end but many chained .get/.post/.put,
# a route chain is not properly closed
```

**Fix:** Add `)` after each route's handler block when it precedes another chained method:
```ts
// Before
.get("/:id/attempts",
  { params: t.Object({ id: t.String() }) },
  async (ctx) => { return attempts; }
).post("/:quizId/submit-assignment", ...)

// After — note the extra ) after the handler
.get("/:id/attempts",
  { params: t.Object({ id: t.String() }) },
  async (ctx) => { return attempts; }
)
.post("/:quizId/submit-assignment", ...)
```

## Stale Server Process Masking the Fix

After fixing, if server still fails to start or old behavior persists:

```bash
# Check which process is on the port
lsof -i :3000

# Kill ALL processes on that port
kill <PID1> <PID2> ...

# Verify port is free
lsof -i :3000  # should return nothing

# Restart fresh
cd ~/projects/umac_ai/backend && bun run src/index.ts
```

**Rule:** After killing a server, always verify with `lsof -i :PORT` that exactly ONE process is listening.