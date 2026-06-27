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
Step 5.5: 補 / 驗證 frontend + backend regression hook,記錄 QA 啟用方式與 production safety；如不需要 hook 必須寫 N/A 理由
    ↓
Step 6: 寫 regression-guard entry 喺 `docs/REGRESSION-GUARD.md`
    ↓
Step 7: 喺 source code 加 comment 標記(防止 refactor 破壞)
    ↓
Step 8: 提交 + commit message 引用 entry ID
```

**紅線**:**冇 step 3 (root cause) 同 step 6 (guard entry) 嘅 bug fix 唔可以 merge**。有 regression test 但 QA 無法友善啟用 / 重跑 / 驗證，且冇明確 N/A 理由，視為 regression guard 不完整。

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

#### QA Regression Mode
- **Frontend hook**: [例如 `data-testid`, QA panel, visual freeze control；無則 N/A + 理由]
- **Backend hook**: [例如 `/__qa/regression/RG-001`, seed/reset/mailbox/test clock；無則 N/A + 理由]
- **QA enablement**: [QA 如何啟用 fixture / switch]
- **Seed/reset data**: [test tenant / fake mailbox / sandbox data]
- **Test command**: [`test:regression:rg -- RG-001` 或等價命令]
- **Expected result**: [QA 應看到什麼]
- **Safety boundary**: [dev/test/staging only; auth/permission/rate limit 不可 bypass]
- **Production exposure check**: [`/__qa/*` production 404/403, `REGRESSION_MODE=true` production hard fail / reject]

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


### Step 5.5: 補 / 驗證 QA Regression Mode

Regression test 寫完後，必須讓 QA 知道點樣重跑同驗證：

1. **Frontend hook** — `data-testid` / `aria-label` / QA panel / visual freeze control；無需要則寫 N/A 理由
2. **Backend hook** — `/__qa/seed` / `/__qa/reset` / fake mailbox / test clock / queue drain / `RG-XXX` fixture；無需要則寫 N/A 理由
3. **QA enablement** — 寫明 test command、seed command、expected output
4. **Safety boundary** — 只限 dev/test/staging；production 不 mount `/__qa/*`，不接受 regression mode 作為 bypass
5. **No bypass** — 不可 disable auth / permission / rate limit / audit / security behavior；測試要配合真實 production behavior

**規則**:Regression mode 係 deterministic fixture / observability / orchestration，唔係後門。QA hook 若會動資料，backend 必須重新驗證 env + auth + tenant scope。

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

## ⚠️ Pitfall — Pure function derive from inline route logic for unit test (2026-06-08 pm-system Sprint 1)

**場景**:route 邏輯入面晒 inline(`worklogs.ts` 內 `computeWorkLogPagination` / `isEditableForCurrentMonth`、`agents.ts` 內 `canClaimTask`),**冇 extract 出嚟做 exportable helper**。要寫 unit test 守住 RG guard 嗰陣,直接 `import` route file 會 trigger 全部 prisma / elysia / middleware dependency — 根本行唔到。

**症狀**:
- `import { ... } from './worklogs'` → bun test 撞 `Cannot find package 'elysia'`
- Mock 晒 prisma 嘅路太重,test 變 integration test
- 冇 helper function 可以 unit test,RG entry 永遠 ❌ Regression test
- 「冇 test 守住舊 bug」一直係真實狀態

**正確做法 — 3 步 derive pattern**(2026-06-08 pm-system Sprint 1 親驗 OK):

1. **抄源碼 inline logic 入 test file 頂部,做 local helper**:
   ```typescript
   // backend/src/routes/agents.test.ts 頂部
   export function canClaimTask(
     user: AuthUser | null,
     isAgentFlag: boolean | null | undefined,
     task: TaskSnapshot
   ): { ok: true } | { ok: false; code: 'UNAUTHORIZED' | 'FORBIDDEN' | 'BAD_REQUEST'; message: string } {
     // 100% 對齊 routes/agents.ts POST /claim-task 嘅 validation 邏輯
     if (!user) return { ok: false, code: 'UNAUTHORIZED', message: 'Authentication required' }
     if (!isAgentFlag && !hasPermission(user, 'tasks.claim')) {
       return { ok: false, code: 'FORBIDDEN', message: 'Only agents can claim tasks or tasks.claim permission required' }
     }
     if (task.status !== 'pending') return { ok: false, code: 'BAD_REQUEST', message: `Task is not available. Current status: ${task.status}` }
     if (task.assigneeId) return { ok: false, code: 'BAD_REQUEST', message: 'Task is already assigned' }
     return { ok: true }
   }
   ```

2. **用 comment 標明「derive 自 source file:line」**:
   ```typescript
   /**
    * Derive 自 routes/agents.ts:238-293 (claim-task handler) 嘅 pure validation logic。
    * 100% 對齊 source 嘅 4 個 check + 對應 status code。
    * 將來 route 改動要同步 update 呢個 helper + 跑 test。
    */
   ```

3. **Sprint 補 test checklist**(可重用):
   - [ ] 揀要守嘅 RG-XXX entry / P0 US(per TEST-COVERAGE.md § 3)
   - [ ] 讀對應 route file inline 邏輯,derive 出 local helper(同 source 100% 對齊)
   - [ ] Helper 入面寫「derive 自 file:line」comment
   - [ ] 寫 5-15 個 test cases(critical path + boundary + admin bypass edge case)
   - [ ] 跑 `bun test src/<path>/<file>.test.ts` 確認全綠
   - [ ] **後續 refactor 必須同步 update 兩處**,或者正式 extract helper 入 route file

**踩坑親驗**(2026-06-08 pm-system `agents.test.ts`):我第一版寫「admin user without isAgent and without tasks.claim is forbidden」—— **test 立即 fail**,因為 `hasPermission` 對 `role === 'admin'` 會 bypass 任何 permission check。即係話:source 嘅 admin bypass 行為我誤解咗,**冇 test 永遠唔會發現**。修正:加埋「admin user bypasses isAgent check via hasPermission admin bypass」case + comment 解釋點解 expected = true。**呢個就係 test 嘅 value —— 守 source 嘅真實行為,而唔係我以為嘅行為**。

**冇 derive 嘅後果**:
- RG entry 永遠 ❌ Regression test
- Tech debt TD-001(測試覆蓋率)永遠高 priority
- 「fix 完又壞」嘅痛點重現(因為 refactor 冇 invariant guard)
- 紅線 12(P0 US 必有 test)+ 紅線 13(冇 RG entry 嘅 fix 唔可以 merge)兩條齊踩

**Lesson**:**derive pure function for unit test 係 RG guard 嘅救命稻草**。Inline logic 無法直接 test → 抄出嚟做 local helper → 守住 invariant → refactor 時用對齊 comment 提醒自己同步。**Sprint 補 test 嘅 default 模式**。

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

## ⚠️ Pitfall — Source-check regression test (when ESM mocking fails for global state)

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

## ⚠️ Pitfall — External spec assumption (Alpine `apk add` package, npm package, OS binary) not verified before committing (2026-06-16, pm-system Sprint 21, class-level)

**場景**:Plan-stage design doc, blog post, Stack Overflow answer, or even a previous project's Dockerfile specifies a package or binary name. Developer copies that name into a Dockerfile, `package.json`, or `apt-get install` line, commits, and pushes — **without verifying the package exists in the target repo**. Build fails only at the layer that needs the package, and only after the rest of the Dockerfile is built. Time wasted: ~30 seconds to a few minutes per failed build. Worse: the failure often surfaces post-merge (after a PR review) when the team tries to actually build the new image.

**真實 hit**(2026-06-16 pm-system Sprint 21):Dockerfile wrote `apk add poppler-utils antiword xls2csv catdoc` based on a plan-stage design doc. `antiword` exists in Alpine v3.22 official repo, but **`catdoc` and `xls2csv` do not**. The first `docker build` failed at layer 2:

```
ERROR: unable to select packages:
  catdoc (no such package):
    required by: world[catdoc]
  xls2csv (no such package):
    required by: world[xls2csv]
```

Sprint 21 was already merged (commit `46323bf`) when the failure surfaced in the user's dev environment. Required a hotfix commit on top of merged work + a `Hotfix US-21.1.1` audit trail entry in the retro doc.

**Why this trap is hard to spot before commit**:
- The packages are real and well-known (`catdoc` is a classic `.doc` reader, `xls2csv` is the standard Perl script). They DO exist in Debian/Ubuntu repos, in Homebrew, and in older Alpine versions (pre-v3.18).
- Plan docs / blog posts / Stack Overflow answers quote them without version-checking.
- The base image `oven/bun:1-alpine` ships with **no man pages and no docs** for what Alpine version it tracks, so you can't `cat /etc/alpine-release` to guess package availability.
- Tsc / lint / unit tests all pass before the docker build attempt — the failure is in the deployment layer, not the code layer.

**5-second verification recipe**(no build needed — use the base image's package manager):

```bash
# Alpine (oven/bun:1-alpine, alpine:3.x, etc.)
docker run --rm <base-image> sh -c "apk search 2>&1 | grep -E '^(<pkg1>-|<pkg2>-|<pkg3>-)' | head -10"

# Debian (oven/bun:1.2, node:20-slim, etc.)
docker run --rm <base-image> sh -c "apt-cache search <pkg1> <pkg2> | head -10"

# npm (no docker needed)
npm view <pkg-name> version 2>&1 | head -3   # exists? + latest version
npm view <pkg-name> deprecated 2>&1          # 0 result = OK
```

If a package isn't in the output, **it's not in the repo**. Find a real alternative (`apk search <keyword>` returns the full candidate list). For Alpine specifically, the full repo index is at `https://pkgs.alpinelinux.org/packages?name=<pkg>` — usable from the host without a docker pull.

**Real alternative-finding workflow**(2026-06-16 pm-system Sprint 21 case):

| Wanted | Verified absent | Real alternative found via `apk search` |
|--------|-----------------|-----------------------------------------|
| `catdoc` (`.doc` fallback) | confirmed no such package | `wv` (provides `wvText`) |
| `xls2csv` (`.xls` parser) | confirmed no such package | `gnumeric` (provides `ssconvert`) |
| `antiword` (`.doc` parser) | exists, no swap needed | — |

So the working `apk add` is `poppler-utils antiword wv gnumeric`. The fix also requires updating the source code in `src/` that calls the binary (e.g. swap `catdoc` command → `wvText`, update error messages, update tests).

**Cross-stack prevention**(4 layers, do all):

1. **Before writing `Dockerfile` / `package.json` / `requirements.txt`** — run the 5-second verify recipe above. **If you skip verify, you accept the build-fail risk**.

2. **Before merging a PR that adds a new package or external binary** — reviewer (or self-review) runs the verify command for each added line. CI doesn't typically run `docker build` on every PR, so the check is human.

3. **In retro / ADR docs** — always include a "Why NOT X" section explaining the alternatives considered and why they were rejected. If a later hotfix swaps a package, the retro entry becomes the audit trail.

4. **In the source code that calls the binary** — if the binary is swapped, update the call site AND the error messages AND the tests. The build will pass with the old call site if the binary is still on PATH (e.g. ssconvert is in gnumeric, but if the old code calls `xls2csv`, the error is at runtime, not build time).

**Detection signal checklist**(出現以下就要 audit 個 codebase 嘅 external spec assumption):

- [ ] 任何 `RUN apk add ...` / `apt-get install ...` line in Dockerfile that lists 2+ packages
- [ ] 任何 `package.json` entry with a `latest` version specifier (drift over time)
- [ ] 任何 `npm install <pkg>` command in a setup script (not version-pinned)
- [ ] 任何 `subprocess.run(['<binary>', ...])` / `Bun.$\`<binary>\`` call that wasn't verified with `which <binary>` in the target image
- [ ] 任何 setup script that calls `pip install <pkg>` / `gem install <pkg>` without `--no-deps` and version pin
- [ ] 任何 Dockerfile line that copies a binary from the host (`COPY ./my-binary /usr/local/bin/`) without verifying the host binary is built for the target arch

**5-step fix workflow** when build fails on missing external package:

1. Note which package(s) failed in the error log.
2. `docker run --rm <base> sh -c "apk search <keyword>"` for the closest matching package name (or `apt-cache search`, or `npm view`).
3. If a real alternative exists in the official repo, swap it in AND update the corresponding code in `src/` that calls the binary. Update error messages. Update tests. Update the retro / ADR "Why NOT X" section with the swap reason.
4. If no alternative exists, fall back to pure JS / pure language (npm, pypi, crates.io, etc.) — but verify it's CVE-clean first via `npm audit` / `pip-audit` / `cargo audit`.
5. **Always patch the retro / ADR doc** with the spec error audit trail. Future agents reading the merged code need to know which package was swapped and why, even if the swap was 1-line and obvious in the diff.

**Related**:
- `docker-mac-arm64-elysia-vite` Pitfall 12 (added 2026-06-16) — covers the Alpine `apk add` case end-to-end with copy-pasteable verify recipe
- `dependency-cve-audit` — covers the npm CVE side (SheetJS xlsx 0.18.5 stuck with CVE-2023-30533)
- `pm-system-deployment` Sprint 21 section — documents the real `apk add` line that's been verified against Alpine v3.22

**Lesson**:**An external package name in a config file is a spec assumption, not a verified fact**. Always run `apk search` / `apt-cache search` / `npm view` against the actual target image before writing the line. 5 seconds of verification saves a 30-second failed build + a hotfix commit + a confused user. **If you find yourself writing `RUN apk add <pkg-name>` and your source is a plan doc / blog post / memory, stop and verify first** — that's the exact failure mode of the 2026-06-16 Sprint 21 hotfix.

## ⚠️ Pitfall — 「fix 名義 = 移除 X」≠ X 真係消失(2026-06-09 pm-system RG-007 cleanup gap, class-level)

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

## ⚠️ Pitfall — Permanent cache = anti-pattern (RBAC / config / any admin-mutable state)

**場景**(2026-06-09 pm-system Sprint 4 RG-007):`rolePermissionCache: Map<string, string[]>` 寫入後從此不再 query DB,改完 `Role.permissions` 唔會 invalidate。User 撞 403,要 `docker compose restart backend` 先 reload。

**底層 anti-pattern**:**任何永久 cache(冇 TTL / 冇 invalidation hook / 冇 version counter 嘅 cache)都係 bug factory**。原因:
1. Admin 改 state 嗰陣,user 唔會即時見到 → silently inconsistent state
2. 撞 bug 嗰陣要 manual workaround(restart / flush)→ 冇 systematic fix
3. 開發人員「為咗 performance」加 cache,但從此冇為「state consistency」付過時間

**3 個 fix strategy**(揀邊個視乎 scale + traffic):

| Strategy | When to use | Cost | Trade-off |
|---|---|---|---|
| **A. 整個移除 cache** | Traffic 低(< 100 req/s 對 single role) | 0 | 1-2ms / req overhead(內部 system 可接受) |
| **B. 加 invalidation hook** | Admin mutation 唔頻密,可以追蹤事件 | 0.5 日 | 漏 hook 嘅 mutation 仍然 stale |
| **C. TTL + version counter** | High-scale,multi-instance | 1-2 日 | TTL window 內仍然 stale |

**David 嘅 choice(2026-06-09)** = **A 整個移除**。理由:pm-system 內部 traffic 低,1-2ms / req 完全可接受,換取「改完即時生效」嘅 invariant。

**Invariant statement**(任何 cache 寫低都必寫):
> 「Cache 內嘅 entry 必須有 explicit invalidation strategy:**TTL** / **version counter 對比 DB** / **explicit `clear` on mutation event**。**永遠唔可以「load once then forget」**。改 admin-side state 必直接影響 user-side。」

**Detection signal checklist**(出現以下就 audit 個 codebase 有冇 permanent cache):
- 任何 `const xxxCache = new Map<...>()` 喺 module scope
- 任何 `let xxxCache: ... = ...` 喺 module scope
- 任何 `useState` / `useRef` 喺 React 個 layer 上面 cache server state
- 任何 3rd-party SDK 嘅 cache config `ttl: 0` / `cache: true` 而冇 invalidation
- 任何 `globalThis.xxx` 嘅 module-level state

**Audit recipe**:
```bash
# 1. 揾 module-level Map / object
rg "new Map<" --type ts backend/src/
rg "^const \w+Cache" --type ts backend/src/

# 2. 揾 .set() 但冇對應 .delete() / .clear()
# (per-file 比較)
rg "\.set\(" backend/src/utils/cache.ts
rg "\.delete\(|clear\(" backend/src/utils/cache.ts
# set 多過 delete/clear = memory leak + stale 風險
```

**Lesson**:**永久 cache 嘅 false-economy 陷阱**。「為咗 1-2ms 性能,引入『改完要 restart』嘅 silent bug」係 bad trade。**Default**:唔 cache。需要 cache 時,先寫 invariant statement + 揀 strategy A/B/C + 寫 RG entry。

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

## ⚠️ Pitfall — Token trust + fake UUID privilege escalation (2026-06-08 pm-system TD-011, class-level security pattern)

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

## ⚠️ Pitfall — Reproduce 撞 500 嘅 root cause 之前唔好寫 fix(2026-06-08 pm-system TD-011)

**場景**:E2E 撞 `fake UUID token 收 500`,我 Round 1 即刻寫 fix:**`derive hook` 加 `if (!dbUser) return null`**。睇 source code 先 catch 真實 bug — `derive hook` 已經有 try-catch(我以為冇),真實 root cause 係 **`prisma.user.findUnique` 對 fake UUID return null(唔 throw),fall through RBAC check,落到 `prisma.project.create({ createdById: user.id })` 撞 FK constraint**。

**2 round miss-and-catch 嘅 cost**:
- Round 1 fix 寫錯位置
- Round 2 睇 `backend/src/index.ts:80-115` 先 catch
- Time 損失:~10 分鐘(re-read source、識破自己嘅假設)
- 更危險:**如果 Round 1 嘅 fix 過咗 review 而冇再睇 source code,bug 仍然喺度**(可能 silence pass test 但真實攻擊面未封)

**Prevention 紀律**(寫 fix 之前):

```
E2E 撞 failure
    ↓
Step 0: **Reproduce** 喺 dev(local curl / minimal script)
    ↓
Step 1: **睇 server log / stack trace**(唔係睇自己嘅 mental model)
    ↓
Step 2: **Trace 個 stack 入真實 code path** — 用 grep / read_file 搵真實嗰行
    ↓
Step 3: 確認 root cause 喺邊個 line / 邊個 function
    ↓
Step 4: 寫 fix(對應真實 root cause,唔係對應 mental model)
    ↓
Step 5: **睇 source code 一眼** — 順手檢查附近有冇其他 invariants 違反
    ↓
Step 6: Fix + regression test + RG entry
```

**Detection signal**(出現以下就要停一停,re-diagnose):
- 寫 fix 之前冇 reproduce 過 — 純靠 mental model
- 寫 fix 之前冇睇 server log / stack trace
- 寫 fix 之前冇 `grep` / `read_file` 個真實 file
- Fix 嘅位置同你估嘅唔同(尤其 hook / middleware 類 — `try/catch` 可能已經有,只係內部 logic 漏)
- 一個 fix 同時想 cover 太多嘢(代表你可能未完全理解 bug 嘅 scope)

**Lesson**:**Reproduce → log → source code → fix**。跳過任何一步都係賭。Mental model 同 source code 衝突嘅時候,**永遠 source code 啱**。

**Reference**: 完整 reproduce 見 `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md` 第 2 節「Diagnosis(我嘅 2 round miss-and-catch)」

---

## ⚠️ Pitfall — Pure function derive from inline route logic for unit test (2026-06-08 pm-system)

**場景**:一個 project 嘅 route 邏輯入面晒 inline(`worklogs.ts` 內 `computeWorkLogPagination` / `isEditableForCurrentMonth`、`agents.ts` 內 `canClaimTask`),**冇 extract 出嚟做 exportable helper**。要寫 unit test 守住 RG guard 嗰陣,直接 import route file 會 trigger 全部 prisma / elysia / middleware dependency — 根本行唔到。

**症狀**:
- 寫 `import { ... } from './worklogs'` → bun test 撞 `Cannot find package 'elysia'`
- Mock 晒 prisma 嘅路太重,test 變 integration test
- 冇 helper function 可以 unit test,RG entry 永遠 ❌ Regression test
- 「冇 test 守住舊 bug」一直係真實狀態

**正確做法 — 3 步 derive pattern**:

1. **抄源碼 inline logic 入 test file 頂部,做 local helper**:
   ```typescript
   // backend/src/routes/agents.test.ts 頂部
   export function canClaimTask(
     user: AuthUser | null,
     isAgentFlag: boolean | null | undefined,
     task: TaskSnapshot
   ): { ok: true } | { ok: false; code: ...; message: string } {
     // 100% 對齊 routes/agents.ts POST /claim-task 嘅 validation 邏輯
     if (!user) return { ok: false, code: 'UNAUTHORIZED', message: 'Authentication required' }
     if (!isAgentFlag && !hasPermission(user, 'tasks.claim')) {
       return { ok: false, code: 'FORBIDDEN', message: '...' }
     }
     if (task.status !== 'pending') return { ok: false, code: 'BAD_REQUEST', message: `Task is not available. Current status: ${task.status}` }
     if (task.assigneeId) return { ok: false, code: 'BAD_REQUEST', message: 'Task is already assigned' }
     return { ok: true }
   }
   ```

2. **用 comment 標明「derive 自 source file:line」**:
   ```typescript
   /**
    * Derive 自 routes/agents.ts:238-293 (claim-task handler) 嘅 pure validation logic。
    * 100% 對齊 source 嘅 4 個 check + 對應 status code。
    * 將來 route 改動要同步 update 呢個 helper + 跑 test。
    */
   ```

3. **Sprint 1 行動總結**(可重用 checklist):
   - [ ] 揀要守嘅 RG-XXX entry / P0 US(per TEST-COVERAGE.md § 3)
   - [ ] 讀對應 route file inline 邏輯,derive 出 local helper(同 source 100% 對齊)
   - [ ] Helper 入面寫「derive 自 file:line」comment
   - [ ] 寫 5-15 個 test cases(critical path + boundary + admin bypass edge case)
   - [ ] 跑 `bun test src/<path>/<file>.test.ts` 確認全綠
   - [ ] **後續 refactor 必須同步 update 兩處**,或者正式 extract helper 入 route file

**冇 derive 嘅後果**:
- RG entry 永遠 ❌ Regression test
- Tech debt TD-001(測試覆蓋率)永遠高 priority
- 「fix 完又壞」嘅痛點重現(因為 refactor 冇 invariant guard)
- 紅線 12(P0 US 必有 test)+ 紅線 13(冇 RG entry 嘅 fix 唔可以 merge)兩條齊踩

**Lesson**:**derive pure function for unit test 係 RG guard 嘅救命稻草**。Inline logic 無法直接 test → 抄出嚟做 local helper → 守住 invariant → refactor 時用對齊 comment 提醒自己同步。**Sprint 補 test 嘅 default 模式**。

## ⚠️ Pitfall — 8 份 doc file 嘅 doc sync pattern (紅線 10/11/13/14)

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

## ⚠️ Pitfall — 解決 surface symptom 之後必 verify 下一個 blocker(cross-stack iteration loop, 2026-06-09 pm-system)

**場景**:Sprint 5 closure,David 講「馬上處理埋 frontend build 不到的問題」。我發現 frontend `WorkLogsPage.tsx:413` 嘅 `await` in non-async `onClick` 阻 Vite build。Fix 之後,跟住跑 `docker compose up -d --build` 想 verify E2E 跑得通,**但撞第二個 blocker**:`backend` container exit(1),log 報:
```
Prisma schema loaded from prisma/schema.prisma.
Error: The datasource.url property is required in your Prisma config file
when using prisma db push.
```

呢個 issue 唔關 frontend fix 事,**亦唔關 TD-003/004/014 事**。係 Sprint 3 sibling 引入 `prisma.config.ts` 嗰陣漏咗 Dockerfile `COPY` + `prisma.config.ts` 用咗 `process.env["..."]` 唔接受嘅 Prisma 7 strict validation。

**Cross-stack iteration loop**(2026-06-09 親驗要識用):

```
User: 「處理埋 X」
    ↓
Fix X(可能係 frontend build / backend error / docker stack 起唔到)
    ↓
Verify X 修咗(rerun docker build / docker compose up)
    ↓
撞下一個 blocker(可能關 Y,Z,完全唔關 X)
    ↓
Ask user: 「Fix X 之後再撞 Y,要唔要連 Y 一齊清?」
    ↓
Yes → loop(每個 blocker 視為獨立 task 收 todo + commit)
No → 留 Y 喺 TECH-DEBT + commit
```

**關鍵 rule**(David 嘅「馬上處理埋 X」cue):
1. **不要悶頭一個 fix 完就 ship**。每次 fix surface symptom 之後,**必 verify stack 真正 work**(docker compose ps / curl health endpoint / 跑 E2E 一輪),而唔係「我覺得 fix 咗就 fix 咗」。
2. **撞下一個 blocker 唔好 assum 屬今次 scope**。Ask user 確認 scope,尤其 blocker 係 sibling 引入嘅 regression 嗰陣(我撞嘅 Prisma 7 係 Sprint 3 sibling 嘅 fix 引入,非今次 scope)。
3. **每個 blocker 視為獨立 task**。3 個 P1 fix 之後撞 Prisma 7 — 唔可以將 Prisma 7 fix 偷渡入 Sprint 5 commit。**要獨立 commit message + RG entry + REGRESSION-GUARD.md entry**。
4. **「同一個 task 包多個 blocker」係 anti-pattern**。David 嘅「failure-state cue pattern」(A / B / C / 停 / 收工)代表「解決嗰個,然後停,等下個 cue」,唔係「解決嗰個 + 順手 N 個」。

**反例 — 我今次差啲做錯嘅嘢**:
David 講「馬上處理埋 frontend build 不到的問題」,我 fix frontend 之後,直接走去 debug docker stack 嘅 Prisma 7 issue,**冇 confirm scope**。好彩 David 用 clarification tool 回應「改 prisma.config.ts: import + env 2 行, root cause fix」先做,**否則我會 silent scope-creep 將 Prisma 7 fix 塞入 Sprint 5 commit,污染 commit history**。

**Prevention checklist**(收到「處理埋 X」cue 之後):
- [ ] 確認 X 嘅 surface symptom(symptom ≠ root cause)
- [ ] Fix X 嘅 root cause
- [ ] Verify X 修咗(stack 真正 work,not「我覺得」)
- [ ] **撞下一個 blocker 必 ask user 確認 scope**(`clarify` tool,2-4 個 options)
- [ ] 如果 user 確認 scope:**獨立 commit + 獨立 RG entry**,唔好混入原本 task
- [ ] 如果 user 唔確認 scope:**TECH-DEBT.md 記低 + 提交 blocker report**,唔好 silent 處理

**Detection signal**(出現以下就要 stop and clarify):
- User cue 講「A」但你手頭撞住 B、C、D 嘅 fix
- 你嘅 todo list 越加越長但冇 user 確認過
- Commit message 講 1 個 fix 但 git diff 顯示 N 個 file 改動,當中 K 個 file 唔關原本 task
- 你嘅 todo list 入面「fix X + fix Y + fix Z + 順手 audit」> 5 個 items

**Lesson**:**收到「處理埋 X」cue → fix X → verify X → ask user about next blocker, 不要悶頭做**。Cross-stack scope 嘅 iteration loop 必須 explicit clarify,**user 嘅 failure-state cue 係「解決嗰個 + 停 + 等下個 cue」**, 唔係「解決嗰個 + 順手 chain reaction fix N 個」。

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
- `references/pm-system-2026-06-08-sprint-1-test-derive.md` — **Sprint 補 test 完整 reproduce 範本**:pm-system Sprint 1 補 3 份 unit test (RBAC / WorkLog / Agent)、3 個 P0 US 升至 PASS-UNIT、coverage 5% → 25%。包括(1) 揀 RG-XXX / P0 US 嘅優先序,(2) 三份 test 嘅 derive 過程(對應 source file:line + 踩坑親驗),(3) 統一 sprint 補 test workflow(可重用),(4) 對應 doc 更新 checklist。**下次做任何「sprint 補 test + doc update」session 直接跟呢份 reproduce**。
- `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md` — **TD-011 end-to-end reproduce**:E2E discover fake UUID 撞 500 → 2 round diagnosis(我 Round 1 誤判 derive hook findUnique,Round 2 睇 source code 先 catch 真實位置)→ fix derive hook 加 user existence check + role 從 DB 攞(順手封咗 token claim privilege escalation)→ 改 E2E test expectation(500 → 403)→ 寫 RG-006 entry + source code comment marker + commit 引用 RG ID。**教科書級 bug fix-and-test cycle,適合未來任何「E2E surface security bug → diagnose → fix → RG entry」session 跟呢個 reproduce**。
- **Pair with `unit-test-coverage-push` skill** (3-step playbook: parse QA-TRACKER → per-US classify derive/integration/DEFERRED → commit series + tracker sync). That skill IS the upstream "push coverage to 100%" workflow; this skill's "Pure function derive from inline route logic" pitfall IS the per-test technique that powers it. Load `unit-test-coverage-push` for the sprint-level playbook; load this skill for the bug-regression flavor + RG entry format.
