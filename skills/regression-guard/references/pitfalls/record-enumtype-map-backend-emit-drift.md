# ⚠️ Pitfall — `Record<EnumType, ...>` map + backend emit 唔同步

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
