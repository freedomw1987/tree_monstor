# Dockerfile Multi-Stage: Reuse Builder's `node_modules` (Bun/Node)

> 補 `docker-multi-stage-dist-overwrite` SKILL 嘅同系列 — 嗰個 skill 集中喺
> 「stale dist/ overwrite」bug,呢個 reference 集中喺 「點樣 reuse builder
> stage 嘅 node_modules 落 runtime stage」嘅 modern pattern。

## 問題

Multi-stage Dockerfile 嘅 runtime stage 想要 「slim image」,有兩個
傳統做法但都係 anti-pattern:

```dockerfile
# ❌ Anti-pattern A: 兩個 stage 都 install
FROM oven/bun:1-alpine AS builder
RUN bun install --frozen-lockfile
RUN bunx prisma generate

FROM oven/bun:1-alpine
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production  # 重複 install,浪費 ~15s
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
```

問題:
1. **重複 install**(浪費 cold-build time ~15s)
2. **Layer 體積反升**(`--production` 個 install layer 526MB + builder
   stage 嘅 node_modules 都喺 image cache,等於 1GB+ 圖層)
3. **Dependency drift 風險**(`--production` 可能裝咗唔同版本嘅 dep)

```dockerfile
# ❌ Anti-pattern B: 用 npm ci prune
FROM node:20-alpine AS builder
RUN npm ci
RUN npm run build

FROM node:20-alpine
RUN npm ci --omit=dev      # 又 re-install
COPY --from=builder /app/dist ./dist
```

問題同上,加埋 `--omit=dev` 可能 drop 咗 runtime 需要嘅 binary
(e.g. Prisma CLI 喺 `dependencies` 而唔係 `devDependencies`)。

## Solution: Reuse builder's `node_modules` directly

```dockerfile
# ─── Stage 1: Builder ───────────────────────────────────────────────────────
FROM oven/bun:1-alpine AS builder

RUN apk add --no-cache poppler-utils  # runtime system deps, 同 base

WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile     # 全 install, 包括 dev deps
COPY prisma ./prisma
COPY src ./src
COPY tsconfig.json ./
RUN bunx prisma generate              # generated client 落 node_modules/@prisma

# ─── Stage 2: Runtime ───────────────────────────────────────────────────────
FROM oven/bun:1-alpine

RUN apk add --no-cache poppler-utils  # runtime system deps, 兩 stage 都要

WORKDIR /app

# Reuse builder's entire node_modules — no re-install, no duplicate.
# Prisma generated client 已經喺呢個 node_modules 入面, runtime 自動搵到。
COPY --from=builder /app/node_modules ./node_modules

# Schema (needed for `prisma migrate deploy` on container start)
COPY --from=builder /app/prisma ./prisma

# Source code (small layer — re-COPY 改 source 唔 touch node_modules)
COPY --from=builder /app/src ./src
COPY --from=builder /app/tsconfig.json ./

ENV NODE_ENV=production
ENV PORT=4000
EXPOSE 4000

CMD ["bun", "src/index.ts"]
```

## 關鍵設計決策

| 決策 | Why |
|------|-----|
| **Reuse 整個 `node_modules`** | Avoid re-install, avoid drift, single source of truth |
| **Runtime stage 用同一個 base image** (`oven/bun:1-alpine`) | 唔需要掟掉 builder stage 嘅 system deps;「slim」主要係 layer 而唔係 base image |
| **唔做 `--production` re-install** | Prisma CLI 喺 `dependencies` (非 `devDependencies`);drop 咗會撞 `prisma migrate deploy` fail |
| **Source code 喺獨立 layer** | 改 source re-COPY 504kB 而唔係 re-COPY 526MB node_modules → rebuild 飛快 |
| **Prisma schema copy** | Some Prisma client internals resolve schema path at runtime |

## Size reduction 期望

對於典型 Bun + Prisma + pdfjs/tesseract backend:

- **Before** (monolithic single-stage): ~670MB
- **After** (multi-stage with reuse): ~650MB
- **Reduction**: ~3% (20-30MB)

**點解唔更大?** 因為 bun 嘅 `node_modules` 真係比較細;
`pdfjs-dist` (35MB) + `tesseract.js` (1.6MB) + `@prisma/*` 全部
都係 production runtime 需要, build-time 唔可能 drop。

## Aggressive pruning 嘅取捨(同 David 2026-06-09 pm-system 確認過)

如果想推到 -15% 嘅 image size,需要:
- Prune `pdfjs-dist` (35MB) → 改用 `pdf2json` 4.x (更細)
- Prune `@prisma/engines` (15MB) → 改用 `@prisma/client` 的 slim build
- 拆 `@prisma/adapter-pg` 嘅 native binary

**但係**:
- 改 dep 要 re-test runtime behavior
- 改 Prisma build 設定有機會撞 driver adapter error
- 5-10MB 嘅 reduction vs 0.5-1 日嘅 audit effort,**唔值**

David 嘅 decision: **接受 22MB 嘅 safe reduction,放棄 aggressive pruning**。
Reason: 對內部 PM system 黎講,image size 唔係 critical path,
**rebuild speed** (改 src 唔 touch node_modules) 嘅 win 大過 size win。

## 守住 image size 改動

```bash
# 1. Build new image with descriptive tag
docker build -t pm-system-backend:sprint-N-multistage ./backend

# 2. Compare size
docker images pm-system-backend --format "{{.Repository}}:{{.Tag}}\t{{.Size}}"
# pm-system-backend:latest                673MB
# pm-system-backend:sprint-N-multistage   651MB

# 3. Verify runtime has all required artifacts
docker run --rm pm-system-backend:sprint-N-multistage ls /app
# 期望:node_modules  prisma  src  tsconfig.json
```

## Related pitfalls

- **`docker-multi-stage-dist-overwrite`** (sibling skill): 講解
  `.dockerignore` 嘅問題(stale dist/ overwrite)。本 reference 假設
  已經有 `.dockerignore` exclude `node_modules` 同 `dist`。
- **`docker-build-cache-debug`** (sibling skill): layer cache 失效嘅
  debug 流程。

## Reference implementation

`pm-system/backend/Dockerfile` (2026-06-09 Sprint 5 closure 採用呢個 pattern,
673MB → 651MB verified by `docker images`)。
