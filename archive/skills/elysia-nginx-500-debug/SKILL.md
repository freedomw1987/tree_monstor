---
name: elysia-nginx-500-debug
description: Debug and fix intermittent HTTP 500 errors from Elysia.js (Bun) backend when proxied through nginx
tags: [bun, elysia, nginx, http-500, backend, reverse-proxy]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Elysia.js + nginx Intermittent 500 Debug

## Symptoms
- nginx proxy returns HTTP 500 ~40-60% of requests to `/api/` endpoints
- Direct backend calls (`curl http://localhost:3001/api/status`) always return 200
- Backend is Elysia.js running on Bun
- nginx error log shows no entries for the failing requests
- The 500 response body is `{"success":false,"message":"伺服器錯誤"}` — a JSON error from the backend

## Root Cause
Elysia.js (Bun) with HTTP/1.1 keepalive + streaming responses causes upstream connection issues with nginx's proxy module. The backend appears to sometimes close connections or send malformed responses that nginx interprets as 500.

## Debugging Steps

1. **Confirm backend is healthy** — direct curl to localhost:3001 should be 100% 200
2. **Check nginx error log** — `sudo tail /var/log/nginx/error.log`
3. **Try curl directly through nginx** — `curl -v https://domain.com/api/status`
4. **Test with rapid requests** — `for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code} "; done`
5. **Check if nginx is masked** — `systemctl status nginx` (masked nginx silently fails)

## Tried Fixes (all failed)
- `proxy_http_version 1.0`
- `proxy_buffering off`
- `proxy_cache off`
- `chunked_transfer_encoding on`
- `tcp_nodelay on`
- Adding timeouts (connect/send/read)
- Using `upstream {}` block with keepalive disabled
- Various Host/X-Forwarded-* header combinations

## Working Fix

Replace Elysia.js with plain Node.js `http` module:

```javascript
import http from 'http';
import { characters, rooms } from './data';

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  const url = req.url || '';
  
  if (url === '/api/status' && req.method === 'GET') {
    const active = characters.filter(c => c.status === 'working').length;
    const idle = characters.filter(c => c.status === 'idle').length;
    const body = JSON.stringify({ characters, rooms, tasks: { active, idle, queue: 2 } });
    res.writeHead(200, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
    res.end(body);
    return;
  }
  
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => console.log(`API running at http://localhost:${PORT}`));
```

## Key Lessons
- Elysia.js Bun server has invisible failures that don't show in Bun's console but cause nginx 500
- Always verify direct backend connectivity first before touching nginx config
- nginx masked state can cause confusing failures — check `systemctl status nginx` first
- HTTP/1.0 and closing Connection header helped but didn't fully fix the issue with Elysia