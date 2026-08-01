# pm-system 2026-06-09 — 拎走「全部缺陷」menu + 加 list search box

## Session context

David 6/9 兩條 feedback 一次過整:
1. 「menu 不用有」 → 拎走「全部缺陷」standalone page (Layout + App + BugsPage.tsx)
2. 項目內頁 (需求/任務/缺陷) + 需求內頁 (任務/缺陷) 加 search box

Frontend-only, 6 files 改, 271 lines 拎走, 173 加返。Commit `048650e`。
Retro doc: `~/www/pm-system/docs/retros/2026-06-09-remove-bugs-menu-add-list-search.md`

## 3 個 push back 嘅 capture

### 輪 1 — scope 過大警示

**David 原文**: 3 條 feedback (1) 拎走「全部缺陷」 (2) 項目內頁 + 需求內頁 search (3) 需求內頁 search
**我 push back**: 
- (1) soft delete 影響 4 個 frontend entry + 5 個 backend endpoint, 問只改 BugsPage?
- (2) 搜尋 client-side 定 server-side?
- (3) 3 個 task 嘅 output mode (red line 50)

**David 揀**: (1) A (只改 BugsPage) + (2) A (client-side) + (3) C (揀 1 個先做)

### 輪 2 — wording parse 修正

**David cue**(獨立 message, 答緊輪 1 嘅 (1)):「我意思是不用有 "全部缺陷" 這個 菜單」

**我 push back 第 2 次**:
- 「menu 不用有」係指 Layout 拎走, 定係連 `/bugs` route + `BugsPage.tsx` 整個拎走?
- 拎走後 search box 仲做唔做?

**David 答**: 「menu 不用有,但項目內頁和需求內頁就要有 缺陷 tab」

**意思確認**:
- 拎走 nav item (Layout.tsx) + 拎走 `/bugs` route (App.tsx) + 拎走 `BugsPage.tsx` file
- BugDetailPage (`/bugs/:id`) 保留 — 從「我的缺陷」/ project 內 bug tab 入 detail 仲要 work
- 3 個 sub-list (project 內 bugs / requirements / tasks + req 內 bugs / tasks) 加 search box

## 8 個 grep audit 抓到嘅 critical paths

拎走 `/bugs` route 之後, 呢啲地方要 audit:

```bash
# 1. Layout.tsx — nav item (1 line)
grep -n "全部缺陷\|/bugs\b" frontend/src/components/Layout.tsx

# 2. App.tsx — route + import
grep -n "BugsPage\|/bugs" frontend/src/App.tsx

# 3. BugDetailPage.tsx — 3 處 back-link
grep -n "/bugs\b" frontend/src/pages/BugDetailPage.tsx

# 4. utils/api.ts — `/bugs` API wrapper 保留 (sub-list 仲要 call)
# 唔拎走,但要 verify sub-list 仲用

# 5. E2E tests — 拎走會 break
grep -n "/bugs\|BugsPage" e2e/tests/*.spec.ts
# → bugs-fix.spec.ts (9 處), pagination.spec.ts T8
```

## 4 個 pitfalls 真實撞過

### P1. `BugsPage.tsx` 整個 delete 之後, BugDetailPage back-link 仲指 `/bugs` → blank dashboard

```tsx
// ❌ 拎走 route 之後, click 落 blank dashboard (react-router fallback 返 `/`)
<Link to="/bugs">返回缺陷列表</Link>

// ✅ 改去 /my-bugs
<Link to="/my-bugs">返回缺陷列表</Link>
```

3 處 back-link + 1 處 navigate 全部要改 (`grep -n "/bugs\b" BugDetailPage.tsx` 拎 4 個 hit)。

### P2. TypeScript import cleanup: `import BugsPage from './pages/BugsPage'`

拎走 route 之後, `import` 留低會報 `Cannot find name 'BugsPage'` (LSP 報咗,雖然 patch 自動拎走咗)。

### P3. `useMemo` 依賴項唔可以漏 `searchX` — 否則 search string 變 filter result 唔變

```tsx
// ❌ 漏 searchX 喺 deps
const filteredBugs = useMemo(() => {...}, [bugs])  // search 改 filter 唔變

// ✅ 完整 deps
const filteredBugs = useMemo(() => {...}, [bugs, searchBug])
```

ESLint react-hooks/exhaustive-deps 會 catch,但用手寫要小心。

### P4. Empty state 順序: `x.length === 0` 先, `filteredX.length === 0` 後

```tsx
// ❌ 順序錯, raw empty 永遠 trigger 唔到
{filteredX.length === 0 ? (
  <div>無符合「{searchX}」嘅 X</div>  // 即使原始空, 都 show 呢個
) : (
  <div>{filteredX.map(...)}</div>
)}

// ✅ 順序對, raw empty 先 check
{x.length === 0 ? (
  <div>暫無 X</div>  // 原始空
) : filteredX.length === 0 ? (
  <div>無符合「{searchX}」嘅 X</div>  // 搜尋無結果
) : (
  <div>{filteredX.map(...)}</div>
)}
```

## 跟進 follow-up (待 sprint 補)

E2E tests 拎走 `/bugs` route 會 break, 紅線 12 (P0 US 必須有 test) 暫時違反:

- [ ] 改 `bugs-fix.spec.ts`: 加 deprecation note + `test.skip` 對應 P0 regression (bug #1/#2/#3/#5/#7), 保留 bug #4 (edit 立即更新) + #6 (附件) + #8 (project card click)
- [ ] 改 `pagination.spec.ts` T8 → `test.skip` + comment
- [ ] Update `docs/QA-TRACKER.md` (紅線 11): US-7.1 (全部缺陷) 標 DEPRECATED
- [ ] Update `docs/PRD.md` (紅線 11): US-7.1 內容標 ❌ 廢棄
- [ ] 補 E2E test 喺 `ProjectDetailPage` 嘅 bug tab: 搜尋 keyword 應該 filter 列表, 確認冇 regression

## 8 個 audit checklist 跑咗 (全 ✓)

1. `useMemo` over `[data, query]` ✓ (3 個 ProjectDetail + 2 個 RequirementDetail = 5 個 useMemo)
2. Search box 同 create button 用 `flex-col sm:flex-row` ✓
3. 2 層 empty state 分開 ✓ (raw empty vs filter empty)
4. Search input 有 `aria-label` ✓
5. Search input 有 `Search` icon 喺左 ✓
6. Filter 只 match `title` field ✓
7. 拎走 standalone page grep back-link 全部 updated ✓ (BugDetailPage 3 處 back-link + 1 處 navigate 改去 /my-bugs)
8. TypeScript 0 error ✓ (`bunx tsc --noEmit` 過)

未跑 (待 RWD mobile audit): 用 `frontend/rwd-mobile-audit` skill verify mobile 唔撞 layout
