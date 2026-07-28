---
name: interruption-recovery
description: Concept + recipes for recovering long dev tasks after interruption (post-recovery verification, context reconstruction from git, smoke-before-merge). Hermes runtime automation retired; platform-neutral references remain valid.
trigger: "interrupt / recovery / resume / 中斷 / 恢復 / 繼續 / 之前 / 上次 / 'where was I' / '開工吧' / '您開工吧'"
category: devops
applicability: operational
---

Last-verified: 2026-07-28

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
| **中斷 (gateway 關 / 收工 / SIGTERM)** | **紅線 31** | **<historical 2026-07-25 retired: `recovery.sh` 自動 fire>** 改為：Claude Code 自動 persist session state |
| **David 醒返 / 開新 session** | **紅線 32** | **<historical 2026-07-25 retired: `resume.sh`>** 改為：`/resume` slash command |

## Recipe: Pre-existing Uncommitted Sprint Detection (5 步, 20 秒)

**情境**: David send「做 X」+ working tree 有大量 changes = re-prompt of uncommitted sprint (前個 session 嘅 agent 做咗 implementation + draft retro doc + verify 過 test 但冇 commit)。

**Anti-pattern**: Agent 見到 `git status` non-zero 之後 default 反應係「**從零 implement**」,會撞 (a) duplicate work, (b) confused by interleaved hunks, (c) blow 走 existing logic。**正確反應係「verify + commit + push」**。

**Detection recipe**:

```bash
# 1. Working tree size
git status --short | wc -l          # > 0 = work in progress
git diff --stat | tail -1           # "+X -Y" 總 change footprint

# 2. US markers in +lines
git diff | grep -E "^\+.*Sprint [0-9]+ US-|^\+.*US-[0-9]+\.[0-9]+"
# Hit 喺 +lines = work 喺度加,唔係移走

# 3. In-flight retro doc
ls docs/retros/$(date +%Y-%m-%d)-*.md 2>/dev/null
# 出現 untracked retro doc = 上一個 session 留低嘅 draft

# 4. Tests pass 唔 pass
cd backend && <runner> 2>&1 | tail -3
# "N pass 0 fail" + worktree 有 changes + retro doc = ship pre-existing uncommitted sprint

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

**完整 recipe + worked example + anti-pattern list**:
`references/post-recovery-verification.md` § Recipe D

**David 嘅「做 X」cue 解讀**:
- 「做 X」+ working tree 有大量 changes = re-prompt of uncommitted sprint
- 「做 X」+ clean working tree = implement from scratch (正常 flow)
- 「修 X」「ship X」同樣 rule
- **永遠先 `git status` + `git diff` 30 秒 verify**,唔好 assume clean start

---

## Recipe: `git status --short` Panic-Decision Pitfall (6 步)

`git status --short` 嘅 output 唔等於 reality:

1. **Stale terminal buffer / 中斷嘅 state-cache**: 特別係 session 過夜 / context 重啟後第一次跑 `git status --short`, 有時 return 之前 session 嘅 partial output。**解決**: 跟 `git status` (no args) 嘅 "On branch / working tree" 兩行為 single source of truth。
2. **Porcelain v1 嘅 X vs ?**: `A` (staged add) + `A` (intend-to-add) + `M` (modified) 混埋, 短 porcelain 唔分 `MM` (staged + modified), 第一眼以為要處理但其實已經 tracked。
3. **David 自己 untracked 嘅 file 冇 `git add`**: worktree 出現 untracked 時, panic-react 反而會 introduce "agent 闖入 David WIP" 嘅問題。

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

---

## Recipe: Reconstruction when state file is generic template (4-source)

`save_state.py` stub `detect_decisions_from_session()` (<historical 2026-07-25 retired>) 仲未 implement, `replace()` 嘅 placeholder 命中率低 → 寫出嚟嘅 `dev-task-state.md` Goal/Decisions/Next Steps 全部係 `<placeholder>`。Resume agent 以為冇 context,實際係要 *look harder*。**4-source 重建 sequence**:

1. `git log --oneline -20` + `git status` + `git log origin/main..HEAD` (red-line 33 revert check) → 知道做咗咩
2. `session_search(query="<project> Day <N> <key-term>")` (FTS5 multi-keyword + quote) → 拎 bookend_start / bookend_end (5 sessions max, ±5 messages per match)
3. `cat docs/_meta/interruption_log.md` → audit trail of save events
4. **David 嘅 last message** — single-letter (`A`/`B`/`C`/`X`)、`好`、`B吧`、ship cue (`recovery` / `Zombie?` / `停`) → **直接 execute,唔好再問**

**輸出**:📍 Resuming <project> 段 + Goal (1 句) + Current state (HEAD + branch + working tree) + Decisions (max 5) + Open question (如果有) + Next 3-5 steps (concrete, file path) + Risks。

**5 tool calls** 完成 reconstruction vs 30+ 問 David 重述。詳細 recipe + worked example:
`references/reconstruct-context-from-git-and-sessions.md`

**何時 recipe 失敗**:1 個禮拜後、多 task 並行、last message 模糊 → 問 1 條 clarifying question,3-4 options 錨住最 likely 嘅 next action。**唔好重新問上一個 session 已經問過嘅 Q** — 答案已經喺度。

## Recipe: Post-Recovery Verification (3 unstated prod-deploy-killers)

`resume.sh` 攞返 state + verify git log 之後,**仲有兩個 prod-deploy-killer
唔 surface 喺 git / state / standard smoke output 入面**:

1. **Untracked providers** — HEAD 已 commit `import { X }` 但 `X` 嘅 file 仲 untracked。Dev build OK (Vite 攞 working tree), prod `git pull` 必 BUILD FAIL (tracked tree 冇 X)。
2. **Stale Docker image bundle** — `docker ps` 顯示 `Up (healthy)` 唔等於 bundle 包含最新 source。

兩個嘅 detection recipe + fix command:**`references/post-recovery-verification.md`**
(§A untracked providers, §B stale bundle, **§C stale stash detection**)。跑完 `resume.sh` 之後、claim "ready to ship / merge / PR" 之前跑, **Recipe C 必須喺 `git stash pop` 之前跑** — 30 秒 save 一次 prod build fail + working-tree landmine。

## Recipe: Smoke-before-Merge Flow (4 phases)

Recipe A + B 解決咗 "verify 唔 surface 嘅 problem" 之後,PR ready 嘅 **standard answer 由 "I smoke 過 dev" 升級做 trunk-based 4-phase flow**:

```
Phase 1: Pre-merge  ── dev host
  1a. 1-click commit untracked providers  (`templates/commit-untracked-files.sh`)
  1b. 1-click push to origin                (`templates/push-after-commit.sh`)

Phase 2: Staging smoke ── staging host
  2a. checkout branch + pull + rebuild
  2b. apply prisma migrate deploy + status  (防 P3009 drift)
  2c. run 14-step E2E smoke                 (`templates/smoke-before-merge.sh`)
  2d. if smoke FAIL → DO NOT MERGE, 回到 Phase 1 fix

Phase 3: Merge ── dev host
  3a. `git checkout main && git merge --no-ff <branch> && git push`

Phase 4: Prod deploy ── prod host (紅線 4,完全留 David)
  4a. `git pull origin main`
  4b. <migration command>
  4c. <seed command>  (RBAC re-seed)
  4d. <rebuild command>  (rebuild image with new source)
  4e. post-deploy smoke: N tabs 200 / round-trip / bundle 含 new feature string
```

**Hermes-redact pitfall (class-level, 所有 E2E smoke script 都撞)**: 寫 `Authorization: Bearer $JWT` 喺 shell 嗰陣 Hermes 嘅 secret-detection 會 replace 個 `$JWT` literal 變 `***`(就算 `$JWT` 係 shell variable 都食), result = curl call 全部用空 token → smoke 100% fail。Fix pattern: `"B" + "earer "` string concat + `/tmp/jwt.txt` file-based token。詳細 template 同 pitfall 解釋:`references/e2e-smoke-script-authoring.md`。

**完整 4-phase 流程 + 3 script 設計 + 點解 smoke-before-merge 重要**:`references/smoke-before-merge-flow.md`。

## Recipe: Generic Template Limitation

`recovery.sh` 嘅 Step 2 跑 `save_state.py`,但個 script 嘅 `detect_decisions_from_session()` 係 stub(永遠 return `[]`),絕大部分 template `replace()` call 又 miss 個 placeholder (只 hit `branch` / `commit` / `uncommitted changes` 嗰 3 個)。結果:**寫出嚟嘅 `dev-task-state.md` 係 generic template**,Decisions / Files / Next Steps / Risks section 全部係 `<placeholder>` 或 `**待填寫**`。

影響:
- Resume 個新 session agent 讀個 state file,完全失憶
- `load_state.py` 嘅 output 看似正常但內容係空

Mitigation:
- `recovery.sh` Step 2 之後印 "⚠️ Generic template" block
- 對應 file: `dev-task-memory/references/recovery-template-limitation.md` 嘅 workaround recipe

## 同其他 skills 嘅關係

- **`dev-task-memory`** (核心) — 5-layer state persistence。interruption-recovery 喺佢上面 build 自動化。
- **`regression-guard`** (existing) — 防舊 bug 翻發。interruption_log.md 配 RG-XXX ID 方便 audit。
- **`dev-checker-loop`** — fresh session 嘅 runtime 上下文管理，shared 用 session resume + state file patterns。

## 🔒 設計保證

| 特性 | 實作 |
|------|------|
| **Crash-safe** | state file 喺 `docs/_meta/` (gitignored) 每次 save 寫完整 markdown, 唔會 partial write 變 corrupted |
| **Cross-machine** | 個 state file 落 disk, 任何 machine 見到 |
| **Cross-session** | `/resume` slash command 跨 session, `/resume "<name>"` 跨 name, fresh option 跨 project |
| **Audit trail** | `docs/_meta/interruption_log.md` 記低所有 interruption, 可 grep / review |
| **冇 single point of failure** | state file、git history、external memory、session state 4 個地方都有 snapshot |

## 4 個 Known limitations (TODO)

1. `sync_external.py` 只寫 local jsonl fallback — mem0 / honcho API integration 仲未 implement；Claude Code 唔需要 — session context 自動 persist
2. `resume.sh` flag → 改為 `claude --continue "<project>"` 或 `/resume` slash command
3. `recovery.sh` 冇 pre-shutdown hook 自動 fire → 改為 Claude Code settings.json Stop hook
4. 3 個 resume option 都係 CLI, 冇 Discord `/resume` slash command

## References (worked examples)

- `references/post-recovery-verification.md` — Recipe A (untracked providers), B (stale bundle), C (stale stash detection), D (pre-existing uncommitted sprint detection).
- `references/reconstruct-context-from-git-and-sessions.md` — 4-source reconstruction recipe + worked example.
- `references/smoke-before-merge-flow.md` — 4-phase flow + 3 script designs + the smoke-before-merge rationale.
- `references/e2e-smoke-script-authoring.md` — Hermes-redact-safe JWT handling pattern.
- `references/compression_subagent.md` — context compression subagent pattern (originally a Hermes feature).