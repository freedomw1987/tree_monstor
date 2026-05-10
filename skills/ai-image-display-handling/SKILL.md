---
name: ai-image-display-handling
description: Handle AI-generated images (base64 data URLs) that arrive in the text field rather than in attachments array
category: frontend
tags: [react, image-handling, ai-chatbot, base64]
---

# AI Image Display Handling

Handle AI-generated images (base64 data URLs) that arrive in the `text` field rather than in `attachments`.

## Problem

When AI models (e.g., Gemini Flash, Stable Diffusion via API) generate images, they often return the result as a base64 data URL embedded in the text/content stream:

```json
{ "chunk": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA..." }
```

The UI renders this as a long unreadable string instead of an actual image.

## Solution

In `MessageBubble.jsx`, detect base64 data URL patterns in `message.text` and render as `<img>`:

```jsx
function isDataUrlImage(text) {
  return typeof text === 'string' && /^data:image\/[^;]+;base64,/i.test(text.trim())
}

export default function MessageBubble({ message }) {
  const text = message.text || ''
  const isInlineImage = isDataUrlImage(text)

  return (
    <div className={`msg-row${isOutgoing ? ' outgoing' : ' incoming'}`}>
      <div className={`bubble...`}>
        {isInlineImage ? (
          <img src={text.trim()} alt="AI generated" className="bubble-img bubble-inline-img" />
        ) : (
          <span className="bubble-text">{text}</span>
        )}
        {/* attachments still handled separately */}
      </div>
    </div>
  )
}
```

## CSS

```css
.bubble-inline-img {
  width: 100%;
  max-width: 320px;
  border-radius: 6px;
  display: block;
  cursor: pointer;
  margin-top: 4px;
}
```

## Key Distinction

- **User-uploaded images** → arrive in `message.attachments[]` as objects with `{ id, name, type, url }`
- **AI-generated images** → arrive as base64 data URL in `message.text`

Both get rendered as `<img>` but via different paths.

## CRITICAL: OpenRouter Gemini Image Generation — `reasoning_details` Path

When using `google/gemini-3.1-flash-image-preview` (or other Gemini image models) via OpenRouter's OpenAI-compatible API, images do NOT come through `delta.content`. They arrive via:

```js
chunk.choices[0]?.delta?.reasoning_details
// [{ type: "reasoning.encrypted", data: "CuWzHwGPPWtf..." }]
```

The `data` field is **raw base64** (no prefix). The `delta.content` stream is **empty** for image-only responses.

### Backend SSE Streaming Fix

In `server.js`, handle image chunks BEFORE text chunks, and skip text chunks after sending an image:

```js
for await (const chunk of stream) {
  const reasoningDetails = chunk.choices[0]?.delta?.reasoning_details;
  let hasImage = false;

  if (reasoningDetails && reasoningDetails.length > 0) {
    for (const rd of reasoningDetails) {
      if (rd.type === 'reasoning.encrypted' && rd.data) {
        // Prefix with data URL so frontend can render as <img>
        res.write(`data: ${JSON.stringify({ chunk: `data:image/png;base64,${rd.data}` })}\n\n`);
        hasImage = true;
      }
    }
  }

  // CRITICAL: Skip text chunks if we already sent an image
  // Otherwise frontend concatenates "data:image/png;base64,BASE64" + "ACK"
  // resulting in an INVALID data URL that isDataUrlImage() cannot detect
  if (hasImage) continue;

  const delta = chunk.choices[0]?.delta?.content;
  if (delta) {
    res.write(`data: ${JSON.stringify({ chunk: delta })}\n\n`);
  }
}
```

### Why the `hasImage` Skip Is Necessary

Gemini Flash streams in this order:
1. Image chunk via `reasoning_details` → `data:image/png;base64,BASE64STRING`
2. Text chunk via `delta.content` → `"ACK"` or description text

If text chunks are NOT skipped, the frontend concatenates all chunks:
```
message.text = "data:image/png;base64,BASE64STRINGACK"
```
This fails the `isDataUrlImage()` regex check (`/^data:image\/[^;]+;base64,/i`) because the extra "ACK" text appended after the base64 string makes it no longer match the anchor.

**Only send the image data URL — suppress all subsequent text chunks.**

## Models Known to Return Generated Images in `text` Field

- `google/gemini-3.1-flash-image-preview` — via `reasoning_details[].data` (raw base64)
- Likely other image generation models via OpenRouter

## `isDataUrlImage()` Regex — Important Constraint

The regex `/^data:image\/[^;]+;base64,/i` is an **anchored** match. It requires the string to START with the data URL pattern. If ANY text precedes or follows the base64 string (e.g., `"Here's the image: data:image/png;base64,..."` or `"data:image/png;base64,BASE64MoreText"`), the image will NOT be detected.

**Keep `message.text` as a clean, isolated data URL for AI-generated images.**

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Image shows as long base64 text string | `message.text` contains extra text around the data URL | Backend should send only the image chunk; check for `reasoning_details` skip logic |
| `isDataUrlImage()` returns false for valid data URL | Data URL has trailing text appended | Same as above — prevent text chunk concatenation |
| Image arrives but console shows broken `src` | Data URL missing `data:image/png;base64,` prefix | Backend must prefix raw base64 with the data URL scheme |
| Image visible in DOM but visually blends with bubble background | Dark image + dark teal bubble background (`--wa-bubble-in: rgb(0,92,75)`) makes image edges hard to see | Add `box-shadow: 0 1px 3px rgba(0,0,0,0.3)` to `.bubble-inline-img` CSS, or `border: 1px solid rgba(255,255,255,0.1)` |
