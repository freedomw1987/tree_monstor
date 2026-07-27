# Reconstructing context when state file is generic template

Companion to `interruption-recovery` skill's Day 11 lesson. When
`resume.sh` (<historical 2026-07-25 retired>) outputs `<placeholder>` Goal / Decisions / Next Steps, the
state file is useless — you have to rebuild from external sources of
truth. This is the working 4-source sequence.

**This recipe was validated 2026-06-07 crm-system Day 14.7** (third
known hit; prior hits 2026-06-09 ×2 and 2026-06-06 once). The skill's
Day 11 lesson acknowledges the limitation but did not crystallise the
workaround — this file does.

---

## Why state file goes generic

`save_state.py` (<historical 2026-07-25 retired>) ships with a stub `detect_decisions_from_session()`
that returns `[]`. The `replace()` calls in the template mostly miss
placeholders (only `branch` / `commit` / `uncommitted changes` reliably
hit). Result: the file gets written with `<placeholder>` everywhere
*except* the header (project name + last-modified timestamp).

Resume skill reads it back, prints the template, and the agent
mis-interprets it as "I have no context." That's wrong — the agent
just has to *look harder*.

## 4-source reconstruction sequence (do all 4, in order)

### Source 1 — `git log` (truth about what's in main)

```bash
cd ~/www/<project>
git log --oneline -20                     # recent commit titles — what shipped
git log --oneline origin/main..HEAD      # ahead commits (red-line 33: revert check)
git log --oneline main..origin/main | head -5   # remote-only commits
git status                                # working tree state
```

**What you learn**: feature names, merge commits, branch context,
working tree dirty-or-clean. The first 5-7 commit titles usually
contain Day-N.N step numbers and feature codenames that map directly
to user-visible work.

### Source 2 — `session_search` (truth about what was decided)

```bash
session_search(query="<project-name> Day <N> red line 16 test infra",
               limit=5)
```

FTS5 returns 5 most-relevant sessions, each with:
- `bookend_start` — first 3 user+assistant messages (the goal / kickoff)
- `bookend_end` — last 3 user+assistant messages (the resolution /
  decisions)
- `messages` — ±5 messages around the FTS5 match, anchor flagged

**Trick**: query with a **multi-keyword combination** (project + day
number + specific term). Single-keyword queries return too-broad
results; specific phrases like `"red line 16"` or `"43a0462"` zero
in on the exact session. Quote phrases for exact-match.

For deeper drill-in, use the scroll shape:
```bash
session_search(session_id="<id>", around_message_id=<match_id>, window=10)
```

### Source 3 — `docs/_meta/interruption_log.md` (audit trail of save events)

```bash
cat docs/_meta/interruption_log.md
```

Each row = one <historical 2026-07-25 retired: `recovery.sh` invocation> with timestamp + reason — 改為手動 state file edit timestamp
("Day 14.7 frontend handoff 收工"). Helps confirm "did we already
ship X / were we mid-Y when interrupted" if state is ambiguous.

### Source 4 — David's last open question / pending approval

**The strongest signal of all.** The previous session often ended with
the agent asking David to pick A/B/C. Check the most recent user
message + last assistant response in the latest session:

- If David's last message was a single letter (`A` / `B` / `C`) →
  **default to that answer and execute immediately**
- If David's last message was `好` / `OK` / `B吧` → approved the
  previous question, take the action
- If David's last message was a 1-3 word cue (`recovery` / `?` /
  `Zombie?` / `停`) → **treat as ship signal**, no further questions

This is the David-cue pattern documented in user-profile memory. Single-
word = stop, ship, no more prompts.

## Output the resume message as if state file had worked

Once you have all 4 sources, emit a "📍 Resuming <project> — last
activity <ts>" block with:

1. **Goal** (1 sentence, what the project is shipping)
2. **Current state** (HEAD commit + branch + working tree status +
   uncommitted file list if any)
3. **Decisions with WHY** (from session_search bookend_end, max 5)
4. **Open question from last session** (David's pending choice if any)
5. **Next 3-5 steps** (concrete, with file paths)
6. **Risks / blockers** (red-line audit gaps, uncommitted sacred files,
   etc.)

Do **not** re-emit the generic template. The point of reconstruction
is to skip the placeholder and jump straight to actionable context.

## Worked example (2026-06-07 crm-system Day 14.7)

Inputs:
- `resume.sh crm-system` (<historical 2026-07-25 retired>) → all `<placeholder>` in Goal/Decisions/Next
- `git log -3` → `019cab8 Merge feat/system-settings-tabs-2026-06-07: Day 14.7...`
- `git status` → `nothing to commit, working tree clean`
- `git log origin/main..HEAD` → empty (sync confirmed)
- `session_search("crm-system Day 14 day 15 tech debt red line 16")` →
  returned bookend showing Q1=`A` (accept `43a0462`) + Q2=`好` (open
  TECH-DEBT ticket)
- Last David message before `recovery` → "Q2:紅線 16 嘅 tech debt 要唔要
  我而家開 docs/TECH-DEBT.md ticket(等 David 之後 review 批准 commit)? 好"

Reconstructed output (what I emitted):
> "Q1 默認 closed (A 接受 `43a0462`); Q2 落實 — 加 P2-13 entry,
> commit `a085bb4`, push to origin/main. Shipped."

5 tool calls vs the ~30 it would have taken to ask David to re-explain.

## When this recipe fails

If after all 4 sources the goal is still unclear (e.g. user came back
after a week, multiple in-progress tasks in flight, ambiguous last
message), it's better to ask **one** clarifying question than to guess
wrong. Use the `clarify` tool, 3-4 options, anchored on the most likely
next action (not "what do you want to do?").

Failure mode to avoid: re-asking the same question the previous
session ended on. If `session_search` bookend_end shows you already
asked "Approve A / B / C?" and David sent a 1-letter answer, the
question is **already answered** — execute, don't re-ask.

## Related

- `interruption-recovery/SKILL.md` § "Day 11 Lesson" — the original
  template-limitation writeup
- `dev-task-memory/SKILL.md` — 5-layer memory architecture (this
  recipe is the manual Layer-2 fallback when Layer 1 fails)
- `interruption-recovery/references/post-recovery-verification.md` —
  Recipes A+B (run **after** reconstruction, before "ready to ship")
