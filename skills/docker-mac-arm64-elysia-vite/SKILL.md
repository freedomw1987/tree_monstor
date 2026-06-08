---
name: docker-mac-arm64-elysia-vite
description: Docker build pitfalls on Mac arm64 (M1/M2/M3/M4) for Elysia (Bun) + Vite 8 (rolldown) projects. Covers missing libssl in oven/bun, npm optional native binding skip, package-lock.json darwin freeze, healthcheck wget absence, and frontend nginx reverse proxy setup.
tags: [docker, mac, arm64, elysia, bun, vite, rolldown, prisma, nginx]
---

# Docker on Mac arm64: Elysia + Vite Pitfalls

Hit these between 2026-06-04 building `~/www/llm-acp`. Likely to repeat on any new Docker-ization of Bun + Vite 8 SPA on Apple Silicon.

## Pitfall 1: Prisma 5 schema engine needs libssl

`oven/bun:1.2` is Debian slim — no `libssl`, no `wget`. Prisma 5 schema engine (`bunx prisma db push`, `migrate dev`) bombs:

```
prisma:warn Prisma failed to detect the libssl/openssl version to use
Error: Schema engine error:
```

**Fix** (in `backend/Dockerfile` base stage):
```dockerfile
FROM oven/bun:1.2 AS base
WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl ca-certificates curl && rm -rf /var/lib/apt/lists/*
```

`curl` is needed too (see pitfall 2).

## Pitfall 2: `wget` not in `oven/bun:1.2`

Default Compose `healthcheck` examples use `wget`. Container fails healthcheck even when Elysia is fine.

**Fix** in `docker-compose.yml`:
```yaml
healthcheck:
  test: ["CMD", "curl", "-fsS", "http://localhost:PORT/api/health"]
```

## Pitfall 3: Vite 8 + rolldown native binding not installed for linux-arm64

When you `COPY package-lock.json` from a Mac host into a `node:20-slim` (linux-x64) or arm64 image, npm preserves the lockfile's `os: darwin` filter for platform-specific optional deps. `@rolldown/binding-linux-arm64-gnu` and `@rolldown/binding-linux-x64-gnu` are listed as `optionalDependencies` and silently skipped. Build then crashes:

```
Error: Cannot find module '../rolldown-binding.linux-x64-gnu.node'
```

Similarly `lightningcss` (Tailwind v4 dep) has the same problem.

**Fix** — DON'T copy the lockfile; let container resolve fresh:
```dockerfile
COPY package.json ./
RUN npm install --no-audit --no-fund --include=optional
```

Tradeoff: lockfile drift between host and container. Acceptable for SPAs. Use a platform-agnostic resolver (corepack + pnpm with `--ignore-platform`) if you need stricter reproducibility.

## Pitfall 4: Don't `--platform=linux/amd64` on Mac arm64

`FROM --platform=linux/amd64 node:20-slim` works for `docker build` via QEMU, but `docker compose up` will refuse to start the container:

```
The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
```

**Fix**: just use `FROM node:20-slim` (default arm64), and rely on pitfall 3's fix.

## Pitfall 5: Prisma `prisma db push --accept-data-loss` is destructive

`docker compose up` re-runs `prisma db push --accept-data-loss` every time. Safe for first deploy, but on schema changes it can drop columns. Use `prisma migrate deploy` in production for safer rollouts.

## Pitfall 6: Build context cleanliness

Backend's `src/index.ts` and `prisma/seed.ts` originally used `import.meta.dir + "../.."` to read `~/www/llm-acp/questions.json`. Worked locally but the build context `backend/` doesn't have that path. Fix: copy `questions.json` into `backend/` and use `".."` only.

## Pitfall 7: Elysia 1.2 + `bun build` is broken in two ways (added 2026-06-05, `crm-system`)

When the user runs an Elysia API in a Docker image, the natural instinct is to `bun build` a single-file bundle for fast startup. **Don't.** On Elysia 1.2.x two distinct failures happen:

1. **`bun build --minify`** crashes at runtime with an internal minified variable error:
   ```
   ReferenceError: vn is not defined
       at /app/dist/index.js:413:54034
   ```
   Cause: Elysia's route handler uses `compile?.()` runtime code generation that emits references to internal variables the minifier renames inconsistently. Even `--minify-whitespace` alone is risky.

2. **`bun build --external @prisma/client`** (the obvious fix to keep Prisma out of the bundle) gives:
   ```
   ReferenceError: client is not defined
       at /app/dist/index.js:21172:31
   ```
   The `--external` flag breaks the bundled output's resolution of the re-exported `@prisma/client` namespace symbol from `@crm/db`.

**Fix** — run source directly, no bundling. COPY the entire workspace (excluding `node_modules` which is rebuilt) into the runtime image and start with `bun run`:

```dockerfile
# runtime stage
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/api ./apps/api
COPY --from=builder /app/packages/db ./packages/db
COPY --from=builder /app/packages/ai ./packages/ai
COPY --from=builder /app/packages/shared ./packages/shared
# Prisma client is hoisted to root node_modules by Bun workspaces
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
# ...
CMD ["bun", "run", "apps/api/src/index.ts"]
```

Tradeoff: image is ~200MB larger and cold start a bit slower, but it's the only stable path on Elysia 1.2.x. Revisit when Elysia 1.3+ ships a fixed bundler story.

## Pitfall 8: `USER bun` + entrypoint script permission (added 2026-06-05, `crm-system`)

`oven/bun:1.2` ships a `bun` user (uid 999). If you `USER bun` after `COPY --chmod=755 entrypoint.sh`, the entrypoint fails with:
```
/bin/sh: 0: cannot open /usr/local/bin/entrypoint: Permission denied
```
And dumb-init at the front of ENTRYPOINT just keeps respawning the container.

**Fix for local deployment** — run as root, add a comment for hardening later:
```dockerfile
# Run as root for simplicity in local deployment.
# (For a more hardened setup, switch to USER bun and adjust file perms.)
# USER bun
ENTRYPOINT ["dumb-init", "/usr/local/bin/entrypoint"]
```
For production hardening you'd need to chown the file to `bun:bun` AND make `/app` writable.

## Frontend nginx + Elysia reverse proxy

`frontend/nginx.conf`:
```nginx
server {
    listen 80;

    location /api/ {
        proxy_pass http://backend:PORT/api/;
        # standard proxy_set_header, proxy_http_version 1.1
    }
    location / {
        try_files $uri $uri/ /index.html;  # SPA fallback
    }
    location ~* \.(js|css|png|...)$ { expires 30d; }
}
```

Use Docker Compose service name (`backend`) not `localhost` in `proxy_pass` — they share a network.

### SPA fallback rewrite cycle (added 2026-06-05, `crm-system`)

The common `try_files $uri $uri/ /index.html` pattern in `location /` will throw a 500 on the root request with this error in the nginx container log:

```
[error] rewrite or internal redirection cycle while internally
redirecting to "/index.html"
```

Reason: when `try_files` falls through to `/index.html`, that path itself matches `location /` and the cycle repeats. Affects every SPA (React/Vue/Svelte) nginx setup, not just Vite.

**Fix** — use a named location for the fallback so the rewrite target is unambiguous:
```nginx
location / {
    try_files $uri $uri/ @spa;
}
location @spa {
    root /usr/share/nginx/html;
    try_files /index.html =404;
}
```

`@spa` is a named location, never matched by URI, so no cycle.

## Reference

Working repo: `~/www/llm-acp` (CodeCommit `arn:aws:codecommit:ap-east-1:646197533509:llm-acp`)
- `backend/Dockerfile`: oven/bun multi-stage with libssl
- `frontend/Dockerfile`: node:20-slim multi-stage, no lockfile
- `frontend/nginx.conf`: /api reverse proxy to backend
- `docker-compose.yml`: backend + frontend + named volume for SQLite

For a full local-deployment stack (Vite SPA + Bun/Elysia API + Postgres + nginx) with copy-paste docker-compose.yml + Dockerfiles + nginx.conf + entrypoint + verification commands, see `templates/full-local-stack.md` (proven in `~/www/crm-system`, 2026-06-05).
