# Per-Resource Endpoints — `docs/endpoints/<resource>.md`

> **When to use:** API 階段，每個 resource 一個檔（例：auth / users / orders）。
> **No-code rule：** JSON schema（request/response/error body）保留 — interface 規格。**不寫** TS/JS/Python 等 source 語言 fetch / axios / 客戶端範例。

## 必填區塊

```markdown
# Endpoints: auth

**對應 US**: US-001, US-005, US-006
**對應實作**: `src/routes/auth.ts`（僅 reference）

## POST /auth/login

**描述**: 用戶登入,回傳 access token + refresh token

**對應 US**: US-001

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "string (8+ chars)"
}
```

**Response 200**:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "...",
  "expires_in": 3600
}
```

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 400 | INVALID_EMAIL | Email 格式錯 |
| 401 | INVALID_CREDENTIALS | 帳號/密碼錯（不洩漏哪個錯） |
| 429 | RATE_LIMIT | 1 分鐘內超過 5 次 |

**對應 Test**: `tests/integration/auth/login.spec.ts`（RT-001）
**對應 regression hook**: RG-001 / `__qa/regression/RG-001`

## POST /auth/refresh

**描述**: 用 refresh token 換新 access token

**對應 US**: US-001

**Request Body**:
```json
{
  "refresh_token": "..."
}
```

**Response 200**:
```json
{
  "access_token": "eyJ...",
  "expires_in": 3600
}
```

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 401 | INVALID_REFRESH_TOKEN | refresh token 過期或無效 |

## POST /auth/logout

**描述**: 撤銷 refresh token（access token 自然過期）

**對應 US**: US-001

**Request Body**: empty

**Response 204**: no content

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 401 | UNAUTHENTICATED | 缺少 / 無效 access token |

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 規則
- 每個 endpoint 一段：description / Request Body / Response / 錯誤碼 / 對應 Test / 對應 regression hook
- JSON 範例必須是 interface 規格；不寫 client-side code
- QA / Regression endpoint（如 `/__qa/*`）的 `Production Behavior` 不可留空，必須明確寫 production not mounted / 404 / 403 / hard reject