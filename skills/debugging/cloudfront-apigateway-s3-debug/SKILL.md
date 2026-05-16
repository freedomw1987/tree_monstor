---
name: cloudfront-apigateway-s3-debug
description: Debug CloudFront returning S3 HTML instead of API Gateway responses for /api/* routes. CloudFront misroutes API calls to S3 static content.
category: debugging
tags: [cloudfront, aws, api-gateway, s3, routing]
---

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
