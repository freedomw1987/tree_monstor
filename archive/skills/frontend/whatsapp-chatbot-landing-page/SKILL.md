---
name: whatsapp-chatbot-landing-page
description: WhatsApp-style landing page for empty state — model selector, auto-create conversation and send first message, jump to chat
tags: [react, whatsapp, chatbot, landing-page]
---

# WhatsApp Chatbot — Landing Page Feature

## Feature Summary
When user has no conversations, show a branded landing page with:
- Big title + subtitle
- Input box (textarea) for the first prompt
- Model selector (radio/grid of AI models)
- Submit creates conversation AND auto-sends the first message, jumping to #/chat

## Architecture

### LandingPage.jsx
```jsx
export default function LandingPage({ onConversationCreated }) {
  // onConversationCreated(convId, message) — called after conversation is created
  async function handleSubmit() {
    const result = await createConversation(selectedModel)
    if (result.success) {
      onConversationCreated(result.data.id, input.trim())
    }
  }
}
```

### App.jsx — State & Handler
```jsx
const [pendingMessage, setPendingMessage] = useState(null)
const { createConversation, selectConversation } = useChat()

async function handleLandingSubmit(convId, message) {
  setPendingMessage(message)
  selectConversation(convId)
}
```

### App.jsx — Conditional Render
```jsx
{!hasConversations ? (
  <LandingPage onConversationCreated={handleLandingSubmit} />
) : (
  <>
    <Sidebar ... />
    <div className={`chat-panel ...`}>
      <ChatArea ... />
      <InputBar
        disabled={!selectedConv}
        pendingMessage={pendingMessage}
        onPendingMessageConsumed={() => setPendingMessage(null)}
      />
    </div>
  </>
)}
```

### InputBar.jsx — Auto-send pending message
```jsx
export default function InputBar({ pendingMessage, onPendingMessageConsumed }) {
  const pendingMessageConsumedRef = useRef(false)

  useEffect(() => {
    if (pendingMessage && !pendingMessageConsumedRef.current) {
      pendingMessageConsumedRef.current = true
      setText(pendingMessage)
      setTimeout(() => {
        handleSend()
        onPendingMessageConsumed()
      }, 50)
    }
  }, [pendingMessage])
}
```

## Key Design Decisions

1. **`pendingMessage` pattern** — LandingPage cannot call `sendMessage` directly (sendMessage is internal to InputBar). Instead, App.jsx holds `pendingMessage` state, passes it to InputBar which auto-triggers on mount.

2. **`pendingMessageConsumedRef`** — Prevents double-fire if `pendingMessage` changes reference on re-render.

3. **`setTimeout(..., 50)`** — Allows React state to settle before calling `handleSend()`.

4. **`hasConversations` check** — `state.conversations.length === 0` — uses ChatContext state, not prop drilling.

## CSS Variables Used (WhatsApp theme)
```css
--wa-conv-bg      /* conversation area background */
--wa-sidebar      /* sidebar background */
--wa-accent       /* green accent: #00A884 */
--wa-text-in      /* primary text */
--wa-text-sec     /* secondary text */
--wa-border       /* borders */
--wa-input-bg     /* input background */
--wa-hover        /* hover state */
```

## Files Created
- `/frontend/src/components/LandingPage.jsx`
- `/frontend/src/components/LandingPage.css`

## Files Modified
- `/frontend/src/App.jsx` — added LandingPage import, conditional render, pendingMessage state
- `/frontend/src/components/InputBar.jsx` — added pendingMessage prop + useEffect handler
