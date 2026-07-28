---
name: docker-multiarch-offline-handoff
description: Build multi-arch (linux/amd64 + linux/arm64) Docker images and hand them to a customer as tarball(s) without a registry. Use when the user needs x86+arm support AND cannot use Docker Hub/ECR/localhost registry. Covers the `docker save` / `docker load` round-trip with per-arch tag handling and the known pitfalls of trying to create local-only manifest lists.
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# Docker Multi-Arch Image Handoff (No Registry)

Use this skill when you need to ship Docker images to a customer/server that may be **x86_64 (amd64) OR aarch64 (arm64)**, **without a Docker registry** (no Docker Hub, no ECR, no localhost:5000). The customer is expected to `docker load` tarballs on their own machine.

**Supporting files in this skill:**
- `references/pm-system-v1.0.0-build-log.md` — session transcript with the 4 actual failure modes encountered and how they were diagnosed. Read this first if the build is failing.
- `templates/build-release.sh` — drop-in build script template (per-arch tars + CHECKSUMS)
- `templates/install.sh` — drop-in customer install script template (arch auto-detect + re-tag)

**Related gotchas captured from this session** (also useful for non-multi-arch Docker work):
- `oven/bun:1-alpine` ships **without `curl`** — use `wget` in compose healthchecks, or `apk add curl` in Dockerfile. Caught here, also seen in earlier crm-system work.
- `docker load` preserves the tag baked into the tar at build time. If your build tags `:v1.0.0-amd64`, the load creates that tag — NOT `:v1.0.0`. Always re-tag after load.
- Mac M-series cross-compile to `linux/amd64` via QEMU takes 5-10x longer than native. Use `background=true` + `notify_on_complete=true` for builds, don't try foreground 600s.

## Hard truth: manifest lists don't work without a registry

`docker manifest create` and `docker buildx imagetools create` both require the image to be reachable on a registry. Even local-only images fail with:

```
ERROR: pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
```

This was verified on Docker Desktop 28.x with no Docker Hub login. Adding `--insecure` to `docker manifest create` does NOT fix it — Docker's exporter needs to pull the manifest to merge it. Workarounds like OCI tarball output (`buildx --output type=oci`) require the customer to use `docker buildx imagetools load` (more complex UX).

**Therefore: ship per-arch tarballs.** One tar per (service, arch) tuple. The customer's install script picks the right tar based on `uname -m`.

## Output structure (per-arch)

```
deploy/dist/
├── pm-system-frontend-v1.0.0-amd64.tar
├── pm-system-frontend-v1.0.0-arm64.tar
├── pm-system-backend-v1.0.0-amd64.tar
├── pm-system-backend-v1.0.0-arm64.tar
├── CHECKSUMS.sha256
└── RELEASE-NOTES.md
```

Tagging convention: `<service>:<version>-<arch>` (e.g. `pm-system-backend:v1.0.0-amd64`). The `-arch` suffix on the tag is **required** — otherwise loading two different-arch tars into the same Docker daemon will silently overwrite each other (same tag → same image ID → second one wins).

## Build recipe (per-arch)

```bash
build_one() {
  local SERVICE="$1" PLATFORM="$2" SUFFIX="$3"
  local TAG="pm-system-${SERVICE}:${VERSION}-${SUFFIX}"
  docker buildx build \
    --platform "$PLATFORM" \
    --tag "$TAG" \
    --file "$PROJECT_ROOT/$SERVICE/Dockerfile" \
    --load \
    "$PROJECT_ROOT/$SERVICE"
  docker save -o "$DIST_DIR/pm-system-${SERVICE}-${VERSION}-${SUFFIX}.tar" "$TAG"
}

build_one frontend linux/amd64 amd64
build_one frontend linux/arm64 arm64
build_one backend  linux/amd64 amd64
build_one backend  linux/arm64 arm64
```

## Customer install — auto-detect arch

```bash
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64)        ARCH_DIR="amd64" ;;
  aarch64|arm64) ARCH_DIR="arm64" ;;
  *) echo "unsupported arch: $ARCH_RAW" >&2; exit 1 ;;
esac

FRONTEND_TAR="pm-system-frontend-${VERSION}-${ARCH_DIR}.tar"
BACKEND_TAR="pm-system-backend-${VERSION}-${ARCH_DIR}.tar"
docker load -i "$FRONTEND_TAR"
docker load -i "$BACKEND_TAR"
```

## CRITICAL pitfall — re-tag after load

`docker load` registers the image with the **tag that was baked into the tar manifest at build time**, which is `:v1.0.0-amd64` or `:v1.0.0-arm64`. It does NOT create a `:v1.0.0` tag automatically. If your `docker-compose.yml` references the arch-less tag (which it should, to be arch-neutral), the load will "succeed" but the image won't be findable by the compose.

**Always re-tag after load:**

```bash
docker tag "pm-system-frontend:${VERSION}-${ARCH_DIR}" "pm-system-frontend:${VERSION}"
docker tag "pm-system-backend:${VERSION}-${ARCH_DIR}"  "pm-system-backend:${VERSION}"
```

This was caught by a real QA Gate (red line 17) — a syntax-checked install.sh appeared to fail with "No such image" on first run. **Always smoke-test the load → re-tag → compose-up path in a sim directory before shipping.**

## Compose file must reference the arch-less tag

```yaml
services:
  backend:
    image: pm-system-backend:${VERSION}    # NOT :${VERSION}-${ARCH}
    # ...
```

## Pitfalls (read before running)

- **Mac M-series + QEMU is slow.** Cross-compile to `linux/amd64` from arm64 takes 5-10x longer than native. For backend images with large native binaries (Bun, Prisma client, anything with `node-gyp`), expect 5-15 minutes per arch on a Mac. Plan timeouts accordingly — 600s foreground is usually enough for one arch; use `background=true` + `notify_on_complete=true` for the full 4-image build.

- **`docker buildx build --platform amd64,arm64 --load` is impossible.** The Docker exporter does not support exporting multi-platform manifest lists via `--load`. You must build each platform separately with its own `--load`, then either (a) `docker save` each tag separately (per-arch recipe above), or (b) attempt `docker manifest create` (broken, see top of skill).

- **Frontend nginx-alpine images are platform-neutral in theory** but `--platform amd64,arm64 --load` still fails for the same exporter reason. Build per-arch anyway for consistency with the install script's per-arch tar discovery.

- **Don't push to docker.io by accident.** `docker buildx imagetools create` will default to pushing the resulting manifest list to docker.io with the user namespace, failing without a Docker Hub login. If you see `insufficient_scope` from `imagetools create`, you forgot to use per-arch tars.

- **Cleanup intermediate tags but KEEP the per-arch tags.** If you `docker rmi` the `:v1.0.0-amd64` tag after saving the tar, the tar still works (tar contains the layers, not a reference to the local tag). But re-running `install.sh` will need to re-load from tar, which is fine.

## Verification script (run before shipping)

```bash
# 1. Build all 4 tars (see build recipe above)
# 2. Simulate a customer machine in /tmp:
SIM="/tmp/multiarch-handoff-smoke-test"
rm -rf "$SIM" && mkdir -p "$SIM" && cd "$SIM"
cp /path/to/your/{frontend,backend}-*.tar .   # only the arch matching $(uname -m)
cp /path/to/your/docker-compose.yml .
cp /path/to/your/.env.example .env
docker compose up -d
sleep 10
curl -fsS http://localhost:80/api/health || echo "❌ backend not healthy"

# 3. Verify arch-less tag exists
docker image ls | grep "${VERSION}" | head -5
# Expected: pm-system-backend:v1.0.0   (no -arch suffix)
```

## When to consider a registry anyway

If the customer's network is unreliable, the tarballs are huge (multi-GB), or you need versioned updates, consider:
- **AWS ECR private** with the customer's IAM role (still requires source access for `docker push`)
- **GitHub Container Registry** free for public, cheap for private
- **`docker save | ssh` stream** to avoid the tar-file round-trip

For 1-3 customers on stable networks, per-arch tars remain the simplest path.
