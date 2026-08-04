# QA Gate — 完整交付流程
> **When to read:** Ship

> **Status:** Canonical. Source of truth for QA Gate release and merge requirements.

> **核心原則**: 未通過 QA Gate 的結果，絕對不能交付給用戶。
> **本文檔**: 係 SOUL.md § 紅線 10/11/16/17 嘅 detailed workflow。
> SOUL.md 只列條件，本文檔講執行 protocol。
> **適用分級**: 邊啲 gate 適用於邊種任務（T1/T2/T3），以 `docs/task-tiering.md` 為唯一正本；小型任務降級必須按其 template 申報。

---

## 0. Pre-Work Sync（任何工作開始前）

**改任何文件 / code 之前**，必須先確認當前狀態：

```bash
# 1. 文檔清單確認
ls docs/PROJECT-OVERVIEW.md docs/PRD.md docs/DESIGN.md docs/API.md \
   docs/TEST-COVERAGE.md docs/TECH-DEBT.md docs/QA-TRACKER.md docs/VERIFY.md 2>&1

# 2. QA-Tracker 當前 row 數
grep -c "^| US-" docs/QA-TRACKER.md

# 3. 工作 tree 狀態
git status --short
git log --oneline -5
```

**記錄起點**: 喺 checkpoint / 任務頂部記低當前狀態，作為 baseline。

---

## 0A. Pre-Build Documentation Gate（進 Build 前必跑）

**Think / Plan 共識必須先落到 project docs，才能開始 Build。** Build 前確認：

```bash
python3 scripts/docs_consistency_check.py --project-docs
```

必備文檔清單（每份文檔的 baseline 內容要求、N/A 規則）以 `docs/project-documentation-standard.md` 為唯一正本；本 gate 檢查該清單全部存在且 baseline 足以回答「做什麼 / 為誰 / 驗收標準 / 架構決策 / 測試計劃」。

**未通過 = 停留在 Plan，不可 Build。** David 在 Build / Review / Test / Ship 前提出新需求或修正時，也要先回到此 gate 的 doc sync，再繼續。

---

## 0B. Existing Project Intake Gate（現有項目接手前）

接手 existing / inherited project，或 project docs / tests / QA tracker / regression hooks 狀態未知時，先執行 `skills/existing-project-intake/SKILL.md`，不可直接進 Build。

觸發情況：

| 觸發 | 場景 |
|------|------|
| Existing project + 未完成 source-first analysis | Agent 未跑 `skills/existing-project-intake` |
| Docs baseline 缺失 / 過期 / 與 source 矛盾 | 跟現有代碼唔對 |
| Tests / QA tracker 狀態未知 | 唔知邊啲有 coverage |
| Regression hooks / `/__qa/*` endpoints 狀態未知 | 唔知點 re-run regression |
| David 要求「總結齊全 docs 後再繼續開發」 | 顯式 intake trigger |

Intake report 必須識別：

- docs baseline status
- PRD ↔ QA tracker sync status
- test inventory / known test commands
- regression mode / hook inventory
- `/__qa/*`、`/debug`、`/dev`、seed/reset endpoint 的 safety state
- minimum task-scoped baseline before Build

缺 `/__qa/*` 不自動 blocking；intake 要判斷 requested task 是否需要 deterministic setup / reset / time / queue / mailbox / external fixture / per-`RG-XXX` hook。若不需要，寫 `N/A + reason`。若 existing debug endpoint 不安全，先標 blocker 或 tech debt，不可盲用。

---

## 0C. Spec Gate（T2/T3 新功能開工前）

T2 / T3 新 feature、user-story、scope 增量或 acceptance contract 改動，先執行 [`spec-driven-development`](../skills/spec-driven-development/SKILL.md)：

1. Fresh foreground BA subagent 產出 `docs/specs/REQ-<NNN>/spec.md` 和 `tests.md`。
2. `spec.md` 的 Given/When/Then AC 必須 atomic、source-verified，blocking `OPEN QUESTION` = 0。
3. `tests.md` 每個 AC 至少映射一個 real `RT-XXX`；STATE / harness 未存在時可暫用 `RT-TBD-*`，但 loop 第一批 work item 必須轉 real ID。
4. Gate ready 後，`dev-checker-loop` 導入 AC / RT；全部 AC 有 executable test、PASS log 和 required use-case evidence 前不可結束。

**未通過 = 停留在 Plan，不可 Build。** T1、bug fix、read-only、QA-only、trivial ops 的例外 routing 以該 skill 和 `docs/task-tiering.md` 為準，並必須申報。

---

## 1. Doc-Code Sync Check（任何改動後必跑）

**任何 code 或文檔改動** → 必須 sync 對應文檔：

| 改動類型 | 必須同步嘅文檔 |
|---------|---------------|
| **Scope / business goal / 成功標準改動** | `PROJECT-OVERVIEW.md` + `PRD.md` + `QA-TRACKER.md` |
| **新 API endpoint / API contract 改動** | `API.md`（+ `TEST-COVERAGE.md` 加 test case）|
| **架構 / data model / infrastructure 改動** | 新 `ADR` + 受影響 docs（如 `API.md` / `TECH-DEBT.md`）|
| **UI / component / layout / token 改動** | `DESIGN.md` + `TEST-COVERAGE.md` |
| **User Story 改動** | `PRD.md`（更新 US）+ `QA-TRACKER.md`（PARTIAL / 新 row）|
| **T2/T3 新 feature / user-story 請求** | `docs/specs/REQ-<NNN>/spec.md` + `tests.md`（已有 PRD baseline 時另同步 `PRD.md` + `QA-TRACKER.md`）|
| **David 在 Build 中提出新需求 / 修正** | 暫停 Build → 更新 `PRD.md` + `QA-TRACKER.md` + 受影響 docs → 再繼續 |
| **Bug fix** | `REGRESSION-GUARD.md`（新 RG-XXX）+ `TEST-COVERAGE.md`（regression test）+ 相關 US row 備註 |
| **Review / QA / code-review feedback** | Apply and update affected docs, or record deferral / rejection rationale in `TECH-DEBT.md`, `QA-TRACKER.md`, `REGRESSION-GUARD.md`, ADR, or the affected canonical doc |
| **新增 / 修改 regression hook 或 switch** | `TEST-COVERAGE.md` Regression Mode / Hooks matrix + `QA-TRACKER.md` regression 欄位；如涉及 bug fix 則同步 `REGRESSION-GUARD.md`，如新增 `/__qa/*` 或 QA panel 則同步 `API.md` / `DESIGN.md` |
| **Refactor** | `TECH-DEBT.md`（新 row，標 DEPRECATED 嘅債務）|
| **依賴升級** | `TECH-DEBT.md`（upgrade 記錄）+ `docs/verify-log/` 新驗證紀錄 |
| **任何 code 改動** | `docs/verify-log/YYYY-MM-DD-<task>.txt`（命令 + 真實輸出 + exit code，同 commit）|

**Drift 檢測**（每次 commit 前）：

```bash
# profile / navigation consistency
python3 scripts/docs_consistency_check.py

# downstream project documentation baseline + PRD ↔ QA-TRACKER sync
python3 scripts/docs_consistency_check.py --project-docs

# branch / PR doc-code sync against base ref
python3 scripts/docs_consistency_check.py --project-docs --base-ref origin/main --doc-code-sync
```

人手理解版：比較 `docs/PRD.md` 與 `docs/QA-TRACKER.md` 的 `US-001` / `US-001.1` / `US-21.1` 清單，任何 diff = drift = 不可 ship。

**Drift = 不可 ship**。冇例外。

---

## 2. PRD ↔ QA-Tracker Sync Protocol

**改 PRD 即係改 scope** — 必須連帶更新 tracker：

| PRD 動作 | QA-Tracker 動作 |
|---------|----------------|
| 加新 US | 喺 tracker 加新 row（Status = PENDING 或 IN_PROGRESS）|
| 改現有 US scope | 改 row 嘅 Description column，加 Note 解釋 scope 改動 |
| 標 US 完成 | 改 Status = PASS，加 完成日期 |
| 標 US 部分完成 | 改 Status = PARTIAL，加 剩餘事項 |
| 刪除 US | 改 Status = DEPRECATED，加 刪除原因 |

**冇 tracker 對應嘅 PRD 改動 = 任務未完成**（紅線 11）。

**Tracker 對應嘅粒度**：

- 1 個主 US（如 `US-001`）對 1 row
- US 細分嘅 sub-task（如 `US-001.1` / `US-21.1`）拆 row
- bug fix / refactor = RG-XXX / TD-XXX row（唔可以只 inline 講）

---

## 3. 三層測試 Coverage Depth 要求

> 紅線 16 講「三層測試必須 pass」，但 pass 唔等如 cover。

**每層測試必須達到以下 minimum**：

| 層 | 最低要求 | 計算方式 |
|---|---------|----------|
| **Unit** | 覆蓋率 ≥ 70%（line + branch）| `bun test --coverage` 或 equivalent |
| **Integration** | 所有 internal API endpoint 有 happy + 1 sad path test | endpoint 對應 test case 列表 |
| **E2E** | 覆蓋**所有 P0 US 嘅 happy path** + 主要 edge case（auth fail、network timeout、空 state）| P0 US 列表 vs E2E 對應 |

**P0 US 嘅 E2E 對應**：

```
PRD US-P0-1: User login → E2E test: login.spec.ts:login_with_valid_creds
PRD US-P0-2: User logout → E2E test: logout.spec.ts:logout_clears_session
...
```

任何 P0 US 冇對應 E2E test → ship blocked。

**Test 唔可以係 placeholder**：

```typescript
// ❌ 唔可以
test("login works", () => {
  expect(true).toBe(true);  // placeholder
});

// ✅ 可以
test("login_with_valid_creds_returns_jwt", async () => {
  const res = await api.post("/auth/login").send({ email, password });
  expect(res.status).toBe(200);
  expect(res.body.token).toMatch(/^eyJ/);
});
```


---

## 3A. Regression Mode Gate（QA-friendly hooks / switches）

Regression mode 係 deterministic fixture / observability / seed / reset / test orchestration，**唔係 bypass mode**。

### 何時必須有 regression hook / switch

- 任何 bug fix（必須有 `RG-XXX` + regression test + QA 啟用方式）
- 任何 `RG-XXX` invariant 或 refactor 觸碰 `RG-` 標記 code
- P0/P1 User Story 的 critical path
- auth / RBAC / payment / upload / cache / queue / notification / audit-log 等高 regression 風險區域

### 必備 artifacts

| Artifact | 內容 | 必備場景 |
|---------|------|----------|
| `docs/REGRESSION-GUARD.md` | bug fix 的 RG entry + QA Regression Mode | 任何 bug fix |
| `docs/TEST-COVERAGE.md` | Regression Mode / Hooks matrix | 任何有 regression hook 嘅功能 |
| `docs/QA-TRACKER.md` | Regression Hook / Regression Mode 欄位 | 同上 |
| `docs/API.md`（現為 `endpoints/<resource>.md`）| backend `/__qa/*` 或等效 QA endpoint | 任何 backend QA endpoint |
| `docs/DESIGN.md`（現為 `components/<Name>.md`）| frontend QA panel / visual regression controls | 任何 frontend QA panel |
| ADR | test tenant、fake mailbox、test clock、queue drain、test-only architecture | 引入 test-only infrastructure |

### Production safety checks

- Production build 不包含 frontend QA panel / QA route
- Backend production 不 mount `/__qa/*`
- `NODE_ENV=production` + `REGRESSION_MODE=true` 必須 hard fail 或 loudly reject
- QA endpoint 必須有 auth / QA secret / staging SSO / IP allowlist 至少一種
- Regression helper 不可 disable auth、permission、rate limit、audit log、security behavior
- QA seed/reset 只能作用於 test tenant / test DB / test schema，不能動 production data 或真實 email/SMS/payment side effect

### `/__qa/*` endpoint merge policy

新增 / 修改 `/__qa/*` 或等效 backend QA endpoint 屬於 API contract change，必須同步：

- `docs/API.md`：method / path、purpose、request / response、auth / secret / allowlist、environment guard、tenant / data scope、audit logging、idempotency / reset behavior、production exposure expectation、相關 `US-XXX` / `RG-XXX`、test command / QA enablement
- `docs/TEST-COVERAGE.md`：Regression Mode / Hooks matrix row
- `docs/QA-TRACKER.md`：Regression Hook / Regression Mode status
- `docs/REGRESSION-GUARD.md`：如 endpoint tied to `RG-XXX` bug fix
- `docs/DESIGN.md`：如涉及 frontend QA panel / visual controls

`/__qa/*` 可以 seed / reset / observe deterministic fixtures，但不可 grant privilege、不可 bypass 真實 auth / permission / rate limit / audit / security behavior。Production 驗證必須證明 route 404 / 403 / hard reject 且沒有 side effect。

### Merge blockers

- `REGRESSION_MODE`、`/__qa`、`x-regression`、`seedRegression` 等 hook 無 env guard
- 禁止 / merge blocker: `skipAuth`、`bypassPermission`、`disableRateLimit`、`rateLimit = false` 等繞過語義出現在 regression code
- QA endpoint 無 auth / internal secret / staging allowlist
- Frontend QA panel 可在 production build 訪問
- `/__qa/*` 出現在 changed code，但 `docs/API.md` 未更新
- `/__qa/*` docs 缺 production boundary 或 auth / control language
- state-changing QA endpoint 缺 tenant / test DB / test schema scope
- unsafe bypass wording 作為 guidance，而不是 forbidden / anti-pattern / merge blocker
- `RG-XXX` entry 提到 backend hook，但缺 Production exposure check

未通過 Regression Mode Gate = 不可 merge / ship。

---

## 4. Pre-Ship Verification Flow

**順序固定，唔可以跳**：

```
1. Run default docs consistency check → profile docs / links / catalog 0 issue
2. Run project docs baseline check (`--project-docs`) → required docs + PRD ↔ QA-TRACKER 0 drift
3. Run doc-code sync check (`--base-ref origin/main --doc-code-sync`) → code 改動有對應 docs
3a. Review feedback sync check → no review / QA / code-review suggestion remains only in chat or PR comments; each is reflected in docs or explicitly deferred / rejected with rationale.
4. Read docs/PRD.md → 確認當前 scope
5. Read docs/QA-TRACKER.md → 確認當前 status
6. Run test suite → 3 層全部 pass + coverage 達 §3 要求
7. Run Regression Mode Gate (§3A) → hooks documented, QA-runnable, production-safe；如有 `/__qa/*`，驗證 production 404 / 403 / hard reject 且無 side effect
8. Update tracker → 反映當前 sprint 嘅真實狀態
9. 跑 smoke test（紅線 17）→ production-like env 0 error
10. Run security scan（紅線 18）→ 0 Critical/High CVE
11. 寫 post-delivery log（§5）
```

任何步驟 fail → 唔可以 ship，回到 phase 1-8 修正。

---

## 5. 交付後記錄 Protocol

每次交付後，喺 checkpoint 寫：

```
QA Gate — [功能名]
├── 驗證日期: YYYY-MM-DD
├── 範圍: [從 PRD 揀啲 US-XXX]
├── 三層測試狀態:
│   ├── Unit: X/Y pass, coverage Z%
│   ├── Integration: X/Y pass
│   └── E2E: X/Y pass, 覆蓋 US [list]
├── Doc sync: ✅ / ❌ (drift list)
├── Security scan: 0 Critical / 0 High
├── 遺留問題: [如有]
└── QA 負責人: Developer Profile
```

如果用戶發現 bug → 追加：

```
Bug 反饋 — P1/P2 — [描述]
├── RG-XXX: 新 regression guard ID
├── Root cause: [為何 QA 漏咗]
├── Prevention: [下次點改 QA Gate / red line]
└── 責任歸屬: QA 未發現 → +1 過
```

---

## 6. 持續改進 Loop

每次交付後問：

- 邊個 red line 觸發咗？
- 邊個 drift 差啲 miss？
- 三層測試有冇 false positive / false negative？
- QA Gate 嘅 checklist 夠唔夠 catch？

如有新發現 → 開新 red line / 更新本文檔 / 開新 skill。

**改 QA Gate 本身** 都需要過 QA Gate（self-referential）：

- 改 qa-gate.md 必須 commit + 過紅線 10（self-documenting）
- 新加嘅 red line 必須跟 qa-gate.md 嘅 §2 protocol 一致

---

## 7. QA 責任定義

**Developer 嘅職責係最後一道防線**：

- 每次交付前，必須完成 §4 嘅 11 步流程
- 發現 bug → 記錄喺 §5 → 修復後重新驗證
- 無法驗證嘅功能 → 明確告知用戶風險
- **未經驗證就交付 → 等同 P1 過**（紅線）

---

## 未通過嚴禁交付

未通過 §4 任何步驟嘅代碼嚴禁交付。如果用戶堅持要，必須明確告知風險並記錄喺 §5。

---

## Related docs

- [Documentation index](00-index.md)
- [Task tiering](task-tiering.md)
- [Testing strategy](testing-strategy.md)
- [QA tracker](qa-tracker.md)
- [Project documentation standard](project-documentation-standard.md)
