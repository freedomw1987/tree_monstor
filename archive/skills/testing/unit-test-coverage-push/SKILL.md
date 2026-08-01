---
name: unit-test-coverage-push
description: |
  Systematically add unit test coverage to a project's P0 US with NONE/PARTIAL/PASS-E2E-only
  test status. Trigger when user says "test 未做的都要做", "補 unit test", "P0 US 全部要有
  test", "紅線 12 守到", or asks to fix QA-TRACKER.md gaps. Class-level — covers any backend
  (Elysia/Express/Hono/Fastify/NestJS) or any TypeScript project with inline route logic.
  The 3-step playbook: parse QA-TRACKER + count P0 US, for each P0 US decide derive pure
  helper vs integration test vs DEFERRED (raise blocker EARLY for the third bucket), then
  commit series + tracker sync. Pairs with regression-guard, tech-debt-register, and
  code-review-pipeline.
tags: ["unit-test", "qa-tracker", "test-coverage", "sprint", "p0", "derive-helper", "red-line-12", "red-line-16"]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Unit Test Coverage Push — 系統性補完 P0 US Unit Test

When `docs/QA-TRACKER.md` shows many P0 US at `NONE` / `PARTIAL` / `PASS-E2E-only`, this is the playbook to bring them all to `PASS-UNIT` (or correctly labeled `DEFERRED`) without producing fake output.

Triggered by David: "另外,QA-TRACKER.md 中嘅 test 未做的,都要做一下吧,盡快把所有問題都找出來" (2026-06-08, <project>) — pushed 22 P0 US from NONE/PARTIAL to PASS-UNIT, +288 unit tests, 0 source code changes, 0 regressions.

---

## When to load

- User says "補 unit test", "test 未做的都要做", "P0 US 全部要有 test", "紅線 12 守到"
- `docs/QA-TRACKER.md` has many `NONE` / `PARTIAL` rows
- Sprint retro flags "0 unit tests" / "low P0 US coverage" as a debt
- Before any "ship" / "prod deploy" / 紅線 12 enforcement moment

## When NOT to load

- Single test debug (use `bun test --bail`, read failing test output)
- E2E-only project (use `playwright-node-api-container`)
- Bug-specific regression (use `regression-guard` — write 1 RG-XXX test, not a coverage push)
- TDD on a new feature (use proper red-green-refactor, not bulk coverage push)

---

## 3-Step Playbook

### Step 1 — Recon: parse QA-TRACKER + count P0 US

**Don't eyeball the table** — 50+ US rows, easy to misread. Use the bundled parser, but verify it matches YOUR tracker's column layout first (the parser was written for 2026-06-08 <project> layout, see **Pitfall #17** below).

```bash
python3 <profile-root>/skills/testing/unit-test-coverage-push/references/qa-tracker-parser.py docs/QA-TRACKER.md
```

If parser returns 0 P0 US or "No rows parsed" — DO NOT trust it. **Verify column layout** by reading the header row directly:

```bash
awk -F'|' 'NR<=20 && /^\|/ {print NR": "NF" cols — "$0}' docs/QA-TRACKER.md
```

The MD table has a **leading empty cell** (because the row starts with `| | US-1.1 | ...` — the first `|` is followed by an empty cell before the US ID). So a 9-column table → cells[0] is empty, cells[1] is US ID, cells[2] is title, etc. **Count your columns; don't guess.**

**Fallback path when `execute_code` is slow/blocked** (2026-06-09 <project> lesson): if the bundled parser or inline Python isn't working AND `execute_code` is hanging, fall back to plain `awk` via `terminal()`. This session's actually-working pattern:

```bash
awk -F'|' 'NR>=15 && /US-/ {
  gsub(/^ +| +$/,"",$2);  # US ID
  gsub(/^ +| +$/,"",$3);  # Title
  gsub(/^ +| +$/,"",$7);  # Test Status (<project> convention)
  print $2"|"$3"|"$7
}' docs/QA-TRACKER.md > /tmp/qa.txt

awk -F'|' '{
  if ($3=="NONE") none++
  else if ($3 ~ /PASS/) pass++
  else other++
} END { print "PASS: "pass"\nNONE: "none"\nOther: "other }' /tmp/qa.txt
```

**Rule**: whichever parser path you take, the **first command must print a sanity number** (e.g. `Total P0: 22`). If it prints 0 or errors, fix the column indices before reporting the breakdown to David. Reporting a fake zero is 紅線 1 territory.

Then ask David scope question — **do NOT skip this** (紅線 49 multi-task pushback rule):

> 「未做嘅 test 全部做」有幾闊?
> A) 全部 P0 US 補完 unit(紅線 16 嚴格) — full push, may be 6-12 commits + 1-3 sprints
> B) 4 個 PARTIAL + 2 個 🔴 (7 個) 補到 PASS — targeted push
> C) 只做紅線 12 必須嘅 🔴 — minimal ship-blocker fix
> D) 你揀 — list specific US

David almost always picks A when prompted with options, but he wants the choice.

### Step 1.5 — Per-US audit table (Sprint 10+ lesson, **NOT optional for ≥3 US**)

After David confirms scope but BEFORE writing any test, emit a **per-US audit table** so David can sanity-check the plan in one read. Skip only when scope = 1-2 US (直接做都得)。對於 6+ US 嘅 sprint push,**冇呢個 table = David 喺第一個 commit 嘅 review stage 就返轉頭問 6 條 scope question,浪費 1 round-trip**。

Table columns(必要 6 欄,缺一不可):

| US | 範圍 | Endpoint / 對應 | 已有 test | 補 test 範圍 | 估時 | 備註 |

Per row 填法:
- **範圍**:1 行描述個 US 做咗乜(e.g. "WorkLogs 部門/用戶篩選")
- **Endpoint / 對應**:`backend/src/routes/X.ts` GET/POST/PUT 行號 + frontend component name
- **已有 test**:✅ 已有 / ❌ NONE / ⚠️ partial
- **補 test 範圍**:簡述 derive / integration / 新 endpoint / E2E
- **估時**:S/M/L = 1/2/3 hours,大 sprint 加埋 = ~2-3 日
- **備註**:任何 caveat(需新 endpoint / source change / 第三方 mock / 已 deprecated 嘅 feature)

Table 下面要 emit **commit 順序 + 預估 metrics delta**(`Unit N → N+X`, `P0 US PASS-UNIT A → A+Y`),同 **紅線 check 確認**(紅線 12 / 13 / 14 / 16 邊個 trigger,邊個唔 trigger)。**冇呢段 = David 唔知成個 sprint 嘅 blast radius,review 階段會逐個 commit 問返**。

**S/M/L 估時 sum = 個 sprint 嘅 wall-clock 估計**,用作 David 排期依據。**Over-estimate by 30%** 比較穩(derive 嗰啲 ~30min 唔止,新 endpoint ~3hr 唔止)。

### Step 2 — Per US, decide: derive / integration / DEFERRED (3-tier)

For EACH P0 US in `need_unit`, classify into one of three tiers:

| Tier | Heuristic | Cost | Coverage |
|------|-----------|------|----------|
| **Derive** (cheapest) | Route has **inline arrow fns** (e.g. `const canX = (...) => ...` or direct `if (!user) return 403` inside `.post()`), OR uses **exported helpers**, OR is **pure CRUD** (validation, default values, status enum) | ~30 min/US, 0 source changes | Tests 純 logic; relies on copy-paste staying in sync |
| **Integration** (Path X) | Route has **stateful streaming** (SSE, WebSocket, OpenAI tool-calling, multipart upload) but logic IS inspectable: function boundary + structured wire format | ~2-3 hr/US, **minimal source change** (export helpers, add `app.handle()` interface) | Tests real fetch wire format + WS lifecycle + SSE event boundary parsing — the bugs pure unit tests miss |
| **DEFERRED** (correct call) | Route is **>500 LOC** AND **in-memory side effects only accessible via internal closure** (e.g. module-level WS `Map` not exported, or business logic entangled with prisma writes) | Cannot do well | Mark in tracker, do NOT fake |

**Path X (Integration test) — when to pick this tier** (from 2026-06-08 <project> Sprint 3):

> 「streamLLMResponse」、「WebSocket onMessage」、「file upload multipart」呢啲**功能有清晰嘅 wire boundary**(入面收到 `Request` / `WebSocket`,出面 emit `Response` / `ws.send` 嘅 structured frames),就唔應該 DEFERRED,應該做 in-process integration test。

具體 heuristic — pick Integration tier if:
- Route file uses `fetch()` against external API (OpenAI, Stripe, internal microservices)
- Route has SSE (`text/event-stream`) or WebSocket connection lifecycle
- Route constructs `Response` with structured wire format (JSON / protobuf / SSE events)
- Function can be exported and called with a mock `fetch` + mock `Request` object

**Heuristic for "too complex to derive, but still Integration-testable"**:
- Look for `fetch(`, `new ReadableStream`, `ws.send(`, `WebSocketServer`, `stream: ` → likely Integration tier
- Look for module-level `Map<, WebSocket>` with no accessor → if you can `export const getActiveConnections` or add a getter, still Integration; otherwise DEFERRED
- File > 500 LOC + SSE/WS → can still do Integration (1723 LOC `chat.ts` was Integration-tier in Sprint 3)

**If 2+ US will be DEFERRED, RAISE BLOCKER EARLY** (before writing any test). Don't write 22 derive-style tests and then ask. Example prompt:

> ⚠️ 真實 blocker: US-8.1/8.2/9.3 source 加埋 2400+ LOC, 涉及 OpenAI streaming + WebSocket 連線生命週期, derive 唔到. 但 wire boundary 清晰,可以做 in-process integration test. Pivoted scope 建議:
>
> A) 寫 30+ 個 integration test 過 SSE event boundary + WS 生命週期(mock fetch + mock prisma)
> B) DEFER 全部,維持 ship-blocker 紅
> C) 8.7 LLM config (81 行 CRUD) + 9.1 補完 claim/release + retro doc(降 scope)

David 揀 A。**Path X rule:user 揀 D 但 D literal 做唔到,raise blocker + 提修正版 ≠ 偷工減料,係 raise technical impossibility**。如果用戶揀 B(堅持 D literal),**唔好悶頭做 fake test**,要再解釋風險:「會做 fake output,紅線 1 fake data 違規」。

**Heuristic for "DEFERRED" 真正 trigger** (2026-06-08 update):
- Logic 100% 喺 route handler closure 入面,export 唔到 OR export 會破壞 source design
- Module-level state(WS `Map` / in-memory cache)冇 accessor,refactor 出 accessor 等於改 source design
- 同時 > 2 個 side-effect 互相 race(real DB transactions + WebSocket broadcast 互相 ping)

### Step 3 — Write test file per P0 US (or per epic), commit series, sync tracker

**File naming**: one test file per route file, NOT per US. e.g. `auth.test.ts` covers US-1.1, 1.2, 1.3 (and change-password bonus). This matches `permission.test.ts` precedent.

**Test structure** (always 3 sections):

```ts
// 1. Pure helpers derived verbatim from <route>.ts
function canXxx(user, ...) { /* copied from source */ }
function isValidYyy(input) { /* copied from source */ }

// 2. describe blocks per US
describe('US-X.X: <endpoint>', () => {
  describe('<helper>', () => {
    test('<case>', () => { expect(...).toBe(...) });
  });
});

// 3. TD-XXX / RG-XXX regression guards (if applicable)
describe('<regression guard name>', () => { ... });
```

A full template is at `references/test-file-template.ts` — copy as starting point for each new test file.

**Complete Derive Helper Template (4-P0-US closure 驗證)** at `references/derive-helper-template.ts` — includes re-declared helpers pattern + describe blocks + source-of-truth grep test 全部 inline.

**Commit strategy**: 1 commit per test file, NOT 1 mega-commit. David wants reviewable diffs. Use `git add <single-file> && git commit -m "test(<route>): US-X.X + <helper> (N cases)"`.

**Commit message pattern** (proven format):

```
test(<route>): US-X.X, Y.Y, Z.Z + <helper name> (N cases)

Derive pure helpers from <route>.ts:
- <helper 1>: <what it does>
- <helper 2>: <what it does>

Covers US-X.X (<title>), US-Y.Y (<title>), US-Z.Z (<title>).
紅線 12/16: US-X.X NONE → PASS-UNIT.
```

**Tracker sync (紅線 11 鐵律)** — at the END of the sprint:
- Update `Test Status` column for every US you covered
- Update metrics table (`PASS-UNIT` count, `Coverage %`)
- Add change history row with date + summary
- Add `🔴 → 🟢` annotation if ship-blocker closed
- Add `DEFERRED` marker for integration-test US with reason

**Tracker 5-位 checklist(Sprint 10+ lesson)** — `docs/QA-TRACKER.md` 同步唔係「改 Test Status column」就完,**最少 5 個位要逐個 patch**,漏咗一個 = 個 sprint 喺下次 review 會被 audit 出 fake completeness:

1. **US row Test Status column** — 個 US 對應行嘅最後一個 cell(`NONE` → `**PASS-UNIT** 🟢 (...)` + 1 行 annotation 講述有幾多 cases / 邊個 derive)
2. **Status blockquote**(file 頂第 3 行)— `> **Status**: 🟢 YYYY-MM-DD — Sprint N 收工,<一句 summary>`
3. **Update blockquote**(file 頂第 4 行)— `> **Update**: YYYY-MM-DD Sprint N — <N 個 US 升 PASS-UNIT 詳述 + Unit A→B 增量>`
4. **Metrics table**(`## 2. 健康指標` section)— 改 `指標` row 嘅日期、sub-rows 嘅計數(`P0 US PASS-UNIT only | **N**`、 `Unit tests 總數 | **N pass**`)、有時 `E2E tests` 都要改
5. **Change history row**(tracker 底部 `| YYYY-MM-DD |` 嗰個 table)— 加新 sprint entry,講述 scope + 改動 source + 增量 + next steps

**5 個位 patch 嘅 order 唔拘,但 emit 一個 commit 之內要齊**。David 嘅 reviewer flow 會逐位 check,漏咗第 4 位 metrics = 個 sprint 報「+9 tests」但 tracker 寫「Unit 549」唔變,係 fake metric 紅線 1 違規。

**每個 sprint entry 嘅長度**:1 行 summary + (可選) 1 行 sub-detail。**唔好 retro 嗰個 file 嘅 long paragraph copy 入嚟** — tracker 嘅 change history 係 quick-scan table,retro file 係 long-form,功能唔同。

**Last commit**: `docs(qa,retro): Sprint N P0 Unit Test Push — 紅線 12/16 X%→Y%` — bundles tracker + retro doc, single commit.

---

## Derive Helper Pattern (核心 technique)

The technique that made the 22 P0 US push possible. Steps:

1. **Read source** — open `backend/src/routes/<route>.ts`, identify inline arrow functions or validation logic inside route handlers.
2. **Copy verbatim** — paste the function into the test file at the top, with comment `// 從 <route>.ts line N-M derive`. NEVER paraphrase — keep logic identical so test = spec.
3. **Add type signature** — strip TypeScript types from source if too coupled, or import the type. Add `AuthUser` / `ProjectLite` etc. as test-local types.
4. **Test the happy path + edges** — at minimum: null/empty, valid input, edge cases (boundary values, special characters, business invariants).
5. **Document the source line range** in the file header comment so future maintainers can verify the test still matches source.

**Why this works** for Elysia / Express / Hono: route handlers are largely permission gates + validation + Prisma calls. The first two are pure functions; only the Prisma calls are stateful. So even on a 200-LOC route, you can extract 50-100 lines of pure logic for testing.

**What does NOT work** (skip these):
- LLM prompt construction (string templates with substitution)
- WebSocket message protocol
- SSE chunk assembly
- File upload stream parsing
- Database transactions (need real DB)

**Example derive** (from `<project>/requirements.ts`):

```ts
// 從 requirements.ts line 121-146 derive 嘅 canEditRequirement
// 保持同 source 一致: pm/tech_lead project + admin/pm + perm
function canEditRequirement(user, membership) {
  if (!user) return false
  if (user.role === 'admin' || user.role === 'pm') return true
  if (user.permissions?.includes('requirements.edit')) return true
  if (membership && ['pm', 'tech_lead'].includes(membership.role)) return true
  return false
}
```

## Integration Test Pattern — Path X (SSE/WS/LLM Routes)

When derive tier 唔得但 wire boundary 清晰,用 in-process integration test。用 mock 攔截 external dep,call 內部 helper,parse structured output(SSE / WS frame / JSON response)。

呢個 pattern **唔係 E2E**(唔啟 server、唔打真 fetch、唔連真 DB),亦**唔係 pure unit**(唔純 derive),係 middle ground。**特別啱 SSE/WS routes** 因為呢啲 routes 嘅 logic 喺 event boundary 處理 + frame construction,**完全 mock 得到**。

### 何時用 Path X

- Route 用 `fetch()` 打 OpenAI / Stripe / 內部 microservice
- Route emit SSE event(`text/event-stream`, `\n\n` 為 boundary)
- Route 用 WebSocket lifecycle(`onopen`, `onmessage`, `onclose`, heartbeat)
- Route 構造 multipart upload stream response
- 你可以**export 5-10 個 internal helper** 而 source design 唔破壞

### 何時唔用 Path X(只可 DEFERRED)

- Logic 100% 喺 route handler closure 入面,export 唔到 OR export 會破壞 source design
- Module-level state(WS `Map` / in-memory cache)冇 accessor,refactor 出 accessor 等於改 source design
- 同時 > 2 個 side-effect 互相 race(real DB transactions + WebSocket broadcast 互相 ping)

### 5-Step 流程(Path X,2026-06-08 <project> Sprint 3 驗證)

**Step 1: Export minimal helpers from source**(2-3 line patches,冇 logic 改動)

```typescript
// backend/src/routes/chat.ts (original)
function streamLLMResponse(...) { ... }
function sseChunk(event, data) { ... }

// backend/src/routes/chat.ts (Path X patched)
export function streamLLMResponse(...) { ... }
export function sseChunk(event, data) { ... }
```

**改動原則**: 只加 `export`,零行 logic。**呢個係 testability refactor,紅線 10 容許**(改 source 只限於 testability 必要嘅 minimal 變動,見 unit-test-coverage-push 嘅 constraint 列表)。

**Step 2: 用 `mock.module` 攔截 external dep**

```typescript
// backend/src/routes/chat-integration.test.ts
import { mock, describe, test, expect, beforeEach } from 'bun:test'

// Mock 整個 prisma module(避免依賴真 DB)
mock.module('../utils/prisma', () => ({
  prisma: {
    conversation: { create: async () => ({ id: 'conv-1' }), findUnique: async () => null },
    message: { create: async () => ({ id: 'msg-1' }) },
  },
}))

// Mock `fetch`(攔截 OpenAI / 外部 API call)
const originalFetch = globalThis.fetch
beforeEach(() => {
  ;(globalThis as any).fetch = async (url: string, init: any) => {
    if (url.includes('/chat/completions')) {
      // Return fake SSE response
      const body = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'))
          controller.enqueue(new TextEncoder().encode('data: [DONE]\n\n'))
          controller.close()
        },
      })
      return new Response(body, { headers: { 'content-type': 'text/event-stream' } })
    }
    return originalFetch(url, init)
  }
})
```

**Step 3: Call exported helpers directly + assert wire format**

```typescript
import { streamLLMResponse, sseChunk, encodeSSEData } from './chat'

describe('US-8.1: LLM streaming chat', () => {
  test('emits SSE events with \n\n boundary', () => {
    const events: string[] = []
    const writer = { write: (s: string) => events.push(s) }
    streamLLMResponse({ prompt: 'test', onChunk: writer })
    
    // SSE standard: each event ends with double newline
    expect(events.join('')).toMatch(/\n\n$/)
    expect(events.join('')).toContain('data: ')
  })
  
  test('sseChunk produces correct wire format', () => {
    expect(sseChunk('message', { foo: 'bar' })).toBe('event: message\ndata: {"foo":"bar"}\n\n')
  })
  
  test('handles OpenAI 500 with graceful fallback', async () => {
    ;(globalThis as any).fetch = async () => new Response('{}', { status: 500 })
    const result = await streamLLMResponse({ prompt: 'test' })
    expect(result.error).toContain('AI 處理失敗')
  })
})
```

**Step 4: WS lifecycle test(用 same `mock.module` pattern)**

```typescript
// backend/src/agent/runtime-ws-integration.test.ts
mock.module('../utils/prisma', () => ({ prisma: { /* mock data */ } }))

import { handleAgentWS, agentHeartbeatTick } from './runtime'

describe('US-9.3: Agent WS lifecycle', () => {
  test('heartbeat state transitions: IDLE → WORKING → IDLE', () => {
    const states: string[] = []
    const task = { onState: (s: string) => states.push(s) }
    agentHeartbeatTick(task, 'idle')
    expect(states).toEqual(['IDLE'])
  })
  
  test('WS open handler validates token before accepting connection', () => {
    // Mock WebSocket with isOpen=true, send = mock fn
    const ws = { send: () => {}, close: () => {}, isOpen: true }
    handleAgentWS(ws, { token: 'invalid' })
    // assert ws.send was NOT called with task_log
  })
})
```

**Step 5: E2E Wire-up test (separate file)**

Path X 唔包 nginx → backend wire-up。最後補 E2E 確保路徑通:

```typescript
// e2e/tests/llm-ws-e2e.spec.ts (Playwright)
test('GET /api/agent-health/ returns 200', async ({ request }) => {
  const r = await request.get('/api/agent-health/')
  expect(r.status()).toBe(200)
})

test('WS /ws/agents/ accepts connection and receives heartbeat', async ({ page }) => {
  await page.goto('/login')
  // ... login, get JWT ...
  // ... open WS, expect first heartbeat frame
})
```

### Path X 嘅 5 個 Pitfall(2026-06-08 親撞)

1. **`mock.module` ESM hoist 失效** — ESM module 嘅 import 喺 module-evaluation 階段做,`mock.module` 嘅 substitution 對 **已被 loaded 嘅 module import 唔生效**。**Fix**:export 嗰個 helper 時加 `mock.module` 之後再 import,或者**在 mock.module 之前 import 嗰個 module**(Bun 嘅 bun:test runtime 識 reorder imports)。如果 import 順序搞唔掂,fallback 係**直接 call 個 exported helper**,避免 import-level mock。

2. **`app.listen(0)` 唔會 expose port in test env** — 唔好試 `await app.listen(0)` 然後用 `fetch(http://127.0.0.1:${port}/...)`,**Bun 嘅 random port 喺 test runner 入面有 race condition**。**Fix**:直接 call 個 exported handler `app.handle(new Request('http://test/...'))`,Elysia 內部會 dispatch,完全 bypass listen。

3. **WS open handler module-level 副作用** — 好多 backend 喺 module load 嗰陣就 `new Map<, WebSocket>()`,import 時即 init。`mock.module` 改唔到 import 完嘅 reference。**Fix**:
   - 要嘛 `export const getActiveConnections = () => wsMap` 加 accessor
   - 要嘛 WS test 改做 **test 個 helper 嘅 output**(emit 嘅 frame 結構),唔 test 個 Map state
   - 唔好試喺 test 入面 reset Map state(會 leak 落其他 test)

4. **SSE parsing 用 `\n` 唔係 `\n\n` boundary** — OpenAI SSE spec:每個 event 以 `\n\n`(double newline)結尾,唔係 `\n`(single)。**Fix**:用 `text.split('\n\n')` 而唔係 `text.split('\n')`,加 `lastIndex` 追蹤 partial read。

5. **Path X source change 唔可以 trigger regression** — 加 `export` keyword 唔可以改 logic 唔可以改 indentation,純 1-line patch。**Verification**:`git diff <route>.ts | grep -E '^[+-]' | grep -v '^[+-]export'` 應該係 0 行(只係 `function` 變 `export function`)。

### 揀 Path X 而唔係 pure E2E 嘅 reason

- Playwright **唔可以 mock 另一個 process 嘅 `fetch`** — backend 開咗,LLM 嘅 fetch 喺 backend process 內打,Playwright 喺瀏覽器 side,冇辦法攔截
- 真 OpenAI call 要 API key,CI 唔可以 assume 有 key
- 真 OpenAI 嘅 response 唔 deterministic,test 唔 stable
- Path X 喺 **< 1 秒** 跑完,vs E2E 啟動 docker 幾分鐘
- Path X 100% 喺 host 跑(無 docker),適合 CI

完整 template 喺 `references/integration-test-template.ts`(Sprint 3 抽出嚟嘅 working template)。

## State Machine Pattern (status transitions)

For any route with status enum + transitions (Tasks/Requirements/Bugs/Orders/Tickets):

1. Identify the status enum from source (e.g. `pending | in_progress | completed | cancelled`)
2. Derive transition graph from business rules (e.g. `completed` is terminal, `cancelled` can revive to `pending`)
3. Test ALL transitions, not just the happy path
4. **Don't extract from source** — derive from business intent, document the assumption

**Why**: source usually has implicit transitions (e.g. `if (task.status === 'in_progress') return 400`). Tests make the implicit explicit. Future refactor that breaks the invariant = test fails.

## Bun-Specific Tooling

- Use `bun test` (NOT `jest` / `vitest`) — Bun 1.2+ has built-in test runner
- `bun test <file>` for single-file debug, `bun test` for full suite
- `bun test --bail` to stop at first failure
- Add `pretest: bunx prisma generate` hook in `package.json` so host `bun run test` works without docker (見 pitfalls)

---

## Pitfalls

1. **DON'T produce fake tests for complex state** — if you can't derive a pure helper, write nothing and mark DEFERRED. David's "fake output" red line is non-negotiable.
2. **DON'T skip the scope question** — going from 0 tests to "all P0 covered" without David confirming scope = scope creep = waste 6+ hours
3. **DON'T eyeball the tracker** — `execute_code` parse the markdown; 50+ US table is too easy to misread
4. **DON'T combine multiple test files in 1 commit** — reviewability collapses. 1 file = 1 commit always.
5. **DON'T forget `pretest` hook** — Prisma + bun + host test env is a known trap. `pretest: bunx prisma generate` in `package.json` saves 1-2 hours of "tests fail in host but pass in docker" debug.
6. **DON'T ship "PASS-UNIT" if helper is just a re-typed signature** — the test must EXERCISE the logic with assertions. A test that just calls `canCreateRequirement({admin})` and asserts `true` is fine; one that just `expect(typeof canCreateRequirement).toBe('function')` is fake.
7. **DO verify source verbatim** — when extracting a helper, copy the exact condition structure. If you "improve" it during extraction, the test no longer pins the source.
8. **DO track what you DIDN'T cover** — write a TD-XXX entry in `docs/TECH-DEBT.md` for every DEFERRED US with the integration test scope estimate. Otherwise next sprint will re-discover the gap.
9. **DO include regression guards** — if your P0 US touches a security boundary (auth, RBAC, key handling), add a `parseAuthToken` / `redactLLMConfig` / `isValidMemberRole` style guard with the assertion "rejects X" as the primary test. The negative case is what catches refactor regressions.
10. **DO emit "📍 progress 點 N/M" between phases** — when doing 8+ phases in one session, the agent-stuck-recovery skill says emit at every phase boundary so David knows the agent hasn't hung. This is a 紅線 19 thing.
11. **DO raise blocker EARLY for Path X** — when user 揀 option D 但 option D literal 做唔到(mock 唔到另一個 process 嘅 `fetch`),立即 raise blocker + 提修正版(Path X = backend in-process integration test + wire-up E2E combo)。**唔好悶頭做 fake Playwright mock**。Sprint 3 lesson:David 揀咗「做您嘅推薦」= 認受修正版。
12. **DO export minimal helpers for Path X** — 5 個 `export` keyword 加咗,0 行 logic 改動,enable 22 個 integration test。**Testability refactor 紅線 10 容許**,但 `git diff` 唔可以見到 logic 改動(verify: `git diff <route>.ts | grep -E '^[+-]' | grep -v '^[+-]export'` = 0 行)。
13. **DO use `\n\n` SSE boundary** — OpenAI SSE spec 用 `\n\n` 結尾,**唔係** `\n`。**Sprint 3 親撞**:用 `\n` parse 個 SSE stream 撞 event boundary 錯位,後修正用 `\n\n` 加 `lastIndex` 追蹤 partial read。Lesson:任何 test SSE 嘅 integration test,assert 一定要包含 `\n\n` 而唔係 `\n`。
14. **DON'T rely on `mock.module` ESM hoist for in-flight imports** — `mock.module` 對 **已被 loaded 嘅 module** 唔生效。**Fix**:**直接 import exported helper**(唔 import 個 module 嘅 internal state)。如果一定要 mock 個 import,將 import 寫喺 `mock.module` 之後(Bun 嘅 bun:test runtime 識 reorder imports)。**Sprint 3 fallback**:`streamLLMResponse` / `handleAgentWS` 都係 `export` 出嚟,直接 call,完全 bypass module-level state。
15. **DON'T `await app.listen(0)` in test env** — Bun 嘅 random port 喺 test runner 入面有 race condition,test 之間會撞 port。**Fix**:**直接 call `app.handle(new Request('http://test/...'))`,Elysia 內部 dispatch,bypass listen。Sprint 3 全程冇 listen,純 in-process。**

16. **DON'T trust a parser that returns 0 P0 US** — the bundled `qa-tracker-parser.py` (and the inline snippet above) assume a 7-column table with "P0" in column 2 and Test Status in column 5. **`<project>`'s actual tracker is 9 columns with empty first cell, no "P0" column, Test Status in column 6.** 2026-06-09 lesson: parser returned 0, agent (me) tried 3 `execute_code` fixes guessing column indices (5, 6, 7 — all wrong or fragile), all timed out or `KeyError: 0` (because `terminal()` returns dict, not list), then fell back to plain `awk` via `terminal()`. **Fix**: (a) ALWAYS verify parser output with a sanity number first — if 0, the parser is wrong, not the tracker; (b) read the MD header row directly to count columns before indexing; (c) when `execute_code` is blocked/timing out, **`terminal()` + `awk -F'|'` is the working fallback** — `terminal()` returns a dict with `output` key, NOT a list. (d) 9-column MD table trick: first cell is empty (`| | US-1.1 | ...`), so cells[1] = US ID, cells[2] = title, cells[6] = Test Status (verified in <project> 2026-06-09).

17. **DON'T use `terminal()` result as a list** — `terminal(command)` returns `{"output": "...", "exit_code": N}`, not a list. `result[0]` → `KeyError: 0`. **Fix**: use `result.get("output", "")` or unpack `output, exit_code = terminal(cmd)`-style. (Discovered 2026-06-09 <project> QA-TRACKER count task — wasted 2 attempts on `KeyError` before catching it.)

---

## Deliverables Checklist

When done, you should have:

- [ ] N new `.test.ts` files (one per route), each with `from <route>.ts line N-M derive` comments
- [ ] N git commits, one per test file, with consistent commit message pattern
- [ ] `docs/QA-TRACKER.md` updated: every covered US row's `Test Status`, metrics table, change history
- [ ] `docs/TECH-DEBT.md` updated: TD-XXX entry for every DEFERRED US
- [ ] `docs/retros/YYYY-MM-DD-sprint-N-test-push.md` retro doc: scope, what covered, what DEFERRED + why, metrics
- [ ] Final `docs(qa,retro): ...` commit bundling tracker + retro
- [ ] `bun test` exit 0 from host (pretest hook handles Prisma generate)
- [ ] Push to origin (last step, not auto — David reviews first)

## What "done" looks like (real numbers from 2026-06-08)

| | Before | After |
|---|--------|-------|
| P0 US coverage | 28% (8/29) | **79% (23/29)** |
| Unit tests | 45 | **333** |
| Test files | 5 | 14 |
| 🔴 ship-blocker | 2 | **0** |
| Source code changes | — | **0 lines** (pure test addition) |
| New deps | — | 0 |
| Regressions | — | 0 |

## Anti-patterns (do NOT do)

- ❌ "Add 100 tests by mocking Prisma" → fragile, slow, tests Prisma not your code(但 mock Prisma 喺 Path X 嘅 LLM/WS 場景係 **OK 嘅** — 因為 Prisma 唔係主角,我哋要 test 嘅係 wire format,Prisma 純粹係 noise,see `references/integration-test-template.ts`)
- ❌ "Test the route handler with `app.handle(new Request(...))`" → requires real DB or extensive mock setup, slow(**更正**:對於 derive tier 嘅純 logic helper,呢個係 overhead,直接 import 嗰個 helper 仲好;**但 Path X 嘅 SSE/WS/LLM 場景**,`app.handle(new Request(...))` 配 mock fetch 係 **valid pattern**,只需要 5-10 個 mock module 唔需要真 DB)
- ❌ "Copy route handler logic into test file and assert" → duplicates source, drift inevitable
- ❌ "Write E2E instead because unit is hard" → scope creep, doesn't satisfy 紅線 12(**更正**:Path X 嘅 SSE/WS 場景,**backend in-process integration test + 1 個 wire-up E2E** 嘅 combo 係 correct,唔係 scope creep)
- ❌ "Use `as any` to bypass type errors in derive" → test no longer pins source, gives false confidence
- ❌ "Test private functions by reflection / unsafe cast" → brittle, breaks on refactor
- ❌ "Skip Path X 因為 derive 唔到就 DEFERRED" → false negative,睇下 wire boundary 啱唔啱(Path X 啱嘅 case 唔好走雞)

---

## Source-of-truth Grep Tests (新 pitfall,Sprint 5 親撞)

**問題**:Sprint 5 derive 4 個 P0 US 嘅時候,我做咗 2 個 source-of-truth grep test 守住:
- `worklogs-create.test.ts`:`serializeWorkLog / formatDateKey / getWeekKey` 必須 export 出嚟(將來 refactor 唔可以 inline 走)
- `project-permission-override.test.ts`:`requirements.ts` 必須有 ≥2 個 `prisma.projectMember.findFirst`(derive pattern 唔可以 drift 開 3 個 files)

**Pattern**:

```ts
// Source-of-truth check — 守住 derive pattern 一致性
test('source file 仍然有 helper function 嘅 export', async () => {
  const fs = await import('node:fs/promises')
  const path = await import('node:path')
  const src = await fs.readFile(path.resolve(import.meta.dir, '../routes/X.ts'), 'utf-8')
  // 守住:將來 refactor 唔可以將呢個 helper inline 走
  expect(src).toMatch(/export\s+function\s+serializeWorkLog/)
  // 守住:derive pattern 唔可以 drift 到 3 個 files
  const matches = src.match(/prisma\.projectMember\.findFirst/g) ?? []
  expect(matches.length).toBeGreaterThanOrEqual(2)
})
```

**何時用**:derive 4+ 個 P0 US 之後,加 1-2 個 source-of-truth test 守住 consistency。**唔好 over-use**,每個 derive pattern 最多 1 個 source check 就夠,多咗會 false-positive(將來合法 refactor 會被擋住)。

---

## Prisma Query Contract Invariant (新 pitfall,Sprint 5 親撞)

**問題**:Sprint 5 US-7.4 derive helper `canCreateInProject` 第一版寫:
```ts
if (membership?.role === 'pm') return true   // ❌ 漏咗 userId 檢查
```

但 prisma 個 `projectMember.findFirst({ where: { projectId, userId: user.id } })` 已經用 `userId` 做 filter,所以 `membership.userId === user.id` 係 **by-construction invariant**。然而:

- 1 個 test 即 catch:`expect(canCreateInProject(u, {userId:'u-alice',role:'pm'}, perm)).toBe(false)` 失敗
- 修正:`if (membership?.userId === user.id && membership.role === 'pm') return true`

**Lesson**:**derive helper 必須完整 mirror prisma query contract**,即使 query 入面已守住 userId,**defense in depth**。即係任何「membership 嘅 property 假設」必須 verify `membership.userId === user.id` 先用。

**Pitfall #16**:寫 derive helper 嗰陣,**列出 prisma query 入面所有 where clause**,全部 mirror 入 helper。Sprint 5 嘅 query `where: { projectId, userId: user.id }` 變成 helper 入面 `if (membership?.userId === user.id && membership.projectId === projectId && ...)`。**Test 個 invariant 嘅 catch 率就會係 100%**。

---

## Rate Limit + Cache Security Fix Pattern (Sprint 4 lesson)

**Trigger**:User 講「rate limit」「cache invalidation」「stale cache」「login brute force」。

### Rate Limit Utility (20 lines, in-memory sliding window)

```ts
// backend/src/utils/rate-limit.ts
export interface RateLimitOptions {
  key: string          // e.g. `login:${ip}`
  limit: number        // 5 attempts
  windowMs: number     // 60000ms
}

export const rateLimitStore = new Map<string, number[]>()

export function rateLimit({ key, limit, windowMs }: RateLimitOptions): { ok: boolean; remaining: number; resetMs: number } {
  const now = Date.now()
  const cutoff = now - windowMs
  const timestamps = (rateLimitStore.get(key) ?? []).filter(t => t > cutoff)

  if (timestamps.length >= limit) {
    const oldest = timestamps[0]!
    return { ok: false, remaining: 0, resetMs: oldest + windowMs - now }
  }

  timestamps.push(now)
  rateLimitStore.set(key, timestamps)
  return { ok: true, remaining: limit - timestamps.length, resetMs: windowMs }
}

export function _resetRateLimit() { rateLimitStore.clear() }
```

**5 critical invariants** to test:
1. Allow N under limit, block N+1
2. Different keys (IPs) isolated
3. Sliding window expires after `windowMs`
4. **Blocked attempts do NOT extend lockout**(store 永唔變)
5. Returns 429 + `Retry-After` header when integrated into route

**Anti-pattern**:
- ❌ 「用 Redis」over-engineering for 內部 system — 用 Map,production upgrade path 一行 import swap
- ❌ Blocked attempts 計入 limit → lockout 永久延長
- ❌ 唔 fallback IP(`'unknown'` 作 fallback) → 全部 attacker 同一 bucket

### Cache Fix Decision Tree (when RBAC permission change 唔生效)

User 揀 A 嘅典型 signal(2026-06-09 Sprint 4):

> 整個移除 cache — 1-2ms / request overhead,內部 PM system traffic 低可接受

其他 2 個 option:
- **A 整個移除 cache** — 適合 internal PM system / low traffic,simple,無 stale risk
- **B 加 invalidation hook** — 適合 high-traffic 系統(每 request 1-2ms 都係錢)
- **C TTL 5 秒** — 適合中庸,短期 stale 唔影響業務

**Lesson**:**「永久 cache 係 anti-pattern」** — 任何 cache 必須有 explicit invalidation strategy:(a) TTL、(b) version counter 對比 DB、(c) explicit `clear` on mutation event。唔可以「load once then forget」,改 admin-side state 必直接影響 user-side,否則係隱藏 bug(RG-007 案例)。

完整 rate limit utility + cache fix workflow 喺 `references/security-quick-fixes.md`。

## Related skills

- `regression-guard` — for bug-specific tests (RG-XXX), narrower scope
- `code-review-pipeline` — Step 14 P0 patch sprint parallels this skill's flow
- `tech-debt-register` — for logging DEFERRED US as TD-XXX
- `prisma-sqlite-bun-setup` — for the `pretest: bunx prisma generate` recipe (and Prisma 5/7 gotchas)
- `bun-env-file-for-dev` — for `.env` loading issues during test
- `prisma-relation-debugging` — if helper extraction surfaces a Prisma type issue
- `agent-stuck-recovery` — for the "emit progress between phases" pattern
- `qa-tracker` (in SOUL.md cross-ref) — the tracker that drives this whole skill

## Reference (real session evidence)

- `<project>` 2026-06-08 Sprint 2 — 22 P0 US pushed NONE/PARTIAL → PASS-UNIT via **Derive tier**, +288 tests, 0 source changes. Full retro: `docs/retros/2026-06-08-sprint-2-p0-unit-test-push.md`
- 9 test files added in Sprint 2: `auth.test.ts`, `projects.test.ts`, `requirements.test.ts`, `bugs.test.ts`, `roles.test.ts`, `agents-create.test.ts`, `agents-claim.test.ts`, `tasks-extended.test.ts`, `wikis.test.ts`, `llm-config.test.ts`
- 3 US flagged DEFERRED in Sprint 2 retro: US-8.1, 8.2, 9.3 — all involve `chat.ts` (1787 LOC) or `agent/runtime.ts` (645 LOC)
- Sprint 2 early blocker raise: at phase 6 (LLM/WS) I stopped and asked David to pivot to US-8.7 + US-9.1 + retro instead of faking US-8.1/8.2/9.3 — saved 1-2 hours of fake output
- `<project>` 2026-06-08 Sprint 3 — **3 US closed via Path X (Integration tier)**: US-8.1 + US-8.2 + US-9.3, +39 integration tests, 5 source files (1-line `export` keyword additions only), 0 regressions. Full retro: `docs/retros/2026-06-08-sprint-3-act14-15-closure.md`
  - 3 test files: `chat-integration.test.ts` (22 cases), `runtime-ws-integration.test.ts` (17 cases), `e2e/tests/llm-ws-e2e.spec.ts` (4 cases)
  - Sprint 3 metrics: backend 372 → 411 tests pass, E2E 13 → 17 tests pass
  - **Sprint 3 P0 coverage 79% → 90%** (23/29 → 26/29)
  - **Path X 新 TD entry**: TD-014 — WS 真連線測試環境(E2E 入面用 Playwright 開真 ws,backend 接唔到)
- **Why Sprint 3 picked Path X over pure E2E**: David 揀咗 option D(Playwright mock backend OpenAI + real WS),但 agent raised blocker — Playwright 唔可以 mock 另一個 process 嘅 `fetch`,只能 mock browser side。建議修正版 Path X:backend in-process integration test(22 cases)+ WS lifecycle test(17 cases)+ wire-up E2E(4 cases)嘅 3-tier combo。David 揀咗「做您嘅推薦」,呢個就係 **Path X rule**:user 揀字面做唔到嘅 option 嘅時候,raise blocker + 提修正版 ≠ 偷工減料,係 raise technical impossibility。
- `<project>` 2026-06-09 Sprint 4 — **2 security fixes + derive closures**: TD-008 login rate limit (5/min IP-based) + RG-007 整個移除 `rolePermissionCache`(user 揀 option A)。2 RG entries + 9 unit tests。**Lesson**:1-2ms / request overhead for 內部 system 係 acceptable,「永久 cache 係 anti-pattern」(see "Rate Limit + Cache Security Fix Pattern" above)。
- `<project>` 2026-06-09 Sprint 5 — **4 P0 US closures (US-6.1, 7.4, 9.4, 9.5) → 紅線 12 100%**: +98 unit tests, 4 份新 test file, **0 source code 改動**(純 derive 適用 serialize + state machine + aggregation + permission 4 個唔同 type)。Catch 1 個 `membership.userId === user.id` 漏 invariant(Sprint 5 first commit 即 fail)→ 修正 + 加 source-of-truth grep test 守 derive pattern consistency。Full retro: `docs/retros/2026-06-09-sprint-5-p0-us-100pct-closure.md`
- `<project>` 2026-06-09 QA-TRACKER count task — **parser column-index trap + `execute_code` fallback to `awk`**: tried to count PASS/NONE/Other on 81-US tracker, bundled parser silently returned 0 (assumes 7-col layout, actual is 9-col + no P0 column). Spent 3 attempts on `execute_code` guessing column indices (5→6→7, all wrong) + 1 `KeyError: 0` on `terminal()[0]` (it's a dict). Final working path: `awk -F'|'` with `gsub(/^ +| +$/,"",$2/$3/$7)` + `terminal().get("output")` access. **Lesson embedded in Pitfall #16 + #17 + Step 1 fallback path.**
