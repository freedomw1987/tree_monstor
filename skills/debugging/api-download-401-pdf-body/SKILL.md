---
name: api-download-401-pdf-body
description: Debug why file downloads via fetch+blob return HTML/incorrect content instead of the actual file — specific pattern where auth middleware on a download endpoint returns 401 with the file body still attached.
tags: [debugging, http, download, auth, fetch-blob]
related_skills: [systematic-debugging]
---

Last-verified: 2026-07-28
# API Download Returns Wrong Content (401 but file in body)

## Symptom

- File download via `fetch('/api/files?key=...')` + `r.blob()` + `createObjectURL` + click
- Downloaded file is HTML/text instead of the expected PDF/docx
- File size is wrong (usually smaller, e.g. an error page instead of the real file)
- The same endpoint works when tested with curl

## Root Cause Pattern

The backend `/api/files` endpoint has **auth middleware** that validates the JWT token. When the token is invalid:
1. Backend returns **HTTP 401** (correct — auth failed)
2. But the **file stream/PDF body was already fetched from S3** before auth check failed
3. The 401 response body contains the actual file binary, not a JSON error
4. Browser's `fetch()` follows the 401 → `r.blob()` gets the HTML error page OR the PDF body (depending on middleware order)
5. The download creates a corrupt file

**Key insight:** Auth check happens AFTER S3 fetch, so the 401 response carries the file body.

## Debugging Steps

### Step 1: Test with curl — no auth header
```bash
PDF_KEY="attachments/your-file.pdf"
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PDF_KEY'))")
curl -s -D - "https://api.board-ai.site/api/files?key=${ENCODED}" -o /tmp/download.pdf
file /tmp/download.pdf
# Expected: "PDF document" — if so, endpoint works without auth
```

### Step 2: Test with invalid token
```bash
curl -s -o /tmp/invalid.pdf -w "%{http_code}" \
  "https://api.board-ai.site/api/files?key=${ENCODED}" \
  -H "Authorization: Bearer invalid_token"
file /tmp/invalid.pdf
# If HTTP=401 but file shows "PDF document" → BUG: 401 response has PDF body
```

### Step 3: Test with empty Bearer token
```bash
curl -s -o /tmp/empty.pdf -w "%{http_code}" \
  "https://api.board-ai.site/api/files?key=${ENCODED}" \
  -H "Authorization: Bearer "
file /tmp/empty.pdf
# If empty Bearer = 200 → auth accepts empty as valid (no token = no auth check)
```

### Step 4: Check the backend route order
Look at the route definition:
```typescript
// INCORRECT (auth AFTER S3 fetch):
router.get('/files', async (ctx) => {
  const response = await s3Client.send(new GetObjectCommand(...))
  // ... fetch S3 FIRST ...
})
// .use(auth)  ← auth fails AFTER file is already fetched

// CORRECT (auth BEFORE S3 fetch):
router.get('/files', auth, async (ctx) => {
  // auth check FIRST
})
```

## Fix Options

### Option A: Remove auth from download endpoint (if files are not sensitive)
```typescript
// Most file downloads don't need auth — the key is the secret
.get("/files", async (ctx) => {
  // S3 presigned URLs or authenticated fetch
})
```
**Pros:** Simple, no auth complexity
**Cons:** Anyone with the key can download

### Option B: Auth check BEFORE S3 fetch
```typescript
.get("/files", auth, async (ctx) => {
  // Auth validated FIRST
  // Then fetch from S3
})
```

### Option C: Frontend check before blob()
```typescript
fetch(`/api/files?key=${encodeURIComponent(url)}`, {
  headers: { Authorization: `Bearer ${token}` }
})
  .then(r => {
    if (!r.ok) throw new Error(`HTTP ${r.status}`)
    return r.blob()
  })
```
**Pros:** Frontend handles it gracefully
**Cons:** Doesn't fix the root cause (backend still sends wrong body with 401)

### Option D: Backend returns error WITHOUT file body
```typescript
.get("/files", async (ctx) => {
  try {
    // validate key first
    await validateKey(ctx.query.key)
    // THEN fetch from S3
  } catch (err) {
    ctx.status = 401
    ctx.body = { error: "Unauthorized" }
    return  // No file body attached to 401
  }
})
```

## Real Example (UMAC AI)

- `/api/files?key=attachments/xxx.pdf` — has auth middleware
- `Bearer invalid_token` → HTTP 401 + PDF body in response
- `Bearer ` (empty) → HTTP 200 + correct PDF
- Student downloads via `fetch + blob` → gets the 401 body instead of PDF
- Same endpoint works in curl because curl doesn't follow the same blob-download path

## Investigation Commands

```bash
# 1. List actual attachments in lesson
curl -s "https://api.board-ai.site/api/lessons/{lesson_id}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for a in json.loads(d.get('attachments','[]')):
    print('name:', a['name'])
    print('url:', a['url'])
"

# 2. Test download with different auth scenarios
for TOKEN in "" " " "invalid"; do
  RESULT=$(curl -s -o /tmp/test_$TOKEN.bin -w "%{http_code}" \
    "https://api.board-ai.site/api/files?key=attachments/xxx.pdf" \
    ${TOKEN:+"$TOKEN"} -H "Authorization: Bearer $TOKEN" --max-time 10)
  echo "Token='$TOKEN' HTTP=$RESULT Size=$(wc -c < /tmp/test_$TOKEN.bin) Type=$(file -b --mime-type /tmp/test_$TOKEN.bin)"
done

# 3. Check S3 object metadata
aws s3api head-object --bucket umac-ai-attachement-prod --key "attachments/xxx.pdf" --region ap-east-1 | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('ContentType:', d.get('ContentType'))
print('ContentLength:', d.get('ContentLength'))
"
```
