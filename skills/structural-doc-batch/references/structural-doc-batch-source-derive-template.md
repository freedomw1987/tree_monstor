# Source-Derive Template — 8 份 Doc Starter

> **目的**:每份 doc 嘅 sections + example,copy 後 modify 即可。
> **Source-first**:所有 content 必須 derive 自 `cat` / `grep` / `read_file`,**唔好 LLM hallucinate**。

---

## Doc 1: `PROJECT-OVERVIEW.md`

### Sections 模板

```markdown
# <Project Name> — Project Overview

> **Status**: Active development (v<X.Y>, YYYY-MM)
> **Owner**: <team / dept>
> **Doc last updated**: YYYY-MM-DD

---

## 1. 項目一句話
<一句話定位>

## 2. 解決咩問題
<3 個 pain points,各 1 段>

## 3. In-Scope (做)
<table>每個模組一行</table>

## 4. Out-of-Scope (唔做)
- 外部客戶協作
- Mobile native app
- ...

## 5. 角色 × 權限 (RBAC 速覽)
<table>Role / 默認權限</table>

## 6. 技術棧
### Backend
- Runtime / Framework / ORM / DB / Auth / AI
### Frontend
- Build / Styling / Routing / State / Editor
### Infra
- Container / Reverse Proxy / DB Migrations

## 7. 部署拓樸
<ASCII 或 diagram ref>

## 8. 目錄結構
<tree>

## 9. 環境
<table>Env / URL / DB / 用途</table>

## 10. 重要決策 (索引)
- ADR-0001-...
- ADR-0002-...
- ADR-0003-...

## 11. 相關文件
<table>想知道... / 睇</table>
```

### Derive 步驟

```bash
# Stack
cat backend/package.json | grep -A 20 dependencies
cat frontend/package.json | grep -A 20 dependencies
# → 後端用咩 framework / 前端用咩 lib

# 目錄結構
ls -la backend/src/routes/  # routes 數量
ls -la frontend/src/pages/  # pages 數量
# → 估算 module 數量
```

---

## Doc 2: `PRD.md`

### Sections 模板

```markdown
# <Project Name> — Product Requirements Document (PRD)

> **Status**: Living document
> **Owner**: <team>
> **Last updated**: YYYY-MM-DD

---

## 1. 產品定位
<2-3 段>

## 2. 用戶角色 (Personas)
### P-<Role>
- **目標**:...
- **痛點**:...
- **典型任務**:...

## 3. User Stories
> **格式**: `US-X.Y` = Epic X,Story Y
> **Priority**: P0 = 必須 / P1 = 應該 / P2 = 可以
> **Status**: DRAFT / IN-PROGRESS / DONE

### Epic 1: <模組>
| ID | Story | Priority | Status |
|----|-------|----------|--------|
| US-1.1 | 作為 <persona>,我可以 <action> | P0 | DONE |
| ...

## 4. Non-Functional Requirements (NFR)
| NFR | 目標 | 備註 |
|-----|------|------|
| Performance | <target> | <note> |
| Security | ... | ... |
| Reliability | ... | ... |
| Usability | ... | ... |

## 5. 假設 + 限制

## 6. 變更歷史
| 日期 | 變更 | 來源 |
|------|------|------|
| YYYY-MM-DD | 初版 derive 自 source code | doc batch |
```

### Derive 步驟

```bash
# Personas — 對應 User.role field
grep -E "role.*String.*default" backend/prisma/schema.prisma
# → derive 5 個 role: admin, pm, tech_lead, developer, tester

# Epic — 對應 routes
ls backend/src/routes/ | sed 's/\.ts$//'
# → derive 12 個 Epic: projects, requirements, tasks, bugs, worklogs, ...

# US — 對應每個 route 嘅 method
grep -E "^\s*\.(get|post|put|delete|patch)" backend/src/routes/projects.ts
# → 4-5 個 US per Epic
```

---

## Doc 3: `architecture/NNNN-<topic>.md`(ADR)

### Sections 模板

```markdown
# ADR NNNN: <標題>

- **Status**: Accepted / Proposed / Deprecated / Superseded by ADR-NNNN
- **Date**: YYYY-MM-DD
- **Deciders**: <names>

## Context
<問題 / 為何要決策>

## Decision
<揀咗咩>

## Rationale
<點解揀,3-5 點>

## Alternatives Considered
### <Alternative 1>
- **Pros**: ...
- **Cons**: ...
- **Why not**: ...

## Consequences
### Positive
- ...

### Negative
- ...

### Mitigation
- ...

## References
- <file:line>
- <doc>
```

### Derive 步驟

```bash
# Stack-related ADR candidates
cat package.json | grep -E "elysia|express|hono|nestjs"
cat package.json | grep -E "prisma|drizzle|sequelize"
cat prisma/schema.prisma | grep "provider ="
# → 3 個 ADR candidates: backend framework / ORM / DB

# Design pattern ADR candidates
grep -E "isAgent" prisma/schema.prisma
# → 1 個 ADR: Agent = User pattern
```

---

## Doc 4: `API.md`(patch only, 唔好重寫)

### Patch 模板(已有 API.md 時)

```markdown
# API 文檔

> **Status**: 🟡 對齊中(YYYY-MM-DD) — endpoint 列表對齊 `backend/src/routes/*.ts`,response shape 可能有 drift,以 backend source 為準。

## 基礎信息
- **Base URL**: `http://localhost:4000/api`
- **認證方式**: Bearer Token(JWT)
- **Content-Type**: `application/json`
- **Auth Header**: `Authorization: Bearer <accessToken>`
```

### Derive 步驟(冇 API.md 時)

```bash
# List all endpoints
grep -rE "^\s*\.(get|post|put|delete|patch)\s*\(" backend/src/routes/ | \
  sed 's/.*\.\([a-z]*\)([^,]*\("[^"]*"\).*/\1 \2/' | sort -u
# → 寫入 API.md sections
```

---

## Doc 5: `TEST-COVERAGE.md`

### Sections 模板

```markdown
# <Project Name> — Test Coverage Report

> **Status**: YYYY-MM-DD snapshot
> **Method**: `find . -name "*.test.*" -not -path "*/node_modules/*"` 掃 source tree

---

## 1. 當前覆蓋率
| Layer | Test Files | 備註 |
|-------|-----------|------|
| Backend Unit | <N> | <files> |
| Backend Integration | <N> | — |
| Frontend Unit | <N> | <files> |
| Frontend Component | <N> | — |
| E2E | <N> | — |
| **Total** | **<N>** | **<X>% coverage (estimate)** |

## 2. Backend Test Inventory
### ✅ <file>
- 涵蓋:<US-IDs>
- 覆蓋 US: <US-IDs PARTIAL>
- 環境:<runner>

### ❌ 缺 test 嘅 routes
- `routes/<X>.ts` — 🔴 Critical(US-...)
- ...

## 3. Frontend Test Inventory
### ✅ <file>
### ❌ 缺 test 嘅 area

## 4. E2E 測試
- ❌ / ✅ <數量> 個
- 候選:<Playwright / Cypress>
- 至少 1 條 critical path 係 ship-blocker

## 5. Coverage 健康指標
| 指標 | 目標 | 當前 | 狀態 |
|------|------|------|------|
| Backend route test coverage | > 80% | <X>% | 🔴/🟡/🟢 |
| Frontend critical path test | > 50% | <X>% | 🔴/🟡/🟢 |
| E2E critical paths | 至少 3 條 | <X> | 🔴/🟡/🟢 |
| Regression test for fixed bugs | 100% | <X>% | 🔴/🟡/🟢 |
| 整體 % (lines covered) | > 70% | unknown | 🔴 |

## 6. 建議工具
| Layer | Tool | Why |

## 7. 行動項目
1. **Sprint 1 (P0)**:...
2. **Sprint 2 (P1)**:...
3. **持續**:...

## 8. 變更歷史
```

### Derive 步驟

```bash
find . -name "*.test.*" -not -path "*/node_modules/*" 2>/dev/null
# → 直接 list 出已有 test file
# → 對應 routes 數量 / pages 數量 = 缺幾多
```

---

## Doc 6: `TECH-DEBT.md`

### 5-field format(跟 `tech-debt-register` skill)

```markdown
# <Project Name> — Tech Debt Register

> **Status**: YYYY-MM-DD snapshot

---

## 0. Headline
| Severity | Count | Ship-blocking? |
|----------|-------|----------------|
| 🔴 P0 | <N> | Yes |
| 🟠 P1 | <N> | No (但應該) |
| 🟡 P2 | <N> | No |

## 🔴 P0 (Critical)
### TD-001: <title>
- **Where**: `<file>:<line>` (或 cross-file)
- **Why**: <技術原因>
- **Fix**: <code snippet>
- **Est**: S / M / L / XL
- **Linked**: <red-line numbers> / <RG-XXX> / <ADR-NNNN>

## 🟠 P1 (High)
...

## 🟡 P2 (Medium)
...

## 行動計劃
### Sprint 1 (P0)
- [ ] TD-001
- [ ] TD-002

### Sprint 2 (P1)
- ...

### Backlog (P2)
- ...

## 變更歷史
```

### Derive 步驟

```bash
# 從 commit 看到嘅「快速 fix」
git log --oneline --all | grep -iE "fix|bug|debug"
# → derive TD entries 反映 process debt

# 從 TEST-COVERAGE 看到嘅 gap
# 0 個 E2E test → TD-002
# RBAC 0 test → TD-001 (security)

# 從 source code 看到嘅 pattern
grep -r "rate-limit" backend/src/  # 0 match = TD-008 rate limiting
grep -r "logger" backend/src/      # pino 寫 stdout = TD-010 log aggregation
```

---

## Doc 7: `QA-TRACKER.md`

### Sections 模板

```markdown
# <Project Name> — QA Tracker (US ↔ Test 對照)

> **Status**: 🔴 YYYY-MM-DD — <coverage> % coverage
> **Rule**: 改 PRD 必更新本檔(紅線 11)

---

## 1. 對照表

### Legend
- **Test Status**: NONE / DRAFT / PARTIAL / PASS / FLAKY

| US | Priority | Backend Test | Frontend Test | E2E Test | Test Status | Owner |
|----|----------|--------------|---------------|----------|-------------|-------|
| **Epic 1: <Name>** | | | | | | |
| US-1.1 | P0 | ❌ / ✅ <file> | ❌ / ✅ | ❌ / ✅ | NONE / PARTIAL / PASS | TBD |
| ...

## 2. 健康指標
| 指標 | 數值 |
|------|------|
| US 總數 | <N> |
| NONE | <N> |
| PARTIAL | <N> |
| PASS | <N> |
| **Coverage %** | **<X>%** |

🔴 **Ship blocker**: 紅線 12 規定 P0 US 必須 PARTIAL/PASS。

## 3. 補 test 優先序(下一個 sprint)
1. 🔴 US-X.Y
2. 🔴 US-X.Y
3. 🟡 ...

## 4. 變更歷史

## 5. 變更規則
**改 PRD 必更新本檔**(紅線 11)。
```

### Derive 步驟

```bash
# US 列表 — 從 PRD.md derive
# Test files — 從 find derive
# Cross-reference: 對每個 US 標 ❌ / ✅ / NONE / PARTIAL
```

---

## Doc 8: `REGRESSION-GUARD.md`(如有 fix commit history)

### RG-XXX entry format(跟 `regression-guard` skill)

```markdown
# <Project Name> — Regression Guard

> **Status**: YYYY-MM-DD 初版
> **Rule**: 每個 bug fix 必須有 RG-XXX entry(紅線 13)

---

## 1. 目的
防止修復過嘅 bug 重新出現。

## 2. Bug 記錄

### RG-001: <title>
- **發現日期**: YYYY-MM
- **Symptom**: <症狀>
- **Root cause**: <技術原因 + 過程原因>
- **Fix**: <fix description>
- **Prevention**: <3 個措施>
- **Regression test**: ❌ / ⚠️ / ✅
- **Ref**: commit `<sha>`

### RG-002: ...
...

## 3. Pattern 觀察
<觀察多個 entry 嘅 pattern,例:AI / Agent 係最脆弱>

## 4. Regression test 模板
```typescript
// tests/regression/RG-XXX.test.ts
import { describe, expect, test } from 'bun:test';

describe('RG-XXX: <bug 簡述>', () => {
  test('should NOT <舊 bug 行為> when <觸發條件>', async () => {
    // arrange
    // act
    // assert
  });
});
```

## 5. 變更歷史

## 6. 規則
**冇 entry 嘅 fix 唔可以 merge**(紅線 13)。
**Root cause + Prevention 兩部分都必填**(紅線 14)。
```

### Derive 步驟

```bash
# Fix commits
git log --oneline --all | grep -iE "fix|bug|debug"
# → derive 5 個 RG entry
# → 每個 entry 必查 git show 確認 detail(避免 fabricate)
git show <sha> --stat
```

---

## Doc 9: `retros/YYYY-MM-DD-initial-doc-batch.md`

### Sections 模板

```markdown
# Retro: YYYY-MM-DD — Initial Documentation Batch

> **Sprint**: Doc batch (non-feature)
> **Facilitator**: Tree Monstor Developer
> **Attendees**: David + Developer
> **Duration**: ~<X> hour

---

## 1. 觸發
David 講:「<原句>」

Reason: <為何要補 doc>

## 2. 做咗咩
<table>Doc / 大小 / 內容</table>

**Total**: <N> 份新文件,共 <X>KB markdown。

## 3. 過程觀察

### ✅ Good
- ...

### ⚠️ Caution
- ...

### ❌ Blockers 發現
- ...

## 4. Action Items
| ID | 行動 | Owner | 目標 |
|----|------|-------|------|
| ACT-1 | ... | TBD | Sprint 1 |
| ...

## 5. Lessons
1. ...
2. ...

## 6. Reference
- SOUL.md 紅線 ...
- <source files>
```

---

## 🎯 共通 Derive 守則

1. **Source-first**:每份 doc 嘅數字 / 數量 / content 必須對應 `cat` / `grep` 結果
2. **Date 一致**:用 YYYY-MM-DD 格式,UTC 唔好用
3. **Status legend 一致**:DRAFT / IN-PROGRESS / DONE / DEPRECATED(NOT 「完成」/「WIP」/etc)
4. **Cross-reference**:doc 之間互相 link,例:TECH-DEBT 嘅 TD-XXX linked 返 RG-XXX
5. **❓ 標記 TBD**:任何 derive 唔到嘅 entry,寫 TBD + 入 retro action items,**唔好 fabricate**
6. **Commit message 詳盡**:8 份 doc 列表 + 重要發現 + 警告(如 working tree untracked changes)
