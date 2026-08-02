# API.md (master) — Template

> **When to use:** Plan / Build 階段（有 API 的 project）。
> **No-code rule:** 不適用於本檔（conventions + index）。Per-resource 檔才嚴格。
> **配套：** per-resource 見 `endpoint-resource-template.md`。

## 結構

```
docs/
├── API.md                ← master: conventions + endpoint index
└── endpoints/
    ├── auth.md           ← per-resource: 該 resource 全部 endpoints
    ├── users.md
    ├── orders.md
    └── ...
```

## 必填區塊

```markdown
# API Reference — <Project Name>

> **Status:** Living document. Conventions here are cross-cutting; per-resource contracts live in endpoints/.

> Base URL: `https://api.example.com/v1`
> Auth: Bearer JWT in `Authorization` header
> Content-Type: `application/json`

## Conventions

### Request format
- All request bodies are JSON
- Timestamps: ISO 8601 UTC (`2026-08-02T12:34:56Z`)
- IDs: UUID v4 unless otherwise noted
- Pagination: cursor-based, see [endpoints/users.md § List users](endpoints/users.md)

### Response format
- Success: `2xx` with JSON body
- Error: `4xx`/`5xx` with `{ error: { code, message, details? } }` body

### Error code convention
| Status | Meaning |
|--------|---------|
| 400 | INVALID_* (client-side validation) |
| 401 | UNAUTHENTICATED |
| 403 | UNAUTHORIZED / FORBIDDEN |
| 404 | NOT_FOUND |
| 409 | CONFLICT_* |
| 429 | RATE_LIMIT |
| 5xx | INTERNAL — server-side, never leaks stack |

### Auth
- Bearer JWT in `Authorization` header
- Token TTL: access 1h, refresh 30d
- Refresh endpoint: [endpoints/auth.md § POST /auth/refresh](endpoints/auth.md)

## Endpoint Index

| Resource | 規格 | Endpoints |
|----------|------|-----------|
| auth | [endpoints/auth.md](endpoints/auth.md) | POST /auth/login, POST /auth/refresh, POST /auth/logout |
| users | [endpoints/users.md](endpoints/users.md) | GET /users/{id}, PATCH /users/{id}, GET /users |
| orders | [endpoints/orders.md](endpoints/orders.md) | POST /orders, GET /orders/{id}, ... |
| ... | ... | ... |

## QA / Regression Endpoints

> Scope: dev/test/staging only. Production must not mount `/__qa/*` or must hard reject before side effects.

| Method | Path | Purpose | Auth / Guard | Data Scope | Audit | Production Behavior | Related US/RG |
|--------|------|---------|--------------|------------|-------|---------------------|---------------|
| POST | /__qa/seed | Seed deterministic fixture | QA secret + staging auth | test tenant only | yes | 404 / 403 | US-001 / RG-001 |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 生成方式
- 手工維護（小 project）
- 半自動：每個 resource 從 JSDoc/TSDoc 生成初版，agent 修飾
- 完全自動：OpenAPI/Swagger codegen

## 更新時機
- Build 前 → 先寫 API contract draft；無 API 則明確標 N/A
- 新 endpoint → 加進對應 resource 檔 + 更新 API.md index
- Request / response / error code 改動 → 同步更新 endpoint contract + TEST-COVERAGE
- Breaking change → 升 major version，保留舊版文件