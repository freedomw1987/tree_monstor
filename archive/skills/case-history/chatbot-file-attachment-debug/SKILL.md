---
name: chatbot-file-attachment-debug
description: Debug and fix WhatsApp-style AI chatbot where PDF attachments show as broken image icons instead of file icons. Multi-layer fix across frontend, backend schema, and buildMessageContent.
tags: [elysia, prisma, react, file-upload, pdf]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# Chatbot File Attachment Bug — Debug & Fix Pattern

## Context
WhatsApp-style AI chatbot (Elysia.js + Prisma + Bun backend, React frontend). User uploads PDF/doc, but chat bubble shows "AI generated" + broken image icon instead of file icon.

## Root Cause (3-layer)
1. **Frontend**: `InputBar`/`LandingPage` never set `type: 'file'` on attachments — all treated as `type: 'image'`
2. **Backend `buildMessageContent()`** (chat.ts): skips all `type !== 'image'` attachments — PDF never sent to AI
3. **Prisma Schema**: `Message` model lacks `type`/`fileName` fields — can't distinguish file vs image

## Fix Pattern

### 1. Frontend — set `type` and `fileName` on attachment
```typescript
// InputBar: save isImage flag at upload time
const isImageFile = imageFile?.type.startsWith('image/')
// → set pendingImage.url + .isImage + .fileName

// On send: set type based on isImage
attachments: [{ type: isImageFile ? 'image' : 'file', url: ..., fileName: ... }]
```

### 2. Backend — Prisma Schema
```prisma
model Message {
  // ... existing fields
  type     String?
  fileName String?
}
```
Then `bunx prisma db push`

### 3. Backend — `buildMessageContent()` must handle file type AND be async
```typescript
async function buildMessageContent(message: string | undefined, attachments: Attachment[]) {
  const content: Array<...> = [];
  for (const att of attachments) {
    if (att.type === 'image') {
      // existing image logic
    }
    if (att.type === 'file' && att.url) {
      // PDF: extract text with pdf-parse
      // TXT/CSV: read directly
      // Others: indicate file type only
    }
  }
  return content;
}
```

**⚠️ CRITICAL**: `buildMessageContent` becomes `async` when adding PDF parsing. Update all call sites to `await`.

### 4. Types — Attachment interface
```typescript
export type Attachment = {
  type?: string;
  url?: string;
  data?: string;
  fileName?: string; // MUST add this
};
```

## Critical Pitfalls

### Patch corruption
**Problem**: Using `patch` with `old_string` that only matches partial function body (e.g. just the function signature line) can insert new content *inside* the function, orphaning the body and producing `Unexpected export` or `Unexpected }` errors.

**Prevention**: Always include full surrounding context in `old_string`. Safer: rewrite entire function blocks rather than doing inline patches on function signatures alone.

**Detection**: `bun src/index.ts` fails with "Unexpected }" or "Unexpected export" pointing deep inside the file, AND `grep -n "}"` shows orphaned closing braces. Fix by viewing lines around the error and manually restoring the function structure.

### Async functions in sync call sites
When making `buildMessageContent` async to support pdf-parse, ALL callers must `await` it. In Elysia route handlers this is fine (they're async), but check `ReadableStream` start() callbacks too.

### LLMs can't read PDF binary
Do NOT send PDF as base64 data URL to AI — LLMs can't parse raw PDF binary. Use pdf-parse v2 to extract text first, then send as text block. Install: `bun add pdf-parse`.

**⚠️ pdf-parse v2 has a breaking API change** — v2 (2.x) is class-based and NOT a drop-in replacement for v1.x. The old `require('pdf-parse')(buffer)` pattern will throw `TypeError: require("pdf-parse") is not a function`.

Correct v2 usage:
```typescript
async function parsePdf(buffer: Buffer): Promise<string> {
  const { PDFParse } = require('pdf-parse');
  const parser = new PDFParse({ data: buffer });
  const result = await parser.getText();
  return result.text;
}
```

## Critical Bug Pattern: Optimistic Message Overwritten by SET_MESSAGES

**Symptom**: User uploads PDF, sends message. AI reply appears but user's own message bubble is missing. The message exists in DB but disappears from UI.

**Root Cause (Race Condition)**:
1. LandingPage/InputBar calls `dispatch(ADD_MESSAGE)` — creates optimistic user message in Redux store
2. Navigation triggers ChatArea mount
3. ChatArea `useEffect` on `selectedId` change calls `SET_MESSAGES` with data from API
4. ⚠️ **Problem**: At this moment, the user message is NOT yet saved to DB (it only gets saved during the SSE stream)
5. `SET_MESSAGES` reducer does a **full REPLACE** (`state.messages[convId] = payload`) — overwrites the optimistic message with an empty array
6. User message vanishes from UI permanently

**Fix**: `SET_MESSAGES` reducer must **MERGE** instead of REPLACE:
```typescript
case 'SET_MESSAGES': {
  const existing = state.messages[action.convId] || []
  const incoming = action.payload || []
  const existingIds = new Set(existing.map(m => m.id))
  const newMessages = incoming.filter(m => !existingIds.has(m.id))
  return {
    ...state,
    messages: {
      ...state.messages,
      [action.convId]: [...existing, ...newMessages],
    },
    loadingMessages: false,
  }
}
```

**How to Detect This Pattern**:
- User message disappears after navigation to ChatArea
- Message IS in DB (check `/api/conversations/:id/messages`)
- MessageBubble renders correctly when `type: 'file'` is set
- But optimistic message vanishes before SSE completes

**When This Happens**: Any time an optimistic user message is added locally, and a `SET_MESSAGES` API call fires before the message is persisted to the database. Common in optimistic UI patterns with async streaming endpoints.

## Verification
After fix:
1. Upload PDF → should show document icon (not image thumbnail)
2. Backend `buildMessageContent()` → PDF text extracted and sent to AI
3. MessageBubble → `type: 'file'` → shows file icon with filename
4. **CRITICAL**: User's own message bubble appears IMMEDIATELY (optimistic), not just after SSE completes
5. Confirm: User message persists even if you refresh the page
