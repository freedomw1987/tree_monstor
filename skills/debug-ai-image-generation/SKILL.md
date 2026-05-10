---
name: debug-ai-image-generation
description: Debug AI image generation not displaying — find correct image data path in OpenRouter/Gemini SSE responses
category: debugging
---
# Debug AI Image Generation — OpenRouter / Gemini

## Problem
AI-generated images from multimodal LLMs (via OpenRouter) don't display in the chat UI. The backend sends SSE events but no image appears.

## Diagnostic Process

### Step 1: Test the backend API directly
```bash
cd /home/ubuntu/projects/whatsapp-chatbot/backend
node -e "
require('dotenv').config();
const { OpenAI } = require('openai');
const openai = new OpenAI({
  apiKey: process.env.OPENROUTER_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
});
(async () => {
  const stream = await openai.chat.completions.create({
    model: 'google/gemini-3.1-flash-image-preview',
    messages: [{ role: 'user', content: 'Draw a red circle' }],
    stream: true,
    max_tokens: 1024,
  });
  for await (const chunk of stream) {
    const delta = chunk.choices[0]?.delta;
    // Check ALL possible image paths
    const images = delta?.images;
    const rd = delta?.reasoning_details;
    if (images?.length > 0) {
      console.log('=== IMAGES PATH ===');
      console.log('type:', images[0]?.type);
      console.log('image_url:', JSON.stringify(images[0]?.image_url)?.slice(0, 300));
    }
    if (rd?.length > 0 && rd[0]?.type === 'reasoning.encrypted') {
      console.log('=== ENCRYPTED PATH ===');
      console.log('data length:', rd[0]?.data?.length);
      console.log('first 30:', rd[0]?.data?.slice(0, 30));
    }
    if (chunk.choices[0]?.finish_reason) { console.log('FINISH'); break; }
  }
})().catch(console.error);
"
```

### Step 2: Check both paths

| Path | Content | Usable? |
|------|---------|---------|
| `delta.images[0].image_url.url` | Already a `data:image/png;base64,...` URL | ✅ Yes — use this |
| `delta.reasoning_details[0].data` | Raw encrypted binary bytes | ❌ No — cannot decode client-side |

### Step 3: Fix the backend SSE handler

Wrong (original):
```javascript
const reasoningDetails = chunk.choices[0]?.delta?.reasoning_details;
if (reasoningDetails?.length > 0) {
  for (const rd of reasoningDetails) {
    if (rd.type === 'reasoning.encrypted' && rd.data) {
      // WRONG: rd.data is encrypted binary, not base64
      res.write(`data: ${JSON.stringify({ image: `data:image/png;base64,${rd.data}` })}\n\n`);
    }
  }
}
```

Correct:
```javascript
const delta = chunk.choices[0]?.delta;

// Path 1: delta.images (preferred — already a data URL)
const images = delta?.images;
if (images && images.length > 0 && images[0]?.image_url?.url) {
  res.write(`data: ${JSON.stringify({ image: images[0].image_url.url })}\n\n`);
  hasSentImage = true;
}

// Path 2: reasoning_details (encrypted binary — skip unless images unavailable)
const reasoningDetails = delta?.reasoning_details;
if (reasoningDetails && reasoningDetails.length > 0) {
  for (const rd of reasoningDetails) {
    if (rd.type === 'reasoning.encrypted' && rd.data) {
      // Log for debug — this path is NOT directly usable
      console.log(`[DEBUG] reasoning_details received but skipping (images path available: ${!hasSentImage})`);
    }
  }
}
```

### Step 4: Restart backend and verify
```bash
pkill -f "node server.js"
cd /home/ubuntu/projects/whatsapp-chatbot/backend && node server.js > /tmp/backend.log 2>&1 &
sleep 2 && curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/
```

### Step 5: Browser console test
In Chrome DevTools Console:
```javascript
fetch('/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: 'Draw a red circle',
    model: 'google/gemini-3.1-flash-image-preview'
  })
}).then(r => r.body.getReader().read()).then(([v]) => {
  const text = new TextDecoder().decode(v);
  console.log('SSE received:', text.slice(0, 300));
});
```

Look for `{"image":"data:image/` in the output — this confirms the backend is sending image events correctly.

## Key Insight
Different providers (Google Gemini, etc.) via OpenRouter may send image data through **multiple delta fields**:
- `delta.images` — structured image objects with `image_url.url` already containing `data:` URL
- `delta.reasoning_details` — encrypted reasoning trace with binary `data` field (not directly usable)

Always test the actual API response structure, not just the documented one. The `images` path is the reliable one for Gemini 3.1 Flash via OpenRouter.
