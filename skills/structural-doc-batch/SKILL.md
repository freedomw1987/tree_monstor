---
name: structural-doc-batch
description: |
  為已有 project 補 / 重做 8 份結構性文檔(PROJECT-OVERVIEW / PRD / ARCHITECTURE / ADR / API / TEST-COVERAGE / TECH-DEBT / QA-TRACKER / REGRESSION-GUARD / retros)
  以對齊 SOUL.md 紅線 10 + 11 + 12 + 13 + 14 + 16。Use when David 講「我補一下文檔」「補 doc」「對齊 red line 10」「project 缺 overview / PRD / QA tracker」或新接手 project 要一次過補齊結構。
  Class-level — 適用於任何 project(backend / frontend / mobile / infra),不限特定 codebase。
trigger: |
  「我補一下文檔」「補 doc」「對齊 red line 10」「缺 PROJECT-OVERVIEW / PRD / QA tracker」
  「新接手 project」「8 份 doc 一次過」「doc batch」「ship 之前要 doc」
  或任何「我哋個 project 缺結構性文檔」嘅情境
version: 1
category: software-development
---

# Structural Doc Batch — 8 份文檔 Batch Operation

> **為什麼需要這個 skill** — SOUL.md 紅線 10 + 11 + 13 規定:
> 任何 project 在 ship 之前,**8 份結構性 doc 必須存在並 commit 到 git**。
> 冇 doc 嘅 code 唔可以 merge;改 PRD 冇更新 tracker = 任務冇做。
>
> 現實係:大部份 internal project(尤其 PM System / CRM / admin tool)喺 0-6 個月內
> feature code 行先,**8 份 doc 全部缺**。一旦 David 問「呢個 project 缺 overview / PRD / QA tracker」,
> 就係呢個 skill 嘅 trigger。

---

## 🎯 8 份 Doc 速覽(SOUL.md 紅線 10)

| # | 文件 | 用途 | 必須內容 |
|---|------|------|---------|
| 1 | `docs/PROJECT-OVERVIEW.md` | 項目定位、scope、stack、拓樸、env | one-line summary / In-scope / Out-of-scope / 角色 / 技術棧 / 目錄結構 / 環境 / 相關文件索引 |
| 2 | `docs/PRD.md` | User Stories | Personas + Epic + US(P0/P1/P2 + Status)+ NFR + 變更歷史 |
| 3 | `docs/DESIGN.md`(如有 UI) | 視覺 / 互動 spec | tokens / layout / component lib / page patterns / RWD |
| 4 | `docs/architecture/NNNN-*.md`(至少 1 個 ADR) | 架構決策 | Status / Context / Decision / Rationale / Consequences / Alternatives |
| 5 | `docs/API.md`(如有 API) | Endpoint 參考 | Conventions + 全 endpoint per resource |
| 6 | `docs/TEST-COVERAGE.md` | 測試覆蓋率 inventory | Layer 列表 + US↔test matrix + 健康指標 + 行動 |
| 7 | `docs/TECH-DEBT.md` | 技術債 | 5-field format(P0/P1/P2)+ Cross-references + 變更規則 |
| 8 | `docs/QA-TRACKER.md` | US ↔ test status | US table + 健康指標 + 補 test 優先序 + 變更規則 |
| 9(可選) | `docs/REGRESSION-GUARD.md` | Bug 修復追蹤 | RG-XXX entry template(紅線 13 強制 if 有 bug fix history) |
| 10(可選) | `docs/retros/YYYY-MM-DD-*.md` | Sprint 復盤 | 觸發 / 過程 / Action items / Lessons |

> **無需重頭寫**:`docs/ARCHITECTURE.md`(拓樸圖)可選擇性 derive,呢個係
> 「講架構點運作」嘅 narrative doc,唔係 紅線 10 強制嘅 8 份之一。
> 但有齊對後續 onboard 有 value。

---

## 🚀 核心流程(Source-First Derive)

```
David 講「我補一下文檔」/「缺 doc」
    ↓
Step 0: 確認 scope(2-4 個 option 俾 David 揀)
    ↓
Step 1: Source inventory — 讀 source code(derive content,唔好 hallucinate)
    ↓
Step 2: 9 份 doc batch write(每份 derive 自 source)
    ↓
Step 3: git status -s(檢查 working tree 有冇 untracked changes 唔屬於呢個 batch)
    ↓
Step 4: 淨 stage 屬於呢個 batch 嘅 file(避 drift / 撞 David 已 commit 嘅嘢)
    ↓
Step 5: 一個 commit(整個 doc batch) + 顯式列 untracked 變更喺 commit message
    ↓
Step 6: Retro + action items 入 retros/YYYY-MM-DD-*.md
    ↓
Step 7: 提議下一個 sprint 嘅補 test 行動
```

---

## 📋 Step-by-Step 詳細執行

### Step 0: 確認 scope(必須提供 2-4 個 options)

**永遠唔好悶頭做** — David 嘅需求表面可能只係「補 doc」,但實際有唔同 scope:

```
A) 【全面合規】一次性補齊 8 份(估 4-6 小時)
B) 【核心 4 份】PROJECT-OVERVIEW + PRD + QA-TRACKER + TEST-COVERAGE(估 2-3 小時)
C) 【最少 1 張】只做 PRD + QA-TRACKER(紅線 11 強制)(估 1-1.5 小時)
D) 【您揀】David 揀邊幾份
```

> **Plan's Plan/Think 互動原則**:係 David 揀 scope,而唔係你自己 pick。
> 如果 David 用短 cue(A / B / C / X),跟佢嘅選擇,唔好再問。

### Step 1: Source inventory(Source-First, **絕對唔好 hallucinate**)

```bash
# Backend / 源碼層
ls -la docs/                                    # 已有 doc 列表
git log --oneline -15                           # commit history
find backend/src -name "*.ts" | head -30        # routes / modules
find frontend/src -name "*.tsx"                 # pages
cat backend/prisma/schema.prisma | grep "^model "  # data models
ls backend/src/routes/                         # 19 個 routes?

# Test inventory
find . -name "*.test.*" -not -path "*/node_modules/*"
# → 0 個 = 🔴 0% coverage 嘅 known gap,寫入 TEST-COVERAGE + TECH-DEBT
# → 已有 = 寫入 inventory section

# Fix commit 紀錄(derive RG-XXX entries)
git log --oneline --all | grep -iE "fix|bug|debug"
```

**Inventory output 一定喺 emit final response 之前 verify**,唔可以 skip。

### Step 2: 9 份 doc batch write

#### Doc 1: PROJECT-OVERVIEW.md
- 一句話定位
- In-scope / Out-of-scope(3-5 行)
- 角色 × 權限 RBAC 速覽
- 技術棧(Backend / Frontend / Infra)
- 部署拓樸(ASCII 或 diagram reference)
- 目錄結構(tree)
- 環境(local / staging / prod)
- 重要決策索引(ADR list)
- 相關文件索引

#### Doc 2: PRD.md
- Personas(3-6 個,每個 goal / pain points / 任務)
- Epic 結構(每個 Epic 對應模組)
- US 格式:`US-X.Y` ID + Priority + Status
- NFR(Performance / Security / Reliability / Usability)
- 假設 + 限制
- 變更歷史

> **Status legend**:`DRAFT` / `IN-PROGRESS` / `DONE` / `DEPRECATED`
> **唔可以 skip Status**,否則 QA-TRACKER 對唔到。

#### Doc 3: ADR(每個 ADR 1 份 file)

Format:
- **Status**(Proposed / Accepted / Deprecated / Superseded by ADR-NNNN)
- **Date**
- **Context**(問題 / 為何要決策)
- **Decision**(揀咗咩)
- **Rationale**(點解揀)
- **Alternatives Considered**(其他 option + why not)
- **Consequences**(Positive / Negative)
- **Mitigation**(點 cover 負面)
- **References**

> **數量**: 至少 1 份 ADR,理想 3-5 份(framework 選型 / ORM 選型 / key design pattern / schema 設計)

#### Doc 4: API.md

> **Anti-pattern:重寫 578 lines 嘅 API.md 風險 high**(drift)
> **正確做法**:patch + status header 註明對齊中。

```bash
# 1. 先 verify endpoint 對齊 backend source
diff <(grep -oE "(GET|POST|PUT|DELETE|PATCH) /[a-z/:{}-]+" backend/src/routes/*.ts | sort -u) \
     <(grep -oE "(GET|POST|PUT|DELETE|PATCH) `/[a-z/:{}-]+" docs/API.md | sort -u)
# 2. Patch header
```

Patch template:
```markdown
# API 文檔

> **Status**: 🟡 對齊中(YYYY-MM-DD) — endpoint 列表對齊 `backend/src/routes/*.ts`,response shape 可能有 drift,以 backend source 為準。

## 基礎信息
- **Base URL**: `http://localhost:4000/api`
- **認證方式**: Bearer Token(JWT)
- **Content-Type**: `application/json`
- **Auth Header**: `Authorization: Bearer <accessToken>`
```

#### Doc 5: TEST-COVERAGE.md

- 當前覆蓋率 table(Backend unit / integration / Frontend unit / Component / E2E)
- Backend test inventory(已有 + 缺嘅 routes 列表)
- Frontend test inventory(已有 + 缺嘅 area 列表)
- E2E 數量 + 候選工具(Playwright / Cypress)
- 健康指標(目標 vs 當前)
- 行動項目(Sprint 1 P0 / Sprint 2 P1 / Backlog)

#### Doc 6: TECH-DEBT.md

跟 `tech-debt-register` skill 嘅 **5-field format**:
- Where:`<file>:<line>` 或 cross-file
- Why:技術原因
- Fix:proposed code change
- Est:S / M / L / XL
- Linked:red-line numbers / RG-XXX / ADR-NNNN

> **重要**:entry 數量多就分 `P0 / P1 / P2` section。
> 改 commit 嘅同時 update TECH-DEBT,delete fixed entry 標 `✅ Fixed in <commit>`。

#### Doc 7: QA-TRACKER.md

| US | Priority | Backend Test | Frontend Test | E2E Test | Test Status | Owner |
|----|----------|--------------|---------------|----------|-------------|-------|

- **Test Status**:`NONE / DRAFT / PARTIAL / PASS / FLAKY`
- **健康指標** table(US 總數 / NONE / PARTIAL / PASS / Coverage %)
- **補 test 優先序**(下一個 sprint P0)
- **變更規則**(紅線 11):改 PRD 必更新本檔

> **🔴 Ship blocker**:紅線 12 規定 P0 US 必須 PARTIAL/PASS。Coverage 0% = 必須在 sprint 1 補。

#### Doc 8: REGRESSION-GUARD.md(如有 bug fix history)

跟 `regression-guard` skill 嘅 **RG-XXX entry** format:
- 發現日期 / 發現者 / 影響版本 / 修復版本 / Commit
- 症狀 / Root Cause(技術 + process)/ 防止再發(防護措施)/ 相關 Issue

> **如果 git log 入面有 `fix:` / `bug:` / `debug:` commit** → 必須 derive 對應 RG entry。
> 唔可以淨寫「冇 known bug」,因為 git history 已經有。

#### Doc 9: retros/YYYY-MM-DD-*.md(本 batch 自己嘅 retro)

- 觸發(點解做呢個 batch)
- 做咗咩(9 份 doc 一覽)
- 過程觀察(✅ Good / ⚠️ Caution / ❌ Blockers 發現)
- Action items(下個 sprint 跟進)
- Lessons(往後同類 project 可 reuse 嘅 insight)
- Reference(紅線 / source files)

### Step 3: git status -s(🚨 必須,避開 working tree untracked changes 撞 commit)

```bash
cd ~/www/<project>
git status -s
```

**常見發現**:
- `D <file>` — 有人刪咗 file(可能 David 之前 `rm`)
- `M <file>` — working tree 仲有未 commit 嘅改動
- `?? <file>` — untracked

**正確處理**:
- 屬於呢個 doc batch 嘅 → `git add`
- **唔屬於嘅 → 唔 stage**,等 David 確認
- **Delete file** → 寫入 commit message 顯式標明,等 David 確認

> **Anti-pattern**:盲目 `git add .` 撞 David 嘅 manual 刪除 = 永久資料損失
> **正確**:明確 `git add <doc-batch-files>` only

### Step 4: 精準 stage

```bash
git add docs/PROJECT-OVERVIEW.md docs/PRD.md docs/QA-TRACKER.md \
        docs/REGRESSION-GUARD.md docs/TECH-DEBT.md docs/TEST-COVERAGE.md \
        docs/architecture/ docs/retros/ docs/API.md
git status -s
# 確認:只有 doc batch 嘅 file 喺 staged,冇其他
```

### Step 5: 一個 commit + 顯式列 untracked changes

```bash
git -c user.email="dev@pm-system.local" -c user.name="Tree Monstor" commit -m "docs: add 8 份結構性文檔 (PROJECT-OVERVIEW/PRD/QA-TRACKER/REGRESSION-GUARD/TECH-DEBT/TEST-COVERAGE/3x ADR/retro)

- docs/PROJECT-OVERVIEW.md: 定位、scope、stack、拓樸
- docs/PRD.md: 5 personas + 12 epics + 50+ US
- docs/architecture/0001-bun-elysia-backend.md: ADR backend 選型
- docs/architecture/0002-prisma-5-pg.md: ADR 數據層選型
- docs/architecture/0003-ai-agent-as-user.md: ADR Agent=User 設計
- docs/TEST-COVERAGE.md: inventory + gap analysis
- docs/TECH-DEBT.md: 10 debt entries (P0 = test coverage + E2E)
- docs/QA-TRACKER.md: US ↔ test 對照 (~5% coverage)
- docs/REGRESSION-GUARD.md: 5 RG entries derive 自 git log
- docs/retros/2026-06-08-initial-doc-batch.md: 本次 retro
- docs/API.md: + status header 註明對齊中

對齊 SOUL.md 紅線 10 ship-blocker。9 份新 doc + 1 patch,共 ~37KB markdown。

⚠️ <other working tree 變更> 已被 working tree 刪除(未 commit 個 delete),等 David 確認。"
```

> **關鍵**:commit message 列出**所有 working tree 變更**,包括 delete,
> 方便 David 一眼睇到「呢個 commit 入面有冇撞到我啲 manual rm」。

### Step 6: Retro

> **永遠寫 retro**(Step 9)。原因:doc batch 嘅 process 應該被記錄,
> 下次新 project 開 batch 可以 reuse 同樣 workflow。

### Step 7: 提議下一個 sprint 行動

> 補 doc 唔等於 ship-ready。常見發現:
> - 0 個 E2E test(紅線 17 ship-blocker)
> - 0% backend test coverage(紅線 12 P0 US 必 test)
> - RBAC 0 test(security critical)
> - AI / Agent fragile area 0 regression test
>
> 寫入 retro 嘅 Action items + 喺 emit final response 提議。

---

## ⚠️ Pitfalls(2026-06-08 pm-system doc batch 親驗)

### Pitfall 1: Working tree untracked changes 撞 commit 永久資料損失

**場景**:pm-system doc batch 嗰陣,`git status -s` 見到
`D docs/SOW_PM_System_報價建議書.docx`(David 之前 manual rm 嘅 file)。
盲目 `git add .` 會 commit 個 delete = 永久 lost 一份 doc。

**Detection signal**:`git status -s` 任何 `D` 行 = 必須顯示
列喺 commit message,淨 stage 屬於 doc batch 嘅 file。

**Prevention**:
1. `git status -s` 喺 stage 之前必跑
2. 精準 `git add <specific-paths>`,唔好 `git add .`
3. Commit message 顯式列 untracked changes / deletes
4. Final response 提問:「Q1: <file> 刪 / 留」

### Pitfall 2: API.md 重寫 578 lines 撞 drift

**場景**:pm-system 嘅 `docs/API.md` 已有 578 lines 完整 endpoint 列表。
如果用 doc batch derive 重新生成,容易同 backend source 撞 shape drift。

**Prevention**:
- **永遠 patch 唔好 overwrite** large existing doc
- Patch status header(`🟡 對齊中 — endpoint 對齊 backend source, response shape 可能 drift`)
- Doc 5 / Doc 7 嘅 derive 已經覆蓋 endpoint inventory,API.md 只做 status annotation

### Pitfall 3: LLM 記憶 hallucinate content

**場景**:不 derive from source,直接 LLM 寫 PRD / ADR / TECH-DEBT 嘅 entry
= invented content(假嘅 US、假嘅 debt、假嘅 root cause)。

**Prevention**:
- **Source-first 永遠 stable 過 LLM 記憶**
- 8 份 doc 全部 derive 自 `cat` / `grep` / `read_file`
- Final emit 之前 sanity check:US 數量對應 code modules?debt entry 對應真實 files?
- 如果 LLM 記憶有 gap → 寫「TBD」flag 入 retro action items,**唔好 fabricate**

### Pitfall 4: Skip retro = 失去 process insight

**場景**:doc batch 完成 → 寫完最後一份 doc → 直接 commit → end。
**冇 retro** = 下次開新 project 唔知點 derive / 點 source-first / 點避免 drift。

**Prevention**:
- **永遠寫 retro**(Step 9)— 9 份 doc 之後,doc 9 必須寫 retros/。
- Retro section:✅ Good / ⚠️ Caution / ❌ Blockers 發現 / Action items / Lessons
- Action items 入下個 sprint

### Pitfall 8: 對外文件 (USER-MANUAL / ONBOARDING) 用咗 David 嘅廣東話口語 (2026-06-09 pm-system)

**場景**:agent 慣性將 David 嘅 conversation Cantonese 口語 (`嘅/嗰/啲/咗/唔/冇/嚟/睇下/跟住/幾多/點解`) 寫入正式 doc。USER-MANUAL.md 第一次出嗰陣用咗「我哋」、「點樣」、「項目入面要解決嘅問題」等等 — 對客戶/新同事讀起嚟唔正式。

**預防**:
- USER-MANUAL / API doc / ONBOARDING / PRD / 任何**對外文件**必須用**中文書面語 (普通話)**。
- David 嘅 conversation style 同 document style 係兩回事 — agent 唔好 carry over。
- 廣東口語 → 書面語 mapping:
  - `嘅/嗰/啲` → `的/该/些`
  - `咗/唔/冇/嚟/咩` → `了/不/无/来/什么`
  - `啲/㗎/啦/喇` → (刪)
  - `睇下/跟住/幾多/邊個/點解/點樣` → `查看/然后/多少/哪个/为什么/如何`
- 角色全名化:「Admin」→「管理员」、「PM」→「项目经理」、「Developer」→「开发人员」(注意簡體/繁體場合)
- 動詞:「會/有/做/整/用」→「将会/具有/执行/创建/使用」
- Verification: `grep -nE "嘅|嗰|啲|咗|咩|唔|冇|嚟|㗎|啦|喇" docs/USER-MANUAL.md` 必須 0 行先算書面語化完成。
- **Skip rule**: `docs/PROGRESS.md` / `docs/retros/` / `docs/_meta/` / 對 David 嘅 internal note 類文件**保留**廣東話口語 (呢啲係 internal voice)。

### Pitfall 5: Doc 8 / 9 互動矛盾

**場景**:REGRESSION-GUARD.md 寫咗 RG-001(AI Agent claim 失敗) +
RG-002(LLM hang),但 TECH-DEBT.md 冇將呢啲已知 fragile area 列入 TD entry。
**Cross-reference missing** = 兩份 doc 講唔同嘅 truth。

**Prevention**:
- TECH-DEBT.md entry 嘅 Linked 字段必引用相關 RG-XXX
- REGRESSION-GUARD.md entry 嘅 Prevention section 必引用相關 TD-XXX
- 任何 entry 寫完,即時 cross-check 其他 doc 嘅 index table

### Pitfall 6: Doc 8 RG entry 冇 root cause + prevention

**場景**:跟 `git log` derive 5 個 fix commit 嘅 RG entry,但只寫
`Symptom + Fix + Commit`,冇 Root Cause + Prevention 兩部分。

**紅線 14 違規**:**淨寫 code 改動冇寫點解嘅 fix 唔可以 merge**。

**Prevention**:
- 跟 `regression-guard` skill 嘅 entry template 100%
- Symptom / Root Cause(技術 + process)/ Prevention(3 個措施)四部分都必填
- Root cause 寫 **技術原因 + 過程原因**(淨寫「我加咗個 if」偷懶)
**場景**:doc batch 完成 → 對齊紅線 10 ✅,但紅線 12 / 16 / 17 仲未做。
如果唔提議下個 sprint 行動,doc batch 只係「合規」,**唔係 ship-ready**。

---

## 🧪 Phase 2: Test Batch(補 unit + E2E + 發現 bug)

> Doc batch 之後,如果 `TEST-COVERAGE.md` 顯示 < 30% coverage,**唔好 ship**。
> 跟住做 **Test Batch**:補 unit test + 設 Playwright E2E + 守住 RBAC。

### Test Batch 6 步流程(2026-06-08 pm-system 親驗)

```
Doc Batch 完成
    ↓
Step 1: 確認 scope(同 doc batch 嘅 2-4 個 options 互動原則)
        A) RBAC middleware test only
        B) E2E framework + critical path
        C) RBAC + E2E 一次過(推薦 — sprint 1 拆得嚟會撞)
    ↓
Step 2: 寫 3 份 unit test(純 derive helper,唔 mock DB)
        - permission.test.ts(RBAC hasPermission / requirePermission)
        - worklogs.test.ts(分頁 + cutoff 邏輯 derive)
        - agents.test.ts(canClaimTask validation)
    ↓
Step 3: 設 Playwright E2E
        - package.json + playwright.config.ts
        - 真 docker compose 起 backend (frontend :8080, backend :4001)
        - critical-path.spec.ts(happy path + health + UI login)
        - rbac-negative.spec.ts(多角色 403 + 已知 bug 守住)
    ↓
Step 4: 跑 test verify + 修正 source code 嘅真實行為假設
        ⚠️ backend 將 auth-missing 視為 403 而非 401(source code 行為)
        ⚠️ Prisma Decimal 序列化成 string → E2E 要 Number() 比較
        ⚠️ login success redirect 去 /(唔係 /projects)
    ↓
Step 5: 過程發現嘅 bug → 即時 write TECH-DEBT entry (TD-XXX)
        例:TD-011 auth derive hook 撞不存在 UUID throw 500
    ↓
Step 6: 更新 TEST-COVERAGE / QA-TRACKER / TECH-DEBT / e2e/README + commit
```

### Phase 3: Fix Batch(2026-06-08 pm-system Sprint 1 第三輪親驗)

```
Test Batch 完成
    ↓
Step 1: 確認 scope(2-4 個 options)
        A) P0 fix(TD-011 = 1 個 security bug)
        B) P0 + P1 一次過
        C) 您揀邊個
    ↓
Step 2: 修 source code(derive hook + role 從 DB 攞)
    ↓
Step 3: docker compose up -d --build backend 真正 re-build container
        ⚠️ 唔係 docker compose restart(佢只 reload config,bake 嘅 image 唔變)
        ⚠️ 用 background=true + notify_on_complete=true(避免 Hermes 安全機制攔)
    ↓
Step 4: 改 E2E test expectation(pre-fix 500 → post-fix 403)
    ↓
Step 5: 跑全部 test 確認冇 regression
        - 13/13 E2E pass
        - 42/42 unit tests 仲綠
    ↓
Step 6: 寫 RG-XXX entry(完整 reproduce + fix + invariant)
        - 同步更新 TECH-DEBT entry 加「✅ Fix 完 + commit ref」
        - 同步更新 QA-TRACKER 嘅 progress row
    ↓
Step 7: source code 加 RG-XXX comment marker
    ↓
Step 8: 1 個 commit + commit message 引用 RG ID
```

**Fix Batch 嘅 5 個 pitfall**(2026-06-08 親驗):

| Pitfall | 症狀 | Fix |
|---------|------|-----|
| `docker compose restart backend` 唔 re-build | Source code 改咗但 backend 仲跑舊 version | 用 `docker compose up -d --build backend` |
| Hermes 安全機制攔 `docker compose up` | Terminal 報 "long-lived server" | 用 `background=true, notify_on_complete=true`,然後 `process(action='poll')` 追進度 |
| 2 round misdiagnosis | 我第一 round 誤判 derive hook 嘅 `prisma.findUnique` throw | **睇 source code 先**,唔好靠記憶 |
| Test 假設錯咗唔改 test | Backend 真係 403 而 test 預期 401 → fail | **Fail = 真實行為對齊**,改 test 而唔係 hardcode |
| 漏寫 cross-doc 同步 | Fix 完但 TD / QA-TRACKER / RG 唔更新 | TG-XXX entry + TD 「✅ Fix 完」 + QA progress row 同一 commit 齊 |

### Final emit pattern(Sprint ship-ready checklist)

每個 sprint 結束嘅 emit 必含嘅 4 個 section:

```markdown
## Sprint N Ship Report

### 📊 結果表
| 指標 | 一開始 | 完咗 | Δ |
|------|--------|------|---|
| Test files | 1 | N | +N |
| Test count | 2 | M | +M |
| P0 US 過 test | 0 | K | +K |
| Coverage | ~5% | ~X% | +X% |
| TD entries | 10 | 11 | +1 (TD-XXX ✅ DONE) |

### 📦 Commit 鏈(全部 YYYY-MM-DD)
```
<hash> <type>: <summary>
<hash> <type>: <summary>
...
```

### 🔍 過程發現 + quirks
- 🐛 發現 security bug TD-XXX(簡述)
- ⚠️ Backend 將 auth-missing 視為 403 而非 401
- ⚠️ Prisma Decimal 序列化成 string
- ⚠️ Login success redirect 去 `/`

### ⏭️ 下次 sprint 建議
🔴 P0 fix TD-XXX(0.1 日,quick win)
🟡 Frontend component test(1 日)
🟡 US-X.Y missing test
🟡 紅線 18 CVE scan
```

**Lesson**:**final emit 唔係「我做咗咩」,係「ship-readiness + 下面 3 條點行」**。David 用呢個 format 5 分鐘內做 next-step decision,唔再要問「咁而家點」。

完整 reproduce:`references/structural-doc-batch-pm-system-2026-06-08-walkthrough-test-batch.md` + `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md`(喺 `regression-guard` skill 入面)

### 3 份 Unit Test 嘅 derive pattern(重要!)

```typescript
// 例:worklogs.test.ts 守住 9adc1fa commit 嘅分頁邏輯
// 因為 worklogs.ts 將邏輯 inline,冇 extract helper,
// 我哋 derive 對應嘅 pure function,unit test 守住 invariant,
// 將來 refactor 抽 helper 時有 baseline

function computeWorkLogPagination(opts: { ... }) {
  // ... 從 source code 嘅 inline logic 100% 抄
  // 唔好 fabricate
}
```

> **關鍵**:derive = 抄 source code 嘅邏輯,**唔係憑記憶寫**。
> 否則 test 守住嘅 invariant 同 source 唔對齊 = false positive safety。

### E2E setup 嘅 5 個 Pitfall(2026-06-08 親驗)

| Pitfall | 症狀 | Fix |
|---------|------|-----|
| `docker compose up` 攔 long-lived | `terminal` 報 "long-lived server" 錯 | 用 `background=true, notify_on_complete=true`,然後 `process(action='poll')` 追進度 |
| Backend port 唔同 docker 內部 | Frontend 8080 proxy,Backend 4001 docker map | 兩個都 test:Frontend via nginx(:8080),Backend direct(:4001) |
| `/api/auth/login` 404 | Backend 有 `/api` group 但 `authRoutes` 喺 group 之外 | 真實 endpoint 係 `/auth/login`(無 `/api`) |
| `prisma findUnique` 撞不存在 UUID throw 500 | E2E 預期 403 但收 500 | 即時加 TECH-DEBT entry (TD-XXX),test 守住 500 行為等待 fix |
| Decimal / Json 序列化成 string | E2E 比較 `hours === 2.5` 失敗 | 用 `Number(workLog.hours)` 或 `JSON.parse()` 比較 |
| Login success redirect path | `waitForURL(/projects/)` timeout | 真實路徑係 `/`(dashboard),用 function 形式 wait |

### Critical Path 嘅 Happy Path 模板

```typescript
test('happy path: project → requirement → task → worklog', async ({ page, request }) => {
  // 1. API login(快,deterministic)— request.post(`${BACKEND}/auth/login`, ...)
  // 2. POST /api/projects + 攞 project.id
  // 3. POST /api/requirements(帶 projectId)
  // 4. POST /api/tasks(帶 projectId + requirementIds:[reqId])
  // 5. POST /api/worklogs(帶 taskId + hours + workDate)
  // 6. UI navigate 到 /worklogs 確認冇 crash
  // 7. finally cleanup(刪返建嘅 project)
})
```

### RBAC Negative 嘅 6 個 pattern

```typescript
test.describe('RBAC negative E2E', () => {
  // 1. Non-admin role POST admin-only endpoint → 403
  // 2. Non-admin role DELETE admin-only endpoint → 403
  // 3. 冇 token → 403(backend 將 auth-missing 視為 FORBIDDEN)
  // 4. Malformed token → 403
  // 5. Non-existent user token → 500(已知 bug,test 守住等 fix)
  // 6. Positive control:admin 同一 endpoint → 200(證明 403 唔係 false positive)
})
```

> **已知 quirk**:pm 有 `projects.create`(2026-06-08 verify)— 我以為冇,
> test 失敗先知,改用 DELETE /users 做 negative case。
> **Lesson**:test 假設 source code 行為,失敗即係**真實行為**唔同假設,
> 即時修正 test,記低係 known behavior 註入 doc。

---

## 🆚 同其他 skill 嘅關係(更新)

| Skill | 角色 | 互動 |
|-------|------|-----|
| `regression-guard` | Bug fix 流程 + RG-XXX entry | REGRESSION-GUARD.md 嘅 RG entry 跟呢個 skill 嘅 format |
| `tech-debt-register` | Tech debt 5-field format | TECH-DEBT.md 嘅 entry 跟呢個 skill 嘅 format |
| `feature-plan-alignment` | Plan 階段 alignment | Doc batch 嘅 Step 0(2-4 個 options)同呢個 skill 一致 |
| `context-summarizer` | 長 task context 壓縮 | Doc batch 通常 < 1 hour,唔需要壓 context |
| `dev-task-memory` | Long task state persistence | Doc batch < 50 tool calls,通常唔需要 |
| **`pagination-with-preserved-aggregates`** | Server-side 分頁 + 守住 stats | Worklog 分頁 test derive 自呢個 skill 嘅 pattern |
| **`client-api-wire-shape-verification`** | Frontend type ↔ backend source | E2E test derive 自真實 wire shape,唔靠 PRD 文字 |
| **`playwright-node-api-container`** | Playwright in container/VM | 我用 local docker,呢個 skill 偏 remote container |
| **🆕 Test Batch Phase 2** | 補 unit + E2E + 守 RBAC | Doc batch 完成後嘅下一個 sprint 行動,見新 skill `test-batch-supplement` |

---

## 🚨 紅線(對齊 SOUL.md)

- **紅線 10**:8 份 doc 必須存在並 commit 到 git。冇 doc 嘅 code 唔可以 merge。
- **紅線 11**:改 PRD 嘅同時必更新 `docs/QA-TRACKER.md`。冇更新 tracker = 任務冇做。
- **紅線 12**:P0 US 必須有對應 test task,Status = PARTIAL / PASS 算完成。
- **紅線 13**:任何 bug fix 必須有 `RG-XXX` entry 喺 `docs/REGRESSION-GUARD.md`。
- **紅線 14**:Bug fix 必須有 root cause + prevention 兩部分。
- **紅線 16**:P0 US 必須有 Unit + Integration + E2E 三層測試。
- **紅線 17**:每次 production deploy 必須跑 smoke test。
- **紅線 18**:任何 Critical/High CVE 必須 0 才可 merge。

---

## 📊 Doc Batch 健康指標

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| Doc batch 完成時間 | < 1 hour | 1-3 hours | > 3 hours(可能 scope 太大) |
| Doc 數量(8 份) | 100% 齊 | 4-7 份 | < 4 份(未對齊紅線 10) |
| Source-first derive 比例 | 100% | 50-99% | < 50%(可能 hallucinate) |
| Working tree untracked 處理 | 顯式列 commit msg | 隱藏 | 盲目 commit(資料損失風險) |
| Retro 寫咗未 | ✅ 寫 | — | ❌ 冇(下次冇 insight) |

---

## 🎬 實戰情境

### 情境:pm-system doc batch(2026-06-08 親驗)

David:「您可以幫分析一下pm-system項目,我補一下文檔?」

**正確流程**(用本 skill):
1. **Step 0**:3 個 scope option + D 開住
2. **Step 1**:Source inventory 發現 19 routes / 18 pages / 18 models / 0 E2E test
3. **Step 2**:9 份 doc batch 寫出
4. **Step 3**:`git status -s` 發現 `D SOW_PM_System_報價建議書.docx`(David 之前 manual rm)
5. **Step 4**:淨 stage 屬於 doc batch 嘅 11 個 file,唔 stage 個 delete
6. **Step 5**:一個 commit `277f337` + commit message 顯式標 ⚠️ docx delete
7. **Step 6**:Retro 寫入 `retros/2026-06-08-initial-doc-batch.md`
8. **Step 7**:提議下個 sprint 補 test 行動(US-7.3 RBAC + US-9.1/9.2 Agent + US-6.2 WorkLog 分頁)
9. **Final emit**:包含 4 個項目(新 doc 表 / 過程發現 / 下一步 / Q1 Q2 等待 David 確認)

**錯誤流程**(冇用本 skill):
- 盲目 `git add .` → 個 docx delete 一齊 commit → David 永久 lost 報價建議書
- LLM hallucinate PRD / TECH-DEBT 內容 → 同 source 對唔上
- 冇 retro → 下次新 project 唔知點 batch
- 冇提議補 test 行動 → doc batch 只係「合規」,**唔係 ship-ready**

---

## 📚 Related references

- `references/structural-doc-batch-source-derive-template.md` —
  8 份 doc 嘅 starter template(可 copy 後 modify),每份列 sections + example
- `references/structural-doc-batch-pm-system-2026-06-08-walkthrough.md` —
  完整 walkthrough 透過 pm-system 9-doc batch,step-by-step 對齊 source
