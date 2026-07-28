---
name: tech-debt-register
description: 記錄和追蹤技術債，幫忙估算修復時間。Template based，系統化追蹤優先級、修復成本、業務影響。
trigger: "tech debt / 技術債 / 技術負債 / debt register"
category: productivity
applicability: operational
---


Last-verified: 2026-07-28
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
2. **Finding fixed** → append a `✅ Fixed in <commit>` (or
   `✅ PARTIAL — <what's done> / <what's deferred> / <linked follow-up>`)
   row to the existing entry. **Do not move to an archive section.**
   The crm-system (2026-06-08) convention is to keep the original
   P?-N entry in place and stack status updates on it, so a
   future reader can see the full history (where, why, fix, est)
   in one block. An archive section splits this across the doc
   and makes "what was the original severity" hard to recover.
3. **Finding re-prioritised** → update severity, note why in the
   entry body.
4. **Finding deferred** → add a `⏸ Deferred: <reason>` tag. Don't
   delete — keep the historical record.

### Status row format (preferred by crm-system 2026-06-08)

```markdown
- **Status (YYYY-MM-DD):** ✅ Fixed in commit <sha> — <one-line summary>
- **Status (YYYY-MM-DD):** ✅ PARTIAL — <what's done> / <what remains>
  (file to follow-up: <US-NNN>)
```

**Why append-in-place, not archive-move:** A TECH-DEBT.md entry
gains value over time (status trail, follow-up links, PARTIAL
markers). Moving it to archive makes the original "where / why /
fix / est" 4 fields harder to find when an auditor asks "why is
this here" — the file becomes a graveyard of fixed items instead
of a living registry. The "Archive" section in the original
template is preserved in the Legacy section below for projects
that prefer that convention.
```

## 何時用呢個 5-field format vs 簡單 table

| Format | 適合 |
|--------|------|
| **5-field 細 entry**(本 skill 推薦 default) | 25+ finding 嘅 comprehensive review、security audit、需要交 dev 跟嘅項目、需要 est 嘅 sprint planning |
| **簡單 table**(`TD-001` 格式) | 5 個以下 finding、quick backlog、admin 唔需要 deep context |
| **Env-only fix**(env-bootstrap problem 變體)| host 跑 test 撞 fail / missing binary / container 內 OK 但 host 唔得 — 用 5-field 但 **影響拆三段**(dev friction / ship / prod),因為 env 問題對呢三層嘅影響係 independent |

**Rule of thumb**:超過 10 個 finding 就用 5-field,因為 table 太擠睇唔到 detail。

### Env-only fix entry 範本 (2026-06-08 pm-system TD-012)

```markdown
### 🟡 TD-012: Host 跑 `bun test` 撞 `tasks.test.ts` fail(環境問題,非 code)

- **發現日期**: <date> (Sprint <N> retro <doc>)
- **發現來源**: <retro 文件 / QA review / David cue>
- **症狀**: <exact error message + how to reproduce on host>
- **根因**: <host vs container 差異 — 通常係 build step 跑咗但 install step 冇跑>
- **影響**:
  - 🟡 **本地 dev friction** — <誰會撞>
  - 🟢 **唔影響 ship** — <docker / CI 點解 OK>
  - 🟢 **唔影響 production** — <runtime 點解唔受影響>
- **修復成本**: <日數,通常 0.01-0.1>
- **業務影響**: Low / Medium — <一句>
- **建議**: P2(純 DX polishing)
- **<date> 進展**: ✅ **已修** — <fix 詳情 + commit SHA>
- **守到**: <3 個 verify command 嘅具體 output>
```

**Why 三段影響 vs 一段 Why:** Env-only fix 嘅特有問題係「對 dev 係 friction,對 ship 係 invisible,對 prod 係 irrelevant」,合併寫會誤導 reviewer 以為係 ship blocker。拆三段令 priority tag 同影響範圍直接 visible。

## 何時用呢個 skill vs 其他

- **Tech debt catalog**(本 skill)— 跨 sprint / 跨 module 嘅結構性問題,5-field format
- **Regression Guard**(`regression-guard` skill)— 個別 bug fix 嘅 invariant,RG-XXX entry
- **QA Tracker**(`docs/QA-TRACKER.md` 配 `qa-tracker` 規範)— US → test 對照,per-feature status
- 三者互補,red-line 10/11/13 spec

## P0/P1 closure workflow (2026-06-09 pm-system Sprint 5)

當用戶問「清 N 個 P0/P1 tech debt」時嘅 recommended workflow,
combine 咗 user 嘅 options-first preference 同 plan-then-execute 紀律。

### 1. Plan 階段:逐個 TD 講 scope + 取捨,3 個選項俾 user 揀

**不要悶頭做**。每個 TD 都要:

- **現狀** — 1-2 行講解目前 code / config 嘅實際 state(grep 結果、import 數、call site 數)
- **改動** — 具體 file 改動清單(切忌抽象)
- **預期** — 量化 outcome(image size、test count、coverage %)
- **取捨問題** — 預設合理選項 + 1-2 個 alternatives + clarify 問 user

**典型 3-options template**(David preference, 2026-06-09 pm-system):
```
A) 【推薦】<safe practical win, 預設>
   - <outcome>
   - <cost>
B) 【激進】<push 落 deeper change>
   - <outcome>
   - <risk>
C) 【保守】<只做最 minimum>
   - <outcome>
   - <cost>
```

User 揀咗先開工。**不要假設 default,即使 plan 已經講咗。**

### 2. Todo 鎖住 scope

開工前 list 出所有 step 喺 `todo` tool,每個 step 一行
(decomposition rule: 1 step = 1 file / 1 commit / 1 verify command)。

**Pattern**:
```
TD-X: 移除 dead code <symbol list>
TD-X: 搬 <file> → <new path>
RG-XXX: 更新 <test file> assert 新 invariant
RG-XXX: 寫 REGRESSION-GUARD.md entry
TD-Y: Dockerfile multi-stage build
TD-Y: docker build 對比 image size
守住: bun test + playwright test 全 PASS
更新 docs/TECH-DEBT.md 標 3 個 P1 為 ✅ + Sprint N closure
```

### 3. Build 階段:每個 step 即 verify

- 改 file → `read_file` 確認未 corrupt(尤其 import line 未掉)
- 加 test → `bun test <file>` 即跑
- 改 Dockerfile → `docker build` 對比 size
- **LSP stale errors 係 noise** — trust `bun --print 'import(...)'` over LSP
  (詳見 `patch-corruption-recovery` 嘅 "Import-silently-dropped pitfall")

### 4. Verify 階段:全 suite 守住

```
cd backend && bun test              # unit
cd e2e && npx playwright test       # E2E (要 docker stack up)
```

如果 E2E 跑唔到(docker stack build 失敗),要:
- 確認 failure 係 pre-existing(grep `git log` 確認)
- 喺 TECH-DEBT.md 變更歷史記低 blocker
- 唔可以靜靜雞 skip 守住

### 5. Ship 階段:closure commit + doc update

- **1 個 closure commit** 包含所有 TD-X + RG-XXX 改動
  (commit message 結構:`refactor(sprintN): clear N P1 tech debt (TD-XXX/...) + RG-XXX`)
- 列出每個 TD 嘅 outcome (file changes, test count, size delta)
- **唔 stage sibling 嘅未 commit 改動**(用 `git add <specific files>` 唔好 `git add .`)
- 推 origin 後 verify `git status` clean

### 6. Document 階段:TECH-DEBT.md sprint closure

每個 TD entry 嘅「2026-06-XX 進展」section 加:
- 具體改動清單(file paths + lines)
- Result 數字(test count、size delta、coverage %)
- 守住方法(test command + expected output)
- 詳見 link 跳到 RG-XXX entry

行動計劃 section 加 `### Sprint N (P1) — ✅ DONE (date)` section
列出 5 個 checkbox(每個 TD + RG entry + 守住)。

變更歷史 section 加一行 closure 摘要(包括「E2E 跑唔到」嘅 blocker 註腳)。

### 7. User-facing report (終點)

4 段:
1. **改動清單**(table format: 範疇 / 改動 / 結果)
2. **守住**(command + pass count)
3. **風險 / Note**(pre-existing issues、out-of-scope 但發現嘅 bug)
4. **Commit hash + push status**
5. **P0/P1 debt 餘下狀態**(收尾 checklist)

David preference: **短、有用、不解釋 why**。每段 1-3 行。
**忌**:14K char inline report(紅線 49 v2, 2026-06-06 crm-system retro)
**宜**:1 個 final response < 3500 chars, hit 所有 verify point

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