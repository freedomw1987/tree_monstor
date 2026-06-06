# 2026-06-06 crm-system — 5-issue bundle (Day 11)

David 5 個 user-visible issue 一次過 ship(全部都係 user-facing UX/functional fix):

1. `bg-popover` token systemic fix (config-level)
2. Quotation Builder 新增 Product 用 page 嘅 full form
3. Quotation Builder 新增 Service 用 page 嘅 full form
4. Service 頁 502 (POST /services body validator 撞命名)
5. Deals 編輯功能

## Issue 1: `bg-popover` token systemic fix

Day 10 揀咗 Path B(component-local `bg-white` swap), 提咗 David "會撞第 2、第 3 次同樣 bug" 嘅 systemic 風險。Day 11 揀咗 Path A — 改 `tailwind.config.js` 嘅 `theme.extend.colors` 加 `popover` token:

```js
// apps/web/tailwind.config.js
colors: {
  // ... 已經有: border, input, ring, background, foreground, primary, secondary, muted, accent, destructive, card
  // Day 11 加:
  popover: {
    DEFAULT: 'hsl(0 0% 100%)',
    foreground: 'hsl(222.2 84% 4.9%)',
  },
  // 對齊完整 shadcn-ui HSL 變量(雖然 Day 11 只用 popover, 但一致性要齊)
}
```

**Pre-emptive rule for 新 shadcn-style 項目**: 跟 `npx shadcn@latest init` 出嘅 `tailwind.config.js` 唔好 hand-edit 走任何 token。**或者**直接用 `npx shadcn@latest add <component>` 加新 component, 佢會自動 inject 對應 `cn()` + class 變量, 唔會撞呢個 trap。**Hermes hand-written `tailwind.config.js` 易漏 token** — crm-system 撞咗兩次(Day 9 Region bug + Day 10/11 popover bug)。

**Day 11 嘅 Path A vs Day 10 嘅 Path B 對比**:
- Path A (改 config): 1 個 file 改, 之後 token 對齊 shadcn 標準, **但** 之前已經 hard-coded 嘅 `bg-white` 唔使改(視覺一致)
- Path B (改 component): 1 個 component 改, 唔改 config, 將來其他 component 撞 `bg-popover` 仲會 silently transparent

**Detection 工具** (必做, 唔好信 build pass):
```bash
# 1. grep utility class
rg "bg-(popover|card-foreground|popover-foreground|destructive-foreground|muted-foreground|accent-foreground|secondary-foreground)" apps/web/src

# 2. 對比 tailwind config 嘅 colors key
node -e "console.log(Object.keys(require('./apps/web/tailwind.config.js').theme.extend.colors).join('\n'))"

# 3. 差集 = missing token
```

**完整 shadcn token set 嘅 cross-check table** (用 `npx shadcn@latest init` 出嘅 `css-variables` mode):

| Token | Default HSL | 用途 |
|---|---|---|
| `background` | `hsl(0 0% 100%)` | body bg |
| `foreground` | `hsl(222.2 84% 4.9%)` | body text |
| `card` | `hsl(0 0% 100%)` | Card bg |
| `card-foreground` | `hsl(222.2 84% 4.9%)` | Card text |
| `popover` | `hsl(0 0% 100%)` | Popover / dropdown bg |
| `popover-foreground` | `hsl(222.2 84% 4.9%)` | Popover / dropdown text |
| `primary` | `hsl(222.2 47.4% 11.2%)` | Button / link |
| `primary-foreground` | `hsl(210 40% 98%)` | Button text |
| `secondary` | `hsl(210 40% 96.1%)` | Secondary button |
| `secondary-foreground` | `hsl(222.2 47.4% 11.2%)` | |
| `muted` | `hsl(210 40% 96.1%)` | Skeleton / disabled |
| `muted-foreground` | `hsl(215.4 16.3% 46.9%)` | Hint text |
| `accent` | `hsl(210 40% 96.1%)` | Hover state |
| `accent-foreground` | `hsl(222.2 47.4% 11.2%)` | |
| `destructive` | `hsl(0 84.2% 60.2%)` | Delete / error |
| `destructive-foreground` | `hsl(210 40% 98%)` | |
| `border` | `hsl(214.3 31.8% 91.4%)` | Default border |
| `input` | `hsl(214.3 31.8% 91.4%)` | Input border |
| `ring` | `hsl(222.2 84% 4.9%)` | Focus ring |

`crm-system` 之前漏咗 `popover` + `card-foreground` + `popover-foreground` + `destructive-foreground` + `accent-foreground` + `secondary-foreground` 6 個 token。Day 11 補 `popover` 就夠 quick fix,但長遠全部補齊。

## Issue 2-3: Quotation Builder 新增 Product/Service 用 page 嘅 full form (見 `polymorphic-line-items` skill)

完整 step-by-step 喺 `polymorphic-line-items` skill 嘅 "Quick-create modal in picker — must be FULL form" section 同 "Day 11 教訓 — Quick-create 都應該做 full form parity"。

## Issue 4: Service 頁 502 — 完整 root cause + fix

(完整 case study 喺 `polymorphic-line-items` skill 嘅 "🚨 Critical 衍生 pitfall: Elysia strict `t.Object` body validator 會 throw 502" section。)

**症狀 verbatim**: David 喺 `/services` page 撳「新增服務」, 入晒名 + man-day row, 撳「建立」, 個 dialog 報 `502`。

**Backend log trace**:
```bash
docker logs crm-api --tail 30
# 看 [POST /services] 撞 "Validation failed"
# "found": "body", "body": {"name":"X","unitPrice":0,"currency":"HKD","manDays":[...]}
# 期待 field: name, description?, category?, unitPrice, currency?, status?, sortOrder?, manDayLines?
# 收到: name, unitPrice, currency, manDays  ← 多了 manDays, 缺了 manDayLines
# Elysia 拒收 → throw 500 / 502
```

**Elysia strict validator 行為**:
- 收到 `manDays` 個 key 唔喺 schema → reject (not silently ignore)
- Schema 用 `t.Array(t.Object({role, dayRate, days}))` 對 `manDayLines`, 唔對 `manDays`
- Reject 後 throw 個 validation error → 500 internal error → nginx / CDN 見到 upstream 500 → client 收 **502**
- 重要: 唔係 422 (Elysia 422 個 path 係 client 收得到 validation error JSON), 係 502 因為 Elysia 個 strict validator throw 喺 route handler 之前, 觸發 catch-all error handler, 個 response 唔算 "expected 422"

**Generic rule for Elysia + strict validator + JSON payload mismatch**:
- Backend schema `t.Object` field name = source of truth
- Frontend type signature 唔可以擅自用 alias (例如 business name vs Prisma relation name)
- 即刻 fix: dialog 入面 send `{...payload, manDayLines: manDays, }` + response normalize `{...created, manDays: created.manDayLines}`
- 永久 fix: `servicesApi.create` 嘅 type signature 改用 `manDayLines` 對齊 backend, 之後 normalize 步驟可以刪除

**為何 typecheck 唔 catch**:
- `servicesApi.create` 個 typed signature 寫 `manDays`, 所以 `manDays: manDays` 完全 type-safe
- 要 typecheck catch,需要改 signature 寫 `manDayLines` (即 `lib/api.ts` 改 source of truth)
- 折衷方案: dialog 入面用 `as never` 兩個 cast, 但 cast 會 silent 過 typecheck, 之後再撞 502

**Picked solution (Day 11)**: 改 `lib/api.ts` `servicesApi.create` signature 用 `manDayLines` 對齊 backend, frontend `Service` type 維持 `manDays` 因為 manDays 係 business / display field, response normalize 喺 dialog 出口做。咁 wire-format 同 type signature 兩個 truth 都 align, 之後其他 caller 用 `servicesApi.create` 都自然用 `manDayLines`。

## Issue 5: Deals 編輯功能 (前端 PATCH form + 後端 reuse)

**Backend 已經有 `PATCH /deals/:id`** (`apps/api/src/routes/deal.ts` line 137-149), `prisma.deal.update({ where, data })` no-op schema validator。**冇改 backend**。

**Frontend 改動**:
1. `pages/deals.tsx` 嘅 `CreateDealDialog` → rename `DealDialog` + 加 `deal?: Deal` prop
2. `DealDialog` isEdit = !!deal, internal state 從 `deal?` pre-fill (title / companyId / value / stageId / expectedCloseDate)
3. `DealCard` 加 hover Edit2 icon + 整個 card 嘅 onClick 入 edit mode (有 `dragging` state 避免 drag-and-drop 撞 click)
4. `DealsPage` 加 `editing: Deal | null` state, render 兩個 `<DealDialog>` instance (create mode + edit mode)

**Stage 改動嘅兩-call pattern (重要)**:
```typescript
async function handleSubmit(e) {
  if (isEdit && deal) {
    const stageChanged = stageId !== deal.stage?.id;
    // 1. PATCH /deals/:id 改其他 editable fields (skip stageId 避免 bypass auto-status)
    await dealsApi.update(deal.id, {
      title: title.trim(),
      value: Number(value) || 0,
      expectedCloseDate: expectedCloseDate || undefined,
    });
    // 2. 如果 stage 改咗, 獨立 PATCH /deals/:id/stage 觸發 backend 嘅 WON/LOST/closedAt 邏輯
    if (stageChanged) {
      await dealsApi.moveStage(deal.id, stageId);
    }
  } else {
    await dealsApi.create({ ... });
  }
}
```

**點解唔一個 call 改哂**:
- `PATCH /deals/:id` 個 backend handler **冇** status/closedAt 邏輯,純 `prisma.deal.update({data: body})`
- `PATCH /deals/:id/stage` (`apps/api/src/routes/deal.ts` line 69-106) 先有 WON/LOST 自動推導 + `closedAt: finalStatus !== 'OPEN' ? new Date() : null` 嘅 side effect
- 兩個 endpoint 行為唔同, **唔可以** 用 stageId 喺 PATCH /deals/:id 一齊送 (會 bypass status logic)
- 解決: 兩個 call 串行。如果 stage 冇改, 淨係做 PATCH /deals/:id;如果 stage 改咗, PATCH 完先再 PATCH /deals/:id/stage

**Drag + click 衝突 guard (新發現 pattern)**:
```typescript
function DealCard({ deal, onEdit, disabled }) {
  const [dragging, setDragging] = useState(false);
  return (
    <div
      draggable={!disabled}
      onDragStart={() => setDragging(true)}
      onDragEnd={() => setDragging(false)}
      onClick={() => { if (!dragging) onEdit(deal); }}   // ← 關鍵 guard
    >
      {/* ... */}
      <button onClick={(e) => { e.stopPropagation(); onEdit(deal); }}>  // icon button
        <Edit2 />
      </button>
    </div>
  );
}
```

**點解需要**:
- Kanban 嘅 drag-and-drop 用 native HTML5 DnD (`draggable={true}`)
- Native browser 行為: `mousedown → mousemove (幾 px) → dragstart` **唔觸發** click event。但**如果用戶 drag 一個 card 放返原位 (`mousedown → mousemove → mouseup` 冇真正 move 出 threshold)**, 個 click event **會 fire** 喺 mouseup。
- 如果 click handler 唔 guard, 個用戶 drag 完個 card 放返原位 → click handler 開 edit dialog → user 經驗 "點解我拖唔郁但個 dialog 開咗"
- Guard 做法: 監聽 `dragstart` / `dragend` 設 flag, click handler check flag。**注意 native click event 唔會喺 drag 期間 fire, 但 drag-and-cancel 會 fire**。

**Generic rule for kanban + edit dialog 嘅 hybrid UI**:
- Kanban card 必然 draggable, 但**同時**要 click 入 detail
- 用 `dragging` flag 區分 "drag-in-progress" vs "click"
- 接受 `dragend` 會 clear flag 但 click event 仲未 fire → 兩者 race condition。**Fix**: 喺 `onMouseUp` 加 50ms `setTimeout` 延遲個 click handler, setDragging(false) 同步 reset, 確認 click 唔會撞。

**Alternative (推薦, 簡單)**: 用戶 drag 完放返原位, 開 edit dialog 係 acceptable UX(有 dragend 之後個 click 開 detail 唔算 bug)。如果想 100% 避 conflict, 用 `pointerdown` + `mousemove` 距離 threshold (>5px = drag, ≤5px = click) 而唔靠 native DnD。

**Deal edit 入面 company disable 嘅 trade-off**:
- Day 11 揀咗 disable Company select 喺 edit mode(`prisma.deal.update` 唔 reject 改 company, 但 admin instinct 覺得 "deal 改 parent company" 唔正常)
- 將來要 enable: 刪 `disabled={!isEdit}` + handler 入面 include companyId

## Subagent long refactor 600s timeout 嘅接管 (核心 lesson)

**Setup**: 派 1 個 subagent 跑 5 phase (Issue 1+2+3+4+5), ~70 行 plan, toolsets = ['terminal', 'file', 'skills'].

**Result**: `api_calls: 63, duration_seconds: 600.17, exit_reason: timeout`。Subagent 撞 timeout 之後 status = "timeout", summary = null, error = "Subagent timed out after 600.0s with 63 API call(s) completed — likely stuck on a slow API call or unresponsive network request."

**Recovery**:
1. 唔好再 delegate — subagent 已經 63 calls 撞牆, 再派會再撞
2. 自己 check subagent 嘅 partial progress: `search_files(pattern="quick-create-*", target="files")` → 兩個 file 已經 create 完整
3. Read 嗰啲 file 確認 quality
4. Check 4 個 plan file 入面邊個改咗邊個未改
5. 接手未做嘅 phase (Day 11 全部 5 phase 都做咗, subagent 跑咗 ~50 calls 做 file changes, 之後 ~13 calls 喺 typecheck loop 撞牆)
6. 最終 typecheck 自己跑: `cd apps/web && bun run typecheck` → exit 0 ✅

**Plan size vs API call budget 嘅 reference (Day 11 數據)**:
- 1 phase (1 file major edit, no verify) → ~10 calls, 5 min OK
- 2 phases (2 file edits + 1 typecheck) → ~25 calls, 10-12 min OK
- 3 phases (3 file edits + 2 typecheck) → ~35-40 calls, 15-20 min borderline
- 5 phases (5+ file edits + 3-4 typecheck passes) → **>50 calls, 撞 timeout 高**。Day 11 證實
- 8+ phases → 必須 split。**Never one goal 包咁多**

**Generic rule for future delegation**:
- 1 個 subagent 1 個 clear deliverable
- 唔好一個 goal 包 multi-phase refactor
- Typecheck loop 嘅上限: 2 個 pass (即係撞 error 兩次 fix)。第 3 次仲有 error → parent 接手
- Subagent log 入面如果出現同一個 `error TSxxxx` > 3 次, 即係 chasing 連環 cast → 立即 rescue

**Subagent 應該喺 plan 度收到嘅 explicit constraint**:
```
"做 4 件事: 改 file A, 改 file B, 改 file C, 改 file D. 唔需要 typecheck pass — parent 接手跑 typecheck. 完成標準: file D 改完 + 寫返 checkpoint 'Phase 4 done' 就 OK."
```

**Checkpoint pattern** (Day 11 subagent 寫咗, 但寫得太遲):
```python
# 改完 1 個 file 寫低:
write_file(path="/tmp/crm-day11-checkpoint.md", content="Phase 1 done: tailwind.config.js modified. Phase 2 done: quick-create-service-dialog.tsx created. Phase 3 pending: shared component rename")
# parent rescue 嗰陣 read 個 file → 即時知住乜
```

## Verification status (Day 11)

- `bun run typecheck` → **exit 0** ✅
- Backend 唔使改 (POST /services validator 已經接受 `manDayLines` / `category` / `status`; PATCH /deals/:id + /deals/:id/stage 都齊)
- 8 files modified (見 main skill update 嘅 summary table)
- 未做: browser E2E smoke (避免 Hermes redact JWT 問題)
- 提咗 David refresh 試, 有 bug 即管 shoot
