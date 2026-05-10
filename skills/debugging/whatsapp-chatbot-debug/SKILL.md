---
name: whatsapp-chatbot-debug
description: Debug image generation in the WhatsApp-style chatbot where AI-generated images don't appear in the browser even though the backend SSE stream is correct.
---

# WhatsApp Chatbot Debugging

Debug image generation in the WhatsApp-style chatbot where AI-generated images don't appear in the browser even though the backend SSE stream is correct.

## Symptoms
- Backend curl confirms SSE sends `data:image/jpeg;base64,...` correctly
- nginx delivers the stream with correct Content-Type
- Browser shows no `<img>` tags in DOM

## Debugging Sequence

### Step 1: Check Backend Log
```bash
tail -50 /tmp/backend.log
```
Look for:
- `PayloadTooLargeError` → express.json limit too small
- `reasoning_details received but skipping (images path available: true)` → image found in `delta.images[0].image_url.url`, not in `reasoning_details[0].data`
- SSE chunks being sent

### Step 2: Check Frontend State via Browser Console
Navigate to `https://chatbot.david-developer.com` in the browser tool, then:
```js
document.querySelectorAll('img').length  // Should be > 0 if images render
```

### Step 3: Common Bug — Duplicate getReader() in InputBar.jsx
In `InputBar.jsx` SSE handler, if you see TWO calls to `response.body.getReader()`, the stream is consumed twice and the second reader gets nothing:
```jsx
// WRONG — stream consumed twice
const reader = response.body.getReader()  // ← first consumer
// ...
const stream = response.body
const reader2 = stream.getReader()  // ← second consumer, gets empty stream

// CORRECT — single reader
const stream = response.body
const reader = stream.getReader()
while (!done) {
  const { value, done: d } = await reader.read()
  // ...
}
```

### Step 4: PayloadTooLargeError Fix
In `backend/server.js`, increase body-parser limit:
```js
app.use(express.json({ limit: '50mb' }));  // was '10mb'
```

### Step 5: Restart Services After Fix
```bash
pkill -f "node.*server.js.*backend"
pkill -f "node.*server.js.*frontend"
cd /home/ubuntu/projects/whatsapp-chatbot/backend && node server.js > /tmp/backend.log 2>&1 &
cd /home/ubuntu/projects/whatsapp-chatbot/frontend && node server.js > /tmp/frontend.log 2>&1 &
```

### Step 6: Reset Browser State
```js
localStorage.clear(); location.reload();
```

## Key Files
- `frontend/src/components/InputBar.jsx` — SSE reader (lines ~77-154), SSE lineBuffer parser
- `frontend/src/components/MessageBubble.jsx` — renders AI images from `data:image/` text; renders user images from `message.imageData` (base64 data URL). Has `onImageClick` prop for lightbox trigger.
- `frontend/src/components/MessageBubble.css` — `.bubble-inline-img` with `max-height: 260px; object-fit: contain`
- `frontend/src/components/ChatArea.jsx` — lightbox `lightboxImage` state, click-to-close overlay
- `frontend/src/components/ChatArea.css` — lightbox CSS (fixed overlay, centered image, X button)
- `backend/server.js` — SSE handler, image from `delta.images[0].image_url.url`
- `/tmp/backend.log` — backend logs

## Known Bugs Fixed (for reference)
- **`new Date.toISOString()` missing parentheses** — `InputBar.jsx` line 138 was `new Date.toISOString()` instead of `new Date().toISOString()`, causing "TypeError: new Date.toISOString is not a function"
- **SSE chunk boundary parse error** — large base64 images split across HTTP chunks caused `JSON.parse()` to fail. Fixed with lineBuffer accumulator in InputBar.jsx SSE handler. See `sse-chunk-boundary-debug` skill for details.
- **User images not displaying inline** — user-uploaded images showed as paperclip icon instead of inline image. Fixed by adding `imageSrc` logic in MessageBubble.jsx to show `<img>` for user images too.
- **Lightbox missing** — added `lightboxImage` state in ChatArea.jsx with click overlay and X button to close.
- **Cross-account data leakage from duplicate backend** — when two `node server.js` processes run simultaneously on port 3002, requests round-robin between them. User A's JWT token can end up being used by User B's session, causing User B to see User A's conversations. Nginx access log shows 403 on `/api/conversations/:id/messages` for wrong users. Fix: kill all duplicate backend processes, ensure only one runs.
- **Vite proxy missing `/ai-images/` route** — In Vite dev mode, requests to `/ai-images/...` returned HTML 404 instead of proxied image binary. Root cause: `vite.config.js` only had proxy config for `/api` but not `/ai-images`. Images showed as broken/blank even though backend served correct PNG binary. Fix: add `/ai-images` proxy entry in `vite.config.js`.
- **Missing Authorization header in InputBar.jsx** — `POST /api/chat` returned 401 Unauthorized even when user was logged in. Root cause: `InputBar.jsx` used raw `fetch('/api/chat', ...)` which did NOT include the `Authorization` header. Other components used the `apiFetch()` wrapper from `ChatContext` which auto-injects the Bearer token, but `InputBar.jsx` hand-wrote its own fetch and forgot the auth header. Fix: add token from `localStorage.getItem('auth_token')` to the headers:
  ```js
  const token = localStorage.getItem('auth_token') || ''
  const response = await fetch('/api/chat', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ ... }),
  })
  ```
  **Debug tip**: Ask user to check Network tab → find `/api/chat` request → look for `Authorization: Bearer eyJ...` in Request Headers. If missing → this bug.

## Critical Diagnostic: Cross-Account Data Leakage
### Symptoms
- User A's conversations appearing in User B's account
- User B can see or delete User A's conversations
- 403 Forbidden on API calls that should succeed
- No code-level auth bug found (JWT verification is correct)

### Diagnosis Steps
1. **Check for duplicate backend processes** — Run `ps aux | grep "node server" | grep -v grep`. Two PIDs = root cause.
2. **Check nginx access log for 403/401 patterns** — `grep "403\|401" /var/log/nginx/access.log | grep conversations`
3. **Verify DB-level isolation** — Query messages/conversations table directly:
   ```bash
   cd /home/ubuntu/projects/whatsapp-chatbot/backend && node -e "
   const db = require('./src/db/database');
   // Check which user owns which conversations
   db.prepare('SELECT id, user_id FROM conversations').all().forEach(c => {
     const user = db.prepare('SELECT email FROM users WHERE id = ?').get(c.user_id);
     console.log(c.id, user.email);
   });
   "
   ```
4. **Check port listeners** — `ss -tlnp | grep 3002`. Should show exactly ONE process.

### Fix
```bash
# Kill ALL duplicate backend processes
pkill -f "node.*server.js"
sleep 2
# Restart single backend
cd /home/ubuntu/projects/whatsapp-chatbot/backend && node server.js &
# Verify only one is running
ss -tlnp | grep 3002
```

## Model for Image Generation
Use `google/gemini-3.1-flash-image-preview` — image comes through `delta.images[0].image_url.url` (base64 data URL), NOT `reasoning_details[0].data`.

## User Image Upload — Architecture Pattern

When user uploads an image in InputBar, the full flow is:
1. `InputBar.jsx` `handleAttach` → `setPendingImage({file, preview: blobURL})`
2. `handleSend` → `POST /api/upload` with `FormData` → backend stores file → returns `{url: "/uploads/uuid-filename.jpg"}`
3. `handleSend` → `sendMessage(text, uploadedUrl)` → dispatches `ADD_MESSAGE` with `imageUrl`
4. `sendMessage` (ChatContext.jsx) → `POST /api/chat` with body `{content, attachments: [{type:"image/*",url:uploadedUrl}], conversationId}`
5. Backend saves to DB with `image_url` column → SSE streams back AI response
6. Frontend receives SSE → `ADD_ASSISTANT_MESSAGE` → renders in MessageBubble

### Key Files
- `backend/server.js` — multer setup, `/api/upload` endpoint, static `/uploads/` serving, `attachments` handling in `/api/chat`
- `frontend/src/components/InputBar.jsx` — `handleAttach` (stores `{file, preview}`), `handleSend` (FormData upload + send)
- `frontend/src/context/ChatContext.jsx` — `sendMessage` wraps `imageUrl` into `attachments: [{type:"image",url:imageUrl}]`
- `backend/uploads/` — uploaded files stored here (NOT in frontend/Vite)
- `/etc/nginx/sites-available/chatbot.david-developer.com` — `location /uploads/` proxy_pass to backend

### Bug: `attachments` Double-Encode from Browser
If `attachments` arrives at `/api/chat` as a JSON string (`'"[{\"type\":\"image\",...}]"'`) instead of an array, the browser's `JSON.stringify` and `fetch` `body: JSON.stringify(...)` combination may double-encode it. Fix in `server.js`:
```js
if (typeof attachments === 'string') {
  try { attachments = JSON.parse(attachments); } catch {}
}
```

### Bug: Upload Works but LLM Can't See Image
**Debug sequence:**
1. **Check DB directly** — query `messages` table for the user message:
   ```bash
   sqlite3 backend/data/auth.db "SELECT content, image_url FROM messages WHERE role='user' ORDER BY created_at DESC LIMIT 5;"
   ```
   - If `image_url` is `NULL` → the attachment URL never reached `/api/chat` → check InputBar `handleSend`
   - If `image_url` has a value → attachment reached backend → check `/api/chat` attachments handling

2. **Check backend debug log** — after restarting backend with debug log added:
   ```bash
   grep "attachments" /tmp/backend.log
   ```
   Should show: `[DEBUG /api/chat] attachments type: object, value: [{"type":"image",...}]`

3. **Test `/api/upload` with curl**:
   ```bash
   TOKEN="eyJ..." && curl -s -X POST http://localhost:3002/api/upload \
     -H "Authorization: Bearer $TOKEN" \
     -F "image=@/tmp/test.png" | jq
   ```
   Should return: `{"url":"/uploads/uuid-filename.png"}`

4. **Test `/api/chat` with image URL directly**:
   ```bash
   TOKEN="eyJ..." && curl -s -X POST http://localhost:3002/api/chat \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"content":"What color is the image?","attachments":[{"type":"image/png","url":"/uploads/test.png"}],"conversationId":"ID"}'
   ```
   Should stream back AI response correctly identifying the image.

### Bug: Image Disappears After Page Refresh
Always caused by `image_url` not being saved to DB. Fix the upload-to-/api/chat flow and this is automatically fixed.

## Bug: LandingPage SSE — `chunk` vs `content` Field Name Mismatch

### Symptoms
- User submits message on LandingPage → user message appears → spinner shows → spinner disappears → **no AI reply**
- Backend curl test returns correct `{"chunk":"Hello","msgId":"..."}` SSE chunks
- Browser shows no AI message, no console errors visible to user

### Root Cause
Backend `/api/chat` sends `{"chunk": "...", "msgId": "..."}` but `sendLandingMessage` in `ChatContext.jsx` only checked `parsed.content`:
```js
// WRONG — backend sends 'chunk', not 'content'
} else if (parsed.chunk || parsed.content) {  // chunk is falsy, content is undefined
  const text = parsed.chunk || parsed.content  // undefined
```

### Fix
```js
// CORRECT — check both fields
} else if (parsed.chunk || parsed.content) {
  const text = parsed.chunk || parsed.content
```

### Files
- `frontend/src/context/ChatContext.jsx` — `sendLandingMessage` SSE parser (line ~333)

### Note
The main chat's SSE parser in `InputBar.jsx` was already correct — it uses `parsed.content`. Only `sendLandingMessage` was broken. Always verify both SSE parsers when fixing streaming bugs.
