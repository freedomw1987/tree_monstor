/**
 * requireSecret — boot-time validator for sensitive env vars.
 *
 * Use at the top of apps/api/src/index.ts (or wherever the runtime
 * is constructed) to hard-fail on missing / weak / dev-only secrets.
 *
 * Pairs with `backend-rbac-audit-log` Step 15.
 *
 * Day 14, crm-system 2026-06-07. Reused for JWT_SECRET,
 * AI_CONFIG_ENCRYPTION_KEY, and any future *_SECRET / *_KEY env var.
 */

export interface RequireSecretOptions {
  /** Minimum character length (e.g. 32 for HS256 JWT secrets). */
  minLength?: number;
  /** Values that are forbidden in production (e.g. the dev-only fallback). */
  forbidden?: string[];
  /** Format validator (e.g. hex regex for `AI_CONFIG_ENCRYPTION_KEY`). */
  format?: (value: string) => boolean;
  /** Error message prefix. */
  label?: string;
}

export function requireSecret(name: string, opts: RequireSecretOptions = {}): string {
  const value = process.env[name];
  const label = opts.label ?? name;

  if (!value) {
    throw new Error(
      `${label} environment variable is required. Refusing to boot. ` +
      `Generate one with: openssl rand -hex 32`
    );
  }

  if (opts.minLength !== undefined && value.length < opts.minLength) {
    throw new Error(
      `${label} must be at least ${opts.minLength} characters (got ${value.length}). ` +
      `Generate one with: openssl rand -hex 32`
    );
  }

  if (opts.format && !opts.format(value)) {
    throw new Error(`${label} is not in the expected format. Check the README for the format spec.`);
  }

  if (
    process.env.NODE_ENV === 'production' &&
    opts.forbidden &&
    opts.forbidden.includes(value)
  ) {
    throw new Error(
      `Refusing to boot: ${label} is set to a forbidden fallback in production. ` +
      `Generate a real secret with: openssl rand -hex 32`
    );
  }

  return value;
}

// ---------------------------------------------------------------------------
// Day 14 usage in crm-system apps/api/src/index.ts:
//
//   import { requireSecret } from './lib/require-secret';
//
//   const JWT_SECRET=requireSecret('JWT_SECRET', {
//     minLength: 32,
//     forbidden: ['dev-only-secret-please-change'],
//   });
//
//   const AI_CONFIG_ENCRYPTION_KEY = requireSecret('AI_CONFIG_ENCRYPTION_KEY', {
//     minLength: 64,                                  // 32 bytes hex-encoded = 64 chars
//     format: (v) => /^[0-9a-f]{64}$/i.test(v),       // hex
//   });
//
//   // ...then later:
//   .use(jwt({ name: 'jwt', secret: JWT_SECRET }))
//
// Smoke verification (run from /tmp):
//
//   echo 'const { requireSecret } = require("'$(pwd)'/apps/api/src/lib/require-secret.ts");' > /tmp/test.ts
//   cat apps/api/src/lib/require-secret.ts >> /tmp/test.ts
//   cat >> /tmp/test.ts <<'EOF'
//   try { requireSecret('JWT_SECRET', { minLength: 32 }); }
//   catch (e) { console.log('OK throw:', e.message); }
//   EOF
//   JWT_SECRET=*** /tmp/test.ts
//   # → OK throw: JWT_SECRET must be at least 32 characters (got 5).
//
// Caveat: bun --env-file=.env shadows shell-set env vars. To test the
// failure path, write a temp env file with a short value and run
// `bun --env-file=/tmp/weak.env src/index.ts`.
// ---------------------------------------------------------------------------
