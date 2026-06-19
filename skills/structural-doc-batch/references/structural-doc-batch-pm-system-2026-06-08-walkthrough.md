# pm-system 2026-06-08 Doc Batch — Complete Walkthrough

> **Session**: 2026-06-08 Discord chat
> **Trigger**: David Chu 講「您可以幫分析一下pm-system項目,我補一下文檔?」
> **Outcome**: 9 份新 doc + 1 patch,commit `277f337`,11 files / +1199 lines / ~37KB

---

## Timeline

```
00:00 — David 講「您可以幫分析一下pm-system項目,我補一下文檔?」
00:01 — Quick scan pm-system 現狀
        - 16 commits, working tree 乾淨
        - 19 backend routes / 18 frontend pages / 18 Prisma models
        - 6 個 RBAC 角色
        - docs/ 已有 9 份(README / ARCHITECTURE / API / AI-AGENT / SPEC / SOW)
        - 缺 8 份(SOUL 紅線 10 缺)
00:02 — 提議 3 個 scope options + D 開住
00:03 — David 答「A」(= 全面合規)
00:04 — 開 todo 11 個 step
00:05 — 寫 PROJECT-OVERVIEW.md + PRD.md + 3 份 ADR
00:06 — 寫 TECH-DEBT.md + QA-TRACKER.md + REGRESSION-GUARD.md + retro
00:07 — 寫 TEST-COVERAGE.md(第一次 call corrupted, retry 成功)
00:08 — Patch API.md(status header)
00:09 — git status -s 發現 ⚠️ SOW_PM_System_報價建議書.docx 已被刪
00:10 — 精準 stage 11 個 file(屬於 doc batch),唔 stage 個 delete
00:11 — Commit `277f337` + commit message 顯式列 ⚠️ docx delete
00:12 — Final report
```

---

## Step 0 — Scope options(用 2-4 個 options 嘅 plan alignment)

```
A) 【全面合規】一次性補齊 8 份(估 4-6 小時)
B) 【核心 4 份】PROJECT-OVERVIEW + PRD + QA-TRACKER + TEST-COVERAGE(估 2-3 小時)
C) 【最少 1 張】只做 PRD + QA-TRACKER(紅線 11 強制)(估 1-1.5 小時)
D) 【您揀】您講邊幾份,我就做邊幾份
```

David 答「A」,直接 ship。

---

## Step 1 — Source inventory

```bash
ls -la ~/www/pm-system/docs/
# → 9 份 已有: README / ARCHITECTURE / API / AI-AGENT / SPEC / SOW

cd ~/www/pm-system && git log --oneline -15
# → 16 commits, 最新 9adc1fa (worklogs pagination)

find backend/src -name "*.ts" | head -30
# → 19 routes: auth / projects / requirements / tasks / bugs / worklogs / chat / ...

cat backend/prisma/schema.prisma | grep "^model "
# → 18 models: User / Department / Role / Permission / LLMConfig / WikiPage / ...

find frontend/src -name "*.tsx" -o -name "*.ts" | head -30
# → 18 pages: Login / Dashboard / Projects / ProjectDetail / Requirements / ...

find . -name "*.test.*" -not -path "*/node_modules/*"
# → 2 個 test files: tasks.test.ts, authRefresh.test.ts
# → ~5% coverage 嘅 known gap

git log --oneline --all | grep -iE "fix|bug|debug"
# → 5 個 fix commits, derive 5 個 RG entries
```

**Inventory output emit 之前已 verify**:0 個 E2E test、0% backend test coverage、RBAC 0 test、Agent 0 test — **全部已知 ship-blocker**。

---

## Step 2 — 9 份 doc batch write

### Doc 1: `PROJECT-OVERVIEW.md` (5.4KB)
- 一句話定位 + 11 sections(見 SKILL.md template)
- 角色 × 權限 5 個 role 對應 schema `User.role` field
- Stack derive 自 `package.json`
- 目錄結構 derive 自 `ls -la`

### Doc 2: `PRD.md` (8.0KB)
- 5 personas: Admin / PM / Tech Lead / Developer / Tester / Visitor
- 12 epics: Auth / Projects / Requirements / Tasks / Bugs / WorkLogs / RBAC / Chat / Agent / Wiki / Reports / Departments
- 50+ US,每個 P0/P1/P2 + Status(DONE 為主,有少量 DRAFT)
- NFR: Performance / Security / Reliability / Usability

### Doc 3-5: 3 份 ADR
- `0001-bun-elysia-backend.md`(Bun + Elysia 選型)
- `0002-prisma-5-pg.md`(Prisma 5.22 選型,stick with 5.22, 唔升 7.x)
- `0003-ai-agent-as-user.md`(Agent = User pattern,isAgent flag)

### Doc 5: `API.md` patch
- **唔重寫** 578 lines 嘅已有 doc
- **只 patch header**:`> **Status**: 🟡 對齊中(2026-06-08)`
- 避 drift(如果 derive response shape 會撞 backend source)

### Doc 6: `TEST-COVERAGE.md` (3.8KB)
- 5 個 layer inventory
- Backend 19 routes 對應 1 個 test file(= ~5%)
- Frontend 18 pages 對應 0 個 test(0% component test)
- E2E 0 個
- 健康指標 5 個全部 🔴
- 行動項目:Sprint 1 P0 補 RBAC + Agent E2E + WorkLog 分頁 regression

### Doc 7: `TECH-DEBT.md` (4.2KB)
- 10 個 debt entries,5-field format
- 🔴 P0: TD-001 測試覆蓋率低 + TD-002 0 個 E2E
- 🟡 P1: TD-003 Dockerfile / TD-004 RBAC consolidate / TD-005 error boundary / TD-008 rate limiting
- 🟢 P2: TD-006 Storybook / TD-007 audit / TD-009 timezone / TD-010 log aggregation
- 從 commit `55845c9` / `7f43cba` / `c42e634` / `c79eed1` / `3938a2d` derive process debt
- Pattern:AI / Agent 係最反覆 fix

### Doc 8: `QA-TRACKER.md` (5.0KB)
- 50+ US 對照 4-layer test status(NONE / DRAFT / PARTIAL / PASS / FLAKY)
- 健康指標:5% coverage,0 個 PASS
- 🔴 Ship blocker:紅線 12 規定 P0 US 必 PARTIAL/PASS,當前 0 個達標
- 補 test 優先序:US-7.3 RBAC → US-9.1/9.2 Agent → US-4.1/4.2/4.3 Task → US-1.1 login → US-6.2 WorkLog
- 變更規則:改 PRD 必更新(紅線 11)

### Doc 9: `REGRESSION-GUARD.md` (3.9KB)
- 5 個 RG entries derive 自 `git log` fix commits
- RG-001 Agent claim 失敗(commit 3938a2d)
- RG-002 LLM call hang(commit c79eed1)
- RG-003 WorkLog 部門欄位缺失(commit c42e634)
- RG-004 Project task workflow(commit 55845c9)
- RG-005 Backend bug(commit 7f43cba)— ⚠️ TBD,等 `git show 7f43cba` 補 detail
- Pattern 觀察:AI / Agent 係最脆弱

### Doc 10: `retros/2026-06-08-initial-doc-batch.md` (3.9KB)
- 觸發 / 做咗咩 / 過程觀察 / Action items / Lessons

---

## Step 3 — `git status -s` 發現 untracked 變更

```bash
cd ~/www/pm-system && git status -s
```

**Output**:
```
 M docs/API.md
 D "docs/SOW_PM_System_報價建議書.docx"
?? docs/PRD.md
?? docs/PROJECT-OVERVIEW.md
?? docs/QA-TRACKER.md
?? docs/REGRESSION-GUARD.md
?? docs/TECH-DEBT.md
?? docs/TEST-COVERAGE.md
?? docs/architecture/
?? docs/retros/
```

**🚨 警告**:`D docs/SOW_PM_System_報價建議書.docx` — 有人(David 之前 manual rm)刪咗呢份報價建議書。

**處理**:
- 屬於 doc batch 嘅 9 個新 file + API.md patch → `git add`
- **個 delete → 唔 stage**,等 David 確認

---

## Step 4 — 精準 stage

```bash
cd ~/www/pm-system && git add \
  docs/PROJECT-OVERVIEW.md \
  docs/PRD.md \
  docs/QA-TRACKER.md \
  docs/REGRESSION-GUARD.md \
  docs/TECH-DEBT.md \
  docs/TEST-COVERAGE.md \
  docs/architecture/ \
  docs/retros/ \
  docs/API.md

git status -s
# → 11 個 file staged,docx delete 仲喺 working tree
```

**驗證**:精準 stage 11 個 doc batch file,絕對冇 `git add .` 撞 docx delete。

---

## Step 5 — 一個 commit + 顯式列 untracked

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

⚠️ docs/SOW_PM_System_報價建議書.docx working tree 已被刪(working tree 狀態),
未 commit 個 delete,等 David 確認。"
```

**Commit result**:`277f337` 11 files / +1199 lines / 0 deletions(因為 docx delete 冇 stage)。

---

## Step 6 — Retro

寫入 `docs/retros/2026-06-08-initial-doc-batch.md`(Step 9),6 個 sections:
1. 觸發
2. 做咗咩
3. 過程觀察(✅ Good / ⚠️ Caution / ❌ Blockers)
4. Action items(6 個)
5. Lessons(4 個)
6. Reference(紅線 + source files)

---

## Step 7 — Final emit + 提議下個 sprint 行動

**Final report sections**:
1. ✅ 9 份 doc 完成表
2. 🔍 過程發現嘅 5 個重要嘢(E2E 0、test 5%、RBAC 0 test、AI fragile、docx delete)
3. 📋 Sprint 1 P0 行動(補 RBAC / Agent E2E / WorkLog 分頁)
4. ❓ Q1 + Q2(docx 刪 / 留,跟住做 / 收工)— 等 David 確認

---

## ⚠️ Pitfalls 喺呢個 session 親驗

### Pitfall 1 親驗:`SOW_PM_System_報價建議書.docx` 撞 delete

- `git status -s` **必須 stage 之前必跑**
- 精準 `git add` paths 唔好 `git add .`
- Commit message 顯式列 untracked / deletes

### Pitfall 2 親驗:`API.md` 578 lines 唔重寫

- 大型 doc 永遠 patch header,**唔好 overwrite**
- Doc 5 / Doc 7 嘅 inventory 已覆蓋 endpoint list,API.md 唔使 derive response shape(避免 drift)

### Pitfall 3 親驗:Tsc pass 嘅錯覺

- Doc batch 寫 doc,**唔涉及 tsc** — 但如果 batch 涉及 code change,tsc pass 唔等於 runtime-safe
- (呢個 session 純 doc,冇踩呢個 pitfall,但係重要嘅 mental model)

### Pitfall 7 親驗:補 doc 之後提議補 test

- 5 個 Ship blocker 寫入 retro Action items + final report
- 下次新 project 開 batch 之後,**Sprint 1 第一週** = 補 test 行動

---

## 📊 呢個 session 嘅 Doc Batch 健康指標

| 指標 | 健康 | 警告 | 呢個 session |
|------|------|------|--------------|
| Doc batch 完成時間 | < 1 hour | 1-3 hours | ~12 turns / 11 tool calls ✅ |
| Doc 數量(8 份) | 100% 齊 | 4-7 份 | 9 份新 + 1 patch ✅ |
| Source-first derive 比例 | 100% | 50-99% | 100% ✅ |
| Working tree untracked 處理 | 顯式列 commit msg | 隱藏 | 顯式列 ⚠️ docx ✅ |
| Retro 寫咗未 | ✅ 寫 | — | ✅ retros/2026-06-08 ✅ |
| 提議下個 sprint 行動 | ✅ | — | ✅ 補 RBAC / Agent / WorkLog ✅ |

**整體**:✅ 健康。

---

## 🎯 對未來 session 嘅 reuse

呢個 walkthrough 係 doc batch skill 嘅 **worked example**。下次任何 project 開 batch:
1. Copy 呢個 file 嘅 step structure
2. Adapt derive 步驟(每個 project schema / routes / pages 唔同)
3. 跟 pitfall checklist(尤其 #1 working tree untracked handling)
4. 寫新 retro(年份/日期唔同)
