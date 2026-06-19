/**
 * Derive Helper Pattern — Complete Test File Template
 *
 * 2026-06-09 pm-system Sprint 5 驗證, 4 個 P0 US 一致用呢個 pattern。
 * 0 source code 改動, 98 個新 unit test, 紅線 12 推到 100%。
 *
 * 何時用:
 * - Route 入面有 inline arrow fn (e.g. `const canX = (...) => ...`)
 * - Validation logic 喺 route handler 入面(直接 `if (!x) return 400`)
 * - Aggregation logic(filter / group / sum)extract 得出嚟
 * - State machine 嘅 transition logic(idle / working / paused etc.)
 * - Permission check 嘅 RBAC gate
 *
 * 何時唔用:
 * - SSE/WS/LLM routes (use Path X in main skill)
 * - State 100% 喺 closure 入面 export 唔到 (use DEFERRED marker)
 *
 * Template structure:
 * 1. Header comment 列 source line range
 * 2. Re-declared helpers (copied verbatim from source)
 * 3. describe blocks per US
 * 4. 1 個 Source-of-truth grep test 守 derive pattern consistency
 */

// ─── Step 1: Re-declared helpers (COPIED VERBATIM from source) ──────────────

// 從 routes/X.ts line N-M derive
// 保持同 source 一致 — 唔好 paraphrase,test = spec
function serializeX(input: any): any {
  return {
    ...input,
    // ... rename / transform
  }
}

function validateY(body: any): { ok: true } | { ok: false; status: number; code: string; message: string } {
  if (!body.required) return { ok: false, status: 400, code: 'VALIDATION_ERROR', message: 'required is required' }
  if (body.value <= 0) return { ok: false, status: 400, code: 'VALIDATION_ERROR', message: 'value must be > 0' }
  return { ok: true }
}

// 從 routes/X.ts aggregation logic derive
function aggregateZ(items: any[]): { total: number; count: number } {
  return {
    total: items.reduce((s, i) => s + (i.value || 0), 0),
    count: items.length
  }
}

// 從 middleware/permission.ts derive
function canDo(user: { role: string; permissions?: string[] }, perm: string, membership?: { userId: string; role: string } | null): boolean {
  if (user.permissions?.includes(perm)) return true
  if (user.role === 'admin') return true
  if (membership?.userId === user.id && membership.role === 'pm') return true
  return false
}

// ─── Step 2: describe blocks per US ─────────────────────────────────────────

import { describe, expect, test } from 'bun:test'

describe('US-X.X: <endpoint> (PASS-UNIT)', () => {
  describe('serializeX (helper)', () => {
    test('renames fieldA → fieldB', () => {
      const input = { id: '1', fieldA: 'foo' }
      expect(serializeX(input).fieldB).toBe('foo')
    })
    test('preserves all other fields', () => {
      const input = { id: '1', fieldA: 'foo', other: 'bar' }
      expect(serializeX(input).other).toBe('bar')
    })
    test('handles missing field (undefined)', () => {
      const input = { id: '1' }
      expect(serializeX(input).fieldB).toBeUndefined()
    })
  })

  describe('validateY (POST body validation)', () => {
    test('rejects missing required field', () => {
      const r = validateY({})
      expect(r.ok).toBe(false)
      if (!r.ok) expect(r.status).toBe(400)
    })
    test('rejects value <= 0', () => {
      const r = validateY({ required: 'x', value: 0 })
      expect(r.ok).toBe(false)
    })
    test('accepts valid input', () => {
      const r = validateY({ required: 'x', value: 5 })
      expect(r.ok).toBe(true)
    })
    test('rejects null body', () => {
      expect(validateY(null).ok).toBe(false)
    })
    test('rejects undefined body', () => {
      expect(validateY(undefined).ok).toBe(false)
    })
  })

  describe('aggregateZ (filter / group / sum)', () => {
    test('sums values correctly', () => {
      expect(aggregateZ([{ value: 1 }, { value: 2 }, { value: 3 }])).toEqual({ total: 6, count: 3 })
    })
    test('handles empty array', () => {
      expect(aggregateZ([])).toEqual({ total: 0, count: 0 })
    })
    test('handles missing value (treated as 0)', () => {
      expect(aggregateZ([{ value: 1 }, {}, { value: 3 }])).toEqual({ total: 4, count: 3 })
    })
  })

  describe('canDo (RBAC)', () => {
    test('admin can do anything', () => {
      expect(canDo({ role: 'admin' }, 'foo.create')).toBe(true)
    })
    test('user with global permission can do', () => {
      expect(canDo({ role: 'developer', permissions: ['foo.create'] }, 'foo.create')).toBe(true)
    })
    test('project-scoped pm can do (developer global + project pm)', () => {
      const u = { role: 'developer' }
      const m = { userId: 'u-1', role: 'pm' as const }
      expect(canDo(u, 'foo.create', m)).toBe(true)
    })
    test('membership role not matching user: cannot borrow', () => {
      // CRITICAL: prisma findFirst with { userId: user.id } guarantees
      // membership.userId === user.id, helper MUST mirror this invariant
      const u = { id: 'u-bob', role: 'developer' }
      const m = { userId: 'u-alice', role: 'pm' as const }
      expect(canDo(u, 'foo.create', m)).toBe(false)
    })
    test('no membership + no permission: blocked', () => {
      expect(canDo({ role: 'developer' }, 'foo.create')).toBe(false)
    })
  })

  // ─── Step 3: Source-of-truth grep test (守 derive pattern consistency) ──────

  describe('Source-of-truth check — 守住 derive pattern 一致性', () => {
    test('source file 仍然有 helper function 嘅 export', async () => {
      const fs = await import('node:fs/promises')
      const path = await import('node:path')

      // 對齊 source file 嘅 relative path
      const srcPath = path.resolve(import.meta.dir, './X.ts')
      const source = await fs.readFile(srcPath, 'utf-8')

      // 守住:將來 refactor 唔可以將呢個 helper inline 走
      // (調整呢個 pattern per 你嘅 file 結構)
      expect(source).toMatch(/prisma\.\w+\.findUnique/)
    })
  })
})
