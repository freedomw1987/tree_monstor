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
- whatsapp-ai-chatbot skill (has relevant project context)
- nginx-sse-streaming-fix skill (nginx proxy gotchas for backend-served content)
