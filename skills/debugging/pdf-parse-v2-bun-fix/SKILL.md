---
name: pdf-parse-v2-bun-fix
description: Fix pdf-parse v2 "not a function" error in Bun — breaking API change from v1
tags: [pdf, bun, elysia, node, debugging]
---


Last-verified: 2026-07-28
# pdf-parse v2 API Fix for Bun

## Problem

```
TypeError: require("pdf-parse") is not a function
```

PDF attachment upload fails with "400 Provider returned error" because:
1. `pdf-parse` was upgraded to v2 (2.4.5+)
2. v2 has a completely different class-based API
3. Old code uses v1 syntax: `require('pdf-parse')(buffer)`
4. v2 exports `PDFParse` class, not a callable function

## Solution

Replace the `parsePdf` function with v2 API:

```typescript
// pdf-parse v2 API — class-based with PDF.js underneath
async function parsePdf(buffer: Buffer): Promise<string> {
  const { PDFParse } = require('pdf-parse');
  const parser = new PDFParse({ data: buffer });
  const result = await parser.getText();
  return result.text;
}
```

**Old v1 API (broken):**
```typescript
const pdfParse = require('pdf-parse');
const result = await pdfParse(buffer); // TypeError: not a function
```

**Old workaround attempt (still broken):**
```typescript
// This doesn't work because pdf-parse v2 is a class, not a callable module
const parse = (pdfParse as any).default ?? pdfParse;
```

## Key Recognition Pattern

When you see:
- `require("pdf-parse") is not a function`
- AND `pdf-parse` package version is 2.x

→ The module was upgraded to v2 which has breaking API changes.

## File to Edit

`/home/ubuntu/projects/whatsapp-chatbot/backend/src/routes/chat.ts`

Search for: `parsePdf`

## Verification

After fix:
```bash
cd /home/ubuntu/projects/whatsapp-chatbot/backend
sudo systemctl restart chatbot-backend
journalctl -u chatbot-backend --since "10 seconds ago" | grep -E "(error|parsePdf|PDF)"
```

No `TypeError` or `parsePdf` errors = success.
