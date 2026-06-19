# Workers + parallel design for Playwright

## 點解 `workers: 1` for shared-seeded apps

如果 backend 嘅 seed data 係 shared(eg. pm-system 嘅 5 個 test user, 1 個 admin, 多個 projects):
- 唔可以 parallel tests — race condition 撞 seed data
- E2E 跑順序:`critical-path` → `llm-ws-e2e` → `rbac-negative` → 17 個 test
- Total ~ 10s(全部 sequential)
- 如果 parallel 4 個 worker → 撞 DB state → 大量 flaky

```typescript
// playwright.config.ts
export default defineConfig({
  workers: 1,           // ← critical: shared seed
  fullyParallel: false, // ← critical: 唔可以 parallel
})
```

## 邊度用 `workers: N` 反而啱

如果 E2E suite 係** fully isolated per test**(每個 test 自建 data + 自己清):
- `workers: 4` 或更多(4-8 個 CPU core)
- `fullyParallel: true`
- 跑得快(17 個 test 5s 完成)
- 但 setup 成本高(per-test fixture)

**Trade-off 矩陣**:

| 屬性 | workers: 1 (shared seed) | workers: N (isolated) |
|------|--------------------------|----------------------|
| 開發成本 | 低(seed 一份) | 高(per-test fixture) |
| 跑得快 | 慢(sequential) | 快(parallel) |
| Flaky 率 | 低(deterministic) | 中(race condition 風險) |
| Debug 容易度 | 易(stack trace 線性) | 中(interleaved) |
| 適合場景 | MVP / pre-production | 成熟 CI / pipeline |

## beforeAll / afterAll 嘅 IP 處理

`beforeAll` 冇 `testInfo`(個 callback 只用 fixtures),要自己 derive:

```typescript
test.describe('RBAC negative', () => {
  test.beforeAll(async ({ request }) => {
    // File 級 IP —— 用 file name 做 hash
    const fileIp = `127.0.0.${hashString('RBAC negative') % 200 + 1}`
    // Warm up: 預登入 admin, save token for afterAll cleanup
    const res = await request.post(`${BACKEND}/auth/login`, {
      headers: { 'X-Forwarded-For': fileIp },
      data: USERS.admin,
    })
    // ...
  })
})
```

## Test isolation strategy

### 1. 完全 independent(推薦 if 成本可接受)

```typescript
test('create project A', async ({ request }, testInfo) => {
  const token = await loginAs(request, 'admin', testInfo.title)
  const proj = await create(token, { name: `A ${testInfo.title}` })
  try {
    // ... assertions on `proj`
  } finally {
    await delete(token, proj.id)
  }
})

test('create project B', async ({ request }, testInfo) => {
  const token = await loginAs(request, 'admin', testInfo.title)
  const proj = await create(token, { name: `B ${testInfo.title}` })
  try {
    // ... assertions on `proj`
  } finally {
    await delete(token, proj.id)
  }
})
```

兩個 test 唔共享 data,撞唔到。

### 2. Shared seed with unique suffix(pm-system 採呢個)

```typescript
test.describe('Critical path', () => {
  const suffix = Date.now().toString(36)   // ← 同一個 describe 內所有 test 共用
  const projectName = `E2E Test Project ${suffix}`
  // ...
})
```

**Caveat**: `Date.now()` 喺 `test.describe` scope 計一次,所有 test 共享 suffix。
- 優點: 容易 debug(同一個 project name 連續多個 test 用)
- 缺點: parallel 撞 data(因為 `workers: 1` OK)

### 3. 完全 independent 跑 workers: N(over-engineered for MVP)

Skip — 過度設計。

## 點解 `fullyParallel: false` 唔可以默設 true

即使 `workers: 1`,Playwright 文件依然跑 `fullyParallel: true` 嘅 default。**必須 explicit 設 false**,否則:
- 同一個 file 內 multiple test 仍然 parallel(就算 workers: 1 global 限 1,但 file 內 test 可能 run in pool)
- 撞 seed data 嘅 race condition

`playwright.config.ts`:
```typescript
{
  workers: 1,
  fullyParallel: false,  // ← 必須 explicit
}
```

## 點解 `retries: 2` 對 CI 重要

```typescript
{
  retries: process.env.CI ? 2 : 0,
}
```

CI 環境 flaky 容忍(retries 跑多 2 次),local 不 retries(fail 立即見)。
- 配 `Date.now()` suffix → retry 撞新 bucket,debug 難
- 配 stable test-title suffix → retry 撞同一 bucket,reproduce 容易

## Hook 順序

```
test.describe  // declare group
  beforeAll    // file-level setup (e.g. seed extra data)
    test 1     // (1) beforeEach, (2) test fn, (3) afterEach
    test 2     // (1) beforeEach, (2) test fn, (3) afterEach
  afterAll     // file-level teardown
```

`beforeAll` / `afterAll` 只跑一次 per file。`beforeEach` / `afterEach` 跑每個 test。
