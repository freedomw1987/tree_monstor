# PRD.md (master) — Template

> **When to use:** Plan 階段，每個 project 都必須有 master + per-US 子檔。
> **No-code rule:** 不適用。
> **配套：** per-US 模板見 `us-template.md`；結構見 § 文件 2 of `project-documentation-standard.md`。

## 結構

```
docs/
├── PRD.md              ← master：scope、NFR、US index（指向 US/ 子檔）
└── US/
    ├── US-001-login.md
    ├── US-002-registration.md
    └── ...             ← 每 US 一個檔
```

## 必填區塊

```markdown
# <Project Name> — PRD

> **Status:** Living document. US index references US/ subfiles.

## Scope（與 PROJECT-OVERVIEW 一致，scope 變更兩邊同步）

## User Story Index

| US | 標題 | 優先級 | 狀態 | Spec |
|----|------|--------|------|------|
| US-001 | 登入 | P0 | DONE | [docs/US/US-001-login.md](US/US-001-login.md) |
| US-002 | 註冊 | P0 | IN_PROGRESS | [docs/US/US-002-registration.md](US/US-002-registration.md) |
| US-003 | 忘記密碼 | P1 | DRAFT | [docs/US/US-003-password-reset.md](US/US-003-password-reset.md) |

狀態: `DRAFT` / `IN_PROGRESS` / `DONE` / `DEPRECATED`

## Non-Functional Requirements
- 效能: response time < 200ms (p95)
- 安全: 敏感資料加密儲存,API rate limit 100 req/min
- 兼容性: 支援 Chrome/Firefox/Safari 最新兩個 major version
- 可用性: 99.9% uptime,允許每月 43 分鐘 downtime

## 假設與風險
- 假設: 用戶有 Gmail
- 風險: ...

## 變更紀錄
| 日期 | US ID | 變更 | 原因 |
|------|-------|------|------|
```

## 規則
- US 編號：`US-` + 3 位數（US-001、US-002 ...）；sub-task 用 `US-001.1`
- Per-US 檔命名：`US-XXX-<kebab-slug>.md`（例：`US-001-login.md`）
- 改 US 必同步 `docs/QA-TRACKER.md`（紅線 11）
- orchestrator inner loop Work Item 直接 reference per-US 檔，不引用 master 第 N 行