---
name: visual-ui-bug-debugging
description: Debug visual UI bugs where user reports something doesn't work but API/terminal checks pass. Use browser + vision analysis instead of just terminal tools.
---

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
