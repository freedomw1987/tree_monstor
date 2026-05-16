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
