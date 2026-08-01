# Security Quick Fixes — Rate Limit + Cache Removal Patterns

> 2026-06-09 pm-system Sprint 4 完整 workflow。David 揀 A (整個移除 cache) 同 A (IP-based 5/min) 嘅 2 個 patterns,各 ~0.5 日 ship。

## 1. Login Rate Limit (TD-008 + RG-008)

### Decision: IP-based 5 attempts / 60s

| 策略 | 適用場景 | 缺點 |
|------|---------|------|
| **A. IP 5/min** ✅ David 揀 | Internal PM system,大多數同事 NAT 同一 IP 出口,簡單 | Shared office IP 一齊被 ban 60s(可接受) |
| B. Username 5/15min | 對 anti-brute-force 更精準,但要 username enumeration 防護 | 撞 username 反而 expose 邊個 username 存在 |
| C. 雙重 (IP 5/min + username 10/hr) | 嚴格 security | 內部 system overkill |

### Utility (20 行, in-memory sliding window)

```ts
// backend/src/utils/rate-limit.ts
export interface RateLimitOptions {
  key: string
  limit: number
  windowMs: number
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
export function _cleanupRateLimit() {
  const now = Date.now()
  for (const [key, timestamps] of rateLimitStore) {
    const fresh = timestamps.filter(t => now - t < 60 * 60 * 1000)
    if (fresh.length === 0) rateLimitStore.delete(key)
    else if (fresh.length !== timestamps.length) rateLimitStore.set(key, fresh)
  }
}
```

### Route integration (auth.ts `POST /login`)

```ts
.post('/login', async ({ body, set, request, cookie: { refreshToken } }) => {
  const { email, password } = body as { email: string; password: string }

  // TD-008: IP-based rate limit (5 attempts / 60s)
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    ?? request.headers.get('x-real-ip')
    ?? 'unknown'
  const limit = rateLimit({ key: `login:${ip}`, limit: 5, windowMs: 60_000 })
  if (!limit.ok) {
    set.status = 429
    set.headers['retry-after'] = String(Math.ceil(limit.resetMs / 1000))
    return {
      error: {
        code: 'TOO_MANY_REQUESTS',
        message: `Too many login attempts. Try again in ${Math.ceil(limit.resetMs / 1000)}s.`
      }
    }
  }

  // ... existing bcrypt + token logic
})
```

### 5 Critical Tests (RG-008)

```ts
describe('RG-008: TD-008 login rate limit', () => {
  beforeEach(() => _resetRateLimit())

  test('allows N attempts under limit', () => {
    for (let i = 0; i < 5; i++) {
      const r = rateLimit({ key: 'login:1.2.3.4', limit: 5, windowMs: 60_000 })
      expect(r.ok).toBe(true)
      expect(r.remaining).toBe(4 - i)
    }
  })

  test('blocks N+1 attempt from same key', () => {
    for (let i = 0; i < 5; i++) {
      rateLimit({ key: 'login:1.2.3.4', limit: 5, windowMs: 60_000 })
    }
    const sixth = rateLimit({ key: 'login:1.2.3.4', limit: 5, windowMs: 60_000 })
    expect(sixth.ok).toBe(false)
    expect(sixth.remaining).toBe(0)
    expect(sixth.resetMs).toBeGreaterThan(0)
  })

  test('isolates different IPs', () => {
    for (let i = 0; i < 5; i++) rateLimit({ key: 'login:1.2.3.4', limit: 5, windowMs: 60_000 })
    const otherIp = rateLimit({ key: 'login:5.6.7.8', limit: 5, windowMs: 60_000 })
    expect(otherIp.ok).toBe(true)
  })

  test('sliding window expires after windowMs', async () => {
    for (let i = 0; i < 5; i++) rateLimit({ key: 'login:test', limit: 5, windowMs: 100 })
    const blocked = rateLimit({ key: 'login:test', limit: 5, windowMs: 100 })
    expect(blocked.ok).toBe(false)
    await new Promise(r => setTimeout(r, 150))
    const allowed = rateLimit({ key: 'login:test', limit: 5, windowMs: 100 })
    expect(allowed.ok).toBe(true)
  })

  test('blocked attempts do NOT extend lockout', () => {
    for (let i = 0; i < 5; i++) rateLimit({ key: 'login:x', limit: 5, windowMs: 60_000 })
    for (let i = 0; i < 100; i++) {
      rateLimit({ key: 'login:x', limit: 5, windowMs: 60_000 })  // all blocked
    }
    const stored = rateLimitStore.get('login:x') ?? []
    expect(stored.length).toBe(5)  // store unchanged
  })
})
```

### Pitfalls
- ❌ **用 Redis** for 內部 system — overkill,Map 已經夠,production upgrade path 一行 import swap
- ❌ **唔 fallback IP**(`'unknown'` 作 fallback) → 全部 attacker 同一 bucket 但 legitimate user 撞 ban
- ❌ **Blocked attempts 計入 limit** → lockout 永久延長
- ❌ **唔 set `Retry-After` header** → client 唔知幾時 retry

### Production upgrade path
```ts
// Replace Map with Redis sorted set
import { Redis } from 'bun'
const r = new Redis()
export function rateLimit({ key, limit, windowMs }) {
  // ... ZADD timestamp, ZREMRANGEBYSCORE, ZCARD, EXPIRE
}
```

---

## 2. Cache Removal (RG-007 — rolePermissionCache)

### Symptom
Admin 喺 Settings → Roles 改完 permission,所有現有 user 唔即時見到。要 `docker compose restart backend` 先 reload。

### Decision Tree

| Option | 適用場景 | Trade-off |
|--------|---------|-----------|
| **A. 整個移除 cache** ✅ David 揀 | 內部 system / low traffic | 1-2ms / request overhead,RBAC 即時生效 |
| B. Invalidation hook | High-traffic production | 加 explicit `clearCache` on role mutation event,易漏 edge cases |
| C. TTL 5s | 中庸,短期 stale 唔影響 | 5s 內 RBAC 變更唔生效,debug 時 confuse |

### Fix (option A, index.ts)

```diff
-// ─── In-memory role permissions cache ────────────────────────────────────────
-// Loaded from DB once per role. Managed by index.ts. Callers use setRolePermissions().
-const rolePermissionCache = new Map<string, string[]>()
-
-function getPrisma(): PrismaClient {
-  return prisma
-}
-
-async function loadRolePermissions(roleName: string): Promise<string[]> {
-  const cached = rolePermissionCache.get(roleName)
-  if (cached !== undefined) return cached
-
-  const prisma = getPrisma()
-  const role = await prisma.role.findUnique({ where: { name: roleName } })
-  const permissions = role?.permissions ?? []
-  rolePermissionCache.set(roleName, permissions)
-  setRolePermissions(roleName, permissions)
-  return permissions
-}
-
-export async function refreshAllRolePermissions() {
-  rolePermissionCache.clear()
-  const prisma = getPrisma()
-  const roles = await prisma.role.findMany({ select: { name: true, permissions: true } })
-  for (const role of roles) {
-    rolePermissionCache.set(role.name, role.permissions)
-    setRolePermissions(role.name, role.permissions)
-  }
-}
+// ─── Role permissions loader (RG-007 fix) ─────────────────────────────────────
+// No in-memory cache — RBAC changes take effect immediately for all users.
+// 1-2ms per request overhead is acceptable for internal PM system (traffic low).
+
+async function loadRolePermissions(roleName: string): Promise<string[]> {
+  const prisma = getPrisma()
+  const role = await prisma.role.findUnique({ where: { name: roleName } })
+  const permissions = role?.permissions ?? []
+  setRolePermissions(roleName, permissions)  // sync middleware map (backward compat)
+  return permissions
+}
+
+export async function refreshAllRolePermissions() {
+  const prisma = getPrisma()
+  const roles = await prisma.role.findMany({ select: { name: true, permissions: true } })
+  for (const role of roles) {
+    setRolePermissions(role.name, role.permissions)
+  }
+}
```

### RG-007 Regression Test (4 source-check tests)

```ts
describe('RG-007: role permissions no longer cached', () => {
  test('rolePermissionCache Map has been removed from index.ts (source code check)', async () => {
    const fs = await import('node:fs/promises')
    const path = await import('node:path')
    const indexPath = path.resolve(import.meta.dir, '../index.ts')
    const source = await fs.readFile(indexPath, 'utf-8')

    // 1. Map declaration gone
    expect(source).not.toMatch(/const\s+rolePermissionCache\s*=\s*new\s+Map/)
    // 2. Cache lookup gone
    expect(source).not.toMatch(/const\s+cached\s*=\s*rolePermissionCache\.get/)
    // 3. Cache.set on load gone
    expect(source).not.toMatch(/rolePermissionCache\.set\(roleName,\s*permissions\)/)
    // 4. But loader + DB query still exist
    expect(source).toMatch(/async function loadRolePermissions/)
    expect(source).toMatch(/prisma\.role\.findUnique\(\s*{\s*where:\s*{\s*name:\s*roleName/)
    // 5. Comment explains why no cache
    expect(source).toMatch(/No in-memory cache|RG-007/)
  })

  // ... 3 more similar tests for derive hook, permission.ts, REGRESSION-GUARD entry
})
```

### Pitfalls
- ❌ **「Load once then forget」永久 cache** — 改 admin-side state 必直接影響 user-side,否則係隱藏 bug
- ❌ **依賴 docker restart 作為 cache invalidation 機制** — production deploy 期間所有 user 撞 403
- ❌ **唔寫 RG-007 entry** — 紅線 13 強制(每個 bug fix 必有 RG-XXX),冇 entry 嘅 fix 唔可以 merge

### Anti-pattern (option B 嘅 failure modes)
Invalidation hook 容易出問題:
- 改完 role 後 `clearCache()` 漏 call 一個 helper
- Multi-instance deployment 嘅 cache 唔 sync
- 喺 async function 中途 clear 但其他 concurrent request 已經 read 咗 stale value

For internal / low-traffic system,**option A 永遠係最簡單最對**。

---

## 3. Combined Sprint 4 Workflow Checklist

- [ ] 確認 David 揀嘅 strategy (e.g. A 整個移除 cache,A IP 5/min)
- [ ] 寫 utility 20 行(不 import 任何 dependency,易 test)
- [ ] 寫 5 critical utility tests(allow/block/isolate/window/blocked-don't-extend)
- [ ] 寫 RG-XXX source-check test 守住 source code grep
- [ ] 喺 route 入面加 utility call(0 個其他改動)
- [ ] Run `bun test` 確認 0 regression
- [ ] Update TECH-DEBT.md (closure note), REGRESSION-GUARD.md (新 entry), USER-MANUAL FAQ(刪 workaround)
- [ ] 1 commit, push, verify remote HEAD
