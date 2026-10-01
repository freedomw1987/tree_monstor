# Probe Naming — 探針命名 + 粒度控制

> 本檔為 regression-guard 的「探針命名最佳實踐」+「粒度控制」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：命名 + 粒度共 16 行屬於「寫探針時」的最佳實踐。

## 探針命名最佳實踐（含 Module prefix）

| ✅ 好的命名（含 Module） | ❌ 不好的命名 |
|---|---|
| `M01-user-login-returns-correct-data` | `test1` |
| `M02-api-v1-users-[id]-returns-404` | `probe1` |
| `M03-payment-validation-rejects-empty-cart` | `test_payment` |

**Module prefix 規則**（v2.9 新增）：
- 格式：`<MODULE_CODE>-<description>`（如 `M01-user-login-returns-correct-data`）
- Module 代碼定義見 `docs/system-design.md` 的「Module 切割」章節
- Module 未定義（`M00` fallback）時可省略 prefix
- Integration test 用 `INT-` prefix（如 `INT-M01-M02-checkout-flow`）標記跨 Module

## 粒度控制

| 粒度 | 說明 | 範例 |
|------|------|------|
| ❌ 太粗 | 一個功能一個探針 | `M01-user-management-works` |
| ❌ 太細 | 每一行都探針 | `M01-line-42-returns-true` |
| ✅ 適中 | 每個邏輯斷言一個探針 | `M01-user-login-returns-correct-data` |
