---
name: prisma-json-field-api-serialization
description: Fix "options.map is not a function" when Prisma Json fields serialize as JSON strings over REST API
tags: [prisma, api, serialization, debug]
---

# Prisma JSON Field API Serialization Fix

## Problem
When a Prisma model has a `Json` field (e.g., `options Json` for quiz questions), the data serializes as a JSON string over HTTP REST API responses, but works fine when accessed directly in backend code. This causes runtime errors like `options.map is not a function` in the frontend.

## Root Cause
Prisma's `Json` field type serializes to a JSON string when sent over HTTP (via Elysia's `.json()`), not a JavaScript array/object. The frontend receives a string that looks like `'["option1","option2"]'` instead of an actual array `["option1", "option2"]`.

## Solution
Always parse JSON fields from API responses before using them:

```typescript
// QuizQuestion from API response
const options: string[] = typeof q.options === 'string' 
  ? JSON.parse(q.options) 
  : q.options

// Then use options.map(...) safely
options.map((opt, i) => ...)
```

### TypeScript Interface (for API responses)
```typescript
interface QuizQuestion {
  id: string
  question: string
  options: string | string[]  // Can be string (from API) or array (from Prisma direct)
  correctIndex: number
}
```

## Prevention
- When designing APIs that return Prisma models with Json fields, always document which fields need JSON parsing
- Consider creating separate DTO types for API responses rather than returning Prisma models directly
- Or: use a serialization layer that converts Json fields to properly typed arrays before sending responses

## Verification
```bash
# Check actual API response
curl http://localhost:3000/api/lessons/{id} | python3 -c "
import sys, json
data = json.load(sys.stdin)
quiz = data['quizzes'][0]
q = quiz['questions'][0]
print('options type:', type(q['options']))
print('options:', q['options'])
"
```

## Files Affected
- `frontend/src/pages/student/LessonView.tsx` — quiz options rendering
- Any component consuming JSON fields from REST API
