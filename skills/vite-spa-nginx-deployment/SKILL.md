---
name: vite-spa-nginx-deployment
description: Deploy a Vite React SPA behind nginx as a static file server — with SPA routing (HashRouter), permissions, and common pitfalls.
version: 1.0.0
metadata:
  hermes:
    tags: [devops, nginx, vite, react, deployment]
---

# Vite SPA + nginx Static Deployment

## Key Principles

1. **Serve the `dist/` folder statically** — NOT Vite dev server. Vite dev uses special paths (`/@vite/client`, `/src/main.jsx`) that nginx cannot proxy correctly.
2. **Use HashRouter** — so email links like `/#/reset/token` work without server-side route support.
3. **Fix www-data permissions** — nginx needs execute permission on the full path to `dist/`.

## nginx Config Pattern

Key directives (replace placeholder values with your actual domain and paths):
- `server_name YOUR_DOMAIN`
- `root /path/to/project/frontend/dist`
- `proxy_pass http://localhost:YOUR_BACKEND_PORT`
- `ssl_certificate` and `ssl_certificate_key` paths

SPA fallback: `try_files $uri $uri/ /index.html`

Static assets: `expires 1y` + `Cache-Control: public, immutable` on `/assets/` location.

## Critical: Path Permissions

nginx runs as `www-data`. Add execute permission on every parent directory leading to the static files:

```bash
# If dist/ is under /home/username/, www-data needs o+x on each parent
chmod o+x /home/username
chmod o+x /home/username/projects
chmod -R 755 /path/to/frontend/dist
```

## React Router: HashRouter for Email Links

Email verification / password reset links go to `https://yourdomain.com/#/reset/token`. `BrowserRouter` treats `#` as a client-side anchor — the server never sees `/reset/token`, causing 404 or wrong route match.

**Fix**: Use `HashRouter` in `main.jsx`. Both the import AND the JSX tag must be updated.

## Docker Container Deployment (SPA in nginx container)

When deploying a Vite SPA into a Docker container running nginx, **delete old assets before copying new ones**. Vite generates new hashed filenames on every build (e.g., `index-Cq2A7D9-.js` → `index-DcAipXpn.js`). If the container keeps old files alongside new ones, nginx may serve stale assets that don't match the new `index.html`.

```bash
# Step 1: Build locally
cd frontend && npm run build

# Step 2: Clear old assets in container
sudo docker exec CONTAINER_NAME sh -c "rm -rf /usr/share/nginx/html/assets/*"

# Step 3: Copy new assets AND index.html
sudo docker cp frontend/dist/assets/. CONTAINER_NAME:/usr/share/nginx/html/assets/
sudo docker cp frontend/dist/index.html CONTAINER_NAME:/usr/share/nginx/html/index.html
```

## Build & Deploy

```bash
# ⚠️ npm run build reads .env.production, NOT .env!
# Always pass VITE_ vars explicitly at build time:
VITE_API_BASE_URL=https://api.example.com npm run build

# Then rsync to nginx server
sudo rsync -av --delete /path/to/project/frontend/dist/ /var/www/your.domain.com/
```

| Symptom | Cause |
|---------|-------|
| Dev site still calls prod API | Browser cached old HTML — Ctrl+Shift+R or incognito |
| Hard refresh still shows old API | Build used wrong `.env` — pass VITE_ vars at build time |

## Common Failure Modes

| Symptom | Cause |
|---------|-------|
| Page blank, JS error in console | Browser cached old HTML. Hard refresh or use incognito. |
| 500 + permission denied in nginx error log | www-data can't traverse path to `dist/` |
| `/#/reset/token` goes to login instead of reset page | `BrowserRouter` used instead of `HashRouter` |
| Assets return 404 | nginx `root` still pointing to Vite dev server instead of `dist/` |
| Vite HMR requests 404 | Production nginx proxying to Vite dev server — switch to static `dist/` |

## SPA + Backend API: nginx Multi-Service Proxy

When deploying a Vite SPA alongside a **separate** backend API service (e.g., Elysia.js on port 4000), nginx must route ALL backend route prefixes to the API server. Missing routes fall through to the SPA fallback (`try_files`) and return 404.

**Example**: Backend uses `/auth`, `/api`, `/refresh` prefixes:
```nginx
upstream backend {
    server 127.0.0.1:4000;
}

server {
    listen 443 ssl;
    server_name your.domain.com;

    # Backend routes — must list ALL route prefixes the backend uses
    location /auth {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass_header Authorization;
    }
    location /api {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass_header Authorization;
    }

    # SPA fallback — must be last
    location / {
        proxy_pass http://127.0.0.1:3000;  # Vite dev or static SPA
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        try_files $uri $uri/ /index.html;
    }
}
```

**Common mistake**: Only routing `/api` to backend, but backend also uses `/auth` prefix. Requests to `/auth/*` then hit the SPA and return 404.

**Debugging**: If an API call returns 404 instead of the expected JSON response, check:
1. Is the route prefix listed in nginx config?
2. Is the backend service running on the correct port?
3. Does `curl http://localhost:BACKEND_PORT/the-route` work directly?

**Verify backend routes directly first**:
```bash
# Test backend directly
curl http://127.0.0.1:4000/auth/login -X POST -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"pass"}'

# Test via nginx (should match direct result)
curl https://your.domain.com/auth/login -X POST -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"pass"}'
```

If direct works but nginx fails → nginx is not proxying that route prefix.
