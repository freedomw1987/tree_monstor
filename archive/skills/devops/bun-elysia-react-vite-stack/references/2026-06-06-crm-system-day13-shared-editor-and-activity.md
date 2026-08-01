# 2026-06-06 crm-system Day 13 — Shared form editor + Activity polymorphic pattern

5-task bundle shipped: Company Activity/Attachment tabs, Deal Kanban Activity panel + per-card +Activity, Service man-day role bug fix + shared ManDayEditor extraction. Backend + frontend both 0 TS errors, Docker build pass, container healthy.

**3 個 class-level 教訓**新發現(其他 pitfall 已有入 SKILL.md):

## 1. Shared form-editor extraction: 防止 create + edit form drift 嘅 silent data loss

**情境**: Service 有 create dialog(`QuickCreateServiceDialog`, 喺 `/services` page + quotation builder autocomplete 用) 同 edit page(`pages/service-detail.tsx`)。兩個 form 個 man-day editor **係兩個獨立 implementation**。

**Bug**: Service edit form 嘅 useEffect mapping response 落 state 嗰陣:
```typescript
setManDays((service.manDays ?? []).map((m) => ({ role: m.role, dayRate: m.dayRate, days: m.days })));
//                  ^^^^^^^^^^ silently drops manDayRoleId, costRate, id, sortOrder
```
Backend snapshot 落 DB 嘅 `manDayRoleId` 永久斷開。**User 開 service 改 day-rate → save → backend 收到 free-form line → 報價建立時 `manDaySnapshot` 冇 catalogue reference → 將來 admin 改 `ManDayRole.price` 唔再影響舊 service**。**完全 silent**(冇 error, 冇 console warning, 只係「改價之後舊 service 唔郁」嘅 subtle business loss)。

**Detection (撞咗通常好遲先知)**:
```bash
# 1. Component 訪問 field 嘅 pattern grep
rg "\.manDayLines\.|\.manDays\." apps/web/src
# 期望全部用 manDays, 有 manDayLines = boundary normalize 漏咗

# 2. Check Prisma response shape 同 frontend type field name 對唔對得齊
grep "manDayRoleId\|manDayLines\|manDays" apps/web/src/lib/api.ts
# 對比 schema.prisma 嘅 ServiceManDay relation
```

**Fix pattern (抽 shared component + 統一 wire-format converter)**:
- 抽 `components/man-day-editor.tsx` 做唯一 source of truth,內含 `toWireRows(rows)` helper 處理 wire shape
- 兩個 parent(`QuickCreateServiceDialog` + `service-detail.tsx`)都 import 同一個 component + 用 `toWireRows`
- **Wire-format converter 必須同 component 喺同一個 file**,唔好兩處 drift
- `useEffect` 嘅 mapping 要 preserve 全部 Prisma field(包括 `id` / `manDayRoleId` / `costRate` / `sortOrder`),唔好 narrow

**Generic rule (create+edit 兩個 form 嘅任何 field editor 都套用)**:
- 抽 shared component, 不要 duplicate UI
- 抽 shared `toWireXxx(state)` helper, 不要各自 inline build payload
- useEffect mapping response 落 state 必須 spread 全部 field, 不要 narrow

**Pitfall (Day 13 真實撞過)**: Wire-format converter 漏 `dayRateDirty` flag:
```typescript
// ❌ Naive: 直接 send 全部 field
{ role: m.role, dayRate: m.dayRate, days: m.days, manDayRoleId: m.manDayRoleId }

// ✅ Correct: catalogue row + dirty → 變 free-form (override 保留)
{ manDayRoleId: m.manDayRoleId, days: m.days }                    // 唔 dirty: backend snapshot
{ role: m.role, dayRate: m.dayRate, days: m.days }                 // dirty/free-form: override
```
**冇 dirty flag → user 改 day-rate 之後再 save 會 trigger backend snapshot → override 永久 lost**。Backend `apps/api/src/routes/service.ts` 嘅 `snapshotManDayLine` 入面有 `if (line.manDayRoleId) { snapshot } else { free-form }` 嘅 conditional — frontend 必須 match, 否則後端 snapshot 蓋過 user override。

**Detection 工具**:
```bash
# 對比 create + edit 兩個 file 嘅 payload construction
rg "manDayLines:|manDayLines: " apps/web/src/components/quick-create-service-dialog.tsx
rg "manDayLines:|manDayLines: " apps/web/src/pages/service-detail.tsx
# 期望: 兩個 file 都係同一個 shape, 且都通過 toWireRows() helper
```

## 2. Polymorphic activity pattern — extend 唔破壞既有 endpoint

**情境**: 原本 `/activities` endpoint 強制要 `companyId XOR dealId` 其中一個(reject both-empty 400)。新需求: Deal Kanban page 要顯示 "all recent activity" — 冇 company / deal filter,user 想睇"呢個禮拜 sales 跟進過咩"。

**Trap**: 唔好改 `/activities` 變 optional filter(會破壞既有 caller)。**改 `/activities/recent` 加 optional params** — 原本就冇 required filter, 加 `authorId` + `since` 最自然。

**Backend 改法**:
```typescript
.get('/activities/recent', async ({ query, set, request }) => {
  const { limit, authorId, since } = query as { limit?: string; authorId?: string; since?: string };
  const where: Record<string, unknown> = {};
  if (authorId) where.authorId = authorId;
  if (since) where.createdAt = { gte: new Date(since) };
  const items = await prisma.activity.findMany({
    where, take: Math.min(Number(limit ?? '10'), 50),
    orderBy: { createdAt: 'desc' },
    include: { author: { select: { id, name, email } }, company: { select: { id, name } }, deal: { select: { id, title } }, attachments: { ... } },
  });
  return { items, total: items.length };
})
```

**Frontend 改法 — 改 signature 由 positional 變 object**:
```typescript
// ❌ Old (positional, 容易撞牆 — 加 filter 要插中間)
recent: (limit = 10) => request(`.../recent?limit=${limit}`),

// ✅ New (object — 加 filter 唔破壞既有 caller signature)
recent: (params: { limit?: number; authorId?: string; since?: string } = {}) => {
  const qs = new URLSearchParams();
  if (params.limit !== undefined) qs.set('limit', String(Math.min(params.limit, 50)));
  if (params.authorId) qs.set('authorId', params.authorId);
  if (params.since) qs.set('since', params.since);
  return request(`/activities/recent${qs.toString() ? `?${qs}` : ''}`);
}
```

**Caller migration (要 grep 全部舊 call site)**:
```bash
rg "activitiesApi\.recent\(" apps/web/src
# 期望: 所有 caller 都用 object form `activitiesApi.recent({ limit })`
```

**Day 13 撞咗 1 個 stale call site**(`RecentActivitiesWidget`):
```typescript
// 改前
queryFn: () => activitiesApi.recent(limit),
// 改後
queryFn: () => activitiesApi.recent({ limit }),
```

**Generic rule (signature breaking change 嘅 frontend migration)**:
- Object params > positional params (尤其 optional filters 一定 object)
- 改 signature 之後 grep 全部 call site,逐個 patch
- TypeScript 唔一定 catch 全部 — 因為 `recent(limit)` 同 `recent({ limit })` 都 pass type-check(就算 params 個 type 有 `authorId` / `since` 都唔阻擋 `recent(10)` 嘅 number 變成 limit field 嘅 weird coercion)

**Response shape 陷阱**: `usersApi.list` 返 `{ items, total }` 但 `usersApi.get` 返 bare object。`DealsActivityPanel` 寫 `useQuery({ queryFn: () => usersApi.list(...) })` 然後 `data.map(...)` → TS 報 `Property 'map' does not exist on type 'NoInfer<{ items, total }> | never[]'`, 因為 TS 推唔到 generic union。**Fix**: 兩次 cast `data as { items?: UserSummary[] } | undefined`, 然後 `data?.items ?? []`。

## 3. Inline modal pattern (deal activity dialog) — 抽 component 而唔係 inline 喺 page

**情境**: 喺 Deal Kanban card 加「＋ Activity」button → 開 inline dialog 預填 dealId → submit POST /activities。

**Trap 1**: 唔好 inline 個 dialog 喺 `deals.tsx`(700+ 行已經好亂)。抽 `components/deal-activity-dialog.tsx` 接受 `{ open, onOpenChange, dealId, dealTitle? }`,內部管 composer state + submit。

**Trap 2**: Composer 嘅 textarea auto-grow 用 `useEffect` 改 `style.height`,記得 effect dep 要有 content 個 state。`document.getElementById('deal-activity-composer') as HTMLTextAreaElement | null` 配 null check(其他 dialog 用同一個 id 會撞)。

**Trap 3**: Submit 流程:
```typescript
// ❌ Concurrent upload (race condition)
const act = await activitiesApi.create({...});
files.forEach(f => attachmentsApi.upload(act.id, f));  // 唔 await!

// ✅ Sequential (audit log 排序正確, nginx buffer 咗 multipart)
const act = await activitiesApi.create({...});
for (const f of files) {
  await attachmentsApi.upload(act.id, f);
}
```
**Race 條件嘅後果**: Backend 嘅 attachment 寫入次序 random, audit log list 嘅 attachment upload 事件次序 random, 之後 user 睇 history 唔可信。

**Wire-format check (POST /activities 必須有 dealId XOR companyId)**:
- Composer preset `dealId`, 唔送 `companyId`(form 唔收 company)
- Backend validate `if (!companyId && !dealId) return 400`
- 測試必須做 1 個 `dealId` 走, 1 個 `companyId` 走, 1 個 both empty → 400

**Generic rule (inline composer / dialog)**:
- 抽 component, 不要 inline 喺 page
- Submit flow 必須 sequential upload
- preset field(dealId / companyId)用 prop, 不要從 URL query 拎

## 4. Auth-protected file download — fetch+blob 唔好直接 `<a href>`

**情境**: Company detail page 嘅「附件」tab 要俾 user download 任何 attachment。Backend `GET /attachments/:id/download` 要 JWT Bearer token,plain `<a href>` 會 401。

**Trap**: `<a href="/api/attachments/X/download" download>下載</a>` → 冇 Authorization header → backend 401 → 視乎 backend 行為, 個 file body 可能 attach 喺 error response(類似 `api-download-401-pdf-body` 個 case)。

**Fix pattern**:
```typescript
async function downloadOne(att: Attachment) {
  const token = getToken();   // lib/api.ts 個 helper
  const res = await fetch(`/api/attachments/${att.id}/download`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
  if (!res.ok) throw new Error(`Download failed (${res.status})`);
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  // Trust backend Content-Disposition filename, fallback metadata
  const dispo = res.headers.get('content-disposition') ?? '';
  const m = dispo.match(/filename="?([^";]+)"?/i);
  a.download = m?.[1] ?? att.fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);   // Safari 需要 delay
}
```

**Critical points**:
- 用 `getToken()` helper(直接讀 `localStorage` 嗰個), 唔好從 props
- `URL.createObjectURL` 必須 `setTimeout` revoke(Safari 仲未開始 download 就 revoke 會壞 file)
- `Content-Disposition` 嘅 filename match 要 fallback 個 metadata `att.fileName`(header 可能被 proxy strip 咗)

**Generic rule (所有 JWT-protected binary download)**:
- fetch + Authorization header + blob + objectURL + 延遲 revoke
- Backend 用 Content-Disposition set filename(防 path injection + 統一 source of truth)
- 永遠唔好用 plain `<a href>` 對 auth-protected endpoint

## 5. Doc 同步永遠係 bottleneck (紅線 10+11 撞牆)

**情境**: David 派咗 5 個 task (T1-T5)。T1-T4 全部 code ship + build pass。T5 寫 doc — 寫到一半 stop, 通知 David 揀 A/B/C/D 之後 4 個 option 嘅 timeout。**最終結果**: 全部 7 個 modified file + 4 個 new file uncommitted 喺 working tree, doc 全部冇做。

**Trap**: 寫 700+ 行 code 唔 commit, doc 變 optional "等 user 揀先做"。

**紅線 10**: 任何 project ship 之前,`docs/PROJECT-OVERVIEW.md` / `PRD.md` / `DESIGN.md` / 至少一個 ADR / `API.md` / `TEST-COVERAGE.md` / `TECH-DEBT.md` 必須存在並 commit。冇文件嘅 code 唔可以 merge。

**紅線 11**: 改 PRD 嘅同時必須更新 `docs/QA-TRACKER.md`。改了 PRD 沒更新 tracker = 任務沒做。

**Day 13 lesson**: **5 個 task 嘅 batch delivery,doc 同步要做埋**。**唔好 ship code 之後問 user 揀 doc option** — 用戶要嘅係 "完工",唔係 "code 完工 doc 待定"。

**Generic pattern (multi-task batch)**:
- 派 task 嗰刻就要 enumerate 對應 doc 改動
- 每個 sub-task done 之後即時更新對應 doc section(PR / US / API endpoint)
- Final commit 之前 grep 全部 doc, 確認 7 份 spec 全部 update

## 6. Hermes bug 確認唔識 session 上下文 (記憶持久性)

**情境**: David 6/06 親自 confirm 個 `RoleDialog` 有 2 個 bug(literal lowercase "Smoke Test Role" 嘅 submit 凍住、permission checkbox 視覺 toggle 但 counter 寫 "0 個已選")。我 smoke 完之後 promise 過 fix 但 session 內 冇 fix, 之後再開新 session David 問 `docker compose up -d --build 出問題`, 我用 `claude --no-session` 開始新 task,**冇任何 memory / skill / doc 記住個 2 個 bug**。

**Trap (memory 唔 cross-session 可靠)**: Hermes memory system 注入 context 喺每個 turn 開頭, 但有 char budget (現時 6329/2200 chars, 已超 100%)。Memory 寫低嘅 bug 容易 lost 喺將來 session。

**Day 13 fix**: **每個 smoke catch 嘅 bug 即時寫入 `docs/TECH-DEBT.md`** + `docs/REGRESSION-GUARD.md` + commit 入 git。Memory 唔可靠, git + file 可靠。Memory 只用嚟記 user preference / environment fact / project 結構, 唔用嚟記 in-flight bug。

**Generic rule (bug triage)**:
- 撞 bug → 即時睇 `docs/REGRESSION-GUARD.md` 有冇 entry
- 冇 → 寫 entry(root cause + prevention + 對應 test)
- Commit 入 git
- Memory 都加 1 行 pointer "see docs/REGRESSION-GUARD.md for open bugs"
- 唔可以 "下次先 fix" / "留到將來 session"

## 7. Hermes LSP stale diagnostics 嘅 false positive 救濟 (複用 Day 12 lesson)

**情境**: 加 import 嗰陣 LSP 報 `Cannot find name 'StickyNote'` / `Cannot find name 'DealActivityDialog'`, 但 `tsc --noEmit` 0 errors。LSP 報錯 line number 對唔上 file 內容(報 line 388 但 file 已經 280 行)。

**Fix (Day 12 + Day 13 都套用)**:
```bash
# 改完 frontend file 永遠跑呢個 — 唔好睇 LSP
cd ~/www/crm-system/apps/web && npx tsc --noEmit --skipLibCheck 2>&1 | head -20
# Expected: 0 行 output (= 0 errors)
# 任何 output 嗰啲先係真 issue
```

**唔好信 LSP 報錯** — LSP daemon 對 rapid patch 嘅 cache invalidation 唔可靠, 報嘅 error 多數 stale。

## 8. Plan-then-batch > piecemeal 確認 (2026-06-06 crm-system 5-task batch lesson)

**情境**: David 開頭派 5 個 task 唔揀 execution mode。我用 `clarify` 工具俾 4 個 option(A 全做 / B 分 2 個 batch / C bug-first / D partial), David 揀 A 一次過。**之後 700+ 行 code + 4 個 new file 全部一次 ship**。

**Generic pattern (5+ task batch)**:
- 第一個 message 用 `clarify` 列 execution mode options
- 對齊後直接 ship 唔再中途問
- 中途只係做 sub-plan(eg. T4 先做再 T1-T3)而唔係 stop 問
- 5 個 task 撞牆位預先睇清(prisma wire-format / activity polymorphic / shared editor extraction)一次過寫

**Anti-pattern**: 5 個 task 派完之後每個 sub-task 都問 David "下一步點做" — 用戶瘋, agent 都累。

## 9. Sub-step plan: 5 task → 10 個 sub-step 嘅 reorder

| Sub-step | 屬於 task | 改咩 file |
|---|---|---|
| 1 | T4 | 抽 `ManDayEditor` component |
| 2 | T4 | `ServiceManDay` type 加 `manDayRoleId` field |
| 3 | T4 | `QuickCreateServiceDialog` 用 `ManDayEditor` |
| 4 | T4 | `service-detail.tsx` 用 `ManDayEditor` + 修 useEffect + 修 updateMutation |
| 5 | T1 | 抽 `AttachmentList` component (fetch+blob download) |
| 6 | T1 | `company-detail.tsx` tab nav 重組 + `OverviewTab` sub-component |
| 7 | T3 | 抽 `DealActivityDialog` component |
| 8 | T3 | `DealCard` + `KanbanColumn` + `DealsPage` wire 個 button + state |
| 9 | T2 + backend | `/activities/recent` 加 `authorId` + `since` filter |
| 10 | T2 | `activitiesApi.recent` 改 signature + `DealsActivityPanel` component + mount |

**每個 sub-step 都跟住 `tsc --noEmit` verify 0 errors 先做下一個** — 避免最後 build fail 唔知邊個 sub-step 撞牆。
