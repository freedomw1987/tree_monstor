---
name: react-browser-automation-gotchas
description: Debug React UI state issues when Playwright/browser automation fails to trigger React synthetic events. Use when browser_click() doesn't update React state.
---

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

## Skill Source

Created: 2026-04-24  
Context: WhatsApp-style React chatbot debugging — clicking sidebar conversation items didn't update chat area when tested via `browser_*` tools. Root cause was React synthetic event handling in Playwright, not actual code bug.
