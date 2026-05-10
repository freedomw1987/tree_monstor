---
name: multimodal-image-chat
description: Build a chat frontend with image attachment support, sending base64 images to a multimodal LLM API (MiniMax, Anthropic, OpenAI compatible). Covers blob URL conversion, base64 encoding, and API image block formatting.
category: inference
tags: [frontend, backend, images, base64, multimodal, mini-max, anthropic, express]
---

# Multimodal Image Chat — Frontend to LLM Pipeline

## Problem Statement

Build a chat app where users can upload images and the LLM (with vision capability) can see and describe them. Requires:
1. **Frontend**: Display image previews, convert blob URLs to base64 for transport
2. **Backend**: Accept base64 images, convert to LLM provider's image block format
3. **LLM API**: Send messages with both text and image content blocks

## Architecture

```
User uploads image
  → InputBar captures File object
    → creates blob: URL (browser memory)
      → ChatArea converts blob: URL → base64 data URL
        → POST /api/chat with { message, attachments: [{type, data}] }
          → Backend extracts base64, strips data URL prefix
            → formats as LLM provider image block { type: 'image', source: {...} }
              → LLM API receives content: [image_block, text_block]
```

## Frontend: Convert Blob URL to Base64

```javascript
// In ChatArea.jsx handleSend function
async function blobToBase64(blobUrl) {
  try {
    const res = await fetch(blobUrl)
    const blob = await res.blob()
    return new Promise((resolve) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result) // data:image/jpeg;base64,...
      reader.readAsDataURL(blob)
    })
  } catch {
    return null
  }
}

const attachmentsWithData = await Promise.all(
  attachments.map(async (att) => ({
    id: att.id,
    name: att.name,
    type: att.type,
    data: att.url.startsWith('data:') ? att.url : await blobToBase64(att.url),
  }))
)
```

Key insight: `URL.createObjectURL(file)` creates a `blob:` URL that is a browser-local pointer. This cannot be sent to the backend — it must be converted back to the actual binary data via `fetch(blobUrl)` → `blob` → `FileReader.readAsDataURL()`.

## Backend: Convert Base64 to LLM Image Block

```javascript
// MiniMax / Anthropic / OpenAI-compatible image block
for (const att of attachments) {
  if (att.type?.startsWith('image/') && att.data) {
    const matches = att.data.match(/^data:([^;]+);base64,(.+)$/)
    if (matches) {
      content.push({
        type: 'image',
        source: {
          type: 'base64',
          media_type: matches[1],       // e.g. 'image/jpeg'
          data: matches[2],             // base64 string without prefix
        },
      })
    }
  }
}
// Append text
content.push({ type: 'text', text: message })

// Send to LLM
{ role: 'user', content }  // content is an ARRAY of blocks
```

## LLM API Differences

| Provider | Image Block `type` | `source.type` | `media_type` |
|----------|-------------------|---------------|--------------|
| MiniMax (Anthropic-compatible) | `'image'` | `'base64'` | `'image/jpeg'` |
| Anthropic | `'image'` | `'base64'` | `'image/jpeg'` |
| OpenAI | `'image_url'` | `'base64'` | `'image/jpeg'` |

For OpenAI vision, the content block format is:
```javascript
{
  type: 'image_url',
  image_url: {
    url: `data:${mediaType};base64,${base64Data}`,
    detail: 'high' // or 'low' | 'auto'
  }
}
```

## Frontend Message Display

In `MessageBubble.jsx`, render attachments alongside text:

```javascript
{message.attachments && message.attachments.length > 0 && (
  <div className="bubble-attachments">
    {message.attachments.map(att => (
      <div key={att.id} className="bubble-attachment">
        {att.type.startsWith('image/') ? (
          <img src={att.url} alt={att.name} className="bubble-img" />
        ) : (
          <div className="bubble-file">
            <Paperclip size={14} />
            <span>{att.name}</span>
          </div>
        )}
      </div>
    ))}
  </div>
)}
```

The `att.url` here is the base64 data URL stored in the message object — not the original blob URL (which would be lost after page refresh).

## Pitfalls

1. **Sending blob: URL to backend** — blob URLs are browser-local and expire. Must convert to base64 before fetch.
2. **Storing blob URL in message state** — if you store `URL.createObjectURL(file)` in the message, it won't persist across page reloads. Store the base64 data URL instead.
3. **LLM `content` must be an array** — when mixing images and text, `content` is `[image_block, text_block]`, not a plain string.
4. **Base64 prefix stripping** — always strip the `data:image/...;base64,` prefix before sending to the API, or re-add it when displaying.
5. **Large images** — consider resizing/compressing images before converting to base64 to avoid hitting API token limits.

## Verification

Test image upload end-to-end:
1. Upload image → image preview appears in chat bubble
2. Send → AI responds with description of the image
3. If AI says "I don't see any image" → the base64 isn't reaching the API or isn't formatted correctly
