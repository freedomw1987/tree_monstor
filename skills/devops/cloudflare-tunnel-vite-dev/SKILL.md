---
name: cloudflare-tunnel-vite-dev
description: Workaround for Vite dev server HMR WebSocket 403 errors when using Cloudflare Tunnel
---

# Cloudflare Tunnel + Vite Dev Server Workaround

## Problem
When exposing a Vite dev server (port 5173) via `cloudflared tunnel`, the page renders blank. Browser console shows:
```
Failed to load resource: the server responded with a status of 403 ()
```
Root cause: Vite's HMR (Hot Module Replacement) WebSocket connection is blocked by Cloudflare's network policies.

## Solution
Use Vite's **production build** (`npm run build`) instead of the dev server, served via a simple static file server.

### Steps
1. `npm run build` in the frontend project → outputs to `dist/`
2. **Important:** If the backend API runs on a different port than the static server, you need a combined static+proxy server (see below) to avoid CORS/blocked API calls.
3. Create Cloudflare tunnel to that port:
   ```bash
   cloudflared tunnel --url http://localhost:<port>
   ```
4. Use the generated `trycloudflare.com` URL for testing

### Static + Proxy Server (Node.js)
If the frontend static server and backend API run on **different ports** (e.g., static on 5174, API on 3002), use a Node.js static+proxy server to avoid CORS issues:

```javascript
// static-proxy.js
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5174;
const BACKEND = 'http://localhost:3002';

const MIME = { '.html':'text/html', '.js':'application/javascript', '.css':'text/css', '.json':'application/json', '.png':'image/png', '.jpg':'image/jpeg', '.svg':'image/svg+xml', '.ico':'image/x-icon' };

http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    // Proxy API requests to backend
    const opts = { hostname:'localhost', port:3002, path:req.url, method:req.method, headers:req.headers };
    const proxy = http.request(opts, (pr) => { res.writeHead(pr.statusCode, pr.headers); pr.pipe(res, {end:true}); });
    req.pipe(proxy, {end:true});
  } else {
    // Serve static files
    let fp = path.join('dist', req.url === '/' ? 'index.html' : req.url);
    if (!fs.existsSync(fp)) fp = path.join('dist', 'index.html');
    const ext = path.extname(fp);
    res.writeHead(200, {'Content-Type': MIME[ext] || 'text/plain'});
    fs.createReadStream(fp).pipe(res);
  }
}).listen(PORT);
```

Run with: `node static-proxy.js` from the project root (where `dist/` is located).

### Why this works
- Production build has no WebSocket/HMR dependency
- Single port = single Cloudflare tunnel = no CORS
- `/api/*` routing ensures API calls reach the backend without CORS preflight issues
- Simple HTTP static file serving is fully compatible with Cloudflare Tunnel
- No CSP, HMR, or WebSocket issues

### ⚠️ Critical: `allowedHosts` in vite.config.js

When Vite dev server is exposed via Cloudflare Tunnel, even after the HMR WebSocket issue is resolved, Vite may still block the request with:
```
403 Blocked request. This host ("xxx.trycloudflare.com") is not allowed.
```

**Fix:** In `vite.config.js`, set `server.allowedHosts: true`:
```js
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    allowedHosts: true,  // ← Required for Cloudflare tunnel
    proxy: {
      '/api': {
        target: 'http://localhost:3002',
        changeOrigin: true
      }
    }
  }
})
```

This tells Vite to accept requests from any host, which is necessary when using cloudflared tunnel (which changes the effective host from `localhost` to `xxx.trycloudflare.com`).

## ⚠️ Critical Rule: `vite --port` Does NOT Load vite.config.js

**Running `vite --port 5174` (or any port) does NOT load `vite.config.js`.** The proxy settings, `allowedHosts`, and all `server.*` config are completely ignored. Only `npm run dev` reads the config file properly.

**Correct ways to start Vite dev server:**
- `npm run dev` — ✅ loads vite.config.js
- `vite --port X` — ❌ ignores vite.config.js

If you need a proxy and must use a non-standard port, use **Option A** (`npm run dev` with `allowedHosts: true`) or **Option B** (production build + static proxy server).

## When to use dev server directly
If you only need to test on the **same machine** as the dev server, skip the tunnel and access `http://localhost:5173` directly. HMR only matters during development when you want live reload.

### Before starting servers — check for port conflicts
```bash
# Check if port is already in use
lsof -i :<port> || netstat -tlnp | grep <port>

# Kill stale processes before restarting
pkill -f "node.*server"  # adapt pattern to your process name
```

### ⚠️ Cloudflared Process Management (Critical)

**Problem:** Multiple `cloudflared tunnel` processes stack up from previous sessions. Old processes keep the tunnel alive on the old URL while new ones create new tunnels. This causes "stale URL" confusion — you read the URL from an old log file and share a dead link.

**Symptoms:**
- `ps aux | grep cloudflared` shows 2-3 cloudflared processes
- Tunnel URL in log files doesn't match the currently running process
- Cloudflared logs show `url:http://localhost:WRONG_PORT` (e.g., 5173 instead of 5174)

**Solution — Clean slate before every tunnel start:**
```bash
# 1. Kill ALL existing cloudflared processes
pkill -9 -f cloudflared
sleep 1

# 2. Verify they're dead
ps aux | grep cloudflared | grep -v grep  # should return nothing

# 3. Verify vite/server is on the RIGHT port
lsof -i :5174  # or whatever port you're using

# 4. Start cloudflared with log file capture
bash -c 'cloudflared tunnel --url http://localhost:5174 2>&1' > /tmp/cf.log &
sleep 12

# 5. Extract the URL from THIS session's log only
grep "trycloudflare.com" /tmp/cf.log | head -1
```

**Why redirect through bash:** The `terminal(background=true)` mechanism does not reliably capture cloudflared's stdout to a queryable log. Cloudflared prints the URL once at startup and the background process session doesn't expose it to tools. Redirecting via `bash -c '... 2>&1' > /tmp/file` is the reliable approach.

**Reliable startup sequence:**
```bash
# 1. Kill ALL existing cloudflared processes
pkill -9 -f cloudflared
sleep 1

# 2. Start new tunnel with output → file redirection
terminal(background=true, command="cloudflared tunnel --url http://localhost:5174 --no-autoupdate > /tmp/cf_new.log 2>&1")

# 3. Wait for URL to appear in log (~10-15s)
sleep 12
# Read the log file
read_file("/tmp/cf_new.log")

# 4. Extract URL
grep "trycloudflare.com" /tmp/cf_new.log | head -1

# 5. Verify the URL is actually accessible (don't trust just the process being alive)
curl -s -o /dev/null -w "%{http_code}" https://xxx.trycloudflare.com/
# Must return 200
```

**⚠️ A running cloudflared process does NOT mean the URL is accessible.** Always verify with `curl`. If the process is running but curl returns non-200, kill the process and start a new tunnel.

**Always verify the port** in cloudflared's output matches what you're serving:
```
INF Settings: map[... url:http://localhost:5174]  ← correct
INF Settings: map[... url:http://localhost:5173]  ← wrong, server isn't on 5173
```

## Ports reference
- Vite dev: 5173 (blocked by Cloudflare for HMR)
- Static build: any port (e.g., 5174)
- Backend API: typically 3000/3001/3002
