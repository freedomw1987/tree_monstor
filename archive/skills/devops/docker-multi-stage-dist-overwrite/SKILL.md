---
name: docker-multi-stage-dist-overwrite
description: Fix Docker multi-stage build where COPY . . overwrites fresh dist/ with stale host files due to missing .dockerignore
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Docker Multi-stage Build: dist/ Overwrite Bug

## Problem

When using Docker multi-stage builds with `npm run build` in the build stage, the `COPY . .` instruction copies the HOST's existing `dist/` folder into the container **after** `npm run build` has already run, overwriting the freshly built files with stale ones.

Symptoms:
- `npm run build` inside the container runs and reports success (✅ built in Xs)
- But the resulting Docker image contains OLD files (old timestamps, old code)
- The Vite/React bundle in the image does NOT contain the latest component
- The user sees no changes despite rebuilding

Root cause:
- No `.dockerignore` file existed, so `COPY . .` (which copies the entire build context) includes `dist/` from the host
- The `COPY . .` layer is cached, so `RUN npm run build` is skipped
- Stale `dist/` from the host context wins

## Solution

Create a `.dockerignore` in the project root (same directory as `docker-compose.yml` and Dockerfile):

```
node_modules
dist
.git
*.log
.env
.env.*
```

This prevents the host's `dist/` from being sent as part of the Docker build context, forcing the build stage to always run `npm run build` from scratch.

## Key Insight

`docker compose build --no-cache` does NOT help here because the cache that's being hit is the `COPY . .` layer (which copies the build context including stale `dist/`), NOT the `RUN npm run build` layer.

## Verification

After building, verify the image contains the correct code:

```bash
# Check file content
sudo docker run --rm <image_name> grep -l "ComponentName" /path/to/assets/*.js

# Check timestamps
sudo docker run --rm <image_name> ls -la /path/to/assets/
# Should show recent timestamps (not old ones from host)

# Check container is actually running new image
sudo docker ps
sudo docker inspect <container_name> --format '{{.Image}}'
# Image SHA should match the newly built image SHA
```

## Common Pitfall

Running `npm run build` locally BEFORE docker build does NOT help if the build context still includes the old `dist/`. The `.dockerignore` is the only real fix.

## Related references

- **`references/multi-stage-builder-reuse-node-modules.md`** — The modern pattern for slim runtime images: copy builder's `node_modules` directly into the runtime stage instead of re-installing with `--production`. Avoids duplicate install + layer bloat + Prisma dependency drift. Verified -22MB on <project> 2026-06-09.