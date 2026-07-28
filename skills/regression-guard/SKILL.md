---
name: regression-guard
description: |
  防止修復過的 bug 重新出現(regression)。
  規則:每個修過的 bug 必須留下「regression test」+「root cause note」+「為何會發生」分析,
  確保日後 refactor / 改需求時唔會重新踩坑。
  David 在 2026-06-06 kanban task 明確指出「舊的 bug 又出現」嘅困擾。
trigger: |
  「bug 翻發」「regression」「舊 bug」「為什麼同樣嘅 bug 又出現」「fix 完又壞」
  或任何 bug 修復流程
  `/__qa`、`REGRESSION_MODE`、`Regression Hook`、`Regression Mode`、`qa:seed`、`qa:reset`、QA endpoint、test fixture endpoint 相關變更
  任何時候 audit `rbac.ts` / `logEvent` caller / RBAC seed coverage 嘅 workflow
  出現 "seed doesn't currently write RolePermission rows" 類 comment ＝ known-bug-without-RG-entry → 紅線 13 違規
category: software-development
applicability: operational
---


Last-verified: 2026-07-28
# Regression Guard — 防舊 Bug 翻發

> **為什麼需要這個 skill** — David 嘅實際困擾(2026-06-06 kanban task):
> 「因為現在我有好大體驗,覺得係啲 bug 翻發,舊的 bug 又出現的感覺」
>
> **根因分析**(根據 David 過去 session 觀察):
> 1. Bug fix 之後,只有「修咗」,冇留「點解會壞嘅解釋」+「防止再壞嘅 test」
> 2. Refactor / 改需求時,新嘅 code 違反咗原本 fix 嘅 invariant
> 3. 冇「為何會壞」嘅紀錄 → 6 個月後 debug 同樣 bug 嘅人(可能係 AI subagent)又踩同樣嘅坑
>
> **這個 skill 解決的就是:把「修 bug」從一次性事件變成「帶歷史的防護」**。

---

## 🎯 核心流程

```
Bug 發現 / 報告
    ↓
Step 1: 重現 bug(reproduce)
    ↓
Step 2: 寫 failing test(red)
    ↓
Step 3: 分析 root cause + 寫「點解會壞」紀錄
    ↓
Step 4: 修代碼 → test 變 green
    ↓
Step 5: 寫 regression test(就算原 bug test 已修好,再加邊界情況)
    ↓
Step 5.5: 補 / 驗證 frontend + backend regression hook,記錄 QA 啟用方式與 production safety；如不需要 hook 必須寫 N/A 理由
    ↓
Step 6: 寫 regression-guard entry 喺 `docs/REGRESSION-GUARD.md`
    ↓
Step 7: 喺 source code 加 comment 標記(防止 refactor 破壞)
    ↓
Step 8: 提交 + commit message 引用 entry ID
```

**紅線**:**冇 step 3 (root cause) 同 step 6 (guard entry) 嘅 bug fix 唔可以 merge**。有 regression test 但 QA 無法友善啟用 / 重跑 / 驗證，且冇明確 N/A 理由，視為 regression guard 不完整。

---

## 🔄 Runtime workflow (cross-ref)

本 skill 集中喺 **post-mortem 流程**(bug fix 之後留 RG-XXX + root cause + prevention)。
**Runtime workflow** — `REGRESSION_MODE=1` 開關、結構化日誌、`docs/STATE.md` 對賬單、checker agent 審計、dev agent 修正 — 由 [`dev-checker-loop`](../dev-checker-loop/SKILL.md) 擁有。

兩個 skill 嘅分工同銜接：

| 階段 | Owner | 銜接點 |
|------|-------|--------|
| **開發中** (per feature) | `dev-checker-loop` | 每個 work item 必須帶 regression test (RT-XXX)，掛進開關、登記 Coverage 表 |
| **Bug fix 之中** (retrofit) | 本 skill (regression-guard) | 修 bug 時必須補 RG-XXX entry(即使 bug 唔屬於 loop 內發現) |
| **Refactor / 改需求** | 本 skill | `rg "RG-XXX"` 確認 invariant 仲 valid，跑對應 regression test |
| **Production 安全** | 本 skill (§ Step 5.5) | `REGRESSION_MODE` 唔可以 bypass production safety — production not mounted / 404 / hard fail；測試要配合真實 production behavior。詳見 Step 5.5「QA Regression Mode」+ 「Pitfall: `/__qa/*` endpoint 變成 accidental backdoor」 |

> **完整 runtime flow**(`REGRESSION_MODE=1` 點 set、log 行格式 `[REGRESSION] <RT-ID> | <feature> | <frontend|backend|e2e> | PASS|FAIL | ...`、Coverage 表樣板、checker 標準、escalation rules)見 `dev-checker-loop/SKILL.md § Regression harness contract` 同 `§ File contract: docs/STATE.md`。本檔唔重複。

**dev-checker-loop 入面提及 RG-XXX 嘅地方**:
- §「Checker standards」嘅「Bug fix 專項」sub-step（即 dev-checker-loop 嘅 Step 1 內部）— bug fix item 必走 [`regression-guard`](./SKILL.md) 標準(red→green test + RG entry + code comment)
- §「File contract」Work Items 表的「涉及檔案 / commits」欄 + Checker Findings 嘅「證據」欄都會引用 RG-XXX

---

## 🎯 Regression test coverage targets

Step 5 嘅「寫 regression test」要按以下 target 涵蓋。呢個對應 Step 5 內文講嘅「**預防性測試 > 反應性測試**」 — 等個 bug 出咗先寫 test 永遠慢人一步。**Coverage 漏咗 = 回歸測試只有形式冇實質**。

### 1. 核心與高風險功能（Core & Critical Features）

- **關鍵業務流程**（Smoke / Sanity Test 延伸）：系統最不可或缺嘅核心功能。
  - 例：電子商務 = 登入 → 搜尋商品 → 加入購物車 → 結帳付款；CRM = 登入 → 建立 Deal → 報價 → 成交。
- **高頻率使用功能**：用戶每日都會頻繁操作嘅模組(list 頁、search、export)。
- **高複雜度 / 高風險模組**：邏輯複雜、改動最頻繁、涉及核心演算法 / 資料庫異動嘅部分(pricing engine、RBAC、audit log、payment)。

### 2. 本次變更相關功能（Impact Area）

- **修復好的 Bug 驗證**：針對過去修過嘅缺陷重測，確保冇復發 — 直接對應 Step 5 嘅 regression test，亦對應 dev-checker-loop 嘅 RT-XXX。
- **受影響區域測試**（Impact Analysis）：新功能 / 改介面嘅延伸影響。
  - 例：改「會員資料頁」→ 必須測「訂單頁面上嘅會員姓名顯示」；改 `Company.roleId` → 必須測 `Deal` / `Contact` 顯示。

### 3. 不同層級嘅測試腳本（Test Pyramid）

回歸測試貫穿自動化測試金字塔各層，缺一不可：

| 層級 | 目的 | 工具 / 模式 |
|------|------|-------------|
| **Unit Tests** | 驗證最小程式區塊（含邊界條件）| bun:test / Jest + derive helper pattern（見 Pitfall §「Pure function derive from inline route logic」）|
| **Integration Tests** | 模組 / API / DB 之間互動同資料傳遞 | supertest / bun:test 配真 DB（test container / 本地 PG）|
| **E2E / UI Tests** | 真實用戶操作流程 | Playwright / Cypress（守住完整 happy path）|

**原則**:覆蓋率傾向金字塔（多 unit、少量 E2E）。但**核心流程嘅 E2E 必須有** — 守住用戶觀察路徑，typecheck / unit 都驗唔到嘅 UI / API 行為必須靠 E2E 撞先 catch 到。

### 4. 前端專屬測試類別（Frontend-specific）

Frontend regression test 除咗上面 1–3 嘅 target，仲要涵蓋以下 5 類。**任何一類完全冇 test = coverage gap finding（major）**。

#### 4.1 視覺與 UI 畫面測試（Visual Testing）

- **視覺比對測試**（Visual Regression Testing）：用 Percy / Playwright / Chromatic 截圖，比對 baseline 圖嘅像素差異。守住 CSS 跑版、文字溢出、按鈕位移、顏色意外變更。
- **響應式設計**（RWD / Mobile Responsiveness）：Desktop / Tablet / Mobile 唔同螢幕解析度下，排版同 menu 縮放、摺疊是否正常。

#### 4.2 使用者互動與流程測試（User Interaction & E2E）

- **關鍵元件互動**：表單驗證（錯格式提示）、彈出視窗（Modal 開關）、下拉選單、分頁（Pagination）、無限滾動（Infinite Scroll）。
- **端到端核心流程**：模擬真實用戶從前端操作到完成任務嘅完整路徑（點擊商品 → 選尺寸 → 加入購物車 → 結帳）。常用工具：Cypress / Playwright。
- **路由與頁面跳轉**（Routing）：SPA 跳轉時 URL 正確更新、Back / Forward 行為、深層連結（Deep Link）能直接打開。

#### 4.3 前端狀態管理與 API 整合（State & API Integration）

- **狀態管理**（State Management）：Redux / Vuex / Zustand / Context API 嘅資料狀態，跨頁面 / 複雜互動後唔會遺失或殘留（例：登出後購物車清空）。
- **API 異常與極端狀況**（Edge Cases & Error Handling）：
  - **Loading State**：API 慢嘅時候顯示 Skeleton / Spinner。
  - **Error Handling**：404 / 500 / 網絡斷線時 UI 優雅顯示提示（Error Boundary），唔好白畫面（White Screen of Death）。
  - **Empty State**：資料列表為空時有適當提示。

#### 4.4 跨瀏覽器與裝置相容性（Cross-Browser & Compatibility）

- **主流瀏覽器渲染**：Chrome / Safari / Firefox / Edge — JS（ESNext 轉譯結果）同 CSS（Flexbox / Grid 支援）皆運作正常。
- **觸控與輸入支援**：手機 / 平板嘅觸控滑動（Swipe）、手勢操作、鍵盤輸入焦點（Focus）。

#### 4.5 前端非功能性測試（Performance & Accessibility）

- **Web 性能指標**（Core Web Vitals）：新 code 唔導致 LCP（最大內容繪製）、CLS（累積佈局位移）、INP（互動到下一次繪製）嚴重退化。
- **無障礙功能**（Accessibility / a11y）：鍵盤導覽（Tab 流暢度）、Screen Reader 朗讀標籤（aria-label）因元件重構而失效。

### 5. Coverage gap 偵測

開 dev-checker-loop 嘅同時（per `dev-checker-loop` Step 3 覆蓋審計），Coverage 表必須對齊呢度列嘅目標：

- 任何 **核心 / 高頻 / 高風險** 功能喺 Coverage 表 MISSING → finding（blocker）。
- 任何 **前端專屬**（視覺 / 互動 / 狀態 / 跨瀏覽器 / 性能 + a11y）類別完全冇 test → finding（major）。
- 任何 **Impact Area** 缺 test → finding（major），要求 dev 補齊。
- 存量缺口（loop 開始前就冇 test 嘅舊功能）逐輪補；最後一輪結束時 Coverage 表不得有無 finding 記錄嘅 MISSING。

> **N/A 嘅兩個 scope，唔好混淆**：
> - **Step 5.5 N/A** = 個別 RG entry 嘅 QA hook 唔需要（例如純 unit test 已經夠）；寫入 entry 嘅「QA Regression Mode」section 註明即可。
> - **本 section 嘅 coverage gap** = project-level（多 RG entry 累積判斷某類別完全冇 test）。系統性 N/A（例如 legacy system 冇 Lighthouse infra 跑 Performance test、冇 Percy/Chromatic 跑 Visual Regression）必須寫入 `docs/TEST-COVERAGE.md` 註明理由，唔可以 silent skip。Checker 見到冇理由嘅系統性 N/A = finding（major）。

---

## 📁 文件結構

每個 project 必須有 `docs/REGRESSION-GUARD.md`,格式:

```markdown
# Regression Guard — <Project Name>

> 目的:追蹤所有修過嘅 bug,確保日後唔會重新踩坑。
> 規則:每個 bug fix 必須喺呢度留 entry,否則不算完成。

## 索引
| Entry ID | Bug 描述 | 發現日期 | 影響版本 | Root Cause | Regression Test | 狀態 |
|----------|---------|---------|---------|-----------|-----------------|------|
| RG-001 | 登入後 token 過期但 UI 唔跳 | 2026-05-12 | v1.2.0 | [see](#rg-001) | [test/auth.test.ts#expired-token-redirect](...) | FIXED |
| RG-002 | 圖片上傳 > 5MB 唔報錯 | 2026-05-20 | v1.2.1 | [see](#rg-002) | [test/upload.test.ts#size-limit](...) | FIXED |
| RG-003 | 註冊 email 重複檢查 race condition | 2026-06-01 | v1.3.0 | [see](#rg-003) | [test/auth.test.ts#concurrent-signup](...) | FIXED, MONITORING |

## 條目格式

<a id="rg-001"></a>
### RG-001 — 登入後 token 過期但 UI 唔跳轉到 login

**發現日期**: 2026-05-12
**發現者**: @David (用戶回報)
**影響版本**: v1.2.0 (released 2026-05-10)
**修復版本**: v1.2.1
**修復者**: @Backend-Bob
**Commit**: `a1b2c3d`

#### 症狀
- 用戶登入後用緊 30 分鐘
- 突然操作一個需要 auth 嘅 endpoint
- 後端回 401,但前端 UI 冇反應(冇跳轉、冇 toast)
- 用戶以為 app 壞咗,實際係 token 過期

#### Root Cause(為何會壞)
- 原本 `apiClient.ts` 有個 axios interceptor 處理 401
- 但 `interceptor` 只 refresh token,**冇** force logout
- 如果 refresh 失敗(refresh token 都過期),silently fail
- 前端冇 global error boundary 處理「auth 死咗」嘅情況

**教訓**:
1. 唔好假設 refresh token 一定 work — 要有 fallback
2. Auth state 變化要 broadcast(用 Event Bus / state machine)
3. UI 必須對「無法恢復嘅 auth 失敗」有明確用戶反饋

#### 防止再發(防護措施)
- [x] **Regression test**: `test/auth.test.ts#expired-token-redirect` 模擬 refresh 失敗 → 預期跳轉到 /login
- [x] **Code comment**: `apiClient.ts` 嘅 interceptor 加 `// RG-001: 唔好 silent fail,要 force logout if refresh fails`
- [x] **Invariant statement**: 「401 + refresh 失敗 = 強制登出」寫入 `docs/architecture/0007-auth-state-machine.md`
- [x] **Linting rule**: ESLint custom rule 禁止 `catch (err) { /* silent */ }` 在 auth-related code

#### QA Regression Mode
- **Frontend hook**: [例如 `data-testid`, QA panel, visual freeze control；無則 N/A + 理由]
- **Backend hook**: [例如 `/__qa/regression/RG-001`, seed/reset/mailbox/test clock；無則 N/A + 理由]
- **Endpoint contract**: [如有 `/__qa/*`，連到 `docs/API.md` endpoint section；無則 N/A + 理由]
- **Auth guard**: [QA secret / staging SSO / IP allowlist / authenticated test role]
- **Environment guard**: [dev/test/staging only；production not mounted / 404 / 403 / hard reject]
- **Data scope**: [test tenant / test DB / test schema only]
- **Audit event**: [QA action 如何記錄 actor、scope、US/RG、fixture version]
- **Idempotency**: [seed/reset 是否 safe to rerun]
- **External side effects**: [fake / sandbox only；真 email / SMS / payment N/A]
- **QA enablement**: [QA 如何啟用 fixture / switch]
- **Seed/reset data**: [test tenant / fake mailbox / sandbox data]
- **Test command**: [`test:regression:rg -- RG-001` 或等價命令]
- **Expected result**: [QA 應看到什麼]
- **Safety boundary**: [dev/test/staging only; auth/permission/rate limit 不可 bypass]
- **Production exposure check**: [`/__qa/*` production 404/403, `REGRESSION_MODE=true` production hard fail / reject]

#### 相關 Issue / Discussion
- [GitHub Issue #234](...)
- [Slack thread 2026-05-12](...)
```

---

## 📝 Step-by-Step 詳細執行

### Step 1: 重現 bug

**紅線:未確認能重現嘅 bug 唔可以 fix**。

```bash
# 1. 寫 reproduction script(寫到 /tmp/,唔好寫到 project)
cat > /tmp/repro_bug.py << 'EOF'
import requests
# 模擬 bug 嘅觸發條件
resp = requests.post("https://api.example.com/upload", files={"file": open("huge.jpg", "rb")})
print(f"Status: {resp.status_code}")  # 期望 413,實際 500
print(f"Body: {resp.text}")
EOF
python3 /tmp/repro_bug.py
```

**記錄**:
- 觸發條件(輸入、狀態、環境)
- 預期 vs 實際
- 重現率(100% / 偶發 / 特定條件)

### Step 2: 寫 failing test (Red)

**在正式 test suite 內加 test(唔好寫到 /tmp/!)**

```typescript
// test/upload.test.ts
describe('Image upload size limit', () => {
  it('should return 413 when file > 5MB', async () => {
    const hugeFile = new File([new ArrayBuffer(6 * 1024 * 1024)], 'huge.jpg', { type: 'image/jpeg' });
    const result = await uploadImage(hugeFile);
    expect(result.status).toBe(413);
  });
});
```

**確認**:`npm test` 跑呢個 test 係 **FAILING** (紅色)。如果 PASS,代表根本無 bug 或者 test 寫錯。

### Step 3: 分析 root cause(最關鍵!)

**要回答三條問題**:
1. **點解會壞?**(技術原因)
2. **點解之前冇人發現?**(process 原因)
3. **點解將來唔會再壞?**(prevention 設計)

```markdown
#### Root Cause

**技術原因**:
- `uploadHandler.ts:42` 用 `await file.arrayBuffer()` 之後直接 push 到 S3
- 冇 size check
- 過咗 Lambda 嘅 6MB payload limit 之後就 500

**Process 原因**:
- 之前只係用 1MB test file 做 integration test
- Production 環境啲用戶有時上傳 5-10MB 嘅相
- 冇 staging environment 用真實 size 測試

**Prevention 設計**:
- Client-side: 喺 file picker 加 size validation(防止用戶揀錯 file)
- Server-side: middleware 做 size check(防止 client-side 被 bypass)
- S3: 用 multipart upload for files > 5MB(支援大 file)
- Test: 加 regression test with 6MB file
```

**規則**:**技術原因 + process 原因都要寫**。淨寫「我加咗個 if 啦」係偷懶。

### Step 4: 修代碼

寫最少嘅 code 改動,確保 step 2 嘅 test 變 GREEN。

### Step 5: 寫 regression test

```typescript
// 加多幾個邊界 case
describe('Image upload edge cases', () => {
  it('should reject 5.1MB with 413', ...);
  it('should accept 4.9MB with 200', ...);
  it('should reject 0-byte file with 400', ...);  // 新加嘅邊界
  it('should handle concurrent uploads of large files', ...);  // 性能
  it('should not leak memory on rejected uploads', ...);  // 資源
});
```

**Frontend regression test example**(守住 UI 行為本身，唔止 backend unit)：

```typescript
// e2e/upload-dialog.spec.ts (Playwright)
import { test, expect } from '@playwright/test'

test('upload dialog > 5MB 顯示錯誤 + 唔送 request', async ({ page }) => {
  await page.goto('/upload')
  const hugeFile = new File([new ArrayBuffer(6 * 1024 * 1024)], 'huge.jpg', { type: 'image/jpeg' })
  await page.locator('[data-testid="upload-input"]').setInputFiles(hugeFile)
  // 守住「client-side size check」嘅 UI 行為
  await expect(page.getByRole('alert')).toContainText('FILE_TOO_LARGE')
  await expect(page.locator('[data-testid="upload-submit"]')).toBeDisabled()
  // 守住「冇送 request」(network idle 確認冇打到 backend)
  const requests: string[] = []
  page.on('request', (req) => requests.push(req.url()))
  await page.locator('[data-testid="upload-retry"]').click()
  expect(requests.filter((u) => u.includes('/api/upload'))).toHaveLength(0)
})
```

**原則**:**預防性測試 > 反應性測試**。等個 bug 出咗先寫 test 永遠慢人一步。

> **完整 frontend coverage 類別**(Visual Regression / Interaction / State / Cross-Browser / Perf + A11y)見 §「🎯 Regression test coverage targets → 4. 前端專屬測試類別」。Step 5 呢度嘅 example 只示範「互動 + 守住行為」一類；其他 4 類要按項目性質 + `docs/TEST-COVERAGE.md` 嘅 coverage 計劃補齊。


### Step 5.5: 補 / 驗證 QA Regression Mode

Regression test 寫完後，必須讓 QA 知道點樣重跑同驗證：

1. **Hook decision** — 先判斷是否真的需要新 hook；現有 deterministic fixture / unit setup / integration setup 足夠時，不要為了方便而加 `/__qa/*`
2. **Frontend QA hook** — `data-testid` / `aria-label` / QA panel / visual freeze control；無需要則寫 N/A 理由。**注意：「Frontend QA hook」同 § 4「前端專屬測試類別」(Visual Regression / Playwright E2E / Lighthouse Perf / A11y) 唔同 — hook 係 test runner 嘅 aid 嚟幫 QA 重跑；functional test 係守住 UI 行為本身嘅 regression test。兩者都應該有，但 role 唔同。**
3. **Backend QA hook** — `/__qa/seed` / `/__qa/reset` / fake mailbox / test clock / queue drain / `RG-XXX` fixture；無需要則寫 N/A 理由
4. **Endpoint contract** — 如新增 / 修改 `/__qa/*`，必須同步 `docs/API.md`、`docs/TEST-COVERAGE.md`、`docs/QA-TRACKER.md`；bug fix / `RG-XXX` 亦同步 `docs/REGRESSION-GUARD.md`
5. **QA enablement** — 寫明 test command、seed command、expected output
6. **Safety boundary** — 只限 dev/test/staging；production 不 mount `/__qa/*`，不接受 regression mode 作為 bypass
7. **No bypass** — 不可 disable auth / permission / rate limit / audit / security behavior；測試要配合真實 production behavior
8. **Production exposure check** — 寫明 production 404 / 403 / hard reject 或 boot-time hard fail 的驗證方式

**規則**:Regression mode 係 deterministic fixture / observability / orchestration，唔係後門。QA hook 若會動資料，backend 必須重新驗證 env + auth + tenant scope。`/__qa/*` endpoint 是 security-sensitive API contract，不是 debug backdoor。

#### Pitfall: `/__qa/*` endpoint 變成 accidental backdoor

`/__qa/*` 只可以建立 deterministic fixture、reset test scope、觀察 sandbox output、控制 test clock / queue；不可為了令 E2E pass 而繞過真實 security behavior。

- ❌ `skipAuth` / `bypassPermission` / `disableRateLimit` / `rateLimit = false`
- ❌ unscoped reset / seed production DB
- ❌ 真 email / SMS / payment side effect
- ❌ 信任 `x-regression-mode` header 作為權限來源
- ✅ authenticated test role / QA secret / staging SSO / IP allowlist
- ✅ test tenant / test DB / test schema only
- ✅ production not mounted / 404 / 403 / hard reject
- ✅ audit log actor、scope、US/RG、fixture version

**判斷準則**:如果測試是因為 bypass 真實行為而 pass，這不是 regression guard；這是新的 production risk。

### Step 6: 寫 REGRESSION-GUARD entry

按上面嘅模板,寫一個完整嘅 entry。

**重要:Entry ID 用 `RG-` + 3 位數遞增**(`RG-001`, `RG-002`...)。

### Step 7: 在 source code 加 comment

```typescript
// uploadHandler.ts
async function uploadImage(file: File) {
  // RG-002: 5MB size limit enforced client + server side
  // 修改前請睇 docs/REGRESSION-GUARD.md#rg-002 嘅 invariant
  if (file.size > 5 * 1024 * 1024) {
    throw new Error("FILE_TOO_LARGE");
  }
  // ...
}
```

**Comment 必須包含**:
- `RG-XXX` entry ID
- 一句 invariant 描述
- 連結到 REGRESSION-GUARD.md

### Step 8: 提交

```bash
git add src/uploadHandler.ts test/upload.test.ts docs/REGRESSION-GUARD.md
git commit -m "fix(upload): enforce 5MB size limit (RG-002)

- Add server-side size check
- Add regression test for 5.1MB upload
- Document root cause and prevention in REGRESSION-GUARD.md
- Add RG-002 comment marker in source code

Refs: RG-002"
```

**Commit message 必須引用 RG ID**,方便日後 `git log --grep "RG-002"` 找返所有相關 commit。

---

## 🔍 防止「同樣 bug 又出現」的具體策略

### 策略 1: Refactor 時嘅 Guard

當 refactor 涉及有 RG entry 嘅 code:

```
Refactor 開始
    ↓
git grep "RG-XXX" → 列出所有受影響位置
    ↓
逐個睇 invariant statement
    ↓
確認 refactor 冇違反任何 invariant
    ↓
跑對應嘅 regression test
    ↓
先可以 merge
```

### 策略 2: 改需求時嘅 Guard

當某個 US 改咗,可能影響之前嘅 RG entry:

```
改 US 影響分析
    ↓
檢查 REGRESSION-GUARD.md 入面,有冇 entry 嘅 invariant 同新 US 衝突
    ↓
如果有衝突:
    - 標記 RG entry 為 NEEDS_REVIEW
    - 在該 entry 加新嘅 section 講解衝突點
    - 跟用戶/PM 確認
    - 寫新 entry `RG-XXX-supersedes-RG-YYY`(保留歷史)
```

### 策略 3: 自動監控

```yaml
# .github/workflows/regression-check.yml
name: Regression Guard
on: [pull_request]
jobs:
  check-rg-references:
    runs-on: ubuntu
    steps:
      - uses: actions/checkout@v3
      - name: Check RG comment markers
        run: |
          # 改咗 src/ 但冇更新 REGRESSION-GUARD.md 嘅 PR → fail
          if git diff --name-only origin/main | grep -E "src/.*\.(ts|js|py)$"; then
            if ! git diff --name-only origin/main | grep -q "REGRESSION-GUARD.md"; then
              if ! git diff origin/main | grep -qE "RG-[0-9]{3}"; then
                echo "❌ Source code 改動冇引用任何 RG entry"
                echo "   要麼:1) 加 RG entry / 2) 確認唔影響現有 RG"
                exit 1
              fi
            fi
          fi
```

### 策略 4: 季度 RG Audit

每季做一次:
```
撈 REGRESSION-GUARD.md 全部 entry
    ↓
逐個睇:
    - regression test 仲跑唔跑?(有冇被 refactor 刪走?)
    - code comment 仲喺唔喺度?
    - invariant 仲 valid 唔 valid?(隨住 system 演進,可能已經唔適用)
    ↓
寫 audit report 喺 `docs/retros/YYYY-QX-regression-audit.md`
    ↓
發現失效嘅 entry → 標 DEPRECATED + 解釋
```

---

## 🆚 同其他文件嘅關係

| 文件 | 角色 | 互動 |
|------|------|------|
| `docs/PRD.md` | 講要做咩 | RG entry 可能引用 US(例:RG-002 違反咗 US-007) |
| `docs/architecture/*.md` | 講點樣做 | RG entry 可能引用 ADR(例:RG-003 因為 ADR-0005 嘅 trade-off 造成) |
| `docs/QA-TRACKER.md` | 持續測試追蹤 | RG 嘅 regression test 一定喺 QA-TRACKER 入面追蹤 |
| `docs/TECH-DEBT.md` | 技術債 | RG entry 升級做 tech debt 嘅情境:「個 fix 唔完美,將來要重做」 |
| `docs/feedback-loop.md` | 獎罰 | 沒寫 RG entry 嘅 bug fix 算 P1 過(已記錄喺 feedback-loop.md 嘅罰則) |
| [`dev-checker-loop`](../dev-checker-loop/SKILL.md) | runtime harness — REGRESSION_MODE=1 開關、`docs/STATE.md` 對賬單、checker agent 審計 | Bug fix item 嘅 RT-XXX 同步登記去 STATE.md Coverage 表；修完後 DEV_DONE item 連同 RG-XXX 一齊被 checker 覆核（見 `dev-checker-loop` § Checker standards Step 1.6）|

---

## 🚨 對應紅線

本 skill 執行紅線 13-15（RG entry 必備、root cause + prevention、refactor invariant 確認）；全文以 `SOUL.md` 為唯一正本。

---

## 🎬 David 嘅實戰情境

情境:David 報 bug —「用戶密碼重設之後,登入之後個 session 仲係舊嘅,新密碼改咗但其他 device 仲可以用舊密碼登入」。

**正確流程**(用本 skill):
1. **重現**:Developer 寫 script 模擬兩 device + 重設密碼,確認 bug
2. **寫 failing test**: `test/auth.test.ts#password-reset-invalidate-sessions`
3. **Root cause 分析**:
   - 技術:`resetPassword` 只 update password hash,**冇** invalidate existing sessions
   - Process:之前 sprint planning 冇考慮「password change = security event = invalidate all sessions」呢個 invariant
4. **修 code**:加 invalidate logic
5. **加 regression test**: 加多 `it('should invalidate refresh tokens after password reset')`
6. **寫 RG-004 entry**:
   - ID:RG-004
   - 症狀:密碼重設後其他 device 仲用舊密碼有效
   - Root cause:密碼改動冇 trigger session invalidation
   - Prevention:所有 auth event(password change, email change, 2FA enable)都 invalidate sessions
7. **Code comment**:
   ```typescript
   // RG-004: 密碼重設必須 invalidate 全部 sessions
   // 違反呢個 invariant = 其他 device 仲可以用舊密碼
   await sessionStore.invalidateAllForUser(userId);
   ```
8. **Commit**:`fix(auth): invalidate sessions on password reset (RG-004)`

**錯誤流程**(冇用本 skill):
- 「我加咗個 invalidate call 啦,搞定」→ **冇 RG entry → 下次 refactor 又會踩**
- 「點解之前冇人 catch 到」 → 永遠唔會知道
- 「同樣嘅 bug 我一年撞 3 次」→ 唔會再撞嘅唯一方法就係**留下紀錄**

---

## 📚 Pitfall references

The detailed historical pitfalls live in `references/pitfalls/` so this skill stays operational rather than becoming a case-history archive. Load the relevant reference when a matching pattern appears; the core workflow, regression-test standards, and current runtime contract remain above.

| Topic | Reference file | Origin |
|---|---|---|
| `logEvent` API field-name drift in callers | [`logevent-api-field-name-drift.md`](references/pitfalls/logevent-api-field-name-drift.md) | crm-system, 2026-06-07 (pre-existing) |
| RBAC seed coverage gap | [`rbac-seed-coverage-gap.md`](references/pitfalls/rbac-seed-coverage-gap.md) | crm-system, 2026-06-07 (CRITICAL) |
| Derive pure helpers from inline route logic for unit tests | [`pure-function-derive-from-inline-route-logic.md`](references/pitfalls/pure-function-derive-from-inline-route-logic.md) | pm-system Sprint 1, 2026-06-08 |
| `Record<EnumType, ...>` map vs backend emit drift | [`record-enumtype-map-backend-emit-drift.md`](references/pitfalls/record-enumtype-map-backend-emit-drift.md) | crm-system audit, 2026-06-06 |
| Plan wording vs backend wire shape | [`plan-doc-wording-vs-backend-wire-shape.md`](references/pitfalls/plan-doc-wording-vs-backend-wire-shape.md) | crm-system Day 14.7, 2026-06-07 |
| Form refactor silently regresses working state | [`form-refactor-silent-regression.md`](references/pitfalls/form-refactor-silent-regression.md) | crm-system, 2026-06-08 |
| Source-check test when ESM mocking is unreliable | [`source-check-regression-test.md`](references/pitfalls/source-check-regression-test.md) | pm-system Sprint 4 RG-007, 2026-06-09 |
| External package / binary spec assumption | [`external-spec-assumption.md`](references/pitfalls/external-spec-assumption.md) | pm-system Sprint 21, 2026-06-16 |
| A “remove X” fix that leaves references behind | [`fix-naming-not-actually-removed.md`](references/pitfalls/fix-naming-not-actually-removed.md) | pm-system RG-007 cleanup gap, 2026-06-09 |
| Permanent cache for admin-mutable state | [`permanent-cache-anti-pattern.md`](references/pitfalls/permanent-cache-anti-pattern.md) | pm-system Sprint 4 RG-007, 2026-06-09 |
| User committed overlapping work first | [`user-committed-before-you.md`](references/pitfalls/user-committed-before-you.md) | crm-system Day 10 doc sync, 2026-06-09 |
| Token trust / fake UUID privilege escalation | [`token-trust-fake-uuid-privilege-escalation.md`](references/pitfalls/token-trust-fake-uuid-privilege-escalation.md) | pm-system TD-011, 2026-06-08 |
| Reproduce and trace a 500 before writing a fix | [`reproduce-before-fix-500.md`](references/pitfalls/reproduce-before-fix-500.md) | pm-system TD-011, 2026-06-08 |
| Eight-file documentation sync pattern | [`eight-doc-files-sync-pattern.md`](references/pitfalls/eight-doc-files-sync-pattern.md) | crm-system, 2026-06-07 |
| Verify the next blocker after a surface fix | [`verify-next-blocker-after-surface-symptom.md`](references/pitfalls/verify-next-blocker-after-surface-symptom.md) | pm-system Sprint 5, 2026-06-09 |

> **Deduplication:** The old section contained the “Pure function derive from inline route logic” pitfall twice (a Sprint 1 version and a generic copy). It is intentionally kept once in `pure-function-derive-from-inline-route-logic.md`.

---

## 📊 衡量指標

每個 project 嘅 health check:

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| 過去 90 日新增 RG entry 數 | < 5 | 5-15 | > 15(可能 process 有問題) |
| RG entry 標 NEEDS_REVIEW 嘅比例 | < 10% | 10-30% | > 30%(需求變更太頻繁沒管理) |
| Regression test 跟 code 一齊 commit 嘅比例 | 100% | 80-99% | < 80% |
| 季度 audit 發現失效 RG 嘅比例 | < 5% | 5-20% | > 20%(audit 太少) |

**注意**:`過去 90 日新增 RG entry 數` 健康值低,代表 codebase 穩定。**唔係「愈少 bug 愈好」**— 可能係冇發現 bug 嘅 reflection。

## 📚 Related references

- `references/crm-system-2026-06-07-rbac-seed-and-audit-log-silent-failures.md` — Two pre-existing CRITICAL bugs found while building Day 14 System Settings: (1) `rbac.ts:50-66` reads from a `RolePermission` table the seed never wrote, silently 403ing all requirePermission-gated endpoints in production (including ADMIN); (2) every audit log call in `settings.ts` uses wrong field names (`userId` vs `actorId`, `entity` vs `resourceType`, etc.) so audit log writes silently fail inside `logEvent`'s `try/catch`. Includes detection recipes, fix code, and prevention checklists. **Read this if you ever audit a project that has `rbac.ts` + `audit.ts` + `seed.ts` together — these two bugs are CLASS-level, not project-specific.**
- `references/pm-system-2026-06-08-sprint-1-test-derive.md` — **Sprint 補 test 完整 reproduce 範本**:pm-system Sprint 1 補 3 份 unit test (RBAC / WorkLog / Agent)、3 個 P0 US 升至 PASS-UNIT、coverage 5% → 25%。包括(1) 揀 RG-XXX / P0 US 嘅優先序,(2) 三份 test 嘅 derive 過程(對應 source file:line + 踩坑親驗),(3) 統一 sprint 補 test workflow(可重用),(4) 對應 doc 更新 checklist。**下次做任何「sprint 補 test + doc update」session 直接跟呢份 reproduce**。
- `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md` — **TD-011 end-to-end reproduce**:E2E discover fake UUID 撞 500 → 2 round diagnosis(我 Round 1 誤判 derive hook findUnique,Round 2 睇 source code 先 catch 真實位置)→ fix derive hook 加 user existence check + role 從 DB 攞(順手封咗 token claim privilege escalation)→ 改 E2E test expectation(500 → 403)→ 寫 RG-006 entry + source code comment marker + commit 引用 RG ID。**教科書級 bug fix-and-test cycle,適合未來任何「E2E surface security bug → diagnose → fix → RG entry」session 跟呢個 reproduce**。
- **Pair with `unit-test-coverage-push` skill** (3-step playbook: parse QA-TRACKER → per-US classify derive/integration/DEFERRED → commit series + tracker sync). That skill IS the upstream "push coverage to 100%" workflow; this skill's "Pure function derive from inline route logic" pitfall IS the per-test technique that powers it. Load `unit-test-coverage-push` for the sprint-level playbook; load this skill for the bug-regression flavor + RG entry format.
