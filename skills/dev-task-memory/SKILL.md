---
name: dev-task-memory
description: Concept + recipes for persisting in-progress dev-task state (state file, git checkpoints, WIP detection, handoff docs). Hermes runtime automation retired; platform-neutral references remain valid.
trigger: "context compression / /new / gateway restart / '繼續之前的任務' / 'where were we' / 'save state' / 'checkpoint task' / subagent 做到一半 stop 嘅 WIP / **multi-phase dev task (>30 min, e.g. security review → fix-batch sprint)**"
category: devops
---


Last-verified: 2026-07-28
# Dev Task Memory

> **⚠️ Runtime 自動化已退役（2026-07-25）**：本 skill 嘅 `scripts/` 自動化係為 Hermes runtime 寫嘅，已隨 Hermes 退役刪除（git 歷史可尋）；文中提及嘅 script 命令屬歷史紀錄。Claude Code 用內建 task list / plan mode / session resume 代替自動化部分。本文件保留為 **concept + recipes**：`references/` 同 `templates/` 入面嘅配方（WIP 偵測、恢復後驗證、handoff 文檔、state file 格式等）係平台中立、仍然有效。

解決 David 2026-06-06 hang fix 嘅延伸問題：**context 處理完之後, dev task 點樣唔好被遺忘**。
5-layer architecture 確保 task 嘅 decisions、current state、next steps 全部 persist 喺 file system,
唔靠 LLM memory (會被 compression 清), 都唔靠 user 記住 (不可靠)。

## 5 個 Layer

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: TRIGGER (決定幾時 save)                            │
├─────────────────────────────────────────────────────────────┤
│  • 紅線 21-22 (long task, > 50 turns)                       │
│  • auto-compression event (gateway/run.py hook)             │
│  • gateway restart                                          │
│  • /new slash command                                       │
│  • User explicit "save state" / "checkpoint"               │
│  • **Subagent 做到一半 stop 嘅 WIP** (新 trigger — 2026-06-06)│
│    → working tree 有 untracked / modified files, 跟住用    │
│      `references/subagent-wip-pickup-recipe.md` 嘅 6-step   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: STATE FILE (Single Source of Truth)               │
├─────────────────────────────────────────────────────────────┤
│  ~/www/<project>/docs/_meta/dev-task-state.md:             │
│  - Goal, Decisions (with WHY), Current state, Next steps,   │
│    Risks, Insights, Session lineage, References             │
│  - Gitignored via .gitignore snippet                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: GIT-TRACKED (可審計 + 可 rollback)                  │
├─────────────────────────────────────────────────────────────┤
│  • enable checkpoints: true (Hermes built-in)               │
│  • /rollback N for file rollback                            │
│  • git commit footer 包含 state summary                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: EXTERNAL MEMORY (cross-session fact recall)        │
├─────────────────────────────────────────────────────────────┤
│  • holographic (local, no API key) or mem0/honcho (API)     │
│  • Sync facts (decisions, insights, risks) 落 external store │
│  • Cross-session: 「之前你話用 X 點解?」即時 recall         │
│  • 當冇 external provider, fallback 落                      │
│    ~/.hermes/memories/dev-task-facts.jsonl  <historical 2026-07-25: retired; Claude Code 冇 built-in fallback> │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 5: CROSS-SESSION SEARCH (session_search FTS5)        │
├─────────────────────────────────────────────────────────────┤
│  • 開新 session 自動 search "what was I working on"        │
│  • 注入 top-3 relevant past sessions                        │
│  • <historical 2026-07-25> 用 `hermes sessions list` 找 candidate sessions（退役）│
│  • Claude Code 對應：plan mode + session resume             │
│  • 唔需要 manual session ID 記憶                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 工具腳本

| Script | 用途 | 觸發時機 |
|--------|------|---------|
| <historical 2026-07-25 retired> `scripts/save_state.py` | 退役；state file 仍寫入 `docs/_meta/dev-task-state.md` 但由 Claude Code plan mode + 手動 edit 取代 | Claude Code: plan mode + manual state file edit |
| <historical 2026-07-25 retired> `scripts/load_state.py` | 退役；session resume 改用 Claude Code 內建 `/resume` | Claude Code: `/resume` slash command |
| <historical 2026-07-25 retired> `scripts/sync_external.py` | 退役；external memory 改用 plan mode + context 內 inject | Claude Code: plan mode session context |

## 📂 支援 References

| File | 觸發時機 |
|------|---------|
| `references/subagent-wip-pickup-recipe.md` | Resume 一個 subagent 做到一半停咗嘅 task — working tree 有 uncommitted WIP, 跟住 6-step recipe: snapshot → commit history → read untracked → audit side effects → finish → verify-before-declaring-done。涵蓋 duplicate gitignore entries、batch-fix 嘅 anti-pattern、revert detection 等。 |
| `references/recovery-template-limitation.md` | **Day 11 lesson (2026-06-09)**: `recovery.sh` + `save_state.py` 嘅 generic template 永遠唔 fill 真正 state(Decisions / Files / Next Steps / Risks section 全部係 placeholder)。Resume 之前一定要手動 overwrite `dev-task-state.md`,fill 真正 state。Workaround recipe + root cause analysis + future fix blueprint 全部喺入面。 |
| `references/working-tree-wip-detection.md` | **Day 11 lesson (2026-06-09)**: Agent 同 David 共用 worktree 嘅時候,David 嘅 WIP(modified + untracked) 唔可以入 agent 嘅 commit。Selective `git add <files>` recipe + 3 條新紅線(34-36)+ Day 11 Phase 1 嘅 case study(crm-system 5M + 3?? WIP detection)。 |
| `references/plan-execution-deviation-protocol.md` | **Day 14.7 lesson (2026-06-07)**: Plan JSON 內部矛盾嘅處理 — 揀 primary intent 唔揀 literal text、3 處冗餘紀錄(code comment + commit + report)、anti-pattern(用戶不問照 ship、靜靜 rewrite plan)。Step 6 `/settings` 案例做 worked example。 |
| `templates/handoff-doc-scaffold.md` | **Day 14 lesson (2026-06-07)**: Human-readable handoff doc 嘅 scaffold,用於 `/new` / 收工 / 「之後呢」trigger 嗰陣,Agent 寫一份 David + fresh session agent 兩邊都讀得順嘅 commit-able doc(同 state file 互補)。Section structure 見 §5 嘅 recipe。 |

## 📖 標準使用流程

### 1) 開新 dev task (Plan → Build 開始)

```bash
# 進入 project directory
cd ~/www/crm-system

# 立即 save 一個 fresh state
# <historical 2026-07-25 retired: save_state.py / sync_external.py 退役>
# 改用 Claude Code plan mode + manual state file edit：
#   1. 開 plan mode
#   2. 手動寫 docs/_meta/dev-task-state.md (Decision/Next Steps/Insights section)
#   3. 用 plan mode 嘅 progress tracking
```

Agent 收到 trigger 應該:
1. <historical 2026-07-25 retired: `save_state.py`> 改為：手動 fill `docs/_meta/dev-task-state.md` 嘅 Decisions、Next Steps、Insights section
2. <historical 2026-07-25 retired: `sync_external.py`> 改為：用 plan mode 內 context 取代 external memory push

### 2) Long task 中段 (每 30 min 或每 10 個 tool calls)

Agent 自動 trigger:
```bash
# <historical 2026-07-25 retired: scripts/save_state.py + scripts/sync_external.py 退役>
# Claude Code 對應：plan mode + TodoWrite tracking
# 不再需要 CLI trigger — Claude Code 內建 task list 自動 track
```

呢個確保就算 hang / compression / restart, state 都唔會 lost。

### 3) Context 壓縮 / Hang fix / /new / Restart 後恢復

User send "繼續" / "resume" / "where were we":
```bash
# <historical 2026-07-25 retired: scripts/load_state.py 退役>
# Claude Code 對應：`/resume` slash command 或 `claude --continue "<project>"`
```

Agent 收到 output 後:
1. Read state file content
2. Inject 入 conversation context
3. Resume 跟住 "Next 3-5 Steps" 繼續做

### 3b) Subagent WIP Pickup (新 — 2026-06-06)

Working tree 有 untracked + modified files 由前一個 subagent 留低, 唔係 from compression。
**唔好** call `load_state.py` (冇 state file, 從未 start), **唔好** re-delegate (浪費 70-90% 嘅 WIP)。
跟 `references/subagent-wip-pickup-recipe.md` 嘅 6-step recipe:
1. `git status` + `git diff --stat` snapshot working tree
2. `git log --oneline -10` check partial progress
3. Read untracked / modified files in full
4. Audit side effects (`.gitignore` duplicates, package.json, etc.)
5. Finish from actual pickup point
6. `git log --oneline origin/main..HEAD` empty + clean working tree 為止

### 4) 任務完成

刪除 state file (task done, no need to resume):
```bash
rm ~/www/<project>/docs/_meta/dev-task-state.md
```

或者 archive 落 `docs/retros/YYYY-MM-DD-<task-name>.md`。

### 5) Human-Readable Handoff Doc (Day 14 lesson — 2026-06-07)

**When**: User 話「之後呢」/「我休息下」/「你 stop 啦」/「/new 啦」,Agent 知道下一個 session
會係 David 自己(或者 fresh agent)讀,需要一份 **人類可讀 + 可 commit + 可 grep** 嘅文件。

**唔可以只靠 state file**:
- `dev-task-state.md` 係 gitignored (紅線 28) — 下一個 session 嘅 fresh agent 唔知有呢個 file
- 內容係 machine-optimized,David 讀起上嚟唔順
- 冇 commit 嘅話,different branch / different machine 嘅 agent 攞唔到

**Handoff doc 嘅特性**(同 state file 對比):

| 特性 | `docs/_meta/dev-task-state.md` (state) | `docs/retros/YYYY-MM-DD-<task>-handoff.md` (handoff) |
|------|--------------------------------------|------------------------------------------------------|
| Gitignored | ✅ 紅線 28 | ❌ 正常 commit(可以 PR 一齊) |
| Reader | Machine + Agent | David + 新 session agent + reviewer |
| Format | Structured (Goal/Decisions/Next Steps) | Narrative + TL;DR + resume block |
| Content | Decisions with WHY, current step | Decisions, **uncommitted WIP** (App.tsx diff!), key env vars, first-3-commands |
| Lifetime | 任務期間 | 任務結束後 audit trail(永遠保留) |
| Use case | `load_state.py` resume | `/new` 後手動 read |

**Recipe**(2026-06-07 crm-system handoff 試過 work):

```bash
# 1. 收集 state(15 lines)
cd ~/www/<project>
git log --oneline -8 <branch>
git status --short
git diff --stat <base>..<branch> | tail -5

# 2. 寫 handoff doc (見 templates/handoff-doc-scaffold.md)
# 結構: TL;DR + Branch State + What's Done + What's NOT Done + Key Decisions
#       + Uncommitted Work + Critical Context + First 3 Commands

# 3. Save state(獨立, 唔係 handoff 嘅 substitute)
python3 scripts/save_state.py --project <name> --goal "..." --trigger task-start
python3 scripts/sync_external.py --project <name>

# 4. Verify 兩個 output 存在
ls -la docs/_meta/dev-task-state.md docs/retros/<date>-<task>-handoff.md

# 5. 印 resume command 畀 David(≤ 5 行)
```

**Critical sections that MUST be in handoff doc**(David 試過 miss 嘅):

1. **Uncommitted WIP** — `git diff` 結果(紅線 30 同 recovery 同理)
2. **David 嘅 untracked files** — 永遠唔可以「清理」,必須 list 出嚟
3. **Key env vars / 32-char gate** — 例如 `JWT_SECRET` 32-char hard-fail,新 session 要 re-export
4. **Latent bugs fix 嘅 caveat** — 例如 seed Role/RolePermission 喺 prod 唔存在,新 endpoint 會 403
5. **First 3 commands** — `cd` + `load_state.py` + start dev
6. **Routing / runtime invariants** (新 — 2026-06-07 lesson) — 當 step commit 包含
   order-dependent routing(sibling route conflict 嗰類)但 smoke test 留到 ship step,必
   須喺 handoff doc 開獨立 sub-section,寫低「聲稱嘅行為 + 點 verify」。TS pass ≠
   runtime pass。詳見 `skills/frontend/react-router-v7-patterns/SKILL.md`(sibling route shadowing pattern)。

**Pitfall**: 唔好將 handoff doc 寫到 `docs/_meta/`,會被 gitignore + 失去 audit trail 嘅 purpose。
**Pitfall**: 唔好 overwrite 已經有嘅 `docs/retros/YYYY-MM-DD-<task>.md` retro file — handoff 係
*中斷* 嘅 trail,retro 係 *完成* 嘅 trail,兩者 timing + content 唔同。

## 🔄 同 Hermes 內建功能嘅整合

| Hermes feature | dev-task-memory 用法 |
|----------------|---------------------|
| <historical 2026-07-25> `hermes --resume <id>` / `-c "<name>"` | 退役；Claude Code 對應：`/resume` slash command + state file Session Lineage |
| <historical 2026-07-25> `hermes checkpoints` (filesystem) | 退役；Claude Code 對應：git checkpoint commit |
| <historical 2026-07-25> `hermes memory status` | 退役；Claude Code 對應：env-based provider selection |
| `session_search` (FTS5) | Layer 5 `load_state.py --search-sessions` 用佢 |
| `/rollback N` | Layer 3 file rollback 配 state file restore |

## ⚠️ 紅線 (跟 SOUL.md 紅線 24-28 對齊)

- **紅線 24**:**每次 long task 開始必須 `save_state.py`**, 唔可以 rely on LLM memory
- **紅線 25**:**每 30 分鐘或 10 個 tool calls 必須 re-save** (Layer 1 自動 trigger)
- **紅線 26**:**Decision 必須有 WHY** — 唔可以淨寫 "Use Hono", 要寫 "Use Hono 4x 細, edge 啱用"
- **紅線 27**:**Resume 時必須先 `load_state.py`**, 唔可以假設自己記得
- **紅線 28**:**State file 唔可以 commit 落 git** — `docs/_meta/*` 必須喺 .gitignore
- **紅線 33**:**Resume 之前必 check `dev-task-state.md` 唔係 generic template**(Day 11 lesson)。
  Generic template 嘅 signals:有 `<Decision 1>` / `<Risk 1>` / `**待填寫**` / 全部 file
  都係 `M (now)` 冇真實 file path。Hit 任何一個 → 手動 overwrite 真正 state 先 resume。
  詳見 `references/recovery-template-limitation.md` 嘅 workaround recipe。
- **紅線 34**:**Sibling subagent 並行 edit 同一 file 時必 check 雙方最後 diff 唔 overlap**(Day 14.7 lesson)。
  Patch tool / write_file 撞到 warning "modified by sibling subagent" / "last read with
  offset/limit pagination" → 唔好盲改。Recipe: (1) `git diff <file>` 睇 sibling 改咗邊段;
  (2) 自己嘅 patch 區段同 sibling 嘅 patch 區段**唔可以重疊**; (3) 如重疊(regex region 撞
  共同 functions / interfaces),手動 merge 兩邊嘅改動,唔好 `git add` + commit 直接撞;
  (4) Commit message 寫低「conflict-free with sibling X 嘅 Y 改動」。詳見
  `references/sibling-subagent-concurrent-edit-recipe.md`(待建)。
- **紅線 35**:**Tying two patches to the same commit when they're in different
  sub-trees is safe; the dangerous case is two patches both touching the
  same function body or interface declaration.** Quick test before committing
  sibling-collision files: `git diff <file> | grep -E "^[+-]" | sort | uniq -c
  | sort -rn | head -20` — any line that appears as both `+` and `-` is a true
  merge conflict, not just proximity.

## 🛠️ 設定 (.gitignore snippet)

每個 project 嘅 `.gitignore` 加:
```gitignore
# dev-task-memory — runtime state, not source
docs/_meta/
dev-task-state.md
```

## 🧪 驗證指令

```bash
# 1. Save state
python3 scripts/save_state.py --project crm-system --goal "Test" --trigger "manual"

# 2. Sync to external
python3 scripts/sync_external.py --project crm-system

# 3. Read back
python3 scripts/sync_external.py --read --project crm-system

# 4. Search
python3 scripts/sync_external.py --search "Prisma"

# 5. Load (resume)
python3 scripts/load_state.py --project crm-system --search-sessions
```

## 📚 配合其他 skills

- `context-summarizer` (existing): 自動每 30 分鐘壓 context。dev-task-memory 補佢嘅缺點 — 壓咗之後 decisions 唔會 lost
- `regression-guard` (existing): 防舊 bug 翻發。state file 嘅 Risks section 配 RG-XXX
- `auto-doc-gen` (existing): 自動生成 API doc。state file 嘅 Decisions 配 doc rationale

## 🐛 已知限制

- **`save_state.py` 嘅 "extract decisions from session"** 而家係 stub — TODO: integrate with hermes_state.py (<historical 2026-07-25 retired>) 讀真正 session DB
- **External memory provider (mem0/honcho)** API call 仲未 implement — 而家 fallback 落 local jsonl
- **Holographic** provider 雖然係 local-only 但需要 config, 默認未啟用 — 可以之後 setup
- **State file 唔會 auto-update** — 必須人手 call save_state.py
  (將來可以做 background curator 自動 trigger)
- **`memory` tool round-trip drift guard (2026-06-19 lesson)** — Hermes 嘅 `memory(action='add')` 會 refuse write 當 `<profile-root>/memories/MEMORY.md` 有 manual edit / shell append / patch tool 嘅 content 唔可以 round-trip through `memory()` call。**Detection**: error message 提 "MEMORY.md.bak.<timestamp>" + "Resolve the drift first — either rewrite the file as a clean §-delimited list of entries, or move the extra content out"。**Resolution recipe**:
  1. `cat <profile-root>/memories/MEMORY.md.bak.<timestamp>` 拎 backup
  2. Manual integrate missing entries into clean §-delimited list (one at a time via `memory(action='add', content='...')`)
  3. Remove or rewrite original MEMORY.md to clean state
  4. Retry `memory(action='add')`
  
  **唔可以** force overwrite — guard 嘅存在係防止 silent data loss (Hermes issue #26045)。**唔可以** retry 5 次(浪費 token + 撞同一個 error)。**Lesson codification**: 如果個 lesson 必須 persist 但 memory tool 拒絕,fallback 落 skill(SKILL.md body)或者講畀 David 知要人手 sync。

## 🆕 Plan Z — Mid-Handoff Single-Step Commit Cycle (2026-06-07)

**Trigger**: User has multi-step work (≥5 steps) remaining, session has hit 紅線 22 (>50 turns)
or 紅線 19 (tool-call noise from earlier hang). **3 paths to offer**, ordered by safety:

| Path | Description | Hang risk | /new cycles | Total wall time |
|------|-------------|-----------|-------------|-----------------|
| **X** (Inline all) | Do every step in this session, accept hang | High (≥1 hang mid-run) | 0 (until forced) | 4-5 hr + 1 unplanned handoff |
| **Y** (Inline half) | Do first N/2 steps, then /new handoff | Medium | 1 planned | 4-5 hr, 1 clean checkpoint |
| **Z** (1-step cycles) | Do exactly 1 step + commit + handoff + /new, repeat | ~Zero per cycle | 1 per step | 4-5 hr, multiple clean checkpoints |

**User pick pattern observed**: David, when offered Z, replied "Z" within 1 turn. The deciding
factor was **proven hang history that session** (今朝 6 點 3 小時 hang, 47-78 API calls stuck).
When user has been burned by hang already, they prefer many small clean cycles over inline sprint.

**Plan Z execution recipe** (tested on crm-system 2026-06-07 Step 5):

1. **Scope the next single step only** — read handoff doc, pick the smallest step with concrete
   file paths (e.g. "Step 5: routes + API client", not "Step 5-8: all frontend").
2. **Execute in ≤20 tool calls** — hard budget. If you cross it, stop and handoff what you have.
3. **Verify locally** — `tsc --noEmit`, `git status --short`, type check. Defer browser/E2E
   smoke to the final ship step (Step 12 of the original plan).
4. **Commit + push** — single commit, descriptive footer pointing to next step.
5. **Update handoff doc + state file** — re-stamp the "What's Done" section with the new commit,
   mark the step as done in the "What's NOT Done" table.
6. **Emit "📍 progress" + explicit `/new` recommendation** — let user run /new themselves.
   Don't auto-/new (user has the shortcut key).
7. **Tool-call budget enforcement**: if a step needs >20 calls, split it across 2 cycles BEFORE
   starting, not mid-cycle.

**Pitfall — routing conflict undetected** (saw in 2026-06-07 crm-system Step 5): When adding
sub-routes that share a prefix with a legacy top-level route (e.g. `/settings/*` + `/settings`),
**react-router v6 picks most-specific match** but the build-time types don't catch this — you
need browser smoke. Plan Z defers that to Step 12, so document the routing invariant in the
handoff doc explicitly so the smoke step knows what to verify.

**Pitfall — TS-only verification is not enough**: `tsc --noEmit` passes for valid route trees
that silently shadow each other at runtime. Treat the routing invariant claim in the handoff
doc as a *prediction to be tested*, not a guarantee.

**Why Z beats the 紅線 21 fallback** (`delegate_task` to subagent): Z keeps the work in the
main session lineage (so cross-session search, state file, retro doc all stay coherent). Subagent
isolation (紅線 21) is better when you need to *escape* the main session context budget; Z is
better when the work is *progressing fine* and you just need a clean checkpoint.

**When NOT to use Z**: trivial 1-shot tasks (just do it inline), tasks with hard external
dependencies that won't survive a /new (e.g. holding an SSH tunnel), or tasks where the user
explicitly says "do it all in one go".

## 🔴 反例 — 2026-06-07 crm-system code review + P0 fix sprint 漏 call save_state.py

**情境**:David 嗌我做「CRM code review (A+B+C) → 開 P0 security fix sprint」,我整咗 12-todo list + 7 commits + evidence report,**全程冇 call `save_state.py`**。最終冇 data loss(全部 commit 落 git),但中間有 2 個高風險 moment:

1. **改 auth.ts register endpoint 嘅時候**第一次寫錯咗 `_actorId` 嗰個 hack(routes 唔應該 pass 內部 data via body)。如果有 state file 紀錄「auth.ts P0-1: requirePermission('user:create') 嗰度 getUserIdFromRequest 嘅 helper 應該點用」,第二次 patch 就唔會走歪路。
2. **Bun `--env-file` 喺 smoke test 撞 shadowing** — 2-3 次 attempts 浪費。State file 嘅 Insights section 寫低「Bun 嘅 env-file 做 floor, 唔可以 shell override」就唔需要再 re-discover。

**Lesson**:**任何 > 30 min 嘅 multi-phase dev task 必須喺 Layer 1 trigger 嗰度 fire**。即係:

- 用戶話「做 A + B + C」→ 即刻 `save_state.py --goal "A + B + C" --trigger task-start`
- 中段每 30 min / 每 10 tool calls → `save_state.py --trigger auto-mid-task` + `sync_external.py`
- Sprint end → 寫 `docs/retros/YYYY-MM-DD-<task>.md` 後,`rm docs/_meta/dev-task-state.md`(task 完了)

**Skip 嘅後果**:compression / /new 之後要 re-discover 同一個 Bun env shadowing pitfall、或者重寫同一個 `_actorId` hack,等於 burn 5-10 min 嘅 tool calls。

**新增紅線 37**:**multi-phase dev task (>30 min, 3+ todos) 必須 task-start 即 call save_state.py**。同紅線 24 對齊(任何 long task 開始必須 save),但 spec 出嚟:唔淨止「long」,要「multi-phase」 — 即 todo list 有明確 phase boundary(Think/Plan/Build/Review/Test/Ship)嘅 task。

---

## 🔴 反例 2 — 2026-06-07 crm-system Day 14.7 Plan → Build 過渡 wire-shape drift (Step 5 → Step 7)

**情境**:Day 14.7 System Settings refactor + Tax Rate feature 嘅 multi-phase plan(Steps 5-12,有 Plan doc + 3 個 options 嘅 ADR)。Step 5(commit `eb1581f`)寫 frontend `settingsApi.getTax/putTax` wrapper 嘅時候,**直接跟 Plan JSON doc 嘅 wording 用 `defaultTaxRate` 做 wire field name**。但 plan doc 同 backend actual route handler(`apps/api/src/routes/settings.ts`)唔同步 — backend 用 `rate` 做 field name(GET response + PUT body 兩邊都係)。PUT runtime 一定 400 Zod validation error,**用戶零實機 catch 唔到**。

**根因**:
1. Plan doc 嘅 `description` field 寫「Default tax rate (%)」,field name 我哋 plan 階段咁就命名 `defaultTaxRate`(亦合理 readable)
2. Backend dev 直接 implement `prisma.systemConfig.upsert({ data: { value: rate } })`,response 用 `rate` 短名(亦合理)
3. Plan 階段冇人 grep backend source code verify actual wire shape
4. Frontend wrapper commit 嗰陣冇 e2e 過(我喺 commit message 寫「smoke test deferred to Step 12」,紅線 — 紅線 12/16 講 P0 US 必須 Unit+Integration+E2E 三層,但呢個算「wire format bug」唔係 US)

**第 7 步先 catch** 因為 Step 7 寫實際 settings-tax.tsx 嘅 wire call 嗰陣,grep backend route handler 確認 actual wire shape,發現 `defaultTaxRate` 根本唔存在於 backend response。Commit `bd1d107` fix 咗 TaxConfig interface + putTax payload。

**Lesson + 新增紅線 38**:**Plan → Build 過渡期 wire-shape verification**(適用於所有 plan-then-build multi-step task,尤其涉及 backend ↔ frontend contract):
- Step N wrapper commit 之前,grep backend actual handler 確認 wire field name + shape(record 喺 Insights section 嘅 state file)
- Plan doc 嘅 `description` / 變量名係 *人話* 命名,backend 嘅 field name 係 *code* 命名,**唔可以假設 1:1**
- Plan doc 有「Options A/B/C 決定」但冇記 wire shape 嘅 section → 自己加,喺 Plan stage commit 嗰陣 grep 一次 backend
- Build stage 寫 wrapper 嗰陣,跟 backend source 唔跟 plan doc(紅線:「按後端 source code 為最終依歸」)

**Prevention recipe**(`skills/software-development/frontend-backend-integration/SKILL.md` 有詳細 recipe + case study):
1. Plan stage 寫完 doc → `git grep` backend route / zod schema → 對齊 wire field name
2. Plan doc 開一個 "Wire shape (verified against backend)" section 記低 `GET /x → { fieldA, fieldB }` / `PUT /x body → { fieldA }`
3. Build stage wrapper commit 之前再 grep 一次(backend 可能 plan stage 之後改咗)
4. 第一次實際 wire call 嘅 commit(典型係「實作第一個 page 嗰個 step」),commit 之前 5-min smoke(就算冇 full E2E 都要 curl 一次 GET 200 確認 field name)

**反例損耗**:Step 5 wrapper 寫錯 → Step 7 catch → commit `bd1d107` fix 浪費 1 commit boundary 但冇 runtime disaster(因為 spec 寫「Step 12 smoke test 先驗」,未到 user)。如果 David Day 14 開個新 tab 直接 trigger `putTax` 就會 400 — 但 Plan 範圍冇 expose settings UI until Step 7,所以零 user-facing impact。**Prevention 嘅 ROI 唔係「災難避免」,係「淨 commit boundary」+「plan doc 嘅 wire-shape section 對日後 audit 有用」**。

---

## 📐 Reusable sub-route + tab navigation recipe(Day 14.7 Step 6-8 印證)

當 plan 揀咗「option A — 一個 URL 切換」嘅 Tabs pattern(對應常見嘅 admin → settings → sub-tab 重構),`templates/shadcn-tabs-wrapper.tsx` 係 known-good starter。常見陷阱:

1. **Radix `<Tabs>` controlled mode 配 NavLink → warning**。每個 `<TabsTrigger>` 必須有對應 `value` 同 active trigger 配對;直接 NavLink 入 `<TabsList>` 會 trigger Radix warning "missing trigger"。**Pick B**:`TabsTrigger` + `onClick={() => navigate('/settings/' + value)}` 失去 middle-click open-in-new-tab,但避 warning。
2. **Layout 包 page 之後 double-header**。Page 本身 render 自己嘅 `h1` + 自製 button-tab strip → Layout 又 render → 視覺垃圾。Step 6 整 layout 嗰陣順手清 page 內部 chrome(寫埋 Step 8 extract 嘅 plan)。
3. **Legacy route URL 保留**。`<Route path="/old"><Navigate to="/new" replace /></Route>` 做 backward-compat 5-10 個 redirect 一次過加,bookmark/email link 唔會死。
4. **Query-string 預填 filter 嗰啲 page**。例如 audit page 接受 `?action=SYSTEM_CONFIG_UPDATED` 從 settings 跳過來即 filtered → 入 page 嗰陣 `useSearchParams()` 攞 initial state,1-2 行 code。

**詳細 wire-shape recipe + sub-route/tab patterns** 喺 `skills/software-development/frontend-backend-integration/SKILL.md`(及其 `references/url-driven-tabs.md`、`references/layout-refactor-chrome.md`)。

## 📝 E2E test result (2026-06-06)

- Save: 2715 bytes 寫入 `~/www/crm-system/docs/_meta/dev-task-state.md`
- Edit: 2 decisions + 1 insight injected
- Sync: 4 facts → `~/.hermes/memories/dev-task-facts.jsonl` (<historical 2026-07-25 retired>)
- Read: 4 facts loaded back ✓
- Search: "Prisma" → 1 hit ✓
- Load: state file full render ✓

### Subagent WIP Pickup test (2026-06-06)

- 入口: User send "現在繼續做" + `git status` show 1 untracked + 2 modified
- Recipe: 6 steps, ~15 min total
- 結果: 1 commit (`7dc56d0`), push 成功, `git log --oneline origin/main..HEAD` empty
- 節省 vs re-delegate: ~15 min (WIP 95% correct, 淨係 consumer page wiring 缺)
- 新增 lessons: audit `.gitignore` for subagent duplicates, batch-fix noise 喺獨立 commit
