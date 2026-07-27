---
name: feature-plan-alignment
description: Plan-stage alignment workflow for non-trivial feature work where David wants to review direction BEFORE code is written. Produces a structured plan doc (MD + boss JSON) with resolved decisions (each marked `chosen_by`), a step-by-step implementation breakdown, risk surface, and ship-gate impact — then notifies David on Discord for go/no-go. Trigger when David says 「B吧」「慢慢」「plan 先」「畀我睇下 plan」「可以 plan 嗎」 OR when a feature is non-trivial (>5 files, 4+ commits, or has a real design choice between A/B/C/D options).
version: 1.0.0
platforms: [macos, linux]
metadata:
  hermes:
    tags: [plan, alignment, david-review, pre-build, think, feature, workflow, decision]
---
# Feature Plan Alignment

> **Goal**: When a feature is non-trivial, get David to **sign off on direction before code is written** — by producing a structured plan artifact (MD + boss JSON + Discord notification) that is short enough to read in 5 minutes and concrete enough to spot disagreements early.

## Why this skill exists

Without a plan gate, the agent writes code based on a guess about what David wants, then either:
- Ships the wrong thing → David says "唔啱" → throwaway 4 hours of work
- Asks 8 clarifying questions in chat → David gives short cues like "B" → agent guesses anyway
- Sits in clarification loop for hours waiting for answers

The plan artifact **collapses the ambiguity into concrete options with `chosen_by` fields**, so David can say "A OK, 改 B 嗰度" in one message instead of explaining from scratch.

## When to trigger

**Trigger when ANY of the following is true:**

1. **David signals review-first intent** — phrases like:
   - 「B 吧」 / 「慢慢」 / 「plan 先」 / 「畀我睇下 plan」 / 「可以 plan 嗎」 / 「check 一下」 / 「你 check 一 check」
   - 「我想 approve 先」 / 「未做之前畀我睇下」
   - **「開工吧」 / 「您開工吧」 / 「start work」 / 「begin」** — when scope is non-trivial (1+ sprint, >5 files, 4+ commits, red-line 16 / RBAC layer). Interpret as **「approve to start sprint planning」**, NOT 「approve to start coding」. Must write plan doc with scope options first. (Added 2026-06-07 — first hit was "您開工吧" interpreted as plan-first gate for Day 15 sprint.)
2. **Feature is non-trivial** — any of:
   - Touches >5 files
   - Will need 4+ commits
   - Has 2+ mutually exclusive design choices (e.g. A vs B vs C tabs layout, pre-fill vs override, single-tenant vs multi-tenant)
   - Affects existing RBAC matrix or schema (new model, new permission, new audit action)
   - Spans backend + frontend (not a one-layer change)
3. **Cross-project schema / UX decisions** — anything that will commit a pattern (e.g. "all admin pages should live under /settings") that other features will inherit

**Do NOT trigger for**:
- Bug fixes with obvious fix (just patch + regression entry)
- 1-file refactors with no design choice
- "Just do what I said" work where David gave concrete instructions already

## Output structure — the alignment artifact

Every plan produces **3 deliverables** in one commit:

| File | Purpose | Format |
|------|---------|--------|
| `docs/retros/<YYYY-MM-DD>-<feature>-plan.md` | Engineering plan — full detail, 12 sections | Markdown |
| `docs/_meta/<YYYY-MM-DD>-<feature>-plan.json` | Boss summary — 3 cards, decisions with `chosen_by`, risks | JSON |
| `docs/_html/<YYYY-MM-DD>-<feature>-plan-boss.html` | What David actually opens | HTML (via `doc-html-preview`) |

The MD goes in `docs/retros/` (not `docs/`) because it's a **work-in-progress** artifact awaiting approval — retros are gitignored in some projects, plan docs are committed (they're the audit trail of the decision).

Actually: plan MDs SHOULD be committed (red-line 10 expects plan-stage work to be documented), but mark them as `⏸ Awaiting David approval` in the title. Once approved and shipped, rename to `docs/retros/<date>-<feature>-shipped.md` and add a "shipped" section linking to the commits.

## MD template — 12 sections

Use this exact structure. Don't skip sections; David knows the structure and will scan for the parts he cares about.

```markdown
# <YYYY-MM-DD> — <Feature Name> Plan

> **Stage:** Plan (David 揀咗 <B/C/etc.> — 寫 plan doc 畀 David review 先)
> **Author:** Developer (main agent)
> **Status:** ⏸ Awaiting David approval
> **Branch:** 仲未開 — 喺 main 直接寫 plan doc, 實作時先 fork

---

## 1. 觸發原因
<What David observed, quoted verbatim if possible. e.g. "David 2026-06-07 觀察: 5 個 admin page 各自有 nav link...">

## 2. Plan questions resolved (David 揀咗)
<Table with 3-5 questions and the chosen option. Each row links to a deeper comparison in §6 or below.>

| Question | Option | Detail |
|----------|--------|--------|
| ... | A) ... | ... |

## 3. Sub-route / 結構 / Sub-component layout
<Table showing new structure: URLs, files, phase status.>

## 4. Schema / 數據模型 設計
<Prisma snippet, migration plan, seed plan.>

## 5. Backend endpoint / API 設計
<Endpoint list with request/response shapes, permission required.>

## 6. Frontend wiring / 設計
<Component breakdown, state management approach, what wraps what.>

## 7. RBAC 影響
<New permissions, role matrix changes, seed impact.>

## 8. Nav / layout 改動
<Nav items to add/remove/redirect, backward compat.>

## 9. 實作 steps (預 X hours, Y commits)
<Numbered 5-12 step list. Each step names a specific commit message.>

## 10. 影響範圍 (file 預估)
<File-by-file estimate: which files, +/- lines.>

## 11. Ship gate 影響
<Which red-lines 10-18 are touched. Which need new tests.>

## 12. 唔做嘅嘢 (P1/P2 backlog)
<Explicit list of scope cuts. This protects scope from creep.>

---

## 13. 決策點 — David 確認
<Final ask: "呢個 plan 接受?揀 A 全部 / 想改 plan / 想縮 scope">

If plan OK 我就:
1. 開新 branch `<prefix>/<feature>-<date>`
2. <merge stash / un-stash David working changes>
3. 跟 §9 嘅 steps 行
4. 跑 smoke + 出 evidence
5. PR + merge
```

## Boss JSON schema — the part David reads

```json
{
  "doc": "<YYYY-MM-DD>-<feature>-plan",
  "source_md": "docs/retros/<file>.md",
  "generated_at": "<ISO timestamp>",
  "generated_by": "main-agent (David picked option <B/C/etc>: write plan doc first, review before building)",
  "one_liner": "<ONE sentence, non-technical, what is this for>",
  "cards": {
    "timeline": "Plan stage only — David review 緊。Approve 後實作 X-Y hours, M commits, K migrations.",
    "cost": "N files 改, ~+XXX lines / -YY lines。零新 dep / 零 infra 改動 / etc.",
    "mitigation": "Backward compat / historical 不變 / audit log 完整 / RBAC 不變 / 等",
    "disclaimer": "Plan stage 不動 source code / David working changes 仲 stash 住 / 等"
  },
  "decisions": [
    {
      "question": "...",
      "options": [
        { "label": "A) ...", "pros": "...", "cons": "..." },
        { "label": "B) ...", "pros": "...", "cons": "..." }
      ],
      "default": "A) ...",
      "blocking": false,
      "chosen_by": "David 2026-06-07"
    }
  ],
  "risks_boss_speak": [
    "Plan 純文件, 未動 source code。David approve 之後先 fork branch 做。",
    "David 嘅 X modified + Y untracked working changes 仲 stash 住, 實作時先攞返。",
    "...",
    "...",
    "..."
  ]
}
```

**Critical fields** (use these exactly):
- `cards.timeline` — David wants to know "how long" in 1 sentence
- `cards.cost` — file count + LoC estimate, NOT money
- `cards.mitigation` — "what's already planned to de-risk", NOT vague hand-waving
- `cards.disclaimer` — "what could still go wrong" — protects against over-promising
- `decisions[].chosen_by` — **MUST** say "David <date>" if David picked, "AI default" if not yet picked. This is the audit trail.
- `risks_boss_speak` — 2-5 items in plain Cantonese-繁中, **referencing real project incidents** if possible, NOT generic platitudes

## Verify plan HTML is not a placeholder

After `build.sh`, **always run the body-region grep** to confirm the boss HTML is not the `👀 老闆版摘要待生成` placeholder:

```bash
for f in docs/_html/*-plan-boss.html; do
  if awk '/<\/head>/,/<script>/' "$f" | grep -q 'class="boss-placeholder"'; then
    echo "❌ PLACEHOLDER  $f"
  else
    echo "✅ HAS CONTENT  $f"
  fi
done
```

Three common gotchas in this pipeline — all from `doc-html-preview` skill:
1. **`build.sh` only globs `docs/*.md`**, not subdirs. Pass sub-folder MDs as positional args.
2. **Boss JSON key is filename-derived**, not semantic. `2026-06-07-feature-plan.md` needs `2026-06-07-feature-plan.json`, NOT `feature-plan.json`.
3. **`verify_boss_html.sh` uses `mapfile` (bash 4+)** — fails silently on macOS default bash 3.2. Use the inline grep above.

See `doc-html-preview/references/crm-system-2026-06-07-build-sh-gotchas.md` for full details.

## Discord notification — what to send

After committing the plan, send a Discord message to David's home channel (or a project thread if one exists):

```
📋 **<Feature Name> Plan** — 已寫好等你 review

**Boss 版 (老闆睇嘅, 拍板事項 + 風險口語化)**:
📄 `docs/_html/<file>-boss.html`

**Engineering 版 (1:1 render, 工程細節)**:
📄 `docs/_html/<file>.html`

**Source MD** (committed <sha>):
`docs/retros/<file>.md`

---

**N 個 decision 你之前揀咗**:
- ✅ A) <short label>
- ✅ A) <short label>
- ✅ A) <short label>

**Tech scope** (3-5 bullets):
- <One-line per major area>

**影響**: ~N files, +XXX / -YY lines, M commits, X-Y hours 實作。

**Plan stage 唔動 source code**。<David's working changes 仲 stash 住 / 等>.

---

**揀一個**:
- **A) Approve** — 我開 `<branch>` 開工
- **B) 改 plan** — 講邊度要改
- **C) 縮 scope** — 只做 <N> 個, 其他暫不 <do thing>
```

The Discord message is what David will respond to. Keep it scannable, lead with the deliverable file paths, end with the 3-option ask.

## Critical rules

1. **NEVER write source code in plan stage** — the entire point is to align before code. If you find yourself writing a `.ts` file, STOP and ask "am I in plan stage?".
2. **Decisions MUST have `chosen_by` field** — even if "AI default (no David input yet)". An empty `chosen_by` is a bug.
3. **Plan MD goes in `docs/retros/`** — not `docs/` (which is for committed architecture / reference docs) and not `_meta/` (which is for the JSONs).
4. **Commit the plan even if David hasn't approved** — `f5fa7b3 docs(plan): Day 14.6 — System Settings 重構 plan (awaiting David approval)` is the audit trail. When David approves, the plan MD IS the design doc for the implementation commits.
5. **After implementation, link plan to evidence** — in the implementation PR / final evidence retro, link back to the plan retro. Traceability = audit trail.
6. **Scope cut (option C in Discord message) is a real option** — sometimes David's choice is "just do Tax rate, not the full restructure". Honor it, don't push the bigger plan.

## What this skill does NOT do

- ❌ Does NOT spawn a CEO subagent to write the plan (main agent has the context, including the recent conversation)
- ❌ Does NOT modify source code
- ❌ Does NOT push to remote (David approves the branch name, then you push)
- ❌ Does NOT send a Discord notification to multiple channels (one home channel or existing project thread)
- ❌ Does NOT start a new worktree or branch (that's implementation, not plan)

## Sprint-start cue sub-pattern (added 2026-06-07)

**David 嘅「開工吧」/「您開工吧」唔係 free-pass 寫 code**。解讀歧義:

| Scope | 解讀 | 動作 |
|-------|------|------|
| Trivial (1 file, 1 commit, 已知 fix) | 「approve 寫 code」 | 直接做,事後 retro |
| Non-trivial (1+ sprint, >5 files, 4+ commits, 紅線 16 / RBAC) | 「approve 啟動 sprint **planning**」 | 寫 plan doc + scope options (A/B/C/D) + 送 Discord 等 David 揀 |

**判定 heuristic**(見唔到 David 明確講咩時):
- 涉及 `docs/TECH-DEBT.md` P1/P2 entry → non-trivial
- 影響 `docs/QA-TRACKER.md` P0/P1 US → non-trivial
- 改 RBAC permission / 新 audit action → non-trivial
- 改 Prisma schema → non-trivial
- 純 bug fix 有 known root cause + 1 個 file 改 → trivial

**Sprint scope plan doc 嘅 minimum viable output**:
- 3-4 個 scope option (A 完整 / B 最小 / C 集中 / D 自訂)
- 每 option: 步驟 + 工時 + commits + 影響 files + 紅線 16/12 影響
- 我 recommendation + 理由
- **Stash 狀態 (David working changes 仲 stash 住? 邊個 file? 最後 commit 何時?)**
  — 同埋 cross-reference `interruption-recovery/references/post-recovery-verification.md`
  Recipe C(per-file diff vs main, 避免 pop 出 duplicate definitions)
- 末段 A/B/C/D 揀一個回我

**Discord 訊息尾段必加**: "Plan stage 不動 source code, David 揀 scope 之前我唔 fork branch" — 顯式標 plan stage, 防 user 預期 agent 已 start 寫 code。

完整 workflow 同 template 見 SKILL.md § "Output structure"。

---

## Common pitfalls (verified 2026-06-07 crm-system)

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Writing source code in plan stage | Patch file gets created accidentally | Only write to `docs/retros/` and `docs/_meta/` in plan stage |
| Forgetting `chosen_by` on decisions | Boss JSON renders decisions as "not yet picked" | Every decision needs `chosen_by: "David <date>"` or `"AI default"` |
| Boss HTML renders as placeholder | David opens HTML, sees "待生成" | Verify with body-region grep; check JSON key matches MD basename |
| Picking options David didn't pick | "I assumed B" — David wanted A | Re-ask David before writing JSON; don't guess |
| Plan doc has 5+ decisions when only 3 were asked | Scope creep, David has to read more | Stick to decisions David actually surfaced; if new questions arise, ask before plan |
| Plan line refs (`file.ts:209-222`) go stale between plan and build | Day 15 P1-3 plan said `deal.ts:209-222 (3 delete handlers)`; real handler was at `deal.ts:329-340` and there were 4 handlers (deal/contact/company/service), not 3 | When following a plan, always grep the actual pattern (`grep -n "function toIdArray"`) and count occurrences. Don't trust line numbers or counts. Note deviation in the plan retro so future agents know the discrepancy. |
| Refactor scope can grow between plan and build | Plan B (Day 15) said "3 delete handlers"; main HEAD had 4 (service.ts also), each with subtle behavioural differences (e.g. service.ts has `usage > 0` early-return) | Before refactoring, do a `grep -l "DELETED" apps/api/src/routes/*.ts` (or equivalent) to count real occurrences. If scope grows, surface it to David BEFORE writing the helper — a 4-handler helper has different signature needs than a 3-handler one (e.g. support for `extraMetadata` to preserve deal.ts's `{ title }` vs the others' `{ name }`). |
| **Plan line-refs go stale after the work that superseded them lands** (2026-06-07 Day 15 lesson) | Plan said `deal.ts:209-222` but the delete handler moved to line 329 when Day 14.7 merge landed. Plan written *before* David's WIP merged into main; line numbers shifted. Implementation time spent re-grepping to find the real location. | (1) In plan docs, prefer `path + symbol/function name` over line numbers (e.g. `apps/api/src/routes/deal.ts :: delete handler`) — the symbol survives renames. (2) When executing a plan from a prior session, re-locate the symbol with `grep -n "function foo"` or `search_files` *before* patching; do not trust the plan's line numbers. (3) Add a verification step in the plan's "實作 steps": "re-grep target symbols to confirm location post-merge". |

## File structure — when to use what

| Project state | Plan goes in | Reason |
|---------------|--------------|--------|
| Fresh project, no existing docs/ | `docs/<feature>-plan.md` (root) | No retros yet, no clear sub-folder |
| Project with existing retros/ | `docs/retros/<date>-<feature>-plan.md` | Consistent with existing pattern |
| Project with plans/ sub-folder | `docs/plans/<date>-<feature>-plan.md` | If project already has one |
| Plan about a specific ADR topic | `docs/architecture/<NNNN>-<topic>.md` and tag as plan in the doc | Use the ADR numbering scheme |

Default for `~/www/crm-system`-style projects: `docs/retros/<date>-<feature>-plan.md`.

## Related skills

- **`doc-html-preview`** — owns the MD→HTML render and the boss JSON schema. Load alongside this skill.
- **`doc-html-preview/references/crm-system-2026-06-07-build-sh-gotchas.md`** — the 3 build-script gotchas (sub-folder glob, JSON key matching, macOS bash 3.2). Read before building the plan HTML.
- **`regression-guard`** — when a plan involves a bug fix, RG-XXX entry is required.
- **`dev-task-memory`** — for very long-running plan+implementation sessions, persist state to `docs/_meta/dev-task-state.md` so a fresh session can resume.
- **`interruption-recovery/references/post-recovery-verification.md` Recipe C** — when a plan's "Stash 狀態" section says David's working changes are stashed, run the stale-stash detection *before* trusting that section. The plan was written from a snapshot; the snapshot may be 100% superseded by a merge that landed after the plan was authored.

## Files in this skill

- `SKILL.md` — this file (workflow + 12-section template + JSON schema + Discord message template)
- `references/crm-system-2026-06-07-system-settings-plan.md` — example of a real plan doc (the one this skill was extracted from)
- `references/crm-system-2026-06-07-plan-boss-json.md` — example of a real boss JSON with `chosen_by` fields and project-specific `risks_boss_speak`
