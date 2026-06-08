// Day 7: working Elysia 1.2 requirePermission plugin with DB-driven RBAC
// Combines Step 3 (cache + clearRoleCache) + Step 9 (jose direct verify)
//
// Place at: apps/api/src/middleware/rbac.ts
// Requires: @crm/db (prisma), @elysiajs/jwt (peerDep, for jwtVerify), jose (transitive)

import { Elysia } from 'elysia';
import { jwtVerify } from 'jose';
import { prisma } from '@crm/db';

const CACHE_TTL_MS = 5 * 60 * 1000;

// roleId -> { permissions: Set<string>, expiresAt: number }
const cache = new Map<string, { permissions: Set<string>; expiresAt: number }>();

async function loadRolePermissions(roleId: string): Promise<Set<string>> {
  const cached = cache.get(roleId);
  if (cached && cached.expiresAt > Date.now()) return cached.permissions;

  const rows = await prisma.rolePermission.findMany({
    where: { roleId },
    select: { permission: true },
  });
  const set = new Set(rows.map((r) => r.permission));
  cache.set(roleId, { permissions: set, expiresAt: Date.now() + CACHE_TTL_MS });
  return set;
}

export function clearRoleCache(roleId?: string) {
  if (roleId) cache.delete(roleId);
  else cache.clear();
}

export async function userHasPermission(userId: string, perm: string): Promise<boolean> {
  const u = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, role: true },
  });
  if (!u) return false;
  let roleId = u.roleId;
  if (!roleId) {
    const r = await prisma.role.findUnique({ where: { name: u.role } });
    if (!r) return false;
    roleId = r.id;
  }
  return (await loadRolePermissions(roleId)).has(perm);
}

// Re-verify JWT in the middleware — see references/elysia-plugin-boundary-derive.md
// for why we don't rely on the upstream authContext derive.
async function getUserIdFromRequest(request: Request): Promise<string | null> {
  const auth = request.headers.get('authorization');
  if (!auth?.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret) return null;
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret));
    if (!payload || typeof payload !== 'object') return null;
    return (payload as { userId?: string; sub?: string }).userId
      ?? (payload as { sub?: string }).sub
      ?? null;
  } catch {
    return null;
  }
}

export function requirePermission(permission: string) {
  return new Elysia({ name: `require-permission:${permission}` }).onBeforeHandle(
    { as: 'scoped' },
    async (ctx: { request: Request; set: { status?: number } }) => {
      const { request, set } = ctx;
      const userId = await getUserIdFromRequest(request);
      if (!userId) {
        set.status = 401;
        return { error: 'Unauthorized' };
      }
      const allowed = await userHasPermission(userId, permission);
      if (!allowed) {
        set.status = 403;
        return { error: `Forbidden: missing permission '${permission}'` };
      }
    }
  );
}

export function requireAnyPermission(...permissions: string[]) {
  return new Elysia({ name: `require-any-permission:${permissions.join('|')}` }).onBeforeHandle(
    { as: 'scoped' },
    async (ctx: { request: Request; set: { status?: number } }) => {
      const { request, set } = ctx;
      const userId = await getUserIdFromRequest(request);
      if (!userId) {
        set.status = 401;
        return { error: 'Unauthorized' };
      }
      for (const p of permissions) {
        if (await userHasPermission(userId, p)) return;
      }
      set.status = 403;
      return { error: `Forbidden: need one of [${permissions.join(', ')}]` };
    }
  );
}
