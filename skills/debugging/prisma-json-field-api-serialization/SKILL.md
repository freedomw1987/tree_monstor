---
name: prisma-json-field-api-serialization
description: Fix runtime errors caused by Prisma field types that serialize as strings over REST (Json / Decimal / BigInt / Date / Bytes) instead of their JS-typed equivalents — covers "options.map is not a function" (Json), "2.5 === "2.5" fails" (Decimal), "Cannot read property of bigint" (BigInt), and similar shape drift. Trigger when a Prisma field comes back as a quoted string but the caller expects array/number/object/Date, especially on PG.
tags: ["prisma", "api", "serialization", "debug", "decimal", "bigint", "json", "e2e"]
---


Last-verified: 2026-07-28
# Prisma Field API Serialization — Json / Decimal / BigInt / Date / Bytes

## Problem (generalized)

Prisma serializes several field types to **strings over REST** that look like the underlying JS value but are not equal to it. Frontend code that does type-coerced equality, `.map()`, or `new Date()` against the API response either crashes or silently compares wrong.

| Prisma type | Wire shape | Caller expects | Failure mode |
|-------------|-----------|----------------|--------------|
| `Json` | `'["a","b"]'` (string) | `["a","b"]` (array) | `options.map is not a function` |
| `Decimal` / `Numeric` | `"2.5"` (string) | `2.5` (number) | `expect(hours).toBe(2.5)` fails, `===` mismatches |
| `BigInt` | `"9007199254740993"` (string) | `9007199254740993n` (bigint) | Arithmetic fails, `===` mismatch |
| `DateTime` | `"2026-06-08T10:00:00.000Z"` (ISO string) | `Date` object | `date.getTime()` throws, `new Date(s)` works but lazy conversion |
| `Bytes` | `"aGVsbG8="` (base64 string) | `Uint8Array` | `bytes.length` is string length not byte length |
| `enum` | `"ACTIVE"` (string) | enum value | usually OK, but be careful in switch statements |

**Why this happens**: Prisma's `Json` type is a JSON-encoded string at the protocol layer; `Decimal` ships as a string to preserve arbitrary precision; `BigInt` exceeds JS number safety. The `@prisma/client` model types document these as strings, but the runtime is the same — and any test or E2E script that compares `===` against a JS literal will fail.

## Solutions (per type)

### Json field — always parse on the consumer

```typescript
// QuizQuestion from API response
const options: string[] = typeof q.options === 'string'
  ? JSON.parse(q.options)
  : q.options
// Then use options.map(...) safely
options.map((opt, i) => ...)
```

```typescript
// TypeScript interface (for API responses) — accept either
interface QuizQuestion {
  id: string
  question: string
  options: string | string[]  // Can be string (from API) or array (from Prisma direct)
  correctIndex: number
}
```

### Decimal / Numeric field — Number() at the comparison site

```typescript
// ❌ Fails: string "2.5" !== number 2.5
expect(workLog.hours).toBe(2.5)

// ✅ Coerce at the comparison site
expect(Number(workLog.hours)).toBe(2.5)

// Or normalize at the API boundary:
const normalized = { ...workLog, hours: Number(workLog.hours) }
```

**E2E / Playwright gotcha** (2026-06-08 pm-system): if your E2E test posts `hours: 2.5` and then `expect(body.workLog.hours).toBe(2.5)`, the assertion **fails** because Prisma Decimal serializes as `"2.5"`. The fix is `Number(...)` at the assertion site, NOT changing the input.

### BigInt — explicit conversion before any arithmetic

```typescript
// ❌ "9007199254740993" + 1 = "90071992547409931" (string concat)
const total = count + 1n  // crashes — bigint + string
// ❌ "9007199254740993" + 1 = "90071992547409931" (also wrong)
const total = Number(count) + 1  // loses precision if > 2^53

// ✅ Keep as BigInt on the wire, convert only when necessary
const total = BigInt(count) + 1n
```

### DateTime — usually safe but watch for arithmetic

ISO 8601 strings are **valid** Date constructor input, so `new Date(apiResponse.createdAt)` works. The gotcha is when you forget:

```typescript
// ❌ String method on what looks like a Date
const today = workLog.date.getTime()  // TypeError: getTime is not a function

// ✅ Coerce first
const today = new Date(workLog.date).getTime()
```

### Bytes — decode from base64 if you need binary operations

```typescript
// ❌ "aGVsbG8=" treated as binary
const bytes = Buffer.from(att.bytes)  // works, but check
// Or in browser:
const decoded = atob(att.bytes)
const bytes = new Uint8Array(decoded.length)
for (let i = 0; i < decoded.length; i++) bytes[i] = decoded.charCodeAt(i)
```

## Prevention

### At the API design layer
- Create separate DTO types for API responses rather than returning Prisma models directly. DTOs should convert Decimals to numbers, BigInts to strings-or-numbers, Bytes to base64, etc.
- Document which fields need conversion in the API.md or a `wire-types.md` file.
- Consider using a serialization helper like `superjson` or a custom Elysia response transformer that handles these types consistently.

### At the test layer (highest ROI for catching)
- For every Prisma field that comes back as a string, the test that consumes it must either:
  - Coerce explicitly (`Number(x)`, `new Date(x)`, `JSON.parse(x)`)
  - Compare as string (`expect(x).toBe("2.5")`)
  - Use a matcher that handles both (`expect(x).toEqual(expect.anything())`)
- Add a "wire shape smoke" test that POSTs a known value, GETs it back, and verifies **the JS type** of each field is what the caller expects.

### Verification recipe

```bash
# Inspect actual API response shape
curl http://localhost:3000/api/worklogs | python3 -c "
import sys, json
data = json.load(sys.stdin)
log = data['workLogs'][0]
for k, v in log.items():
    print(f'  {k}: type={type(v).__name__}  value={v!r}')
"
```

Expected output for a Prisma `Decimal` field:
```
  hours: type=str  value='2.5'
```
The string type tells you immediately you need `Number()` at the consumer.

## E2E Test Pattern (Playwright / API test)

```typescript
test('POST /worklogs preserves hours', async ({ request }) => {
  const res = await request.post('/api/worklogs', {
    headers: { Authorization: `Bearer ${token}` },
    data: { taskId, hours: 2.5, workDate: '2026-06-08' },
  })
  expect(res.status()).toBe(200)
  const { workLog } = await res.json()
  // ⚠️ Prisma Decimal serializes as "2.5" — Number() required
  expect(Number(workLog.hours)).toBe(2.5)
})
```

### Playwright Critical Path 全鏈條嘅 normalize pattern(2026-06-08 pm-system)

如果個 happy path 入面 POST /projects / /requirements / /tasks / /worklogs 全部 derive 自 Prisma model,
要喺 E2E test 嘅 response parse 階段 wrapper 一層 normalize helper:

```typescript
// 唔好喺每個 expect() 散 Number(),集中喺 parse
const body = await res.json()
const normalized = {
  workLog: { ...body.workLog, hours: Number(body.workLog.hours) },
  task: body.task,
  // ...
}
expect(normalized.workLog.hours).toBe(2.5)
```

**或者** 喺 request stage 預期 string,直接 `expect(workLog.hours).toBe("2.5")` —
比較字面值 stable,避免 Number() precision 失真(Decimal 精度 > number)。

## 進階 case:BigInt arithmetic over REST

如果 backend 用 BigInt(eg. 大量 token count),前端 唔可以直接 `total + 1n`
(API 回 string)。**正確做法**:用 `BigInt(count) + 1n` 顯式 cast,絕對
唔好用 `Number(count) + 1`(precision 失真 if > 2^53)。

```typescript
// E2E test
const total = (await res.json()).totalTokens  // string from Prisma BigInt
expect(total).toBe("9007199254740993")  // string comparison safe
// Or arithmetic:
expect(BigInt(total) + 1n).toBe(9007199254740994n)
```

## Files Commonly Affected

- `backend/src/routes/*.ts` — responses with Decimals (worklogs, quotations, amounts, rates, prices)
- `frontend/src/pages/*` — list / detail views that render Decimals
- `frontend/src/utils/api.ts` — typed response wrappers (must declare string-or-number union)
- E2E tests that post and verify numeric values

## Related

- `prisma-sqlite-bun-setup` — covers Prisma 5 vs 7 + SQLite-specific gotchas (Json field stored as String, etc.)
- `prisma-relation-debugging` — relation field name drift, different from this shape drift
- `debugging/patch-route-field-silently-dropped` — when a field is sent but silently disappears (different bug class)
