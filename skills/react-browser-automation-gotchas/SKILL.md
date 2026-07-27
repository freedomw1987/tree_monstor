---
name: react-browser-automation-gotchas
description: Debug React UI state issues when Playwright/browser automation fails to trigger React synthetic events. Use when browser_click() doesn't update React state.
---


Last-verified: 2026-07-28
# React + Browser Automation Gotchas

## Context

When debugging React UIs with Playwright/Puppeteer via `browser_*` tools, certain React patterns cause automation to fail silently even when the actual app works fine. This skill captures lessons learned from testing a WhatsApp-style React chatbot where `browser_click()` repeatedly failed to trigger React state updates.

---

## Core Finding

**React synthetic events don't always fire from Playwright's programmatic clicks.**

Symptom: `browser_click('@e3')` returns success (no error), subsequent `browser_snapshot` shows element was "clicked" (highlighted state), but React state (`selectedId`, `messages[]`) **did not update**.

Why: React 18 uses synthetic event delegation. Playwright's click dispatches a DOM event, but React's `onClick` handler on a `<div>` may not fire if:
- The element is a non-semantic element (`<div>` instead of `<button>`)  
- React hasn't attached its event listener at that exact moment (timing issue)
- The click hits a wrapper element rather than the child with the handler

---

## Lesson Learned: Don't Trust Automation for React State Verification

### The Trap
1. You click a conversation item in a sidebar via automation
2. React state *should* update → chat area should change
3. Browser snapshot shows the same old chat content
4. You assume there's a code bug
5. But the code is fine — automation just didn't trigger React's state

### The Fix
1. **Before concluding a bug exists**, verify via **alternative means**:
   - Check `browser_console` for `console.log` output (needs explicit capture)
   - Use `browser_console` with expressions like `document.getElementById('some-element').textContent`
   - Check React DevTools state via browser console expression
   - Compare **network requests** — if clicking a conversation SHOULD trigger an API call, check if the network request was made

2. **Use console expressions to read state directly**:
   ```javascript
   // Check actual rendered HTML
   document.body.innerHTML.substring(0, 500)
   
   // Find actual class names in use
   [...document.querySelectorAll('*')].map(el => el.className).filter(c => c && c.includes('conv'))
   ```

3. **The `.conv-item` class trap**: 
   - Automation searched for `document.querySelectorAll('.conv-item')` → returned empty
   - But the sidebar WAS rendering conversations visually
   - Root cause: CSS class in code was `.conversation-item`, not `.conv-item`
   - Always check actual rendered class names, not assumed names

---

## Practical Debugging Sequence for React UI Issues

```
Step 1: Verify page loads correctly
  → browser_navigate → browser_vision (screenshot)
  
Step 2: Check actual DOM state before clicking
  → browser_console: document.querySelectorAll('*').map(el => el.className).filter(c => c.includes('conv'))
  
Step 3: Click and IMMEDIATELY check network/state
  → browser_click → wait → browser_console to read state
  → Do NOT trust browser_snapshot alone to tell you if state changed
  
Step 4: If state didn't change:
  a. Verify element HAS the onClick handler (check source)
  b. Check if click target is the RIGHT element (maybe parent/wrapper)
  c. Try clicking a DIFFERENT element that definitely has a handler
  d. Fall back to: verify code logic via code review, then MANUAL testing
  
Step 5: Manual testing fallback
  → Ask user to test manually and report what they see
  → This is VALID when automation consistently fails
```

---

## When to Abandon Automation

- After 3+ attempts with different approaches, if automation still shows inconsistent results but code looks correct → assume code is fine, escalate to manual testing
- Browser tool's accessibility tree (`browser_snapshot`) can show broken/misleading structure even when page renders correctly visually
- Console.log output may be swallowed by the automation framework
- Vision screenshot analysis may fail to read cached screenshots

---

## Pattern: Dialog Freezes — Counter Label vs Checkbox 視覺 Desync (2026-06-06 crm-system real)

**Symptom:** Click 4 個 `<input type="checkbox">` (browser_click 全部 success),但個 dialog 入面嘅 counter label 仲係 "0 個已選"。Snapshot 個 checkbox `checked=true`,vision 見到剔,console 完全冇 error。Submit 個 button click 之後 mutation hook 都唔 trigger(no spinner, no error banner, no toast, no network)。

**Why this is DIFFERENT from the synthetic-event trap above:**
- Click 確實 fire 咗(checkbox `checked` 狀態有改)
- 但 React `useState` 個 value 冇變 — 即 controlled input 嘅 `value`/`checked` 喺 re-render 後被 revert
- 一般係 3 個 cause 之一:
  1. **`useEffect` prefill 同 `useState` initial 撞**: `useEffect` reset `setSelected(new Set())` 因為 `open` prop 變化或者 `role` prop 未到位
  2. **`useQuery enabled: open`** 喺 modal 入面 re-fetch 一個會 trigger re-render 嘅 query,重設 form state
  3. **`onChange` 寫 inline 個 closure 用咗 stale `selected`** (`toggle()` 用 `setSelected(next)` 啱嘅,但如果某處用咗 `selected.has(p)` 而非 functional update, race condition 會 reset 個 state)

**Don't trust 視覺 checked — verify state via DOM probe:**
```javascript
// In browser_console, 讀 controlled input 嘅 actual state
const checks = [...document.querySelectorAll('input[type="checkbox"]')];
checks.map(c => ({ name: c.parentElement.textContent, checked: c.checked, hasOnChange: !!c.onchange }));
// 全部 checked=true 但 React state selected.size === 0 = 100% desync 證據
```

**Smoke 流程必跑「isolation by direct API」:**
當 frontend 同 backend 唔知邊度錯嘅時候,**直接 bypass UI 打 API** 確認 backend 接受邊個 shape:

```bash
# 1. 拎 token (login)
docker exec crm-api sh -c 'cat > /tmp/probe.mjs << "EOF"
const login = await fetch("http://localhost:3001/auth/login", {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email: "admin@crm.local", password: "admin123" })
});
const { token } = await login.json();
const create = await fetch("http://localhost:3001/roles", {
  method: "POST",
  headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
  body: JSON.stringify({ name: "UPPERCASE_NAME", ... })
});
console.log("status:", create.status, "body:", await create.text());
EOF
node /tmp/probe.mjs'
```

如果 API 返 201 + clean record,**frontend 100% 係 bug**(state 同步 / validation / mutation trigger);如果 API 返 400,**frontend 應該有 error UX 但冇 render**(更深 bug, 通常係 `onError` callback 唔 fire 或者 error state UI 唔 mount)。

**Cleanup discipline:**任何 smoke test 直接 create 嘅 DB row,**完成後必刪**。Avoid prod DB pollution:
```bash
docker exec crm-api sh -c '...fetch(`.../${id}`, { method: "DELETE" })...'
```

**CRITICAL smoke 報告鐵律**:
- Console 冇 error **唔等於** mutation 成功
- Counter label + checkbox 視覺唔一致 = controlled input state desync,**trust 視覺 = 永遠 miss 呢類 bug**
- Submit 後 dialog 仲 freeze = mutation hook 冇 fire,證明要 trace 返 React DevTools 或者直接 bypass

## Skill Source

Created: 2026-04-24  
Updated: 2026-06-06 — added "Dialog Freezes — Counter Label vs Checkbox 視覺 Desync" pattern from crm-system smoke test
Context: WhatsApp-style React chatbot debugging — clicking sidebar conversation items didn't update chat area when tested via `browser_*` tools. Root cause was React synthetic event handling in Playwright, not actual code bug.
Created: 2026-04-24  
Context: WhatsApp-style React chatbot debugging — clicking sidebar conversation items didn't update chat area when tested via `browser_*` tools. Root cause was React synthetic event handling in Playwright, not actual code bug.
