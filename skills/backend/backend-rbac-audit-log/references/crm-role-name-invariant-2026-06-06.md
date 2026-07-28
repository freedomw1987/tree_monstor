# CRM-system 2026-06-06 — Role name UPPERCASE invariant + frontend mirror pitfall

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body, "Step 13" block. This is the full
> crm-system incident log where `POST /roles` returned 400 (lowercase
> reject) but the frontend dialog froze silently because
> `useMutation.onError` didn't render error state. The general rule
> (backend invariants must be mirrored in the frontend form) lives in
> SKILL.md; this file is the concrete reproduction recipe.

`POST /roles` 嘅 `name` field 喺 crm-system 強制 **UPPERCASE 內部 identifier** (`ADMIN` / `SALES` / `VIEWER` / `SMOKE_TEST_ROLE`),而 `displayName` 先係 user-facing 中文/英文混合。Backend check 喺 `apps/api/src/routes/roles.ts` line 72 附近:

```typescript
if (data.name !== data.name.toUpperCase()) {
  set.status = 400;
  return { error: 'Role name must be UPPERCASE (e.g. SENIOR_SALES)' };
}
```

呢個 invariant 嘅**對應 frontend form 一定要 mirror**,否則 user 填「Senior Sales」會凍住冇 feedback:

```tsx
// apps/web/src/components/role-dialog.tsx — 必須 UPPERCASE 化
<Input
  value={name}
  onChange={(e) => setName(e.target.value.toUpperCase().replace(/\s+/g, '_'))}
  placeholder="e.g. SENIOR_SALES"
/>
// 仲要喺 submit 前:
// if (name !== name.toUpperCase()) setError('內部名稱必須大寫');
```

**Smoke test 揭發嘅 bug sequence** (crm-system 2026-06-06):
1. Click「新增自訂角色」→ dialog 開,counter「0 個已選」
2. 填 `name="Smoke Test Role"`,勾 4 個 permission
3. Click「建立」→ **dialog 凍住**:冇 spinner,冇 error banner,冇 toast,console 乾淨
4. 背後:`POST /roles` 返 400(lowercase reject),`useMutation.onError` **冇 render error state**(debug 細節見 `archive/skills/case-history/visual-ui-bug-debugging` (archived) skill 嘅「Backend Invariant Silent-Fail」section)
5. **Bypass UI direct API probe 確認 backend 正常**:
   ```bash
   docker exec crm-api sh -c 'cat > /tmp/probe.mjs << "EOF"
   const login = await fetch("http://localhost:3001/auth/login", {
     method: "POST", headers: { "Content-Type": "application/json" },
     body: JSON.stringify({ email: "admin@crm.local", password: "admin123" })
   });
   const { token } = await login.json();
   const r = await fetch("http://localhost:3001/roles", {
     method: "POST",
     headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
     body: JSON.stringify({ name: "SMOKE_TEST_ROLE", displayName: "Smoke Test Role", ... })
   });
   console.log("status:", r.status, "body:", await r.text());
   EOF
   node /tmp/probe.mjs'
   # → 201 + 完整 record
   ```
6. **清理**:`DELETE /roles/:id` 將 smoke test 整出嚟嘅 row 移除,**避免污染 prod DB**

**Lesson 3 條 invariant checklist**(任何 backend 強制嘅 invariant, frontend form 必 mirror):
1. **Format invariant**(`UPPERCASE` / `slug` / `email`) → input `onChange` 即時 transform + Zod schema `.regex()`
2. **Length invariant**(`minLength` / `maxLength`) → input `maxLength` + Zod schema
3. **Enum invariant**(`role: 'ADMIN' | 'SALES'`) → 用 `<Select>` 而唔係 `<Input>`,submit 前 check 個 value 喺 enum 內

**Frontend 必用 toast library**(eg. `sonner` / `react-hot-toast`),`onError` 唔可以淨 render inline `<p>`(太易被 dialog 高度 ignore):
```tsx
const onError = (e: Error) => {
  toast.error(parseApiError(e));      // ← 必 user-visible
  setError(parseApiError(e));          // ← inline 輔助
};
```