# pm-system auth mount-path incident

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

