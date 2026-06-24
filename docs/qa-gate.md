# QA Gate — 完整交付流程

> **Status:** Canonical. Source of truth for QA Gate release and merge requirements.

> **核心原則**: 未通過 QA Gate 的結果，絕對不能交付給用戶。
> **本文檔**: 係 SOUL.md § 紅線 10/11/16/17 嘅 detailed workflow。
> SOUL.md 只列條件，本文檔講執行 protocol。

---

## 0. Pre-Work Sync（任何工作開始前）

**改任何文件 / code 之前**，必須先確認當前狀態：

```bash
# 1. 文檔清單確認
ls docs/PROJECT-OVERVIEW.md docs/PRD.md docs/DESIGN.md docs/API.md \
   docs/TEST-COVERAGE.md docs/TECH-DEBT.md docs/QA-TRACKER.md 2>&1

# 2. QA-Tracker 當前 row 數
grep -c "^| US-" docs/QA-TRACKER.md

# 3. 工作 tree 狀態
git status --short
git log --oneline -5
```

**記錄起點**: 喺 checkpoint / 任務頂部記低當前狀態，作為 baseline。

---

## 1. Doc-Code Sync Check（任何改動後必跑）

**任何 code 或文檔改動** → 必須 sync 對應文檔：

| 改動類型 | 必須同步嘅文檔 |
|---------|---------------|
| **新 API endpoint** | `API.md`（+ `TEST-COVERAGE.md` 加 test case）|
| **架構改動** | 新 `ADR` + `DESIGN.md`（更新架構圖）|
| **User Story 改動** | `PRD.md`（更新 US）+ `QA-TRACKER.md`（PARTIAL / 新 row）|
| **Bug fix** | `REGRESSION-GUARD.md`（新 RG-XXX）+ `TEST-COVERAGE.md`（regression test）|
| **Refactor** | `TECH-DEBT.md`（新 row，標 DEPRECATED 嘅債務）|
| **依賴升級** | `TECH-DEBT.md`（upgrade 記錄）|

**Drift 檢測**（每次 commit 前）：

```bash
# 檢查 PRD 嘅 US 列表 vs QA-TRACKER 嘅 US 列表
grep -oP 'US-\d+\.\d+' docs/PRD.md | sort -u > /tmp/prd_us.txt
grep -oP 'US-\d+\.\d+' docs/QA-TRACKER.md | sort -u > /tmp/tracker_us.txt
diff /tmp/prd_us.txt /tmp/tracker_us.txt
# 任何 diff = drift = 不可 ship
```

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

- 1 個 US 對 1 row
- US 細分嘅 sub-task（如 US-21.1 / US-21.3）拆 row
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

## 4. Pre-Ship Verification Flow

**順序固定，唔可以跳**：

```
1. Read docs/PRD.md → 確認當前 scope
2. Read docs/QA-TRACKER.md → 確認當前 status
3. Run drift check (§1) → 0 diff 才繼續
4. Run test suite → 3 層全部 pass + coverage 達 §3 要求
5. Run doc-code sync check → 所有改動有對應 doc
6. Update tracker → 反映當前 sprint 嘅真實狀態
7. 跑 smoke test（紅線 17）→ production-like env 0 error
8. Run security scan（紅線 18）→ 0 Critical/High CVE
9. 寫 post-delivery log（§5）
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

- 每次交付前，必須完成 §4 嘅 9 步流程
- 發現 bug → 記錄喺 §5 → 修復後重新驗證
- 無法驗證嘅功能 → 明確告知用戶風險
- **未經驗證就交付 → 等同 P1 過**（紅線）

---

## 未通過嚴禁交付

未通過 §4 任何步驟嘅代碼嚴禁交付。如果用戶堅持要，必須明確告知風險並記錄喺 §5。

---

## Related docs

- [Documentation index](00-index.md)
- [Testing strategy](testing-strategy.md)
- [QA tracker](qa-tracker.md)
- [Project documentation standard](project-documentation-standard.md)
