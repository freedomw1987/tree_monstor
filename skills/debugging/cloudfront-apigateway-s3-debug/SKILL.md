---
name: cloudfront-apigateway-s3-debug
description: Debug CloudFront returning S3 HTML instead of API Gateway responses for /api/* routes. CloudFront misroutes API calls to S3 static content.
category: debugging
tags: [cloudfront, aws, api-gateway, s3, routing]
---


Last-verified: 2026-07-28
# CloudFront + API Gateway + S3 Routing Debug

## Symptoms
- API Gateway works perfectly when called directly via URL
- CloudFront returns S3 static HTML content (or 403/404) for `/api/*` paths
- Root path `/` returns correct S3 static content
- API endpoints only fail when routed through CloudFront

## Common Pattern
```bash
# Direct API Gateway - WORKS
curl -s "https://{api-id}.execute-api.{region}.amazonaws.com/prod/api/v1"
# ✅ Returns correct JSON

# Through CloudFront - FAILS  
curl -s "https://your-domain.com/api/v1"
# ❌ Returns S3 HTML content or wrong response
```

## Root Cause
CloudFront Cache Behavior is routing `/api/*` paths to S3 origin instead of API Gateway origin. This happens when:
1. Default cache behavior sends ALL paths to S3
2. API Gateway origin is not properly added as a separate behavior
3. Behavior order matters - more specific paths should come first

## Debug Commands

### Step 1: Confirm API Gateway works directly
```bash
# Test API Gateway direct URL
curl -s --connect-timeout 10 "https://{api-id}.execute-api.{region}.amazonaws.com/prod/"
# Should return: {"name":"UMAC AI API","status":"ok"}
```

### Step 2: Test through CloudFront
```bash
# Test root path (should work - S3 static)
curl -s --connect-timeout 10 "https://your-domain.com/"

# Test API path (should return JSON, but returns HTML if broken)
curl -s --connect-timeout 10 "https://your-domain.com/api/v1"
# If you see HTML content here, the routing is broken
```

### Step 3: Check what CloudFront is actually serving
```bash
# Get full response headers
curl -sI "https://your-domain.com/api/v1"

# Check Content-Type - should be application/json for API
# If Content-Type is text/html, CloudFront is serving S3 content
```

## Fix Options

### Option A: Add API Gateway as Origin and Create Behavior (Recommended)
In CloudFront console:
1. Create new Origin: API Gateway endpoint
   - Origin Domain: `{api-id}.execute-api.{region}.amazonaws.com`
   - Origin Path: `/prod` (or `/v1` if using API Gateway v1)
2. Create Cache Behavior:
   - Path Pattern: `api/*`
   - Origin: Select the API Gateway origin
   - Viewer Protocol Policy: HTTPS only
   - Cache policy: Managed-CachingDisabled
3. Ensure API behavior comes BEFORE default S3 behavior in priority

### Option B: Use API Gateway with Regional Endpoint
```bash
# Change API Gateway endpoint type from EDGE to REGIONAL
# This often resolves CloudFront routing issues
aws apigateway update-rest-api \
  --rest-api-id {api-id} \
  --patch-operations op=replace,path=/endpointConfiguration/types/EDGE,value=REGIONAL
```

### Option C: Bypass CloudFront for API (Quick Fix)
Point frontend directly to API Gateway URL:
```javascript
// In your frontend API config
const API_BASE_URL = 'https://{api-id}.execute-api.{region}.amazonaws.com/prod/api'
```
Keep CloudFront only for static assets.

## Key Diagnostic Signal
| Endpoint | Direct API Gateway | Through CloudFront |
|----------|-------------------|-------------------|
| `/` | N/A | ✅ Static HTML |
| `/api/v1` | ✅ JSON | ❌ HTML or wrong |

## Prevention
- Always test BOTH direct API Gateway URL AND CloudFront URL
- When creating CloudFront distribution, add API Gateway origin FIRST with specific path pattern
- Remember: Cache behavior order matters - specific paths (`/api/*`) must come before default (`/*`)

---

## Case 2: CloudFront Origin Using Internal ALB DNS Name (502 Error)

### Symptoms
- CloudFront returns HTTP 502 for all API requests
- Direct ALB URL works fine
- `/api/*` routes fail through CloudFront
- CORS preflight (OPTIONS) requests also fail

### Root Cause
CloudFront is configured with an internal ALB DNS name (e.g., `UMacAi-UmmaA-uNbd4HN8HzLy-154450466.ap-east-1.elb.amazonaws.com`) as the origin. Internal ALB DNS names only resolve from within the VPC - they do NOT resolve from CloudFront edge nodes (which are on the public internet).

### Debug Commands
```bash
# Test direct ALB - WORKS
curl -sI "https://UMacAi-UmmaA-...elb.amazonaws.com/api/courses"

# Test through CloudFront - 502 ERROR
curl -sI "https://your-domain.com/api/courses"

# Check CloudFront response headers
curl -sI --max-time 15 "https://your-domain.com/api/courses"
# Look for: x-cache: Error from cloudfront
```

### Fix
Replace the ALB DNS name origin with the API subdomain CNAME that routes to the ALB:

1. **In CloudFront console:**
   - Edit the API Gateway origin
   - Origin Domain: Change from `UMacAi-UmmaA-...elb.amazonaws.com` to `api.board-ai.site`
   - Origin Protocol Policy: `match-viewer` (recommended for flexibility)

2. **In CDK (recommended - infrastructure as code):**
   ```typescript
   // Before (BROKEN - internal DNS doesn't resolve from CloudFront edge)
   const albDomain = 'UMacAi-UmmaA-uNbd4HN8HzLy-154450466.ap-east-1.elb.amazonaws.com';
   
   // After (WORKS - DNS resolves from anywhere)
   const albDomain = 'api.board-ai.site';  // Route53 A record → ALB
   ```

3. **Ensure DNS is configured:**
   - Route53 A alias record: `api.board-ai.site` → ALB target
   - Verify: `nslookup api.board-ai.site` should return ALB IP

### Key Diagnostic Signal
| Test | Expected | Broken |
|------|----------|--------|
| Direct ALB URL | ✅ 200 OK | ✅ 200 OK |
| CloudFront API path | ✅ 200 OK | ❌ 502 Error |
| `curl -sI` response | `HTTP/2 200` | `HTTP/2 502` |

### Prevention
- Never use internal ELB/ALB DNS names as CloudFront origins
- Always create a Route53 A alias record for the API subdomain and use that in CloudFront origin
- Internal DNS names (`.elb.amazonaws.com`, `.compute.internal`) are only resolvable within VPC
