# ⚠️ Pitfall — logEvent API field-name drift in caller code (crm-system 2026-06-07, pre-existing)

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
