# Wire-Shape Verification Recipe (Plan → Build Transition)

## 來源 (case study)

**crm-system Day 14.7** (2026-06-07): System Settings refactor (sub-route tabs) + Tax Rate feature, 12-step multi-phase plan(Steps 5-12 + retro)。Plan JSON doc 寫到 wire-shape 用 readable 命名 `defaultTaxRate`,但 backend `apps/api/src/routes/settings.ts` 嘅 actual handler 用 short name `rate` 喺 GET response + PUT body 兩邊。Step 5 (`eb1581f`) 寫 frontend `settingsApi.getTax/putTax` wrapper 跟咗 plan doc 命名,**冇 grep backend source**。Step 7 (`bd1d107`) 寫 `settings-tax.tsx` 嗰陣先 catch,fix 咗 `TaxConfig` interface + `putTax` payload 字段名同 type。損耗: 1 個多餘 commit boundary,但冇 runtime disaster(Step 12 smoke test 先驗 plan 範圍,未 trigger)。

## 問題 pattern (recurring)

Plan doc 嘅 `description` / 變量名係 **人話 readable 命名**,backend code 嘅 field name 係 **code-style 命名**(通常短、type-hinted 過)。**冇 1:1 假設**。

- Plan: "Default tax rate (%)" → 我哋命名 `defaultTaxRate`
- Backend: `prisma.systemConfig.upsert({ data: { value: rate } })` → response `rate`
- 衝突。

## Prevention recipe (5 steps)

### 1) Plan stage 完成 → grep backend source 對齊 wire shape

```bash
# 對齊 GET response shape
git grep -n "GET\|return\|json" apps/api/src/routes/<module>.ts | head -20
# 對齊 PUT body / Zod schema
git grep -n "Zod\|t.Object\|body:" apps/api/src/routes/<module>.ts
# 對齊 type def
git grep -n "interface\|type " packages/db/prisma/schema.prisma
```

### 2) Plan doc 加 "Wire shape (verified against backend)" section

```markdown
## Wire shape (verified against backend 2026-06-07)

GET  /settings/tax     → { key, rate, description?, updatedAt?, updatedBy? }
PUT  /settings/tax     body → { rate }
PUT  /settings/tax     response → TaxConfig (same as GET)

Wire field name: `rate` (NOT `defaultTaxRate` — plan description wording
differs from backend code; see commit bd1d107 for the fix).
```

### 3) Build stage wrapper commit 之前再 grep 一次

Backend 可能 plan stage 之後改咗(尤其如果有人 land 其他 plan 而改 schema)。再 grep 一次唔係 paranoia 係 cheap insurance。

### 4) 第一次實際 wire call 嘅 commit 之前,curl smoke 5 分鐘

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@local","password":"xxx"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/settings/tax | jq .
# Verify: { "key": "default_tax_rate", "rate": 0, ... } ← 字段名確認
```

Hermes 嘅 secret-redact 機制會 block shell-based multi-step auth(`sed` 攞唔到真 token);用 `python3 -c` 一次性做 login + authed request(2026-06-05 crm-system Day 6 lesson)。

### 5) 第一次 wire call 嘅 commit message 寫實 smoke 結果

```text
feat(web): First wire call to /settings/tax

Smoke: curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/settings/tax
       → 200 { "key": "default_tax_rate", "rate": 0, "description": "..." }

Wire shape (verified live against backend):
  GET  → { key, rate, description?, updatedAt?, updatedBy? }
  PUT  body → { rate }
  updatedBy is full user object { id, name, email }, NOT a string id
```

## 何時 skip 呢個 recipe

- 純 frontend refactor(無 backend contract 改動)
- Plan stage 已經由 CEO/SA subagent grep 過 backend 並 commit 咗 wire-shape doc(可直接信)
- 純 cosmetic / internal refactor(唔接 wire)

## Sub-route tab navigation (Day 14.7 Step 6-8 walkthrough)

7 個 step,每個配 commit hash:

| Step | Commit    | Work                                                            |
|------|-----------|-----------------------------------------------------------------|
| 5    | `eb1581f` | Sub-route tree + `settingsApi.{getTax,putTax}` client wrapper   |
| 6    | `72e13a2` | `components/ui/tabs.tsx` (shadcn wrapper) + `SettingsLayout` 7-tab nav (URL-driven controlled) + 刪 SettingsPage 內部 double-header |
| 7    | `bd1d107` | `pages/settings-tax.tsx` + **wire-shape fix** (Plan doc → backend actual) + `useSearchParams` pre-filter audit page |
| 8    | `8161cbd` | 5 sub-route placeholder → real pages + 5 top-level → `<Navigate replace />` backward-compat |

**Key pitfalls 編年**(每個值得 inline 落自己嘅 plan doc 嘅 "Gotchas" section):

1. **Radix `<Tabs>` controlled mode 配 NavLink → warning "missing trigger"**。每個 `<TabsTrigger>` 必須有對應 `value` + active trigger 配對;NavLink 入 `<TabsList>` 會 trigger warning。**Pick**:`TabsTrigger` + `onClick={() => navigate('/settings/' + value)}` — 失去 middle-click open-in-new-tab(acceptable for in-app nav),避 warning。

2. **Layout 包 page 之後 double-header**。Page 自己 render `h1` + 自製 button-tab strip → Layout 又 render → 視覺垃圾。**Fix**:Step 6 整 layout 嗰陣順手清 page 內部 chrome(寫埋 Step 8 extract 嘅 plan 入 comment)。

3. **Legacy route URL 保留**。5 個 `<Route path="/old"><Navigate to="/new" replace /></Route>` 一次過加,bookmark / email / chat-share link 唔會死。Plan mitigation section 寫明呢個。

4. **Cross-tab link 預填 filter**。例如 audit page 接受 `?action=SYSTEM_CONFIG_UPDATED`,從 settings-tax page 跳過去即 filtered。Page 入面 `useSearchParams()` 攞 initial state,1-2 行 code。

5. **Page header 嘅 "Phase 2 / Coming soon" placeholder button**。拆 sub-route 之前個 page 內部成日有自己嘅 tab strip(典型 "Phase 1: Pipeline / Phase 2: Tax" button),sub-route 化之後 Layout 提供 7-tab,呢啲 inline button 必須刪 — 否則 click 唔 work 之餘視覺混亂。

6. **Top-level route 唔可以一刀切刪**。5 個 admin page 嘅深層連結(從 email / chat / bookmark 嚟)要保留 redirect,Plan mitigation 嗰度寫明。`/users/:id` (user detail) 唔屬 admin,保留 verbatim;`/ai` (AiChat) 唔屬 settings,保留 verbatim。

## 相關 references

- `dev-task-memory/SKILL.md` 反例 2 section 嘅 紅線 38 條目
- `dev-task-memory/templates/shadcn-tabs-wrapper.tsx` known-good starter
- SOUL.md 紅線: 「按後端 source code 為最終依歸」(user feedback 2026-06-04,2026-06-07 wire-shape bug 再次印證)
- SOUL.md 紅線 11: 改 PRD 必更新 `docs/QA-TRACKER.md`(Plan → Build 過渡的 contract drift 屬於呢條嘅廣義應用)
