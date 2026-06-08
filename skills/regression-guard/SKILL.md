---
name: regression-guard
description: |
  防止修復過的 bug 重新出現(regression)。
  規則:每個修過的 bug 必須留下「regression test」+「root cause note」+「為何會發生」分析,
  確保日後 refactor / 改需求時唔會重新踩坑。
  David 在 2026-06-06 kanban task 明確指出「舊的 bug 又出現」嘅困擾。
trigger: |
  「bug 翻發」「regression」「舊 bug」「為什麼同樣嘅 bug 又出現」「fix 完又壞」
  或任何 bug 修復流程
  任何時候 audit `rbac.ts` / `logEvent` caller / RBAC seed coverage 嘅 workflow
  出現 "seed doesn't currently write RolePermission rows" 類 comment ＝ known-bug-without-RG-entry → 紅線 13 違規
version: 2
category: software-development
---

# Regression Guard — 防舊 Bug 翻發

> **為什麼需要這個 skill** — David 嘅實際困擾(2026-06-06 kanban task):
> 「因為現在我有好大體驗,覺得係啲 bug 翻發,舊的 bug 又出現的感覺」
>
> **根因分析**(根據 David 過去 session 觀察):
> 1. Bug fix 之後,只有「修咗」,冇留「點解會壞嘅解釋」+「防止再壞嘅 test」
> 2. Refactor / 改需求時,新嘅 code 違反咗原本 fix 嘅 invariant
> 3. 冇「為何會壞」嘅紀錄 → 6 個月後 debug 同樣 bug 嘅人(可能係 AI subagent)又踩同樣嘅坑
>
> **這個 skill 解決的就是:把「修 bug」從一次性事件變成「帶歷史的防護」**。

---

## 🎯 核心流程

```
Bug 發現 / 報告
    ↓
Step 1: 重現 bug(reproduce)
    ↓
Step 2: 寫 failing test(red)
    ↓
Step 3: 分析 root cause + 寫「點解會壞」紀錄
    ↓
Step 4: 修代碼 → test 變 green
    ↓
Step 5: 寫 regression test(就算原 bug test 已修好,再加邊界情況)
    ↓
Step 6: 寫 regression-guard entry 喺 `docs/REGRESSION-GUARD.md`
    ↓
Step 7: 喺 source code 加 comment 標記(防止 refactor 破壞)
    ↓
Step 8: 提交 + commit message 引用 entry ID
```

**紅線**:**冇 step 3 (root cause) 同 step 6 (guard entry) 嘅 bug fix 唔可以 merge**。

---

## 📁 文件結構

每個 project 必須有 `docs/REGRESSION-GUARD.md`,格式:

```markdown
# Regression Guard — <Project Name>

> 目的:追蹤所有修過嘅 bug,確保日後唔會重新踩坑。
> 規則:每個 bug fix 必須喺呢度留 entry,否則不算完成。

## 索引
| Entry ID | Bug 描述 | 發現日期 | 影響版本 | Root Cause | Regression Test | 狀態 |
|----------|---------|---------|---------|-----------|-----------------|------|
| RG-001 | 登入後 token 過期但 UI 唔跳 | 2026-05-12 | v1.2.0 | [see](#rg-001) | [test/auth.test.ts#expired-token-redirect](...) | FIXED |
| RG-002 | 圖片上傳 > 5MB 唔報錯 | 2026-05-20 | v1.2.1 | [see](#rg-002) | [test/upload.test.ts#size-limit](...) | FIXED |
| RG-003 | 註冊 email 重複檢查 race condition | 2026-06-01 | v1.3.0 | [see](#rg-003) | [test/auth.test.ts#concurrent-signup](...) | FIXED, MONITORING |

## 條目格式

<a id="rg-001"></a>
### RG-001 — 登入後 token 過期但 UI 唔跳轉到 login

**發現日期**: 2026-05-12
**發現者**: @David (用戶回報)
**影響版本**: v1.2.0 (released 2026-05-10)
**修復版本**: v1.2.1
**修復者**: @Backend-Bob
**Commit**: `a1b2c3d`

#### 症狀
- 用戶登入後用緊 30 分鐘
- 突然操作一個需要 auth 嘅 endpoint
- 後端回 401,但前端 UI 冇反應(冇跳轉、冇 toast)
- 用戶以為 app 壞咗,實際係 token 過期

#### Root Cause(為何會壞)
- 原本 `apiClient.ts` 有個 axios interceptor 處理 401
- 但 `interceptor` 只 refresh token,**冇** force logout
- 如果 refresh 失敗(refresh token 都過期),silently fail
- 前端冇 global error boundary 處理「auth 死咗」嘅情況

**教訓**:
1. 唔好假設 refresh token 一定 work — 要有 fallback
2. Auth state 變化要 broadcast(用 Event Bus / state machine)
3. UI 必須對「無法恢復嘅 auth 失敗」有明確用戶反饋

#### 防止再發(防護措施)
- [x] **Regression test**: `test/auth.test.ts#expired-token-redirect` 模擬 refresh 失敗 → 預期跳轉到 /login
- [x] **Code comment**: `apiClient.ts` 嘅 interceptor 加 `// RG-001: 唔好 silent fail,要 force logout if refresh fails`
- [x] **Invariant statement**: 「401 + refresh 失敗 = 強制登出」寫入 `docs/architecture/0007-auth-state-machine.md`
- [x] **Linting rule**: ESLint custom rule 禁止 `catch (err) { /* silent */ }` 在 auth-related code

#### 相關 Issue / Discussion
- [GitHub Issue #234](...)
- [Slack thread 2026-05-12](...)
```

---

## 📝 Step-by-Step 詳細執行

### Step 1: 重現 bug

**紅線:未確認能重現嘅 bug 唔可以 fix**。

```bash
# 1. 寫 reproduction script(寫到 /tmp/,唔好寫到 project)
cat > /tmp/repro_bug.py << 'EOF'
import requests
# 模擬 bug 嘅觸發條件
resp = requests.post("https://api.example.com/upload", files={"file": open("huge.jpg", "rb")})
print(f"Status: {resp.status_code}")  # 期望 413,實際 500
print(f"Body: {resp.text}")
EOF
python3 /tmp/repro_bug.py
```

**記錄**:
- 觸發條件(輸入、狀態、環境)
- 預期 vs 實際
- 重現率(100% / 偶發 / 特定條件)

### Step 2: 寫 failing test (Red)

**在正式 test suite 內加 test(唔好寫到 /tmp/!)**

```typescript
// test/upload.test.ts
describe('Image upload size limit', () => {
  it('should return 413 when file > 5MB', async () => {
    const hugeFile = new File([new ArrayBuffer(6 * 1024 * 1024)], 'huge.jpg', { type: 'image/jpeg' });
    const result = await uploadImage(hugeFile);
    expect(result.status).toBe(413);
  });
});
```

**確認**:`npm test` 跑呢個 test 係 **FAILING** (紅色)。如果 PASS,代表根本無 bug 或者 test 寫錯。

### Step 3: 分析 root cause(最關鍵!)

**要回答三條問題**:
1. **點解會壞?**(技術原因)
2. **點解之前冇人發現?**(process 原因)
3. **點解將來唔會再壞?**(prevention 設計)

```markdown
#### Root Cause

**技術原因**:
- `uploadHandler.ts:42` 用 `await file.arrayBuffer()` 之後直接 push 到 S3
- 冇 size check
- 過咗 Lambda 嘅 6MB payload limit 之後就 500

**Process 原因**:
- 之前只係用 1MB test file 做 integration test
- Production 環境啲用戶有時上傳 5-10MB 嘅相
- 冇 staging environment 用真實 size 測試

**Prevention 設計**:
- Client-side: 喺 file picker 加 size validation(防止用戶揀錯 file)
- Server-side: middleware 做 size check(防止 client-side 被 bypass)
- S3: 用 multipart upload for files > 5MB(支援大 file)
- Test: 加 regression test with 6MB file
```

**規則**:**技術原因 + process 原因都要寫**。淨寫「我加咗個 if 啦」係偷懶。

### Step 4: 修代碼

寫最少嘅 code 改動,確保 step 2 嘅 test 變 GREEN。

### Step 5: 寫 regression test

```typescript
// 加多幾個邊界 case
describe('Image upload edge cases', () => {
  it('should reject 5.1MB with 413', ...);
  it('should accept 4.9MB with 200', ...);
  it('should reject 0-byte file with 400', ...);  // 新加嘅邊界
  it('should handle concurrent uploads of large files', ...);  // 性能
  it('should not leak memory on rejected uploads', ...);  // 資源
});
```

**原則**:**預防性測試 > 反應性測試**。等個 bug 出咗先寫 test 永遠慢人一步。

### Step 6: 寫 REGRESSION-GUARD entry

按上面嘅模板,寫一個完整嘅 entry。

**重要:Entry ID 用 `RG-` + 3 位數遞增**(`RG-001`, `RG-002`...)。

### Step 7: 在 source code 加 comment

```typescript
// uploadHandler.ts
async function uploadImage(file: File) {
  // RG-002: 5MB size limit enforced client + server side
  // 修改前請睇 docs/REGRESSION-GUARD.md#rg-002 嘅 invariant
  if (file.size > 5 * 1024 * 1024) {
    throw new Error("FILE_TOO_LARGE");
  }
  // ...
}
```

**Comment 必須包含**:
- `RG-XXX` entry ID
- 一句 invariant 描述
- 連結到 REGRESSION-GUARD.md

### Step 8: 提交

```bash
git add src/uploadHandler.ts test/upload.test.ts docs/REGRESSION-GUARD.md
git commit -m "fix(upload): enforce 5MB size limit (RG-002)

- Add server-side size check
- Add regression test for 5.1MB upload
- Document root cause and prevention in REGRESSION-GUARD.md
- Add RG-002 comment marker in source code

Refs: RG-002"
```

**Commit message 必須引用 RG ID**,方便日後 `git log --grep "RG-002"` 找返所有相關 commit。

---

## 🔍 防止「同樣 bug 又出現」的具體策略

### 策略 1: Refactor 時嘅 Guard

當 refactor 涉及有 RG entry 嘅 code:

```
Refactor 開始
    ↓
git grep "RG-XXX" → 列出所有受影響位置
    ↓
逐個睇 invariant statement
    ↓
確認 refactor 冇違反任何 invariant
    ↓
跑對應嘅 regression test
    ↓
先可以 merge
```

### 策略 2: 改需求時嘅 Guard

當某個 US 改咗,可能影響之前嘅 RG entry:

```
改 US 影響分析
    ↓
檢查 REGRESSION-GUARD.md 入面,有冇 entry 嘅 invariant 同新 US 衝突
    ↓
如果有衝突:
    - 標記 RG entry 為 NEEDS_REVIEW
    - 在該 entry 加新嘅 section 講解衝突點
    - 跟用戶/PM 確認
    - 寫新 entry `RG-XXX-supersedes-RG-YYY`(保留歷史)
```

### 策略 3: 自動監控

```yaml
# .github/workflows/regression-check.yml
name: Regression Guard
on: [pull_request]
jobs:
  check-rg-references:
    runs-on: ubuntu
    steps:
      - uses: actions/checkout@v3
      - name: Check RG comment markers
        run: |
          # 改咗 src/ 但冇更新 REGRESSION-GUARD.md 嘅 PR → fail
          if git diff --name-only origin/main | grep -E "src/.*\.(ts|js|py)$"; then
            if ! git diff --name-only origin/main | grep -q "REGRESSION-GUARD.md"; then
              if ! git diff origin/main | grep -qE "RG-[0-9]{3}"; then
                echo "❌ Source code 改動冇引用任何 RG entry"
                echo "   要麼:1) 加 RG entry / 2) 確認唔影響現有 RG"
                exit 1
              fi
            fi
          fi
```

### 策略 4: 季度 RG Audit

每季做一次:
```
撈 REGRESSION-GUARD.md 全部 entry
    ↓
逐個睇:
    - regression test 仲跑唔跑?(有冇被 refactor 刪走?)
    - code comment 仲喺唔喺度?
    - invariant 仲 valid 唔 valid?(隨住 system 演進,可能已經唔適用)
    ↓
寫 audit report 喺 `docs/retros/YYYY-QX-regression-audit.md`
    ↓
發現失效嘅 entry → 標 DEPRECATED + 解釋
```

---

## 🆚 同其他文件嘅關係

| 文件 | 角色 | 互動 |
|------|------|------|
| `docs/PRD.md` | 講要做咩 | RG entry 可能引用 US(例:RG-002 違反咗 US-007) |
| `docs/architecture/*.md` | 講點樣做 | RG entry 可能引用 ADR(例:RG-003 因為 ADR-0005 嘅 trade-off 造成) |
| `docs/QA-TRACKER.md` | 持續測試追蹤 | RG 嘅 regression test 一定喺 QA-TRACKER 入面追蹤 |
| `docs/TECH-DEBT.md` | 技術債 | RG entry 升級做 tech debt 嘅情境:「個 fix 唔完美,將來要重做」 |
| `docs/feedback-loop.md` | 獎罰 | 沒寫 RG entry 嘅 bug fix 算 P1 過(已記錄喺 feedback-loop.md 嘅罰則) |

---

## 🚨 紅線 (新增)

加入 `SOUL.md` 嘅紅線清單:

> **紅線 13**:任何 bug fix 必須有對應嘅 `RG-XXX` entry 喺 `docs/REGRESSION-GUARD.md`,**冇 entry 嘅 fix 唔可以 merge**。

> **紅線 14**:Bug fix 必須有 root cause + prevention 兩部分,**淨寫 code 改動冇寫點解嘅 fix 唔可以 merge**。

> **紅線 15**:Refactor 涉及有 `RG-` 標記嘅 code 必須先確認冇違反 invariant,否則要開新 entry 講解取捨。

---

## 🎬 David 嘅實戰情境

情境:David 報 bug —「用戶密碼重設之後,登入之後個 session 仲係舊嘅,新密碼改咗但其他 device 仲可以用舊密碼登入」。

**正確流程**(用本 skill):
1. **重現**:Developer 寫 script 模擬兩 device + 重設密碼,確認 bug
2. **寫 failing test**: `test/auth.test.ts#password-reset-invalidate-sessions`
3. **Root cause 分析**:
   - 技術:`resetPassword` 只 update password hash,**冇** invalidate existing sessions
   - Process:之前 sprint planning 冇考慮「password change = security event = invalidate all sessions」呢個 invariant
4. **修 code**:加 invalidate logic
5. **加 regression test**: 加多 `it('should invalidate refresh tokens after password reset')`
6. **寫 RG-004 entry**:
   - ID:RG-004
   - 症狀:密碼重設後其他 device 仲用舊密碼有效
   - Root cause:密碼改動冇 trigger session invalidation
   - Prevention:所有 auth event(password change, email change, 2FA enable)都 invalidate sessions
7. **Code comment**:
   ```typescript
   // RG-004: 密碼重設必須 invalidate 全部 sessions
   // 違反呢個 invariant = 其他 device 仲可以用舊密碼
   await sessionStore.invalidateAllForUser(userId);
   ```
8. **Commit**:`fix(auth): invalidate sessions on password reset (RG-004)`

**錯誤流程**(冇用本 skill):
- 「我加咗個 invalidate call 啦,搞定」→ **冇 RG entry → 下次 refactor 又會踩**
- 「點解之前冇人 catch 到」 → 永遠唔會知道
- 「同樣嘅 bug 我一年撞 3 次」→ 唔會再撞嘅唯一方法就係**留下紀錄**

---

## ⚠️ Pitfall — logEvent API field-name drift in caller code (crm-system 2026-06-07, pre-existing)

**場景**: `apps/api/src/middleware/audit.ts:12-20` 定義嘅 `AuditEvent` interface 係:

```typescript
export interface AuditEvent {
  actorId: string | null;       // ← 正確 field name
  action: AuditAction;          // ← typed enum, NOT string
  resourceType?: string;
  resourceId?: string;
  description?: string;
  metadata?: unknown;
  request?: Request;
}
```

但 `apps/api/src/routes/settings.ts:88-95` 同其他舊 routes call 緊:

```typescript
await logEvent({
  userId,              // ❌ 錯 — interface 用 actorId
  action: 'CREATE',    // ❌ 錯 — 應該係 AuditAction.CREATE 唔存在(只係 PIPE 嘅 string,actual 係 'PIPELINE_STAGE_CREATED' 等)
  entity: 'PipelineStage',  // ❌ 錯 — interface 用 resourceType
  entityId: stage.id,       // ❌ 錯 — interface 用 resourceId
  description: `...`,
  request,
});
```

**症狀**: TypeScript 唔報錯(`@ts-nocheck` 喺 settings.ts) + `bun run --no-typecheck` boot OK + runtime Elysia 唔驗 shape = **每次 audit log 寫入實際係 `{ actorId: undefined, action: undefined, resourceType: undefined, ... }`** → Prisma `auditLog.create()` 因為 `action` 唔可以 null throw `TypeError: Invalid value` → logEvent 嘅 `try/catch` 靜靜 swallow 咗。**Audit log 永遠唔 write**。`console.error('[audit] failed to log event:', ...)` 但你冇 grep stderr 所以唔知。

**Root cause(為何會壞)**:
1. 早期 `logEvent` 可能用 `userId / action: 'CREATE' / entity: ...` (simplified shape)
2. 後來改用 `actorId / action: AuditAction / resourceType: ...` 嚴格 type
3. 舊 routes 冇跟住 update
4. 冇任何 test / smoke check audit log 寫成功
5. 冇 `rg "logEvent" apps/api/src/routes/` 嘅 audit

**3 個 prevention 措施**(必須一齊做):

1. **Caller code 跟 AuditEvent interface 100%**:
   ```typescript
   await logEvent({
     actorId: userId,                                            // ← 唔係 userId
     action: 'PIPELINE_STAGE_CREATED',                            // ← typed AuditAction
     resourceType: 'pipeline_stage',                              // ← 唔係 entity
     resourceId: stage.id,                                        // ← 唔係 entityId
     description: `Created stage "${name}"...`,
     metadata: { name, position: nextPosition, pipelineId: pipeline.id },
     request,
   });
   ```

2. **驗 audit log 真係寫到**:
   ```bash
   # Smoke test: trigger 一個 mutation, 直接 query audit_logs table
   PGPASSWORD=*** psql -h localhost -U crm -d crm -c \
     "SELECT action, resource_type, actor_id FROM audit_logs ORDER BY created_at DESC LIMIT 5;"
   # 預期: action 唔可以 NULL, actor_id 唔可以 NULL for authed calls
   ```

3. **Startup health check**(可選但推薦):
   ```typescript
   // apps/api/src/index.ts boot
   await prisma.auditLog.create({
     data: { action: 'USER_LOGIN', actorId: null, description: 'boot health check' },
   });
   await prisma.auditLog.deleteMany({ where: { description: 'boot health check' } });
   // 如果 AuditEvent 唔啱,boot 已經 fail
   ```

**Detection signal**(出現以下即 audit 所有 `logEvent` call site):
- `rg "logEvent\({" apps/api/src/routes/` → grep 全部 caller
- 任何 caller 用 `userId` 唔係 `actorId` ＝ 100% 壞
- 任何 caller 用 string literal 'CREATE' / 'UPDATE' / 'DELETE' 唔係 AuditAction enum value ＝ 100% 壞
- 任何 caller 用 `entity: ...` 唔係 `resourceType: ...` ＝ 100% 壞
- 任何 caller 用 `entityId: ...` 唔係 `resourceId: ...` ＝ 100% 壞
- @ts-nocheck 喺 caller file ＝ silently 唔報錯

**Pre-existing occurrences in crm-system** (2026-06-07 audit):
- `apps/api/src/routes/settings.ts:88-95` (PIPELINE_STAGE CREATE)
- `apps/api/src/routes/settings.ts:166-173` (PIPELINE_STAGE UPDATE)
- `apps/api/src/routes/settings.ts:221-228` (PIPELINE_STAGE DELETE)
- 任何其他用緊 `userId, action: 'CREATE'` pattern 嘅 route file

**Lesson**:Audit log 嘅 silent failure = 整個 security/observability 失明。Type drift 喺 `try/catch` 包住嘅 helper function 入面特別危險 — 永遠 silent。`@ts-nocheck` 喺 caller = 失去咗最後一道防線。**Solution**:做 code review 時必跑 `rg "logEvent" apps/api/src/routes/` 對齊 AuditEvent interface;`rg "userId.*action.*CREATE"` 撈 0 result 先 ship。

## ⚠️ Pitfall — RBAC seed coverage gap: rbac.ts reads from a table the seed never writes (crm-system 2026-06-07, CRITICAL)

**場景**: `apps/api/src/middleware/rbac.ts:50-66` 嘅 `userHasPermission(userId, permission)` 真係 query DB:

```typescript
export async function userHasPermission(userId: string, permission: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, role: true },
  });
  if (!user) return false;

  let roleId = user.roleId;
  if (!roleId) {
    const role = await prisma.role.findUnique({ where: { name: user.role } });
    if (!role) return false;
    roleId = role.id;
  }

  const perms = await loadRolePermissions(roleId);   // ← 讀 RolePermission table
  return perms.has(permission);
}
```

但 `packages/db/prisma/seed.ts` **完全冇 seed 過 `Role` / `RolePermission` row** = 個 table 永遠空 = `loadRolePermissions` 永遠 return empty Set = **`userHasPermission` 永遠 return false** = **任何 `requirePermission(...)` gate 都會 silently 403 所有 user**(包括 ADMIN)。

**症狀**:
- 冇 admin 任何人可以 hit requirePermission-gated endpoint
- 公開 endpoint(`GET /companies` etc.)OK 因為冇 gate
- `rbac.ts:84` 嘅 `getUserIdFromRequest` 真係 verify JWT,所以 userId 唔係 null
- 403 response 看似正常(permission denied),但其實 ALL users 都 fail,包括 ADMIN
- 開發人員如果用 ADMIN token 跑 smoke test,會 403 → 誤以為自己嘅 perm 唔啱 → 走去 debug role / permission 名 → 浪費幾個鐘
- 已知存在 comment: `apps/api/src/routes/man-day-role.ts:29` 直接寫 `"because the seed script doesn't currently write RolePermission rows"` — 即係個 project 知道呢個 bug 但冇 RG entry,冇 red-line 跟進

**Root cause(為何會壞)**:
1. `rbac.ts` 設計上 read DB table (RolePermission) — 正確
2. 開發人員 `roles.ts:131-138` 有 `tx.rolePermission.createMany()` — 即係 UI 可以寫入
3. 但 seed 從來冇做呢步
4. Production 環境 ADMIN 由 UI 改自己嘅 role 之前,冇辦法 access 任何 requirePermission-gated endpoint
5. 冇 integration test 撞「fresh DB + new user + 任何 perm check」

**3 個 prevention 措施**(必須一齊做):

1. **Seed `Role` + `RolePermission` rows** from `packages/shared/src/permissions.ts` source of truth:
   ```typescript
   // packages/db/prisma/seed.ts
   const { PERMISSIONS } = await import('@crm/shared/permissions');
   const allKeys = Object.keys(PERMISSIONS) as Permission[];
   const ROLE_PERMS: Record<string, string[]> = {
     ADMIN:  allKeys,
     SALES:  ['company:read', ...],   // match shared/permissions.ts
     VIEWER: ['company:read', ...],
   };
   for (const roleName of ['ADMIN', 'SALES', 'VIEWER'] as const) {
     await prisma.role.create({
       data: {
         name: roleName,
         displayName: '...',
         isSystem: true,
         permissions: { create: ROLE_PERMS[roleName].map((p) => ({ permission: p })) } },
       },
     });
   }
   // User FK → Role, 所以一定要喺 user.create() 之前
   ```

2. **Wire `User.roleId`** 喺 seed,fallback 邏輯仍然 work 但 cache 更穩:
   ```typescript
   const adminRole = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
   await prisma.user.create({
     data: { email: 'admin@crm.local', ..., roleId: adminRole?.id, role: 'ADMIN' },
   });
   ```

3. **Integration smoke 撞 fresh DB + ADMIN access**:
   ```bash
   # 跑完 `bun run db:reset` 後:
   bun run db:seed
   TOKEN=*** -X POST localhost:3001/auth/login -d '{"email":"admin@crm.local","password":"admin123"}' | jq -r .token)
   curl -H "Authorization: Bearer *** localhost:3001/users
   # 預期 200, 唔係 403
   ```

**Detection signal**(出現以下即 audit RBAC seed coverage):
- 任何 `rbac.ts` 嘅 `userHasPermission` / `loadRolePermissions` function
- 任何 `requirePermission(...)` middleware call
- 對照 `packages/db/prisma/seed.ts` — 有冇 create `Role` + `RolePermission`?
- 對照 `packages/shared/src/permissions.ts` — 每個 permission 有冇對應 Role 嘅 seed entry?
- `rg "rolePermission.createMany" --type ts` 撈 seed 入面有冇用
- `rg "from '@crm/shared/permissions'" seed.ts` 撈 seed 有冇 import 個 shared source of truth

**Pre-existing bug class in crm-system** (2026-06-07 audit):
- `man-day-role.ts:29` 嘅 comment 直接 acknowledge: "because the seed script doesn't currently write RolePermission rows" → **known-bug-without-RG-entry**(紅線 13 違規)
- 任何 commit series 加 `requirePermission(...)` 喺 P0 security review 嗰陣,冇配套 seed 改動 = production 死
- 2026-06-07 P0-2 (companies/contacts/deals routes 公開) 修補加入 RBAC **silently 封死咗所有 user** 對呢啲 endpoint 嘅 access,因為冇 seed 配套

**Lesson**:**任何 RBAC middleware 嘅 read path 必須有對應 seed 嘅 write path**,否則係 100% production 死。**Audit checklist**:
- [ ] `rbac.ts` / `permission.ts` 嘅 read path list(全部)
- [ ] `seed.ts` 嘅 write path list(全部)
- [ ] 對齊:每個 read 都有對應 write
- [ ] 對齊:每個 `requirePermission` string literal 喺 seed 嘅 `ROLE_PERMS[role]` 入面
- [ ] Integration smoke: fresh DB → seed → login → 撞每個 requirePermission endpoint
- [ ] Staging 環境 deploy 後做一次 same smoke(prod mirror)

## ⚠️ Pitfall — Pitfall — `Record<EnumType, ...>` map + backend emit 唔同步

**場景**(2026-06-06 crm-system audit log bug):

```typescript
// lib/api.ts
type AuditAction = 'USER_LOGIN' | 'QUOTATION_CREATED' | 'DEAL_CREATED' | ...;  // 漏咗 12 個

// pages/audit.tsx
const ACTION_LABELS: Record<AuditAction, { label: string; variant: BadgeVariant }> = {
  USER_LOGIN: { label: '登入', variant: 'info' },
  QUOTATION_CREATED: { label: '建立報價', variant: 'success' },
  // ... 24 entries
  // ❌ 漏 DEAL_STAGE_CHANGED, PRODUCT_*, SERVICE_*, ROLE_*, REGION_*
};

function AuditRow({ event }) {
  const meta = ACTION_LABELS[event.action];   // 返 undefined
  return <Badge variant={meta.variant}>...</Badge>;  // 💥 TypeError: Cannot read 'variant' of undefined
}
```

**症狀**:Runtime 撞到 9 個 backend action(33 個 emit vs 24 個 map),**成個 row 即刻 dead**,之後嘅 row 全部唔 render。

**3 個同步 root cause**:
1. **Backend 加新 audit event 唔 update frontend map**
2. **`AuditAction` type union 唔 cover 新 enum value** — TypeScript 冇 catch 到
3. **冇 fallback** — 一旦 miss,row 即死,冇 graceful degradation

**正確防護**(必須 3 個一齊做):
1. **Map + Type union 同步 exhaustive**:每次 backend 加 audit event,frontend map 同 type union 必須**同一個 commit** 同步更新
2. **Helper fallback**:
   ```typescript
   function getActionMeta(action: string) {
     return ACTION_LABELS[action as AuditAction] ?? {
       label: action,                    // raw enum 顯示
       variant: 'secondary' as const,    // gray badge
     };
   }
   ```
3. **Type union 改用 `string` 寬鬆** 或用 **switch + exhaustiveness check**:
   ```typescript
   function assertNever(x: never): never { throw new Error(`Unhandled: ${x}`); }
   ```

**檢測信號**(出現以下就 audit 個 codebase):
- 任何 `Record<EnumType, ...>` map 喺 frontend(`ACTION_LABELS`, `STATUS_VARIANTS`, `ROLE_PERMISSIONS`...)
- Backend emit `auditLog.create({ action: 'X' })` 嘅 enum
- 兩者唔喺同一個 PR / 唔 exhaustiveness check

**預防 checklist**(新增 audit event 時):
- [ ] `lib/api.ts` 加 entry 入 `AuditAction` type union
- [ ] 對應 page 嘅 label map 加 entry
- [ ] Helper 加 fallback(就算 miss 都唔 crash)
- [ ] `npm run typecheck` 確認 exhaustive
- [ ] Hit backend 一個 event 確認 row render 成功

**Lesson**:Enum-driven mapping 嘅 design 必須有 **defensive fallback** + **exhaustive type union** + **cross-stack sync discipline**(backend 加 enum 嘅同時 frontend 三處要一齊改)。

## ⚠️ Pitfall — Plan doc wording vs backend wire shape (silent 400 on first PUT)

**場景**(2026-06-07 crm-system Day 14.7 Step 5/7):Plan doc 用「default tax rate」呢個 human-readable wording,developer 就 follow plan 同樣嘅 naming convention 寫 client wrapper:

```typescript
// Step 5 — Plan doc 入面嗰個 term 嘅 1:1 translation,以為係 source of truth
export interface TaxConfig {
  defaultTaxRate: number;     // ← Plan doc wording
  updatedAt?: string;
  updatedBy?: string;
}

export const settingsApi = {
  getTax: () => request<TaxConfig>('/settings/tax'),
  putTax: (data: { defaultTaxRate: number }) =>     // ← 同 Plan 一樣
    request<TaxConfig>('/settings/tax', { method: 'PUT', body: JSON.stringify(data) }),
};
```

但 backend 真係 wire 嘅 field name 唔同:

```typescript
// apps/api/src/routes/settings.ts:296 — 真正寫入 Prisma 嘅 field
const { rate } = body as { rate: number };        // ← 唔係 defaultTaxRate
const updated = await prisma.systemConfig.upsert({
  where: { key: 'default_tax_rate' },
  update: { value: rate, ... },                    // ← wire field = "rate"
  create: { key: 'default_tax_rate', value: rate, ... },
});
```

**症狀**:
- `tsc --noEmit` 0 errors(client wrapper type 100% self-consistent)
- `GET /settings/tax` 200,read 返嚟個 value 仲可以秀到(因 server side Prisma default null,graceful fallback)
- `PUT /settings/tax` 即刻 400(Zod validation: `Expected pick 'rate', got 'defaultTaxRate'`)
- E2E 撞 POST 先 catch 到,**唔做 E2E 永遠唔知**
- 個 user 第一次按 Save 嗰陣 400,UI 顯示 generic error message

**Root cause(為何會壞)**:
1. **Plan doc 嘅 human-readable wording 唔等於 wire field name**。Plan doc 寫「default tax rate」係 marketing-friendly 唔係 database field。
2. **Client 冇** grep backend source:`grep "value:" apps/api/src/routes/settings.ts` 一行就見到 `value: rate`。
3. **冇 E2E smoke 喺 Step 5 嘅 commit 之後**。如果做咗:`curl -X PUT /api/settings/tax -d '{"rate":13}'` → 200,再跑 `curl -X PUT ... -d '{"defaultTaxRate":13}'` → 400,兩個 shape 對比即刻 catch。
4. **`request<TaxConfig>(...)` 嘅 generic type 唔係 runtime validation** — T 係 compile-time promise,fetch 過嘅 JSON runtime shape 唔檢查。

**Prevention(必須 2 個一齊做)**:

1. **Client wrapper 跟 backend source of truth,唔跟 plan doc wording**:
   ```bash
   # Step 5 第一個 action:睇 backend GET + PUT response shape
   curl -s http://localhost:3001/api/settings/tax | jq .
   # 跟住:睇 backend write path
   grep -n "value:" apps/api/src/routes/settings.ts
   # 然後寫 client wrapper
   ```
   ```typescript
   export interface TaxConfig {
     key: string;
     rate: number;                                    // ← backend wire field
     description?: string | null;
     updatedAt?: string | null;
     updatedBy?: { id: string; name: string; email: string } | null;
   }
   putTax: (data: { rate: number }) => ...            // ← wire field, 唔係 Plan doc
   ```

2. **任何新增 endpoint 嘅 commit 必須跟住 E2E smoke**:
   ```bash
   # 1. Login
   TOKEN=*** -X POST localhost:3001/api/auth/login -d '...' -H 'Content-Type: application/json' | jq -r .token)
   # 2. Read 返 shape
   curl -s -H "Authorization: Bearer *** http://localhost:3001/api/settings/tax | jq .
   # 3. PUT 兩次,正反 case 確認 wire field name
   curl -X PUT -H "Authorization: Bearer *** -H "Content-Type: application/json" \
        -d '{"rate":13}' http://localhost:3001/api/settings/tax
   # 4. DB 確認 row 寫入
   ```

**Detection signal**(出現以下即 audit 全部新 client wrapper):
- 任何 `interface` 命名跟 plan doc wording 但唔跟 backend grep result
- 任何 PUT/POST 冇立即跟 smoke test
- 任何新 endpoint 嘅 wire field 同 user-facing description 不對應
- 任何 `request<T>(...)` 用 generic type 但冇 runtime validation(zod / io-ts / arktype)

**Lesson**:**Plan doc 嘅 wording 係 for human communication;backend grep result 係 source of truth**。Step 5 應該 immediately `grep "value:" backend/src/routes/<file>` 攞 wire field name,然後寫 client wrapper。任何寫「client-side interface 先,backend smoke 最後」嘅 workflow = 高風險 silent 400。

## ⚠️ Pitfall — Form refactor 破壞原本 working code 嘅 silent regression

**場景**(2026-06-08 crm-system 統一 `ManDayEditor` refactor):

我抽 `ManDayEditor` 共享 component 嚟取代 `service-detail.tsx` 同 `QuickCreateServiceDialog` 兩處獨立嘅 form。**Tsc pass ✅ + Docker build pass ✅ + 推到 origin/main ✅**。**但 UI 完全壞咗**:
- `ManDayEditor` 個 `value: ServiceManDay[]` props 從未 sync 入 parent state
- 5 個 `Input` share 同一個 `row.roleName` global,唔係 per-row
- Submit 出去嘅 wire payload 全部 5 個空 row → backend `TypeError: Cannot read 'properties' of undefined`
- User 開個 service form 睇唔到 man-day role section,save 失敗 500

**冇任何人 catch 到**,因為:
- ❌ 我冇跑 browser smoke 喺 push 之前
- ❌ tsc pass 嘅錯覺以為 type-safe = runtime-safe
- ❌ 我 patch 嗰陣 replace 咗成個 file,**冇保留原本 working 嘅 state shape** 嘅完整 list
- ❌ 冇任何 test 阻擋(紅線 16 違規)

**真正嘅教訓 — Form refactor 必須遵守嘅 4 條紀律**:

1. **抄原本 working file 嘅完整 state list 先**:
   ```bash
   # 步驟 0: 攞原本 working file 入 /tmp
   git show dcae100:apps/web/src/components/quick-create-service-dialog.tsx > /tmp/ORIG-dialog.tsx
   # 然後清點所有 useState 嘅 setter + 全部 controlled input 嘅 value/onChange
   ```
2. **refactor 唔可以 overwrite 整個 file** — 用 patch 增量改,逐段 verify
3. **refactor 完必須跑 form 嘅 happy path**:
   - Browser navigate 去個 page
   - 填 form
   - Submit
   - 撳返 detail page 確認 DB round-trip 啱
4. **P0 form feature 必須有 happy-path E2E test** — 冇 test = silent regression risk

**檢測信號**(出現以下就要 audit form 改動):
- 任何 `useState` 個 setter `setFoo` 喺 parent 但個 form 用緊 prop 唔 trigger sync
- 任何 `<Input value={x} onChange={...}>` 但 onChange 唔更新 x
- 任何 controlled input 數量 > 5 個 per row
- 任何 form 嘅 wire payload 喺 submit 時 `JSON.stringify(form)` 個 keys 唔等於 expected schema

**預防 checklist**(form refactor 必跑):
- [ ] 攞原本 working file 嘅完整 state list 入 `/tmp/ORIG-*.tsx`
- [ ] 清點所有 `useState` setter
- [ ] 驗證每個 controlled input 嘅 `value` / `onChange` 對應到邊個 state
- [ ] 用 patch 增量改,唔好 overwrite 整個 file
- [ ] 改完跑 form happy path 喺 browser
- [ ] 確認 wire payload 嘅 keys / shape 同 backend expected 一致
- [ ] 確認 DB round-trip 啱(GET 返個 entity 睇 fields 都齊)
- [ ] (P0 form) 加 happy-path E2E test

**Lesson**:`tsc pass` 永遠唔等於 `feature work`。Frontend form refactor 嘅黃金標準係**原本 working code path 一個字都唔可以掉**。

## ⚠️ Pitfall — User 喺你前面 commit 咗,你重做撞 hash

**場景**(2026-06-09 crm-system Day 10 doc sync):David 喺我 recon 嗰陣自己 commit 咗 `d79930e fix(ai): T1 nav label + T2/T3 chat route config + permission fix`,完全做齊 RG-002/003/004 嘅 3 個 fix。我**冇**睇 `git log origin/main..HEAD` 就 commit 我嘅 `c0d11b1 feat(ai): Day 10 AI Assistant infrastructure`,**入面包咗我重做嘅 `chat.ts` 改動** — push 之前先睇 log 發現撞。

**症狀**:`git log origin/main..HEAD` 出現 David 個 `d79930e`,而我嘅 `c0d11b1` 改 `apps/api/src/routes/chat.ts` 同 David 改嘅**完全一樣**。冇 `git diff d79930e..HEAD -- apps/api/src/routes/chat.ts` 報 conflict(因為 git 3-way merge 接受兩個 identical change),push 咗上去 remote 就有 duplicate commit。

**修正流程**:
```bash
# 1. Push 之前必跑
git log --oneline origin/main..HEAD

# 2. 如果撞 David 個 commit,soft-reset + unstage 衝突 file + reset 個 file 返 David 版本
git reset --soft HEAD~1                    # 取消我自己個 commit,file 留喺 staged
git reset HEAD <conflicted-file>          # unstage 個 file
git checkout <david-commit-sha> -- <file> # working tree 換返 David 版本
# 3. Commit 返只 stage 咗嘅、真正新嘅 file,commit message 引用 David hash:
git commit -m "feat(ai): Day 10 infrastructure

Note: chat.ts fix was already shipped by David in d79930e (RG-002/003 +
T2/T3 spec). This commit re-uses that version via git checkout to
avoid duplicate work on origin.

Refs: d79930e"
```

**預防 checklist**(任何 long session commit 之前必跑):
- [ ] `git log --oneline origin/main..HEAD` — 睇有冇 David 親做嘅 commit 我冇 follow 到
- [ ] `git diff <david-commit>..HEAD -- <file>` 逐個 file 比較,確認冇 identical change
- [ ] 如果撞,**soft reset + checkout David 版本 + reference** — 唔好 duplicate
- [ ] 跟住先 commit 真正新嘅 work

**Lesson**:長 session 入面,David 會主動 commit / push 佢自己嘅 fix。**做 commit 之前永遠當 origin 有新嘢**。`git log origin/main..HEAD` + `git diff <sha>..HEAD -- <path>` 係兩條強制 command,任何 commit 之前必跑。

## ⚠️ Pitfall — 8 份 doc file 嘅 doc sync pattern (紅線 10/11/13/14)

**場景**:每次 ship 一個有架構性嘅 feature(新 schema、新 package、新 route family),紅線 10 要求 8 份 doc 必須 commit:

| File | 必填時機 | Owner |
|------|---------|-------|
| `docs/PROJECT-OVERVIEW.md` | Plan 結束(隨首個 code commit) | 你 |
| `docs/PRD.md` | 改 US 嘅同時必更新 | 你 |
| `docs/DESIGN.md` | 設計定稿時 | 你 |
| `docs/architecture/NNNN-*.md` | 每個重大架構決策即時 | 你 |
| `docs/API.md`(如有 API) | 每個 endpoint 上線前 | 你 |
| `docs/TEST-COVERAGE.md` | 每個 sprint 結束時 | 你 |
| `docs/QA-TRACKER.md` | 改 PRD 嘅同時必更新 | 你 |
| `docs/REGRESSION-GUARD.md` | 每個 bug fix | 你 |

**Anti-pattern**(2026-06-07 crm-system 親驗):5 個 task 嘅 code + backend smoke 全部 ship,**但 8 份 doc 一份都冇** — 「**冇文件嘅 code 唔可以 merge**」嘅紅線 10 直接踩。David 嘅 spec:「更新了docs 未」一問先知。

**正確 audit-driven fix flow**:
```
recon 結論(懷疑 T2/T3 缺 infrastructure)
    ↓
完整 audit(DB schema / routes / frontend / RBAC 全部)
    ↓
確認 3 個 audit bug(RG-002 env-var drift / RG-003 503 translation / RG-004 缺 permission)
    ↓
每個 bug 修 + 寫 RG-XXX entry(invariant 必須語句化,例如 "MUST NEVER read OPENAI_API_KEY env var")
    ↓
8 份 doc 同步寫 — 一個 commit series 3 個 atomic commit:
  1. backend / 2. frontend / 3. docs
    ↓
DB smoke + curl smoke + commit message 引用 RG ID + push
```

**Doc scope 速查**(每份 file 寫咩):

| Doc | 必含 sections |
|-----|---------------|
| PROJECT-OVERVIEW | one-line summary / tech stack / repo layout / day-by-day history / Day-N feature 一段講晒 |
| PRD | Epic + US + status legend + backlog + change log |
| DESIGN | 視覺語言 tokens / layout / component lib / page patterns / Day-N UI specifics / RWD |
| API | Conventions(URL/auth/err shape)/ 全 endpoint per resource / Day-N 新 endpoint 完整 |
| TEST-COVERAGE | Test layers 定義 / US→test matrix / manual smoke checklist |
| QA-TRACKER | US status table / Day-N batch audit table / smoke test results / open follow-ups |
| architecture/NNNN- | Status / Context(其他 option)/ Decision / Rationale / Consequences / Alternatives |
| REGRESSION-GUARD | RG-XXX entry template(發現日 / root cause 技術+process / invariant / prevention)+ 索引表 |

**Lesson**:**ship 完整 feature 嘅 closing loop 永遠係「code + smoke + doc + RG entry + push」5 步**。漏 doc = 紅線 10 違規 = 用戶問「更新了docs 未」= 你要返嚟重做。

---

## 📊 衡量指標

每個 project 嘅 health check:

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| 過去 90 日新增 RG entry 數 | < 5 | 5-15 | > 15(可能 process 有問題) |
| RG entry 標 NEEDS_REVIEW 嘅比例 | < 10% | 10-30% | > 30%(需求變更太頻繁沒管理) |
| Regression test 跟 code 一齊 commit 嘅比例 | 100% | 80-99% | < 80% |
| 季度 audit 發現失效 RG 嘅比例 | < 5% | 5-20% | > 20%(audit 太少) |

**注意**:`過去 90 日新增 RG entry 數` 健康值低,代表 codebase 穩定。**唔係「愈少 bug 愈好」**— 可能係冇發現 bug 嘅 reflection。

## 📚 Related references

- `references/crm-system-2026-06-07-rbac-seed-and-audit-log-silent-failures.md` — Two pre-existing CRITICAL bugs found while building Day 14 System Settings: (1) `rbac.ts:50-66` reads from a `RolePermission` table the seed never wrote, silently 403ing all requirePermission-gated endpoints in production (including ADMIN); (2) every audit log call in `settings.ts` uses wrong field names (`userId` vs `actorId`, `entity` vs `resourceType`, etc.) so audit log writes silently fail inside `logEvent`'s `try/catch`. Includes detection recipes, fix code, and prevention checklists. **Read this if you ever audit a project that has `rbac.ts` + `audit.ts` + `seed.ts` together — these two bugs are CLASS-level, not project-specific.**
