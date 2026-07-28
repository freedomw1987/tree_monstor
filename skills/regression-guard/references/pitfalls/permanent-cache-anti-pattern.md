# ⚠️ Pitfall — Permanent cache = anti-pattern (RBAC / config / any admin-mutable state)

**場景**(2026-06-09 pm-system Sprint 4 RG-007):`rolePermissionCache: Map<string, string[]>` 寫入後從此不再 query DB,改完 `Role.permissions` 唔會 invalidate。User 撞 403,要 `docker compose restart backend` 先 reload。

**底層 anti-pattern**:**任何永久 cache(冇 TTL / 冇 invalidation hook / 冇 version counter 嘅 cache)都係 bug factory**。原因:
1. Admin 改 state 嗰陣,user 唔會即時見到 → silently inconsistent state
2. 撞 bug 嗰陣要 manual workaround(restart / flush)→ 冇 systematic fix
3. 開發人員「為咗 performance」加 cache,但從此冇為「state consistency」付過時間

**3 個 fix strategy**(揀邊個視乎 scale + traffic):

| Strategy | When to use | Cost | Trade-off |
|---|---|---|---|
| **A. 整個移除 cache** | Traffic 低(< 100 req/s 對 single role) | 0 | 1-2ms / req overhead(內部 system 可接受) |
| **B. 加 invalidation hook** | Admin mutation 唔頻密,可以追蹤事件 | 0.5 日 | 漏 hook 嘅 mutation 仍然 stale |
| **C. TTL + version counter** | High-scale,multi-instance | 1-2 日 | TTL window 內仍然 stale |

**David 嘅 choice(2026-06-09)** = **A 整個移除**。理由:pm-system 內部 traffic 低,1-2ms / req 完全可接受,換取「改完即時生效」嘅 invariant。

**Invariant statement**(任何 cache 寫低都必寫):
> 「Cache 內嘅 entry 必須有 explicit invalidation strategy:**TTL** / **version counter 對比 DB** / **explicit `clear` on mutation event**。**永遠唔可以「load once then forget」**。改 admin-side state 必直接影響 user-side。」

**Detection signal checklist**(出現以下就 audit 個 codebase 有冇 permanent cache):
- 任何 `const xxxCache = new Map<...>()` 喺 module scope
- 任何 `let xxxCache: ... = ...` 喺 module scope
- 任何 `useState` / `useRef` 喺 React 個 layer 上面 cache server state
- 任何 3rd-party SDK 嘅 cache config `ttl: 0` / `cache: true` 而冇 invalidation
- 任何 `globalThis.xxx` 嘅 module-level state

**Audit recipe**:
```bash
# 1. 揾 module-level Map / object
rg "new Map<" --type ts backend/src/
rg "^const \w+Cache" --type ts backend/src/

# 2. 揾 .set() 但冇對應 .delete() / .clear()
# (per-file 比較)
rg "\.set\(" backend/src/utils/cache.ts
rg "\.delete\(|clear\(" backend/src/utils/cache.ts
# set 多過 delete/clear = memory leak + stale 風險
```

**Lesson**:**永久 cache 嘅 false-economy 陷阱**。「為咗 1-2ms 性能,引入『改完要 restart』嘅 silent bug」係 bad trade。**Default**:唔 cache。需要 cache 時,先寫 invariant statement + 揀 strategy A/B/C + 寫 RG entry。
