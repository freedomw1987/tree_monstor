# Per-US File Template — `docs/US/US-XXX-<slug>.md`

> **When to use:** Plan 階段，每個 user story 一個檔。
> **No-code rule:** 不適用（描述 contract / AC，不寫 source code）。

## 必填區塊

```markdown
# US-001 — 登入

**狀態**: DONE
**優先級**: P0
**對應文件**: [PRD.md § User Story Index](../PRD.md)
**對應 QA tracker row**: US-001
**對應 regression test**: RT-001（路徑: `tests/auth/login.spec.ts`）
**最後更新**: 2026-08-02 by dev-agent

## 描述
**As** 已註冊用戶 **I want** 用 email + 密碼登入 **so that** 存取個人化功能

## 驗收標準
- [ ] Given 已註冊 email + 正確密碼, when 提交登入表單, then 200 + 跳轉 dashboard
- [ ] Given 錯誤密碼, when 提交, then 401 + 顯示「帳號或密碼錯誤」
- [ ] Given 連續 5 次失敗, when 第 6 次, then 429 + 鎖 15 分鐘

## 邊界情況（edge cases）
- 空字串 → 前端擋（HTML required），後端擋（400 INVALID_EMAIL）
- 密碼 < 8 字元 → 前端擋
- Email 不存在 vs 密碼錯誤 → 同一錯誤訊息（不洩漏哪個錯）

## Out of scope
- SSO（GitHub / Google）— 屬 US-005
- 記住我（Remember Me）— 屬 US-006

## 依賴
- US-002 註冊（必須先有帳號）

## 變更紀錄
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-08-02 | 初版 | 從 plan stage 共識落實 |
```

## 規則
- US ID 與 master index 完全一致
- 改 US → 同步 master index + QA-TRACKER + coverage/<US-id>.md + components / endpoints（如影響）
- Dev 完成 DEV_DONE 時必須 append changelog 行（含 commit SHA + 簡述）