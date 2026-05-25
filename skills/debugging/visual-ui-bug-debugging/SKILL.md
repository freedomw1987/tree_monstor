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

## Common Pattern: List Page Renders Empty Even Though API Works

**Symptom:** User reports "the list doesn't show any items". API returns correct data via curl, but page is blank.

**Root cause pattern:** The page component only has a CREATE form but is **missing the loading logic entirely** — no `useEffect`, no `api.list()` call, no render of list items.

**Debugging steps:**
1. API check: `curl https://api.example.com/projects` — confirm it returns data.
2. Code inspection: Read the page component — look for `useEffect` and `api.list` or `api.get`.
3. The bug signature: A page that renders a create form but has NO `useEffect` + data-loading function.
4. Fix: Add the missing `useEffect` + loading + rendering logic.

**This pattern is extremely common** in React apps where a developer creates a page scaffold with a working create form, but forgets (or the code is reverted/lost) the list-loading side.

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
