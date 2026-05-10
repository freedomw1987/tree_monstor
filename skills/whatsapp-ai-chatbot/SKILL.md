---
name: whatsapp-ai-chatbot
description: WhatsApp-style AI Chatbot webapp with React + Tailwind + Vite + OpenRouter (multi-model, vision, image generation)
category: webapp
---

# WhatsApp AI Chatbot Webapp

## 快速啟動
```bash
cd ~/projects/whatsapp-chatbot

# New Backend (Elysia.js + Prisma, port 3001) — via systemd
sudo systemctl start chatbot-backend
sudo systemctl status chatbot-backend

# Old Backend (Express.js, port 3002) — DEPRECATED, stoppped
cd backend && node server.js &

# Frontend static+proxy (port 5174) — Express serves dist/ + proxies /api/* to backend
cd frontend && node server.js &
```

**重要變更（2025-04-25）**：
- 新後端：`backend-new/`（Elysia.js + Prisma + Bun runtime），port **3001**，由 systemd 管理
- 舊後端：`backend/`（Express.js），port ~~3002~~，**已停用**
- nginx proxy_pass 已更新為 `http://localhost:3001`

## 技術棧
- React + CSS (original styles, Tailwind refactor reverted) + Vite (frontend)
- **Node.js/Express 5** (frontend static server + proxy, port 5174)
- **Bun runtime + Elysia.js + Prisma ORM** (backend, port 3001, systemd-managed)
- OpenRouter API (multi-model: text, vision, image generation)

### 新舊後端對照
| | 舊後端 | 新後端 |
|--|--------|--------|
| 框架 | Express.js | Elysia.js |
| ORM | better-sqlite3 (direct) | Prisma ORM |
| Runtime | Node.js | Bun |
| Port | 3002（已停用） | 3001 |
| 入口 | `server.js` | `src/index.ts` |
| 管理 | 手動 `node server.js` | systemd `chatbot-backend` |

### Systemd Service 管理
```bash
# 查看狀態
sudo systemctl status chatbot-backend

# 重啟
sudo systemctl restart chatbot-backend

# 查看日誌
sudo journalctl -u chatbot-backend -f
```

### 環境變量（新後端）
新後端透過 systemd `Environment=` 注入，不需要 `.env`：
- `OPENROUTER_API_KEY`
- `JWT_SECRET`

如果需要在 systemd 中修改：
```bash
sudo systemctl edit chatbot-backend
# 或直接編輯 /etc/systemd/system/chatbot-backend.service
sudo systemctl daemon-reload
sudo systemctl restart chatbot-backend
```

## OpenRouter 整合
- Base URL: `https://openrouter.ai/api/v1`
- Auth: `Authorization: Bearer sk-or-v1-...`
- SDK: `openai` npm package (NOT Anthropic)
- Streaming: SSE with `data: {"chunk":"text"}\n\n` format
- Vision: `image_url` in content blocks
- Image generation (Gemini 3.1 Flash): `reasoning_details[0].data` contains base64 image

## AI 模型
| 模型 | ID | 功能 |
|------|-----|------|
| Moonshot K2.6 | `moonshotai/kimi-k2.6` | 文字 |
| GPT-5.4 | `openai/gpt-5.4` | 文字+Vision |
| GLM-5.1 | `z-ai/z-ai-plus-1` | 文字 |
| Gemini 3.1 Pro | `google/gemini-3.1-pro` | 文字 |
| Gemini 3.1 Flash (Vision) | `google/gemini-3.1-flash-image-preview` | 文字+Vision+**圖像生成** |

## 已知問題

### K2.6 Reasoning Model: Content in `reasoning` Field, Not `content`
**K2.6 (and likely other reasoning models) returns content in a `reasoning` field, NOT `content`.**
```javascript
// ❌ WRONG — works for non-reasoning models
const content = chunk.choices[0]?.delta?.content || ''

// ✅ CORRECT — K2.6 reasoning model
const reasoning = chunk.choices[0]?.delta?.reasoning || ''
const content = reasoning  // Use reasoning field for K2.6
```
- Also requires `max_tokens: 150` minimum (or `finish_reason: length` truncation occurs)
- For anything needing reliable text extraction, use `openai/gpt-4o-mini` instead (non-reasoning, stable `content` field)

### Express 5 + http-proxy-middleware Wildcard Routing Broken
**Express 5 incompatibility with `http-proxy-middleware` wildcard paths (`/api/*`).**
- Symptom: `/api/chat` proxy returns 404 or hangs
- Root cause: path-to-regexp v2/v3 breaking change in Express 5
- Fix: Use Node.js native `http.request()` instead:
```javascript
// server.js — native http proxy (works in Express 5)
const proxyReq = http.request({
  hostname: 'localhost', port: 3002, path: req.path, method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
}, (proxyRes) => {
  res.writeHead(proxyRes.statusCode, proxyRes.headers)
  proxyRes.pipe(res)
})
// Also add: app.post('/chat', ...) as alias that rewrites to /api/chat
```

### react-router-dom v7 useParams() Required for Route Params
**react-router-dom v7 的 Route params（如 `/reset/:token` 和 `/verify/:email`）不再自動透過 props 傳遞，必須用 `useParams()` 鉤子。**
- 徵兆：API 收到的請求 body 裡 token/email 欄位是 `undefined`，但 URL 是正確的
- 原因：v7 的 Route 元件不再自動 spread params 到 props
- 解決：每個讀取 URL 參數的組件都必須用 `useParams()`：
```jsx
// ❌ WRONG — token always undefined in react-router-dom v7
function ResetPassword({ token }) { ... }

// ✅ CORRECT — use useParams() hook
import { useParams } from 'react-router-dom';
function ResetPassword() {
  const { token } = useParams();
  ...
}
```
- 受影響的組件：ResetPassword.jsx, Verify.jsx（以及其他所有 `/path/:param` 路由的組件）
- 所有 auth相關頁面（ResetPassword, Verify）都使用 `href="#/path"` anchor 標籤導航

### CSS Flexbox: InputBar/MessageList Disappears on Overflow
**`.chat-area` or `.message-list` with `flex: 1` refuses to shrink, pushing InputBar off-screen.**
- Root cause: flex items default to `min-height: auto` — content size becomes minimum
- Fix: `min-height: 0` on the flex-grow container:
```css
.message-list { min-height: 0; flex: 1; overflow-y: auto; }
.chat-area { min-height: 0; flex: 1; display: flex; flex-direction: column; }
```

### Sidebar Header vs Chat Header Height Mismatch
**Sidebar header and chat header appear different heights.**
- Fix: Both use identical padding, flex-shrink, and border:
```css
.sidebar-header, .chat-header {
  padding: 12px 16px;
  flex-shrink: 0;
  border-bottom: 1px solid var(--wa-border);
}
```

### User Image Upload → LLM Vision: `type: 'image'` Not `type.startsWith('image/')`
**User uploads reach LLM but LLM says "no image provided."**
- Root cause: Backend `/api/chat` checked `att.type.startsWith('image/')` but frontend sends `type: 'image'` (no `/`)
- Both the DB storage filter AND the OpenAI content builder used `startsWith('image/')` — both silently failed
- Symptom: AI replies "I don't see any image" despite upload succeeding, DB `image_url = NULL`
- Fix: Change to `att.type === 'image'` in BOTH filter locations:
  ```javascript
  // Line ~103 — DB image_url storage
  const imageUrls = attachments
    .filter(att => att.type === 'image' && att.url && att.url.startsWith('/'))
    .map(att => att.url);

  // Line ~120 — OpenAI content builder
  if (att.type === 'image') {
    if (att.url && att.url.startsWith('/')) {
      // Read local file → convert to base64 dataUrl for OpenAI
    }
  }
  ```
- Backend also converts local `/uploads/xxx.jpg` files to `data:${mime};base64,...` before sending to OpenAI
- Verification: `curl -X POST /api/chat` with `{"type":"image","url":"/uploads/file.jpg"}` should get AI response describing the image

### Missing Auth Routes: update-profile and change-password
**Settings page "儲存資料" and "更改密碼" buttons fail with 404.**
- Root cause: `AccountSettings.jsx` calls `/api/auth/update-profile` and `/api/auth/change-password`, but these routes didn't exist in `backend/src/routes/auth.js`
- Fix: Add both routes to auth.js:
  ```javascript
  router.post('/update-profile', authMiddleware, (req, res) => {
    const { name } = req.body;
    db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name.trim(), req.user.userId);
    res.json({ success: true, message: '個人資料已更新', data: user });
  });

  router.post('/change-password', authMiddleware, (req, res) => {
    const { currentPassword, newPassword } = req.body;
    // Verify old password with bcrypt.compareSync, then hash and update
    res.json({ success: true, message: '密碼已更改' });
  });
  ```

### Mobile Settings Page: Cannot Scroll to "更改密碼" Button
**On mobile, the settings page shows the top form but the password change section is off-screen and unscrollable.**
- Root cause: `.auth-root { align-items: center }` with `min-height: 100vh` centers the card vertically — overflow above/below is hidden
- Fix in Auth.css:
  ```css
  .auth-root {
    align-items: flex-start;  /* was: center */
    overflow-y: auto;          /* new */
    -webkit-overflow-scrolling: touch;  /* new for iOS momentum scroll */
  }
  ```

### User-Uploaded Images ≠ AI-Generated Images
**User uploads show as base64 inline; AI images should show as inline `<img>`.**
- User uploaded image: `message.imageData` exists + `message.text` is empty → show 📎 attachment icon only
- AI generated image: `message.text.startsWith('data:image/')` → render inline `<img>`
- Fix in MessageBubble: check BOTH `imageData` AND `text` content type

## 專案結構
```
~/projects/whatsapp-chatbot/
  backend/                    # DEPRECATED — Express.js, port 3002, 已停用
    server.js
    .env
  backend-new/               # CURRENT — Elysia.js + Prisma + Bun, port 3001
    src/
      index.ts               # Elysia app 入口
      lib/
        prisma.ts             # Prisma client singleton
        env.ts                # 環境變量（從 systemd Environment= 讀取）
      middleware/
        auth.ts               # JWT auth guards (Elysia middleware)
      routes/
        auth.ts               # register, verify, login, forgot, reset, me, profile
        conversations.ts      # CRUD + messages (with SSE support)
        chat.ts               # SSE streaming with OpenRouter
        upload.ts             # Bun multipart file upload
    prisma/
      schema.prisma           # User, EmailVerification, PasswordReset, Session, Conversation, Message
      migrate.ts              # 數據遷移腳本（bun:sqlite）
    package.json
  frontend/
    src/
      App.jsx           # 主佈局
      components/
        Sidebar.jsx     # 對話列表、模型選擇器
        ChatArea.jsx    # 訊息泡泡、輸入框、SSE reader
        MessageBubble.jsx  # 訊息泡泡（含圖片渲染）
        MessageBubble.css  # 圖片樣式 (.bubble-inline-img)
      context/
        ChatContext.jsx  # 對話狀態（含 model 欄位、sendLandingMessage）
    dist/            # Vite build 輸出
    package.json
```

## 架構核心原則：Backend-Owns-Store

**消息必須由 Backend 直接保存到 DB，前端絕不應該在 SSE 事件後觸發額外的 API 保存調用。**

錯誤模式：前端收到 SSE 事件 → 調用 `saveMessageToDb` API → race condition + 消息順序錯亂
正確模式：Backend 在 SSE 流程中直接寫 DB → 返回 `msgId` 供前端更新 UI

```
用戶請求 → Backend 生成 msgId (UUID) → 立即寫入 DB (content='') → 返回 msgId
AI stream → Backend 收到每個 chunk → 更新 DB content → 前端只做 UI 更新
AI image → Backend 保存圖片 → 更新 DB image_url → 前端只做 UI 更新
done → Backend 標記完成
```

### SSE 事件合約（msgId 必在每個事件中）

```javascript
// 文字 chunk
{ "chunk": "partial text", "msgId": "uuid" }

// 圖片就緒（AI 生成的圖片 URL）
{ "image": "/ai-images/file.jpg", "msgId": "uuid" }

// 完成
{ "done": true, "msgId": "uuid" }
```

### 前端 Reducer 合約

```javascript
// ADD_MESSAGE: 添加新消息（已知 ID）
dispatch({ type: 'ADD_MESSAGE', payload: { id: msgId, role: 'assistant', text: '' } })

// UPDATE_MESSAGE: 更新現有消息（streaming text / image_url）
dispatch({ type: 'UPDATE_MESSAGE', payload: { id: msgId, updates: { text: '...' } } })
```

### DB 保存時序（Backend 處理）

1. 收到用戶請求 → 立即 INSERT user message（content = 用戶輸入）
2. 第一個 AI chunk 到達 → INSERT assistant message（content = ''，id = UUID）
3. 後續 AI chunks → UPDATE assistant message（content += chunk）
4. AI image 到達 → UPDATE assistant message（image_url = '/ai-images/...'）
5. done → 無需額外操作（消息已保存在 DB）

### ⚠️ 關鍵禁止事項

**禁止**：前端在 SSE 流程中調用 `saveMessageToDb` 或任何保存 API
**禁止**：後端在 streaming 完成後才保存消息
**禁止**：依賴前端 generateUUID() 或任何客戶端生成的 message ID
**禁止**：修改 `InputBar.jsx` 的 `/api/chat` fetch 時漏掉 `Authorization: Bearer ${token}` header — 這是 401 的最常見原因。永遠用 `apiFetch` 或手動加上 auth header。

### ⚠️ 已知問題

### onNewChat Silent Failure — dispatch Missing from useChat Destructuring
**`onNewChat` appears to work (modal closes) but no conversation is created. Textarea stays disabled.**
- Root cause: `const { state } = useChat()` — `dispatch` was NOT destructured, so `dispatch({ type: 'NEW_CHAT' })` was `undefined` and silently failed
- Fix: Always use `const { state, dispatch } = useChat()` in App.jsx
- Pattern: Any component using `onNewChat` or `onSelectConv` callbacks that call `dispatch` MUST have `dispatch` in the destructuring
- Symptom: No error in console, but `ADD_MESSAGE` / `NEW_CHAT` actions never fire

### AWS SES Sandbox: All Recipients Must Be Verified
**AWS SES 沙盒模式下，所有收件人 email 都必須先驗證才能發送。**
- 錯誤：`Email address is not verified. The following identities failed the check in region US-EAST-1`
- 解決：使用 AWS CLI 驗證每個新 email：
```bash
aws ses verify-email-identity --email-address user@example.com --region us-east-1
```
- 收件人會收到驗證郵件，點擊確認連結後即可收信
- **長期方案：** 申請 AWS SES 生產模式（production access）解除此限制
- Yahoo/Outlook 等公共郵箱驗證容易失敗，Gmail 相對穩定
### SSE Streaming: 每個 Chunk 都 ADD_MESSAGE（已修復）

**問題**：每個 SSE chunk 都 dispatch `ADD_MESSAGE`，造成每個 chunk 產生一個新氣泡而非更新同一個。
**根本原因**：前端嘗試在 SSE chunk 到達時創建消息，而不是等待 Backend 返回 msgId。
**修復方案**：参见上方「Backend-Owns-Store」架構。Backend 在第一個 chunk 到來時就 INSERT 消息並返回 msgId；前端收到 msgId 後 dispatch `ADD_MESSAGE`，後續 chunks 使用 `UPDATE_MESSAGE`。

### Browser Automation Daemon Crash
**Browser automation (Playwright-based) daemon crashes frequently with "socket mismatch" errors.**
- Symptom: `Daemon failed to start (socket: /tmp/agent-browser-*.sock)`
- Fix: Call `browser_navigate()` to restart — each crash requires fresh navigation
- Workaround: Use curl for API testing instead of browser automation when possible

### Cloudflared Tunnel SSE Timeout
**Free cloudflared tunnel terminates SSE connections after ~2 seconds.**
Image generation takes 15-30s → connection always drops → `net::ERR_NETWORK_CHANGED`.
- Workaround: **Always test via localhost:5174**, not the cloudflared URL
- Root cause: free tier has no connection persistence

### Vite Tree-shaking Elimination
**Standalone utility functions used only in JSX render may be tree-shaken.**
If `isDataUrlImage()` wasn't in the built bundle, inline the logic directly in JSX:
```jsx
// BAD — Vite tree-shakes this
function isDataUrlImage(text) { return text.startsWith('data:image/'); }
// ...
{isDataUrlImage(message.text) && <img src={message.text} />}

// GOOD — inline logic prevents elimination
{typeof message.text === 'string' && message.text.startsWith('data:image/') && <img src={message.text} />}
```

## LandingPage 元件（空狀態引導頁）

當用戶沒有任何對話時，顯示 LandingPage 而非空白聊天區域。

### 設計原則
- LandingPage 是一個「全屏覆蓋層」，不需要 sidebar
- 使用 `position: absolute; inset: 0` 覆蓋 `.app-shell`（因為 `.chat-panel` flex 布局會限制寬度）
- `.app-shell` 必須設 `position: relative`
- 提交時直接調用 `sendLandingMessage`（不走 InputBar），避免 race condition

### `sendLandingMessage` — ChatContext 中的完整流程
```javascript
// 在 ChatContext.jsx 中新增
const sendLandingMessage = useCallback(async (model, message, imageBase64 = null) => {
  // 1. 創建對話
  const convResult = await apiFetch('/api/conversations', { method: 'POST', body: JSON.stringify({ name: 'New Chat', model }) })
  if (!convResult.success) return convResult
  const conv = convResult.data
  dispatch({ type: 'ADD_CONVERSATION', payload: conv })
  dispatch({ type: 'SELECT_CONVERSATION', id: conv.id })

  // 2. 即時新增 user message 到 UI
  const userMsg = { id: crypto.randomUUID(), role: 'user', content: message, image_url: imageBase64, created_at: Date.now() }
  dispatch({ type: 'ADD_MESSAGE', convId: conv.id, message: userMsg })

  // 3. 保存到 DB
  await apiFetch(`/api/conversations/${conv.id}/messages`, { method: 'POST', body: JSON.stringify({ role: 'user', content: message, image_url: imageBase64 }) })

  // 4. SSE streaming
  dispatch({ type: 'SET_STREAMING', payload: true })
  // ... SSE reader loop (見下方完整實作)
  // ADD_MESSAGE / UPDATE_MESSAGE dispatch 同一般 chat
  dispatch({ type: 'SET_STREAMING', payload: false })
  return convResult
}, [])
```

### App.jsx 中的條件渲染
```jsx
// App.jsx — 沒有對話時顯示 LandingPage，有對話時顯示正常 UI
const hasConversations = state.conversations.length > 0

return (
  <div className="app-shell"> {/* position: relative */}
    {!hasConversations ? (
      <LandingPage onConversationCreated={handleLandingSubmit} />
    ) : (
      <> {/* 正常 sidebar + chat-panel */} </>
    )}
  </div>
)
```

### CSS 關鍵：覆蓋層定位
```css
/* .app-shell 必須是 relative */
.app-shell { position: relative; }

/* LandingPage 佔滿整個 app-shell */
.landing {
  position: absolute;
  inset: 0;          /* = top:0; right:0; bottom:0; left:0 */
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
}

/* 卡片不要過窄 */
.landing-container { width: 100%; max-width: 520px; }
```

### 圖片附件功能
LandingPage 的 input 框需要有圖片附件按鈕：
- hidden `<input type="file" accept="image/*">` + `useRef` 觸發
- 選擇後用 FileReader 轉 base64，顯示預覽縮圖 + X 刪除
- 提交時 `sendLandingMessage(model, message, base64Image)` 一次完成

## 部署方式

**不是 Vercel，是 nginx + Let's Encrypt。**
```bash
# 1. Build frontend
cd ~/projects/whatsapp-chatbot/frontend && npm run build

# 2. Copy dist files
cp -r dist/* /home/ubuntu/projects/whatsapp-chatbot/frontend/dist/

# 3. Reload nginx
sudo nginx -s reload

# 4. 確認新 bundle（注意 hash 每次都會變）
curl -s https://chatbot.david-developer.com/ | grep -o 'index-[^"]*\.js'

# 5. 重啟後端（如有更新）
sudo systemctl restart chatbot-backend
```

**Production domain**: `https://chatbot.david-developer.com`（不是 `chat.david-developer.com`）

**Nginx config**: `/etc/nginx/sites-available/chatbot.david-developer.com`
所有 `proxy_pass` 指向 `http://localhost:3001`（新後端）

## Streaming UI Indicator（typing/spinner）

**正確做法**：Streaming 狀態存在 Context (`isStreaming`) 中，由 InputBar 在 fetch 開始/結束時更新。

### ChatContext 新增 streaming state
```javascript
// initialState
{ isStreaming: false, generatingImage: false, ... }

// reducer
case 'SET_STREAMING': return { ...state, isStreaming: action.payload }
case 'SET_GENERATING_IMAGE': return { ...state, generatingImage: action.payload }

// provider
setStreaming: (val) => dispatch({ type: 'SET_STREAMING', payload: val }),
setGeneratingImage: (val) => dispatch({ type: 'SET_GENERATING_IMAGE', payload: val }),
```

### InputBar 更新 streaming 狀態
```javascript
// handleSend() 開始時
setStreaming(true)
dispatch({ type: 'SET_STREAMING', payload: true })

// SSE reader finally
setStreaming(false)
dispatch({ type: 'SET_STREAMING', payload: false })
```

### ChatArea 讀取並渲染
```jsx
const { isStreaming, generatingImage } = state

return (
  <>
    {/* Typing indicator — 三點動畫 */}
    {!generatingImage && isStreaming && <TypingIndicator />}
    {/* Image generating spinner */}
    {generatingImage && <ImageGeneratingIndicator />}
  </>
)
```

## Markdown 渲染

**需求**：AI 回覆以 Markdown 格式輸出，前端需要渲染為 HTML。

**安裝**：`npm install marked`（無需其他配置）

**用法**（MessageBubble.jsx）：
```jsx
import { marked } from 'marked'
marked.setOptions({ breaks: true, gfm: true })

// Incoming (AI) messages — render markdown
{!isOutgoing && (
  <span
    className="bubble-text bubble-markdown"
    dangerouslySetInnerHTML={{ __html: marked.parse(message.content) }}
  />
)}

// Outgoing (user) messages — plain text
{isOutgoing && <span className="bubble-text">{message.content}</span>}
```

**CSS 樣式**（MessageBubble.css）：
```css
.bubble-markdown p { margin: 0; }
.bubble-markdown p + p { margin-top: 4px; }
.bubble-markdown code { font-family: monospace; background: rgba(0,0,0,0.12); padding: 1px 5px; border-radius: 4px; }
.bubble-markdown pre { background: rgba(0,0,0,0.12); border-radius: 6px; padding: 8px 10px; overflow-x: auto; }
.bubble-markdown pre code { background: none; padding: 0; }
.bubble-markdown a { color: #4da6ff; text-decoration: underline; }
.bubble-markdown ul, .bubble-markdown ol { margin: 4px 0; padding-left: 20px; }
.bubble-markdown blockquote { border-left: 3px solid var(--wa-border); padding-left: 10px; }
.bubble-markdown table { border-collapse: collapse; }
.bubble-markdown th, .bubble-markdown td { border: 1px solid var(--wa-border); padding: 4px 8px; }
```

## Mobile Sidebar 狀態持久化

**需求**：手機上刷新頁面，sidebar 應保持上一次狀態（打開/關閉）。

**實現**：
```jsx
// App.jsx — initial state 從 localStorage 讀
const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(() => {
  if (typeof window !== 'undefined' && window.innerWidth < 768) {
    const saved = localStorage.getItem('mobile_sidebar_open')
    return saved === null ? true : saved === 'true'
  }
  return false
})

// 狀態變化時寫入 localStorage
useEffect(() => {
  if (window.innerWidth < 768) {
    localStorage.setItem('mobile_sidebar_open', String(isMobileSidebarOpen))
  }
}, [isMobileSidebarOpen])

// 選了對話時自動關閉 sidebar
useEffect(() => {
  const isMobile = window.innerWidth < 768
  if (selectedConv && isMobile) setIsMobileSidebarOpen(false)
}, [selectedConv])
```

## 驗證 Build
```bash
# 確認 inline image detection 在 bundle 中
grep -c "startsWith.*data:image" dist/assets/index-*.js
grep "bubble-inline-img" dist/assets/index-*.js

# 確認 ChatArea SSE reader handles chunk.image
grep "chunk.image" dist/assets/index-*.js
```

## 快速 Debug
```bash
# Backend health (新後端 port 3001)
curl http://localhost:3001/health

# SSE streaming test (text model)
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"message":"hello","model":"moonshotai/kimi-k2.6"}'

# SSE streaming test (image generation, ~17s)
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"message":"Generate an image of a red circle","model":"google/gemini-3.1-flash-image-preview"}'

# 查看後端日誌
sudo journalctl -u chatbot-backend -f --lines=50
```
