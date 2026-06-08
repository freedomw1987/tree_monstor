# Reference example: crm-system System Settings plan (2026-06-07)

> **Why this is in the skill**: This is the plan doc that was the trigger for extracting `feature-plan-alignment`. It demonstrates the 12-section template, the "questions resolved" table pattern, the file-impact estimate, and the final "David confirm" ask.

## Full source (lightly trimmed)

```markdown
# 2026-06-07 — System Settings 重構 + Tax Rate 設定 Plan

> **Stage:** Plan (David 揀咗 B 慢一慢 — 寫 plan doc 畀 David review 先)
> **Author:** Developer (main agent)
> **Status:** ⏸ Awaiting David approval
> **Branch:** 仲未開 — 喺 main 直接寫 plan doc, 實作時先 fork

---

## 1. 觸發原因
David 2026-06-07 觀察:
- 5 個 admin page(Users / Roles / AI 設定 / Man-day roles / Audit log)各自有 nav link,admin 操作要跳來跳去
- Settings page 嘅 Tax rate tab 係 `disabled cursor-not-allowed`(Phase 2 TODO)
- 期望:集中去「系統設置」一個 hub 搞晒所有 admin 嘢,加 Tax rate 設定

## 2. Plan questions resolved (David 揀咗)

| Question | Option | Detail |
|----------|--------|--------|
| 點樣收埋 admin pages 入 系統設置 | **A) Tabs (sub-routes)** | `/settings/{pipeline,tax,users,roles,ai,man-day,audit}`。 Deep link 仍 work。 |
| Tax rate 點同 quotation 互動 | **A) 預設值 (per-quotation 可覆寫)** | Quotation builder 用系統預設, sales 可逐張 override。Historical 唔變。 |
| Tax rate 跨區域定 per-region | **A) 全公司單一稅率** | 起步 1 個 row, 將來 per-region 簡單加。 |

## 3. Sub-route 結構
| URL | Component 來源 | Phase | 備註 |
|-----|---------------|-------|------|
| `/settings` | redirect → `/settings/pipeline` | — | 現有 default |
| `/settings/pipeline` | 現有 `settings.tsx` (Phase 1) | ✅ Done | Day 11 已 ship |
| `/settings/tax` | **新寫** `settings-tax.tsx` | 🆕 | 見 §4 |
| `/settings/users` | wrap 現有 `users.tsx` | 🔀 搬 | 頁面內容不變, 只外面包 SettingsLayout |
| `/settings/roles` | wrap 現有 `roles.tsx` | 🔀 搬 | 同上 |
| `/settings/ai` | wrap 現有 `ai-config.tsx` | 🔀 搬 | 同上 |
| `/settings/man-day` | wrap 現有 `man-day-roles.tsx` | 🔀 搬 | 同上 |
| `/settings/audit` | wrap 現有 `audit.tsx` | 🔀 搬 | 同上 |

## 4. Tax Rate 設計
[Prisma snippet, endpoint design, audit pattern — full detail]

## 5. Backend endpoint
- `GET /api/settings/tax` → `{ rate: 5.00, updatedAt, updatedByName }`
- `PUT /api/settings/tax` body `{ rate: 5.00 }` → 200 + audit `SYSTEM_CONFIG_UPDATED`

## 6. Frontend wiring
[quotation-builder.tsx change, useQuery pattern]

## 7. RBAC 影響
[settings:read / settings:update permission matrix]

## 8. Nav layout 改動
[adminNavItems diff, backward-compat Navigate]

## 9. 實作 steps (預 4-6 小時, 4-6 commits)
1. DB migration: SystemConfig + seed
2. Backend: /settings/tax + AuditAction enum
3. RBAC: settings:* permissions
4. Frontend routes: App.tsx + 5 Navigate
5. SettingsLayout: new tab nav
6. Page wrappers × 5
7. Tax Rate tab UI
8. Quotation builder wire
9. Nav layout
10. Smoke + revert detection

## 10. 影響範圍 (file 預估)
| Area | Files | Est lines |
|------|-------|-----------|
| DB schema + migration + seed | schema.prisma + migration + seed.ts | +50 |
| Backend route | settings.ts | +60 |
| RBAC | permissions.ts + seed | +10 |
| Frontend routes | App.tsx | -5 + 35 |
| SettingsLayout | settings-layout.tsx (新) | +90 |
| Settings-tax page | settings-tax.tsx (新) | +80 |
| Quotation builder | quotation-builder.tsx | +20 |
| Nav layout | app-layout.tsx | -8 + 15 |
| API client | lib/api.ts | +15 |
| AuditAction enum | schema.prisma | +1 |
| Docs | PRD + QA-TRACKER + retro | +180 |
| **Total** | **~12 files** | **~+540 / -13** |

## 11. Ship gate 影響
- 紅線 11 ✅ auto-satisfy (commit PRD + QA-TRACKER 一齊)
- 紅線 13 不 trigger
- 紅線 16 要加 1 個 integration smoke
- 紅線 18 不 trigger

## 12. 唔做嘅嘢 (P1/P2 backlog)
- Settings RWD mobile deep optimization(P1)
- Settings breadcrumb + 「unsaved changes」提示(P2)
- Per-region tax rate 拆分(P2 - 將來加)
- Settings landing 「最近修改」summary(P2)
- 其他 system default 搬入 SystemConfig(P2)

---

## 13. 決策點 — David 確認
呢個 plan 接受?**3 個 direction 揀咗 A 全部**, 5 個 sub-route 搬遷策略 + Tax rate 預設值設計 + RBAC 新 permission — 全部 reasonable defaults。

如果 plan OK 我就:
1. 開新 branch `feat/system-settings-tabs-2026-06-07`
2. 攞返 David 嘅 stash
3. 跟 §9 嘅 10 步 plan 行
4. 跑 smoke + 出 evidence
5. PR + merge
```

## What makes this a good reference

- **Section 2 is short** — just the table of resolved questions, not the full comparison. The full comparison happened in the `clarify` tool calls BEFORE the plan was written.
- **Section 10 has a real estimate** — `+540 / -13 lines, 12 files` — not handwaving like "moderate effort". David can read the file list and immediately spot if scope is wrong.
- **Section 11 explicitly says which red-lines apply** — the QA gate is a real concept in this project (from `SOUL.md` 紅線 10-18), and any plan that touches it has to acknowledge it.
- **Section 12 protects scope** — explicitly listing what you WON'T do prevents David from assuming you're including those things.
- **Section 13 ends with a clear next-step** — `揀一個` from a 3-option menu (A approve / B change plan / C shrink scope). David's response can be one word.

## Anti-patterns to avoid

- ❌ Writing 30+ options when David only asked about 3 — pick the 3 David surfaced, not the 30 you thought of
- ❌ "I'll explore and come back with a plan" — explore WHILE writing the plan, the plan IS the exploration
- ❌ "The plan will be X hours of work" without a breakdown — always show the step list (§9)
- ❌ No `chosen_by` field on decisions — every decision needs provenance
