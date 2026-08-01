/**
 * E2E test helpers — shared by all *.spec.ts in this directory.
 *
 * 點解要有呢個 file (2026-06-09 RG-012):
 * - Backend 嘅 `auth.ts` IP-based rate limit (5 attempts/60s, TD-008 + RG-008)
 *   對 E2E 全 hit `login:unknown` bucket (Elysia 攞唔到 Playwright request 嘅
 *   `X-Forwarded-For` header,落 `?? 'unknown'` fallback)。
 * - 我哋 1 個 docker stack 上跑多個 E2E test,每個 test 平均 1-2 個 login
 *   attempt → 全部撞同一個 bucket → 撞 429。
 *
 * 修法: 每個 test 用獨立 IP (`127.0.0.<n>`) 做 caller identity,自然 isolate
 * bucket。完全合乎真實 RBAC 行為 (每個 caller 都有獨立 counter)。
 *
 * 守住 invariant (RG-012):
 * - login 一定要行呢個 helper (唔可以 inline fetch)
 * - helper 一定要 inject `X-Forwarded-For` (唔可以留空)
 * - IP 一定要用 `127.0.0.<n>` form (唔可以係 IPv6, backend 只睇 x-forwarded-for split)
 * - 唔可以 reuse 同一個 IP 跨 test (會撞 counter)
 *
 * **用法**:
 * 1. 抄呢個 file 入 `<project>/e2e/tests/_helpers.ts`
 * 2. 改 USERS constant 對應自己嘅 seed user
 * 3. 改 BACKEND URL 對應自己嘅 port
 * 4. Spec 入面 import: `import { test, loginAs } from './_helpers'`
 * 5. 任何 login 都行: `const token = await loginAs(request, 'admin', testInfo.title)`
 */
import { test as base, expect, type APIRequestContext } from '@playwright/test'

const BACKEND = 'http://localhost:4001'   // ← 改自己 backend port

export const USERS = {
  admin: { email: 'admin@test.com', password: 'admin123' },
  pm: { email: 'pm@test.com', password: 'pm123' },
  techlead: { email: 'techlead@test.com', password: 'tl123' },
  developer: { email: 'dev@test.com', password: 'dev123' },
  tester: { email: 'tester@test.com', password: 'test123' },
} as const

export type Role = keyof typeof USERS

/**
 * Login as `role` using a unique caller IP. Returns accessToken.
 *
 * IP derivation: uses `127.0.0.<n>` where `<n>` is the current test
 * title hash modulo 200 + 1. Each test gets a unique IP, isolating
 * the rate-limit bucket from siblings and re-runs.
 */
export async function loginAs(
  req: APIRequestContext,
  role: Role,
  testTitle: string,
): Promise<string> {
  const u = USERS[role]
  const ip = `127.0.0.${ipSuffixForTest(testTitle)}`
  const res = await req.post(`${BACKEND}/auth/login`, {
    headers: { 'X-Forwarded-For': ip },
    data: u,
  })
  expect(
    res.status(),
    `login ${role} from ${ip} should succeed (got ${res.status()})`,
  ).toBe(200)
  const body = await res.json()
  return body.accessToken as string
}

/**
 * Map a test title → deterministic IP suffix in [1, 200].
 * Using a stable hash means reruns of the same test still hit the same
 * IP, but different tests hit different IPs. Date.now() would not be
 * stable across retries.
 */
function ipSuffixForTest(testTitle: string): number {
  let h = 0
  for (let i = 0; i < testTitle.length; i++) {
    h = (h * 31 + testTitle.charCodeAt(i)) | 0
  }
  return (Math.abs(h) % 200) + 1
}

/**
 * Wraps Playwright `test` so beforeEach can pass the test title to
 * `loginAs`. Spec files should use this `test` instead of importing
 * from `@playwright/test` directly when they need login.
 */
export const test = base
