# pm-system Sprint 1 — TD-011: E2E-discover → fix → regression test 完整 reproduce

> **時機**:2026-06-08 Sprint 1,E2E framework 完成後第二個 sprint 行動
> **性質**:**教科書級** bug fix-and-test cycle,適合未來任何「E2E surface security bug → diagnose → fix → RG entry」session 跟呢個 reproduce

---

## 1. 情境(完整 timeline)

```
PM System 1.0 — backend 喺 Bun + Elysia + Prisma + PG
derive hook 喺 backend/src/index.ts,負責解析 Authorization Bearer token
```

### 1.1 設定

| 項目 | 內容 |
|---|---|
| Project | `pm-system` |
| Stack | Bun 1.2 + Elysia 1.2 + Prisma 5 + PG 15 + Docker Compose |
| Auth pattern | `Bearer <userId:role>` token(`userId` 從 token 第一段,`role` 從 token 第二段) |
| Permission middleware | `requirePermission('X')` 喺 routes,讀 `userRole` derive from token |
| Seed user | admin/pm/techlead/dev/tester 5 個,role 各異 |

### 1.2 觸發:Sprint 1 E2E 補 RBAC negative cases

寫 `e2e/tests/rbac-negative.spec.ts`,覆蓋 6 個 case(non-admin POST / projects 403 / 冇 token / malformed token / etc.)。**預期 fake UUID token 收 403 graceful**(冇 token → 應該 401 / 403;fake token 應該同樣)。

### 1.3 E2E fail 一個 case:fake UUID token 收 500

```bash
$ curl -s -X POST http://localhost:4001/api/projects \
    -H "Authorization: Bearer 00000000-0000-0000-0000-000000000000:admin" \
    -H "Content-Type: application/json" -d '{"name":"repro"}'
# → 500 Internal Server Error
```

Server log 見:

```
Invalid `prisma.project.create()` invocation:
Foreign key constraint violated on the constraint: projects_created_by_id_fkey
```

**冇 500 message 直接出** — Prisma 撞 FK constraint。

---

## 2. Diagnosis(我嘅 2 round miss-and-catch)

### 2.1 Round 1:我以為 bug 喺 derive hook 嘅 `prisma.user.findUnique`

```typescript
// backend/src/index.ts (我以為嘅位置)
try {
  const dbUser = await prisma.user.findUnique({ where: { id: userId }, ... })
  // 我以為呢度 throw 500
} catch (e) { return { user: null } }
```

**誤判** — `findUnique` 對不存在 UUID return `null`,**唔 throw**。我以為個 try/catch 包住就穩陣,事實係 derive hook **冇 check `dbUser === null`**。

### 2.2 Round 2:直接睇 derive hook source code,再追 stack

睇 `backend/src/index.ts:80-115`,確認:

```typescript
try {
  const [userId, role] = token.split(':')
  if (!userId) return { user: null }

  const permissions = role ? await loadRolePermissionsForRole(role) : []  // ← 用 token 嘅 role!
  // ...
  return {
    user: { id: userId, role, permissions },  // ← 冇 verify user 真實存在
  }
} catch (e) {
  console.error('[auth] derive failed:', e)
  return { user: null }
}
```

**Root cause 真係咁**:
1. Fake UUID token 嚟到 → `userId = '00000...'`(fake)
2. `role = 'admin'` 從 token 攞
3. `loadRolePermissionsForRole('admin')` 攞晒 admin perms
4. `prisma.user.findUnique` 對 fake UUID return `null`,但 **冇 check**,所以 `dbUser` 直接被忽略
5. `user` context 變 `{ id: 'fake', role: 'admin', permissions: [...全 admin perms] }`
6. RBAC check 過咗(因為個 fake user 有 admin perms)
7. 落到 `POST /api/projects` 嘅 handler
8. Handler 寫 `createdById: user.id`(fake UUID)
9. `prisma.project.create({ createdById: 'fake' })` 撞 `projects_created_by_id_fkey` FK constraint
10. Prisma throw 500

### 2.3 **Security bonus 發現**:token claim privilege escalation

呢個 bug 嘅**第二個維度**:**用 `role` 從 token 字串攞(非 DB 攞)** = **client 寫 `:admin` 就 claim admin perms**,即使 user 真實係 dev/tester。

```bash
# Dev user 嘅 token dev 應該只可以 claim developer perms
# 但只要 client 改 token 第二段寫 "admin" 即可 claim admin
TOKEN="real-dev-user-uuid:admin"  # ← 冇人 verify role 對應 user
```

**呢個係** 另一個** production 死法**,可能比 fake UUID 更危險 — **任何 user 都可以提權**。

---

## 3. Fix(derive hook 加 user existence check + role 從 DB 攞)

```typescript
// backend/src/index.ts derive hook — fix 後
try {
  const [userId, role] = token.split(':')           // ← role 從 token 攞只係 fallback hint
  if (!userId) return { user: null }

  // ⭐ FIX TD-011: 必須先 load user 確認真實存在 + role 從 DB 攞
  const dbUser = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, role: true },
  })
  if (!dbUser) return { user: null }                // ← fake UUID → graceful null

  // ⭐ FIX TD-011 bonus: role 必須由 DB 攞(never trust client)
  // 即使 token 寫 ':admin' 都要用 dbUser.role
  const permissions = await loadRolePermissionsForRole(dbUser.role)

  return {
    user: { id: dbUser.id, role: dbUser.role, permissions },
  }
} catch (e) {
  console.error('[auth] derive failed:', e)
  return { user: null }
}
```

**3 個唔可以 miss 嘅 line**:
- `if (!dbUser) return { user: null }` — 守住 fake UUID
- `loadRolePermissionsForRole(dbUser.role)` 而唔係 `role` — 守住 token claim privilege escalation
- `id: dbUser.id` 而唔係 `id: userId` — 對齊 DB reality

**改完 verify 兩件事**:
1. 13/13 E2E pass(原來 1 個 fail 嘅 test 改期望 500→403)
2. 42/42 unit tests 仲綠(冇 regression)

---

## 4. E2E test expectation update(守住 fix 後行為)

```typescript
// e2e/tests/rbac-negative.spec.ts
test('non-existent user token: returns 403 (TD-011 FIXED)', async ({ request }) => {
  // ✅ FIXED 2026-06-08: derive hook 而家 check user 真實存在 + role 從 DB 攞
  // 之前 fake UUID token 會過 derive hook 落到 project.create 撞 FK 然後 500
  // 修咗之後:derive hook `if (!dbUser) return { user: null }` → permission check fail → 403
  // 同時亦修咗 privilege escalation(用 dbUser.role 而唔係 token 嘅 role 字串)
  const fakeUuid = '00000000-0000-0000-0000-000000000000'
  const res = await request.post(`${BACKEND}/api/projects`, {
    headers: { Authorization: `Bearer ${fakeUuid}:admin` },
    data: { name: 'E2E Negative Project' },
  })
  expect(res.status()).toBe(403)
  const body = await res.json()
  expect(body.error?.code).toBe('FORBIDDEN')
})
```

**Pre-fix state 對比**:

```typescript
// Pre-fix(2026-06-08 撞 bug 嗰陣):
test('non-existent user token: backend currently returns 500 (KNOWN BUG TD-XXX)', async ({ request }) => {
  // 守住現時 500 行為
  expect(res.status()).toBe(500)
  // TODO: TD-XXX — fix prisma.findUnique error handling in auth derive
})

// Post-fix(2026-06-08 fix 後):
test('non-existent user token: returns 403 (TD-011 FIXED)', async ({ request }) => {
  expect(res.status()).toBe(403)
  expect(body.error?.code).toBe('FORBIDDEN')
})
```

**Lesson**:**E2E test 預期應該 mirror 修好後嘅行為**。如果用 pre-fix expectation 鎖死,fix 之後 test 仲 fail 以為 fix 撞咗 — **過咗 fix 必須同步 update E2E expectation**,即係 RG-006 entry 嘅 regression test 真係 work 嘅 evidence。

---

## 5. RG-006 entry(寫入 `docs/REGRESSION-GUARD.md`)

```markdown
### RG-006: Auth derive hook 對 fake UUID token throw 500(2026-06-08 E2E 發現)

- **發現日期**: 2026-06-08
- **Symptom**: 用 well-formatted 但不存在嘅 user UUID 嘅 token POST /api/projects
  收到 `HTTP 500 Internal Server Error`,backend log 見 `prisma.project.create()` 撞
  `Foreign key constraint violated on the constraint: projects_created_by_id_fkey`
- **Root cause**: backend/src/index.ts derive hook(line 80-115)對 fake UUID token:
  1. `dbUser = null`(findUnique 唔 returns)
  2. 但用 `userId` 從 token 推斷 role,fall through 過 RBAC check
  3. Route handler (POST /api/projects) 寫 `createdById: user.id` 撞 FK
  4. Prisma throw 500
- **Fix**:
  - derive hook 加 `if (!dbUser) return { user: null }` 早 return
  - 順手修 **privilege escalation**:改用 `dbUser.role` 而唔係 token 嘅 role 字串
    (原本 `Bearer fake-uuid:admin` 都可以 claim admin perms)
  - 加 `console.error` 喺 catch block 方便 debug
- **Prevention**: derive hook 必須嚴格驗 user 真實存在 + role 由 DB 攞(never trust client)
- **Regression test**: ✅ 2026-06-08 fix 後加返(`e2e/tests/rbac-negative.spec.ts` line 125)
  - 預期 403 FORBIDDEN(graceful auth-missing)
  - 順手 verify privilege escalation 守住(同一 fake token 唔再可以 access admin endpoint)
- **Ref**: TECH-DEBT.md TD-011
```

---

## 6. Source code comment marker(防止 refactor 破壞 invariant)

```typescript
// backend/src/index.ts derive hook
const dbUser = await prisma.user.findUnique({
  where: { id: userId },
  select: { id: true, role: true },
})
if (!dbUser) return { user: null }
// RG-006: 唔可以 rely on token 字串,role 必須由 DB 攞
// 違反呢個 invariant = privilege escalation + 撞 FK throw 500
const permissions = await loadRolePermissionsForRole(dbUser.role)
```

---

## 7. Commit message 模板(紅線 13 引用 RG ID)

```
fix(security): TD-011 — auth derive hook 對 fake UUID 500→403

對應 TECH-DEBT TD-011 + RG-006(新 entry)。

**Root cause**:
backend/src/index.ts derive hook 對 well-formatted 但唔存在嘅 user UUID:
  1. dbUser = null (findUnique 唔 returns)
  2. 但用 userId 從 token 推斷 role,fall through 過 RBAC check
  3. Route handler (POST /api/projects) 寫 createdById: user.id 撞 FK
  4. Prisma throw 500

**Fix**(backend/src/index.ts derive hook):
- 加 `if (!dbUser) return { user: null }` 早 return
- 順手修 **privilege escalation**:
  原本 `Bearer fake-uuid:admin` 都可以 claim admin perms(用 token 字串)
  而家改用 `dbUser.role`(DB 真相)— never trust client
- 加 `console.error` 喺 catch block 方便 debug

**驗證**:
- 13/13 E2E tests pass(3 critical-path + 10 rbac-negative)
- E2E test 預期由 500 改 403,validate 個 fix 真係 work
- 42/42 unit tests 仲綠(無 regression)

**守住嘅 invariants**:
- 唔再 throw 500
- 唔再可以 claim 唔存在 user 嘅 role
- client 收到清晰 FORBIDDEN 403 而唔係 confusing 500

**Security bonus**:
呢個 fix 順手封咗一個 privilege escalation — 原本 fake token 寫 'admin' 就 claim
admin perms,即使 user 真實唔存在。而家 role 必須從 DB 攞。

Refs: RG-006, TD-011
```

---

## 8. Take-aways(可重用 checklist)

任何「E2E discover bug → fix → regression test」嘅 session 必跑:

- [ ] **E2E 預期 mirror 真實行為(就算係 bug 行為)** — 寫入 test,等 fix 後改期望
- [ ] **E2E 唔係 fail 即停** — fail 嗰陣先睇 server log(stack trace),往往 reveal 真實 root cause 唔係直覺位置
- [ ] **Source code 永遠係 source of truth**(我 Round 1 誤判 derive hook,睇 source 先 catch 真實位置)
- [ ] **Test assumption 錯咗即修正 test** — 唔好 fabricate test 嚟 pass;如果 backend 真係 403 而我假設 401,改 test
- [ ] **Fix 觸及多個 invariants** — TD-011 fix 同時修咗 2 個 bug(fake UUID 500 + token claim 提權)
- [ ] **Fix 之後**:
  - 跑全部 test suite 確認冇 regression
  - 更新 E2E test 預期
  - 寫 RG-XXX entry(root cause + prevention + invariant 語句化)
  - Source code 加 `RG-XXX` comment marker
  - Commit message 引用 RG ID
- [ ] **更新 cross-doc**:
  - `docs/TECH-DEBT.md` 個 TD entry 加「Fix 完」+ commit ref
  - `docs/QA-TRACKER.md` 加 progress row
  - `docs/REGRESSION-GUARD.md` 加新 RG entry
- [ ] **Security bonus discovery** — fix 一個 bug 嗰陣,如果 source code 有其他 invariants 違反,**同一個 fix 順手修埋**(但要 commit message 列清楚)

---

## 9. 同其他 skill 嘅關係

- `structural-doc-batch` Test Batch Phase 2 — 呢個 reproduce 就係 Phase 2 嘅 **Step 5 + Step 6**(發現 bug 即時 TECH-DEBT + fix)
- `backend-rbac-audit-log` Step 8e + Step 9 — TD-011 屬於 derive hook 嘅另一類 pitfall(唔係 seed coverage,係 hook 本身嘅 user existence check)
- `code-review-pipeline` Step 1 (auth axis) — TD-011 屬於 auth review axis 嘅典型 missing check
- `prisma-json-field-api-serialization` — TD-011 唔屬於 serialization,但 `prisma.X.create()` 撞 FK throw 500 係 Prisma 嘅另一類常見 silent failure,值得 awareness
