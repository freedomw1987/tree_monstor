---
name: frontend-backend-integration
description: Discipline for writing frontend code that wraps backend endpoints — verify wire shape against backend source (not plan/spec doc), handle prefill races, refactor pages into tabbed layouts without double chrome, wire URL-driven Tabs.
trigger: "writing a new API client wrapper / refactoring a page into a tabbed layout / pre-filling a form from a network call / collapsing sidebar nav / when a Plan doc and the actual backend disagree on field names / 'add a Settings tab' / 'move pages into a layout' / 'X and Y should look the same' / 'X 要同 Y 一致' (modal/form duplication → extract single component) / TypeScript TS7006 'Parameter implicitly has an any type' inside a component with `({...}: any)` props"
category: software-development
---


Last-verified: 2026-07-28
# Frontend-Backend Integration Discipline

When writing frontend code that integrates with a backend API, the most common class of bug is **wire shape drift** — the client wrapper uses field names/types that the backend doesn't actually return/accept. The Plan/spec doc is a wish list, not a contract; the backend code is the contract.

## Core Principle: Read Backend Source First

Before writing any `api.ts` wrapper method, open the corresponding backend route file and verify:

1. **Field names** in the request body and response payload (exact spelling, case)
2. **Field types** (number vs string, array vs object, nullable vs required)
3. **Auth requirements** (which permission, anonymous vs authed)
4. **Status codes** for success/error paths

```bash
# Quick wire-shape scan of a backend route
cat apps/api/src/routes/<feature>.ts | grep -A 20 "GET\|PUT\|POST\|.use(requirePermission"
```

**Why this matters**: A Plan doc written 2 days ago may have been reworded, the backend may have been refactored, or the implementer may have used different vocabulary. The 60 seconds of grep saves a runtime bug that would have been caught at code-review time anyway. Plan docs are spec; backend source is truth. (User's standing rule from 2026-06-04: "後端 API 答案為最終依歸".)

## Wire-Shape Verification Recipe (before committing any API wrapper)

For every new or modified typed client call (`request<T>()`, fetch wrapper, zod schema ↔ DTO):

1. **Locate the actual backend route handler** — `rg -n "'/settings/tax'" apps/api/src/routes/` — and read its real `return { ... }` value. The handler decides the wire shape, not the Prisma model: a `value Json` column can hold anything; the handler wraps it before sending.
2. **For PUT/POST, read the body validator** (`rg -n "body: t\.|t\.Object\(" <route file>`). The validator gives the exact field names the backend accepts — if the client sends `defaultTaxRate` and the validator says `rate`, that's a 400.
3. **Check the Prisma `include`/`select`** — the response has the *selected* shape, not the full model. Common drift: `updatedBy` is a `{ id, name, email }` user object (or `null` for seeded rows), not a string id. Mark nullable fields `T | null`.
4. **Record the verified shape in the Plan doc** — add a "Wire shape (verified against backend <date>)" section listing `GET /x → { ... }` / `PUT /x body → { ... }`, so the next agent inherits the contract instead of re-guessing from prose.
5. **Re-grep before the wrapper commit** — the backend may have changed since the plan stage. A second grep is cheap insurance, not paranoia.
6. **Curl-smoke the first real wire call before committing it** (5 minutes: login, GET, eyeball the field names), and paste the actual response into the commit message as evidence.

**Skip only when**: pure frontend refactor with no contract change; the wire shape was already grepped-and-committed at plan stage by a trusted pass; or the change is cosmetic/internal and never touches the wire.

### Why TypeScript won't save you

- `tsc --noEmit` validates call-site argument shape against the generic; it cannot validate that the endpoint actually *returns* what `request<TaxConfig>` claims. The runtime response is opaque to TS.
- `as Type` casts are lies at the boundary — the runtime is still whatever the backend sent.
- Optimistic `useEffect(() => setQueryData(...))` can mask wire drift for one round-trip before the truth comes back. Always test a full read → write → re-read cycle in dev.
- Backend field renames land with zero client-side TS errors. For endpoints you control, an optional compile-time shape assertion (`type Assert = TaxConfig['rate'] extends number ? true : false; const _c: Assert = true;`) next to the wrapper catches "backend drifted, wrapper didn't".

### Diagnosis when "tsc passes but the endpoint 400s"

1. Run the backend in dev mode and curl the endpoint with a real token.
2. Diff the JSON keys against the TS type — every missing/extra/null field is a drift.
3. For PUT: send the client's payload and read the Zod/validator error message — it names the exact field the backend expected.

### Observed drift cases (crm-system 2026-06)

| Client wrapper assumed | Backend actually used | Symptom |
|---|---|---|
| `defaultTaxRate` (plan doc wording) | `rate` (route handler return) | PUT 400 (Zod) |
| `s.manDays` | Prisma relation `manDayLines` | silent crash, "0 man-day roles" |
| `String @default("ACTIVE")` column | typed enum `status ServiceStatus` | Prisma emits enum cast → 42704 |
| `updatedBy: string` (admin id) | full user object `{id,name,email} \| null` | `.name` on undefined |

## Reference Docs (Specific Patterns)

- `references/url-driven-tabs.md` — shadcn `<Tabs>` with URL as source of truth
- `references/form-prefill-race.md` — the user-touched flag pattern for auto-prefill from network call
- `references/layout-refactor-chrome.md` — wrapping pages in a Layout: strip inner chrome, plan backward-compat Navigate redirects

## Verification Scripts

- `scripts/verify-bundle-modal-uniqueness.sh` — confirm a modal label appears exactly once in the production JS bundle (use after extracting a duplicated modal into a shared component)

## Workflow (Frontend ↔ Backend)

1. **Plan stage**: Agree on URL structure, response shape, auth. Write to Plan doc.
2. **Backend implementation first**: route handler + audit log + tests.
3. **Frontend client wrapper**: BEFORE writing, grep the backend route file for the actual field names. Run `tsc --noEmit` after.
4. **Frontend UI**: Wire the wrapper to UI components.
5. **Smoke test**: Browser, verify the network round-trip end-to-end. Don't trust "the build passes" alone.

## Pitfalls

- **Plan doc ≠ wire shape** — Plan may say `defaultTaxRate`, backend says `rate`. Always grep the backend route file before committing the client wrapper. (crm-system Day 14.7 Step 7 caught this at code-review time before any PUT was sent; runtime would have 400'd on a Zod validation error.)
- **LSP stale after sibling subagent edits** — When two subagents edit the same file, LSP can show ghost "duplicate identifier" errors. The real `tsc --noEmit` is the source of truth; rerun it.
- **Wrapping a page in a Layout doubles the chrome** — If the page has its own `<h1>` or tab strip and the Layout also has one, you'll render twice. Strip the inner chrome at the wrap step, not defer to "later".
- **NavLink inside Radix Tabs controlled mode** — Radix warns about missing triggers. Use TabsTrigger + onClick → navigate() instead. Trade-off: middle-click "open in new tab" doesn't work on tab buttons (still works on direct URLs).
- **Auto-prefill clobbers user input** — A `useEffect(() => setState(serverValue), [])` overwrites a value the user typed before the network response returned. Use the `userTouched` flag pattern (see `references/form-prefill-race.md`).
- **Adding pagination to a list page with stats cards + Excel export** — Adding `skip`/`take` to `findMany` silently breaks total counts and Excel exports (they start reading paged data). The class-level pattern is: server `aggregate` over the full filtered set + `findMany` for the page + `limit=-1` sentinel for export + frontend reads `serverTotalCount` (not `pagedRows.length`). See `pagination-with-preserved-aggregates` skill — its `## Smoke Test (Required)` section has the verification template.
- **LoginPage form 冇 `name` attribute → Playwright selector timeout** — 純 React controlled `<input value={...} onChange={...}>` 冇 HTML `name`,所以 `page.fill('input[name="email"]')` 會 timeout。即使其他 page 嘅 form 有 `name`(form-heavy 嘅 page 通常有),login 嗰個往往冇(E2E auth flow 嘅 standard 入口)。**Fix**:Playwright 寫 selector 一律 fallback `input[type="email"], input[name="email"]` — comma-OR 兩個 selector,Playwright 自動 try first match。Reference:`e2e/tests/critical-path.spec.ts:156`。Verify script(`npx tsx` ad-hoc)可以單用 `input[type="email"]`,因為 login 嗰度冇其他 `<input type="email">` 撞名。
- **React Router `<Route index>` 唔等於 `/dashboard` URL** — 好多 React Router 7+ 嘅 SPA 會用 `<Route index element={<DashboardPage />} />` 將 dashboard 喺 parent path(`/`)之下,所以 login `navigate('/')` 落 root path,**URL 係 `/` 而唔係 `/dashboard`**。**Pitfall**:`page.waitForURL('**/dashboard')` 會 timeout 即使 login 成功 — dashboard page content 已經 render 咗。**Fix**:`page.waitForURL((url) => url.pathname === '/')` 或者 match 寬鬆 regex `path === '/' || /projects|dashboard|home/.test(path)`。Reference:`e2e/scripts/verify-sprint16-dashboard.ts` 嘅 login helper 演化(初版用 `**/dashboard` 撞牆 → 改 `pathname === '/'` 即過)。
- **`sync_playwright` 一次性 context manager,唔可以兩次 `start()`** — Python `from playwright.sync_api import sync_playwright; with sync_playwright() as p: ...` 個 `p` handle 已經 manage 緊 Playwright lifecycle。如果你喺 `with` 入面寫 `sync_playwright().start().chromium.launch()` 撞 context manager 重入,拋 `Error: It looks like you are using Session.playwright API inside the asyncio loop` 或者更 subtle 嘅 hang。**Fix**:reuse 同一個 `p` handle,例如 `browser2 = p.chromium.launch()` 而唔係 `browser2 = sync_playwright().start().chromium.launch()`。Alternative 完全跳開 Python(用 `npx tsx` node script)亦可 — Playwright 對 Node.js 嘅 sync/async 設計冇呢個 trap。
- **Hermes redactor 對 `python3 -c` 嘅 secret 會 redact** — Hermes secret-detection 會 trace shell command 嘅 stdout,`python3 -c "print('password=admin123')"` 之類嘅 inline 腳本如果輸出 `password=***` 樣式嘅 string 會被 redact 變 `***`,下游 regex / sed / 變數 assign 拎到空 string。**Fix**:**Visual verify script 一律寫到獨立 file**(`.ts` 配 `npx tsx` 或 `.py` 配 `python3 <file>.py`),唔好用 `python3 -c "..."` inline。因為 file execution 嘅 output 仲係會被 redact,但 file 嘅 **input** 唔 trace,變數 / 寫 file 嘅 secret flow 唔受影響。最理想係用 `python3 subprocess.run(...)` 寫落 `/tmp/<file>` 然後讀返 file(同 `interruption-recovery` 嘅 `python3 -c` 寫 file pattern 一致)— 詳見 `interruption-recovery/SKILL.md` 同 `dev-task-memory` 嘅 `sync_external.py` pattern。
- **Playwright login 後 wait dashboard widget text 出現,而唔係淨係 waitForLoadState** — 4 個 widget 同時 load 4 個 parallel API request,Dashboard mount 咗但 API 仲未 return 嘅 window 期間,`page.content()` 唔會見到 widget text。`networkidle` 等唔到 background keep-alive(WebSocket、analytics beacon)。**Fix**:login + navigate('/') 之後顯式 `await page.locator('text=<expected widget 文字>').waitFor({ timeout: 15_000 })` 再 `page.content()`。Sprint 16 用過嘅 anchor text:`text=進行中任務` + `h2:has-text("我參與嘅項目")` 雙 anchor 確保 widget + grid heading 都 ready。
- **`function Comp({...}: any)` 個 `any` 會 transitive 污染內部所有 callback 嘅 type inference** — 一個 local helper function(典型樣式:`function AddBugModal({ ..., assigneeOptions }: any) { ... assigneeOptions.map((m) => ...) }`)即使 `assigneeOptions` 本身 typed 做 `MemberOption[]`,`tsc` strict mode 仲會報 `Parameter 'm' implicitly has an 'any' type` 因為個 `any` 個 props type 沿住 call chain 污染落去。**Symptoms**:`tsc` 報 `TS7006: Parameter 'X' implicitly has an 'any' type.` 喺明明 typed 好嘅 `options` 上。**Fix**:直接喺 source array 顯式標 type,例如 `const assigneeOptions: MemberOption[] = project?.members?.map((m) => ({ id: m.user.id, name: m.user.name })) || []`。**Prevention**:避免 `({...}: any)` props 簽名 — 用 `interface` / `type` typed props。短期 refactor 唔想改 signature,source array 顯式標 type 就 bypass 個 transitive `any`。Reference:`pm-system frontend/src/pages/ProjectDetailPage.tsx:658-661`(喺 `function AddBugModal({ ..., assigneeOptions }: any)` 內部用,fix 係顯式標 `assigneeOptions: MemberOption[]`)。
- **兩個 entry point 有「睇起嚟一樣但其實唔同」嘅 modal → 抽 single component,唔好改 visual** — 用戶講「X 同 Y 要一致」嘅時候,response temptation 係「我 copy Y 嘅 styling 落 X」,但**正確係抽 single source of truth**:`<AddTaskModal>` 變 component,兩個 caller 各自 pass props 過去。**Reasoning**:
  1. Copy-paste modal 嘅 field drift(`description` 一個用 RichTextEditor 一個用 textarea;toggle 一個有 smart-assign panel 一個冇;submit button style 一個用 `btn-primary` 一個自訂藍色)— 任何新增 field 都要改兩度
  2. Production bundle 入面會見到同一個 UI text 出現 N 次(eg. `智能分配` 出現 2 次 = 兩份 inline modal)
  3. 「複製另一個嘅 styling」永遠慢過 sync,因為 caller 嘅 form state / options / submit handler 唔同

  **Verify single source of truth**:改完之後 `docker exec <frontend-container> sh -c 'grep -c "<unique-modal-text>" /usr/share/nginx/html/assets/*.js'` 應該係 `1` 而唔係 N(每個 caller 一次)。Reference:`pm-system` 2026-06-10 — Kanban inline modal 換做共用 `<AddTaskModal>`,production bundle `智能分配` 出現次數由 (改之前應有 2) 變 `1`。
- **重複 30 行 useEffect(smart-assign / recommendation / debounced search)喺 2+ component = 抽 custom hook** — 唔好就地 copy 30 行 useEffect,即使兩個 component 各自嘅 state / props 唔同。**Trigger 訊號**:第二個 caller 嘅 `useEffect` 一字不漏同第一個一樣(典型:same `setTimeout(500)`, same `getAgentsOverview()` API call, same skill keyword map, same `bestScore` loop)。**Refactor 嘅 hook shape**:`useRecommendedAgent({ title, desc, autoAssign, onAutoAssign })` return `{ recommendedAgent }`,內部 own 個 debounce 邏輯。**為何要快抽**:呢類 logic 容易演化(改 skill map、加 cooldown、改 matching algorithm)— 兩份永遠 drift。**Verification**:抽 hook 之後每個 caller 由 30 行 useEffect 變 1 行 `useRecommendedAgent(...)`,grep `skillKeywords` 喺 source 入面只出現 1 次(原本會 2 次)。Reference:`pm-system` 2026-06-10 — Kanban 嗰邊 useEffect 應該由 `ProjectDetailPage` 抽做 `useRecommendedAgent` hook,而唔係 copy-paste。

## When the Plan/Design Doc is Out of Sync

Three recovery options, in increasing cost:

1. **Patch the client wrapper to match backend** (cheapest — backend already shipped, user data is at stake).
2. **Patch the backend to match the Plan** (only if no real users yet, AND the wire shape hasn't been documented in API.md).
3. **Update the Plan doc to reflect the backend reality** (always do this last — the Plan doc is the "lie" that's causing the drift; fixing the doc prevents the next agent from making the same mistake).

For shipped features with users, default to (1) + (3). For new features in development, (1) is fine if the backend just landed, (2) is fine if it caught early.

## Related Skills

- `dev-task-memory` — state persistence for multi-step refactors
- `patch-corruption-recovery` — when patches corrupt files during a refactor
