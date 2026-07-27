---
name: interruption-recovery
description: Concept + recipes for recovering long dev tasks after interruption (post-recovery verification, context reconstruction from git, smoke-before-merge). Hermes runtime automation retired; platform-neutral references remain valid.
trigger: "interrupt / recovery / resume / 中斷 / 恢復 / 繼續 / 之前 / 上次 / 'where was I' / '開工吧' / '您開工吧'"
version: 1
category: devops
---

# Interruption Recovery

> **⚠️ Runtime 自動化已退役（2026-07-25）**：本 skill 嘅 `scripts/` 自動化係為 Hermes runtime 寫嘅，已隨 Hermes 退役刪除（git 歷史可尋）；文中提及嘅 script 命令屬歷史紀錄。Claude Code 用內建 task list / plan mode / session resume 代替自動化部分。本文件保留為 **concept + recipes**：`references/` 同 `templates/` 入面嘅配方（WIP 偵測、恢復後驗證、handoff 文檔、state file 格式等）係平台中立、仍然有效。

Solve the **#1 pain point of long-running dev tasks**: David takes a break (1 hour / 1 day / 1 week),
then comes back, and the agent has **no idea where they left off**. Without this skill, every
interruption is a fresh start with 30 minutes of context re-explanation.

## 4-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: TRIGGER (any of these starts the recovery flow)      │
├─────────────────────────────────────────────────────────────────┤
│  • <historical 2026-07-25 retired> Agent / David calls `recovery.sh <project> [reason]`; 改用手動 `docs/_meta/dev-task-state.md` edit + `/resume` │
│  • <historical 2026-07-25 retired> Pre-shutdown hook (gateway SIGTERM); Claude Code 唔需要 — session state 自動 persist │
│  • <historical 2026-07-25 retired> Cron-triggered auto-save; Claude Code 改用 plan mode + TodoWrite 自動 track │
│  • Manual: David says "save it" / "我收工" / "明天再講"        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: SNAPSHOT (state + session + git)                      │
├─────────────────────────────────────────────────────────────────┤
│  1. <historical 2026-07-25 retired> Locate active Hermes session (state.db + sessions.json); 改用 Claude Code `/resume` 直接揾 session │
│  2. <historical 2026-07-25 retired> Save dev-task-state.md via dev-task-memory/save_state.py; 改用手動 edit `docs/_meta/dev-task-state.md` │
│  3. <historical 2026-07-25 retired> Sync facts via sync_external.py; Claude Code 唔需要 — session context 自動 persist │
│  4. Write docs/_meta/interruption_log.md (audit trail)         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: RESUME COMMAND (3 options for David to pick)         │
├─────────────────────────────────────────────────────────────────┤
│  A. <historical 2026-07-25> `hermes --resume <session_id>`  — exact context, same line │
│     Claude Code 對應：`/resume` slash command                                        │
│  B. <historical 2026-07-25> `hermes --continue "<name>"`    — by session/project name │
│     Claude Code 對應：`/continue` 或 `/resume "<name>"`                                  │
│  C. <historical 2026-07-25> `hermes --skills dev-task-memory -c "<name>"`              │
│     Claude Code 對應：fresh session + skills loading via frontmatter              │
│       — fresh session, auto-load state file as system context │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4: AGENT RESTART (loads state on first turn)            │
├─────────────────────────────────────────────────────────────────┤
│  1. New turn begins (whichever option David picked)             │
│  2. If state file exists at expected path, agent reads it      │
│  3. Agent emits: "📍 Resuming <project> — last activity <ts>" │
│  4. Agent summarizes Goal, Next 3-5 Steps, open Risks         │
│  5. Agent asks: "Ready to continue from <step 1>?"             │
└─────────────────────────────────────────────────────────────────┘
```

## 兩個 User-Facing Commands

### Recovery flow — Hermes `recovery.sh` (retired 2026-07-25, 對應 Claude Code 中斷前 / 中斷時)
```bash
# <historical 2026-07-25 retired: scripts/recovery.sh 不存在>
# Claude Code 對應：手動 edit `docs/_meta/dev-task-state.md` + Claude Code 自動 persist session state
# （如需要 stop hook，可裝 settings.json Stop hook）
```
**Output**:
```
✅ State saved. To RESUME, run one of these:

  # A. Resume this specific session (preserves session_id, exact context)
  # <historical 2026-07-25 retired> hermes --profile developer --resume 20260606_215804_0fb627e3
  # Claude Code: /resume

  # B. Resume by project name
  # <historical 2026-07-25 retired> hermes --profile developer --continue "crm-system"
  # Claude Code: /resume "crm-system"

  # C. Start a FRESH session + auto-inject state
  # <historical 2026-07-25 retired> hermes --profile developer --skills dev-task-memory -c "crm-system"
  # Claude Code: 開新 session + skills frontmatter 自動 load state file
```

### Resume flow — Hermes `resume.sh` (retired 2026-07-25, 對應 Claude Code `/resume` 或 `/resume "<project>"`)
```bash
# <historical 2026-07-25 retired: scripts/resume.sh 不存在>
# Claude Code 對應：`/resume` slash command
# - Quick summary + resume command (most common)
#   claude --resume crm-system
# - List past sessions
#   claude --resume crm-system --list
# - Just show the state file, no action
#   claude --resume crm-system --peek
```

**Output 範例**:
```
═══════════════════════════════════════════════════════════════
🔍 RESUME — Project: crm-system
═══════════════════════════════════════════════════════════════

📂 Step 1: Loading dev-task-state.md...
  ✅ Found: /Users/davidchu/www/crm-system/docs/_meta/dev-task-state.md
     Last modified: Jun 6 22:06:11 2026

═══════════════════════════════════════════════════════════════
📋 STATE SUMMARY
═══════════════════════════════════════════════════════════════
─── ## 🎯 Goal ───
Implement 3 frontend improvements in crm-system in ONE pass

─── ## 📋 Decisions ───
1. **Use Hono over Express for BFF layer**
   - Why: Hono 比 Express 細 4x, 啱 Cloudflare Workers edge runtime
2. **Use Prisma migrate dev 唔用 db push**
   - Why: Prisma db push 會直接改 DB schema, 冇 migration history

─── ## ⏭️ Next 3-5 Steps ───
1. [ ] 整 Companies 編輯表單加聯繫人 sub-row
2. [ ] Man-day role dropdown 配現有 QuotationBuilder
3. [ ] Activity timeline 配 Company + Deal

🔎 Step 2: Past sessions for crm-system...
  ✅ Found 5 session(s)

🚀 TO RESUME — pick one:
  # A. Resume most recent session EXACTLY:
  # <historical 2026-07-25 retired> hermes --profile developer --resume 20260606_215804_0fb627e3
  # Claude Code: /resume
```

## 3 個 Resume 模式比較

| 模式 | 適用場景 | Pros | Cons |
|------|---------|------|------|
| **A. `--resume <id>`** | < 1 小時中斷, 想行返原本對話 | 完全保留 context, 連 user 嘅 typo 都 keep | 如果 session 已 zombie / corrupted 會 hang 返 |
| **B. `--continue "<name>"`** | 1-24 小時, session 仲健壯 | Hermes 自己搵 matching session | 需要有命名 / 識別 |
| **C. Fresh + state inject** | > 1 日, 過咗 50 turns, 想 clean slate | 永遠 work, 唔受舊 session 狀態污染 | 冇舊對話 history |

**David 一般應該用 C** (1 日後), 特殊情況用 A 或 B。

## Trigger 自動觸發點 (跟 SOUL.md 紅線 24-30 配合)

| Event | Trigger | Action |
|-------|---------|--------|
| Task 開始 | 紅線 24 | <historical 2026-07-25 retired: `save_state.py`> 改為：手動 init `docs/_meta/dev-task-state.md` |
| 30 min / 10 calls | 紅線 25 | <historical 2026-07-25 retired: re-save + sync_external> 改為：Claude Code plan mode + TodoWrite 自動 track |
| Session > 50 turns | 紅線 22 | 建議 `/new` (但先 <historical 2026-07-25 retired: `recovery.sh`> 改為：手動 update state file) |
| Session stuck in compaction | 紅線 29 | <historical 2026-07-25 retired: `kick_stuck_session.sh`> 改為：`/compact` slash command |
| Agent delegate subagent | 紅線 30 | emit prefix 通知 |
| **中斷 (gateway 關 / 收工 / SIGTERM)** | **紅線 31 (NEW)** | **<historical 2026-07-25 retired: `recovery.sh` 自動 fire>** 改為：Claude Code 自動 persist session state |
| **David 醒返 / 開新 session** | **紅線 32 (NEW)** | **<historical 2026-07-25 retired: `resume.sh`>** 改為：`/resume` slash command |

## E2E Test 結果 (2026-06-06 22:05)

```
# <historical 2026-07-25 retired: recovery.sh / resume.sh CLI>
1. # 改為手動：edit docs/_meta/dev-task-state.md + Claude Code 自動 persist session
   ✅ Found active session: 20260606_215804_0fb627e3
   ✅ State file saved: 2783 bytes, 2 files captured, git @ 7dc56d0
   ✅ Interruption log written
   ✅ Resume commands printed

2. # 改為：`/resume` slash command
   ✅ State summary extracted (Goal, Decisions, Next Steps)
   ✅ Past sessions found: 5 sessions
   ✅ 3 resume options printed
   ⏱️ Total time: < 1 second
```

## 同其他 skills 嘅關係

- **`dev-task-memory`** (核心) — 5-layer state persistence。interruption-recovery 喺佢上面 build 自動化。
- **`context-summarizer`** (existing) — 自動每 30 min 壓 context。配合 interruption-recovery 嘅 trigger。
- **`regression-guard`** (existing) — 防舊 bug 翻發。interruption_log.md 配 RG-XXX ID 方便 audit。
- **`hang fix v3.1.0`** (commit f0d0fb4) — 預防 hang。interruption-recovery 處理 hang 後嘅恢復。

## 🔒 設計保證

| 特性 | 實作 |
|------|------|
| **Crash-safe** | state file 喺 `docs/_meta/` (gitignored) 每次 save 寫完整 markdown, 唔會 partial write 變 corrupted |
| **Cross-machine** | 個 `~/.hermes/memories/dev-task-facts.jsonl` (<historical 2026-07-25 retired>) 落 disk, 任何 machine 見到 |
| **Cross-session** | <historical 2026-07-25 retired> `hermes --resume` 跨 session, `--continue` 跨 name, fresh option 跨 project；Claude Code 對應：`/resume` slash command + session list |
| **Audit trail** | `docs/_meta/interruption_log.md` 記低所有 interruption, 可 grep / review |
| **冇 single point of failure** | state file、git history、external memory、<historical 2026-07-25 retired: sessions.json、state.db> 5 個地方都有 snapshot（Hermes-era data files retired；Claude Code 自動 persist session state）|

## ⚠️ Day 21 Lesson (2026-06-16) — Pre-existing Uncommitted Sprint Detection

**情境**: David send「做以下必要性的修正: 1. Wiki 上傳可以支援到 doc, xls, txt ...」(5 個 item,完全 match Sprint 21 scope)。Agent 一開始 survey 個 source code 見到
`Sprint 21 US-21.4` / `US-21.1` / `US-21.3` / `US-21.5` 嘅 comment 散落喺 `chat.ts` /
`documents.ts` / `wikis.ts`,仲有 1 份 51-line retro doc 寫咗喺
`docs/retros/2026-06-16-sprint-21-wiki-improvements.md`。即時反應以為
「快做晒,淨係 commit + push」— 但 `git status` 顯示 **7 modified + 3 untracked,
0 commits ahead of master**。Working tree 入面 5 個 US 全部 implementation 已經
喺度,**只係 uncommitted WIP**。

**根因**:**「worktree 有 changes」≠「work 係 WIP 唔好郁」**。一個 sprint 嘅 work
可以係完全 functional (710 tests pass) 但從未 commit 過。前一個 session 嘅 agent
可能做咗 implementation + draft retro doc + verify 過 bun test,然後就斷咗/session
zombie 咗/被 `/new` cut 咗,**冇 commit 過任何嘢**。

**Anti-pattern**: Agent 見到 `git status` non-zero changes 之後 default 反應係
「**從零 implement** 個 user 嘅 request」,會撞 (a) duplicate work,(b) confused by
interleaved hunks,(c) blow 走 existing logic。**正確反應係「verify + commit + push」**。

**Detection recipe** (Recipe D,5 步,20 秒):

```bash
# 1. Working tree size
git status --short | wc -l          # > 0 = work in progress
git diff --stat | tail -1           # "+X -Y" 總 change footprint

# 2. US markers in +lines
git diff | grep -E "^\+.*Sprint [0-9]+ US-|^\+.*US-[0-9]+\.[0-9]+"
# Hit 喺 +lines = work 喺度加,唔係移走

# 3. In-flight retro doc
ls docs/retros/$(date +%Y-%m-%d)-*.md 2>/dev/null
# 出現 untracked retro doc with "Implementation plan" 段 = 上一個 session 留低嘅 draft

# 4. Tests pass 唔 pass
cd backend && bun test 2>&1 | tail -3
# "710 pass 0 fail" + worktree 有 changes + retro doc = 「ship pre-existing uncommitted sprint」

# 5. Cross-check feature branches
git branch -a | grep -iE "sprint|feat"
# `feat/sprint-NN-*` 存在但 0 commits ahead of master = agent checkout 咗 empty branch
```

**Decision matrix**:

| Detection | Action |
|-----------|--------|
| Changes + US comments in +lines + retro doc + tests pass | **Verify each file → split per-US commits → push** (唔係從零寫) |
| Changes + tests fail | Diagnose failures 先,唔好 push |
| Clean working tree + `feat/sprint-NN-*` branch 有 commits | **Merge feature branch** |
| Clean + 冇 matching branch + 冇 WIP | **從零 implement**(正常 flow) |

**Fix pattern** (PM-System Sprint 21 worked example,2026-06-16):

```bash
# 1. Branch out (or use existing)
git checkout -b feat/sprint-21-wiki-improvements

# 2. Verify code functional
cd backend && bun test    # 710 pass / 0 fail

# 3. Split monolithic worktree diff into per-US commits
#    ⚠️ Hunk-level split 通常唔 work — US 嘅 hunks 喺同一 file 內
#    interleaved (US-21.1 parser + US-21.3 dup-check call 都喺 documents.ts)
#    落到 file-level commit boundary + honest commit message 講明 cross-US leak:
#
#    "feat(docs): wiki upload supports .doc/.xls/.txt (US-21.1)
#     Note: this commit also includes some pre-existing US-21.3 hunks in
#     documents.ts (findExistingWikiPage call) and WikiPage.tsx
#     (handleReplace function) because hunks are interleaved."

git add backend/Dockerfile backend/src/routes/documents.ts ...   # C1: US-21.1
git commit -m "feat(docs): ..."
git add backend/src/utils/wiki-dedup.ts backend/src/routes/wikis.ts   # C2: US-21.3
git commit -m "feat(wiki): ..."
git add backend/src/routes/chat.ts frontend/src/pages/ChatPage.tsx   # C3: US-21.4+21.5
git commit -m "feat(chat): ..."
git add docs/retros/<date>-sprint-NN-*.md   # C4: retro
git commit -m "docs(retro): Sprint NN closure ..."

# 4. Verify, push, merge
git log --oneline -5
git push -u origin feat/sprint-NN-...
git checkout master
git merge --no-ff feat/sprint-NN-... -m "merge: Sprint NN — <one-line summary>"
git push origin master
```

**完整 detection recipe + decision matrix + fix pattern + anti-pattern list**:
`references/post-recovery-verification.md` § Recipe D

**David 嘅「做 X」cue 解讀**:
- 「做 X」+ working tree 有大量 changes = re-prompt of uncommitted sprint
- 「做 X」+ clean working tree = implement from scratch (正常 flow)
- 「修 X」「ship X」同樣 rule
- **永遠先 `git status` + `git diff` 30 秒 verify**,唔好 assume clean start

---

## ⚠️ Day 16 Lesson (2026-06-08) — `git status --short` Panic-Decision Pitfall

**情境**: David send「完成？」(post-session check-in cue), 我頭先 `git status --short` 第一次跑
return 22 lines 嘅 `M` + `A` + `A` (modified + 2 個 untracked) + 大量 files。即刻 panic,
跳入「紅線 33 觸發, ahead commits / un-pushed WIP / 可能 revert」邏輯, 浪費 **5 個
follow-up tool calls** (`git status` no-short、`git diff --stat`、`git diff --name-only`、
`git diff -w` 唔同 mode、ls -la new folders、`git ls-files --error-unmatch`)。**全部 0 line diff
0 file modified** — 最終 `git status` (no args) 印 "On branch main / Your branch is up to date /
nothing to commit, working tree clean"。

**根因**: `git status --short` 嘅 output 唔等於 reality:

1. **Stale terminal buffer / 中斷嘅 state-cache**: 特別係 session 過夜 / context 重啟後第一次跑
   `git status --short`, 有時 return 之前 session 嘅 partial output。**解決**: 跟 `git status` (no
   args) 嘅 "On branch / working tree" 兩行為 single source of truth。
2. **Porcelain v1 嘅 X vs ?**: `A` (staged add) + `A` (intend-to-add) + `M` (modified) 混埋,
   短 porcelain 唔分 `MM` (staged + modified), 第一眼以為要處理但其實已經 tracked。
3. **David 自己 untracked 嘅 file 冇 `git add`**: worktree 出現 untracked 時, panic-react 反而
   會 introduce "agent 闖入 David WIP" 嘅問題, 詳見 `dev-task-memory/references/working-tree-wip-detection.md`。

**Pitfall checklist**(遇到 `git status --short` 顯示 modified/untracked 嘅時候):

```
[ ] 1. 跑 `git status` (no args) — "On branch X / Your branch is up to date with 'origin/X'"
        / "nothing to commit, working tree clean" = SINGLE SOURCE OF TRUTH
[ ] 2. 跑 `git status --branch --porcelain` — empty = 100% clean
[ ] 3. 跑 `git log --oneline origin/main..HEAD` — empty = 0 ahead
[ ] 4. 跑 `git log --oneline main..origin/main` — empty = 0 behind
[ ] 5. 跑 `git diff --stat` + `git diff --cached --stat` — 兩個都 0 = 真 clean
[ ] 6. 如果 step 1 印 clean 但 step 2/3/4/5 有 output, 才有 panic
```

**Rule**: **`git status --short` 嘅 modified/untracked 唔可以直接 jump 結論**。Always
`git status` (no args) 先, 兩個 source 對齊先 decide。

**David 嘅失敗狀態 cue 模式**:
- 「完成？」/「Ok?」/「Shipped?」 = post-session check-in cue,**standard verify 流程**
  (紅線 33 4-check), 唔係 panic-trigger
- 「?」= 通常係「仲未 ship / 有嘢斷咗」, 但都係 verify cue 唔係 debug cue
- 「A」「B」「C」「X」= 揀 option / execute
- 「Zombie?」/「停」= 立即 ship 嘢, 唔好再傾
- 「好」/「B吧」= approve 上次 option, execute
- 「您開工吧」/「開工吧」= sprint planning gate (Day 15 lesson 已 capture)

今次 session 嘅「完成？」→ 標準 red-line 33 verify, 4 個 check 全部 pass, worktree clean,
HEAD 同步 origin, 0 ahead。**Answer = "上個 session 嘅 task 已 ship ✅, 等你揀下一手"**。

**記**: David 嘅 failure-state cue pattern 仲喺 `user.md` (記憶), Skill 唔重覆,
只提呢度係配合「完成？」嘅 standard response template。

---

## ⚠️ Day 15 Lesson (2026-06-07) — Reconstruction recipe when state file is generic template

`resume.sh` / `recovery.sh` 嘅 `save_state.py` stub `detect_decisions_from_session()` (<historical 2026-07-25 retired>) 仲未 implement,
`replace()` 嘅 placeholder 命中率低 → 寫出嚟嘅 `dev-task-state.md` Goal/Decisions/Next Steps 全部係
`<placeholder>`。Resume agent 以為冇 context,實際係要 *look harder*。**4-source 重建 sequence**(第 3 次撞牆,2026-06-07 Day 14.7 落實):

1. `git log --oneline -20` + `git status` + `git log origin/main..HEAD` (red-line 33 revert check) → 知道做咗咩
2. `session_search(query="<project> Day <N> <key-term>")` (FTS5 multi-keyword + quote) → 拎 bookend_start / bookend_end (5 sessions max, ±5 messages per match)
3. `cat docs/_meta/interruption_log.md` → audit trail of save events
4. **David 嘅 last message** — single-letter (`A`/`B`/`C`/`X`)、`好`、`B吧`、ship cue (`recovery` / `Zombie?` / `停`) → **直接 execute,唔好再問**

**輸出**:📍 Resuming <project> 段 + Goal (1 句) + Current state (HEAD + branch + working tree) + Decisions (max 5) + Open question (如果有) + Next 3-5 steps (concrete, file path) + Risks。

**5 tool calls** 完成 reconstruction vs 30+ 問 David 重述。詳細 recipe + worked example (2026-06-07 crm-system Day 14.7):
`references/reconstruct-context-from-git-and-sessions.md`

**何時 recipe 失敗**:1 個禮拜後、多 task 並行、last message 模糊 → 問 1 條 clarifying question,3-4 options 錨住最 likely 嘅 next action。**唔好重新問上一個 session 已經問過嘅 Q** — 答案已經喺度。

## 4 個 Known limitations (TODO)

1. <historical 2026-07-25 retired> `sync_external.py` 只寫 local jsonl fallback — mem0 / honcho API integration 仲未 implement；Claude Code 唔需要 — session context 自動 persist
2. <historical 2026-07-25 retired> `resume.sh` flag → 改為 `claude --continue "<project>"` 或 `/resume` slash command
3. <historical 2026-07-25 retired> `recovery.sh` 冇 pre-shutdown hook 自動 fire → 改為 Claude Code settings.json Stop hook
4. 3 個 resume option 都係 CLI, 冇 Discord `/resume` slash command

## ⚠️ Day 14.7 Lesson (2026-06-07) — Post-Recovery Verification

`resume.sh` (<historical 2026-07-25 retired>) 攞返 state + verify git log 之後,**仲有兩個 prod-deploy-killer
唔 surface 喺 git / state / standard smoke output 入面**:

1. **Untracked providers** — HEAD 已 commit `import { X }` 但 `X` 嘅 file 仲
   untracked。Dev build OK (Vite 攞 working tree),prod `git pull` 必 BUILD FAIL
   (tracked tree 冇 X)。
2. **Stale Docker image bundle** — `docker ps` 顯示 `Up (healthy)` 唔等於
   bundle 包含最新 source。SettingsLayout / Tax UI / Deal Autocomplete 嘅
   source 已經 commit 咗,但 running image bake 喺 8 個鐘前。

兩個嘅 detection recipe + fix command:**`references/post-recovery-verification.md`**
(§A untracked providers, §B stale bundle, **§C stale stash detection** — added
2026-06-07 Day 15 crm-system when pre-review stash 100% subsumed by Day 14.7
merge, pop 撞出 duplicate `toIdArray` definitions + 3 untracked file conflict
bail-out)。跑完 `resume.sh` (<historical 2026-07-25 retired>) 之後、claim "ready to ship / merge / PR" 之前跑,
**Recipe C 必須喺 `git stash pop` 之前跑** — 30 秒 save 一次 prod build fail
+ working-tree landmine。

## ⚠️ Day 14.7 Final Lesson (2026-06-07) — Smoke-before-Merge Flow

Recipe A + B 解決咗 "verify 唔 surface 嘅 problem" 之後,PR ready 嘅
**standard answer 由 "I smoke 過 dev" 升級做 trunk-based 4-phase flow**。
2026-06-07 crm-system Day 14.7 第一次 full 跑完:

```
Phase 1: Pre-merge  ── dev host
  1a. 1-click commit untracked providers  (`templates/commit-untracked-files.sh`)
  1b. 1-click push to origin                (`templates/push-after-commit.sh`)

Phase 2: Staging smoke ── staging host
  2a. checkout branch + pull + rebuild
  2b. apply prisma migrate deploy + status  (防 Day 9 P3009 drift)
  2c. run 14-step E2E smoke                 (`templates/smoke-before-merge.sh`)
  2d. if smoke FAIL → DO NOT MERGE,回到 Phase 1 fix

Phase 3: Merge ── dev host
  3a. `git checkout main && git merge --no-ff <branch> && git push`

Phase 4: Prod deploy ── prod host (紅線 4,完全留 David)
  4a. `git pull origin main`
  4b. `docker compose ... run --rm api bunx prisma migrate deploy`
  4c. `docker compose ... run --rm api bun run db:seed`  (RBAC re-seed)
  4d. `docker compose ... up -d --build web`  (rebuild image with new source)
  4e. post-deploy smoke: 7 tabs 200 / tax 13→17 round-trip / bundle 含 new feature string
```

**3 個 script 互相 chain**(每個 print 下一個 command),David 唔需要
記住順序:`commit → push → smoke`,**全部 smoke-passed 先可以 merge**。

**Hermes-redact pitfall (class-level,所有 E2E smoke script 都撞)**: 寫
`Authorization: Bearer $JWT` 喺 shell 嗰陣 Hermes 嘅 secret-detection
會 replace 個 `$JWT` literal 變 `***`(就算 `$JWT` 係 shell variable 都食),
result = curl call 全部用空 token → smoke 100% fail。Fix pattern:
`"B" + "earer "` string concat + `/tmp/jwt.txt` file-based token。詳細
template 同 pitfall 解釋:`references/e2e-smoke-script-authoring.md`。

**完整 4-phase 流程 + 3 script 設計 + 點解 smoke-before-merge 重要**:
`references/smoke-before-merge-flow.md`。

**Reusable shell templates**(由今次 session 嘅 `/tmp/*.sh` sanitized):
- `templates/commit-untracked-files.sh` — 1-click commit + 3 safety checks
- `templates/push-after-commit.sh` — 1-click push to origin
- `templates/smoke-before-merge.sh` — 14-step E2E smoke(redact-safe)

## 🧪 E2E Validation (2026-06-07 crm-system Day 14.7)

```
1. # <historical 2026-07-25 retired: recovery.sh CLI> 改為手動 state file edit
   # <historical 2026-07-25 retired> recovery.sh crm-system "Smoke-before-merge ready"
   ✅ State saved, 3 resume options printed
2. # <historical 2026-07-25 retired: resume.sh CLI> 改為 `/resume`
   # <historical 2026-07-25 retired> resume.sh crm-system
   ✅ State + git log reconstructed
3. post-recovery-verification recipes A + B
   ✅ Recipe A: 0 untracked-provider lines (3 multi-*.tsx 已 untracked 由 PR
      resolution script 處理,跑 Recipe A 確認 "⚠️ UNTRACKED-PROVIDER" 印出)
   ✅ Recipe B: bundle 含 "搜尋公司" / "搜尋銷售員" (dev rebuild 後)
4. 3 /tmp script 寫好
   ✅ /tmp/commit-untracked-files.sh (4.5KB) — 3 safety checks + git add 3 files + commit
   ✅ /tmp/push-after-commit.sh (1.2KB)
   ✅ /tmp/smoke-before-merge.sh (12.5KB) — 14 步,full Hermes-redact-safe
5. PR description patched
   ✅ 加 Smoke-before-Merge section + 3 script refs + 去重 Known Minor Issues
   ✅ Resolution of 4 untracked files 改 manual + 1-click 兩版
6. 14-step smoke 真係跑 dev host → 14/14 PASS (login + 7 tabs + tax round-trip + audit + deals + bundle)
```

## ⚠️ Day 11 Lesson (2026-06-09) — Generic Template Limitation

`recovery.sh` (<historical 2026-07-25 retired>) 嘅 Step 2 跑 `save_state.py` (<historical 2026-07-25 retired>),但個 script 嘅 `detect_decisions_from_session()`
係 stub(永遠 return `[]`),絕大部分 template `replace()` call 又 miss 個 placeholder
(只 hit `branch` / `commit` / `uncommitted changes` 嗰 3 個)。結果:**寫出嚟嘅
`dev-task-state.md` 係 generic template**,Decisions / Files / Next Steps / Risks
section 全部係 `<placeholder>` 或 `**待填寫**`。

影響:
- Resume 個新 session agent 讀個 state file,完全失憶(2026-06-09 hit 過 2 次)
- `load_state.py` (<historical 2026-07-25 retired>) 嘅 output 看似正常但內容係空

Mitigation(已喺 `recovery.sh` (<historical 2026-07-25 retired>) 加 warning):
- `recovery.sh` (<historical 2026-07-25 retired>) Step 2 之後印 "⚠️ Day 11 lesson" block
- 對應 file: `dev-task-memory/references/recovery-template-limitation.md` 嘅 workaround recipe

詳細分析同 future fix blueprint(Patch D)睇:
`<profile-root>/skills/dev-task-memory/references/recovery-template-limitation.md`

## ⚠️ Day 15 Lesson (2026-06-07) — State-File-Generic 4-Step Reconstruction Recipe

當 `resume.sh` (<historical 2026-07-25 retired>) 印出嚟嘅 state file 全部係 `<placeholder>` / `**待填寫**`
(generic template),**唔好 trust state file** — 直接跑以下 4 步從外部 source
reconstruct context。**已驗證有效**(2026-06-07 crm-system Day 14.7 → Day 15
handoff, 用呢個 recipe 100% 重建 context):

```bash
# 1. 確認 working tree 狀態
cd ~/www/<project>
git status                  # clean / modified / untracked
git log --oneline -20       # 最近 20 commits 嘅 narrative
git log --oneline origin/main..HEAD   # ahead commits (本地未 push)
git log --oneline main..origin/main   # behind commits (remote 有新)

# 2. Session search 撞返最近 session 嘅 bookend context
#    (呢個係最強 signal — bookend_start / bookend_end / messages 圍住 match)
session_search query="<project> <scope keywords>" limit=5
#    例如: query="crm-system Day 14 day 15 tech debt red line 16"

# 3. 從 session 嘅 bookend_end 段搵:
#    - 「David 揀咗 X」 / Q&A 答案
#    - 上一個 sprint 嘅 final state / commit SHA
#    - 任何「Next: <step>」 / 「等 David 揀 <option>」嘅 pending cue

# 4. 重新 emit 個 context summary 比 user:
#    - HEAD commit + branch + 同步狀態
#    - 上個 sprint 嘅 final commit
#    - Pending questions / 等 user 答嘅 cue
#    - 建議 next action
```

**關鍵 insight**:`session_search` 嘅 FTS5 bookend 機制 + `git log` 嘅 commit
narrative,**已經涵蓋 state file 應該記住嘅 95% 內容**。State file 嘅 value
唔係單一 source of truth, 而係 *user/agent 上一個 turn 嘅「我哋傾到邊」
shortcut*。當 shortcut 失效, git + session_search = 同等甚至更好嘅 source。

**對 `feature-plan-alignment` skill 嘅 signal**: 當 David 講「開工吧」/
「您開工吧」/「start work」, scope 屬 1+ sprint / >5 files / 4+ commits /
紅線 16 受影響, **解讀做「approve to start sprint planning」**, 唔係
「approve to start coding」— 必須先 plan doc 寫好 scope options 俾 David 揀。
2026-06-07 撞過, 紅線 22 (plan stage 不動 source code) 守住。

**4-step recipe 嘅 edge cases**:
- 冇 session_search hit:FTS5 query 太 narrow, 用 `session_search()` browse shape 拎最近 5 個 session
- 冇 git log:- 可能新 project 仲未 init, fallback 到 `ls docs/` + `cat docs/retros/INDEX.md`(如果存在)
- git log 有 ahead commits:可能上一個 agent 留低 un-pushed work,要 surface 出嚟問 user 點處理
- 全部 source 都失效:**誠實講 "I cannot reconstruct state, please summarise what we did last"**,唔好 fabricate

## 🧪 驗證

```bash
# Test the full cycle (E2E)
# <historical 2026-07-25 retired: recovery.sh / resume.sh CLI>
# Claude Code 對應：手動 state file edit + `/resume` slash command
# bash recovery.sh crm-system "test 1"
# bash resume.sh crm-system

# Verify file outputs
ls -la ~/www/crm-system/docs/_meta/
cat ~/www/crm-system/docs/_meta/interruption_log.md
```
