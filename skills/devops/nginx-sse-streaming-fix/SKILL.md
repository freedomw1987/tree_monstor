---
name: nginx-sse-streaming-fix
description: Fix nginx reverse proxy buffering SSE responses so streaming works correctly
tags: ["devops", "nginx", "sse", "streaming"]
---

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
Even with correct nginx settings, `text.split('\n')` on each HTTP chunk breaks JSON lines that span two chunks. See skill `sse-chunk-boundary-debug` for the fix.

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
