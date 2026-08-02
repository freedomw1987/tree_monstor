# ADR — Template (Michael Nygard format)

> **When to use:** Plan / Build 階段，每個重大架構決策一個 ADR。
> **位置:** `docs/architecture/NNNN-<short-title>.md`（NNNN 是 4 位數,單調遞增）

## 模板

```markdown
# ADR-NNNN — <簡短標題>

## Status
- Proposed / Accepted / Deprecated / Superseded by ADR-XXXX

## Context
[面對咩問題?有咩 constraints?有咩 forces?]

## Decision
[揀咗咩方案?具體講做咩。]

## Consequences
### Positive
- 好處 1
- 好處 2
### Negative
- 壞處 1
- 壞處 2
### Neutral
- 中性影響

## Alternatives Considered
### 方案 A — [名]
- 優: ...
- 缺: ...
- 不選原因: ...

### 方案 B — [名]
- ...

## References
- [相關連結]
```

## 規則
- **一個 ADR 一個決策**（不要一篇寫 5 個決策）
- **永遠不要修改已 Accepted 的 ADR**；要改就寫新 ADR 並在舊 ADR 標 `Superseded by ADR-XXXX`
- 用 git 歷史保留時序

## 範例命名
- `0001-use-postgres-for-primary-db.md`
- `0002-monorepo-vs-polyrepo.md`
- `0003-jwt-vs-session-auth.md`
- `0004-tailwind-v4-with-vite.md`