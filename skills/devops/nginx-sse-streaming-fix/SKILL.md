---
name: nginx-sse-streaming-fix
description: Fix nginx reverse proxy buffering SSE responses so streaming works correctly
tags: ["devops", "nginx", "sse", "streaming"]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# nginx SSE Streaming Fix

## 問題症狀
- SSE (Server-Sent Events) endpoint 看似正常（Response Header 有 `Content-Type: text/event-stream`）
- 後端有正確的 streaming 行爲，但在瀏覽器 Network tab 看不到 streaming
- `document.querySelectorAll('img').length === 0`，DOM 裡根本沒有即時生成的內容
- 原因是 nginx reverse proxy 預設會 **buffer** 整個 response，等收到完整內容後才轉送給客戶端

## 修復方案

### 1. Backend — 加 response header
```javascript
res.setHeader('X-Accel-Buffering', 'no');
```

### 2. nginx site config — 對應的 location 加 proxy buffering 關閉
```nginx
location /api/ {
    proxy_pass http://localhost:3002;
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_cache off;
    proxy_request_buffering off;
    chunked_transfer_encoding on;
    proxy_read_timeout 300s;
    client_max_body_size 50M;
}
```

## Important Lessons Learned

### nginx is often NOT the culprit
- `curl` test to nginx backend showed complete base64 image arriving correctly (1.7MB+)
- nginx error log was clean — no SSE-related errors
- Root cause was **browser-side SSE parser** (chunk boundary bug), NOT nginx

### Always test with curl first
```bash
curl -s --no-buffer -X POST https://chatbot.david-developer.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Draw a red circle","attachments":[]}' \
  --no-buffer 2>&1 | head -5
```
If curl shows complete SSE events ending in `data: {"done":true}`, nginx is fine.

### The actual SSE bug: chunk boundary parsing

Even with correct nginx settings, `text.split('\n')` on each HTTP chunk breaks JSON lines
that span two chunks. SSE arrives as network packets, not as logical events — a large payload
(base64 image, long completion) will be split mid-line, and `JSON.parse` throws
`Unterminated string in JSON at position N`.

**Fix — keep a buffer across reads and only parse complete lines:**

```javascript
let buffer = '';
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  buffer += decoder.decode(value, { stream: true });

  const lines = buffer.split('\n');
  buffer = lines.pop() ?? '';   // last element may be a partial line — keep it

  for (const line of lines) {
    if (!line.startsWith('data: ')) continue;
    try {
      handle(JSON.parse(line.slice(6)));
    } catch (e) {
      console.warn('[SSE] parse error:', e.message);  // don't abort the whole stream
    }
  }
}
```

**Two ordering traps in the same loop:**

1. **`done` processed before a sibling event.** If `{"done":true}` and `{"image":...}` land in
   the same chunk and the handler sets the outer loop flag immediately, the loop exits before
   the payload is handled. Use a *local* flag and yield it only after the inner `for` completes.
2. **Two parsers, one field name.** Apps often grow a second SSE reader (landing page, widget).
   When fixing a streaming bug, grep every `getReader()` call site and confirm each reads the
   field the backend actually emits — `parsed.chunk ?? parsed.content`.

### Never store base64 payloads in the database

A column with a length cap (ORM validation or `VARCHAR(255)`) will silently truncate a
50KB-150KB base64 image, leaving an `<img src>` of ~69 chars and no error anywhere. Write the
bytes to disk, store the *path*, and convert to base64 only at the moment of the AI API call.
Serve the directory as static files and give the reverse proxy a matching `location` block.

Confirm truncation directly in the DB rather than guessing:

```bash
sqlite3 app.db "SELECT length(image_url) FROM messages WHERE image_url IS NOT NULL LIMIT 3;"
```

### Dev-proxy parity

If the backend serves static assets from its own paths (`/uploads/`, `/ai-images/`), the Vite
dev proxy needs an entry for each one — otherwise dev returns the SPA's HTML 404 fallback and
images look broken even though production nginx is fine. Also raise `proxyTimeout` (default
~30s) above your slowest stream, or long generations die with `ERR_EMPTY_RESPONSE`.

## 驗證方法
在瀏覽器 Console：
```javascript
document.querySelectorAll('img').length  // streaming 時應該 > 0
```
或在 Network tab 看 Response，應該是逐步收到 chunks，而不是一次收到完整內容。

## 適用場景
- SSE streaming 看似正常但即時 DOM 更新失效
- nginx 作爲 reverse proxy 的所有 SSE/streaming endpoints
- 任何 Server-Sent Events
- Long-polling 或 chunked transfer 場景
