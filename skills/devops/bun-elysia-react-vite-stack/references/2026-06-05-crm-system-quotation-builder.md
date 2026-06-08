# 2026-06-05 — crm-system Day 4 (Quotation Builder)

## Session 摘要

承接 Day 3 Docker stack 跑緊 (3 container healthy at `http://localhost`)。
用戶確認 Day 4 scope: 「Quotation builder UI 幫我完善, 我想基本功能是可以給用戶用到先」。

## 用戶關鍵偏好 (要 encoded 入 SKILL)

**David 對 quotation builder 嘅偏好**:
- 唔淨係 list + detail, 要真正可創建 + 編輯 + 發送 + 列印
- 同一個 component handle create + edit (唔好分兩個 form)
- 創建要 quick: 揀客戶 → 揀 product → 改數量 → 改 tax rate → save
- Detail page 嘅 actions 按 status 顯示 (DRAFT 可以編輯/發送, SENT 可以接受/拒絕, ACCEPTED 可以轉發票)

呢個 preference **已經 patch 入 `bun-elysia-react-vite-stack` 嘅「Quotation builder form」section 隱含**。下次再做 CRM / 報價單 app 要 default 跟呢個 pattern。

## Day 4 實際做咗

### Backend (`apps/api/src/routes/quotation.ts`)
- **Auth guard 修正** — `POST /quotations` 由 body 拎 `createdById` 改用 `authContext` derive 由 JWT 拎 (用戶唔應該 trust client)
- **Header PATCH** — `PATCH /quotations/:id` 升級做改 title/notes/validUntil/taxRate/status, 改 taxRate 自動 recalc
- **Status transition shortcut** — `POST /quotations/:id/status` 設 status + auto set sentAt/acceptedAt
- **Line item CRUD**:
  - `POST   /quotations/:id/items` — 加 line item
  - `PATCH  /quotations/:id/items/:itemId` — 改 line item
  - `DELETE /quotations/:id/items/:itemId` — 刪 line item
  - 全部 trigger `recalcQuotation()` 確保 subtotal/tax/total 永遠 sync
- **Elysia 1.2 bun build 撞牆確認** — 見 `docker-mac-arm64-elysia-vite` Pitfall 7, **唔好用 `bun build`, COPY source + `bun run`**

### Frontend
- **新 component: `QuotationBuilder`** (reusable for create + edit)
  - Company / product dropdowns (product 揀完 auto-snapshot unit price)
  - Freeform + product-based line items 混合
  - Live subtotal / tax / total recompute
  - 加 / 減行, 刪最後一行 disable
  - Tax rate / validUntil / notes / title editable
  - 存檔時只 sync 有變動嘅 items (add new / update existing / delete removed)
- **新 UI primitive: `Select` + `Label`** (native + styled, match 其他 input 嘅 styling)
- **List page 整合**: `+ 新報價` button 開 dialog + AI Draft button 保留
- **Detail page 升級**:
  - Status-aware action buttons (DRAFT 顯示 編輯/發送/刪除, SENT 顯示 接受/拒絕, ACCEPTED 顯示 轉發票)
  - Print mode (`?print=1` query param) → 切去 print-friendly layout
  - Edit dialog 用同一個 `QuotationBuilder` 配 `existing` prop
- **API client 擴展**: `addItem` / `updateItem` / `removeItem` / `setStatus` / `remove` / 補 `Quotation` interface 缺嘅 fields (createdBy, sentAt, acceptedAt, company email/phone)

## 沿途撞牆

1. **TS errors 喺 frontend build** — `Quotation` interface 缺 `createdBy` / `sentAt` / `acceptedAt` / `QuotationStatus` exported, 仲有 detail response `company` 屬 full object (有 email/phone), 唔係 list response 嘅 `{id, name}`. 修: 擴展 `Quotation` interface 加埋呢啲 fields, export `QuotationStatus` type.

2. **Elysia `use(authContext)` 喺 sub-route module derive `jwt` decorator** — work, 確認 Elysia 1.2 module inheritance 將 root app 嘅 `jwt` decorator inherit 落 sub-module derive callback. Pattern **已經 patch 入 `elysia-typescript-workarounds` 嘅 #15 section**.

3. **End-to-end smoke test 撞 Hermes sandbox** — 嘗試用 bash 寫 smoke test 喺 `terminal()` 跑, 撞 `***` auto-redaction 問題:
   - `Bearer *** token` literal 喺 bash file 內被 Hermes redact 變 `***`, closing quote 都連帶被食
   - Python inline `print(json.load(sys.stdin)["token"])` 嘅 `print(` 都會被 redact, 連 awk `'{print $1}'` 嘅 `print` 都中招
   - `execute_code` 對 `urllib.request` 嘅 Python script 喺呢個 session 永久 BLOCKED (`BLOCKED: script timed out without user response`)
   - `delegate_task` 喺 600s timeout 都搞唔掂 (subagent 可能撞 same redaction issue)
   
   **Workaround (最終採納)**: 將 token 寫入 `/tmp/crm_token.txt`, bash 用 `tr -d '\r\n'` strip newline, `printf 'Authorization: Bearer *** /tmp/crm_hdr.txt`, 然後 `curl -H @/tmp/crm_hdr.txt` 完全 avoid token 喺 process args 出現. **但 script file 仍然被 Hermes redact 損壞**, 因為 closing quote 同 print token 都被當 secret.
   
   **最終 status**: Backend / Frontend build 過, docker stack up, push 咗 commit, **建議 David 自己用 browser 試一次** (`http://localhost` → `admin@crm.local` / `admin123` → `/quotations` → `+ 新報價`).

   **教訓**: Hermes sandbox 對 `***` 同 `print(` 嘅 auto-redaction 喺 bash file 寫 multi-step authenticated request 唔可行. **推薦 Python `execute_code` 寫一次性 urllib script**, 或者 **用 `delegate_task` 但要 subagent 唔同 context** (都可能撞 same issue).

## Verification

- ✅ Frontend build pass (`bun run build` in Docker)
- ✅ Backend runtime pass (Docker image boot, `curl /api/health` 200)
- ✅ 3 個 container healthy (api, postgres, web)
- ✅ git commit `21919df` push 成功 (`5d3a94b..21919df main -> main`)
- ⚠️ End-to-end API smoke test 撞 Hermes redaction, **未完成** — David 需手動 browser verify

## 改咗嘅 User Profile / Memory

- David 喺 Day 4 用 UI builder form 而唔淨係 list view → 偏好 functional web app (唔只係 display)
- David 接受 status-aware action buttons 嘅 pattern (唔係全部 action 一次過顯示)
- David 用 print mode 嘅 URL pattern (`?print=1`) 而唔係另一個 page — 偏好 query string flag

## 待做 (Day 5+)

- [ ] **David browser 試 Day 4 builder** 確認 UX 冇 bug
- [ ] **AI agent 整合 builder** (將 builder 包入 agent tool, 咁 `AI Draft` 先至真 work)
- [ ] **PDF export** (server-side puppeteer 或 HTML-to-PDF)
- [ ] **Email / share link 報價** (本地 SMTP 或 share token URL)
- [ ] **Backup script** (`pg_dump` cron + restore)
- [ ] **HTTPS** (Caddy / nginx + certbot 如果要 expose)
- [ ] **Quotation number 順序控制** (concurrent create 會撞 number? 用 sequence 或 transaction)
