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

## Reference

Working repo: `~/www/llm-acp` (CodeCommit `arn:aws:codecommit:ap-east-1:646197533509:llm-acp`)
- `backend/Dockerfile`: oven/bun multi-stage with libssl
- `frontend/Dockerfile`: node:20-slim multi-stage, no lockfile
- `frontend/nginx.conf`: /api reverse proxy to backend
- `docker-compose.yml`: backend + frontend + named volume for SQLite
