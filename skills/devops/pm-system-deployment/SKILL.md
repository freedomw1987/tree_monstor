---
name: pm-system-deployment
description: PM System deployment and development guide
---

# PM System Deployment Skill

## Project Location
`~/projects/pm-system/`

## Tech Stack
- Frontend: React 19 + Tailwind CSS v4 + Vite + Recharts + react-markdown (for wiki)
- Backend: Elysia.js (Bun) + Prisma + PostgreSQL
- Deployment: Docker Compose with nginx reverse proxy

## Quick Start

### Local Development
```bash
# Backend
cd ~/projects/pm-system/backend
bun run src/index.ts  # Runs on :4000

# Frontend
cd ~/projects/pm-system/frontend
bun run dev  # Runs on :3000
```

### Docker Deployment
```bash
cd ~/projects/pm-system/infra
sudo docker compose up -d --build
```

### Initial Setup (PostgreSQL)
```bash
# Create database
sudo -u postgres psql -c "CREATE DATABASE pm_system;"
sudo -u postgres psql -c "CREATE USER pm_user WITH PASSWORD 'pm_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE pm_system TO pm_user;"

# Run migrations
cd ~/projects/pm-system/backend
sudo -u postgres psql -d pm_system -c "GRANT ALL ON SCHEMA public TO pm_user;"
bunx prisma db push --force-reset
```

### Create Admin User
```bash
# Hash password
cd ~/projects/pm-system/backend
bun -e "import bcrypt from 'bcryptjs'; const hash = await bcrypt.hash('admin123', 10); console.log(hash);"

# Insert into database
PGPASSWORD=pm_password psql -h localhost -U pm_user -d pm_system -c "INSERT INTO users (id, email, name, password_hash, created_at, updated_at) VALUES ('admin-001', 'admin@company.com', 'System Admin', '\$hash', NOW(), NOW());"
```

## Known Issues

### Tailwind CSS v4 Migration
- Uses `@import "tailwindcss"` instead of `@tailwind` directives
- Uses `@theme {}` block for custom colors instead of `tailwind.config.js`
- PostCSS plugin changed to `@tailwindcss/postcss`

### TypeScript Path References
- tsconfig.json must be JSON format (not TS), with `files: []`
- tsconfig.app.json needs `ignoreDeprecations: "6.0"` to suppress baseUrl deprecation

### Prisma with Connection Pooling
- Uses `@prisma/adapter-pg` with `pg` Pool for connection pooling
- Prisma config in `prisma.config.ts` (not schema `url` field)

### Prisma Schema Changes — Critical Order of Operations
When adding new models to the Prisma schema:
1. Update `schema.prisma` with new model
2. **`npx prisma db push`** — updates the database schema (does NOT regenerate client)
3. **`npx prisma generate`** — regenerates the Prisma client types (MUST run separately!)
4. Rebuild backend: `bun build src/index.ts --outdir=dist --target=bun`
5. Deploy — restart container or copy new files

**Common bug**: After `db push`, if new model fields are `undefined`, it's because `prisma generate` was never run. The error looks like:
```
undefined is not an object (evaluating 'prisma.wikiPage.findMany')
```

**Always verify**: Check `node_modules/@prisma/client/index.d.ts` contains your new model, or inside the container: `grep WikiPage /app/node_modules/@prisma/client/index.d.ts`

### Docker Build Artifacts vs Source
The Dockerfile has `CMD ["bun", "src/index.ts"]`. If you rebuild with `bun build` (outputting to `dist/`), you must either:
- Change Dockerfile CMD to `CMD ["bun", "dist/index.js"]` AND rebuild the image, OR
- Copy the bundled `dist/index.js` into the running container manually

When the container's entrypoint/CMD runs `bun src/index.ts` (TypeScript source) but the Prisma client was generated for the bundled output, you'll get silent failures — the server starts but routes that use new Prisma models return empty/undefined.

### Docker Permission Error
- If "permission denied while trying to connect to the docker API":
  - Add user to docker group: `sudo usermod -aG docker $USER`
  - Or run with sudo: `sudo docker compose up -d --build`

### Backend Permission-System Route Updates
- Permission checks use `hasPermission` from `src/middleware/permission.ts`.
- Route-level permissions follow keys like `requirements.view`, `requirements.create`, `requirements.edit`, `requirements.delete`.
- For incremental route edits, preserve existing backward-compatible role/project-member fallbacks unless the task explicitly asks to remove them. Example for requirements: keep admin/pm role fallback and project `ProjectMember.role` checks while adding `hasPermission(user, 'requirements.*')` checks.
- Add explicit `if (!user)` guards before accessing `user.id`; several legacy routes assume authenticated context and can otherwise throw.
- Full `bunx tsc --noEmit` currently reports broad pre-existing project errors (Elysia `user` context typing and unrelated Prisma types). For a targeted route syntax/bundle verification, use:
  ```bash
  cd ~/projects/pm-system/backend
  bun build src/routes/<route>.ts --outdir /tmp/pm-system-<route>-build --target=bun
  ```

### Role Permissions Cache Bug (Critical)
The `rolePermissionCache` in `src/middleware/permission.ts` is the single source of truth for role permissions. It is loaded at startup via `refreshAllRolePermissions()` in `index.ts` and is **NOT automatically invalidated** after role mutations.

**Symptom**: After creating/updating/deleting a role in AdminPanel, admin users get 403 Forbidden on subsequent API calls that check `user.role !== 'admin'` or permission-based auth — even though they are legitimately admins.

**Fix in `src/routes/roles.ts`**: After every POST (create), PUT (update), and DELETE on roles, call `refreshAllRolePermissions()` to re-sync the cache:
```ts
// At top of roles.ts
import { rolePermissionCache } from '../middleware/permission'

// After role.create / role.update / role.delete in each handler:
// 1. Invalidate the cache entry
rolePermissionCache.delete(roleName)
// 2. Refresh all roles (avoids stale admin permissions)
const { refreshAllRolePermissions } = await import('../index')
await refreshAllRolePermissions()
```
Note: Uses dynamic `await import('../index')` to avoid circular dependency since `roles.ts` is imported by `index.ts`.

### seedRolePermissions Deduplication
`seedRolePermissions()` in `roles.ts` is called on every role route request. It uses a module-level `permissionsSeeded` flag to avoid redundant DB writes after the first call:
```ts
let permissionsSeeded = false

async function seedRolePermissions(prisma: any) {
  if (!permissionsSeeded) {
    // seed permissions and roles...
    permissionsSeeded = true
  }
  // always upsert roles (they may be edited by admin)
  await Promise.all(DEFAULT_ROLES.map(...))
}
```

### Deploying Backend to Docker Container
The production backend runs in a `restart: always` Docker container. When replacing `dist/index.js`:

**Correct sequence** (avoids corrupted file from container restart loop):
```bash
# 1. Stop container (prevents restart loop during write)
sudo docker stop pm-system-backend-1

# 2. Copy new file into container's filesystem
sudo docker cp ~/projects/pm-system/backend/dist/index.js pm-system-backend-1:/app/dist/index.js

# 3. Start container
sudo docker start pm-system-backend-1

# 4. Verify startup logs
sudo docker logs pm-system-backend-1 --tail 5
```

**What NOT to do**: `docker exec <container> tee /app/dist/index.js < dist/index.js` — the `tee` approach causes the container to restart during the write (because `restart: always` policy detects the process death), resulting in a partial/corrupted file.

### Wiki Pages Are Project-Scoped
Wiki pages (`WikiPage` model) are scoped to projects via `projectId` FK. They are **not** a standalone feature:
- Wiki pages require project membership (non-admins must be project members to view/create)
- There is NO `/wiki` standalone route or sidebar link — the WikiPage component is reserved for future embedding inside ProjectDetailPage
- If a standalone Wiki page was previously added to the sidebar nav, remove it from `Layout.tsx` navItems and remove its Route from `App.tsx`

## Test Credentials
- Email: admin@company.com
- Password: admin123

## API Endpoints
- POST /api/auth/login
- POST /api/auth/logout
- POST /api/auth/refresh
- GET/POST /api/projects
- GET/POST /api/requirements
- GET/POST /api/tasks
- GET/POST /api/bugs
- GET/POST /api/work-logs
- GET /api/reports/cost
- GET /api/reports/progress
- GET/POST/PATCH/DELETE /api/wikis (project-scoped wiki pages)

## File Structure
```
pm-system/
├── backend/
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/ (auth, users, projects, requirements, tasks, bugs, worklogs, reports, attachments, wikis)
│   │   ├── middleware/
│   │   └── utils/
│   ├── prisma/
│   │   └── schema.prisma
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── pages/ (Login, Dashboard, Projects, ProjectDetail, MyTasks, MyBugs, WorkLogs, Reports, Users)
│   │   ├── components/
│   │   ├── context/
│   │   └── utils/
│   ├── Dockerfile
│   └── nginx.conf
├── infra/
│   ├── docker-compose.yml
│   └── nginx.conf
└── docker/
    └── certs/
```