---
name: elysia-file-upload-multer
description: Add file upload to Elysia.js (Bun) backend — hand-rolled multipart parser (RECOMMENDED for Elysia 1.2) OR Multer with static file serving. Use when the user says "file upload", "attachment upload", "multipart form data", "PDF upload", "image upload" against an Elysia/Bun API.
triggers:
  - "add file upload to Elysia backend"
  - "multer elysia upload endpoint"
  - "elysia static files uploads"
  - "attachment upload endpoint"
  - "multipart form data parser"
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Elysia.js File Upload — Two Approaches

## TL;DR

For **Elysia 1.2 / Bun** projects, **use the hand-rolled multipart parser below** (Approach A). The `multer` integration in this skill is kept as Approach B for legacy / non-Elysia-1.2 projects but the `({} as any).file` callback hack is brittle and depends on multer internals that Elysia 1.2 sometimes strips.

**Why prefer the hand-rolled parser**:
- Pure Web Streams API (`request.body.getReader()`) — no Express/Connect-era middleware drama
- No `as any` casts — typed return
- Trivial to enforce per-file size limits and bail at 100 MB without buffering the whole body
- ~80 lines, no extra dependency
- Works identically in Bun, Node 18+, and the browser fetch polyfills

## Approach A — Hand-rolled multipart parser (RECOMMENDED for Elysia 1.2 / Bun)

### 1. The parser

```ts
// apps/api/src/lib/multipart.ts
const MAX_FILE_BYTES = 50 * 1024 * 1024;   // 50 MB per file
const MAX_TOTAL_BYTES = 100 * 1024 * 1024;  // 100 MB total request

export async function parseMultipart(request: Request, boundary: string): Promise<{
  files: Array<{ fieldName: string; fileName: string; mimeType: string; buffer: Buffer }>;
  fields: Record<string, string>;
}> {
  const reader = request.body?.getReader();
  if (!reader) throw new Error('No body');
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_TOTAL_BYTES) throw new Error('Upload too large');
    chunks.push(value);
  }
  const raw = Buffer.concat(chunks.map((c) => Buffer.from(c)));
  const delim = Buffer.from(`--${boundary}`);
  const files: Array<{ fieldName: string; fileName: string; mimeType: string; buffer: Buffer }> = [];
  const fields: Record<string, string> = {};
  let pos = 0;
  while (pos < raw.length) {
    const partStart = raw.indexOf(delim, pos);
    if (partStart === -1) break;
    pos = partStart + delim.length;
    if (raw[pos] === 0x2d && raw[pos + 1] === 0x2d) break;            // closing "--"
    if (raw[pos] === 0x0d && raw[pos + 1] === 0x0a) pos += 2;         // skip CRLF
    const headerEnd = raw.indexOf(Buffer.from('\r\n\r\n'), pos);
    if (headerEnd === -1) break;
    const headerText = raw.subarray(pos, headerEnd).toString('utf-8');
    pos = headerEnd + 4;
    const nextBoundary = raw.indexOf(delim, pos);
    if (nextBoundary === -1) break;
    let partEnd = nextBoundary;
    if (raw[partEnd - 2] === 0x0d && raw[partEnd - 1] === 0x0a) partEnd -= 2;
    const partBody = raw.subarray(pos, partEnd);
    const disposition = headerText.match(/Content-Disposition:\s*form-data;\s*name="([^"]+)"(?:;\s*filename="([^"]*)")?/i);
    const ctype = headerText.match(/Content-Type:\s*([^\r\n]+)/i);
    if (!disposition) { pos = nextBoundary; continue; }
    const fieldName = disposition[1];
    const fileName = disposition[2] ?? '';
    const mimeType = ctype ? ctype[1].trim() : 'application/octet-stream';
    if (fileName) {
      if (partBody.byteLength > MAX_FILE_BYTES) {
        throw new Error(`File "${fileName}" exceeds ${MAX_FILE_BYTES / 1024 / 1024} MB limit`);
      }
      files.push({ fieldName, fileName, mimeType, buffer: Buffer.from(partBody) });
    } else {
      fields[fieldName] = partBody.toString('utf-8').trim();
    }
    pos = nextBoundary;
  }
  return { files, fields };
}
```

### 2. The route

```ts
// apps/api/src/routes/activity.ts
import { mkdir, writeFile, unlink } from 'fs/promises';
import { join, extname } from 'path';
import { randomUUID } from 'crypto';
import { parseMultipart } from '../lib/multipart';
// Elysia 1.2 derive does NOT reach handler scope — re-derive inline.
import { getUserIdFromRequest } from '../middleware/rbac';

const DATA_DIR = process.env.DATA_DIR ?? '/app/data/uploads';
// Ensure the directory exists at module load. Safe to call repeatedly.
mkdir(DATA_DIR, { recursive: true }).catch((err) => {
  console.error('[upload] Failed to create DATA_DIR', DATA_DIR, err);
});

.post('/activities/:id/attachments', async ({ params, set, request }) => {
  // Day N: in Elysia 1.2, the `userId` derived by authContext does NOT
  // reach the route handler scope (only onBeforeHandle / onAfterHandle
  // hooks). See `elysia-typescript-workarounds` #17. Re-derive inline:
  const userId = await getUserIdFromRequest(request);
  if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
  const ctype = request.headers.get('content-type') ?? '';
  const m = ctype.match(/^multipart\/form-data;\s*boundary=(.+)$/i);
  if (!m) { set.status = 400; return { error: 'Content-Type must be multipart/form-data with a boundary' }; }
  const boundary = m[1].replace(/^"|"$/g, '');
  let parsed;
  try {
    parsed = await parseMultipart(request, boundary);
  } catch (err) {
    set.status = 413;
    return { error: (err as Error).message };
  }
  if (parsed.files.length === 0) {
    set.status = 400;
    return { error: 'No file provided' };
  }
  for (const f of parsed.files) {
    // IMPORTANT: never use the user's filename on disk — use a random UUID + ext
    const ext = extname(f.fileName) || '';
    const key = `${randomUUID()}${ext}`;
    await writeFile(join(DATA_DIR, key), f.buffer);
    await prisma.attachment.create({
      data: {
        activityId: params.id,
        fileName: f.fileName,
        mimeType: f.mimeType,
        sizeBytes: f.buffer.byteLength,
        storageKey: key,
        uploadedById: userId,
      },
    });
  }
  set.status = 201;
  return { count: parsed.files.length };
})
```

### 3. Frontend — FormData with React + fetch

```tsx
async function uploadFiles(activityId: string, files: FileList) {
  const fd = new FormData();
  for (const f of Array.from(files)) fd.append('file', f);   // field name must match server
  const res = await fetch(`/api/activities/${activityId}/attachments`, {
    method: 'POST',
    body: fd,
    headers: { Authorization: `Bearer ${token}` },
    // Do NOT set Content-Type — the browser sets it with the boundary
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}
```

### 4. Storage location + Docker volume (crm-system pattern)

Local disk + named volume is the simplest for demo / SMB:

```yaml
# docker-compose.yml
services:
  api:
    volumes:
      - crm_uploads:/app/data/uploads
volumes:
  crm_uploads:
```

```dockerfile
# apps/api/Dockerfile
RUN mkdir -p /app/data/uploads && chown -R bun:bun /app/data || true
```

The `mkdir` in the image is a fallback for `docker exec` use; the compose mount is what survives `docker compose down`. Use `randomUUID()`-based `storageKey` (NOT the user filename) — filename traversal (`../../etc/passwd`) is otherwise trivial.

### 5. Download — `Content-Disposition: attachment` (avoid cross-tab warning)

```ts
.get('/attachments/:id/download', async ({ params, set, request }) => {
  // Elysia 1.2: re-derive userId inline (see elysia-typescript-workarounds #17).
  const userId = await getUserIdFromRequest(request);
  if (!userId) { set.status = 401; return { error: 'Unauthorized' }; }
  const att = await prisma.attachment.findUnique({ where: { id: params.id } });
  if (!att) { set.status = 404; return { error: 'Attachment not found' }; }
  const { readFile } = await import('fs/promises');
  const buf = await readFile(join(DATA_DIR, att.storageKey));
  set.headers = {
    'Content-Type': att.mimeType,
    'Content-Disposition': `attachment; filename="${att.fileName.replace(/"/g, '')}"`,
    'Content-Length': String(att.sizeBytes),
  };
  return new Response(buf, { status: 200 });
})
```

**Frontend pattern that avoids the "leave site" popup** — use blob + `download` attribute instead of plain `<a target="_blank">`:

```ts
async function downloadAttachment(id: string, fileName: string) {
  const res = await fetch(`/api/attachments/${id}/download`, { credentials: 'include' });
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName;             // ← forces download, no popup
  a.click();
  URL.revokeObjectURL(url);
}
```

### 6. nginx body size limit (MUST match backend)

```nginx
server {
    client_max_body_size 50M;       # match the MAX_FILE_BYTES above
    ...
    location /api/ {
        proxy_send_timeout 120s;     # allow 50MB on slow links
        proxy_read_timeout 120s;
        proxy_pass http://crm_api;
    }
}
```

If you forget `client_max_body_size`, nginx returns 413 silently before the request even hits your Elysia handler — and you'll spend an hour debugging "the upload worked locally but not behind nginx."

### Approach A pitfalls

1. **Always randomise the on-disk key** — never `f.fileName` as `storageKey`. Use `randomUUID() + extname(f.fileName)`.
2. **Set nginx `client_max_body_size`** to match the backend's `MAX_FILE_BYTES` or the request dies at the edge.
3. **DELETE the file on row delete** — cascade the DB row AND `unlink` the disk file. Otherwise orphan files leak forever.
4. **`mkdir` at module load** — the named volume is mounted by compose, but the in-container path needs to exist the very first time the image boots (before the volume is mounted). Doing it in the Dockerfile is the safer location.
5. **The boundary from the header may have surrounding quotes** — strip them: `boundary.replace(/^"|"$/g, '')`.
6. **`request.body.getReader()` returns `null`** if the body has already been consumed — guard with `if (!reader) throw`.
7. **Elysia 1.2 derive context does NOT reach handler scope** — the example routes above use `getUserIdFromRequest(request)` to re-derive `userId` inline because the `authContext` `.derive()` callback only injects into `onBeforeHandle` / `onAfterHandle` hooks, not the route handler destructuring. If you write `{ params, set, userId, request } => …` expecting `userId` to come from `authContext`, you'll get `undefined` and silent 401s. See `elysia-typescript-workarounds` #17 for the full diagnosis.

---

## Approach B — Multer (legacy, brittle on Elysia 1.2)

## Trigger
Need to add file upload functionality to an Elysia.js (Bun) backend — teacher attachments, images, documents, etc.

## Stack
- Elysia.js (Bun runtime)
- Multer for `multipart/form-data` handling
- Static file serving via Elysia static plugin or custom route

## Steps

### 1. Install multer
```bash
cd ~/projects/umac_ai/backend
npm install multer
mkdir -p uploads
```

### 2. Create upload route — `src/routes/upload.ts`
```ts
import { Elysia, t } from "elysia";
import multer from "multer";
import path from "path";

const storage = multer.diskStorage({
  destination: path.join(process.cwd(), "uploads"),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.random().toString(36).slice(2)}${path.extname(file.originalname)}`;
    cb(null, unique);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  fileFilter: (_req, file, cb) => {
    const allowed = [
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.ms-powerpoint",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "image/jpeg",
      "image/png",
      "image/gif",
      "text/plain",
    ];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error("Unsupported file type"));
    }
  },
});

export const uploadRoutes = new Elysia()
  .post(
    "/api/upload",
    async ({ set, headers }) => {
      const token = headers.authorization?.replace("Bearer ", "");
      if (!token) {
        set.status = 401;
        return { error: "Authentication required" };
      }
      // ... JWT verify + role check ...

      return new Promise((resolve, reject) => {
        const multerHandler = upload.single("file");
        multerHandler({} as any, {} as any, (err: any) => {
          if (err) {
            set.status = 400;
            resolve({ error: err.message });
            return;
          }
          const file = ({} as any).file;
          resolve({
            name: file.originalname,
            url: `/uploads/${file.filename}`,
            size: file.size,
          });
        });
      });
    },
    {
      body: t.Any(),
      response: {
        200: t.Object({
          name: t.String(),
          url: t.String(),
          size: t.Number(),
        }),
      },
    }
  );
```

### 3. Register in `src/index.ts`
```ts
import { staticPlugin } from "@elysiajs/static";
import { uploadRoutes } from "./routes/upload";

app
  .use(staticPlugin({ prefix: "/uploads" }))  // Serve uploaded files publicly
  .use(uploadRoutes);
```

### 4. Frontend — send as FormData
```tsx
const formData = new FormData();
formData.append("file", fileInput.files[0]);
const res = await api.post("/upload", formData, {
  headers: { "Content-Type": "multipart/form-data" },
});
// res.data = { name, url, size }
```

## Pitfalls

1. **CRASH: `ReferenceError: t is not defined`**
   - Always import `t` from "elysia" in the upload route file, even if using `t.Any()` for body.

2. **Static serving missing**
   - Without `staticPlugin`, uploaded files are stored but not accessible. Add it before upload routes.

3. **Multer in Elysia**
   - Multer doesn't integrate as an Elysia plugin cleanly; use the Promise-wrapped approach.

4. **No auth on upload route**
   - Don't forget to check Authorization header / JWT before accepting uploads.

5. **Wrong `Content-Type`**
   - Frontend must use `multipart/form-data` and NOT set `Content-Type` header manually (browser sets it with boundary).

## Verification
1. `curl http://localhost:3000/health` — backend up
2. `curl -F "file=@test.pdf" http://localhost:3000/api/upload` — upload works
3. `curl http://localhost:3000/uploads/` — file is downloadable