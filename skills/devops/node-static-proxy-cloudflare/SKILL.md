---
name: node-static-proxy-cloudflare
description: Start a Node.js static+proxy server and Cloudflare tunnel in the correct sequence with proper process management
---

# Node.js Static+Proxy + Cloudflare Tunnel Startup

## Problem
Starting a static file server with API proxy and exposing it via Cloudflare tunnel involves multiple processes. Wrong sequencing or shell-level backgrounding causes EADDRINUSE, "connection refused", and zombie processes.

## Correct Startup Sequence

**Order matters — always.**

1. Kill existing processes on all ports
2. Start backend (wait for it to be ready)
3. Start static+proxy server (wait for it to be ready)
4. Start Cloudflare tunnel pointing at static+proxy port

## Step-by-Step

```javascript
// Step 1: Kill any existing processes on key ports
lsof -i :3002 | grep -v "^COMMAND" | awk '{print $2}' | sort -u | xargs -r kill -9
lsof -i :5174 | grep -v "^COMMAND" | awk '{print $2}' | sort -u | xargs -r kill -9
pkill -f cloudflared
```

```javascript
// Step 2: Start backend
terminal(background=true, command="cd ~/projects/whatsapp-chatbot/backend && node server.js > /tmp/backend.log 2>&1")
// Verify: terminal(command="sleep 2 && lsof -i :3002") // should show LISTEN
```

```javascript
// Step 3: Start static+proxy server (Node.js inline script)
terminal(background=true, command=`node -e "
const http = require('http');
const fs = require('fs');
const path = require('path');
const distDir = '/home/ubuntu/projects/whatsapp-chatbot/frontend/dist';
const PORT = 5174;
const MIME = { '.html':'text/html', '.js':'application/javascript', '.css':'text/css', '.json':'application/json', '.png':'image/png', '.jpg':'image/jpeg', '.svg':'image/svg+xml' };
http.createServer((req, res) => {
  if (req.url.startsWith('/api')) {
    const opts = { hostname:'localhost', port:3002, path:req.url, method:req.method, headers:req.headers };
    const pr = http.request(opts, (proxyRes) => { res.writeHead(proxyRes.statusCode, proxyRes.headers); proxyRes.pipe(res, {end:true}); });
    req.pipe(pr, {end:true});
  } else {
    let fp = path.join(distDir, req.url === '/' ? 'index.html' : req.url);
    const ext = path.extname(fp);
    res.writeHead(200, {'Content-Type': MIME[ext] || 'application/octet-stream'});
    fs.createReadStream(fp).pipe(res);
  }
}).listen(PORT, () => console.log('Static+Proxy on ' + PORT));
" > /tmp/static.log 2>&1`)
// Verify: terminal(command="curl -s -o /dev/null -w '%{http_code}' http://localhost:5174") // should return 200
```

```javascript
// Step 4: Start Cloudflare tunnel — ONLY after static server verified
terminal(background=true, command="cloudflared tunnel --url http://localhost:5174 > /tmp/cloudflared.log 2>&1")
// Extract URL within 10 seconds:
terminal(command="sleep 10 && grep -o 'https://[a-z0-9-]*\\.trycloudflare\\.com' /tmp/cloudflared.log | head -1")
```

## ⚠️ Critical Rule: `vite --port` Does NOT Load vite.config.js

**A common mistake is to run `vite --port 5174` to start the dev server on a different port. This does NOT load `vite.config.js` — so `server.proxy` settings are completely ignored.**

Symptoms:
- `vite.config.js` has `server.proxy` configured for `/api`
- `vite --port 5174` starts successfully
- But API calls from the browser return `404` — the proxy never activated
- The proxy config in vite.config.js is simply never read

**Two correct approaches:**

**Option A — Use `npm run dev`** (recommended for development with HMR):
- Vite loads `vite.config.js` properly → proxy works
- Requires `server.allowedHosts: true` for Cloudflare tunnel

**Option B — Production build + static proxy server** (more reliable, no HMR):
- `npm run build` → generates `dist/`
- Serve `dist/` via a custom Node.js static+proxy server
- This is the approach described in this skill

**Why this matters:** `vite --port X` is just a port override flag. It tells Vite "listen on port X" but skips all config file loading. Only `npm run dev` (which internally calls `vite` with the proper loader) reads `vite.config.js`.

## Critical Rules

- **Use `terminal(background=true)` for ALL long-lived processes** — never shell-level `&` or `nohup`
- **Never start cloudflared before the static server is confirmed running** — it will permanently fail and the tunnel URL will never appear
- **Extract the tunnel URL immediately** — it appears in the first ~10 lines before any connection logs
- **Kill all processes on same ports before restarting** — port conflicts give EADDRINUSE

## Starting / Restarting Cloudflare Tunnel

**Always kill existing cloudflared processes before restarting — old instances linger:**
```bash
pkill -f cloudflared
sleep 1
```

**Wrap cloudflared in `sh -c` so output is redirected to a log file:**
```javascript
terminal(background=true, command="sh -c 'cloudflared tunnel --url http://localhost:5174 > /tmp/cf.log 2>&1'")
// Extract URL after 10s:
terminal(command="sleep 10 && grep -o 'https://[a-z0-9-]*\\.trycloudflare\\.com' /tmp/cf.log | head -1")
```

Without `sh -c`, cloudflared output is silently discarded and the tunnel URL never appears in any log.

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `EADDRINUSE :::5174` | Old process still on port | Kill with `lsof -i :PORT \| awk '{print $2}' \| xargs kill -9` |
| `connection refused` from cloudflared | Static server not running yet | Verify `curl localhost:PORT` before starting tunnel |
| Cloudflare exits with code 1 | Port still in use | Kill existing process first |
| No tunnel URL in log | Extracted too early OR cloudflared output not captured | Wrap in `sh -c '... > /tmp/cf.log 2>&1'`, wait 10s, check `/tmp/cf.log` |
| Duplicate cloudflared processes | Old instances not killed | `pkill -f cloudflared` before starting |

## Ports Reference
- Backend: `3002`
- Static+Proxy: `5174`  
- Cloudflare tunnel: proxies to `localhost:5174` (not directly to backend)

## Custom Hostname (david-developer.com) — Requires Cloudflare Auth

Using `--hostname chatbot.david-developer.com` with a Quick Tunnel requires `cloudflared login` to authenticate with your Cloudflare account first. Without it, the tunnel appears to work (gets a trycloudflare.com URL) but `--hostname` setting is silently ignored — the domain never actually resolves.

**Quick Tunnel with `--hostname` still returns a trycloudflare.com URL.** The `--hostname` parameter is stored in Settings but has no effect without auth. Always check `/tmp/cf.log` to see what URL was actually assigned.

Two working options for custom subdomain:
1. **Named Tunnel** (recommended): `cloudflared login` once, then `cloudflared tunnel route dns <name> <subdomain>`. URL is permanently stable.
2. **Quick Tunnel + Route53 CNAME**: Start Quick Tunnel, grab the trycloudflare.com URL, create a Route53 CNAME pointing to it. Update CNAME whenever tunnel restarts.

## Detecting NAT/Non-Routable Servers

Before choosing nginx+Let's Encrypt vs Cloudflare Tunnel, check if the server is actually reachable from the internet:

```bash
# Test from outside
curl -s --connect-timeout 5 http://$(curl -s ifconfig.me)/

# timeout = NAT/shared IP, ports blocked → MUST use Cloudflare Tunnel
# refused = port free, can use nginx + certbot
# 200 = fully routable public IP → can use nginx + Let's Encrypt
```

AWS EC2 instances with Elastic IP behind NAT will show timeout. The `ifconfig.me` public IP and the actual routable IP are different in NAT setups.

**Two modes:**

| Mode | Auth needed | URL | Stability |
|------|-------------|-----|-----------|
| Quick Tunnel (`--url` only) | No | Random `.trycloudflare.com` | URL changes on restart |
| Named Tunnel (`--hostname`) | Yes (`cloudflared login`) | Your subdomain (e.g. `chatbot.david-developer.com`) | Persistent |

**To use a custom subdomain:**
1. On a machine with a browser: run `cloudflared login` and complete the OAuth flow
2. Or: manually add a CNAME in Cloudflare Dashboard pointing to the Quick Tunnel URL (must update whenever tunnel restarts)
3. Then: `cloudflared tunnel --url http://localhost:5174 --hostname chatbot.david-developer.com`

**If `--hostname` hangs silently:** The tunnel is waiting for DNS propagation or auth is not complete. Check `curl -s https://chatbot.david-developer.com` — it will fail until DNS/CNAME is set up.

## Verification Commands
```bash
lsof -i :3002   # backend
lsof -i :5174   # static
curl localhost:5174          # 200 = static OK
curl localhost:3002/api/chat  # should stream or return 200
curl localhost:5174/api/chat # 200 = proxy OK
grep trycloudflare /tmp/cloudflared.log  # tunnel URL
```
