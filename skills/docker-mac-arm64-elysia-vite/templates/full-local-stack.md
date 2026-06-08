# Full local stack: Vite SPA + Bun/Elysia API + Postgres + nginx

Known-good stack from `~/www/crm-system` (Day 3, 2026-06-05). Starting point for any new "Bun/Elysia API + Vite/React SPA + Postgres for local deployment" project. For VPS/NAS deployment, NOT for cloud (use CDK/Terraform for that).

## Tree

```
project-root/
├── docker-compose.yml          # base: postgres + api + web (+ opt-in adminer)
├── docker-compose.prod.yml     # override: stricter restart, no adminer
├── apps/
│   ├── api/
│   │   ├── Dockerfile          # multi-stage oven/bun:1.2
│   │   ├── docker-entrypoint.sh
│   │   └── src/index.ts
│   └── web/
│       ├── Dockerfile          # multi-stage Vite build -> nginx
│       ├── nginx.conf
│       └── src/
├── packages/
│   ├── db/                     # Prisma schema + client
│   └── ai/                     # optional: agent code
├── scripts/
│   ├── docker-dev.sh           # one-shot launcher
│   └── docker-reset.sh         # safe reset
├── .env                        # POSTGRES_*, JWT_SECRET, OPENAI_API_KEY
└── .env.example
```

## docker-compose.yml (base)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: crm-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-crm}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-crm_dev_password}
      POSTGRES_DB: ${POSTGRES_DB:-crm_system}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-crm} -d ${POSTGRES_DB:-crm_system}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    container_name: crm-api
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:***@postgres:5432/${POSTGRES_DB}?schema=public
      JWT_SECRET: ${JWT_SECRET:-change-me-in-production-please-use-long-random-string}
      OPENAI_API_KEY: ${OPENAI_API_KEY:-}
      NODE_ENV: production
      PORT: 3001
      HOST: 0.0.0.0
      SEED_DB: ${SEED_DB:-}
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:3001/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
    expose:
      - "3001"

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
    container_name: crm-web
    restart: unless-stopped
    depends_on:
      api:
        condition: service_started
    ports:
      - "${WEB_PORT:-80}:80"
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  adminer:
    image: adminer:4.8.1
    container_name: crm-adminer
    profiles: ["with-adminer"]
    ports:
      - "${ADMINER_PORT:-8080}:8080"
    depends_on:
      - postgres

volumes:
  pgdata:
    name: crm_pgdata
```

## apps/api/Dockerfile

```dockerfile
# Stage 1: install + prisma generate
FROM oven/bun:1.2 AS builder
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json bunfig.toml tsconfig.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
COPY packages/db/package.json ./packages/db/
COPY packages/ai/package.json ./packages/ai/
COPY packages/shared/package.json ./packages/shared/

RUN bun install --frozen-lockfile

COPY packages/db ./packages/db
COPY packages/ai ./packages/ai
COPY packages/shared ./packages/shared
COPY apps/api ./apps/api

WORKDIR /app/packages/db
RUN bunx prisma generate

WORKDIR /app

# Stage 2: runtime (no bundling — see skill Pitfall 7)
FROM oven/bun:1.2 AS runtime
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates curl dumb-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/api ./apps/api
COPY --from=builder /app/packages/db ./packages/db
COPY --from=builder /app/packages/ai ./packages/ai
COPY --from=builder /app/packages/shared ./packages/shared
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

COPY apps/api/docker-entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# USER bun  # see skill Pitfall 8 — keep as root for local

ENV NODE_ENV=production PORT=3001 HOST=0.0.0.0

EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS http://localhost:3001/health || exit 1

ENTRYPOINT ["dumb-init", "/usr/local/bin/entrypoint"]
CMD ["bun", "run", "apps/api/src/index.ts"]
```

## apps/api/docker-entrypoint.sh

```sh
#!/bin/sh
set -e

echo "==> [entrypoint] Running database migrations..."
if [ -z "$SKIP_MIGRATE" ]; then
  cd /app/packages/db
  bunx prisma migrate deploy
  cd /app
fi

if [ "$SEED_DB" = "true" ]; then
  echo "==> [entrypoint] SEED_DB=true, seeding..."
  cd /app/packages/db
  bun run prisma/seed.ts
  cd /app
fi

echo "==> [entrypoint] Starting API server..."
cd /app
exec "$@"
```

## apps/web/Dockerfile

```dockerfile
FROM oven/bun:1.2 AS builder
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json bunfig.toml tsconfig.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
COPY packages/db/package.json ./packages/db/
COPY packages/ai/package.json ./packages/ai/
COPY packages/shared/package.json ./packages/shared/

RUN bun install --frozen-lockfile

COPY packages/shared ./packages/shared
COPY apps/web ./apps/web

WORKDIR /app/apps/web
ARG VITE_API_BASE=/api
ENV VITE_API_BASE=$VITE_API_BASE
RUN bun run build

FROM nginx:1.27-alpine AS runtime
COPY --from=builder /app/apps/web/dist /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## apps/web/nginx.conf

```nginx
upstream crm_api {
    server api:3001;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript
               application/xml+rss application/atom+xml image/svg+xml;

    location = /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }

    location /api/ {
        rewrite ^/api/(.*)$ /$1 break;
        proxy_pass http://crm_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # SPA fallback — use named location to avoid rewrite cycle
    location / {
        try_files $uri $uri/ @spa;
    }
    location @spa {
        root /usr/share/nginx/html;
        try_files /index.html =404;
    }
}
```

## scripts/docker-dev.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-up}" in
  up|"")
    docker compose up -d --build
    docker compose logs -f
    ;;
  --seed)
    SEED_DB=true docker compose up -d --build
    for i in 1 2 3 4 5 6 7 8 9 10; do
      curl -fsS http://localhost/health >/dev/null 2>&1 && break
      sleep 2
    done
    echo "Stack up at http://localhost — admin@crm.local / admin123"
    ;;
  --reset)
    docker compose down -v
    ;;
  --logs)
    docker compose logs -f
    ;;
  --adminer)
    docker compose --profile with-adminer up -d --build
    ;;
  *) echo "Usage: $0 [up|--seed|--reset|--logs|--adminer]"; exit 1 ;;
esac
```

## Verification commands

After `docker compose up -d`:

```bash
# All three should be healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# Nginx health
curl -sS http://localhost/health         # -> ok

# API health through nginx reverse proxy
curl -sS http://localhost/api/health    # -> {"status":"ok","db":"connected"}

# Frontend SPA serves index.html
curl -sS http://localhost/ | head -1     # -> <!doctype html>

# Login + list a resource
python3 -c "
import json, urllib.request
r = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/auth/login',
  data=json.dumps({'email':'admin@crm.local','password':'admin123'}).encode(),
  headers={'Content-Type':'application/json'})).read())
token = r['token']
data = json.loads(urllib.request.urlopen(urllib.request.Request(
  'http://localhost/api/companies',
  headers={'Authorization': f'Bearer {token}'})).read())
print(f'companies: {data[\"total\"]}')"
```

## Common first-run pitfalls in this template

- **If `crm-api` keeps restarting** — `docker logs crm-api`. Common: schema path wrong (entrypoint assumes `/app/packages/db/prisma/schema.prisma`).
- **If `crm-web` returns 500 on `/`** — nginx SPA cycle. Check that `nginx.conf` uses the `@spa` named location pattern above, not `try_files $uri $uri/ /index.html`.
- **If you get `client is not defined` or `vn is not defined` in the API** — you tried to `bun build` instead of running source directly. Revert Dockerfile to the version above.
- **If `npm install` in web container fails with rolldown binding** — you COPY'd `package-lock.json` from Mac. Drop it; let container resolve fresh (see skill Pitfall 3).
