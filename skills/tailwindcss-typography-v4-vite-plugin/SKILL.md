---
name: tailwindcss-typography-v4-vite-plugin
description: Fix @tailwindcss/typography plugin not applying styles in Tailwind CSS v4 + Vite projects
category: frontend
---

# Tailwind CSS v4 + @tailwindcss/typography plugin registration

## Problem
`@tailwindcss/typography` styles not applying even though plugin is in `tailwind.config.js` plugins array.

## Root Cause
Tailwind CSS v4 changed the plugin registration mechanism. The `tailwind.config.js` approach from v3 does NOT work in v4.

## Correct Fix (Tailwind v4)
In your CSS file (`src/index.css`), add `@plugin` directive directly after `@import "tailwindcss"`:

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";

@theme {
  /* your custom theme variables */
}
```

## Wrong approach (tailwind.config.js for v4)
```js
// WRONG for v4 — this does nothing
plugins: [require("@tailwindcss/typography")]
```

## Verification
After build, check CSS bundle contains "prose" class:
```bash
grep -c "prose" dist/assets/*.css
# Should return > 0 (e.g., 1, 100, etc.)
```

## Trigger Conditions
- Using `tailwindcss: "^4.x.x"` in package.json
- `@tailwindcss/typography` installed but prose styles missing
- Using Vite as build tool
