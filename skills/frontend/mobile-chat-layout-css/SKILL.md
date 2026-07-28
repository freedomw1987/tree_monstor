---
name: mobile-chat-layout-css
description: Fix WhatsApp-style mobile chat layout with fixed input bar — missing CSS classes and padding issues
tags: [css, mobile, layout, react]
author: developer
created: 2026-04-21
---


Last-verified: 2026-07-28
# Mobile Chat Layout CSS — WhatsApp-Style Fixed Input Bar

## Problem
In a React chat app with sidebar + chat panel layout, mobile mode has `position:fixed` input bar at bottom, but messages get hidden behind it.

## Root Causes
1. `.hidden-mobile` class referenced in JSX but **never defined in CSS**
2. `.message-list` lacks `padding-bottom` to account for fixed input bar height

## Verified Fix

### App.css — mobile layout toggle
```css
@media (max-width: 768px) {
  .sidebar-panel {
    width: 100%;
    min-width: unset;
    position: fixed;
    inset: 0;
    z-index: 10;
  }

  .sidebar-panel.hidden-mobile {
    display: none;
  }

  .chat-panel {
    width: 100vw;
    position: fixed;
    inset: 0;
    overflow: hidden;
  }

  .chat-panel.hidden-mobile {
    display: none;
  }
}
```

### ChatArea.css — message list bottom padding
```css
@media (max-width: 768px) {
  .message-list {
    padding-bottom: 80px; /* height of fixed input bar + buffer */
  }
}
```

### InputBar.css — fixed positioning (reference)
```css
@media (max-width: 768px) {
  .input-bar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 6px 8px 8px;
    box-shadow: 0 -2px 8px rgba(0,0,0,0.2);
  }
}
```

## Key Insight
**Every class name used in JSX must be defined in CSS.** Use browser devtools to check computed styles when elements don't behave as expected.

## Common Flexbox Chat Layout Bug — Message List Doesn't Scroll (Desktop)

### Symptoms
- InputBar gets pushed off-screen when there are many messages
- Message list expands indefinitely instead of scrolling within a fixed area
- Everything works on mobile (with `position: fixed`) but breaks on desktop

### Root Cause
**The `min-height: 0` rule is missing.** In a flex column layout:
- `.chat-panel` has `display: flex; flex-direction: column`
- `.chat-area` has `flex: 1` (grows to fill space)
- `.message-list` has `flex: 1` (should fill remaining space and scroll)

Without `min-height: 0`, flex items interpret `flex: 1` as "grow to content size" — they ignore the parent's height constraint and expand to fit their content. The message list grows to fit ALL messages, pushing the InputBar off-screen.

### Fix — Add `min-height: 0` at every flex level

```css
/* .chat-panel — the outer container */
.chat-panel {
  flex: 1;
  height: 100%;
  min-width: 0;
  display: flex;
  flex-direction: column;
  min-height: 0; /* ← critical: allows children to shrink */
}

/* .chat-area — intermediate flex child */
.chat-area {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--wa-bg);
  min-height: 0; /* ← critical */
  flex: 1;
}

/* .message-list — the scrolling container */
.message-list {
  flex: 1;
  min-height: 0; /* ← critical: enables overflow-y scroll */
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
```

### Rule of Thumb
> In a flex column layout where a child has `flex: 1` and `overflow-y: auto`, **that element and every ancestor up to the fixed-height container must have `min-height: 0`**.

### Detection
1. Open DevTools → Elements
2. Inspect `.message-list` → Computed → Height
3. If height grows with message count instead of staying fixed → `min-height: 0` is missing somewhere in the chain
4. Also check: does `html, body, #root, .app-shell` all have `height: 100%` or `height: 100vh`?

## Detection
1. Open DevTools → Elements panel
2. Find element with `hidden-mobile` class
3. Check Styles pane — if class shows no rules, it's undefined
4. Mobile layout test: viewport 390x844, scroll to bottom, verify last message is visible above input bar

---

## Mobile Default View & Cascading Input Disable

### The Problem
Mobile chat app defaults to blank chat area (no conversation selected) → input bar is disabled → user cannot type even after starting a conversation.

### Root Cause Chain
1. `isMobileSidebarOpen` defaults to `false` (sidebar hidden)
2. On mobile load with no saved conversation → blank chat panel shows
3. `InputBar disabled={!selectedConv}` → input is disabled
4. User sees empty chat and can't interact with input

### The Fix — Auto-toggle mobile view by conversation state

```jsx
import { useState, useEffect } from 'react'

export default function App() {
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false)
  const { state } = useChat()
  const selectedConv = state.conversations.find(c => c.id === state.selectedId)

  // On mobile, show sidebar by default when no conversation is selected
  useEffect(() => {
    const isMobile = window.innerWidth < 768
    if (isMobile && !selectedConv) {
      setIsMobileSidebarOpen(true)   // show sidebar → user can tap "new chat"
    } else if (isMobile && selectedConv) {
      setIsMobileSidebarOpen(false)   // show chat panel
    }
  }, [selectedConv])

  return (
    <div className="app-shell">
      <div className={`sidebar-panel ${isMobileSidebarOpen ? '' : 'hidden-mobile'}`}>
        <Sidebar onNewChat={() => setIsMobileSidebarOpen(false)} onSelectConv={() => setIsMobileSidebarOpen(false)} />
      </div>
      <div className={`chat-panel ${isMobileSidebarOpen ? 'hidden-mobile' : ''}`}>
        <ChatArea onBack={() => setIsMobileSidebarOpen(true)} />
        <InputBar disabled={!selectedConv} />
      </div>
    </div>
  )
}
```

### Key Pattern
- **Mobile default**: Show sidebar (conversation list) when no conversation selected
- **Transition**: When user selects a conversation, switch to chat panel
- **Back button**: ChatArea has an `onBack` handler to return to sidebar
- The `useEffect` on `selectedConv` handles auto-transition on conversation change

---

## Mobile Scroll Overflow — align-items: center Kills Scrolling

### Symptoms
- Page content clipped at top/bottom on mobile
- Cannot scroll to see bottom elements (buttons, inputs) on Settings page, Landing page, or sidebar
- `overflow-y: auto` on child doesn't work — parent clips it

### Root Cause
`align-items: center` in a flex container with `min-height: 100vh` causes the flex child to be centered, and if it overflows, the overflow is clipped in both directions. The parent has no scroll context.

### Fix — Change align-items + add overflow-y to parent

```css
/* Settings, Auth pages — .auth-root */
.auth-root {
  align-items: flex-start; /* was: center */
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

/* Landing page — .landing */
.landing {
  align-items: flex-start; /* was: center */
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  box-sizing: border-box;
}

/* Sidebar panel mobile */
@media (max-width: 768px) {
  .sidebar-panel {
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }
}

/* Chat panel mobile — must scroll independently */
@media (max-width: 768px) {
  .chat-panel {
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }
}
```

### Rule
> Every full-page container with `min-height: 100vh` and `display: flex` **must use `align-items: flex-start`** if it contains scrollable children. Use `align-items: center` only when content is guaranteed to fit without scrolling.

### Detection
- Viewport: 375x812 (iPhone SE)
- If bottom buttons/input fields are cut off → align-items is center on a flex parent
- Fix: DevTools → Computed → flexbox → check align-items value
