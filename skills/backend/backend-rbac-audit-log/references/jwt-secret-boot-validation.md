# Boot-time JWT_SECRET hard-fail pattern (crm-system Day 14 P0-4)

> **Source**: extracted byte-identical from the previous
> `backend-rbac-audit-log` body, Step 15. The general rule
> (validate secrets at boot, never trust an unset/weak fallback)
> is framework-agnostic but the original was heavily crm-system
> specific — preserved here as the canonical template + smoke
> verification recipe.

**The trap**: Elysia + `@elysiajs/jwt` config usually looks like:

```ts
// ❌ SILENTLY BOOTS WITH A KNOWN-WEAK SECRET
.use(jwt({ name: 'jwt', secret: process.env.JWT_SECRET ?? 'dev-only-secret-please-change' }))
```

If the env var is missing in production, the API starts up with the literal fallback string. Anyone reading the public source repo can forge tokens. **There is no warning.**

**Fix**: hard-fail at the top of `index.ts`, BEFORE the Elysia instance is constructed:

```ts
// apps/api/src/index.ts — top of file, before any import that uses JWT
const JWT_SECRET=proces...
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required. Refusing to boot.');
}
if (JWT_SECRET.length < 32) {
  throw new Error(`JWT_SECRET must be at least 32 characters (got ${JWT_SECRET.length}). Generate one with: openssl rand -hex 32`);
}
if (process.env.NODE_ENV === 'production' && JWT_SECRET=*** 'dev-only-secret-please-change') {
  throw new Error('Refusing to boot: JWT_SECRET is set to the dev-only fallback in production.');
}

// ...later...
.use(jwt({ name: 'jwt', secret: JWT_SECRET }))    // ← no ?? fallback anymore
```

**Why 32 chars**: 32 random hex chars = 128 bits of entropy, which matches `aes-256-gcm` and is the minimum most JWT libraries consider "strong" for HS256. Below that, the secret is brute-forceable offline given any leaked token.

**Smoke verification recipe** (3 cases, must throw):

```bash
# 1. short secret
JWT_SECRET=*** /tmp/test-jwt.ts
# → error: JWT_SECRET must be at least 32 characters (got 5).

# 2. dev fallback in production
JWT_SECRET=dev-on...ange NODE_ENV=production bun /tmp/test-jwt.ts
# → error: JWT_SECRET must be at least 32 characters (got 29).
#    (length check fires first; both checks throw which is fine)

# 3. valid
JWT_SECRET=*** rand -hex 32> bun /tmp/test-jwt.ts
# → OK boot, secret length: 64 env: development
```

**Caveat — Bun `--env-file` shadowing**: if you test with `bun --env-file=.env`, the shell `JWT_SECRET=*** override` does NOT take precedence — Bun loads the .env file values as the floor. To test the failure path, write a temp env file with a short secret, then run `bun --env-file=/tmp/crm-env-weak src/index.ts`. This bit me in crm-system Day 14 — wasted 2-3 smoke attempts before isolating.

**Same pattern for other secrets**: `AI_CONFIG_ENCRYPTION_KEY` (must be 32-byte hex, `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`) and any `*_SECRET` / `*_KEY` env var deserves the same 3-condition check. Encapsulate as a `requireSecret(name, opts)` helper if you have more than 2:

```ts
function requireSecret(name: string, opts: { minLength?: number; forbidden?: string[] } = {}) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} environment variable is required.`);
  if (opts.minLength && value.length < opts.minLength) {
    throw new Error(`${name} must be at least ${opts.minLength} characters (got ${value.length}).`);
  }
  if (opts.forbidden?.includes(value) && process.env.NODE_ENV === 'production') {
    throw new Error(`${name} is set to a forbidden fallback in production.`);
  }
  return value;
}
```