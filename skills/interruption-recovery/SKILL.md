---
name: interruption-recovery
description: 4-layer interruption + recovery mechanism for long dev tasks. Auto-save on any interruption, one-command resume with full context restore. Built on top of dev-task-memory state files.
trigger: "interrupt / recovery / resume / 中斷 / 恢復 / 繼續 / 之前 / 上次 / 'where was I'"
version: 1
category: devops
---

# Interruption Recovery

Solve the **#1 pain point of long-running dev tasks**: David takes a break (1 hour / 1 day / 1 week),
then comes back, and the agent has **no idea where they left off**. Without this skill, every
interruption is a fresh start with 30 minutes of context re-explanation.

## 4-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: TRIGGER (any of these starts the recovery flow)      │
├─────────────────────────────────────────────────────────────────┤
│  • Agent / David calls `recovery.sh <project> [reason]`        │
│  • Pre-shutdown hook (gateway SIGTERM, system reboot)           │
│  • Cron-triggered (auto-save every 30 min during long tasks)    │
│  • Manual: David says "save it" / "我收工" / "明天再講"        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: SNAPSHOT (state + session + git)                      │
├─────────────────────────────────────────────────────────────────┤
│  1. Locate active Hermes session (state.db + sessions.json)    │
│  2. Save dev-task-state.md via dev-task-memory/save_state.py    │
│  3. Sync facts to external memory (sync_external.py)           │
│  4. Write docs/_meta/interruption_log.md (audit trail)         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: RESUME COMMAND (3 options for David to pick)         │
├─────────────────────────────────────────────────────────────────┤
│  A. `hermes --resume <session_id>`  — exact context, same line  │
│  B. `hermes --continue "<name>"`    — by session/project name   │
│  C. `hermes --skills dev-task-memory -c "<name>"`              │
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

### `recovery.sh` (中斷前 / 中斷時 run)
```bash
bash ~/.hermes/profiles/developer/skills/interruption-recovery/scripts/recovery.sh \
    crm-system "day 9 frontend handoff 收工"
```
**Output**:
```
✅ State saved. To RESUME, run one of these:

  # A. Resume this specific session (preserves session_id, exact context)
  hermes --profile developer --resume 20260606_215804_0fb627e3

  # B. Resume by project name
  hermes --profile developer --continue "crm-system"

  # C. Start a FRESH session + auto-inject state
  hermes --profile developer --skills dev-task-memory -c "crm-system"
```

### `resume.sh` (David 醒返 / 想 resume)
```bash
# Quick summary + resume command (most common)
bash resume.sh crm-system

# List past sessions
bash resume.sh crm-system --list

# Just show the state file, no action
bash resume.sh crm-system --peek
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
  hermes --profile developer --resume 20260606_215804_0fb627e3
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
| Task 開始 | 紅線 24 | `save_state.py --project X --goal "..."` |
| 30 min / 10 calls | 紅線 25 | re-save + sync_external |
| Session > 50 turns | 紅線 22 | 建議 `/new` (但先 `recovery.sh`) |
| Session stuck in compaction | 紅線 29 | `kick_stuck_session.sh` |
| Agent delegate subagent | 紅線 30 | emit prefix 通知 |
| **中斷 (gateway 關 / 收工 / SIGTERM)** | **紅線 31 (NEW)** | **`recovery.sh` 自動 fire** |
| **David 醒返 / 開新 session** | **紅線 32 (NEW)** | **`resume.sh` / 自動 load state** |

## E2E Test 結果 (2026-06-06 22:05)

```
1. recovery.sh crm-system "second test 22:05"
   ✅ Found active session: 20260606_215804_0fb627e3
   ✅ State file saved: 2783 bytes, 2 files captured, git @ 7dc56d0
   ✅ Interruption log written
   ✅ Resume commands printed

2. resume.sh crm-system
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
| **Cross-machine** | 個 `~/.hermes/memories/dev-task-facts.jsonl` 落 disk, 任何 machine 見到 |
| **Cross-session** | `hermes --resume` 跨 session, `--continue` 跨 name, fresh option 跨 project |
| **Audit trail** | `docs/_meta/interruption_log.md` 記低所有 interruption, 可 grep / review |
| **冇 single point of failure** | state file、git history、external memory、sessions.json、state.db 5 個地方都有 snapshot |

## 4 個 Known limitations (TODO)

1. `sync_external.py` 而家只寫 local jsonl fallback — mem0 / honcho API integration 仲未 implement
2. Agent 第一次入新 session 唔會**自動** load state — David 要主動 run `resume.sh` (或 `--skills dev-task-memory` flag)
3. `recovery.sh` 冇 **pre-shutdown hook** 自動 fire (要手動 run)
4. 3 個 resume option 都係 CLI, 冇 Discord `/resume` slash command

## 🧪 驗證

```bash
# Test the full cycle (E2E)
bash recovery.sh crm-system "test 1"
bash resume.sh crm-system

# Verify file outputs
ls -la ~/www/crm-system/docs/_meta/
cat ~/www/crm-system/docs/_meta/interruption_log.md
```
