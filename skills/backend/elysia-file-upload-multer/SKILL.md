---
name: elysia-file-upload-multer
description: Add file upload to Elysia.js (Bun) backend using Multer with static file serving
triggers:
  - "add file upload to Elysia backend"
  - "multer elysia upload endpoint"
  - "elysia static files uploads"
---

# Elysia.js File Upload with Multer + Static Serving

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