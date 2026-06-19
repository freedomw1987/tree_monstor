# Sprint 11 (2026-06-09) — Sprint Follow-up Registration (docs-only, no-code)

## TL;DR

PM-System retro `docs/retros/2026-06-09-sprint-11-wiki-attachments-search-deprecate-bugs-page.md` 收工後,David 開新 message 寫「補: [ ] E2E test 喺 ProjectDetailPage 嘅 bug tab... [ ] E2E test 喺 ... search filter [ ] Wiki full-text search (需要 Postgres tsvector 或 MeiliSearch) — scope 較大,hold 住」。

呢個 message **唔係** retro follow-up 寫入新 sprint 嘅 user-facing request — 佢只係叫 agent 將 retro doc 嘅 "What's NOT done" 段 (line 75-79) **register 入 tracker**,等下個 sprint 開工對住做。**0 coding intent**,只係 docs patch。

## What changed (1 file, +13 / −2)

| File | Change |
|------|--------|
| `docs/QA-TRACKER.md` | (1) Status banner 加新 `> **Update**:` line — `Retro Sprint 11 follow-up registration: T15a + T15b DRAFT, US-10.3 NONE-HOLD`; (2) US-5.6 row 嘅 E2E cell 由 `❌(DEPRECATED... 等下次 sprint 補 E2E)` 改 `❌(DRAFT T15a + T15b, Sprint 11 planned — ProjectDetailPage bug tab create + rich text + image paste + search filter 全部要補 E2E;舊 CreateBugModal 5 tests 2026-06-09 skip)`; (3) US-10.3 row 嘅 Status 由 `NONE` 改 `NONE-HOLD 🟠` 加 hold 理由; (4) 新增 `### 🟠 Open follow-ups (Sprint 11 / 12 planned, non-P0)` section 喺 health metrics 下面, 列 T15a / T15b / US-10.3 full-text / 2 個 DEFERRED refactor 5 條 |

**冇 code commit, 冇 test commit, 冇 metric increment**。Diff 純 docs。

## Key decisions (with WHY)

### 1. **T15a + T15b 命名, 唔開 T16 + T17 唔同 US**

- **Why sub-letter**: T14 系列已經用咗喺 Sprint 9 嘅 pagination (T14a-h 10 個 test)。Sprint 11 first T-ID = T15a。US-5.6 嘅 2 條 sub-task 全部歸 T15 series (T15a + T15b), 唔係 T15a + T16a, 因為 sub-task 必須 share 同一個 US row 嘅 E2E cell
- **Why 唔開 2 row US-5.6**: 開 2 row 即係 table 噪音 — David 一打開 tracker 見到 2 row US-5.6 會以為係唔同 US,搞到 US-ID collision

### 2. **NONE-HOLD 唔等於 DEPRECATED**

| Marker | 意思 | 紅線 12 點睇 |
|--------|------|--------------|
| `DEPRECATED ⚫` | 拎走,功能 cancel,US cancel | 唔適用(US 經已 cancel) |
| `NONE-HOLD 🟠` | 留低,scope 太大 hold 住,將來可能 reopen | **唔適用**(P1/P2 非 P0,紅線 12 對 P0 強制) |
| `PARTIAL 🟡` | 部分做咗,部分未做,跟住會補 | 適用(US 仲 active) |

US-10.3 hold 嘅理由要寫入 Status cell 嘅 parenthetical,等 David 一打開 row 就知點解 hold、將來點 reopen:**「client-side title search done in `WikiTab`;**full-text search hold** — 需要 Postgres `tsvector` GIN index 或 MeiliSearch sidecar,scope 較大,留俾下個 epic 決定 — 紅線 12 唔適用,P1 非關鍵」**。最後一句 `紅線 12 唔適用,P1 非關鍵` 係 critical — 寫低紅線豁免,將來 audit 唔會撞。

### 3. **Status banner 嘅 Update line 開新一條, 唔累積**

Sprint 10 個 6-step rhythm 規定 `> **Update**:` 用 `;US-X.Y()` separator 累積,因為每個 US closure 係 tracked event。docs-only commit **唔係** US closure event — 冇 test count increment, 冇 metric change。改用 narrative 格式:

```text
> **Update**: 2026-06-09 收工 — Retro Sprint 11 follow-up registration: US-5.6 E2E DRAFT T15a + T15b Sprint 11 planned; US-10.3 NONE-HOLD — client-side title search done, full-text search hold 等下個 epic 決定 (tsvector / MeiliSearch)
```

### 4. **新增 "🟠 Open follow-ups" section 而唔入 P0 health metrics**

Open follow-ups 全部係 non-P0 (US-5.6 P1, US-10.3 P1, refactor P2)。入 P0 metrics table 會破壞「**100% P0 US** 🟢」嘅 invariant(雖然 count 唔變, 但 visual noise)。**獨立 section** 喺 health metrics 下面 — David 一打開 tracker 由上至下讀:

1. Status banner (Sprint N 進行中)
2. 對照表 (US ↔ Test)
3. Health metrics (P0 100%)
4. **🟠 Open follow-ups (non-P0, Sprint 11/12 planned)** ← 新 section
5. Sprint history (Sprint 6-10 收工摘要)

跟住佢打開 `Sprint 12` worker 開工嗰陣,**直接 read 個 section 就知 follow-up 喺邊度**,唔使 grep retro doc。

### 5. **DEFERRED refactor 都入 Open follow-ups table**

雖然 refactor 唔係 US-level, 但佢哋 100% 會喺將來 sprint 影響 implementation, 入 table 保留 discoverability。Entry 用 `refactor` 開頭代替 US-ID, 等 visual 上分得開 US-level 同 refactor-level follow-up:

```markdown
| **refactor** | 抽共享 `<EntitySubListSection>` (ProjectDetailPage + RequirementDetailPage ~95% 一樣 sub-list code) | TBD | DEFERRED, 1-2 日 refactor |
| **refactor** | `CreateBugModal.tsx` 對齊新 `<AddBugModal>` pattern — 三個 divergent bug-creation surface | TBD | DEFERRED |
```

## Bucket classification(本 session 用到)

| David 嘅 message 條目 | Bucket | 處理 |
|----------------------|--------|------|
| 「E2E test 喺 ProjectDetailPage 嘅 bug tab (US-5.6 嘅 create + rich text + image paste)」 | **A: New test follow-up** | US-5.6 row E2E cell 改 `DRAFT T15a + T15b` |
| 「E2E test 喺 ProjectDetailPage 嘅 bug tab search filter」 | **A: New test follow-up** (sub-task 2 of US-5.6) | 同上 — share T15 series |
| 「Wiki full-text search — scope 較大, hold 住」 | **B: New US-level follow-up** (hold 性質) | US-10.3 Status 改 `NONE-HOLD 🟠` |

3 條全部覆蓋, 0 條漏。

## Verification (一個 docs commit 嘅 ship gate)

```bash
cd ~/www/pm-system
git diff --stat docs/QA-TRACKER.md
# Expect: 1 file changed, 13 insertions(+), 2 deletions(-)
git status
# Expect: 1 modified file, 0 untracked, 0 staged-not-yet-committed
```

**冇跑 `bun test` / `npx playwright`** — 因為 pure docs, 冇 code/test 改動。**`tsc --noEmit` 都唔跑** — `docs/*.md` 唔過 tsc。

## Common pitfalls (本 session 撞過 / 避咗)

### Pitfall 1: 開 2 row US-5.6 (避咗)

`ProjectDetailPage` bug tab create + search filter 2 條 follow-up 都關 US-5.6,如果 default 開 2 row 即係噪音。**用 E2E cell 寫 `(DRAFT T15a + T15b)`** 一個 row 就夠。

### Pitfall 2: NONE-HOLD 寫成 DEPRECATED (避咗)

US-10.3 嘅 full-text search 唔係 cancel,只係 hold 住等將來 epic 決定。寫 DEPRECATED ⚫ 會誤導 David 以為功能 cancel,將來 reopen 唔到。**NONE-HOLD 🟠 + parenthetical 解釋點解 hold + 點解紅線 12 唔適用**。

### Pitfall 3: 漏「Open follow-ups」section (避咗)

如果只改 US row, David 下次開 Sprint 12 worker 開工, 要 grep `DRAFT` 搵 T15x 入邊度。**新增 section 集中 list 晒**, 等 1 個 read 就有齊 context。

### Pitfall 4: 用 `;US-X.Y()` separator 喺 Update line (避咗)

docs-only commit 唔係 US closure event。**新開 Update line 用 narrative 格式**, 唔 join 入舊 Sprint 10 累積 string。

## Lessons

1. **`補:` 格式 = docs-only registration, 唔等於 new coding request**。User 嘅 message 開頭 `補:` 已經係 strong signal「呢個係 retro follow-up 段嘅 copy-paste, 純 register, 唔入 6-step rhythm」。Agent 唔好 default 開嗰 US 嘅 6-step, 跳 step 5 嘅 3-spot docs-only path。
2. **T15a + T15b 命名 sub-task 一定要 share US row**。Multi-row 會 trigger US-ID collision worry, David 會以為係 typo。
3. **NONE-HOLD 係 explicit hold 唔係 cancel**。Status cell 嘅 parenthetical 一定要寫「點解 hold + 將來點 reopen + 紅線豁免」3 樣, 唔係淨寫 `NONE-HOLD`。
4. **Open follow-ups section 集中 list**, David 下個 sprint 開工免 grep。
5. **`docs/QA-TRACKER.md` 改完一定要 commit + push**, David 嘅「睇唔到 = 冇做」鐵律伸延到「冇 git diff = 冇做」(per memory entry), docs-only commit 都要走 git log revert check。

## What's NOT done (本 session 嘅 follow-up 已經 register 喺 tracker)

- T15a: E2E `ProjectDetailPage` bug tab create + rich text + image paste (DRAFT, Sprint 11 planned)
- T15b: E2E `ProjectDetailPage` bug tab search filter (DRAFT, Sprint 11 planned)
- US-10.3 full-text search (HOLD, 等下個 epic 決定)

下次 Sprint 12 worker 開工,**直接讀 `docs/QA-TRACKER.md` 嘅 Open follow-ups section**, 唔使讀 retro doc。
