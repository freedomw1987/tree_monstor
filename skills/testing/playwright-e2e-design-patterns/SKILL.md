---
name: playwright-e2e-design-patterns
description: E2E test design patterns for Playwright + full-stack (Docker) apps — caller IP isolation vs backend rate limit (RG-008/RG-012 invariant), per-test setup hooks, Tiptap/ProseMirror rich-text-editor interaction patterns (ClipboardEvent + image/* File for paste, NOT innerHTML+dispatchEvent), graceful seed-data fallback (try-fixture → first-item → self-create), 4-option triage when a Playwright pre-existing failure reveals a real backend bug (default-to-fix over skip), 7-step diagnostic that starts with `git status` + `docker exec` source check, and "implementation vs tracker plan divergence" reconciliation. Trigger when designing E2E suites, debugging flaky 429s, testing Tiptap editors, writing fixtures, triaging pre-existing E2E failures, or when tracker plan says X but implementation does Y.
tags: ["playwright", "e2e", "testing", "rate-limit", "caller-identity", "docker", "tiptap", "prosemirror", "rich-text-editor", "seed-data", "fixture-resilience", "pre-existing-failure-triage", "rbac-bug-discovery", "tracker-divergence", "spec-alignment", "uncommitted-work-check", "stale-container-check"]
---

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

## Pattern 8: Playwright 撞 pre-existing failure 嘅 triage(2026-06-10 pm-system Sprint 13)

### 問題

Sprint closure 跑 full E2E suite,撞 N 個 pre-existing failure(eg 4/55 fail)。**唔係所有 failure 都可以用 helper patch 解決** — 部分係**真實 backend bug**。盲目用「`describe.skip` + DEPRECATED comment」掩蓋 security bug = 紅線 13 違規(冇 RG entry 嘅 fix 唔可以 merge)+ 紅線 14 違規(冇 root cause + prevention)。

### Diagnostic 步驟(7 個 step,3 個 tool call 以內)

1. **Step 0:`git status -s` 睇有冇上一個 session 漏 commit 嘅 fix**(disk 有 source code 但 HEAD 冇)— 直接 commit + 唔好從頭再寫
2. **Step 0.5:`docker exec <backend> cat /app/src/routes/<file>.ts | grep <fn>` 確認 running container 嘅 source 同 disk 一致** — disk 有 fix 但 container running stale = rebuild + restart,唔係 bug
3. **Step 1:`npx playwright test <failing-test-name>`** 跑單一 test,睇 root error
4. **Step 2:睇 backend log 嘅實際 response**(唔靠 mental model)— `docker compose logs backend | tail -30`
5. **Step 3:睇 stack trace 嘅 source code**(必 `grep` 真實 file,例如 `grep -n "developer" backend/src/routes/tasks.ts`)— skip helper 通常係 sprint 7-9 引入嘅 P0 spec 加 `describe.skip`,而新 spec 直接寫 assertion 會揭真實 bug
6. **Step 4:直接 hit API reproduce**(用 curl + 已知 user role)— 確認係「test 期望錯」定「backend 真係錯」
7. **Step 5:判定每個 failure 嘅 root cause class**:
   - **A. Test-helper bug** — seed data 名變咗(Sprint 8+ docker entrypoint 改咗),或者 IP rate-limit 撞 → patch helper(Pattern 7 fallback 適用)
   - **B. Test expectation bug** — spec 期望 `expect(status).toBe(403)` 但 backend 返 200,**可能係 test 寫錯**或者**可能係 backend 真係 security bug**。要 reproduce 確認
   - **C. 真實 backend bug** — `curl PUT /api/tasks/:id -H "Authorization: Bearer dev-token" -d '{"title":"hijack"}'` 返 200,backend 真係漏 RBAC gate

**完整 7-step playbook + 撞過嘅 reproduce 例子** 喺 `references/pre-existing-failure-triage.md`。

### Triage 4-option table 寫法(必修,成段 ship 嘅 critical part)

**唔可以**直接撞 option。寫一段 4-option triage table 俾 user 揀,跟 `feature-plan-alignment` 嘅 4-option pattern:

| # | Option | Scope | 預估 | 風險 |
|---|--------|-------|------|------|
| 1 | 只修 helper(test bug) | Spec-only | 20 分鐘 | 紅線 13 守,但 D 漏住 production 漏洞 |
| 2 | **修 helper + 修 backend + 加 unit test 守住 invariant** | Spec + Backend | 45 分鐘 | **全綠,紅線 13/14 都守** |
| 3 | 修 helper + 修 backend 但唔加 unit test | Spec + Backend (小) | 30 分鐘 | Backend 修咗但冇 invariant test,將來可能返轉 |
| 4 | 全部 `describe.skip` + DEPRECATED label(同 Sprint 11 `/bugs` 拎走個做法) | Docs-only | 10 分鐘 | Test 表面乾淨但 security bug 留喺 production |

**我推薦 Option 2** — 因為 D 係真實 security bug,紅線 13 + 14 規定 bug fix 必須有 root cause + prevention + regression test entry。**skip-without-fix 唔合規**。

### 判斷「test bug vs backend bug」嘅 3 條 heuristic

| 線索 | 偏向 test bug | 偏向 backend bug |
|------|---------------|-----------------|
| Test 期望嘅 status code | 期望 `4xx` 但 backend 返 `2xx` | 期望 `4xx` 但 backend 返 `2xx`(backend 真係漏 gate) |
| Curl reproduce | Curl 一樣返錯 status(backend 真錯) | Curl 返 200(spec 期望錯) |
| 改 backend 後 test 過唔過 | N/A | 改 backend return 403 → test 過咗 = backend 真係 bug |
| Production audit log | N/A | 有 user 用 developer role 改 title = backend bug 已被 exploit |
| Code comment 寫住 `// TODO` / `// FIXME` | N/A | Backend 有 `// TODO: enforce RBAC` = known bug,未有 RG entry(紅線 13 違規) |

**`// TODO` / `// FIXME` 嘅 code comment 係 highest signal** — 個 project 知道有 bug 但冇 RG-XXX entry = 紅線 13 違規 = 必須修 + 加 entry + 加 test。

### 「fix 名義 = 移除 / deprecate」唔等於 cleanup 嘅 pitfall

撞過(Sprint 13 plan):舊 test 用 `describe.skip` + DEPRECATED comment 掩蓋 RBAC bug,**新 spec 寫斷言 `expect(403)` 反而揭發 backend 真係漏 gate**。**新 spec 唔可以默守舊 spec 嘅 skip pattern** — 必須 reproduce + 4-option triage + Option 2 default。

### 配套 checklist(任何「Playwright failure → 4-option triage」session 必跑)

- [ ] 跑 full E2E,grep 出 pre-existing failure list
- [ ] 對每個 failure 跑 `npx playwright test <name>` 拎 root error
- [ ] 對每個 failure curl reproduce 確認係 test bug 定 backend bug
- [ ] 寫 4-option triage table(結構跟 `feature-plan-alignment` § "Output structure")
- [ ] 預設 recommendation = Option 2(紅線 13/14 合規)
- [ ] User 揀咗之後先動 code,唔好 default 落 Option 4(skip-without-fix)

---

## Pattern 6: Testing Tiptap / ProseMirror rich text editors(2026-06-10 pm-system)

**Scope**: 任何用 Tiptap 嘅 React rich text editor(`<RichTextEditor value={x} onChange={setX} />` 帶 `.ProseMirror` contenteditable)— 通用於 pm-system / 將來其他 Tiptap-based apps。

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

## Pattern 7: Graceful seed-data fallback in test fixtures(2026-06-10 pm-system)

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
2. ✅ Seed 冇「範例」但有其他 project(Sprint 8+ docker entrypoint 改咗)
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

## Pattern 9: Implementation 與 tracker 計劃出現分歧時嘅 spec 重對齊(2026-06-10 pm-system US-5.6)

### 問題

E2E 寫嘅時候撞咗「tracker 講過會有 X,但 implementation 唔係 X」嘅情況。撞過(pm-system 2026-06-10 US-5.6 Project detail bug tab):
- **Tracker 講**:Bugs list 嘅 status / severity 篩選係 **server-side**(plan 寫住 `?status=OPEN&severity=BUG`)
- **Implementation 係**:`<ProjectDetailPage>` 嘅 bug tab 用 `useState + useMemo` 喺 client-side filter,backend 冇 `?status=...` query support
- **3 個錯誤應對**(都要避免):
  1. **❌ 盲從 tracker** — 寫 spec 用 `?status=OPEN&severity=BUG` query,backend 唔認得 → test 永遠 fail
  2. **❌ 反轉 implementation** — 為咗對齊 tracker plan 就改 backend 加 server-side filter
  3. **❌ Skip test** — `describe.skip` 標 DIVERGED,等下個 sprint 再處理

### ✅ 正確做法:Update spec to match reality + inline comment 解釋

```typescript
// ✅ OK: Test 對齊 actual implementation(用 client-side filter),
// 同時 inline 註解講點解同 tracker plan 唔同
test('US-5.6: project bug tab filters by status client-side', async ({ page }) => {
  // Note (2026-06-10): tracker planned server-side filter via
  // `?status=OPEN&severity=BUG`, but `<ProjectDetailPage>` actually
  // uses client-side `useMemo` filter (see ProjectDetailPage.tsx#L210-218).
  // Server-side filter is a future improvement (T-XX). E2E verifies
  // the current client-side behavior; the spec is the contract.
  await page.goto(`/projects/${projId}/bugs?status=OPEN`)
  // Click OPEN status filter button
  await page.getByRole('button', { name: 'Open', exact: true }).click()
  // Assert: only OPEN bugs visible
  const rows = page.getByTestId('bug-row')
  await expect(rows).toHaveCount(2)
  for (const row of await rows.all()) {
    await expect(row).toContainText('OPEN')
  }
})
```

**點解**:
1. **Test 係 spec,唔係 plan** — 個 US 嘅 expected behavior 由 spec 表達,唔由 plan 規定
2. **Implementation = ground truth** — Plan 係 intention;implementation 係 deployed reality
3. **Divergence 必須文件化** — Inline comment 寫住 (a) 邊日發現,(b) tracker 點講,(c) implementation 點做,(d) 將來點 reconcile
4. **唔好 hardcode 期待 server-side behavior** — 將來如果 backend 真係加 `?status=`,spec 要 update

### 配套 checklist(任何「tracker plan 講 X 但 implementation 做 Y」撞到時)

- [ ] `git grep <X-feature>` 確認 implementation 真係做 Y
- [ ] 寫 1-line inline comment 解釋 divergence(日子、tracker ref、implementation 嘅 source 位置)
- [ ] Spec assert implementation 而唔係 plan
- [ ] (Optional) 開新 T-XX follow-up 入 `docs/QA-TRACKER.md`「Plan 對齊 sprint」標 PARTIAL,等下個 sprint 處理
- [ ] (Optional) Patch plan doc 標 divergence(例:`docs/PRD.md` US-5.6 改個 status 標 ⏸️ deferred)

**Anti-patterns**(要避免):

| Anti-pattern | 點解 NG |
|---|---|
| Skip test with TODO | Spec 失 cover,user 唔知呢個 behavior 係 work 定 broken |
| 為咗 spec pass 反轉 implementation | Implementation 為 product/user 設計,test 唔應該 override product decision |
| 改 tracker 扮冇分歧 | 文件失真,將來再睇會誤導 |
| 寫 spec 同時 assert 兩種 behavior | Race condition + 將來一邊 implement 改咗,spec 兩邊都會 fail |

### 點解唔用 Step 5 「A/B/C failure class」處理

Step 5 處理**失敗**嘅 case(tracker 同 implementation 對齊但 test 仲 fail)。Pattern 9 處理**冇失敗**嘅 case(tracker 同 implementation 唔對齊但 implementation 正常)— 兩者唔同。**呢個 pattern 屬於「寫 spec 嘅時候」唔係「triage failure 嘅時候」**。

---

## 參考文件

- `references/caller-ip-isolation.md` — Per-test IP 完整 implementation 細節 + 點解 stable hash 而非用 Date.now
- `references/workers-parallel-design.md` — 邊度用 workers=1 vs parallel, shared seed 嘅 trade-off
- `references/stack-health-diagnostic.md` — Docker stack 起唔到 4 個 root cause(Vite build silent fail / Prisma 7 strict validation / volume mount 漏 migration / external dep miss)+ Stack health 100% checklist
- `references/tiptap-paste-patterns.md` — Tiptap / ProseMirror rich text editor E2E testing: 3 個 pitfall + 1 個 workaround template
- `references/pre-existing-failure-triage.md` — Sprint closure 撞 pre-existing failure 嘅 **7-step diagnostic**(Step 0: git status, Step 0.5: docker exec source check, Step 1-5)+ 4-option triage pattern(2026-06-10 pm-system)+ pm-system Sprint 13 嘅 4 個 failure 嘅 root cause 預分析
- `templates/_helpers.ts` — 已經 verified 嘅 `loginAs` helper(pm-system production use, 2026-06-09)

## Pattern 10: E2E spec auth state setup — 唔好打 `/api/auth/me` 拎 user(2026-06-10 pm-system Sprint 14)

### 問題

寫 E2E spec 時需要攞真實 user object(id / name / role)去 inject 入 localStorage 過 frontend `AuthContext`。天真做法係用 `loginAs` 攞 token + 然後 call backend `/api/auth/me` 拎 user,然後 `loginViaStorage(page, token, user)`。

**Pitfall**:Backend 嘅 auth route **唔一定 mount 喺 `/api/auth/*`**。撞過 2026-06-10:pm-system 嘅 `auth.ts` route mount 喺 `/auth/*` (root level),而其他 route(user / project / bug) 喺 `/api/*` group。Spec 寫 `/api/auth/me` 返 404,login 后個 step crash。

### 解決方法:唔好 hit backend 拎 user,用 static fixture

```typescript
// ✅ OK: Static user fixture + token from helper
async function loginViaStorage(page: Page, token: string) {
  await page.goto(`${FRONTEND}/login`)
  await page.evaluate(
    ({ accessToken, refreshToken }) => {
      localStorage.setItem('accessToken', accessToken)
      localStorage.setItem('refreshToken', refreshToken)
      localStorage.setItem(
        'user',
        // 唔需要 backend confirm — frontend AuthContext 對 localStorage 嘅 user shape 唔做 server-side 驗證
        // server-side auth 喺每個 API call 嘅 Authorization header
        JSON.stringify({ id: 'admin', name: '系統管理員', email: 'admin@test.com', role: 'admin' }),
      )
    },
    { accessToken: token, refreshToken: 'e2e-sprint14-refresh-token' },
  )
}
```

**Why 啱**:
1. **Frontend `AuthContext` 唔會** verify 個 user object 同 server 一致 — 只係讀 localStorage 嘅 user field 做 permission check
2. **Server-side auth 喺每個 API call 嘅 `Authorization: Bearer <token>` header** — 唔靠 user object
3. **Spec 唔需要 user.id 對 server 真實 id**,只需要 frontend 嘅 permission check 過(e.g. `hasAnyPermission(user, ['projects.create'])` 靠 `user.role === 'admin'` 通過)
4. **Avoid 撞 backend mount-path 嘅 pitfall** — 唔需要知道 `/api/auth/*` vs `/auth/*` 邊個啱

### 撞過嘅 3 個 backend mount-path 變體

| 框架/慣例 | 預設 mount | Spec 寫 |
|---|---|---|
| Elysia root level (`/auth/*`) | pm-system 2026-06 | `/auth/login` + `/auth/me` 喺 root,**唔喺** `/api/` |
| Elysia grouped (`/api/auth/*`) | 一些 refactor 過嘅 app | `/api/auth/login` + `/api/auth/me` |
| Express typical | 看 routing tree | 通常 `/api/auth/*` |

**Rule**:**直接 grep `backend/src/index.ts` 嘅 `.use(authRoutes)` / `.group('/api', ...)` 確認 mount path**,唔好靠 mental model。

### 配套:Auth state setup 嘅 4 步(NOT 5 步)

```typescript
// ❌ NG:5 步(login API → /api/auth/me → inject → goto → reload)— 第 2 步可能 404
// ✅ OK:4 步(login API → inject static user → goto — 唔需要 reload 因為 await page.goto = full navigation)
async function e2eAuth(page: Page, req: Page['request'], role: Role, testTitle: string) {
  const token = await loginAs(req, role, testTitle)
  await page.goto(`${FRONTEND}/login`)  // 攞到 origin
  await page.evaluate(({ accessToken }) => {
    localStorage.setItem('accessToken', accessToken)
    localStorage.setItem('refreshToken', 'e2e-fixture-refresh')
    localStorage.setItem('user', JSON.stringify({ id: role, name: 'E2E', email: `${role}@test.com`, role }))
  }, { accessToken: token })
  // 唔需要 reload — page.goto(targetUrl) 已經 full navigation
}
```

### 配套 pitfall:`page.goto(URL)` vs `page.goto(URL, { waitUntil: 'networkidle' })`

- `waitUntil: 'networkidle'` 喺 SPA 嘅 SPA 路由下有時 hang 喺永遠唔 idle(因為 fetch 自動 revalidate / WebSocket)
- **Prefer** `waitUntil: 'domcontentloaded'` + 顯式 `page.waitForSelector('h1:has-text("儀表板")')` 等 UI ready

## Pattern 11: Node Playwright audit script for SPA auth (2026-06-10 pm-system)

### 問題

`rwd-mobile-audit` skill 推薦用 Python Playwright 跑 SPA screenshot audit。但 **Python 環境 vs Node 環境** 撞過:

| Environment | 撞過嘅 issue |
|---|---|
| Python (`/usr/local/bin/python3`) | `pip install playwright` 撞 PEP 668;`playwright install` 又 install 錯 chromium 版本(頭撞 `chromium-1155`,實際 system 已經有 `chromium-1223`)|
| Node (`e2e/node_modules`) | 已有 `chromium-1223` install,直接 `import { chromium } from 'playwright'` work |

**Recommendation**:**用 Node 而非 Python** (如果 project 已經有 `e2e/` 嘅 Playwright install)。直接 reuse 個 e2e setup。

### 完整 Node script(Sprint 14 嘅 rwd-audit-s14.mjs 簡化版)

```javascript
// /tmp/rwd_audit.mjs
import { chromium } from 'playwright'  // 用 project 嘅 e2e/node_modules
import { promises as fs } from 'fs'

const OUT = '/tmp/rwd_audit_s14'
await fs.mkdir(OUT, { recursive: true })

const PAGES = [
  ['dashboard', 'http://localhost:8080/'],
  ['projects', 'http://localhost:8080/projects'],
]

const browser = await chromium.launch()
const ctx = await browser.new_context({
  viewport: { width: 390, height: 844 },
  isMobile: true, hasTouch: true,
})
const page = await ctx.new_page()

// Step 1: 喺 /login 攞 token
await page.goto('http://localhost:8080/login', { waitUntil: 'networkidle' })
const loginResult = await page.evaluate(async () => {  // ← 函數 literal, 唔用 template literal!
  const res = await fetch('http://localhost:4001/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '127.0.0.1' },
    body: JSON.stringify({ email: 'admin@test.com', password: 'admin123' })
  })
  if (!res.ok) return { error: 'login failed', status: res.status }
  return await res.json()  // ← 必須 return, 否則 evaluate 返 undefined
})
if (loginResult.error) { console.error(loginResult); process.exit(1) }

// Step 2: Inject localStorage
await page.evaluate((t) => {
  localStorage.setItem('accessToken', t)
  localStorage.setItem('refreshToken', 'rwd-audit-refresh')
  localStorage.setItem('user', JSON.stringify({ id: 'admin', name: '系統管理員', email: 'admin@test.com', role: 'admin' }))
}, loginResult.accessToken)

// Step 3: Audit each page
const results = []
for (const [name, url] of PAGES) {
  await page.goto(url, { waitUntil: 'networkidle' })
  await page.waitFor_timeout(500)
  const scrollH = await page.evaluate('document.body.scrollHeight')
  if (scrollH > 8000) {  // ← Pre-check 避免爆 100k px
    console.log(`  ${name}: WARN scrollH=${scrollH}px > 8000px, skip screenshot`)
    continue
  }
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true })
  const bodyW = await page.evaluate('document.body.scrollWidth')
  results.push({ name, url, scrollH, bodyW, overflow: bodyW > 390 })
}
await browser.close()
await fs.writeFile(`${OUT}/summary.json`, JSON.stringify(results, null, 2))
```

**3 個 critical syntax**:
1. **`await page.evaluate(async () => {...})`** — 函數 literal, 唔好用 `` `async () => {}` `` template literal (會 return undefined)
2. **Step 2 evaluate 帶 argument**:`evaluate((t) => {...}, loginResult.accessToken)` — 第二個 arg 係 serialize 入 page context
3. **Pre-check scrollHeight** — 避免 fullPage screenshot 爆

### 從 project root 跑 vs 從 `e2e/` 跑

**Pitfall**:從 `pm-system/` cwd 跑 `npx playwright test` 撞 root `package.json` 冇 playwright 嘅問題 → npm 自動 install 或者搵到舊 version → conflict。**Rule**:**從 `e2e/` cwd 跑所有 Playwright command**:
```bash
cd /Users/davidchu/Sites/localhost/pm-system/e2e
node rwd-audit-s14.mjs  # 用 e2e 嘅 playwright install
npx playwright test tests/sprint14-projects-search-and-dashboard.spec.ts
```

### Delete 跑 audit 嘅 throwaway script 跑完即刪

Audit script 唔應該 commit 入 `e2e/`(test-results/ 同 playwright-report/ 已經 gitignore,但 custom audit 唔係 spec,屬於 temporary verification):
```bash
rm /Users/davidchu/Sites/localhost/pm-system/e2e/rwd-audit-s14.mjs
```

如果想 keep,擺去 `e2e/scripts/`(sub-dir)或者 `/tmp/`(global temp)— 唔好擺去 `e2e/tests/`(會被 Playwright 當 spec 跑)。
