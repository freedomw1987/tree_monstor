# ⚠️ Pitfall — Token trust + fake UUID privilege escalation (2026-06-08 pm-system TD-011, class-level security pattern)

**場景**(2026-06-08 pm-system TD-011 親驗):Backend 嘅 auth derive hook:

```typescript
// backend/src/middleware/auth.ts:80-115
export const derive = async ({ headers, request, set }: ...) => {
  const auth = headers.authorization
  if (!auth) return { user: null }                       // ← (A) missing token

  const token = auth.replace('Bearer ', '')
  const [userId, roleFromToken] = token.split(':')       // ← (B) simple token format

  if (!userId) return { user: null }

  try {
    const dbUser = await prisma.user.findUnique({ where: { id: userId } })
    // ❌ 冇 check `if (!dbUser) return { user: null }` ← (C) ROOT BUG

    return {
      user: {
        id: userId,                                       // ← 用 token 嘅 id, 唔係 dbUser.id
        role: roleFromToken as any,                       // ← (D) 🔴 ROLE 從 TOKEN 攞!
        permissions: permissionsForRole(roleFromToken),   // ← 假設 token 寫 :admin 即 admin
      }
    }
  } catch (e) {
    request.log.error(e, '[auth] derive failed')
    return { user: null }
  }
}
```

**真實攻擊**:
```bash
# Attacker 用任何 fake UUID + 自稱 admin
curl -H "Authorization: Bearer 00000000-0000-0000-0000-000000000000:admin" \
     -X POST http://localhost:4001/api/projects \
     -d '{"name":"attacker project"}'
```

**應該**:403 FORBIDDEN(user not found)
**實際**(未修前):**500 Internal Server Error** + PrivEsc 後遺:
- (C) `dbUser` 係 null,`prisma.user.findUnique` throw 唔 throw(其實冇 throw,係 silent null)→ fall through
- (D) **role 從 token 攞**,即使 `dbUser` 係 null,permission array 仍然用 `roleFromToken='admin'` 計算
- 落到 `prisma.project.create({ createdById: user.id, ... })` 撞 FK constraint
- `createdById='00000000-0000-...'` 唔存在 user → P2003 foreign key constraint violation → 500

**兩個 bug,一個 root cause 修法**:

```typescript
// ✅ FIX: 1) null check 2) role 從 DB 攞,唔信任 token
const dbUser = await prisma.user.findUnique({ where: { id: userId } })
if (!dbUser) {
  request.log.warn({ userId }, '[auth] derive: user not found')
  return { user: null }                    // ← 一早 fail,連 role 嘅 permission 都唔計算
}

return {
  user: {
    id: dbUser.id,                          // ← DB truth
    role: dbUser.role as any,               // ← DB truth, NEVER trust client
    permissions: permissionsForRole(dbUser.role),  // ← 由 DB 嘅 role 計
  }
}
```

**Bonus 副作用**: 呢個 fix 順手封咗 **3 個 silent privilege escalation attack vector**:
1. Fake token claim admin(`Bearer xxx:admin` 即使 user 唔存在都 claim admin)→ 而家 user 唔存在直接 403
2. Token 寫 `:pm` 扮 PM 角色(user 真實係 developer)→ 而家 role 由 DB 攞,claim 唔到
3. Custom token 寫 `:superuser` → fallback 行為不明,但 permission array 會係空(因為 `permissionsForRole('superuser')` 唔認)

**Root cause 雙層**:
- **技術**:`dbUser` 冇 null check + `role` 從 token 攞(`roleFromToken`)而唔從 DB 攞
- **Process**:Token 設計太 simple(`userId:role` 而唔係 JWT 或 random opaque token)+ 冇 integration test 撞 fake token

**3 個 prevention 措施**(必須一齊做):

1. **Auth hook 嘅 `if (!dbUser) return null` null check + role 從 DB 攞**(上述 fix 嘅 2 個改動)

2. **Integration test 撞 fake token family**(每個 backend 必須有):
   ```typescript
   // RBAC negative E2E
   describe('Auth derive hook — fake token family', () => {
     it('fake UUID + admin role → 403 not 500', async () => {
       const resp = await request(app)
         .post('/api/projects')
         .set('Authorization', 'Bearer 00000000-0000-0000-0000-000000000000:admin')
         .send({ name: 'test' })
       expect(resp.status).toBe(403)             // ← 唔係 500
     })

     it('fake UUID + non-admin role → 403 (no permission bypass)', async () => {
       const resp = await request(app)
         .post('/api/projects')
         .set('Authorization', 'Bearer 00000000-0000-0000-0000-000000000000:developer')
         .send({ name: 'test' })
       expect(resp.status).toBe(403)
     })

     it('real user UUID but token claims different role → uses DB role', async () => {
       // Real developer user 嘅 UUID, token 寫 :admin
       const devUser = await prisma.user.findFirst({ where: { role: 'developer' } })
       const resp = await request(app)
         .post('/api/admin/users')              // admin-only endpoint
         .set('Authorization', `Bearer ${devUser.id}:admin`)
         .send({ ... })
       expect(resp.status).toBe(403)             // ← developer 真實 role 唔可以做 admin
     })
   })
   ```

3. **Audit log 對 derive hook 嘅 fake token 嘗試**:
   ```typescript
   if (!dbUser) {
     request.log.warn({ userId, ip: request.headers.get('x-forwarded-for') }, '[auth] derive: fake token attempt')
     // 寫入 audit_log,security monitoring 可以睇
     await prisma.auditLog.create({
       data: {
         action: 'AUTH_FAKE_TOKEN',
         actorId: null,
         resourceType: 'auth',
         metadata: { userId, roleClaimed: roleFromToken, ip: ... },
       }
     })
     return { user: null }
   }
   ```

**Detection signal checklist**(audit 任何 backend 嘅 auth derive / middleware):

- [ ] 任何 `auth.derive` / `authMiddleware` / `requireAuth` function 嘅 source code
- [ ] 個 function 入面有冇 `if (!dbUser) return null` 或 `if (!user) return res.status(401)`?
- [ ] `role` 嘅 source 係 token 抑或 DB?(`role: roleFromToken` = ❌, `role: dbUser.role` = ✅)
- [ ] 個 token 係 JWT(opaque, server 解析)抑或 simple string format(`userId:role` = ❌)?
- [ ] `prisma.user.findUnique({ where: { id: userId } })` 之後嘅 code path 有冇可能 fall through null?
- [ ] 任何 `permissionsForRole(...)` 嘅 input 來自 token 抑或 DB?
- [ ] Backend 撞 fake token 嘅時候 500 抑或 401/403?(`500` = bug,`401/403` = 正確)
- [ ] 有冇 integration test 撞「fake UUID + 任何 role」?

**Reference**:`references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md` 嘅 § 2「Diagnosis(我嘅 2 round miss-and-catch)」+ 完整 reproduce。

**Lesson**:**任何 backend auth derive 嘅 output 都必須由 DB derive,絕對唔可以由 client-可控 input(token)derive**。呢個係 OWASP Top 10 嘅 A01:2021 – Broken Access Control + A07:2021 – Identification and Authentication Failures 嘅交集。Fake token 撞 500 = double whammy(security bug + reliability bug)。每次撞 500 都要 grep 個 stack trace 源頭 — 通常係 auth/middleware layer 嘅 null check missing。
