# Day 8 Pattern — Region enum, Deal Kanban, Quotation↔Deal 1-to-many

crm-system Day 8 2026-06-05 加咗三個新嘅 schema 區塊 + Kanban UI pattern,記低俾下一個 CRM / sales tool project 參考。

## 1. Region segmentation (3 primary + "Other" free-form)

**Use case**: B2B 公司主力 HK/MO/CN 三地,但有少量其他地區客戶 (Taiwan / Singapore / Japan / 海外華人公司等)。

```prisma
enum Region {
  HK
  MO
  CN
  OTHER
}

model Company {
  // ... 其他 fields
  region       Region   @default(HK)
  customRegion String?  // 僅 region = OTHER 時填
}
```

**Backend Elysia validator**:
```typescript
body: t.Object({
  region: t.Optional(t.Union([
    t.Literal('HK'),
    t.Literal('MO'),
    t.Literal('CN'),
    t.Literal('OTHER'),
  ])),
  customRegion: t.Optional(t.String()),
}),
```

**Frontend UX**:
- 每個 company card 顯示 region badge `🇭🇰 香港`
- Filter 用 pill row(全部 / 🇭🇰 HK / 🇲🇴 MO / 🇨🇳 CN / 🌏 OTHER)
- 新增公司 dialog 用 4-button grid(emoji + 中文 label),揀 OTHER 時出現自訂 Input
- Region badge 用 `region === 'OTHER' ? customRegion : <label>`

## 2. Deal Kanban (sales pipeline, drag-drop 6 stages)

**Schema 已有**(Day 1 預先建好):
```prisma
model Pipeline { stages PipelineStage[]; deals Deal[] }
model PipelineStage {
  pipelineId String
  name       String   // "Lead" / "Qualified" / "Proposal" / "Negotiation" / "Won" / "Lost"
  position   Int      // 1-6, 配合 @@unique([pipelineId, position])
  probability Int     // 0-100
  color      String?  // hex, "#10B981" etc
}
model Deal { stageId String; stage PipelineStage @relation(...) }
```

**Backend routes**:
- `GET /deals/kanban` — return `{ pipeline, buckets: [{ stage, deals: [] }] }`,一次 query 拉晒,frontend bucket by stage
- `PATCH /deals/:id/stage` body `{ stageId }` — move deal,backend auto-set `status: WON/LOST` 根據 stage.name

**Frontend drag-drop pattern**:
```tsx
// 每 column onDragOver / onDrop 接 dealId
onDrop={(e) => {
  e.preventDefault();
  const dealId = e.dataTransfer.getData('text/deal-id');
  moveStage.mutate({ dealId, stageId: bucket.stage.id });
}}

// 每 card onDragStart set dealId
draggable
onDragStart={(e) => e.dataTransfer.setData('text/deal-id', deal.id)}

// useMutation with optimistic update
const moveStage = useMutation({
  mutationFn: ({ dealId, stageId }) => dealsApi.moveStage(dealId, stageId),
  onMutate: async ({ dealId, stageId }) => {
    await qc.cancelQueries({ queryKey: ['deals-kanban'] });
    const previous = qc.getQueryData<KanbanData>(['deals-kanban']);
    // 手動 bucket-by-stage 重組,unshift 到新 stage
    qc.setQueryData(['deals-kanban'], optimisticBuckets);
    return { previous };
  },
  onError: (_e, _v, ctx) => qc.setQueryData(['deals-kanban'], ctx?.previous),
});
```

**Stats cards above board**: Open count / Total value / Weighted (by probability) / Stages count
**Per-column header**: stage name + deal count + column total value + probability 百分比 footer

## 3. Quotation ↔ Deal 1-to-many (revisions 支援)

**Use case**: 一個 Deal 可能 link 多張 Quotation(v1 報價 / 客戶要求降價 v2 / 改用另一個 service bundle v3)。

**Schema 改動**:
```prisma
model Quotation {
  // ... 其他 fields
  dealId  String?  // nullable: stand-alone quotation 都容許
  deal    Deal?    @relation(fields: [dealId], references: [id], onDelete: SetNull)
  @@index([dealId])
}

model Deal {
  // ... 其他 fields
  quotations Quotation[]   // 反向 relation
}
```

**`onDelete: SetNull`** 而唔係 Cascade,原因:報價單屬於會計記錄,即使 deal 刪咗都應該保留(改 dealId = null 即可)。

**Migration 步驟** (Prisma 唔識自動 backfill 1-to-1 → 1-to-many):
1. `ALTER TABLE quotations ADD COLUMN "dealId" TEXT`
2. (如要 backfill 舊 data) `UPDATE quotations SET "dealId" = (SELECT id FROM deals WHERE ...) WHERE ...`
3. `ALTER TABLE quotations ADD CONSTRAINT fk FOREIGN KEY ("dealId") REFERENCES deals("id") ON DELETE SET NULL`
4. 唔好設 NOT NULL

In Docker dev: `docker exec crm-postgres psql` 行 SQL + 手動 `INSERT INTO _prisma_migrations(...)` 保持 history sync。詳細見 `bun-elysia-react-vite-stack`。

**Frontend UX**:
- Quotation Builder 多咗 "關聯 Deal (可選)" dropdown,enable 條件 = 已揀咗 company
- 揀咗 company 後即時 fetch `?companyId=X` 載入公司嘅 deal
- 顯示格式 `Deal Title · HK$50,000 · Stage Name`
- Deal 嘅 detail page (`/deals/:id`) 顯示 `quotations[]` 列表(現有 backend 已 include)

## 4. Quotation Builder: polymorphic autocomplete (Product + Service)

**每行 item 有 type toggle** (Product / Service), 切換即清空 item:
```tsx
<div className="flex gap-1 p-0.5 bg-muted rounded-md">
  <button onClick={() => onSwitchType('PRODUCT')}
          className={itemType === 'PRODUCT' ? 'bg-background shadow' : 'text-muted-foreground'}>
    <Package /> Product
  </button>
  <button onClick={() => onSwitchType('SERVICE')}>...</button>
</div>
```

**Typeahead autocomplete pattern** (代替 `<select>` dropdown):
```tsx
<div className="relative" ref={wrapRef}>
  <Input
    value={query}
    onChange={(e) => { setQuery(e.target.value); setOpen(true); }}
    onFocus={() => setOpen(true)}
  />
  {open && (
    <div className="absolute z-50 top-full mt-1 max-h-60 overflow-y-auto bg-popover border rounded shadow-lg">
      {filtered.map(p => (
        <button onClick={() => { onApply(p.id); setOpen(false); }}>
          <div>{p.name}</div>
          <div className="text-xs">{p.sku} · {p.category}</div>
          <div className="text-xs">{formatCurrency(p.unitPrice)}</div>
        </button>
      ))}
      <div className="border-t">
        <button onClick={() => setCreateOpen(true)}>
          <Plus /> 新增 Product「{query}」
        </button>
      </div>
    </div>
  )}
</div>
```

關鍵 UX:dropdown 底部永遠有 "+ 新增 X「query」",user 唔使中斷 flow 去 product page 新增 catalogue item。

**Service snapshot SOW 顯示**:
```tsx
{!isProduct && line.manDaySnapshot?.length > 0 && (
  <details>
    <summary>SOW · {line.manDaySnapshot.length} 個 role breakdown</summary>
    {line.manDaySnapshot.map(m => (
      <div>{m.role} · {m.days}d × {formatCurrency(m.dayRate)} = {formatCurrency(m.subtotal)}</div>
    ))}
  </details>
)}
```

## 5. Lessons / pitfalls (Day 8 撞過)

1. **Prisma `Decimal` → JSON → string**:`.reduce((s, d) => s + d.value, 0)` 喺 frontend 會 string concat 變 trillion。每個 Decimal field frontend 累加必須 `Number(d.value)` 強制轉型。
2. **Elysia 1.2 LSP noise**:`elysia/dist/*.d.ts` 嘅 type errors 全部係 pre-existing + bun-types 衝突,**`bun run build` 唔 care**。辨識 signal:build 成功但 `bunx tsc --noEmit` 幾百 error。Trust build output。
3. **`patch` tool `replace_all: true` 唔可以靠 file path uniqueness** — 個 tool 喺 file 內 match 次數統計,可能一個 file 內 hit 多次,搞到 file syntax 損壞。用之前要先 `grep -c "pattern" file.ts` 確認,或者用 unique context 唔好靠 replace_all。
4. **`docker compose up -d <service>` recreate 唔會 re-publish port** — Docker compose 嘅 known issue。要用 `up -d --force-recreate <service>` 確保新 image publish 啱 port,否則 3001/tcp 顯示 healthy 但 host 連唔到。
5. **Dockerfile 唔自動 bind-mount `migrations/`** — host 改 schema + 加 migration folder,**container 內 entrypoint 只睇 image 入面 COPY 嘅 version**。要 `docker compose build --no-cache <service>` 重新 build image,否則 container 會用舊 schema (4 migrations 顯示,實際 5 個)。
