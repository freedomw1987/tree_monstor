---
name: sse-chunk-boundary-debug
description: Diagnose and fix SSE JSON parse errors caused by HTTP chunked transfer encoding splitting SSE lines mid-JSON
---


Last-verified: 2026-07-28
# SSE Chunk Boundary JSON Parse Failure — Debug & Fix

## Problem
Browser SSE parser fails with `Unterminated string in JSON at position N` when receiving large base64 images via SSE from backend through nginx.

## Diagnostic Workflow

### Step 1: Confirm backend sends correct data
```bash
curl -s -X POST https://chatbot.david-developer.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Draw a red circle","attachments":[]}' \
  --no-buffer 2>&1 | head -5
```
If curl shows complete base64 JSON ending in `data: {"done":true}`, backend and nginx are fine.

### Step 2: Check nginx error log
```bash
sudo tail -20 /var/log/nginx/error.log
```
Look for SSE-related errors (none = nginx not the culprit).

### Step 3: Check nginx buffering settings
Even with `proxy_buffering off;`, nginx may still buffer large responses. Confirm:
- `proxy_buffering off;`
- `chunked_transfer_encoding on;`
- `proxy_request_buffering off;`
- `proxy_read_timeout 300s;`
- Backend sends `X-Accel-Buffering: no` header

If all above confirmed but SSE parse error persists → **root cause is browser-side SSE parser**, not nginx.

## Root Cause — Confirmed NOT nginx
nginx is correctly configured with all recommended settings. The **real culprit is the browser's SSE stream reader** receiving chunked-transfer-encoded data split mid-line.

HTTP chunked transfer encoding (`Transfer-Encoding: chunked`) splits data at arbitrary byte boundaries — NOT at SSE line boundaries. A long `data: {"image":"data:image/png;base64,VERY_LONG..."}` line may be split across two HTTP chunks:
- Chunk 1 ends mid-JSON: `data: {"image":"data:image/png;base64,iVBOR...INCOMP`
- Chunk 2 continues: `LETE_BASE64_STRING..."}`

When `text.split('\n')` is applied per-chunk, the incomplete JSON fragment causes `JSON.parse()` to throw.

**nginx buffering was NOT the issue** — curl confirmed nginx delivered complete base64 JSON correctly. Adding more nginx headers (`X-Accel-Buffering: no`) did not fix the browser-side parse error.

## Fix: Line Buffer Accumulator
## Fix: Line Buffer Accumulator

```javascript
let lineBuffer = ''

while (!done) {
  const { value, done: d } = await reader.read()
  if (value) {
    const text = decoder.decode(value)
    // Prepend any leftover partial line from previous chunk
    const lines = (lineBuffer + text).split('\n')
    // Last element may be incomplete — save for next chunk
    lineBuffer = lines.pop() || ''

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const raw = line.slice(6)
        try {
          const data = JSON.parse(raw)
          // handle data.chunk, data.image, data.done, data.error
        } catch (e) {
          // JSON was incomplete — carry partial forward
          lineBuffer = raw
        }
      }
    }
  }
  if (d) done = true
}
```

### Key insight
`JSON.parse()` throws on incomplete JSON → catch the error → carry the partial `raw` string into `lineBuffer` → next chunk prepends it → re-parse.

### Common mistake
Setting `lineBuffer = line.slice(6)` in the catch block (forgets the already-split raw content). Must be `lineBuffer = raw`.

## Verification
After fix: `Ctrl+Shift+R` (hard refresh), send message that triggers SSE. Check browser console for `[SSE] parse error` — should be gone.

## nginx Config (reference — NOT the fix)
```nginx
proxy_buffering off;
chunked_transfer_encoding on;
proxy_request_buffering off;
proxy_read_timeout 300s;
```
Backend also sends `X-Accel-Buffering: no` header. These are correctly set in `/etc/nginx/sites-available/chatbot.david-developer.com` but they do NOT fix the browser-side chunk boundary issue — only the lineBuffer accumulator does.

## Files
- Frontend SSE handler: `/home/ubuntu/projects/whatsapp-chatbot/frontend/src/components/InputBar.jsx`
- Backend SSE endpoint: `/home/ubuntu/projects/whatsapp-chatbot/backend/server.js`
- nginx config: `/etc/nginx/sites-available/chatbot.david-developer.com`
