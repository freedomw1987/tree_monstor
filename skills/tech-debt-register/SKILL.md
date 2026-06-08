---
name: tech-debt-register
description: 記錄和追蹤技術債，幫忙估算修復時間。Template based，系統化追蹤優先級、修復成本、業務影響。
trigger: "tech debt / 技術債 / 技術負債 / debt register"
version: 1
category: productivity
---

# Tech Debt Register

系統化記錄、優先級排序、和規劃償還技術債。

## Tech Debt 模板

```markdown
# Tech Debt Register — {project_name}

> **Source:** <review date> code review (Security A + Architecture B + Ship Gate C)
> by Developer. Each entry has: where, why, severity, estimated cost,
> and the P0/P1/P2 priority assigned by red-line 10 + business risk.
> **Update this file when a finding is fixed, deferred, or re-prioritised.**

---

## 0. Headline

| Severity | Count | Ship-blocking? |
|----------|-------|----------------|
| 🔴 **P0** (critical, blocks ship) | <N> | Yes |
| 🟠 **P1** (high, must fix this sprint) | <N> | No (but should) |
| 🟡 **P2** (medium, backlog) | <N> | No |

**Target:** all P0 done before next prod ship. P1 in this sprint. P2
maintained as a known backlog.

---

## P0 — Ship blockers (must fix before next deploy)

### P0-N — <one-line title>
- **Where:** `<file>:<line>` (single file) or `<file>` (cross-file)
- **Why:** <technical reason — what goes wrong, what an attacker can do>
- **Fix:** <exact code change with example snippet>
- **Est:** <S / M / L / XL>
- **Linked:** <red-line numbers> / <related RG-XXX> / <related ADR-NNNN>

### P0-1 — 示例: Self-registration allows picking `role: 'ADMIN'`
- **Where:** `apps/api/src/routes/auth.ts:69-105`
- **Why:** `POST /auth/register` has no `.use(authContext)` or
  `.use(requirePermission('user:create'))`. Body schema accepts
  `role: t.Union([ADMIN, SALES, VIEWER])` from the client. Anyone on the
  public internet can self-register as admin in one request.
- **Fix:** Add `requirePermission('user:create')` and drop the `role`
  field from the body schema; new users default to SALES. Admins promote
  via the existing `PATCH /users/:id` flow.
- **Est:** 1 hour
- **Linked:** red-lines 3/5/7 (security; implicit in red-line 11).

---

## P1 — High (this sprint, after P0)

### P1-N — <one-line title>
- **Where:** `<file>` (or list of files)
- **Why:** <technical reason>
- **Fix:** <proposed solution>
- **Est:** <S / M / L / XL>
- **Linked:** <related entries>

---

## P2 — Medium backlog (sprint +1 or later)

### P2-N — <one-line title>
- **Where:** `<file>`
- **Why:** <reason>
- **Fix:** <approach>
- **Est:** <S / M / L / XL>

---

## Cross-references

- **Red-line 10** (`docs/project-documentation-standard.md`): this file
  is the project-documentation standard's `TECH-DEBT.md` requirement.
- **Red-line 11** (`docs/qa-tracker.md`): QA-TRACKER.md is the per-US
  status; this file is the cross-cutting tech debt (architecture +
  security + ops). Different concern, both required.
- **Red-line 13** (`skills/regression-guard/`): each bug fix gets an
  RG-XXX entry; tech debt items are pre-existing structural issues
  and don't get RG- entries unless they have already caused a bug.
- **Red-line 16/17/18** (testing + smoke + CVE): tracked in
  `docs/qa-gate.md` and `docs/TEST-COVERAGE.md`.

---

## How to update this file

1. **New finding** discovered → append a new `### P?-N` block with
   location, why, fix, est, linked entries.
2. **Finding fixed** → change severity tag, append `✅ Fixed in <commit>`
   with date, move to a `## Archive` section at the bottom.
3. **Finding re-prioritised** → update severity, note why in the
   entry body.
4. **Finding deferred** → add a `⏸ Deferred: <reason>` tag. Don't
   delete — keep the historical record.
```

## 何時用呢個 5-field format vs 簡單 table

| Format | 適合 |
|--------|------|
| **5-field 細 entry**(本 skill 推薦 default) | 25+ finding 嘅 comprehensive review、security audit、需要交 dev 跟嘅項目、需要 est 嘅 sprint planning |
| **簡單 table**(`TD-001` 格式) | 5 個以下 finding、quick backlog、admin 唔需要 deep context |

**Rule of thumb**:超過 10 個 finding 就用 5-field,因為 table 太擠睇唔到 detail。

## 何時用呢個 skill vs 其他

- **Tech debt catalog**(本 skill)— 跨 sprint / 跨 module 嘅結構性問題,5-field format
- **Regression Guard**(`regression-guard` skill)— 個別 bug fix 嘅 invariant,RG-XXX entry
- **QA Tracker**(`docs/QA-TRACKER.md` 配 `qa-tracker` 規範)— US → test 對照,per-feature status
- 三者互補,red-line 10/11/13 spec

## Legacy simple-table template(保留向後兼容)

```markdown
# Tech Debt Register — {project_name}

## 條目格式
| ID | 描述 | 模組 | 優先級 | 修復成本 | 業務影響 | 狀態 | 日期 |

### 優先級定義
- **P0 (Critical)**: 影響核心功能或安全，立即修復
- **P1 (High)**: 影響開發效率，1-2週內修復
- **P2 (Medium)**: 技術上有問題，下個 sprint 修復
- **P3 (Low)**: 可忽略或下次重構時處理

### 修復成本估算
- **S (Small)**: < 4 小時
- **M (Medium)**: 4-16 小時
- **L (Large)**: 16-40 小時
- **XL (Extra Large)**: > 40 小時（需要單獨 sprint）

---

## P0 — Critical

| ID | 描述 | 模組 | 修復成本 | 業務影響 | 狀態 | 日期 |
|----|------|------|---------|---------|------|------|
| TD-001 | 密碼明文存儲 | Auth | M | 安全風險 | TODO | 2026-05-10 |
```


## 使用方式

### 識別 Tech Debt
當發現以下情況時，立即記錄：
- 臨時解決方案（workaround）
- 重複代碼超過 3 次
- 沒有測試覆蓋的關鍵代碼
- 已知性能問題
- 安全漏洞或潛在風險

### 觸發 Subagent
```python
delegate_task(
    goal="記錄新發現的技術債",
    context="""
    描述：API 沒有 rate limiting
    模組：backend/api
    優先級：P1
    修復成本：S (< 4 小時)
    業務影響：DDoS 風險
    """,
    role="leaf",
    toolsets=['terminal', 'file']
)
```

### Sprint Planning
在每個 sprint planning 時：
1. 讀取 `docs/tech-debt.md`
2. 選擇該 sprint 能完成的 TD（根據修復成本）
3. 在 sprint backlog 中加入 Tech Debt 償還任務
4. 目標：每個 sprint 償還 1-2 個 P1 TD

## 償還原則

1. **先高優先級**：P0 > P1 > P2 > P3
2. **先低成本**：同優先級時，先做 S 再做 M/L/XL
3. **業務影響**：同優先級時，先做高業務影響的
4. **不要累积**：發現就記錄，不要假裝看不見
5. **償還時間**：估算 × 2（實際通常更久）