# PM-System Sprint 11 — Wiki/Attachments search + deprecate `/bugs` E2E tests

Session 2026-06-09 commit `8c99f32` (follow-up to `048650e`).

## TL;DR

David 揀 (B) skip 失效 E2E + (C) 延伸 Wiki/Attachments search, 一次過整:
- **B closure (紅線 11/12 復合規)**:`describe.skip`/`test.skip` 6 個 P0 regression + 文件標 DEPRECATED
- **C extension**:`WikiTab` + `AttachmentsTab` 加 search box, 但 layout 唔同 default (two variants)

## 7 個 file 改咩

| File | Change | Lines |
|------|--------|-------|
| `frontend/src/components/WikiTab.tsx` | Variant A (left sidebar list) search | +36 / -7 |
| `frontend/src/components/AttachmentsTab.tsx` | Variant B (upload bar adjacent) search | +70 / -19 |
| `e2e/tests/bugs-fix.spec.ts` | `describe.skip` x 2 (5 tests) + file header changelog | +31 / -12 |
| `e2e/tests/pagination.spec.ts` | T8 `test.skip` | +8 / -3 |
| `docs/QA-TRACKER.md` | US-5.5 → DEPRECATED ⚫, US-5.6 → PARTIAL 🟡, +changelog row | +5 / -3 |
| `docs/PRD.md` | Epic 5 US-5.5 strikethrough + US-5.6 row | +2 / 0 |
| `docs/retros/...` | Sprint 11 retro doc | new |

## WikiTab Variant A — 兩欄 layout

```tsx
// 兩欄 layout: 左 list sidebar (w-72) + 右 content pane
<div className="flex gap-6 h-full">
  <div className="w-72 flex flex-col">
    {/* Title + 新增 button 自己一行 */}
    <div className="flex items-center justify-between mb-3">
      <h3>頁面列表</h3>
      <button>+ 新增</button>
    </div>
    {/* Search 自己一行 (唔同行 justify-between, 視覺 hierarchy 清楚) */}
    <div className="relative mb-3">
      <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
      <input className="w-full pl-8 pr-3 py-1.5 ..." placeholder="搜尋頁面..." aria-label="搜尋 Wiki 頁面" />
    </div>
    {/* List body */}
  </div>
  {/* Right content pane — 唔受 search 影響 */}
</div>
```

**Why own row, 唔同 title 並排**: list header 已經 `justify-between` (title + create button), 加 search 變 3 個 item 撞。Search 自己一行視覺清楚。

## AttachmentsTab Variant B — Upload bar 旁

```tsx
{/* Upload + search row, RWD 兩行 */}
<div className="mb-6 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
  {canUpload && (
    <div className="flex items-center gap-4">
      <label htmlFor="upload" className="btn-primary">上傳附件</label>
      <span className="text-sm text-gray-500">支援圖片、文檔...</span>
    </div>
  )}
  <div className="relative w-full sm:w-72 sm:ml-auto">
    <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
    <input className="w-full pl-8 pr-3 py-1.5 ..." placeholder="搜尋附件..." aria-label="搜尋附件" />
  </div>
</div>
```

**Key differences from default page**:
- `sm:ml-auto` 推 search right-aligned, 即使 `canUpload` 係 false 都 keep right
- `py-1.5` (唔係 `py-2`): 附件 grid 密度高啲, search 縮細一格 match
- `Search size={14}` 唔係 `{16}`: 同 attachment card 嘅 icon size 對齊

## E2E test deprecation pattern

**6 個 test skip 嘅結構** (4 describe, 1 describe.skip, 1 test.skip):

| Describe | Status | Why |
|----------|--------|-----|
| `Bugs page (/bugs)` | ❌ describe.skip (3 tests) | `/bugs` route 拎走 |
| `Bug detail page (/bugs/:id)` | ✅ 保留 (1 test) | `/bugs/:id` 仲 work, edit + save 仲 cover |
| `Create bug modal` | ❌ describe.skip (2 tests) | entry 經已 `/bugs`, 拎走咗 |
| `Attachments tab image preview` | ✅ 保留 (1 test) | 用 `/projects/${projectId}`, 唔受影響 |
| `Project card click navigation` | ✅ 保留 (2 tests) | 用 `/projects`, 唔受影響 |

**為何 `describe.skip` > `test.skip` x 6**:
- Playwright report 清楚顯示「skipped 6 tests」 grouped, 唔會 fail
- 同事 review 一睇就知「呢個 describe 內 6 個 test 經已 skip 因為 feature 廢咗」
- 比 6 個 `test.skip` inline 同 6 個 `test()` 並排易讀
- **唔好 `test.fixme`** (表示 broken 要修) 或 **唔好 delete test** (冇 audit trail)

**File header 嘅 changelog block** 範本:

```ts
/**
 * Bugs fix E2E tests — RG-2026-06-09
 *
 * 涵蓋 7 個回歸 bug(對應 P0 sprint 2026-06-09 嘅 fix):
 *   - bug #1 / #2  全部缺陷列表頁可新增缺陷(去 /bugs 見到「新建缺陷」button) [DEPRECATED 2026-06-09]
 *   - bug #3       全部缺陷列表頁可跳去詳情(click row → /bugs/:id)              [DEPRECATED 2026-06-09]
 *   ...
 *
 * 2026-06-09 變更:David 拎走「全部缺陷」standalone page(`/bugs` route 刪除)。
 * 對應 P0 regression test 全部 skip,標 DEPRECATED。Detail page(`/bugs/:id`)
 * 仲存在(test #4 仍然 work),附件(#6)同 project card(#8)都保留。下次 sprint
 * 補:ProjectDetailPage 嘅 bug tab create flow + search filter regression。
 */
```

## QA-TRACKER 嘅 DEPRECATE row pattern

| US | Title | Backend Test | Frontend Test | E2E Test | Test Status | Owner |
|----|-------|--------------|---------------|----------|-------------|-------|
| US-5.5 | 全部缺陷列表 + 詳情 | ❌(新 GET /:id) | ❌ | ❌(DEPRECATED 2026-06-09 — 拎走 standalone `/bugs` page) | **DEPRECATED** ⚫ | TBD |
| US-5.6 | Bug 描述 rich text + image paste | ❌ | ❌ | ❌(DEPRECATED 2026-06-09 — 拎走 `/bugs` 個獨立 create entry,ProjectDetailPage 嗰度 create flow 等下次 sprint 補 E2E) | **PARTIAL** 🟡 | TBD |

**Key points**:
- **❌(DEPRECATED 2026-06-09 — reason)** 喺 E2E cell 寫埋原因
- **Status 變 ⚫ DEPRECATED** (唔係 🟢 PASS-E2E, 唔係 🟡 PARTIAL — 完全 retire)
- **PARTIAL 🟡** for US-5.6 因為 `BugDetailPage` 仲用 `RichTextEditor`, 功能 work 但 E2E 冇 cover (entry 經已廢)
- **+changelog row** 喺 bottom table 講呢個 sprint:「DEPRECATE US-5.5... + 加 search box 喺 5 個 list page」

## PRD.md 嘅 strikethrough pattern

```markdown
| ID | Story | Priority | Status |
|----|-------|----------|--------|
| US-5.1 | 作為 Tester,我可以建 Bug(...) | P0 | DONE |
| US-5.2 | 作為 Tester,我可以將 Bug 分派畀 developer | P0 | DONE |
| US-5.3 | 作為 Developer,我可以睇「我的 Bug」| P0 | DONE |
| US-5.4 | 作為 Tester,我可以更新 Bug 狀態(...) | P0 | DONE |
| ~~US-5.5~~ | ~~作為 PM,我可以睇「全部缺陷」列表 + 詳情(/bugs standalone page)~~ | ~~P0~~ | ❌ **DEPRECATED 2026-06-09** (David 拎走 `/bugs` standalone page,只保留「我的缺陷」+ 項目/需求內頁 bug tab 入口) |
| US-5.6 | Bug 描述支援 rich text + image paste | P1 | DONE (Backend + BugDetailPage 嘅 RichTextEditor;E2E 暫時 PARTIAL,等 ProjectDetailPage 補 test) |
```

**Strikethrough = historical context**, 唔好 delete row(同事 review 會 miss context)。

## 6 條 follow-up (retro doc 留低)

- [ ] Sprint 11/12 補 E2E test 喺 `ProjectDetailPage` 嘅 bug tab (US-5.6 create + rich text + image paste)
- [ ] Sprint 11 補 E2E test 喺 `ProjectDetailPage` 嘅 bug tab search filter
- [ ] Wiki full-text search (Postgres `tsvector` / MeiliSearch) — scope 較大, hold 住

## Lesson (跨 session 用)

1. **`describe.skip` > `test.skip` x N** for grouped deprecation
2. **File header changelog 比 inline comment 更明顯** — reader 一開 file 就知歷史
3. **Strikethrough row 喺 PRD 唔好 delete** — 保留 historical context
4. **紅線 11 (改 PRD 必更新 tracker) 真係 work** — 文件同步係 ship 必要條件
5. **E2E test grep 跟 feature 死** — 拎走 feature 必 `grep -n` 拎 reference
6. **Component variant 唔同, audit checklist 要 extend** — default pattern 之外有時 layout 撞,加 `Step 4b Variant A/B` 守到
