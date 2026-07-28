# ⚠️ Pitfall — Plan doc wording vs backend wire shape (silent 400 on first PUT)

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
