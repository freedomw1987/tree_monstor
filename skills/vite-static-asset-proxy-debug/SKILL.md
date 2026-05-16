---
name: vite-static-asset-proxy-debug
category: debugging
description: Diagnose and fix Vite dev server not proxying backend static asset paths (images, files) — common pattern where assets work in production but return HTML in local dev.
---

# Vite Dev Server Static Asset Proxy Debug

## When to Use
When static assets (images, files) served by a backend work in production but not in local Vite dev server — especially if the URL returns HTML instead of binary content.

## Symptoms
- Image URL `/ai-images/...` returns `<!DOCTYPE html>` in Vite dev (port 5173/5174) but correct binary in production
- Lightbox/expanded view works but inline preview doesn't
- Image element exists in DOM with correct dimensions (`offsetWidth > 0`) but invisible
- `curl http://localhost:PORT/ai-images/...` returns HTML, not image bytes

## Root Cause Pattern
Vite dev server does NOT serve files outside of project root by default. If the backend (port 3002) serves static files from its own `public/` directory, Vite returns its own index.html for those paths unless explicitly proxied.

## Diagnosis Checklist
1. `curl -s http://localhost:VITE_PORT/ai-images/img.jpg | head -c 20 | xxd` — check if HTML or binary
2. Compare with `curl -s http://localhost:BACKEND_PORT/ai-images/img.jpg | head -c 20 | xxd` — backend should return binary
3. Check `vite.config.js` proxy section — is the static path proxied?
4. Check production web server config — does it proxy the static path to backend?

## Fix

**vite.config.js** — add proxy for the backend static asset path:
```javascript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:3002',
      changeOrigin: true
    },
    '/ai-images': {
      target: 'http://localhost:3002',
      changeOrigin: true,
      rewrite: (path) => path
    }
  }
}
```

## Verification
```bash
# Should return binary (PNG header: 89 50 4e47, JPEG header: ff d8 ff)
curl -s http://localhost:5174/ai-images/img.jpg | head -c 20 | xxd

# If returns <!DOCTYPE html> — proxy is missing or not working
```

## Key Insight
The same problem pattern applies to any backend-served static path: `/uploads/`, `/files/`, `/attachments/`, etc. Always proxy them in Vite dev config alongside `/api/`.

## Related
- whatsapp-chatbot skill (has relevant project context)
- nginx-sse-streaming-fix skill (nginx proxy gotchas for backend-served content)

---

## Vite Build: `.env.production` Overrides `.env` Even in Dev

### Symptoms
- Dev website (e.g. `https://course.david-developer.com`) loads but all API calls go to production (e.g. `api.board-ai.site`)
- `curl https://your-dev-site.com/assets/index-XXXXX.js | grep -c api.production-site.com` returns > 0
- Dev `.env` file has correct `VITE_API_BASE_URL` but built JS contains wrong domain

### Root Cause
Vite's `loadEnv` function loads `.env.production` when `VITE_APP_ENV` is not explicitly set to `"development"`, AND when `process.env.NODE_ENV` is not `"development"`. `npm run build` defaults `NODE_ENV=production`, so it loads `.env.production` which overrides `.env`.

### Always Use Explicit Env Var When Building Dev
```bash
VITE_API_BASE_URL=https://your-dev-api.com/api npm run build
```

Or set both explicitly:
```bash
NODE_ENV=development VITE_API_BASE_URL=https://your-dev-api.com/api npm run build
```

Never rely solely on `.env` file for Vite builds — always pass the target env var explicitly.

### Verification After Build
```bash
# Check built JS for wrong API domain
curl -s https://your-dev-site.com/assets/index-XXXXX.js | grep -o 'api\.wrong-domain\.com' | wc -l
# Should return 0

# Check for correct API domain
curl -s https://your-dev-site.com/assets/index-XXXXX.js | grep -o 'api\.correct-domain\.com' | wc -l
# Should return >= 1
```

### Key Insight
This applies to any env var prefixed with `VITE_`. If you need a dev build with different values than production, always pass them explicitly during `npm run build` — never rely on `.env` file alone for build-time env vars.
