---
name: chat-frontend-backend-debug
description: Debug WhatsApp-style chat UI where AI doesn't respond — covers API format mismatch, missing dispatch, React state bugs, mobile layout
---


Last-verified: 2026-07-28
# Chat Frontend ↔ Backend Integration Debugging

## Problem
User sends message in chat UI → AI never responds, no visible error.

## Layer-by-Layer Diagnosis

```
InputBar.handleSend()
  → fetch('/api/chat', { body: { ??? } })
    → Backend server.js (/api/chat route)
      → OpenRouter API
        → SSE stream: data: {"chunk":"..."}\n\n
          → Frontend SSE parser
            → dispatch(UPDATE_MESSAGE)
              → React state update
                → UI renders
```

## Layer 1: Test Backend API with curl

```bash
curl -X POST http://localhost:3002/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hi","conversationHistory":[],"model":"moonshotai/kimi-k2.6"}'
```

- **Expected:** SSE stream with `data: {"chunk":"..."}\n\n` lines
- **400 error:** Frontend sending wrong body format → Layer 2
- **Stream works:** Bug is frontend state/SSE parsing → Layer 3

## Layer 2: Fix API Body Format Mismatch

**Common mismatch — backend expects:**
```javascript
const { message, conversationHistory = [], model } = req.body;
```

**But frontend sends:**
```javascript
{ messages: [{role:'user', content:'...'}] }  // WRONG format
```

**Fix — match backend's expected shape:**
```javascript
body: JSON.stringify({
  message: userText,
  conversationHistory: history,  // [{role, content}, ...]
  model: selectedConv.model,
})
```

## Layer 3: Frontend State Management Bugs

### Bug A: Missing dispatch from context destructuring
```javascript
// WRONG — dispatch is undefined at runtime
const { state } = useChat()
dispatch({ type: 'NEW_CHAT' })

// RIGHT
const { state, dispatch } = useChat()
```

### Bug B: Action dispatched but no reducer case
```javascript
// Reducer needs:
case 'SET_TYPING': {
  const { convId, typing } = action
  return {
    ...state,
    conversations: state.conversations.map(c =>
      c.id === convId ? { ...c, typing } : c
    )
  }
}
```

### Bug C: UPDATE_MESSAGE before ADD_MESSAGE
```javascript
// WRONG — no placeholder exists when UPDATE runs
dispatch({ type: 'UPDATE_MESSAGE', id: '__pending', updates: { text } })

// RIGHT — add pending placeholder first
const pendingId = 'pending-' + Date.now()
dispatch({
  type: 'ADD_MESSAGE',
  convId,
  message: { id: pendingId, sender: 'assistant', text: '', timestamp }
})
// stream chunks → accumulate text
dispatch({
  type: 'UPDATE_MESSAGE',
  convId,
  messageId: pendingId,
  text: streamedText
})
```

### Bug D: Typing indicator reads wrong field
```javascript
// Component: reads isTyping
{selectedConv.isTyping && <TypingIndicator />}

// Reducer sets: typing
c.id === convId ? { ...c, typing } : c

// Fix: align the field name
{selectedConv.typing && <TypingIndicator />}
```

## Layer 4: Mobile Layout Bugs

### InputBar inside hidden panel
```jsx
// WRONG — InputBar inside .chat-panel (display:none when sidebar open on mobile)
<div className={`chat-panel ${isMobileSidebarOpen ? 'hidden-mobile' : ''}`}>
  <ChatArea />
  <InputBar />  // display:none, textarea appears disabled
</div>

// RIGHT — InputBar at app-shell level, always visible
<div className="app-shell">
  <Sidebar />
  <ChatArea />
  <InputBar />
</div>
```

### Mobile shows blank on first load
```jsx
useEffect(() => {
  if (window.innerWidth < 768 && !selectedConv) {
    setIsMobileSidebarOpen(true)
  }
}, [selectedConv])
```

## Verification Checklist

1. + button → select model → new conv appears in sidebar → textarea enabled
2. Type message → Enter → user bubble shows → AI response streams in
3. Long response → 3-dot typing indicator visible
4. Mobile: chat view → tap ← → sidebar returns
5. Multiple convs: create 2+, switch between, each retains its messages

## Key Principle
**Always curl the API first.** If curl works but UI doesn't, bug is frontend — not backend.

---

## Layer 5: SSE Streaming Bugs

### Bug E: `data.done` breaks loop before `data.image` is processed

**Symptom:** AI generates an image (confirmed via backend curl = 200 with 1.4MB response), but UI shows raw base64 text instead of an inline `<img>` tag. `document.querySelectorAll('img').length` returns 0 or the image tag has wrong src.

**Root cause:** SSE chunks arrive as network packets. If `data.done` and `data.image` are in the **same chunk**, the inner forEach loop finds `data.done` first, sets `done = true`, and the outer `while (!done)` loop exits before `data.image` is ever processed.

**Original buggy code pattern:**
```javascript
async function* streamSSE(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        if (data.done) {         // ← sets done = true synchronously
          done = true;            // ← outer while exits next iteration
          yield { done: true };
        }
        if (data.image) {         // ← never reached if data.done was in same chunk
          yield { image: data.image };
        }
      }
    }
  }
}
```

**Fix — defer `done` until after all data events in the chunk are processed:**
```javascript
async function* streamSSE(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done: readerDone, value } = await reader.read();
    if (readerDone) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    let eventDone = false;  // ← local flag, NOT the outer loop variable

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        if (data.image) {
          yield { image: data.image };  // ← process image FIRST
        }
        if (data.done) {
          eventDone = true;  // ← defer until after inner loop
        }
      }
    }

    if (eventDone) {
      yield { done: true };  // ← yield AFTER all data events handled
    }
  }
}
```

**Verification:**
1. Backend curl confirms image generation returns 200 with ~1.4MB response
2. `document.querySelectorAll('img').length` should return ≥ 1
3. `document.querySelector('img').src` should start with `data:image/`
4. Browser DevTools → Network: `/api/chat` should return 200 with large response size

### Bug F: Vite proxy timeout kills SSE streaming requests

**Symptom:** Backend SSE `/api/chat` works fine with curl (returns full response), but browser console shows request hanging, then `ERR_EMPTY_RESPONSE` or `net::ERR_CONNECTION_CLOSED` after ~30 seconds. No JS error, the request just dies.

**Root cause:** Vite dev server proxy has a default `proxyTimeout` (~30 seconds). AI image generation via SSE takes 30-60 seconds. The proxy kills the connection before the backend finishes streaming.

**Fix — set `proxyTimeout: 120000` in `vite.config.js`:**
```javascript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:3002',
      changeOrigin: true,
      timeout: 120000,      // ← add this
      proxyTimeout: 120000, // ← critical for SSE streaming
    },
    '/ai-images': {
      target: 'http://localhost:3002',
      changeOrigin: true,
      timeout: 120000,
      proxyTimeout: 120000,
    }
  }
}
```

**Verification:**
```bash
# Test with curl — should complete without hanging
curl -X POST http://localhost:5174/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Draw a cat","attachments":[],"conversationHistory":[],"model":"google/gemini-3.1-flash-image-preview"}' \
  --max-time 90

# Should see complete SSE response including data:image/png;base64,...
```

---

### Bug J: Missing `useState` declaration — silent streaming crash

**Symptom:** After a code refactor or subagent edit, AI streaming chat stops working entirely. No visible error on UI. Browser console shows: `Uncaught (in promise) ReferenceError: setStreamingText is not defined at d (index-XXXXX.js:51:42688)`. The `<img>` tags never appear even though backend curl confirms images are generated.

**Root cause:** A `setXXX()` function is called in the component (e.g., `setStreamingText('')`) but the corresponding `useState` was never declared. This can happen when:
- A subagent adds a `setStreamingText('')` call during a refactor but forgets the `const [streamingText, setStreamingText] = useState('')` declaration
- A code template has the call without the state declaration
- A merge conflict removes the state declaration but keeps the calls

**Diagnosis — search for mismatched state calls:**
```bash
# Find all useState declarations in a component
grep -n "useState" src/components/InputBar.jsx

# Find all setter calls (setXxx patterns) that might be missing declarations
grep -n "set[A-Z]" src/components/InputBar.jsx
```

**Fix — add the missing state declaration:**
```javascript
// At the top of the component, with other useState calls:
const [streamingText, setStreamingText] = useState('');  // ← add this
const [isStreaming, setIsStreaming] = useState(false);
```

**Verification — after rebuild:**
```javascript
// Browser console: should be NO ReferenceError
// Test: send a message → AI response streams in with text
// Test: send "draw a cat" → image appears in bubble
```

**Key principle:** Always verify `setXXX` calls have matching `useState` declarations when debugging silent streaming failures. The error is "not defined" not "undefined" — the variable doesn't exist at all.

---

**Symptom:** Fix is applied to InputBar.jsx but browser still runs old code. `?t=12345` cache-buster on URL doesn't help. The page may even visually reload but the JS bundle is still cached.

**Root cause:** Vite's dev server serves the JS bundle with its own caching headers. A full page reload (`location.reload(true)`) may not actually re-fetch the Vite-served JS module.

**Fix — force Vite to invalidate its module cache:**
```javascript
// In browser console, run:
window.__vite_plugin_force_reload = true
location.reload()
```
Or restart the Vite dev server:
```bash
pkill -f "vite"
cd /path/to/frontend && npm run dev
```

**Better approach — use the Vite HMR WebSocket directly:**
```javascript
// Connect to Vite HMR WebSocket to trigger full reload
const ws = new WebSocket('ws://localhost:5173/@vite/client')
ws.onopen = () => { ws.send('{"type":"full-reload"}'); ws.close(); }
```

**Verification:** After reload, check `window.__vite_plugin_force_reload` or verify the InputBar.jsx fix is in the running code via browser DevTools Sources panel.

### Bug G: `new Date.toISOString()` missing parentheses in dispatch

**Symptom:** AI generates an image (confirmed via backend curl = 200), but `document.querySelectorAll('img').length` returns 0. No error in browser console, but the `dispatch({ type: 'ADD_MESSAGE', ... })` silently fails.

**Root cause:** Typo — `new Date.toISOString()` is missing parentheses. JavaScript evaluates `new Date` as a constructor call, then `.toISOString` on the constructor object (not an instance), returning a function string. This throws a TypeError when used as a timestamp property in the dispatched action object, crashing the SSE handler silently.

**Original buggy code:**
```javascript
dispatch({
  type: 'ADD_MESSAGE',
  convId,
  message: {
    id: 'assistant-' + Date.now(),
    sender: 'assistant',
    text: base64Url,        // or text: chunk
    timestamp: new Date.toISOString()  // ← WRONG: should be new Date().toISOString()
  }
})
```

**Fix:**
```javascript
timestamp: new Date().toISOString()  // ← parentheses added
```

**Verification:**
```javascript
// In browser console after sending an image prompt:
document.querySelectorAll('img').length  // should be ≥ 1
```

### Bug H: SSE chunk boundary — incomplete JSON parse

**Symptom:** `[SSE] parse error: Unterminated string in JSON at position N` in browser console. Image is partially received — the base64 string gets cut mid-way at byte N.

**Root cause:** SSE arrives in network chunks. If a chunk boundary cuts through a `data: {...}` line in the middle, the partial JSON is incomplete → `JSON.parse()` throws. This is especially likely for large payloads like base64-encoded images (80KB+) where the entire image is one giant `data: {"image":"base64..."}` event.

**nginx misdiagnosis:** This error is often wrongly blamed on nginx buffering. **Verify first — always test with curl through nginx before touching nginx config:**
```bash
curl -s -X POST https://chatbot.david-developer.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Draw a red circle","attachments":[],"conversationHistory":[],"model":"google/gemini-3.1-flash-image-preview"}' \
  --no-buffer | head -5
```
If curl shows **complete** `data:image/png;base64,...` followed by `data: {"done":true}`, nginx is NOT the problem. The issue is browser-side SSE parsing.

**If nginx IS the problem (curl also truncated), fix with:**
```nginx
location /api/ {
    proxy_pass http://localhost:3002;
    proxy_buffering off;
    proxy_cache off;
    chunked_transfer_encoding on;
    proxy_request_buffering off;
    proxy_read_timeout 300s;
    client_max_body_size 50M;
}
# Also ensure backend sends:
res.setHeader('X-Accel-Buffering', 'no');
```

**If nginx is NOT the problem (curl works fine), fix is in the frontend SSE parser.**

**Frontend SSE parser fix — accumulate partial lines across chunks:**
```javascript
let buffer = '';
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  buffer += decoder.decode(value, { stream: true });

  // Process complete lines only; keep incomplete data in buffer
  const lines = buffer.split('\n');
  buffer = lines.pop()!; // keep incomplete line in buffer

  for (const line of lines) {
    if (line.startsWith('data: ')) {
      try {
        const data = JSON.parse(line.slice(6));
        // process data...
      } catch (e) {
        console.warn('[SSE] parse error:', e.message);
        // Don't crash — keep processing remaining lines
      }
    }
  }
}
```

**Key debugging principle:** When image/SSE fails, always test with `curl --no-buffer` through the full URL path (nginx → backend) BEFORE assuming nginx is buffering. If curl shows complete data, the bug is in browser SSE parsing, not infrastructure.

**nginx curl test checklist:**
- ✅ curl returns complete `data:image/png;base64,...` with trailing `data: {"done":true}` — nginx fine, bug in browser
- ❌ curl returns truncated base64 or hangs — nginx buffering issue → apply `proxy_buffering off` etc.

---

### Bug I: SQLite TEXT column truncates base64 image data

**Symptom:** AI generates an image (backend curl = 200, 1.4MB response), `document.querySelectorAll('img').length` returns 0, but no browser console errors. The `<img>` tag may exist but has a `src` that is a truncated base64 string (~69 characters).

**Root cause:** SQLite column defined as `TEXT` has a hard limit of ~1GB for a string, BUT the Sequelize model defined `image_url` with a validation maxLength of 255 characters. The image base64 string is 50KB–150KB. Sequelize silently truncates the value before writing to SQLite, losing most of the data.

**Evidence:**
```bash
# The file on disk is correct
ls -lh /tmp/ai-images/img-1776958433428-u9qcrz.jpg  # → 1.5MB

# But the database has only 69 characters
sqlite3 chat.db "SELECT length(image_url), substr(image_url, 1, 30) FROM messages WHERE image_url IS NOT NULL LIMIT 3;"
# → 69|"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfF"
```

**Fix — two parts:**

**1. Backend: save image to disk, store path in DB instead of base64**
```javascript
// In the SSE handler, instead of:
// message.image_url = `data:image/png;base64,${base64Data}`

// Save to disk:
const fs = require('fs');
const path = require('path');
const imageDir = '/tmp/ai-images/';
if (!fs.existsSync(imageDir)) fs.mkdirSync(imageDir, { recursive: true });

const filename = `img-${Date.now()}-${Math.random().toString(36).slice(2,8)}.jpg`;
const filepath = path.join(imageDir, filename);
fs.writeFileSync(filepath, Buffer.from(base64Data, 'base64'));

// Store path instead of base64 in DB:
message.image_url = `/ai-images/${filename}`;
```

**2. Backend: serve images as static files**
```javascript
// Add static route in server.js BEFORE the SSE streaming route:
const imageDir = '/tmp/ai-images/';
app.use('/ai-images', express.static(imageDir));
```

**3. nginx: proxy `/ai-images/` to backend (for HTTPS)**
```nginx
location /ai-images/ {
    proxy_pass http://localhost:3002;
    proxy_buffering off;
    proxy_cache off;
    add_header Cache-Control "public, max-age=31536000";
}
```

**4. Frontend: `<img>` tag already works** — `message.image_url` contains the full HTTPS URL, which is a valid `src` for `<img>`.

**DB migration (one-time):**
```sql
-- Add a new column for file paths (keep old column temporarily)
ALTER TABLE messages ADD COLUMN image_path TEXT;

-- Copy existing base64 data to disk files, store path in new column
-- (Python script recommended for large datasets)

-- Drop old column and rename new one
ALTER TABLE messages DROP COLUMN image_url;
ALTER TABLE messages ADD COLUMN image_url TEXT;
```

**Verification:**
```bash
# Backend returns file path in SSE
curl -s -X POST https://chatbot.david-developer.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Draw a cat","attachments":[],"conversationHistory":[],"model":"google/gemini-3.1-flash-image-preview"}' \
  | grep -o '"/ai-images/[^"]*"'

# File exists and is non-empty
ls -lh /tmp/ai-images/

# HTTPS URL is accessible
curl -I https://chatbot.david-developer.com/ai-images/img-1776958433428-u9qcrz.jpg
# → HTTP/2 200, Content-Length: 1492824

# Browser DevTools → Network tab: image request returns 200 with correct size
```

### Bug L: Non-image file (PDF/DOC) attachment shows nothing in chat bubble

**Symptom:** User uploads a PDF file. AI correctly reads and responds to the PDF content, but the user message bubble shows no attachment (no file icon, no filename). The `type` field in the message is `null` instead of `'file'`.

**Root cause:** Two issues in InputBar.jsx:

**Issue 1 — `type` logic checks wrong variable:**
```javascript
// WRONG — uploadedImageUrl is null for non-image files (PDFs go to /api/upload too,
// but uploadedImageUrl is only set for image/* files)
type: isImageFile ? 'image' : (uploadedImageUrl ? 'file' : null)

// RIGHT — check imageFile directly
type: isImageFile ? 'image' : (imageFile ? 'file' : null)
```

**Issue 2 — `image_url` is null for non-image files:**
```javascript
// WRONG — uploadedImageUrl is always null for PDFs (no image preview URL)
image_url: uploadedImageUrl || null

// RIGHT — for non-image files, use blob preview URL from pendingImage
image_url: isImageFile ? (uploadedImageUrl || null) : (pendingImage?.preview || null)
```

**Frontend fix in `handleSend()`.message object:**
```javascript
const isImageFile = imageFile?.type.startsWith('image/')
const userMsg = {
  id: userMsgId,
  role: 'user',
  content: userText || '',
  type: isImageFile ? 'image' : (imageFile ? 'file' : null),  // ← FIXED
  fileName: isImageFile ? null : (imageFile?.name || null),
  image_url: isImageFile ? (uploadedImageUrl || null) : (pendingImage?.preview || null),  // ← FIXED
  created_at: Date.now(),
}
```

**Also fix `attachments` array for non-image files:**
```javascript
// WRONG — attachments is empty for PDFs
const attachments = uploadedImageUrl ? [{ type: 'image', url: uploadedImageUrl }] : []

// RIGHT — include non-image files in attachments so backend processes them
const attachments = (() => {
  if (!imageFile) return [];
  if (isImageFile) return [{ type: 'image', url: uploadedImageUrl }];
  return [{ type: 'file', url: uploadedImageUrl, fileName: imageFile.name, mimeType: imageFile.type }];
})();
```

**Backend `buildMessageContent()` must handle `att.type === 'file'`:**
```typescript
// Non-image files (PDF, DOC) — backend reads file and extracts text for AI
if (att.type === 'file' && att.url) {
  const filepath = path.join(uploadsDir, path.basename(att.url));
  if (existsSync(filepath)) {
    const ext = path.extname(filepath).toLowerCase().replace('.', '');
    const fileBuffer = readFileSync(filepath);
    if (ext === 'pdf') {
      const { PDFParse } = require('pdf-parse');
      const parser = new PDFParse({ data: fileBuffer });
      const result = await parser.getText();
      content.push({ type: 'text', text: `[PDF content from ${att.fileName}]:\n${result.text.slice(0, 50000)}` });
    }
    // ... similar for doc, docx, txt
  }
}
```

**Verification:** Upload a PDF → user message bubble should show file icon + filename. AI should respond to PDF content.

### Bug M: SSE stream "Controller is already closed" causes truncated AI response

**Symptom:** AI starts responding (text streams into UI), then suddenly stops mid-sentence. Backend logs show: `Stream processing error: Invalid state: Controller is already closed`. The `done: true` message may never be sent.

**Root cause:** The backend SSE stream's `ReadableStream` controller is closed by nginx or the client before the backend finishes sending. When the catch block tries to `send({ error: ... })` on an already-closed controller, it throws. Since this happens in the outer catch block, it doesn't affect the stream output — but the error log is noisy and the `done: true` signal may be lost.

**Fix — protect all `send()` and `controller.close()` calls in the stream handler:**
```typescript
} catch (error) {
  console.error('Stream processing error:', toErrorMessage(error));
  try { send({ error: toErrorMessage(error) }); } catch {}  // ← protected
  try { controller.close(); } catch {}                     // ← protected
}
```

**Also ensure nginx is NOT buffering SSE (common cause of premature close):**
```nginx
location /api/ {
    proxy_pass http://localhost:3001;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 300s;
    chunked_transfer_encoding on;
    proxy_request_buffering off;
    tcp_nodelay on;
}
```

**Also set backend SSE response headers:**
```typescript
return new Response(stream, {
  headers: {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',  // critical for nginx
  },
});
```

**Verification:**
```bash
# Test SSE stream through nginx — should NOT be truncated
curl -s -X POST https://chatbot.david-developer.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Explain what a flowchart is","attachments":[{"type":"file","url":"/uploads/upload-xxx.pdf","fileName":"flowchart.pdf"}],"conversationHistory":[],"model":"gpt-4o"}' \
  | grep "data:" | tail -5

# Should end with: data: {"done":true} (not cut off mid-stream)
```

### Bug K: Uploaded image URL works for display but AI doesn't "see" it

**Symptom:** `POST /api/upload` saves file to `backend/uploads/` and returns `{ url: "/uploads/xxx.jpg" }`. File is accessible via HTTPS. URL is stored in DB. But AI API responds "I don't see any image" or ignores the image.

**Root cause:** AI APIs cannot access your server's local relative paths like `/uploads/xxx.jpg`. They only accept:
1. **Public HTTPS URLs** — e.g. `https://yourdomain.com/uploads/xxx.jpg`
2. **Base64 data URLs** — e.g. `data:image/png;base64,iVBORw0KG...`

**Solution — hybrid approach:** DB stores clean URL path; backend converts to base64 at request time when calling AI.

```javascript
// server.js — convert local image URLs to base64 before sending to AI
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const AI_IMAGES_DIR = path.join(__dirname, 'ai-images');

for (const att of attachments) {
  if (att.type && att.type.startsWith('image/')) {
    if (att.url && att.url.startsWith('/')) {
      // Local file — read from disk and convert to base64 for AI
      const filename = path.basename(att.url);
      const filedir = att.url.startsWith('/ai-images') ? AI_IMAGES_DIR : UPLOADS_DIR;
      const filepath = path.join(filedir, filename);
      if (fs.existsSync(filepath)) {
        const ext = path.extname(filepath).toLowerCase().replace('.', '') || 'jpeg';
        const mime = ext === 'png' ? 'image/png' : 'image/jpeg';
        const base64 = fs.readFileSync(filepath).toString('base64');
        content.push({ type: 'image_url', image_url: { url: `data:${mime};base64,${base64}`, detail: 'low' } });
      }
    } else if (att.url) {
      // External URL — pass through directly
      content.push({ type: 'image_url', image_url: { url: att.url, detail: 'low' } });
    }
  }
}
```

**Frontend upload flow:**
```javascript
// 1. Upload file → get clean URL
const { url } = await fetch('/api/upload', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` },
  body: formData
}).then(r => r.json());

// 2. Send chat with URL attachment (NOT base64)
fetch('/api/chat', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: 'What do you see?',
    conversationId,
    model,
    attachments: [{ type: 'image', url }]  // URL, not base64
  })
});
```

**nginx — serve `/uploads/` through backend:**
```nginx
location /uploads/ {
    proxy_pass http://localhost:3002;
    proxy_buffering off;
    proxy_cache off;
}
```

**Verification checklist:**
- `POST /api/upload` returns `{ url: "/uploads/xxx.jpg" }`
- `curl https://domain/uploads/xxx.jpg` returns HTTP 200
- DB `messages.image_url` contains `/uploads/xxx.jpg` (NOT base64)
- AI response correctly describes the image content

**Key principle:** Database NEVER stores base64. Store clean file paths. Convert to base64 only at AI API call time.

---

## Layer 6: AI-Generated Image Display (base64 in the text field)

### Bug N: AI image arrives as base64 data URL in `message.text`, renders as raw string

**Symptom:** Image-generation models (e.g. Gemini Flash image preview) return the image as a base64 data URL in the text/content stream. The bubble shows a long unreadable string instead of an image.

**Key distinction:**
- **User-uploaded images** → arrive in `message.attachments[]` as `{ id, name, type, url }`
- **AI-generated images** → arrive as a base64 data URL in `message.text`

Both render as `<img>`, but via different code paths.

**Fix — detect data URLs in the bubble component:**
```jsx
function isDataUrlImage(text) {
  return typeof text === 'string' && /^data:image\/[^;]+;base64,/i.test(text.trim())
}
// In MessageBubble: isDataUrlImage(text) ? <img src={text.trim()} .../> : <span>{text}</span>
```

**Anchored-regex constraint:** the check requires the string to START with `data:image/...;base64,`. Any text before or after the base64 (e.g. `"Here's the image: data:..."` or `"data:...BASE64ACK"`) breaks detection. Therefore the **backend must send the image as a clean, isolated event and suppress subsequent text chunks** once an image was sent in that response:

```js
if (hasImage) continue;  // skip delta.content chunks after the image event
```

Gemini streams image first, then a trailing text chunk ("ACK"/description); without the skip, the frontend concatenates them into an invalid data URL.

**Cosmetic gotcha:** a dark generated image can visually blend into a dark bubble background. Add `box-shadow: 0 1px 3px rgba(0,0,0,0.3)` or a faint border to the inline-image CSS.

### Bug O: Finding the real image data path in OpenRouter/Gemini SSE deltas

**Symptom:** Backend receives SSE chunks from OpenRouter for `google/gemini-3.1-flash-image-preview` but no usable image is forwarded. `delta.content` is empty for image-only responses.

**The two candidate paths:**

| Path | Content | Usable? |
|------|---------|---------|
| `delta.images[0].image_url.url` | Already a `data:image/png;base64,...` URL | Yes — use this |
| `delta.reasoning_details[0].data` | Encrypted binary reasoning trace | No — cannot be decoded client-side |

An early fix wrapped `reasoning_details[].data` in a `data:image/png;base64,` prefix — it looked plausible but the bytes are encrypted, not image base64. The reliable path is `delta.images`.

**Diagnostic — probe the raw stream with a Node one-off before touching the app:**
```js
// node -e script: call openai.chat.completions.create({ ..., stream: true })
for await (const chunk of stream) {
  const delta = chunk.choices[0]?.delta;
  if (delta?.images?.length) console.log('IMAGES:', delta.images[0]?.image_url?.url?.slice(0, 60));
  if (delta?.reasoning_details?.length) console.log('RD type:', delta.reasoning_details[0]?.type,
    'len:', delta.reasoning_details[0]?.data?.length);
}
```

**Key insight:** providers routed through OpenRouter may put image data in multiple delta fields. Always inspect the actual response structure with a probe script — not just the documented one — then forward `delta.images[0].image_url.url` as the SSE `image` event.

---

## Layer 7: User Image Attachments → Multimodal LLM

Pipeline: File input → `URL.createObjectURL(file)` blob preview → convert to base64 → POST with `attachments` → backend formats the provider's image block → LLM sees the image.

**Blob URLs cannot leave the browser.** `blob:` URLs are browser-local pointers and expire; convert back to real bytes before sending:

```javascript
async function blobToBase64(blobUrl) {
  const blob = await (await fetch(blobUrl)).blob()
  return new Promise((resolve) => {
    const reader = new FileReader()
    reader.onloadend = () => resolve(reader.result) // data:image/jpeg;base64,...
    reader.readAsDataURL(blob)
  })
}
```

**Provider image-block formats** (backend converts base64 → block; `content` must be an ARRAY of blocks when mixing image + text, not a plain string):

| Provider | Block `type` | Shape |
|----------|-------------|-------|
| Anthropic / MiniMax (Anthropic-compatible) | `'image'` | `{ source: { type: 'base64', media_type, data } }` (prefix stripped) |
| OpenAI-compatible | `'image_url'` | `{ image_url: { url: 'data:<mime>;base64,<data>', detail: 'low'\|'high' } }` (prefix kept) |

**Pitfalls:**
1. Sending a `blob:` URL to the backend — it's meaningless outside the browser.
2. Storing the blob URL in message state — dead after page reload; store the base64 data URL or an uploaded file path.
3. Forgetting to strip (Anthropic) or keep (OpenAI) the `data:image/...;base64,` prefix.
4. Large images — resize/compress before base64 to avoid API limits.
5. If the AI says "I don't see any image", the base64 never reached the API or the block format is wrong — curl the chat endpoint with a known-good attachment to isolate.

---

## Layer 8: Process / Environment-Level Bugs

### Bug P: Duplicate `getReader()` — stream consumed twice

A response body can only be read once. If the SSE handler calls `response.body.getReader()` twice (e.g. once directly and once via an intermediate variable), the second reader gets an empty stream and the UI silently shows nothing. Keep exactly one reader per response.

### Bug Q: `PayloadTooLargeError` on image requests

Base64 attachments inflate request bodies. Raise the body-parser limit: `app.use(express.json({ limit: '50mb' }))`.

### Bug R: Duplicate backend processes — cross-account data leakage

**Symptom:** User A's conversations appear in User B's account; sporadic 403s on `/api/conversations/:id/messages`; JWT verification code is correct.

**Root cause:** two `node server.js` processes listening on the same port — requests round-robin between them with mixed in-memory state.

**Diagnosis:** `ps aux | grep "node server"` (two PIDs = root cause) and `ss -tlnp | grep <port>` (must show exactly ONE listener). Then verify DB-level ownership directly with a query before suspecting the auth code.

**Fix:** `pkill` all instances, restart one, re-verify the port has a single listener.

### Bug S: Missing Authorization header in a hand-rolled fetch

**Symptom:** `POST /api/chat` returns 401 while the user is logged in; other endpoints work.

**Root cause:** most components use an `apiFetch()` wrapper that auto-injects the Bearer token, but one component hand-wrote `fetch('/api/chat', ...)` without the header.

**Debug tip:** Network tab → the failing request → Request Headers → no `Authorization: Bearer eyJ...` → this bug. Fix by using the shared wrapper (preferred) or injecting the token explicitly.

### Bug T: `attachments` arrives as a JSON string (double-encode)

If the backend receives `attachments` as `'[{"type":"image",...}]'` (string) instead of an array, a stringify happened twice on the way out. Defensive fix in the route: `if (typeof attachments === 'string') try { attachments = JSON.parse(attachments) } catch {}` — then fix the frontend serialization.

### Bug U: Two SSE parsers, one field-name mismatch (`chunk` vs `content`)

**Symptom:** Main chat streams fine, but a second entry point (e.g. landing-page chat) shows the spinner then nothing — backend curl confirms correct `{"chunk":"..."}` events.

**Root cause:** the app has more than one SSE parser, and one of them reads a different field name than the backend sends.

**Rule:** when fixing any streaming bug, grep for ALL SSE parsers (`getReader()` call sites) and verify each one reads the field names the backend actually emits. Parse with `parsed.chunk || parsed.content` style fallbacks if both exist historically.

### Vite dev proxy must cover every backend-served path

If images are served from `/ai-images/` (or `/uploads/`) by the backend, the Vite dev proxy needs an entry for each path — otherwise dev mode returns the SPA's HTML (404 fallback) instead of the image binary, and images show as broken even though production nginx works.

### Quick debug sequence (images don't appear but backend is correct)

1. `tail -50 /tmp/backend.log` — look for `PayloadTooLargeError`, image-path debug lines, SSE sends.
2. Browser console: `document.querySelectorAll('img').length` — 0 means the frontend never rendered an image node.
3. Check the SSE reader (single `getReader()`, buffer accumulator, done-after-image ordering — Bugs E/H/P).
4. Check the DB row (`image_url` NULL → attachment never reached the chat route; truncated → Bug I).
5. `localStorage.clear(); location.reload()` to reset poisoned client state before re-testing.
