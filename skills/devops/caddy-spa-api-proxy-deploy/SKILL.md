---
name: caddy-spa-api-proxy-deploy
description: Deploy Vite SPA + Bun API backend behind Caddy reverse proxy in Docker with host networking
---

# Caddy SPA + API Reverse Proxy Deployment

Deploy a Vite SPA frontend and Bun/Elysia API backend behind Caddy reverse proxy in Docker.

## Context

- Caddy runs in Docker container with `network_mode: host`
- Frontend: Vite preview server on host port (e.g., 3002)
- Backend: Bun server on host port (e.g., 3000)
- Domain: e.g., `pos.david-developer.com`
- Goal: `https://domain/` → frontend, `https://domain/api/*` → backend API

## Setup Steps

### 1. Vite Config

```typescript
// vite.config.ts
export default defineConfig({
  server: {
    host: '0.0.0.0',  // Required for Caddy in Docker to reach it
  },
  build: {
    outDir: 'dist',
  },
  preview: {
    port: 3002,
    host: '0.0.0.0',
  },
})
```

### 2. Caddyfile

```caddy
pos.david-developer.com {
    # SPA frontend — Vite preview handles SPA fallback natively
    handle /api/* {
        handle_path /api/*  # Strip /api prefix before proxying
        reverse_proxy 172.31.19.145:3000  # Use host IP, not host.docker.internal
    }

    # All other routes → Vite preview (SPA fallback)
    reverse_proxy 172.31.19.145:3002
}
```

**Key insight**: `handle_path` vs `handle`:
- `handle /api/*` — proxies `/api/auth/login` as-is to backend (backend must know `/api` prefix)
- `handle_path /api/*` — strips `/api`, proxies `/auth/login` to backend (backend has no `/api` prefix)

Choose based on your backend routes. If backend uses `/auth/login`, use `handle_path`. If backend uses `/api/auth/login`, use `handle`.

### 3. Get Host IP

```bash
ip route get 1 | awk '{print $(7)}'
# or
hostname -I | awk '{print $1}'
```

Use that IP in Caddyfile instead of `host.docker.internal`.

### 4. Start Services on Host

```bash
# Backend (Bun)
cd ~/projects/lemontree_aws/backend && bun src/index.ts &

# Frontend (Vite preview — supports SPA fallback natively)
cd ~/projects/lemontree_aws/frontend && bun run preview --port 3002 --host &
```

### 5. Reload Caddy

```bash
sudo docker exec chatbot-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

### 6. Verify

```bash
# Frontend
curl -s -o /dev/null -w "%{http_code}" https://pos.david-developer.com/
# → 200

# Dashboard route (SPA)
curl -s -o /dev/null -w "%{http_code}" https://pos.david-developer.com/dashboard
# → 200

# API
curl -s -X POST https://pos.david-developer.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"pass"}'
# → {"success":true,"token":"..."}
```

## Pitfalls

### ❌ Python http-server / bunx http-server
These servers do NOT support SPA fallback. All 404s return a blank page instead of `index.html`. **Use Vite preview instead** — it has built-in SPA fallback.

### ❌ Alpine-based Prisma in Debian Docker
Prisma Alpine binaries crash on Debian containers with "Failed to fetch Inter from fetch priority". Use host processes instead of Docker for Bun/Node services if you hit this.

### ❌ `host.docker.internal` in host-network Docker
With `network_mode: host`, `host.docker.internal` doesn't resolve inside the container. Use the host's actual IP address instead.

### ❌ Caddy `handle` instead of `handle_path`
If backend expects `/auth/login` but you proxy `/api/auth/login` as-is, the backend returns 404. Use `handle_path` to strip the prefix.

### ❌ Caddy not reloaded after config change
Caddy caches the config. Always `reload` after editing the Caddyfile.

## Architecture

```
Internet
    ↓ HTTPS
Caddy (Docker, host network, ports 80/443)
    ├── /api/* → handle_path strip → reverse_proxy host:3000 (Bun backend)
    └── /*     → reverse_proxy host:3002 (Vite preview, SPA fallback)
```
