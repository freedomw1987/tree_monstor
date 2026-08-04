# Per-US Coverage — `docs/coverage/<US-id>.md`

> **When to use:** Test 階段，每個 US 一個檔。
> **No-code rule:** 不適用。

## 必填區塊

```markdown
# Coverage: US-001 — 登入

**對應 US**: [docs/US/US-001-login.md](../US/US-001-login.md)
**對應 RT**: RT-001
**最後更新**: YYYY-MM-DD by dev-agent

## Test inventory

### Unit tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| `tests/unit/auth/password-validator.test.ts` | 密碼強度校驗 | ✅ |
| `tests/unit/auth/login-form-validation.test.ts` | 表單欄位驗證 | ✅ |
| `tests/unit/auth/rate-limiter-token-bucket.test.ts` | 5次/15min rate limit 邏輯 | ✅ |

### Integration tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| `tests/integration/auth/login.spec.ts` | POST /auth/login + DB + JWT 簽發 | ✅ |

### E2E tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| `tests/e2e/auth/login-happy-path.spec.ts` | UI 登入 happy path | ✅ |
| `tests/e2e/auth/login-rate-limit.spec.ts` | 連續失敗觸發 429 | ✅ |

## RT-001 (regression test)
- **位置**: `tests/regression/auth/RT-001-login.spec.ts`
- **掛入開關**: `REGRESSION_MODE=1 bun test:regression`
- **斷言**: 用戶可觀察行為（200 + redirect、401 + error message、429 + 鎖定）— 不斷言實作細節
- **最後 PASS 日期**: YYYY-MM-DD

## 已知 gap
- 2FA 流程未覆蓋（US-005 範圍）
- 第三方 SSO 失敗 fallback 未覆蓋

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 規則
- 斷言必須是**用戶可觀察行為**（頁面渲染結果、API response、狀態變化），不是實作細節
- 功能型 US 完成 DEV_DONE 前，必須有對應 RT 註冊
- orchestrator checker 驗 US 時讀本檔 + 對應 US spec + 跑 RT