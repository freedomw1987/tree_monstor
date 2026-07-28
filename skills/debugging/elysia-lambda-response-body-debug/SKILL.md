---
name: elysia-lambda-response-body-debug
description: Debug and fix empty response body when deploying Elysia.js to AWS Lambda
tags: [aws, lambda, elysia, debugging]
---


Last-verified: 2026-07-28
# Debug Elysia.js Lambda Response Body Empty

## Symptoms
- Lambda returns HTTP 200 with correct `content-type: application/json` header
- Response body is always empty (`content-length: 0`)
- Same Lambda handler code works when called directly with `app.handle()`
- CloudWatch shows no errors

## Root Cause
`response.arrayBuffer()` returns 0 bytes for Elysia's Response objects in Lambda's Node.js 18 runtime. The body stream appears valid but `arrayBuffer()` reads nothing.

**Why**: Elysia uses a custom Response body implementation (ReadableStream) where `arrayBuffer()` consumes the stream differently than `text()`. In some Node.js/lambda environments, the buffer read returns empty.

## Diagnosis Steps

1. **Local test** — confirm the issue exists locally:
```bash
node -e "
const { handler } = require('./dist/lambda.cjs');
handler({
  httpMethod: 'GET',
  path: '/health',
  headers: { host: 'lambda.empty' },
  body: null,
  isBase64Encoded: false,
  rawQueryString: ''
}).then(r => {
  console.log('body len:', r.body?.length ?? 0);
  console.log('isBase64:', r.isBase64Encoded);
});
"
```

2. **Isolate Elysia response** — test Elysia directly:
```bash
node -e "
import('elysia').then(({ Elysia }) => {
  const app = new Elysia().get('/health', () => ({ status: 'ok' }));
  return app.handle(new Request('https://test/health'));
}).then(r => {
  console.log('status:', r.status);
  return r.text();
}).then(t => console.log('text:', JSON.stringify(t), 'len:', t.length));
"
```

3. **Test arrayBuffer vs text**:
```bash
node -e "
app.handle(req).then(async r => {
  console.log('arrayBuffer len:', (await r.arrayBuffer()).byteLength);
  console.log('text len:', (await r.text()).length);
});
"
```

## Fix

Replace `response.arrayBuffer()` with `response.text()` in `src/lambda-handler.ts`:

```typescript
// ❌ Broken
const buffer = await response.arrayBuffer()
return {
  body: buffer.length > 0 ? Buffer.from(buffer).toString('base64') : '',
  isBase64Encoded: buffer.length > 0,
}

// ✅ Fixed
const text = await response.text()
return {
  body: text,
  isBase64Encoded: false,
}
```

## Why text() Works
`text()` reads the body as a string which is what API Gateway Lambda proxy integration expects. Base64 encoding was unnecessary complexity — API Gateway Lambda proxy accepts plain JSON strings directly.

## Additional Debugging Notes

### CDK-Lambda Permission Drift (403 AccessDeniedException)
**Symptom:** API Gateway returns 403 AccessDeniedException on test-invoke, 500 on real API call. Lambda direct invocation works fine (200 OK, 158KB response). `/health` and `/docs` work but newly created resources fail.

**Root cause:** CDK defines Lambda permission resources for API Gateway methods, but CloudFormation never creates them — resource ID in CDK differs from actual CloudFormation (drift). CDK account number typo caused the original CDK deploy failure, leaving CloudFormation stack with partial resources.

**Diagnosis:**
```bash
# Check Lambda permissions (SourceArn)
aws lambda get-policy --function-name <arn> --region ap-southeast-1 | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['Statement']) for p in d.get('Policy',{}).get('Statement',[])] if isinstance(d.get('Policy'),str) else print(d)"

# Test API Gateway → Lambda directly
aws apigateway test-invoke-method --rest-api-id <id> --resource-id <res-id> --http-method GET --path-with-query-string '/docs/json'
# 403 = Lambda permission missing/wrong
# 200 = working correctly

# Check CloudFormation stack drift
aws cloudformation detect-stack-drift --stack-name LemontreeApiStack --region ap-southeast-1
aws cloudformation describe-stack-resource-drifts --stack-name LemontreeApiStack --region ap-southeast-1
```

**Fix:** Re-deploy CDK stack to sync CloudFormation. CDK account must be correct (`631807311787`, NOT typo `631807311287`).

**Workaround:** Embed OpenAPI spec JSON directly into `/docs` HTML response via `@elysiajs/swagger`'s `content` parameter — eliminates need for separate `/docs/json` endpoint.

### API Gateway test-invoke vs Real API Error Code Mismatch
- `test-invoke-method` returns **403** for missing Lambda permissions
- Real API Gateway returns **500 Internal server error** for same condition
- Always use `test-invoke-method` for diagnosis — gives cleaner error messages

### API Gateway REST API Resources Outside CDK Management Fail
**Symptom:** Manually creating API Gateway resources (via AWS CLI console) and adding Lambda permissions still results in 403 AccessDeniedException.

**Root cause:** Not fully diagnosed — appears API Gateway has internal state/configuration that doesn't propagate Lambda permissions correctly for resources not managed by CDK.

**Fix:** Use CDK to manage ALL API Gateway resources and Lambda permissions. Don't mix manual and CDK-managed resources.

### Headers Constructor Bug in Lambda Environment
**Symptom:** `/health` returns 502 Bad Gateway. Lambda logs show: `TypeError: Cannot read properties of undefined (reading 'split')` at Headers constructor initialization.

**Root cause:** Elysia's Response object creates Headers incorrectly in Node 18 Lambda runtime — Headers object is empty or undefined when constructed.

**Fix:** Ensure the wrapper.js polyfill is applied AND use `response.text()` instead of `response.arrayBuffer()` for Lambda responses.

### Binary Response: arrayBuffer() Returns 0 bytes
**Problem:** `response.arrayBuffer()` returns 0 bytes for Elysia's Response objects in Lambda Node 18 runtime. Body stream appears valid but buffer read returns empty.

**Fix:** Use `response.text()` instead — API Gateway Lambda proxy integration accepts plain JSON strings directly. Base64 encoding is unnecessary complexity.

```typescript
// ✅ Fixed Lambda handler
const text = await response.text()
return {
  body: text,
  isBase64Encoded: false,
}
```

## Rebuild & Deploy
```bash
cd ~/projects/lemontree_v3
npx esbuild src/lambda-handler.ts --bundle --platform=node --target=node18 --outfile=dist/lambda.cjs --format=cjs
python3 -c "import zipfile; zf=zipfile.ZipFile('dist/lambda.zip','w',zipfile.ZIP_DEFLATED); zf.write('dist/wrapper.js'); zf.write('dist/lambda.cjs')"
AWS_DEFAULT_REGION=ap-southeast-1 aws lambda update-function-code --function-name <ARN> --zip-file fileb://dist/lambda.zip
```

## Verification
```bash
curl https://api.david-developer.com/health
# Should return: {"status":"ok","service":"lemontree-v3","version":"0.1.0"}
```
