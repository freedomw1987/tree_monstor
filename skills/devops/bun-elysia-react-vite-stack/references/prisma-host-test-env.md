# Prisma + Bun host test env pitfall (Docker rescues)

> **Class:** Bun + Prisma full-stack project (Elysia / Express / Hono backend,
> Docker Compose dev / CI runner)
> **Source of truth:** 2026-06-07 crm-system Day 6 + 2026-06-08 pm-system
> Sprint 1 retro ACT-10 (David 實機 trigger)
> **Severity:** 🟡 P2 — DX friction, NOT ship-blocking (Docker saves you)

---

## Symptom

```bash
$ cd backend && bun test
# Some test file (e.g. tasks.test.ts) fails:
error: Cannot find module '.prisma/client/default'
  from '.../node_modules/@prisma/client/default.js'
 45 tests across 4 files
 42 pass
 1 fail
 1 error
```

Same test file passes in Docker:

```bash
$ docker compose exec backend bun test src/routes/tasks.test.ts
 3 pass, 0 fail, 3 expect() calls [1244ms]
```

**Why:** The test file (or anything that imports `@prisma/client`) needs
`node_modules/.prisma/client/default.js`. `bun install` on the host does
**NOT** run `prisma generate`. Your project's Dockerfile does (typically
after `bun install` / `bun install --production`, then `bunx prisma generate`
or a `RUN npx prisma generate` step inside the build).

So:
- Docker image → has the generated client → tests pass.
- Host machine → no generated client → tests that touch Prisma fail.

---

## Fix (1 line of `package.json`)

Add a `pretest` hook to `backend/package.json`:

```json
"scripts": {
  "test": "bun test",
  "pretest": "bunx prisma generate"
}
```

Now `bun run test` (or `bun test` if invoked via `npm run`/`bun run`/CI
runner that respects lifecycle scripts) regenerates the client first, then
runs the test suite.

**Verified on pm-system 2026-06-08:**

```bash
$ rm node_modules/.prisma/client/default.js   # simulate fresh
$ bun run test
  45 pass, 0 fail, 80 expect() calls [750ms]
$ ls node_modules/.prisma/client/default.js   # re-generated
```

---

## Why both `test` and `pretest`?

If your `package.json` only has `"test": "bun test"` defined by default
(no `test` key at all), running `bun test` directly bypasses the
`pretest` hook. **You need both** to make the hook fire reliably across:

| Invoker | Fires `pretest`? |
|---------|------------------|
| `bun test` (direct) | ❌ No — bypasses npm-style scripts |
| `bun run test` | ✅ Yes |
| `npm test` | ✅ Yes |
| `npm run test` | ✅ Yes |
| `yarn test` | ✅ Yes |
| CI runners (GitHub Actions `npm test`, etc.) | ✅ Yes |

If you only want one command to remember, use `bun run test`.

**Alternative: make the `bun test` direct path work too.**
Add an alias in your `~/.zshrc` or shell rc:

```sh
alias bt='bun run test'
```

Or commit a `bin/test` script:

```bash
#!/usr/bin/env bash
set -e
bunx prisma generate
exec bun test
```

(`chmod +x` it, then `git add bin/test && git commit`. CI runs `./bin/test`.)

---

## Don't confuse with the Prisma 7 SQLite problem

The `prisma-sqlite-bun-setup` skill documents a **different** problem
where Prisma 7 + SQLite + Bun's experimental SQLite driver has
`url = env(...)` removed from `schema.prisma` and requires
`prisma.config.ts` + driver adapter mode. That one is Prisma-version
specific and is the reason pm-system / crm-system / umac-ai all pin
**Prisma 5.22.0** for SQLite projects.

**This host-test-env pitfall is orthogonal** — it hits on both Prisma 5
and Prisma 7, and on both SQLite and Postgres. The fix is the same
`pretest: bunx prisma generate` hook.

---

## When the hook is not enough

If the test failure is **inside the test body** (e.g. `prisma.user.findUnique`
throws something other than `Cannot find module`), the hook fired but
something else is wrong. Read the full stack:

| Stack fragment | Likely cause |
|----------------|--------------|
| `Cannot find module '.prisma/client/default'` | This pitfall — fix with `pretest` |
| `Cannot find module '@prisma/client'` | `bun install` not run / `package.json` not in `backend/` |
| `prisma.user.findUnique` throws `TypeError: undefined` | DB not seeded / `DATABASE_URL` wrong |
| `Migration drift: P3009` | Schema changed without `migrate dev`; see `prisma-migrate-private-rds` |

---

## Recording in `docs/TECH-DEBT.md`

When you ship the fix, add a TD-NNN entry like this (matches pm-system's
TD-012 from 2026-06-08):

```markdown
### 🟡 TD-012: Host 跑 `bun test` 撞 `tasks.test.ts` fail(環境問題,非 code)

- **發現日期**: 2026-06-08 (Sprint 1 retro 2026-06-08 ACT-10)
- **發現來源**: Sprint 1 retro 文件, David 2026-06-08 QA review 時觸發
- **症狀**: `cd backend && bun test` host 跑出 `42 pass / 1 fail / 1 err` —
  `Cannot find module '.prisma/client/default' from '.../node_modules/@prisma/client/default.js'`
- **根因**: Host `bun install` 唔跑 `prisma generate`, 所以
  `node_modules/.prisma/client/default.js` 缺失。Docker container 內 Dockerfile
  `bun install --production` 後有 `bunx prisma generate`, 所以 docker 內 3 個
  `tasks.test.ts` cases 照跑全綠
- **影響**:
  - 🟡 **本地 dev friction** — 新 onboard 同事 / CI 跑 host test 會撞 fail
  - 🟢 **唔影響 ship** — Docker 內 full test 套件 45+13 全綠
  - 🟢 **唔影響 production** — runtime client 由 image bake 步驟 generate 好
- **修復成本**: 0.01 日 (2 行 `package.json` 改動)
- **業務影響**: Low — 純 DX 問題
- **建議**: P2
- **2026-06-08 進展**: ✅ **已修** — `backend/package.json` 加 `"test": "bun test"` +
  `"pretest": "bunx prisma generate"` hook, host 跑 `bun run test` 即自動
  generate client → 45 pass / 0 fail (commit `03f59c2`)
- **守到**:
  - `cd backend && bun run test` → 45 pass / 0 fail / 80 expect() calls [750ms]
  - `docker compose exec backend bun test` → 45 pass / 0 fail
  - `cd e2e && npx playwright test` → 13/13 E2E pass
```

Note the **影響** field is split three ways (dev friction / ship / prod) —
this is the right shape for env-only fixes. `tech-debt-register` skill's
default P0-N entry format collapses everything into "Why" + "Fix"; for
env bootstrap problems the tri-split is clearer.

---

## Checklist when you see this in a new project

```
[ ] Read backend/package.json — is `"test"` script defined?
[ ] If not, add `"test": "bun test"` AND `"pretest": "bunx prisma generate"`
[ ] Verify: rm node_modules/.prisma/client/default.js && bun run test
[ ] Confirm: ls node_modules/.prisma/client/default.js
[ ] If using Elysia 1.2 + bun build, ALSO check: are tests running
    against the source (bun test src/...) not the dist? (See
    crm-system memory — `--minify` + Elysia compile?.() breaks
    code-gen; just `bun run src/index.ts` for runtime.)
[ ] Add TD-NNN entry to docs/TECH-DEBT.md with the tri-split 影響
[ ] Update retro / change log
```

---

## Cross-references

- `prisma-sqlite-bun-setup` — the Prisma 7 + SQLite version-specific problem
  (different fix, different scope)
- `prisma-migrate-private-rds` — if the failure is `P3009 drift` not
  `Cannot find module`, the hook won't help; need a migration deploy
- `docker-port-forward-shadow-debug` — if host tests fail because the
  test process is connecting to the wrong DB port (e.g. host 5432 vs
  container 5433), this is a different class of problem
- `tech-debt-register` skill — for the TD-NNN entry format
- `interruption-recovery` skill — for the recovery pattern when this
  bites mid-sprint
