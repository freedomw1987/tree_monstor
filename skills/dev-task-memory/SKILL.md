---
name: dev-task-memory
description: 5-layer persistent memory for in-progress dev tasks — survives context compression, /new, gateway restart. State file + git checkpoints + external memory + cross-session search.
trigger: "context compression / /new / gateway restart / '繼續之前的任務' / 'where were we' / 'save state' / 'checkpoint task'"
version: 1
category: devops
---

# Dev Task Memory

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
│    ~/.hermes/memories/dev-task-facts.jsonl                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 5: CROSS-SESSION SEARCH (session_search FTS5)        │
├─────────────────────────────────────────────────────────────┤
│  • 開新 session 自動 search "what was I working on"        │
│  • 注入 top-3 relevant past sessions                        │
│  • 用 hermes sessions list 找 candidate sessions           │
│  • 唔需要 manual session ID 記憶                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 工具腳本

| Script | 用途 | 觸發時機 |
|--------|------|---------|
| `scripts/save_state.py` | Save 當前 dev task state 落 `docs/_meta/dev-task-state.md` | Layer 1 trigger fires 佢 |
| `scripts/load_state.py` | Read state file + 注入 context (for resume) | New session / /new / after-compression / after-restart |
| `scripts/sync_external.py` | Extract facts → push to external memory (or local fallback) | 每次 save_state 完之後 fire |

## 📖 標準使用流程

### 1) 開新 dev task (Plan → Build 開始)

```bash
# 進入 project directory
cd ~/www/crm-system

# 立即 save 一個 fresh state
python3 ~/.hermes/profiles/developer/skills/dev-task-memory/scripts/save_state.py \
    --project crm-system \
    --goal "實作 Companies 編輯頁加聯繫人 sub-row" \
    --trigger "task-start"
```

Agent 收到 trigger 應該:
1. 立即 call `save_state.py`
2. Fill in `docs/_meta/dev-task-state.md` 嘅 Decisions、Next Steps、Insights section
3. Call `sync_external.py` push facts 落 external memory

### 2) Long task 中段 (每 30 min 或每 10 個 tool calls)

Agent 自動 trigger:
```bash
python3 scripts/save_state.py --project crm-system --trigger "auto-mid-task"
python3 scripts/sync_external.py --project crm-system
```

呢個確保就算 hang / compression / restart, state 都唔會 lost。

### 3) Context 壓縮 / Hang fix / /new / Restart 後恢復

User send "繼續" / "resume" / "where were we":
```bash
python3 scripts/load_state.py --project crm-system --search-sessions
```

Agent 收到 output 後:
1. Read state file content
2. Inject 入 conversation context
3. Resume 跟住 "Next 3-5 Steps" 繼續做

### 4) 任務完成

刪除 state file (task done, no need to resume):
```bash
rm ~/www/<project>/docs/_meta/dev-task-state.md
```

或者 archive 落 `docs/retros/YYYY-MM-DD-<task-name>.md`。

## 🔄 同 Hermes 內建功能嘅整合

| Hermes feature | dev-task-memory 用法 |
|----------------|---------------------|
| `hermes --resume <id>` / `-c "<name>"` | state file 嘅 `Session Lineage` section 寫低 resume command |
| `hermes checkpoints` (filesystem) | Layer 3 自動 enable, 唔需要額外 config |
| `hermes memory status` | Layer 4 查 active provider |
| `session_search` (FTS5) | Layer 5 `load_state.py --search-sessions` 用佢 |
| `/rollback N` | Layer 3 file rollback 配 state file restore |

## ⚠️ 紅線 (跟 SOUL.md 紅線 24-28 對齊)

- **紅線 24**:**每次 long task 開始必須 `save_state.py`**, 唔可以 rely on LLM memory
- **紅線 25**:**每 30 分鐘或 10 個 tool calls 必須 re-save** (Layer 1 自動 trigger)
- **紅線 26**:**Decision 必須有 WHY** — 唔可以淨寫 "Use Hono", 要寫 "Use Hono 4x 細, edge 啱用"
- **紅線 27**:**Resume 時必須先 `load_state.py`**, 唔可以假設自己記得
- **紅線 28**:**State file 唔可以 commit 落 git** — `docs/_meta/*` 必須喺 .gitignore

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

- **`save_state.py` 嘅 "extract decisions from session"** 而家係 stub — TODO: integrate with hermes_state.py 讀真正 session DB
- **External memory provider (mem0/honcho)** API call 仲未 implement — 而家 fallback 落 local jsonl
- **Holographic** provider 雖然係 local-only 但需要 config, 默認未啟用 — 可以之後 setup
- **State file 唔會 auto-update** — 必須人手 call save_state.py
  (將來可以做 background curator 自動 trigger)

## 📝 E2E test result (2026-06-06)

- Save: 2715 bytes 寫入 `~/www/crm-system/docs/_meta/dev-task-state.md`
- Edit: 2 decisions + 1 insight injected
- Sync: 4 facts → `~/.hermes/memories/dev-task-facts.jsonl`
- Read: 4 facts loaded back ✓
- Search: "Prisma" → 1 hit ✓
- Load: state file full render ✓
