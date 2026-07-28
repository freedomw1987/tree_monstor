# ⚠️ Pitfall — Source-check regression test (when ESM mocking fails for global state)

**場景**(2026-06-09 pm-system Sprint 4 RG-007):要守嘅 invariant 係「`rolePermissionCache` 呢個 Map 唔可以存在」(即係「永久 cache = anti-pattern」呢個 invariant)。但你冇辦法用 `mock.module('../utils/prisma', ...)` 嚟 derive unit test — 因為:

1. `loadRolePermissions` 冇 export 喺 `index.ts`(只係內部 helper)
2. `import { ... } from '../index'` 會 trigger `Elysia().listen(4000)` 即時啟動 server 撞 port
3. `mock.module` 對 ESM hoist 唔可靠 — `prisma` 喺 import 時已經 freeze 咗,後 mock 失效
4. 即使 mock 到,你 verify 嘅係「mock 行為」,唔係「source 真係刪咗 cache」

**症狀**:
- Test fail:`0 pass / 2 fail` 因為 server 啟動撞 port
- Mock 0 call:ESM 已經 import 真 prisma,`mock.module` 後到
- 「Derive pure function」(見上面 pitfall)呢個 pattern 唔適用 — 因為根本冇 pure function extract 得到

**正確做法 — Source-check regression test (3 個 recipe)**:

```typescript
// backend/src/middleware/role-cache-no-cache.test.ts
import { describe, expect, test } from 'bun:test'
import * as fs from 'node:fs/promises'
import * as path from 'node:path'

describe('RG-XXX: <invariant 簡述>', () => {
  test('source code 確認 anti-pattern 唔存在', async () => {
    const indexPath = path.resolve(import.meta.dir, '../index.ts')
    const source = await fs.readFile(indexPath, 'utf-8')

    // ✅ 1. 刪咗嘅 symbol — negative assertion
    expect(source).not.toMatch(/const\s+rolePermissionCache\s*=\s*new\s+Map/)

    // ✅ 2. 刪咗嘅 access pattern — negative assertion
    expect(source).not.toMatch(/rolePermissionCache\.set\(roleName,\s*permissions\)/)

    // ✅ 3. 仍存在嘅 invariant — positive assertion
    expect(source).toMatch(/async function loadRolePermissions/)
    expect(source).toMatch(/prisma\.role\.findUnique\(/)

    // ✅ 4. Comment 解釋點解 — 防止 refactor 走樣
    expect(source).toMatch(/No in-memory cache|RG-XXX/)
  })

  test('middleware 入面仍由 user.permissions 攞,唔由 Map 攞', async () => {
    // 守住「permission 來源係 derive hook 嘅 per-request injection」呢個 invariant
    const permissionPath = path.resolve(import.meta.dir, './permission.ts')
    const source = await fs.readFile(permissionPath, 'utf-8')
    expect(source).toMatch(/user\.permissions\?\.includes\(permission\)/)
  })

  test('docs/REGRESSION-GUARD.md 有對應 entry', async () => {
    // 守住「doc 唔可以 orphan」— 任何 fix 嘅 RG entry 必 commit
    const rgPath = path.resolve(import.meta.dir, '../../../docs/REGRESSION-GUARD.md')
    const rg = await fs.readFile(rgPath, 'utf-8')
    expect(rg).toMatch(/RG-XXX.*<invariant|invariant.*RG-XXX/s)
  })
})
```

**3 個 recipe 嘅底層原理**:
- **Source-code grep test** = 守住「**code 唔可以重新引入 anti-pattern**」(re-introduction guard)
- **Doc assertion** = 守住「**doc 唔可以 orphan**」(RG entry 必 commit 喺 code 改動同一個 commit)
- 兩個一齊 = 守「**bug fix 嘅完整 evidence chain**(source 改 + comment 解 + doc 紀錄)」

**同「derive pure function」嘅分工**:
| 場景 | 用邊個 |
|---|---|
| 邏輯可以 extract 出去做 exportable helper | **Pure function derive**(已有 pitfall) |
| 邏輯係 global state / Map / cache / module-level singleton | **Source-check regression test**(呢個 pitfall) |
| Server 啟動就撞 port,根本 import 唔到 | **Source-check regression test** |
| Mock 對 ESM hoist 唔可靠 | **Source-check regression test** |
| 想 verify「真係改咗 source」而唔係「mock 行為啱」 | **Source-check regression test** |

**Prevention checklist**(寫 cache / global state / singleton 嘅 fix 之前):
- [ ] 確認要守嘅 invariant 係「**呢個 pattern 唔可以存在**」vs「**呢個 function 行為啱**」
- [ ] 如果係前者,用 source-check test
- [ ] Test 入面 4 個 assertion 齊:negative symbol、negative access、positive helper、positive comment
- [ ] Doc assertion 守住 RG-XXX entry 已 commit
- [ ] Comment 必須有 RG-XXX reference(防止 refactor 改走)

**Lesson**:**ESM 對 global state / module singleton 嘅 mock 不可靠**。當 invariant 嘅本質係「**呢樣嘢唔可以存在**」(cache Map / hard-coded secret / unsafe API call)時,直接 grep source code 係最穩嘅 regression test。**Derive pattern 同 source-check pattern 互補**,唔係二揀一。
