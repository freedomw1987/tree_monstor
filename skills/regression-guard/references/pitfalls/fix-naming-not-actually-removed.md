# ⚠️ Pitfall — 「fix 名義 = 移除 X」≠ X 真係消失(2026-06-09 pm-system RG-007 cleanup gap, class-level)

**場景**:Sprint 4 fix RG-007「移除 `rolePermissionCache` permanent cache」,**commit message、regression test、docs entry 都做齊**。Sprint 5 我去清 TD-004 時 `grep rolePermissionCache` 發現:

```bash
$ rg "rolePermissionCache|setRolePermissions|invalidateRolePermissions" backend/src/
backend/src/middleware/permission.ts:37:export const rolePermissionCache = new Map<string, string[]>()
backend/src/middleware/permission.ts:39:export function setRolePermissions(roleName: string, permissions: string[]) {
backend/src/middleware/permission.ts:40:  rolePermissionCache.set(roleName, permissions)
backend/src/middleware/permission.ts:43:export function invalidateRolePermissions(roleName?: string) {
backend/src/middleware/permission.ts:45:  rolePermissionCache.delete(roleName)
backend/src/middleware/permission.ts:47:  rolePermissionCache.clear()
backend/src/index.ts:25:import { setRolePermissions } from './middleware/permission'
backend/src/index.ts:42:  setRolePermissions(roleName, permissions)
backend/src/index.ts:50:    setRolePermissions(role.name, role.permissions)
backend/src/routes/roles.ts:2:import { rolePermissionCache, hasPermission } from '../middleware/permission'
backend/src/routes/roles.ts:274:      rolePermissionCache.delete(normalizedName)
backend/src/routes/roles.ts:341:        if (role.name) rolePermissionCache.delete(role.name)
backend/src/routes/roles.ts:343:      if (existing.name !== role.name) rolePermissionCache.delete(existing.name)
backend/src/routes/roles.ts:385:    rolePermissionCache.delete(role.name)
```

**問題**:`rolePermissionCache` Map 仲 export 緊(死碼)、`setRolePermissions` 仲喺 `index.ts` 嗰度 call、`rolePermissionCache.delete(...)` 仲喺 `roles.ts` 4 個 mutation handler 入面 call。**Map 仲 set 嘢但冇 code 讀返(`rolePermissionCache.get(...)` 整個 codebase = 0 occurrences)**,所以係 dead write + half-orphan import。

**實際影響**:
- 唔影響 runtime(冇人 read,write 冇 effect)
- 製造 confusing source state:新 developer 睇 `setRolePermissions(...)` call 會以為 cache 真係 work
- TD-008(原本講「rate limit + 移除 cache」)嘅 cache 移除部分其實**得咗 50%**:regression test 守住「`rolePermissionCache.get(...)` 唔可以 hit」(因為本來就 0 call),但**冇守住「`rolePermissionCache` 唔可以存在喺 source 入面」**
- David / 後人手動 audit 嗰陣,要再行一次 cleanup

**Root cause(為何會漏)**:
1. **Fix 嘅 invariant 寫得唔夠 sharp** — RG-007 個 entry 寫「`rolePermissionCache` 唔再被 read」,但應該寫「`rolePermissionCache` symbol 唔可以存在喺 source code 入面」。前者守住行為,後者守住結構。
2. **Regression test 走 source-code grep 但冇走 import grep** — `role-cache-no-cache.test.ts` 嘅 `expect(source).not.toMatch(/const\s+rolePermissionCache\s*=\s*new\s+Map/)` 已經有,點解冇 catch 到?—— 因為個 regex 揾嘅係**聲明 site**(`new Map`),唔係 **import site**(`import { rolePermissionCache } from ...`)。`roles.ts:2` 個 import 用嘅係 `rolePermissionCache` 嘅另一個 reference 形式,冇 trigger 個 assertion。
3. **冇 call-site 級 audit** — fix 嗰陣只睇 `index.ts` 個 derive hook 改用 `dbUser.role`,冇 audit `roles.ts` 4 個 mutation handler 仲 import + call 死碼。

**3 個 prevention 措施(必須一齊做,fix 移除類 symbol 必跑)**:

1. **Sharp invariant statement** — RG entry 嘅 invariant 必須明確揀「**結構**」定「**行為**」:
   - ✅ 結構(invariant = symbol 唔存在):
     > 「`rolePermissionCache` symbol(無論 export / import / declaration)唔可以存在喺 `backend/src/**/*.ts` 入面。任何 commit 重新引入都 fail CI。」
   - ✅ 行為(invariant = runtime path):
     > 「`userHasPermission` 必須由 DB 攞 permissions,任何 cache.get() 撞 1ms-cache 都 fail test。」
   - ❌ 模糊(兩者都唔 cover):
     > 「個 cache 唔再 work」← 守住 mock 行為,守唔住 source 結構

2. **Source-check regression test 加 4 條 negative assertions(覆蓋 export / import / declaration / call)**:
   ```typescript
   // backend/src/middleware/role-cache-no-cache.test.ts (extend)
   describe('RG-009: rolePermissionCache 完全消失', () => {
     const SOURCE_FILES = [
       'backend/src/middleware/permission.ts',
       'backend/src/index.ts',
       'backend/src/routes/roles.ts',
     ]

     for (const relPath of SOURCE_FILES) {
       test(`${relPath} 冇 rolePermissionCache 任何 reference`, async () => {
         const source = await fs.readFile(path.resolve(import.meta.dir, '../../' + relPath), 'utf-8')
         // ✅ 1. declaration
         expect(source).not.toMatch(/const\s+rolePermissionCache\s*=\s*new\s+Map/)
         // ✅ 2. export
         expect(source).not.toMatch(/export\s+(const|function)\s+rolePermissionCache/)
         // ✅ 3. import(原 regex 漏咗呢個)
         expect(source).not.toMatch(/import\s+.*\brolePermissionCache\b/)
         // ✅ 4. call site
         expect(source).not.toMatch(/rolePermissionCache\.(get|set|delete|clear)\(/)
         // ✅ 5. 同伴 functions
         expect(source).not.toMatch(/\bsetRolePermissions\(/)
         expect(source).not.toMatch(/\binvalidateRolePermissions\(/)
       })
     }
   })
   ```

3. **Fix 完成 checklist**(任何「移除 X / 廢除 X / 改名 X」嘅 fix 必跑):
   - [ ] `rg "\bX\b" --type ts backend/src/` → 期望 0 result(跨所有 file)
   - [ ] `rg "import .*\bX\b" --type ts backend/src/` → 期望 0 result
   - [ ] `rg "from .*['\"](.*X.*)['\"]" --type ts backend/src/` → 期望 0 result(包括 indirect import 經 barrel file)
   - [ ] `rg "X\.|\bX\(" --type ts backend/src/` → 期望 0 result(call site)
   - [ ] **每個原本 call X 嘅 file 必睇** — 即使「fix 行為」已經 work,call site 仲係死碼 = 半 orphan
   - [ ] Grep 結果 0 嘅 file 仍要 `git diff` 睇有冇 dev 改過但未 commit 嘅 reference
   - [ ] Update RG entry 加「Cleanup verified by rg on YYYY-MM-DD, N files grep, 0 references」note

**Detection signal**(出現以下就要 audit 上次 fix 嘅 cleanup status):

- [ ] 個 fix commit message 講「remove / 移除 / deprecate / 廢除」但冇跟 cleanup commit
- [ ] 個 fix commit 同 source file 之後嘅 commit,冇人 grep 過死碼
- [ ] 個 regression test 用 `mock.module` 守行為但冇 source-grep 守結構
- [ ] TD-XX entry 標 ✅ Fixed 但 source 入面仲有 reference
- [ ] Dev 用 IDE 嘅「find references」撈到 N 個 reference 但 N > 0 = cleanup gap

**Lesson**:**「fix 行為」+「守住 source 結構」係兩回事**。Mock-based regression test 守住 runtime 行為,source-grep regression test 守住 code structure,缺一就會出現「function 從此再無用」嘅死碼半 orphan。**Rule of thumb**:任何「移除 / 廢除 / 改名」嘅 fix,**rg 0 result 係 ship 嘅最低條件**。
