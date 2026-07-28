---
name: playwright-e2e-design-patterns
description: E2E test design patterns for Playwright + full-stack (Docker) apps — caller IP isolation vs backend rate limit (RG-008/RG-012 invariant), per-test setup hooks, Tiptap/ProseMirror rich-text-editor interaction patterns (ClipboardEvent + image/* File for paste, NOT innerHTML+dispatchEvent), graceful seed-data fallback (try-fixture → first-item → self-create), 4-option triage when a Playwright pre-existing failure reveals a real backend bug (default-to-fix over skip), 7-step diagnostic that starts with `git status` + `docker exec` source check, and "implementation vs tracker plan divergence" reconciliation. Trigger when designing E2E suites, debugging flaky 429s, testing Tiptap editors, writing fixtures, triaging pre-existing E2E failures, or when tracker plan says X but implementation does Y.
tags: ["playwright", "e2e", "testing", "rate-limit", "caller-identity", "docker", "tiptap", "prosemirror", "rich-text-editor", "seed-data", "fixture-resilience", "pre-existing-failure-triage", "rbac-bug-discovery", "tracker-divergence", "spec-alignment", "uncommitted-work-check", "stale-container-check"]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Playwright E2E design patterns

## 點解要呢個 skill

E2E suite 跑全 stack(backend + DB + frontend) 撞 rate limit,係常見 flaky test 來源,90% 嘅 dev 第一次撞會 debug 錯方向(以為係 backend 嘅 bug)。**問題唔喺 backend 行為,係 E2E caller identity 設計錯**。

核心 invariant:**backend rate-limit 對 caller 嘅認知,係基於 IP;E2E 跑咁多個 test 個 caller IP 唔可以全部撞同一個 bucket**。

---

## Pattern 1: Per-test caller IP isolation (RG-012)

### 問題

Backend 嘅 auth/login 對 `x-forwarded-for` 第 1 個 IP 做 rate limit(eg. 5 attempts / 60s)。Playwright 嘅 `request.post` **唔自動 inject** `X-Forwarded-For` header。Elysia/Express 攞到 `null` → 落 `?? 'unknown'` fallback → **所有 E2E login 撞同一個 bucket `login:unknown`** → 17 個 test 個 spec 平均 1-2 個 login 嘗試,撞 5/60s limit → 4 個 test 連續 429。

**Symptom 識別**:
- E2E 第 5 個 test 之後連續 429
- Backend log 見 "TOO_MANY_REQUESTS"
- Error message:`429 Too Many Login Attempts` 或 `Retry-After: <seconds>`

### 解決方法:Helper 自動 inject IP

```typescript
// e2e/tests/_helpers.ts
import { test as base, expect, type APIRequestContext } from '@playwright/test'

const BACKEND = 'http://localhost:4001'

export const USERS = {
  admin: { email: 'admin@test.com', password: 'admin123' },
  // ... other roles
} as const

export type Role = keyof typeof USERS

/**
 * Login as `role` using a unique caller IP. Returns accessToken.
 * IP derivation: hash(testTitle) % 200 + 1 → '127.0.0.<n>'
 * Each test gets a unique IP, isolating rate-limit bucket.
 */
export async function loginAs(
  req: APIRequestContext,
  role: Role,
  testTitle: string,
): Promise<string> {
  const u = USERS[role]
  const ip = `127.0.0.${ipSuffixForTest(testTitle)}`
  const res = await req.post(`${BACKEND}/auth/login`, {
    headers: { X-Forwarded-For: ip },   // ← 關鍵: 一定要 inject
    data: u,
  })
  expect(res.status()).toBe(200)
  const body = await res.json()
  return body.accessToken as string
}

function ipSuffixForTest(testTitle: string): number {
  let h = 0
  for (let i = 0; i < testTitle.length; i++) {
    h = (h * 31 + testTitle.charCodeAt(i)) | 0
  }
  return (Math.abs(h) % 200) + 1
}

export const test = base
```

**Spec 用法**:
```typescript
import { test, loginAs } from './_helpers'

test('developer cannot create project', async ({ request }, testInfo) => {
  const token = await loginAs(request, 'developer', testInfo.title)
  // ... 撞唔到 rate limit
})
```

**每個 test 用獨立 IP → 撞唔到 bucket**。Backend 0 改動。

### 點解唔用 `Date.now()` 嘅 IP suffix

- **Stable across retries**:重跑同一個 test 仍然用同一個 IP(用 test title hash,唔用 `Date.now()`)
- **Deterministic**:debugging 時睇 log 知 IP 對應邊個 test
- **200 個 bucket 夠 100+ 個 test 嘅 suite 唔撞**(2 個 spec × 100 個 test = 200 個 unique IPs)

### PR review checklist

加新 E2E spec 必須 check:
```bash
grep -E "post\(.*auth/login" e2e/tests/
```

**唔可以**:
- 任何 inline `req.post(.*auth/login.*` (必須經 helper)
- 任何 reuse IP 跨 test(會撞 counter)
- 任何 skip helper「快啲」(backend rate limit 唔認得匿名 caller)

---

## Pattern 2: 邊度用 `page.request` vs 直接 `request`

| 場景 | 用 | 原因 |
|------|------|------|
| API-only test(打 backend endpoint) | `request` from fixtures | Clean, no browser context |
| UI test 需要先 API login | `page.request` | 自動 share browser context cookies |
| UI test 要打 backend(經 nginx 8080) | `page.request` 對 8080 / `request` 對 4001 | 兩條 path 都覆蓋,驗 wire |
| WS test | `WebSocket` global (Node 22) | 跳過 Playwright abstraction |

**記住**:`page.request` 同 `request` **兩個都唔自動 inject** `X-Forwarded-For`,helper 一視同仁。

---

## Pattern 3: Workers + beforeAll/afterAll 設計

### workers=1 for shared-seeded apps

如果 backend 嘅 seed data 係 shared(eg. pm-system 嘅 admin user, projects, tasks):
- **唔可以 parallel tests** — race condition 撞 seed data
- `playwright.config.ts`:`workers: 1, fullyParallel: false`
- 跑得慢但 deterministic

### beforeAll reset(per file, 唔係 per test)

```typescript
test.describe('RBAC negative', () => {
  test.beforeAll(async ({ request }) => {
    // Reset DB, create test fixtures, warm up cache
  })
})
```

`beforeAll` 用 `request` fixture,**冇 `testInfo`**,用 `test.describe()` 嘅 file name 做 IP suffix。

### afterAll cleanup(小心 nested resources)

```typescript
test('create project, then cleanup', async ({ request }, testInfo) => {
  const token = await loginAs(request, 'admin', testInfo.title)
  const proj = await create(token, ...)
  try {
    // ... assertions
  } finally {
    // ALWAYS cleanup
    await delete(token, proj.id)
  }
})
```

---

## Pattern 4: API vs UI login trade-off

| 場景 | 用 | 原因 |
|------|------|------|
| 純 API test | `loginAs` helper(快) | 5ms, deterministic |
| UI smoke test | 走 React login form(慢) | 驗證真實 user flow |
| 兩個都要 | 各一個 test | 覆蓋 happy path + UI flow |

**Anti-pattern**:
- 全部 test 走 UI login 慢(每個 5-10s,17 個 test = 2-3 分鐘)
- 全部 test 走 API login 失去 UI 覆蓋

---

## Pattern 5: Rate-limit E2E 測試自身

如果 backend 嘅 rate limit(eg. RG-008)係 critical behavior,**要單獨一個 test 守住**:

```typescript
test('rate limit blocks 6th login attempt from same IP', async ({ request }, testInfo) => {
  const ip = `127.0.0.${ipSuffixForTest(testInfo.title)}`
  // Hit login 5 times — all should 200
  for (let i = 0; i < 5; i++) {
    const res = await request.post(`${BACKEND}/auth/login`, {
      headers: { X-Forwarded-For: ip },
      data: USERS.admin,
    })
    expect(res.status()).toBe(200)
  }
  // 6th attempt → 429
  const blocked = await request.post(`${BACKEND}/auth/login`, {
    headers: { X-Forwarded-For: ip },
    data: USERS.admin,
  })
  expect(blocked.status()).toBe(429)
  expect(blocked.headers()['retry-after']).toBeDefined()
})
```

**Wait 60s + reset 唔可行** — 跑完整個 suite 要 5 分鐘。Helper 嘅 stable IP 設計就係為咗呢類 test 唔撞其他 test。

---

## Common anti-patterns

### Anti-pattern 1: Inline fetch /auth/login

```typescript
// ❌ NG: 撞 'login:unknown' bucket
const res = await request.post(`${BACKEND}/auth/login`, {
  data: { email: 'admin@test.com', password: 'admin123' },
})

// ✅ OK: 經 helper
const token = await loginAs(request, 'admin', testInfo.title)
```

### Anti-pattern 2: 用 single static IP 跨 test

```typescript
// ❌ NG: 所有 test 用 '127.0.0.1' → 撞同一個 bucket
headers: { 'X-Forwarded-For': '127.0.0.1' }

// ✅ OK: 每個 test 用獨立 IP
const ip = `127.0.0.${ipSuffixForTest(testInfo.title)}`
```

### Anti-pattern 3: Skip rate limit 設定

```typescript
// ❌ NG: 開發時 disable rate limit,production 重新 enable
// 危險:E2E 唔覆蓋真實 rate limit behavior

// ✅ OK: helper 設計同 production 一致
```

### Anti-pattern 4: 用 `Date.now()` 做 IP suffix

```typescript
// ❌ NG: 唔 stable, retry 撞唔同 bucket
const ip = `127.0.0.${Date.now() % 200 + 1}`

// ✅ OK: stable per test title
const ip = `127.0.0.${ipSuffixForTest(testInfo.title)}`
```

---

## Quick diagnostic: 點知我撞 rate limit 嘅 bucket 問題?

```bash
# 1. 跑 E2E,睇 fail 嘅 test
npx playwright test 2>&1 | tail -30

# 2. 睇 error: 如果係 "429 Too Many Login Attempts" / "Retry-After" → 撞 rate limit
# 3. Backend log: 確認 IP 都係 "unknown" 或全部同一個 IP
docker compose logs backend | grep "TOO_MANY"

# 4. Fix: 加 helper,改 spec
```

---

## Pattern 6: Testing Tiptap / ProseMirror rich text editors

**Scope**: 任何用 Tiptap 嘅 React rich text editor(`<RichTextEditor value={x} onChange={setX} />` 帶 `.ProseMirror` contenteditable)。

### Pitfall 1: 唔可以用 `el.innerHTML = html; dispatchEvent('input')` mock image paste

**Symptom**: Tiptap description 入面嘅 `<img>` tag 喺 setContent / DOM innerHTML path 會**被 drop**,即使你 set 咗 inline `data:image/png;base64,...`:

```typescript
// ❌ NG: 個 <img> tag 永遠唔會 survive
const proseMirror = modal.locator('.ProseMirror').first()
await proseMirror.evaluate((el, html) => {
  el.innerHTML = html  // 包含 <img src="data:image/png;base64,...">
  el.dispatchEvent(new InputEvent('input', { bubbles: true }))
}, '<p>text</p><p><img src="data:image/png;base64,..."></p>')
// Submit 後 backend 收到: <p>text</p><p></p>  ← 個 <img> 跌咗
```

**Why Tiptap drop 個 `<img>`**:Tiptap onUpdate 用 `editor.getHTML()` 觸發,但 `dispatchEvent('input')` 唔會觸發 Tiptap command pipeline;而且即使觸發, Tiptap 嘅 Image extension 對 inline data URL schema parse 唔到(尤其係 short base64 / corrupted token)會 silently strip 個 tag。

**✅ Workaround:真正 trigger `handlePaste` event 帶 image/* File**(L85-99 of `RichTextEditor.tsx`):

```typescript
// ✅ OK: 真實 paste event + clipboardData.items 帶 image/* File
// → handlePaste handler → handleImageFile(file) →
//   (冇 uploadEntity) → FileReader.readAsDataURL → editor.commands.setImage({src: dataUrl})
const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
const pngBuffer = Buffer.from(pngBase64, 'base64')

await proseMirror.evaluate((el, b64) => {
  // 喺 browser context 將 base64 → Uint8Array → File
  const bin = atob(b64)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  const file = new File([bytes], 'paste.png', { type: 'image/png' })
  const dt = new DataTransfer()
  dt.items.add(file)
  el.focus()
  el.dispatchEvent(new ClipboardEvent('paste', {
    bubbles: true,
    cancelable: true,
    clipboardData: dt,
  }))
}, pngBase64)

// 等 FileReader async + Tiptap onUpdate + React state sync(1-2 round trips)
await page.waitForTimeout(500)

// Submit 後 backend description 包含:
// <p>...</p><p><img src="data:image/png;base64,iVBORw0KGgo..." alt=""></p>
```

**Alternative for uploadEntity-based apps**:`RichTextEditor` 接受 `uploadEntity={{ type: 'bug', id: 'xxx' }}` prop,handleImageFile 會 upload 去 `/api/attachments` 同 insert URL(唔係 data URL)。呢個 path 仲要 mock 一個 `/api/attachments/upload` endpoint response — 用 `page.route` intercept。

### Pitfall 2: `setContent` 喺 React controlled mode 嘅 round-trip 差異

`bugs-fix.spec.ts:217-221` 嗰個 pattern(`innerHTML + dispatchEvent('input')`)對 **純文字** / **Tiptap schema 識 parse 嘅 inline mark**(`<strong>`、`<em>`、`<a>`)係 work 嘅 — 因為 Tiptap parse 完 emit 返 React state。但對 `<img>` / 自訂 node 唔 work。

**Use 嘅 heuristic**:
| 內容 | Pattern |
|---|---|
| 純文字 / paragraph | `innerHTML + dispatchEvent` ✅ |
| Inline marks(`<strong>` / `<em>` / `<a>`) | `innerHTML + dispatchEvent` ✅ |
| Block node(heading, list) | `innerHTML + dispatchEvent` ⚠️ 部分 Tiptap schema 識 |
| Image paste | 必須 `ClipboardEvent('paste', { clipboardData: dt })` + image/* File ✅ |
| Image upload(有 `uploadEntity`) | 必須 mock `/api/attachments/upload` via `page.route` + 觸發 file input change event |
| Drag-drop file | 必須 `DispatchEvent('drop', { dataTransfer: dt })` + image/* File ✅ |

### Pitfall 3: 唔好信 DOM `.ProseMirror` 嘅 innerHTML 嚟做 assertion

Submit 之前 innerHTML 可能有 `<img>`(因為你 set 咗),但 **Tiptap schema 已經 drop 咗,React state 嘅 `value` 唔包 `<img>`**。Submit 嘅 body 係 React state 唔係 DOM。

**✅ Assertion 必須喺 server side**:
```typescript
// Submit 後 GET /api/bugs/:id 拎返 detail,確認 description 包含
const detail = await page.request.get(`${BACKEND}/api/bugs/${found.id}`)
const detailBody = await detail.json()
expect(detailBody.bug.description).toMatch(/<img[^>]+data:image\/png/)
```

---

## Pattern 7: Graceful seed-data fallback in test fixtures

### 問題

E2E spec 寫死 seed data 名(`'範例項目'`、`'admin user'`),但 docker entrypoint 改咗 / seed 演進之後,呢啲 fixture 名唔再存在 → spec 全部 fail `expect(...).toBeTruthy()`。

**常見 fixture 假設死亡 signal**:
- `projects.find((p) => p.name.includes('範例'))` 返 undefined
- `users.find((u) => u.email === 'admin@seed.com')` 返 undefined
- Backend 返空 array `[](fresh DB volume)` 或只有 E2E-PG-* 自動 gen 嘅 fixture

### ✅ Fallback pattern:try-fixture → fallback-first-item → self-create

```typescript
async function getSampleProjectId(req: Page['request'], token: string): Promise<string> {
  const res = await req.get(`${BACKEND}/api/projects`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  expect(res.status()).toBe(200)
  const body = await res.json()
  const projects = body.projects as Array<{ id: string; name: string }>

  if (projects.length === 0) {
    // Case 3: 連 fallback 都冇(fresh docker volume)— 自己建
    const createRes = await req.post(`${BACKEND}/api/projects`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        name: `E2E-fixture-${Date.now().toString(36)}`,
        description: 'auto-created for spec',
      },
    })
    expect(createRes.status(), 'auto-create fixture project').toBe(200)
    const created = await createRes.json()
    return created.project.id as string
  }

  // Case 1 → 2: 搵特定 fixture → fallback 第一個
  const sample = projects.find((p) => p.name.includes('範例')) ?? projects[0]
  return sample.id as string
}
```

**3 個 case 都 handle**:
1. ✅ Seed 有「範例」項目(legacy)
2. ✅ Seed 冇「範例」但有其他 project
3. ✅ 完全空 array(fresh docker volume)— 自己建 fixture

**Pre-existing precedent**:`rbac-negative.spec.ts:173` 用咗 `?? projects[0]` pattern:
```typescript
const sample = projects.find((p: any) => p.name === '範例項目') ?? projects[0]
// 如果 projects[0] 都冇:test.skip(true, 'no sample project seeded — skipping')
```
但 skip path 唔 robust — 我哋加埋 self-create 確保冇 skip。

### Cleanup discipline

Self-create 嘅 fixture 要 cleanup,避免污染後續 test:
```typescript
// try-finally 包住成個 test,finally 內 cleanup
try {
  // ... test logic
} finally {
  await page.request.delete(`${BACKEND}/api/projects/${fixtureId}`, {
    headers: { Authorization: `Bearer ${token}` },
  }).catch(() => {})  // 唔 throw 避免 mask 真正 failure
}
```

---

## Pattern 8: Auth state reuse and mount-path verification

Reuse authenticated state when a test is not explicitly validating the login UI. Obtain the token through the shared login helper, inject the minimum user state the frontend requires, then navigate to the target route. Before asserting on an auth endpoint, verify the mount path the running app actually exposes; do not infer `/api/auth/*` or `/auth/*` from framework convention.

For SPA readiness, prefer `waitUntil: 'domcontentloaded'` plus an explicit user-visible locator over `networkidle`, which can hang while polling or WebSockets remain active.

## Pattern 9: Removed-feature specs

When a product feature has been removed, E2E specs that still reference it must be explicitly skipped with a removal reason or deleted alongside the feature. Do not leave them active as unexplained failures, and do not use a skip to conceal a still-supported feature's defect.

## Pattern 10: Reuse the project Playwright installation for audits

When a project already has Playwright and browsers installed in its E2E workspace, run one-off audit scripts with that installation instead of introducing a second runtime. Execute Playwright commands from the workspace that owns the dependency, keep throwaway scripts outside the spec discovery path, and delete them after verification.

For `page.evaluate`, pass a function literal and serialize values through its argument. Before taking a full-page screenshot, inspect document height so pathological layouts cannot create enormous captures.

## Project case history

| Reference | Contents |
|---|---|
| [Caller IP isolation](references/caller-ip-isolation.md) | Detailed per-test caller identity implementation. |
| [Pre-existing failure triage](references/pre-existing-failure-triage.md) | Full diagnostic and failure-classification playbook. |
| [Stack health diagnostic](references/stack-health-diagnostic.md) | Docker stack-health troubleshooting cases. |
| [Tiptap paste patterns](references/tiptap-paste-patterns.md) | Rich-text paste incident details and templates. |
| [Workers and parallel design](references/workers-parallel-design.md) | Worker-count and shared-seed trade-offs. |
| [pm-system Sprint 13 triage](references/pm-system-sprint-13-triage.md) | Sprint 13 chronology and project-specific triage findings. |
| [pm-system tracker divergence](references/pm-system-tracker-divergence.md) | US-5.6 tracker and implementation divergence case. |
| [Auth mount-path incident](references/auth-me-mount-path-incident.md) | `/api/auth/me` versus `/auth/me` incident and auth-state workaround. |
| [pm-system Sprint 14 Node audit](references/pm-system-sprint-14-node-audit.md) | Dated audit script, environment findings, and spec inventory. |
