---
name: elysia-aws-lambda-deploy
description: Deploy Elysia.js (Bun-first framework) to AWS Lambda Node.js runtime — bundler config, handler resolution, CDK runtime mismatches, crypto polyfill, API Gateway 500 debugging, and ACM DNS validation gotchas
tags:
  - aws
  - lambda
  - elysia
  - bun
  - api-gateway
  - cdk
---


Last-verified: 2026-07-28
# Elysia.js on AWS Lambda Deployment

## Context

Deploying Elysia.js (Bun-first framework) to AWS Lambda involves several non-obvious compatibility issues. The Lambda runtime is Node.js (not Bun), so bundled code must be CommonJS-compatible. Key pitfalls: Bun build outputs Bun-specific code, handler resolution depends on zip file structure, and CDK runtime settings can drift from actual Lambda config.

**Before debugging Lambda 500 errors:** Always check CloudWatch logs first with:
```bash
aws logs filter-log-events --log-group-name "/aws/lambda/<function-name>" --start-time $(date -d '2 minutes ago' +%s000) --region <region>
```

## Build Tool: esbuild or Bun (both work)

### Bun Build (Verified Working in lemontree_v3)

```bash
bun build src/lambda-handler.ts \
  --target=node \
  --outfile=dist/handler.cjs \
  --format=cjs
```

After bun build, **patch the output** to fix `crypto` global availability in Node.js 18:
```python
# Patch: add var crypto = require("crypto") after "use strict";
import re
with open('dist/handler.cjs', 'r') as f:
    content = f.read()
if 'var crypto = require("crypto")' not in content:
    content = content.replace('"use strict";', '"use strict";\nvar crypto = require("crypto");', 1)
    with open('dist/handler.cjs', 'w') as f:
        f.write(content)
```

### esbuild (Alternative)

```bash
npx esbuild src/lambda-handler.ts \
  --platform=node \
  --target=node18 \
  --format=cjs \
  --bundle \
  --outfile=dist/index.js
```

**Avoid** `--define:import.meta.require=require` — this can cause `ReferenceError: crypto is not defined` because it interferes with module-level crypto usage.

## Lambda Handler Resolution

### How Node.js Lambda Resolves Handlers

Lambda's `index.mjs` does `require(<handler_module>)`. The handler string format matters:

| Handler String | Resolved As | Notes |
|---------------|-------------|-------|
| `index.handler` | zip root `index.js` → `.handler` export | ✅ Standard |
| `wrapper.handler` | zip root `wrapper.js` → `.handler` export | Requires wrapper.js in zip root |
| `lambda.handler` | tries to `require('lambda')` | ❌ Wrong — treats as npm module name |

### Zip File Structure

**Always put the entry point file at the ZIP ROOT (no directory prefix):**

```bash
# ✅ Correct — handler.js at zip root
python3 -c "
import zipfile
with zipfile.ZipFile('dist/lambda.zip', 'w') as z:
    z.write('dist/handler.js', 'handler.js')  # 2nd arg = archive name (no 'dist/' prefix)
"

# ❌ Wrong — dist/handler.js in zip (will fail with 'Cannot find module')
python3 -c "
import zipfile
with zipfile.ZipFile('dist/lambda.zip', 'w') as z:
    z.write('dist/handler.js')  # Adds as 'dist/handler.js'
"
```

### Deploy Commands

```bash
# 1. Build with esbuild
cd ~/projects/lemontree_v3
npx esbuild src/lambda-handler.ts \
  --platform=node \
  --target=node18 \
  --format=cjs \
  --bundle \
  --outfile=dist/index.js

# 2. Package (index.js at zip root)
python3 -c "
import zipfile
with zipfile.ZipFile('dist/lambda.zip', 'w') as z:
    z.write('dist/index.js', 'index.js')
"

# 3. Upload code
aws lambda update-function-code \
  --function-name <arn> \
  --zip-file fileb://dist/lambda.zip \
  --region ap-southeast-1

# 4. Set handler (file name without extension + .handler)
aws lambda update-function-configuration \
  --function-name <arn> \
  --handler index.handler \
  --region ap-southeast-1
```

## Lambda Handler Template

```typescript
// src/lambda-handler.ts
import { Elysia } from 'elysia'
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'
// ... your imports

const app = new Elysia()
  .get('/health', () => ({ status: 'ok' }))
  .group('/api', (app) => app.use(authRoutes) /* ... */)

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const isBase64 = event.isBase64Encoded
  const body = isBase64 ? Buffer.from(event.body ?? '', 'base64') : event.body

  const path = event.path + (event.rawQueryString ? `?${event.rawQueryString}` : '')
  const response = await app.handle(
    new Request(`https://lambda.empty${path}`, {
      method: event.httpMethod,
      headers: event.headers as Record<string, string>,
      body,
    })
  )

  const text = await response.text()
  return {
    statusCode: response.status,
    headers: Object.fromEntries(response.headers.entries()),
    body: text,
    isBase64Encoded: false,
  }
}
```

**Important:** Use `response.text()` NOT `response.arrayBuffer()` — Elysia's Response body implementation causes `arrayBuffer()` to return 0 bytes in Lambda Node.js runtime.

## CDK Stack: Critical Configuration

### Common CDK Mistakes

```typescript
// ❌ Wrong runtime
runtime: aws_lambda.Runtime.NODEJS_20_X,  // CDK says NODEJS_20_X but actual Lambda is nodejs18.x

// ✅ Match actual Lambda runtime
runtime: aws_lambda.Runtime.NODEJS_18_X,

// ❌ Handler references non-existent file
handler: 'wrapper.handler',  // wrapper.js may not exist or be at zip root

// ✅ Handler matches zip entry point
handler: 'index.handler',  // zip root has index.js
```

### CDK Stack Template (Verified Working)

```typescript
// cdk/lib/stack.ts
import { Stack, Duration, aws_lambda, aws_apigateway, aws_route53, aws_certificatemanager, CfnOutput } from 'aws-cdk-lib'

export class LemontreeApiStack extends Stack {
  constructor(scope: Construct, id: string, props: LemontreeApiStackProps) {
    super(scope, id, props)

    const lambdaFn = new aws_lambda.Function(this, 'LemontreeApiLambda', {
      runtime: aws_lambda.Runtime.NODEJS_20_X,  // or NODEJS_18_X — must match actual Lambda
      handler: 'index.handler',                  // zip root has index.js
      code: aws_lambda.Code.fromAsset(props.lambdaBundlePath),
      memorySize: 512,
      timeout: Duration.seconds(30),
    })

    // Rest API (NOT HTTP API — no binary support)
    const api = new aws_apigateway.RestApi(this, 'LemontreeApi', {
      binaryMediaTypes: ['*/*'],
      endpointTypes: [aws_apigateway.EndpointType.REGIONAL],
    })

    // /health
    const health = api.root.addResource('health')
    health.addMethod('GET', new aws_apigateway.LambdaIntegration(lambdaFn))

    // /docs (Swagger UI)
    const docs = api.root.addResource('docs')
    docs.addMethod('GET', new aws_apigateway.LambdaIntegration(lambdaFn))

    // /docs/json (OpenAPI spec)
    const docsJson = docs.addResource('json')
    docsJson.addMethod('GET', new aws_apigateway.LambdaIntegration(lambdaFn))

    // /api/* proxy
    const apiProxy = api.root.addResource('api')
    apiProxy.addProxy({
      defaultIntegration: new aws_apigateway.LambdaIntegration(lambdaFn),
      anyMethod: true,
    })

    // Custom domain + ACM cert
    const cert = new aws_certificatemanager.Certificate(this, 'ApiCert', {
      domainName: props.domainName,
      validation: aws_certificatemanager.CertificateValidation.fromDns(),
    })

    const apiDomain = new aws_apigateway.DomainName(this, 'ApiDomain', {
      domainName: props.domainName,
      certificate: cert,
      endpointType: aws_apigateway.EndpointType.REGIONAL,
    })

    apiDomain.addBasePathMapping(api, { basePath: '' })

    new aws_route53.ARecord(this, 'ApiDns', {
      zone,
      recordName: props.domainName,
      target: aws_route53.RecordTarget.fromAlias({
        targetType: 'api-gateway-domain',
        apigatewayDomain: apiDomain,
      }),
    })
  }
}
```

### If CDK Drift Occurs

```bash
# Check drift
cdk diff

# Force sync CDK state to match template
cdk deploy --require-approval=never

# If Lambda runtime drifted, you must redeploy
# Check actual Lambda runtime:
aws lambda get-function --function-name <arn> --query 'Configuration.Runtime'
```

## Common Lambda Errors and Fixes

### `SyntaxError: Cannot use import statement outside a module`
**Cause:** Bundle has top-level `import` ESM statements in CJS runtime.
**Fix:** Use esbuild with `--platform=node --format=cjs`. Do NOT use `bun build --target=node`.

### `SyntaxError: Cannot use 'import.meta' outside a module`
**Cause:** Bundle uses `import.meta.url` or similar at top level.
**Fix:** esbuild normally handles this. If using `--define:import.meta.require=require`, the resulting CJS module has export compatibility issues — try without that flag.

### `Error: Cannot find module 'X'`
**Cause:** Either (a) zip doesn't have file at root, or (b) handler string is wrong.
**Fix:** Check zip contents: `python3 -c "import zipfile; z=zipfile.ZipFile('dist/lambda.zip'); print(z.namelist())"`. Ensure handler matches zip root filename.

### `Runtime.MalformedHandlerName: Bad handler`
**Cause:** Handler string is invalid (e.g., just `handler` with no filename).
**Fix:** Use format `filename.handler` where filename matches zip root file without extension.

### `ReferenceError: crypto is not defined`
**Cause:** Code uses `crypto` at module init time (e.g., Elysia cookie signing).
**Fix:** Add polyfill at top of bundled file or via wrapper.js:
```javascript
// At very top of index.js
if (typeof globalThis.crypto === 'undefined') {
  const nodeCrypto = require('crypto');
  Object.defineProperty(globalThis, 'crypto', { value: nodeCrypto });
}
```

### API Gateway Returns 500 but Lambda Direct Invoke Works
**Cause:** Usually one of:
1. Lambda permission missing for API Gateway (check Lambda resource-based policy)
2. API Gateway method has no integration configured (test-invoke shows `type: Null`)
3. CDK drift — API Gateway resources don't match CloudFormation template

**Debug:**
```bash
# Check Lambda permissions
aws lambda get-policy --function-name <arn>

# Check API Gateway method integration
aws apigateway get-method --rest-api-id <id> --resource-id <rid> --http-method GET

# Check test-invoke
aws apigateway test-invoke-method \
  --rest-api-id <id> \
  --resource-id <rid> \
  --http-method GET \
  --path-with-query-string '/health'
```

### Lambda Cold Start ~200ms but Response is 500
**Cause:** Module loads but handler throws — usually import resolution or runtime incompatibility.
**Fix:** Check CloudWatch for the specific error type:
- `Runtime.UserCodeSyntaxError` → bundle format problem
- `Runtime.ImportModuleError` → missing dependency or wrong handler
- `Runtime.MalformedHandlerName` → handler string format wrong

## ACM DNS Validation

CDK `aws-certificatemanager.Certificate` with DNS validation sometimes doesn't auto-create Route53 records:

```bash
# Get the validation record from ACM
aws acm describe-certificate --certificate-arn <arn> \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Create CNAME in Route53
aws route53 change-resource-record-sets \
  --hosted-zone-id <hz-id> \
  --change-batch '{
    "Changes":[{
      "Action":"UPSERT",
      "ResourceRecordSet":{
        "Name":"<Name>",
        "Type":"CNAME",
        "TTL":300,
        "ResourceRecords":[{"Value":"<Value>"}]
      }
    }]
  }'
```

## Binary Responses (File Uploads/Downloads)

**REST API only** — HTTP API has no binary support. Set `binaryMediaTypes: ['*/*']` on the REST API.

Handler must return `isBase64Encoded: true` and body as base64 for binary content:
```typescript
const buffer = Buffer.from(arrayBuffer)
return {
  statusCode: 200,
  headers: { 'Content-Type': 'application/pdf' },
  body: buffer.toString('base64'),
  isBase64Encoded: true,
}
```

## Embedded OpenAPI Spec (No /docs/json Endpoint Needed)

Instead of a separate `/docs/json` route, embed the OpenAPI spec directly in the HTML. This avoids an extra API Gateway resource and Lambda invocation.

```typescript
// src/generated-docs.ts — auto-generated, do not edit manually
import { handler } from './lambda-handler'
import { generateOpenApi } from '@elysiajs/swagger'

const spec = generateOpenApi(handler.app)

export const generatedHtml = `<!DOCTYPE html>
<html>
<head>
  <title>API Documentation</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    const spec = ${JSON.stringify(spec)};  // embedded spec — no /docs/json needed
    window.onload = () => SwaggerUIBundle({ spec, dom_id: '#swagger-ui' });
  </script>
</body>
</html>`
```

Then in `lambda-handler.ts`:
```typescript
import { generatedHtml } from './generated-docs'

app.get('/docs', () => new Response(generatedHtml, {
  headers: { 'Content-Type': 'text/html' }
}))
// No /docs/json route needed — spec is embedded in the HTML
```

**Why this matters:** Each API Gateway resource requires a separate Lambda integration. With embedded spec, you only need `/docs` → Lambda. Without it, you need both `/docs` → Lambda AND `/docs/json` → Lambda.

## CDK Drift: CDK Cannot Manage Existing Resources

If no local CloudFormation stack exists (e.g., API Gateway was created manually or by another tool), `cdk deploy` completes with "no changes needed" — CDK simply doesn't know those resources exist.

**Symptoms:**
- CDK stack shows "no differences" but API Gateway resources don't match CDK code
- `cdk diff` shows nothing, but actual Lambda runtime is wrong
- CDK deploy succeeds but nothing changes

**Fix:** Either import existing resources into CDK or accept manual management:
```bash
# Check if CDK has any record of the stack
cdk list  # if empty, no local stack exists

# To manage existing API Gateway, you'd need to import it:
cdk import arn:aws:apigateway:ap-southeast-1:631807311787:/restapis/40uo445gf0
```

## API Gateway CORS Configuration (Critical for Browser Apps)

**Important:** API Gateway REST API with Lambda `AWS_PROXY` integration does NOT automatically handle CORS. OPTIONS preflight requests must be handled at API Gateway level.

### The Problem

When deploying a browser app that calls the API directly (bypassing CloudFront), you'll get:
```
Access to XMLHttpRequest at 'https://api-gateway-url/prod/api/auth/login' 
from origin 'https://your-domain.com' has been blocked by CORS policy: 
Response to preflight request doesn't pass access control check: 
No 'Access-Control-Allow-Origin' header is present
```

### The Solution: Mock Integration for OPTIONS

You must configure API Gateway to respond to OPTIONS preflight requests with CORS headers:

```bash
# 1. Add OPTIONS method to the /{proxy+} resource
aws apigateway put-method \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method OPTIONS \
  --authorization-type NONE \
  --no-api-key-required

# 2. Create MOCK integration (returns fixed response without calling Lambda)
aws apigateway put-integration \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method OPTIONS \
  --integration-http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json": "{\"statusCode\": 200}"}'

# 3. Add method response (enable CORS header parameters)
aws apigateway put-method-response \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": true,
    "method.response.header.Access-Control-Allow-Methods": true,
    "method.response.header.Access-Control-Allow-Origin": true
  }'

# 4. Add integration response (map header values)
python3 << 'PYEOF'
import subprocess, json
params = {
    "method.response.header.Access-Control-Allow-Headers": "'*'",
    "method.response.header.Access-Control-Allow-Methods": "'*'",
    "method.response.header.Access-Control-Allow-Origin": "'https://your-allowed-origin.com'"
}
cmd = [
    "aws", "apigateway", "put-integration-response",
    "--rest-api-id", "<api-id>",
    "--resource-id", "<resource-id>",
    "--http-method", "OPTIONS",
    "--status-code", "200",
    "--response-parameters", json.dumps(params)
]
subprocess.run(cmd)
PYEOF

# 5. Deploy to activate changes
aws apigateway create-deployment \
  --rest-api-id <api-id> \
  --stage-name prod \
  --description "Add CORS support"
```

### Alternative: Allow All Origins via CloudFront

If you use CloudFront in front of API Gateway, you can configure CORS headers there instead:
- Add `Access-Control-Allow-Origin: *` (or specific domain)
- Add `Access-Control-Allow-Methods: *`
- Cache OPTIONS responses: `Cache Based on Selected Request Headers: None` (whitelisted headers)

### Frontend API URL Configuration

For browser apps calling API Gateway directly (no CloudFront):
```env
# .env.production
VITE_API_BASE_URL=https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod/api
```

For apps behind CloudFront:
```env
VITE_API_BASE_URL=https://your-cloudfront-domain.com/api
```

## Troubleshooting Workflow

1. **Check Lambda CloudWatch logs first** — always. The error type tells you 80% of what's wrong.
2. **Direct Lambda invoke** vs API Gateway — if direct works but API GW doesn't, it's an API Gateway integration/permission issue.
3. **Check zip contents** — confirm file structure is correct.
4. **Verify handler string** — must match zip root filename + `.handler`.
5. **Check actual Lambda runtime** — `aws lambda get-function --query 'Configuration.Runtime'`.
6. **CDK drift check** — `cdk diff` to see if actual infrastructure diverged from code.
