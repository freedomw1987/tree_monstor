# Probe Naming — 探針命名 + 粒度控制

> 本檔為 regression-guard 的「探針命名最佳實踐」+「粒度控制」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：命名 + 粒度共 16 行屬於「寫探針時」的最佳實踐。

## 探針命名最佳實踐

| ✅ 好的命名 | ❌ 不好的命名 |
|------------|--------------|
| `user-login-returns-correct-data` | `test1` |
| `api-v1-users-[id]-returns-404` | `probe1` |
| `payment-validation-rejects-empty-cart` | `test_payment` |

## 粒度控制

| 粒度 | 說明 | 範例 |
|------|------|------|
| ❌ 太粗 | 一個功能一個探針 | `user-management-works` |
| ❌ 太細 | 每一行都探針 | `line-42-returns-true` |
| ✅ 適中 | 每個邏輯斷言一個探針 | `user-login-returns-correct-data` |
