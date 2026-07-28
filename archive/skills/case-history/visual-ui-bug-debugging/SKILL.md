---
name: visual-ui-bug-debugging
description: Debug visual UI bugs where user reports something doesn't work but API/terminal checks pass. Use browser + vision analysis instead of just terminal tools.
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# Visual UI Bug Debugging — When User Reports Something You Can't Reproduce

## When to Use
User reports a visual/UI bug (e.g., "image not showing", "button doesn't work", "layout broken") but:
- API checks via curl/terminal all return 200 / correct data
- You can't immediately see the problem from DOM snapshots

## Core Approach: Browser + Vision, Not Just Terminal

### Step 1: Open the actual deployed URL in browser
```
browser_navigate("https://the-actual-production-url")
```
Terminal curl doesn't render JavaScript or show visual states.

### Step 2: Use browser_vision to see what the browser sees
```
browser_vision({
  question: "Is there a broken image icon where the image should appear? Describe exactly what you see in the message bubble area."
})
```
Vision catches: broken image placeholders, invisible elements, layout overflow issues that DOM can't detect.

### Step 3: Check browser console for silent JS errors
```
browser_console({ clear: true })
// then after interactions:
browser_console()
```

### Step 4: Use full snapshot for anonymous elements
```
browser_snapshot({ full: true })
```
Anonymous `<img>` tags (React renders) often don't appear in compact snapshots.

### Step 5: If vision + console show nothing wrong
The bug may be:
- Transient (fixed by browser cache after a reload)
- Specific to user's browser/extension state
- Already resolved
→ Report back with evidence (vision screenshot + console status)

## Key Insight
browser_vision + screenshot is the ONLY tool that actually shows what the user sees visually. DOM inspection and curl both have blind spots for CSS-based rendering issues, broken image states, and race conditions.

## Common Pattern: List Page Renders Empty Even Though API Works

**Symptom:** User reports "the list doesn't show any items". API returns correct data via curl, but page is blank.

**Root cause pattern:** The page component only has a CREATE form but is **missing the loading logic entirely** — no `useEffect`, no `api.list()` call, no render of list items.

**Debugging steps:**
1. API check: `curl https://api.example.com/projects` — confirm it returns data.
2. Code inspection: Read the page component — look for `useEffect` and `api.list` or `api.get`.
3. The bug signature: A page that renders a create form but has NO `useEffect` + data-loading function.
4. Fix: Add the missing `useEffect` + loading + rendering logic.

**This pattern is extremely common** in React apps where a developer creates a page scaffold with a working create form, but forgets (or the code is reverted/lost) the list-loading side.

## Common Pattern: React 19 Unmounts Entire Tree When One Component Throws

**Symptom:** A specific route page is completely blank (`document.getElementById('root')?.children?.length === 0`). Other pages work fine. The page component has no visible error in the JS console (or the error is swallowed). The browser snapshot may show sidebar/nav working but `<main>` is empty.

**Root cause pattern:** React 19 (no `componentDidCatch` ErrorBoundary anywhere) **unmounts the entire tree on the first render throw** in any descendant. A single bad `r.permissions.length` (where `r.permissions` is `undefined`) propagates as `Cannot read properties of undefined (reading 'length')` and silently empties `#root`.

**Most common offending expressions** in a CRM/listing page:
- `array.length` / `array.map(...)` where the backend didn't return the array you assumed
- `r.field.something` where the field shape is different per endpoint (e.g. `rolesApi.list()` returns `_count: { users, permissions }`, but `rolesApi.get(id)` returns `permissions: string[]`)
- `permissionLabel[someKey]` where the map is actually a `string[]` not `Record<string, string>`
- `new Date(undefined)` → `Invalid Date` (rarely a render throw, but pollutes UI)

**Debugging steps (run in browser_console):**
1. `document.getElementById('root')?.children?.length` — if `0`, the tree unmounted
2. `document.getElementById('root')?.innerHTML?.length` — same info
3. `performance.getEntriesByType('resource').filter(r => r.name.includes('/api/'))` — confirm what fetches happened
4. `performance.getEntriesByType('resource').filter(r => r.name.includes('/api/')).map(r => r.responseStatus)` — confirm all 200
5. **Curl each `/api/*` endpoint directly and print the JSON shape** — the offending assumption is almost always in there

**Fix — once you've found the shape mismatch:**
1. Make the frontend interface accept the actual shape. If the backend returns `_count`, your TypeScript interface should have `_count?: {...}`, not a flat `userCount?: number`.
2. If the backend shape genuinely varies per endpoint (list vs detail), document both shapes in a union interface:
   ```ts
   // list endpoint: { name, displayName, description, isSystem, _count: { users, permissions } }
   // detail endpoint: { ...same..., permissions: string[] }
   export interface Role {
     id: string;
     name: string;
     displayName?: string | null;
     description: string | null;
     isSystem: boolean;
     permissions?: string[];        // detail only
     _count?: { users?: number; permissions?: number };  // list only
     createdAt: string;
     updatedAt?: string;
   }
   ```
3. **ALWAYS before coding a frontend interface, curl the endpoint and inspect the JSON.** The shape you get may not be the shape you designed in the planning phase. Sibling subagents, route file edits, or "I'll just use the count" optimizations can shift the shape between sessions.

**Anti-pattern to avoid:** Skipping the curl+JSON inspection because "I wrote this route 30 minutes ago, I know what it returns". The route file may have been edited by another agent or by a code review fix.

**Prophylactic fix:** Add a top-level `ErrorBoundary` in `main.tsx` so future render throws show a fallback UI instead of an empty `#root`. One screen of dev cost, saves an hour of "where did my page go" each time.

## Common Pattern: Backend Invariant Silent-Fail — Frontend 冇 Enforce (2026-06-06 crm-system 撞牆)

**Symptom:** 個 create dialog 填完表、勾完 permissions、click Submit,**dialog 凍住冇反應**:冇 spinner、冇 error banner、冇 toast、冇 network request 出現、console 完全乾淨、submit button 唔 disable 唔 show loading。D癲果個 mutation hook 彷彿冇 trigger。

**Root cause pattern:** Backend 強制某個 invariant(eg. `name !== name.toUpperCase()` 拒絕 lowercase role name),**但 frontend 冇 mirror 個 invariant**。當 user submit 一個違反 invariant 嘅 payload,server 返 400 帶 error body,**但 frontend 嘅 `onError` callback 唔 fire** / error state 唔 render。最常見 3 個原因:
1. **HTTP client throw 唔出**:`fetch()` 返 400/422 默認 throw,但 axios 配 `validateStatus`、ofetch、自家 wrapper 可能 swallow 4xx。要查 `apps/web/src/lib/api.ts` 嘅 request helper。
2. **React Query mutation onError 唔 fire**:`useMutation` 個 `mutationFn` 包住個 client call,如果 client 唔 throw(只返 `{ ok: false, error }`),onError 唔 trigger。`onSuccess` 雖然會 trigger 但 response 唔 success shape。
3. **Error state 寫咗但 UI 唔 render**:`{error && <p>...</p>}` 配 React render 時序 issue,或者個 error 寫到 `useState` 但 component 喺 mutation 完成後 unmount + remount(dialog 喺 open prop toggle)。

**Debugging sequence**:
1. **Stop trusting the dialog freeze** — open **browser DevTools Network tab** 看有冇 outgoing request
2. **冇 network request = mutation 唔 trigger**(搶 source code trace `useMutation` / form `onSubmit`)
3. **有 network request + 4xx = client 冇 throw / onError 唔 fire**:
   - 直接打 backend `curl` 確認 exact error response shape
   - 對比 frontend `onError` 點 parse 個 response
4. **Bypass UI 用 direct API probe** 確認 backend 接受邊個 shape,frontend 應該 align 邊個 invariant:
   ```bash
   docker exec crm-api sh -c '.../tmp/probe.mjs...'
   # 用 UPPERCASE name → 201
   # 用 lowercase name → 400 (證明 server 嘅 invariant 嚴格)
   ```
5. **Frontend fix 必須有 2 部分**:
   - **Client-side guard 喺 input**:`<Input value={name} onChange={e => setName(e.targetValue.toUpperCase())}>` 或者 trim 完 `name.toUpperCase()` validate,直接 block 唔合法 payload
   - **Server-side error UX 必 render**:`onError: (e) => { setError(parseApiError(e)); toast.error(...) }` — 用 toast library(sonner / react-hot-toast),唔可以淨靠 inline `<p>`(容易被 dialog 高度 ignore)

**Invariant rule 鐵律(2026-06-06)**:
- 任何 backend 嘅 invariant(eg. uppercase name / non-null field / enum check),frontend **必 mirror** 一個對應嘅 client-side validation
- 否則 user 提交一個**表面合理**嘅 value(eg. "Senior Sales")→ server reject → frontend freeze 唔出聲 → 用戶以為 bug → 再試再失敗
- **「enforce everywhere」鐵律: backend = 真相,frontend = 提點**。提點唔到都冇所謂唔代表 server 唔該 reject,只係代表 frontend 對 user 唔友善。

**Examples in crm-system**:
- `apps/api/src/routes/roles.ts` line 72: `if (data.name !== data.name.toUpperCase()) { /* reject */ }`
- `apps/web/src/components/role-dialog.tsx` line 211-219: `<Input value={name} onChange={(e) => setName(e.target.value)} />` — 冇 uppercase transform,冇 client validation
- 撞 bug 嗰陣:`name="Smoke Test Role"` (mixed case + space)→ POST 400 → useMutation onError 唔 fire / 唔 render → dialog freeze 5 秒

**Pre-emptive pattern**:寫 frontend form 嗰陣,**先用 backend code grep 全部 invariant** (eg. `data.X !== data.X.toUpperCase()` / `enum.parse()` / `.required()`),**逐個 mirror 入 form 嘅 validation**。Step 1 喺 spec,Step 2 喺 Zod schema,Step 3 喺 input onChange transform。

## Common Pattern: shadcn-style Tailwind token 漏 → Panel/Dropdown 完全透明 (2026-06-06 crm-system 真實撞牆)

**Symptom:** User reports 一個 popover / dropdown / autocomplete panel 透底(見到後面嘅 table / 另一個 row 嗰 column / textarea)。**冇 console error**, API call 200, 其他 page 正常。DevTools 嘅 element tree 入面個 panel 存在, 但**冇 background-color**。

**Root cause pattern:** shadcn-style component 用 `bg-popover` / `text-popover-foreground` / `bg-card` / `border-input` 等等 cva 變量, 期望佢哋喺 `tailwind.config.js` 嘅 `theme.extend.colors` 有對應 HSL token。如果個 config **冇 declare** 個 token, Tailwind JIT 喺 build 階段 **silently omit** 個 class(唔報錯, build pass), 結果個 element computed style 嘅 `background-color` 係 `rgba(0,0,0,0)` 完全透明。

**常見漏 token list** (shadcn default config 齊嘅, hand-written 容易漏):
- `popover` + `popover-foreground` (dropdown, command palette, combobox, popover, dialog 入面)
- `card-foreground`
- `destructive-foreground`
- `muted-foreground` ← **crm-system 撞過 `bg-muted/20` + `text-muted-foreground` 個 'muted' token 有但 'muted-foreground' 都 work, 但 'popover' 完全冇**

**Debugging steps**:
1. **喺 DevTools inspect 個 panel element**, 睇 computed `background-color`:
   ```js
   const el = document.querySelector('[class*="bg-popover"]');
   window.getComputedStyle(el).backgroundColor
   // 透明 bug: "rgba(0, 0, 0, 0)"
   // 正常: "rgb(255, 255, 255)" or "rgb(0, 0%, 0%)" 之類
   ```
2. **grep 全 codebase 嘅 utility class**, 對比 config 嘅 `colors` key 集合:
   ```bash
   rg -o 'bg-[a-z-]+|text-[a-z-]+' apps/web/src | sort -u
   ```
   然後手動對 `tailwind.config.js` 嘅 `theme.extend.colors` 嘅 key。**有 utility class 但冇 token = silent omission**。
3. **確認 Tailwind 唔報錯**:
   ```bash
   bun run build
   # 個 utility class 唔出現喺 bundle 入面, 但 build 唔 fail
   grep -r "bg-popover" dist/assets/*.css
   # 透明 bug: empty
   # 正常: ".bg-popover { background-color: hsl(...) }"
   ```

**Fix (3 個 option, 由小到大改)**:
1. **Element-local 改 utility class** (最快, David 揀咗呢個): `bg-popover` → `bg-white border border-border` (視覺對齊, 因為 `popover: DEFAULT: hsl(0 0% 100%)` 白色)
2. **Config-level 補齊 shadcn token set**: 加 `popover`, `popover-foreground`, `card-foreground`, `destructive-foreground`, 配 HSL 顏色。**一改搞掂成個 app 嘅所有 dropdown/popover/dialog 透明度**。
3. **改用 `npx shadcn@latest add <component>` 重 generate**: 自動 inject 對應 cn() + class 變量, 唔會撞呢個 trap。**最預防性** 但要 rewrite component code。

**Pre-emptive rule (新 shadcn-style 項目)**: 跟 `npx shadcn@latest init` 出嘅 `tailwind.config.js` **唔好 hand-edit 走任何 token**。Hand-written 容易漏, crm-system 撞咗兩次(Day 9 Region bug + 今日 popover bug)都係同一個 systemic pattern。

**Related skill**: `bun-elysia-react-vite-stack` 嘅「shadcn-style token 唔可以漏」section 有 full Tailwind config snippet (HSL 顏色齊 shadcn 標準 set)。

## Production Video Player Gotcha: `react-player@2.x`

**Symptom:** Lesson/page data has a valid YouTube URL and the page renders, but no video iframe/player appears for students.

**Root cause pattern:** `react-player@2.x` expects the video prop to be `url`, not `src`. If frontend renders:

```tsx
<ReactPlayer src={lesson.videoUrl} controls />
```

React compiles successfully, but ReactPlayer receives no URL and renders no YouTube iframe. Fix:

```tsx
<ReactPlayer url={lesson.videoUrl} controls />
```

**Debugging steps:**
1. Verify backend/DB actually returns `videoUrl` for the lesson.
2. Check installed react-player version and type definitions: `node_modules/react-player/base.d.ts` should show `url?: ...`.
3. Build frontend and inspect bundled JS for `url:<videoUrl variable>` rather than `src:<videoUrl variable>`.
4. Deploy static frontend to S3 and invalidate CloudFront if production is CloudFront/S3 backed.
5. Verify with Playwright/browser that `document.querySelector('iframe')` exists and iframe `src` points to YouTube.
