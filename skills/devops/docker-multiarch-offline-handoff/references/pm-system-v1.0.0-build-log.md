# Reference: PM-System v1.0.0 Client Release Build Log

**Project:** ~/www/pm-system (Bun + Elysia + Prisma 7 + Postgres 15 frontend, Vite + React + nginx-alpine frontend)
**Date:** 2026-06-09
**Context:** David needed to ship a Docker-based product to a customer without source code, supporting both x86_64 and aarch64. No registry available.

## Decision matrix (3 options considered)

| Option | Verdict |
|--------|---------|
| A. Single multi-arch tarball via manifest list | **REJECTED** — `docker manifest create` and `docker buildx imagetools create` both fail with `pull access denied` on local-only images. No working CLI path without a registry. |
| B. Per-arch tarballs, install.sh auto-detects via `uname -m` | **CHOSEN** — works, customer experience is still 1-command. |
| C. Localhost:5000 registry on dev machine | Rejected — adds setup complexity, pollutes the customer package, not needed. |

## The 3 failures encountered (in order)

### Failure 1: `--load` doesn't support multi-platform
```
docker buildx build --platform linux/amd64,linux/arm64 --load --tag X .
# ERROR: failed to build: docker exporter does not currently support exporting manifest lists
```
**Fix:** Build each platform separately with its own `--load`, do not pass `--platform` with multiple values.

### Failure 2: `docker manifest create` on local images
```
docker manifest create pm-system-frontend:v1.0.0 --amend ... --amend ...
# ERROR: pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
```
**Fix:** Don't use `docker manifest create` at all when there's no registry. Skip to per-arch tars.

### Failure 3: `docker buildx imagetools create` on local images
```
docker buildx imagetools create --tag pm-system-frontend:v1.0.0 ...-amd64 ...-arm64
# Same insufficient_scope error
```
**Fix:** Same as #2 — `imagetools create` tries to push the manifest list to a registry. Skip it.

## The post-load re-tag bug (caught by QA Gate red line 17)

After `docker load -i pm-system-frontend-v1.0.0-arm64.tar`:
```
docker image ls
REPOSITORY              TAG                IMAGE ID
pm-system-frontend      v1.0.0-arm64      abc123
```
No `:v1.0.0` tag exists. If `docker-compose.yml` says `image: pm-system-frontend:v1.0.0`, the compose-up will fail with "No such image" even though the tar loaded successfully.

**Fix (added to install.sh):**
```bash
docker tag "pm-system-frontend:${VERSION}-${ARCH_DIR}" "pm-system-frontend:${VERSION}"
docker tag "pm-system-backend:${VERSION}-${ARCH_DIR}"  "pm-system-backend:${VERSION}"
```

## The healthcheck curl bug

`oven/bun:1-alpine` base image does NOT ship with `curl`. The compose file initially had:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/api/projects >/dev/null || exit 1"]
```
Result: `healthcheck: /bin/sh: curl: not found`, container marked unhealthy forever, even though the app inside was running fine.

**Fix:** Use `wget` (alpine busybox ships with it by default):
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:4000/api/projects >/dev/null || exit 1"]
```

Alternative: install curl in Dockerfile with `RUN apk add --no-cache curl`. But wget is simpler and saves image size.

## The schema drift issue (out of scope but flagged)

`prisma/schema.prisma` has `model Role` and `model Permission` and `model LLMConfig`, but `prisma/migrations/20260521053128_init/migration.sql` does NOT contain CREATE TABLE statements for them. Dev DB was synced via `prisma db push` (push-to-schema, not migration). When customer runs `prisma migrate deploy` for the first time, the migration runs but the tables don't exist → `PrismaClientKnownRequestError: Table 'public.Role' does not exist`.

**This is a project-level bug, not a release-script bug.** Flag for David's next sprint: add a new migration `20260609000000_missing_role_permission_llmconfig` with the missing CREATE TABLE statements.

## Final tar sizes (Mac M-series, QEMU cross-compile)

| Tar | Size | Build time |
|-----|------|------------|
| frontend-amd64 | 63M | ~30s (cached layers reused) |
| frontend-arm64 | 62M | ~30s |
| backend-amd64 | 642M | ~45s (Bun + Prisma engine, native) |
| backend-arm64 | 634M | ~3min (QEMU emulated x86→arm64 build) |
| **Total** | **~1.4 GB** | **~4.5 min end-to-end** |

## Lessons that fed back into the skill

1. **The "no-registry multi-arch" problem is unsolvable with stock Docker tooling.** Anyone who tells you otherwise is selling you a registry.
2. **Per-arch tars + `uname -m` auto-detect is the only sane path** when you control the build machine AND the install script.
3. **Always re-tag after `docker load`** — the tag baked into the tar is sacred.
4. **`oven/bun:1-alpine` healthcheck needs wget, not curl** — this should be a one-liner in every compose file that uses bun.
5. **QA Gate red line 17 (real smoke test) caught 3 bugs in this session** (re-tag, curl, schema). Syntax checks + bash -n are not enough. Always run install.sh end-to-end in /tmp before shipping.
