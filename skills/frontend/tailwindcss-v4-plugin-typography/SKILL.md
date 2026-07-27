---
name: tailwindcss-v4-plugin-typography
description: Fix Tailwind CSS v4 plugin registration for @tailwindcss/typography and prose classes
---


Last-verified: 2026-07-28
# Tailwind CSS v4 — Plugin Registration (typography etc.)

## Problem
`@tailwindcss/typography` installed but `prose` classes don't work. CSS bundle missing typography styles. Adding `require("@tailwindcss/typography")` to `tailwind.config.js` `plugins` array has no effect.

## Root Cause
Tailwind CSS v4 changed the plugin registration mechanism:

- **v3 (Tailwind 3.x)**: Plugins registered in `tailwind.config.js` `plugins` array with `require()`
- **v4 (Tailwind 4.x)**: Plugins registered directly in CSS with `@plugin` directive after `@import "tailwindcss"`

## Fix

In `src/index.css`:

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";

@theme {
  /* ... existing theme ... */
}
```

NOT in `tailwind.config.js` — that file is ignored for plugin registration in v4.

## Verification
After build, check the CSS bundle for `prose` classes:

```bash
grep -c "prose" dist/assets/*.css
```

Expected: count > 0 (typography plugin generates prose classes in the CSS bundle).

CSS bundle size should also grow noticeably (from ~33KB to ~57KB for a typical project).

## Trigger Conditions
- `tailwindcss: "^4.x.x"` in package.json (works with Vite via `@tailwindcss/vite` or any v4 build setup)
- `@tailwindcss/typography` installed but prose styles missing
- Plugin listed in `tailwind.config.js` plugins array with no effect

## Other v4 Plugins
The same `@plugin` syntax applies to any Tailwind v4 plugin:
- `@tailwindcss/typography`
- `@tailwindcss/forms`
- `@tailwindcss/line-clamp`
- etc.
