# TECH-DEBT.md — Template

> **When to use:** Build / Reflect 階段，發現 debt 就記。
> **No-code rule:** 不適用。
> **參考：** 5-field format 見 `skills/tech-debt-register/SKILL.md`（canonical）。

## 規則
- 必須 commit 入 git（放 `docs/TECH-DEBT.md`）
- 每個 sprint planning 必須 review
- 重大 debt（P0/P1）必須有對應 ticket ID

## 5-field format（每個 entry）

| Field | 說明 |
|-------|------|
| **Where** | `<file>:<line>` 或 cross-file |
| **Why** | 技術原因 |
| **Fix** | proposed code change |
| **Est** | S / M / L / XL |
| **Linked** | red-line numbers / RG-XXX / ADR-NNNN |

## Entry 範例

```markdown
### TD-001 — [簡短描述]
- **Where**: `src/api/auth.ts:42`
- **Why**: in-memory cache 在量大後會 OOM；目前無 eviction policy
- **Fix**: 換 LRU cache 或 Redis；migration path 見 ADR-0005
- **Est**: M
- **Linked**: 紅線 12 (P0 US coverage); RG-007 (cache stale 之前的 bug)
- **狀態**: OPEN / IN_PROGRESS / ✅ Fixed in <commit>
- **記錄日期**: 2026-08-02
```

## 規則
- P0 / P1 必須有 ticket ID
- 改 commit 同時 update TECH-DEBT；刪 entry 標 `✅ Fixed in <commit>`
- 按 P0 / P1 / P2 section 分組（entry 多時）