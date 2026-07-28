# ⚠️ Pitfall — External spec assumption (Alpine `apk add` package, npm package, OS binary) not verified before committing (2026-06-16, pm-system Sprint 21, class-level)

**場景**:Plan-stage design doc, blog post, Stack Overflow answer, or even a previous project's Dockerfile specifies a package or binary name. Developer copies that name into a Dockerfile, `package.json`, or `apt-get install` line, commits, and pushes — **without verifying the package exists in the target repo**. Build fails only at the layer that needs the package, and only after the rest of the Dockerfile is built. Time wasted: ~30 seconds to a few minutes per failed build. Worse: the failure often surfaces post-merge (after a PR review) when the team tries to actually build the new image.

**真實 hit**(2026-06-16 pm-system Sprint 21):Dockerfile wrote `apk add poppler-utils antiword xls2csv catdoc` based on a plan-stage design doc. `antiword` exists in Alpine v3.22 official repo, but **`catdoc` and `xls2csv` do not**. The first `docker build` failed at layer 2:

```
ERROR: unable to select packages:
  catdoc (no such package):
    required by: world[catdoc]
  xls2csv (no such package):
    required by: world[xls2csv]
```

Sprint 21 was already merged (commit `46323bf`) when the failure surfaced in the user's dev environment. Required a hotfix commit on top of merged work + a `Hotfix US-21.1.1` audit trail entry in the retro doc.

**Why this trap is hard to spot before commit**:
- The packages are real and well-known (`catdoc` is a classic `.doc` reader, `xls2csv` is the standard Perl script). They DO exist in Debian/Ubuntu repos, in Homebrew, and in older Alpine versions (pre-v3.18).
- Plan docs / blog posts / Stack Overflow answers quote them without version-checking.
- The base image `oven/bun:1-alpine` ships with **no man pages and no docs** for what Alpine version it tracks, so you can't `cat /etc/alpine-release` to guess package availability.
- Tsc / lint / unit tests all pass before the docker build attempt — the failure is in the deployment layer, not the code layer.

**5-second verification recipe**(no build needed — use the base image's package manager):

```bash
# Alpine (oven/bun:1-alpine, alpine:3.x, etc.)
docker run --rm <base-image> sh -c "apk search 2>&1 | grep -E '^(<pkg1>-|<pkg2>-|<pkg3>-)' | head -10"

# Debian (oven/bun:1.2, node:20-slim, etc.)
docker run --rm <base-image> sh -c "apt-cache search <pkg1> <pkg2> | head -10"

# npm (no docker needed)
npm view <pkg-name> version 2>&1 | head -3   # exists? + latest version
npm view <pkg-name> deprecated 2>&1          # 0 result = OK
```

If a package isn't in the output, **it's not in the repo**. Find a real alternative (`apk search <keyword>` returns the full candidate list). For Alpine specifically, the full repo index is at `https://pkgs.alpinelinux.org/packages?name=<pkg>` — usable from the host without a docker pull.

**Real alternative-finding workflow**(2026-06-16 pm-system Sprint 21 case):

| Wanted | Verified absent | Real alternative found via `apk search` |
|--------|-----------------|-----------------------------------------|
| `catdoc` (`.doc` fallback) | confirmed no such package | `wv` (provides `wvText`) |
| `xls2csv` (`.xls` parser) | confirmed no such package | `gnumeric` (provides `ssconvert`) |
| `antiword` (`.doc` parser) | exists, no swap needed | — |

So the working `apk add` is `poppler-utils antiword wv gnumeric`. The fix also requires updating the source code in `src/` that calls the binary (e.g. swap `catdoc` command → `wvText`, update error messages, update tests).

**Cross-stack prevention**(4 layers, do all):

1. **Before writing `Dockerfile` / `package.json` / `requirements.txt`** — run the 5-second verify recipe above. **If you skip verify, you accept the build-fail risk**.

2. **Before merging a PR that adds a new package or external binary** — reviewer (or self-review) runs the verify command for each added line. CI doesn't typically run `docker build` on every PR, so the check is human.

3. **In retro / ADR docs** — always include a "Why NOT X" section explaining the alternatives considered and why they were rejected. If a later hotfix swaps a package, the retro entry becomes the audit trail.

4. **In the source code that calls the binary** — if the binary is swapped, update the call site AND the error messages AND the tests. The build will pass with the old call site if the binary is still on PATH (e.g. ssconvert is in gnumeric, but if the old code calls `xls2csv`, the error is at runtime, not build time).

**Detection signal checklist**(出現以下就要 audit 個 codebase 嘅 external spec assumption):

- [ ] 任何 `RUN apk add ...` / `apt-get install ...` line in Dockerfile that lists 2+ packages
- [ ] 任何 `package.json` entry with a `latest` version specifier (drift over time)
- [ ] 任何 `npm install <pkg>` command in a setup script (not version-pinned)
- [ ] 任何 `subprocess.run(['<binary>', ...])` / `Bun.$\`<binary>\`` call that wasn't verified with `which <binary>` in the target image
- [ ] 任何 setup script that calls `pip install <pkg>` / `gem install <pkg>` without `--no-deps` and version pin
- [ ] 任何 Dockerfile line that copies a binary from the host (`COPY ./my-binary /usr/local/bin/`) without verifying the host binary is built for the target arch

**5-step fix workflow** when build fails on missing external package:

1. Note which package(s) failed in the error log.
2. `docker run --rm <base> sh -c "apk search <keyword>"` for the closest matching package name (or `apt-cache search`, or `npm view`).
3. If a real alternative exists in the official repo, swap it in AND update the corresponding code in `src/` that calls the binary. Update error messages. Update tests. Update the retro / ADR "Why NOT X" section with the swap reason.
4. If no alternative exists, fall back to pure JS / pure language (npm, pypi, crates.io, etc.) — but verify it's CVE-clean first via `npm audit` / `pip-audit` / `cargo audit`.
5. **Always patch the retro / ADR doc** with the spec error audit trail. Future agents reading the merged code need to know which package was swapped and why, even if the swap was 1-line and obvious in the diff.

**Related**:
- `docker-mac-arm64-elysia-vite` Pitfall 12 (added 2026-06-16) — covers the Alpine `apk add` case end-to-end with copy-pasteable verify recipe
- `dependency-cve-audit` — covers the npm CVE side (SheetJS xlsx 0.18.5 stuck with CVE-2023-30533)
- `pm-system-deployment` Sprint 21 section — documents the real `apk add` line that's been verified against Alpine v3.22

**Lesson**:**An external package name in a config file is a spec assumption, not a verified fact**. Always run `apk search` / `apt-cache search` / `npm view` against the actual target image before writing the line. 5 seconds of verification saves a 30-second failed build + a hotfix commit + a confused user. **If you find yourself writing `RUN apk add <pkg-name>` and your source is a plan doc / blog post / memory, stop and verify first** — that's the exact failure mode of the 2026-06-16 Sprint 21 hotfix.
