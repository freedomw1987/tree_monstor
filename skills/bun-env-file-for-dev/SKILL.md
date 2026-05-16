---
name: bun-env-file-for-dev
description: Bun dev server requires --env-file flag to load .env; AWS SDK needs region env vars
---

# Bun .env File Loading — Dev Server

## Problem
Bun runtime does NOT automatically load `.env` files. Unlike Node.js (which needs `dotenv` or similar), Bun has built-in support via `--env-file` flag. Without it, `process.env.VARIABLE` will be undefined even if the variable exists in `.env`.

## Symptoms
- `process.env.SES_REGION` is `undefined` in Bun dev server despite `SES_REGION=us-east-1` in `.env`
- SDK/API calls fail silently or with obscure errors because credentials/region env vars are missing
- Node.js works fine with same `.env` file (uses local AWS credentials chain)

## Correct Startup Command
```bash
bun --env-file=.env src/index.ts
```

**NOT** just `bun src/index.ts` — that loads no `.env`.

## Why This Matters for AWS SDK
- AWS SDK v3 (`@aws-sdk/client-ses`, etc.) reads `process.env.AWS_REGION` or `process.env.SES_REGION` to know which region to use
- Without the env file loaded, these are undefined and SDK calls fail
- Local dev credentials come from `~/.aws/credentials` (AWS CLI config), not ECS task role

## Verification
After starting with correct flags:
```bash
curl -s http://localhost:3000/health
curl -s -X POST "http://localhost:3000/api/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
# Should return {"ok":true,...} not 500
```

Check logs for `[SES] Email sent: <MessageId>` — if you see `[SES] Error:` followed by region/credential error, the `.env` was likely not loaded.