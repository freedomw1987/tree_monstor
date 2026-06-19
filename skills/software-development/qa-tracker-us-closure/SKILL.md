---
name: qa-tracker-us-closure
description: Per-US test closure cadence for closing out NONE/PARTIAL P0 user stories in a project's QA-TRACKER.md. Class-level, applies to any project that uses the US ↔ Test 對照 tracker pattern (PM-System, crm-system, llm-acp, future projects). Trigger when a project's QA tracker shows rows with NONE / PARTIAL / DRAFT for P0 user stories, or when the user says "close out P0 US test gap", "Sprint N P0 test push", "做嗰啲 NONE 嘅 US", "ship 嗰啲 P0 test by test", or "audit NONE US". Per-US rhythm is audit source, write derive-or-source test, run + fix, commit + tracker sync + push. Distinct from a multi-axis code review (see `code-review-pipeline`) and from full Sprint retrospective writing.
---

# QA Tracker — Per-US Test Closure Cadence

Close out the P0 user stories that show as NONE / PARTIAL in `docs/QA-TRACKER.md`, one commit at a time, with a per-US test file and a tracker sync.

## Why this skill exists

`docs/QA-TRACKER.md` (see `docs/qa-tracker.md` for the format) is the source of truth for which US has which test. When rows show `NONE` for P0 US, the project can't ship those features with full coverage. Closing them one by one is a discrete, repeatable workflow, NOT a single big bang (which 紅線 12 + 16 forbid for P0 because the per-US test attribution gets lost).

## When to use vs. not

| Situation | Use this skill? | Why |
|-----------|----------------|-----|
| Tracker has 5+ P0 US with NONE | ✅ Yes | Per-US closure is exactly the pattern |
| User says "ship all remaining P0 test" | ✅ Yes | Split into per-US commits, audit each |
| One P0 US needs a feature + test together | ✅ Yes | Same per-US rhythm applies |
| User asks "review the codebase" | ❌ No | That's `code-review-pipeline` (multi-axis) |
| User asks "write retro for Sprint N" | ❌ No | That's the existing retro workflow |
| P1/P2 US gap closure | ⚠️ Yes but lower priority — confirm with user first |
| **User says "補: [ ] ..." 格式 = retro follow-up 段 list 出嚟** | ✅ **Yes (docs-only path)** | See **§Sprint follow-up registration** below — pure docs patch, no code/test, register retro "What's NOT done" 段入 tracker |

## The 6-step per-US rhythm

For each P0 US, do these in order. **Hard rule: one US = one commit + one tracker sync + one push + one revert-detection check.** Do NOT bundle multiple US into one commit — David needs the per-US commit attribution for ship-gate audit and the per-US RG entries.

### 1. Audit the US scope (1-2 tool calls)

Before writing a single test, **read the actual source code** for that US's route + helpers. Check:

- **Endpoint** (route file + method), e.g. `backend/src/routes/worklogs.ts:24-62` for US-6.4
- **Helper exports** — is the logic in an exported helper (`export function ...`) or inline in the route?
  - **Exported helper** → import directly in test (more stable, less duplication)
  - **Inline logic** → derive a pure function in the test file that mirrors the source
- **Existing tests** — read `*.test.ts` next to the route file, some US invariants are already partially covered
- **Frontend code**, e.g. `RichTextEditor.tsx` for US-3.5 had a `<p></p>` → `''` invariant worth testing

Audit output goes into the commit message body, NOT a separate file.

### 2. Decide: derive or source-import

| Helper situation | Use |
|------------------|-----|
| `export function` already exists in route | `import { ... } from './routeFile'` |
| Helper is `const` inside route file (not exported) | Derive a mirror function in the test file, link to source line in comment |
| Logic spread across route + multiple `if` branches | Derive a single function that takes the relevant query/user args |

PM-System examples:

- `tasks.ts` exports `buildTaskListWhere` + `resolveTaskProjectId` → **source-import** (commit 3b93dba)
- `worklogs.ts` has all logic inline → **derive** `buildWorkLogFilterWhere` (commit df8c4dd)
- `requirements.ts` accepts `description: string` from frontend RichTextEditor → **derive** `normalizeRichTextDescription` based on the frontend's `<p></p>` → `''` invariant (commit e45626b)

### 3. Write the tests (target 5-10 cases per US)

Test cases must cover the actual invariant, NOT trivial smoke. Good categories:

| Category | What to test |
|----------|--------------|
| **RBAC gate** | "non-admin tries to set userId filter" → ignored. "admin sets departmentId" → applied. |
| **Null safety** | undefined / null / empty-string input → graceful return, no throw |
| **Round-trip fidelity** | US-3.5: any HTML in → same HTML out (Tiptap `<p></p>` → `''` is the only exception) |
| **Cross-entity guards** | US-4.4: multiple linked requirements across different projects → error |
| **Composition** | "filter A + filter B can both be applied" |
| **Edge cases** | boundary values (date 5th vs 4th), empty input, single-element array |

Aim for 5-10 cases per US. Fewer = undertested, more = redundant.

### 4. Run + fix (always run the full backend suite, not just the new file)

`bun test` runs the whole backend suite in ~3s. ALWAYS run it after writing tests — even if your new test file passes, the suite-wide run catches unintended regressions in shared helpers (`computePagination`, `serializeWorkLog`, etc.).

```bash
cd backend && bun test 2>&1 | tail -5
# Expect: "NNN pass 0 fail NN expect() calls"
```

If 0 fail + N increased by your test count, proceed to commit. If fail, fix before committing.

### 5. Commit + tracker sync (5 spots in QA-TRACKER.md, all required)

Commit message format:

```text
test(<area>): US-X.Y <short description> (Sprint N)

N 個新 [derive|source] test 守住 [US-X.Y] 嘅 [<invariant categories>]:
- <bullet 1: invariant + behavior>
- <bullet 2: invariant + behavior>
- ...

US-X.Y 由 NONE → PASS-UNIT[+E2E] (Sprint N: 計數 +N)。
[Optional: full-suite regression result]

QA-TRACKER.md 同步更新 <5 個 spot 嘅具體改動>。
```

QA-TRACKER.md has 5 spots that must sync per US (紅線 11). Easy to miss one:

1. **The US row itself** — change `NONE` → `**PASS-UNIT** 🟢 (Sprint N: <N> tests — <summary>)` in the comparison table
2. **Metrics row "P0 US PASS-UNIT only"** — increment count
3. **Metrics row "Unit tests 總數"** — update count + add `+N` delta
4. **Sprint history entry** (bottom of file) — add a row in the date-sorted table summarizing the US push
5. **Status header `> **Status**:` AND `> **Update**:` lines** — append to the Update line on EVERY commit, not just the first of the sprint. The Update line is cumulative — by sprint end, it tells the full story in one read.

Example Update-line progression (累積 pattern, NOT rewrite):

```text
# After commit 1 (US-6.4)
> **Status**: 🟢 2026-06-10 — Sprint 10 進行中,P0 remaining US test push(US-6.4 已 PASS-UNIT)
> **Update**: 2026-06-10 Sprint 10 — US-6.4 worklogs filter RBAC 由 NONE → PASS-UNIT(9 個 test,non-admin 強制 userId + admin departmentId gate),Unit 549→558(+9)

# After commit 2 (US-3.5)
> **Update**: 2026-06-10 Sprint 10 — US-6.4 ...;US-3.5(requirement rich-text)由 NONE → PASS-UNIT(11 個 test,...);Unit 558→569(+11)
```

Each commit appends its US closure to the existing Update string (use `;US-X.Y(...)` separator). The Status line only changes wording on the first commit of a sprint (e.g. add "Sprint N 進行中") and on sprint closure (change to "Sprint N 收工").

### 6. Push + revert-detection

After commit:

```bash
git push origin master
git log --oneline origin/master..HEAD    # MUST be empty
git log --oneline -3 origin/master        # HEAD MUST be top
```

Per memory entry "Revert detection 鐵律": David has done `git revert` mid-session in past projects and the assistant never noticed. Always do the 3-second revert check before claiming a US is done.

## Sprint follow-up registration (docs-only, no-code) — TRIGGER: "補: [ ] ..." 格式

**Trigger signal**: User message 開頭係 `補:`(或 `+` / `add:` / 英文 `add:`)後面 list 住啲 task,通常係 retro doc "What's NOT done" 段嘅 copy-paste(eg PM-System retro `2026-06-09-sprint-11-...md` line 75-79)。**冇 coding request**,只係要將 follow-up **register** 入 tracker 等下個 sprint 開工嗰陣 agent 開 file 就見到。

呢個係 **pure docs-only update**,**唔入 6-step per-US rhythm** — 唔寫 test, 唔 commit code,只 patch `docs/QA-TRACKER.md`。**0 個 code commit,1 個 docs commit**。

### The 4-step docs-only rhythm

#### 1. 讀 retro doc 嘅 "What's NOT done" 段(0-1 tool call)

如果 user message 入面有 retro 嘅 reference(file path 或 file 內文),讀 `docs/retros/<date>-sprint-N-...md` 嘅 bottom section(通常叫 "What's NOT done" / "Out of scope" / "Follow-up")。

#### 2. 將每條 follow-up 歸類入 3 個 bucket(0 tool calls,純分類)

| Bucket | 信號 | Tracker 處理 |
|--------|------|--------------|
| **A: New test follow-up** | 「E2E test 喺 X」「補 test」「X spec」 | 對應 US row 嘅 E2E cell 改 `❌(DRAFT Txx, Sprint N planned — <一句解釋>)`,+ Status 保持 `PARTIAL` 或 `NONE` |
| **B: New US-level follow-up** | 「US-X.Y full-text」「[新 area] search」 | 對應 US row Status 改 `NONE-HOLD` 🟠(加 hold 嘅理由 + 點解紅線 12 唔適用:P1/P2) |
| **C: Refactor / infra follow-up** | 「抽 component」「對齊 pattern」 | 唔入 US row, 加去新 section「🟠 Open follow-ups」最後一張 table |

#### 3. Txx 命名(sequence 跟上一個 sprint, 唔跳號)

| Sprint 最後一個 T-ID | 下次 first T-ID | Example |
|----------------------|----------------|---------|
| T14h (Sprint 9) | **T15a** | PM-System Sprint 11 follow-up (2026-06-09) |
| T15x (Sprint 11) | T16a | next sprint |

**Rule**: 一個 US 嘅多條 follow-up → **T15a + T15b + T15c**(sub-letter), 唔開 T16 唔同 US,即使係隔離。**Sub-task 一定 share 同一個 US row**。Example:
- T15a: E2E `ProjectDetailPage` bug tab create + rich text + image paste (US-5.6 sub-task 1)
- T15b: E2E `ProjectDetailPage` bug tab search filter (US-5.6 sub-task 2)

兩個都入 US-5.6 row 嘅 E2E cell:**`❌(DRAFT T15a + T15b, Sprint 11 planned — ...)`** — 唔開 row。

#### 4. Patch 落 tracker(3 spots,5-15 lines 改動)

| Spot | 點改 |
|------|------|
| 1. **US row** (Bucket A/B) | E2E cell 加 `(DRAFT T15a + T15b, Sprint 11 planned — ...)` 或 Status cell 加 `NONE-HOLD` 🟠 |
| 2. **新增 section「🟠 Open follow-ups」** | 喺 health metrics table 下面加一張 table(ID / US / Owner / Status),list 晒全部 Bucket A + B + C 嘅 follow-up, 等下次開 Sprint 12 個 worker 一打開 tracker 就見到 |
| 3. **Status banner** | 加一行 `> **Update**: <date> <sprint> 收工 — Retro Sprint <N+1> follow-up registration: <一句 summary>` |

**5個 spot 嘅 full US closure rhythm 唔適用** — 因為冇 code, 冇 test count, 冇 metrics increment。**只改呢 3 個 spot**。

### Example commit message (docs-only, no code)

```text
docs(qa-tracker): register Sprint 11 follow-ups (T15a/T15b/US-10.3 hold)

Retro 2026-06-09 sprint 11 收工 "What's NOT done" 段 3 條 follow-up 全部
register 入 tracker, 等下個 sprint 開工對住做:

- T15a (DRAFT): E2E `ProjectDetailPage` bug tab create + rich text +
  image paste — US-5.6 PARTIAL, 覆 ProjectDetailPage 入口(舊
  CreateBugModal 5 tests 2026-06-09 skip, 唔可以重新 deprecate)
- T15b (DRAFT): E2E `ProjectDetailPage` bug tab search filter —
  US-5.6 PARTIAL sub-task 2
- US-10.3 NONE-HOLD 🟠: Wiki full-text search hold, scope 較大
  需要 Postgres tsvector 或 MeiliSearch, 留俾下個 epic 決定
  (Sprint 11 client-side title search 已 done in WikiTab,
  P1 非關鍵 紅線 12 唔適用)

Patch:
- 1 file / +13 / -2
- 0 code, 0 test
- 1 docs commit
```

### Common pitfalls (docs-only)

- **唔好 default 開 US-5.6 row 2 條** — 用同一 row 嘅 E2E cell 寫 `(DRAFT T15a + T15b)` 即夠。**Multi-row 表 = 噪音**, David 一打開 tracker 見到 2 row US-5.6 會以為係唔同 US。
- **NONE-HOLD 唔等於 DEPRECATED** — DEPRECATED ⚫ = 拎走,紅線都放棄;NONE-HOLD 🟠 = 留低,只係 explicit 「呢個暫時唔做,等將來決定」,status 仍然 active, David 寫新 epic 嗰陣可以 query 「咩 US 係 HOLD 嘅」做 input。
- **Status banner 嘅 Update line 用 `;US-X.Y()` separator 唔 work 喺 docs-only** — 因為冇 US closure event, 改用一句 narrative `Retro Sprint N follow-up registration: <summary>`。**6-step rhythm 嘅累積 pattern 唔適用**, docs-only commit 開新 Update line。
- **冇 commit 都係 0 個 fix / 0 個 feature** — David 嘅「睇唔到 = 冇做」鐵律伸延到「冇 git diff = 冇做」,**docs-only commit 仍然要 push + git log 確認 HEAD 喺度**。
- **唔好加多過 1 個 "Open follow-ups" section** — 整個 tracker 應該得 1 個(喺 health metrics 下面)。如果再 patch 發現 row 重複, grep `Open follow-ups` 確認。

## Common pitfalls

- **Bundling multiple US in one commit** — David loses the per-US attribution for ship-gate audit. Default: one US = one commit. **Exception**: 2 US sharing the SAME route file + SAME derive pattern (e.g. US-2.4 + US-2.3 both in `projects.ts` and both derive project helpers) can ship as one commit — the shared `describe` blocks preserve per-US attribution in the test file even when the commit message groups them. PM-System Sprint 10 commit `bfb8618` did exactly this. If unsure, ask the user before bundling.
- **Deriving logic when source is exported** — wastes effort, drifts over time. Always check `export` first.
- **Testing trivial invariants** — `expect(add(1, 2)).toBe(3)` is a smoke test, not a coverage test. The point of these tests is to lock in **invariants** (RBAC gates, round-trip fidelity, cross-entity guards) so future refactors don't silently break them.
- **Forgetting one of the 5 tracker spots** — the sprint history row at the bottom is the one most often missed. The Update-line append is the second most often missed.
- **Not running the full suite** — `bun test <file>` is faster but misses regressions in shared helpers. **Run rhythm per commit**:
  1. `bun test <new_file>` — confirm new test file passes (fast feedback)
  2. `bun test` — full backend suite, must end with `N pass 0 fail` before commit
  3. (E2E US only) `cd e2e && ../frontend/node_modules/.bin/tsc --noEmit --target es2020 --module commonjs --moduleResolution bundler --esModuleInterop --skipLibCheck --strict tests/<new>.spec.ts` — TypeScript pre-flight because e2e/ has no own `tsc` install and `npx tsc` collides with the wrong wrapper (see SOUL.md npm pitfall).
- **Re-running `git pull` mid-sprint** — fine, but if it brings new changes that touch a route you just audited, re-audit before next US.
- **Derive function null-safety vs source's "caller guards"** — when source uses `user?.role !== 'admin'` and a null user is theoretically reachable, your derive function will still output `{members: {some: {userId: undefined}}}` for null users (because `user?.role` is `undefined`, which `!== 'admin'` is true). **Do NOT** write a test that expects "null user → no OR scope" — that's a different function. Two options:
  1. Mirror source's output (accept the `userId: undefined` row) and document "caller must guard null user" in the test comment. The route handler does this upstream (e.g. `projects.ts:29` `if (!user) return { projects: [] }`).
  2. Add an explicit null guard at the top of the derive function (`if (!user) return {}`) and document "derive adds a defensive guard the route already had" — only do this if you're also patching the source.

  PM-System Sprint 10 commit `bfb8618` US-2.4 hit this — the test had to be rewritten after a 1-fail run, expecting `{members: {some: {userId: undefined}}}` and noting "caller 必須 guard 返". This is correct behavior, not a bug.
- **E2E spec for frontend-heavy US without dev stack** — some US have no cheap unit boundary (drag-drop Kanban, multi-modal editor flows). The user may opt to ship a `.spec.ts` file with `TypeScript clean` + 5/6 tests that run on real stack + 1 placeholder (`test.skip`) for the drag-drop interaction that needs keyboard-accessible rewrite. This is a valid PASS-E2E status — the spec exists, the file compiles, and the API invariant is locked down. The drag-drop rewrite is a follow-up sprint task. PM-System Sprint 10 commit `eaae48a` US-4.5 used this pattern; the file is `e2e/tests/project-kanban.spec.ts` (6 tests, 5 functional, 1 drag-drop skip).

## Multiple US in one commit (rare but legitimate)

When **2 US share the same source file + same derive pattern** and the user's preferred commit cadence allows it, bundle them. PM-System Sprint 10 commit `bfb8618` did this for US-2.4 + US-2.3, both in `projects.ts` — the derive pattern is identical, the test categories are distinct, and shipping them together saved 1 round of full-suite + revert check. Always tell the user this is a bundled commit in the commit message body.

## Session start checklist (when triggered)

1. `cd <project>; git pull`
2. `grep -E '^\|.*NONE' docs/QA-TRACKER.md | head -20` — list of US to close
3. Ask user: "逐個 / 一次過開 5-6 個 sprint? (default: 1 sprint, 5-7 US, P0 first)"
4. For each US: audit → test → commit → tracker sync → push → revert check
5. Sprint closure: update Sprint history entry, mark Sprint N as "Sprint N closure", next sprint in "in progress"

## Reference

- `references/pm-system-sprint-10-example.md` — worked example of 3 US closures from PM-System Sprint 10 (2026-06-10), with audit decisions, test categories, tracker sync spots, and pattern observations
- `references/pm-system-sprint-10-commits-4-5.md` — Sprint 10 commits #4 + #5 (US-2.4+US-2.3 bundled, US-4.5 E2E spec draft). Covers derive null-safety pitfall, multiple-US-per-commit rare exception, E2E spec draft pattern, TypeScript pre-flight for e2e/ specs.
- `references/sprint-followup-registration-example.md` — Sprint 11 (2026-06-09) docs-only follow-up registration: 3 條 retro "What's NOT done" 段 → tracker 嘅 2 row patch + 1 new section + T15a/T15b sub-letter naming + NONE-HOLD 🟠 marker。**When to use: 用戶 message 開頭係 `補:` / `+:` 格式 list 住嘅 task,純 docs-only,冇 coding intent**。

## Related skills

- `code-review-pipeline` — for multi-axis review before ship (different cadence)
- `regression-guard` — for any bug fix that ships (per-US test push rarely hits this; only if a test reveals a real bug)
- `tech-debt-register` — if the audit reveals debt that doesn't fit a US closure (e.g. missing migration)
- `context-summarizer` — Sprint 10+ long sessions, decisions get auto-summarized; per-US commit messages are the durable record
- `interruption-recovery` — pair with the docs-only rhythm if David 收工前要中途停(register 咗 1-2 條 Txx 然後 /new,下個 session 用 load_state 恢復)
