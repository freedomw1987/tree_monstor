---
name: ios-safari-scroll-fixed-elements
description: Fix iOS Safari scrolling issues for elements using position:fixed inside overflow:hidden bodies. For React apps where a page (Login, Settings, etc.) uses a fixed-position root div that can't scroll on mobile Safari.
applicability: generic-pattern
---


Last-verified: 2026-07-28
# iOS Safari Scrolling Fix for Fixed-Position Elements

## The Problem

On iOS Safari, a `position: fixed` element with `overflow-y: auto` **won't scroll** if its parent `body` has `overflow: hidden` but the fixed element lacks explicit height constraints.

Symptoms:
- Desktop: works fine
- iOS Safari: content overflows but can't scroll
- Swiping does nothing or causes the whole page to bounce/overscroll
- The fixed element's content is cut off at the viewport edge

## Root Cause

iOS Safari requires explicit height constraints on a scrollable container. When a div uses `position: fixed` without `height: 100%` on both `html/body` and the element itself, Safari treats it as having no defined height boundary, so `overflow-y: auto` has no scrollable area.

## The Fix (CSS)

Apply to the page's root container (e.g., `.auth-root`, `.settings-root`):

```css
/* Step 1: Lock the body/html — they must NOT scroll */
html, body {
  height: 100%;
  overflow: hidden;
}

/* Step 2: Make the page container the scrollable region */
.page-root {
  min-height: 100vh;
  height: 100%;           /* Critical: gives Safari a defined height */
  position: relative;      /* Critical: establishes containing block */
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;  /* iOS momentum scroll */
  overscroll-behavior: contain;       /* prevents scroll chaining */
  box-sizing: border-box;
}

/* Step 3: If the inner card has flex layout, prevent it from shrinking */
.page-card {
  flex-shrink: 0;   /* prevents card from collapsing in flex container */
}
```

## Key Properties Explained

| Property | Why It Matters |
|---|---|
| `html,body { height:100%; overflow:hidden }` | Safari needs both set. `overflow:hidden` on body stops double-scrollbars and Safari's rubber-band effect on the document level |
| `height: 100%` on .page-root | Without this, Safari treats `position:fixed` as `height:auto` and calculates 0 scrollable area |
| `position: relative` on .page-root | Establishes a containing block for absolutely-positioned children |
| `overscroll-behavior: contain` | Prevents scroll-chaining to parent elements (i.e., stops the "pull to refresh" rubber-banding from propagating) |
| `flex-shrink: 0` on inner card | In a flex container, the card won't be compressed to 0 height |

## Common Pitfalls

1. **Setting `min-height: 100vh` but no `height: 100%`** — `100vh` on iOS Safari includes the browser chrome (address bar). Use `100%` with `overflow:hidden` on body instead.

2. **`overflow: hidden` on body without `height: 100%`** — This alone doesn't fix iOS Safari. Both must be set.

3. **`position: fixed` on the scrollable element** — If the page root IS `position: fixed`, it still needs `height: 100%` explicitly. Fixed positioning removes an element from normal flow, so Safari can't infer its height.

4. **`-webkit-overflow-scrolling: touch` missing** — Without this, iOS uses scroll deceleration that feels "janky" compared to native apps.

## For React SPAs (Vite + React Router)

When the entire app lives inside a root div with `overflow: hidden` (common in chat apps with sidebar layouts), auth/settings sub-pages need their own independent scroll context:

```jsx
// AccountSettings.jsx
<div className="auth-root">  {/* ← this must be the scroll container */}
  <div className="auth-card">
    {/* ...long form content... */}
  </div>
</div>
```

The `.auth-root` must have `height:100%` and `overflow-y:auto`. The `.auth-card` should NOT be `position:fixed` — it should be a normal flow element inside the scrollable container.

## When This Pattern Doesn't Apply

- If the scrollable element is `position: absolute` (then `overflow` works without `height:100%`)
- If the page uses `position: sticky` (scrolls naturally without special handling)
- If the content is inside a modal/overlay with its own scroll layer

## Skill Source

Created: 2026-04-24
Context: Fixed iOS Safari scrolling on WhatsApp chatbot's Settings page (`/#/settings`) which uses `.auth-root` from Auth.css. The `.auth-root` had `overflow-y: auto` but lacked explicit `height: 100%`, and `html/body` lacked `height: 100%; overflow: hidden`.
