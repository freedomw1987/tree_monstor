---
name: vite-nginx-stale-cache-debug
description: Debug why Vite React app changes are not reflected after rebuild - Nginx serving stale cached JS. Key signal is immutable cache headers and JS file content unchanged.
category: debugging
tags: [vite, nginx, caching, react, deployment]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# Vite + Nginx Stale Cache Debug

## Symptoms
- Frontend rebuild completes (0 errors) but new behavior does not appear
- `curl -sI https://domain/assets/index.js | grep ETag` shows same ETag as before
- User sees old code despite code changes committed
- Browser cache clear does not fix it

## Root Cause
Nginx caches the JS file. Vite uses query param hash busting (`?v=XXXXXXXX`), NOT filename hashing. Nginx serves `file.js?v=NEW_HASH` as `file.js` (query stripped). Since URL never changes, `Cache-Control: public, immutable` caches the old file forever.

## Debug Commands

### Confirm stale cache
```bash
# When was dist file actually rebuilt
stat /path/to/frontend/dist/assets/*.js | grep Modify

# What is Nginx actually serving
curl -sI https://your-domain/assets/index.js | grep "Content-Length\|ETag\|Cache-Control"

# Check if dist file has your new code
grep -c "your-new-code-pattern" /path/to/frontend/dist/assets/*.js
```

### Check Nginx config for immutable caching
```bash
cat /etc/nginx/sites-available/your-domain
# Look for: expires 1y + add_header Cache-Control "public, immutable"
```

## Permanent Fix: Rename file in Vite config

In `vite.config.ts`:
```js
build: {
  rollupOptions: {
    output: {
      entryFileNames: 'assets/[name]-[hash].js',
      chunkFileNames: 'assets/[name]-[hash].js',
      assetFileNames: 'assets/[name]-[hash].[ext]'
    }
  }
}
```
This puts hash in the filename so URL changes on every content change. Nginx immutable cache becomes harmless since the URL itself changes.

## Temporary Fix: Disable immutable caching in Nginx

Change Nginx config from:
```nginx
expires 1y;
add_header Cache-Control "public, immutable";
```
To:
```nginx
expires -1;
add_header Cache-Control "no-cache, no-store, must-revalidate";
```
Then reload nginx.

## Key Diagnostic Pattern
```bash
# If this grep returns code BEFORE your fix, the cached file is being served
grep -o "some-code-pattern-from-your-fix" /path/to/frontend/dist/assets/*.js
```

## Prevention
- After any rebuild that changes behavior, verify dist file contains your new code
- Use `build.rollupOptions.output.assetFileNames` with `[hash]` for production
- After deploying, always do live verification: `curl -s URL | grep "your-new-code"`
