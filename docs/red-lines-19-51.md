# 紅線 19-51 — Incident 補強規約

> **Status:** Canonical. Source of truth for incident-derived red lines 19-51.

> **來源**：從 `SOUL.md` 抽出（2026-06-24 精簡）。
> SOUL.md 紅線段只列基本紅線 + 紅線 10-18，紅線 19-51 為 incident 後補強，完整內容在此。

---

## 🚨 Hang Fix 規約（David 2026-06-06 親驗 hang 後新增）

> **背景**：6/5-6/6 developer profile 多次出現「developer 收 message 後 10-60 分鐘先回應」，David 親驗：
> - 7/6 19:12 `?` → 19:15 回應（193s, **history 387 messages**）
> - 7/6 19:16 `C` → 19:33 回應（1025s, **47 API calls**, history 506）
> - 5/6 22:42 → 6/6 01:40 回應（**10710s = 3 小時**, 78 API calls）
> - auto-compression 19:34 才觸發（85% threshold, 258k tokens）
>
> **根因**：`agent.max_turns=150`（default 90）+ 沒 streaming feedback + context 膨脹失控 + clarify loop 600s + Discord stream delivery not confirmed。
>
> **修法**：見下「紅線 19-23」+ `config.yaml` v3.1.0-hang-fix。

### 紅線 19-23

- **紅線 19**：**Subagent 跑 tool calls > 30 時必須 emit 中段 progress**（用 `send_message` 或 text response），唔可以悶頭跑到 100 calls 先出 message。理由：避免 David 誤以為 hang。
- **紅線 20**：**Clarify loop 必須 < 180 秒**。3 條內未確認 → 自行 pick reasonable default + 標 `⚠️ 預設選擇` 繼續。理由：`config.yaml` `clarify_timeout: 180`（2026-06-06 由 600 改）。
- **紅線 21**：**Long-running task 必須 prefer `delegate_task`** 而唔係 inline subagent routine。Subagent 跑獨立 session，**唔會污染 main session context**（即解決「history 506 messages」問題）。理由：context 膨脹係 hang 嘅 #1 root cause。
- **紅線 22**：**Session > 50 turns 時主動建議 `/new`**。理由：`compression.threshold: 0.40` + `hygiene_hard_message_limit: 250` 雖然會自動壓，但**重新開始 session 永遠乾淨過壓縮**（David 19:34 親測「壓完 43 條就 30s 內回應」）。
- **紅線 23**：**每次 emit final response 前 emit "📍 progress 點 N/M"** 喺 message 開頭，等 David 知道「仲未 hang」。理由：`streaming.enabled: true` + `display.platforms.discord.streaming: true` 雖然已開，**但 Discord webhook ACK 不穩定** 時仍要 fallback。

### User-visible 行為改變（v3.1.0-hang-fix 生效後）

| 指標 | 之前 | 之後（預期） |
|------|------|-----------|
| Median response time | 629.9s (10.5 分鐘) | < 300s |
| Turns 慢過 10 分鐘 | 17/34 (50%) | < 5/34 (15%) |
| Hang 個案（>1hr） | 1-2 個 / day | 0 個 / day |
| 3 小時 hang | 1 個 | 0 個 |
| Context 膨脹 trigger | 50% threshold, 85% hard | 40% threshold, 250-msg hard |

---

## 🧠 Dev Task Memory 規約（David 2026-06-06 加 skill `dev-task-memory` 後新增）

> **背景**：Hang fix 解決咗「developer 唔回應」嘅問題，但**冇解決「context 處理完之後 dev task 嘅 decisions / state 點樣唔好被遺忘」**。
> 即使壓縮成功、session 重新開始，developer 之前做嘅 decisions（用 Hono 唔用 Express）、next steps（寫 Companies 編輯）都會 lost — 除非 persist 落 file system。
>
> **修法**：新 skill `skills/dev-task-memory/` 5-layer architecture：
> 1. **Trigger**（紅線 21-22 hook）→ 2. **State file**（`docs/_meta/dev-task-state.md`）→ 3. **Git checkpoint**（`hermes checkpoints` enabled）→ 4. **External memory**（holographic/mem0, fallback local jsonl）→ 5. **Cross-session search**（`session_search` FTS5）
>
> 詳見 `skills/dev-task-memory/SKILL.md`。

### 紅線 24-28（dev-task-memory 核心）

- **紅線 24**：**每個 long dev task 開始時必須 `save_state.py --project <name> --goal "..." --trigger task-start`**，唔可以 rely on LLM memory（會被 compression 清）。理由：6/4-6/6 多次 hang fix 證明，即使有 compression，decisions 仍 lost。
- **紅線 25**：**每 30 分鐘或每 10 個 tool calls 必須 re-save**（`--trigger auto-mid-task`）+ `sync_external.py --project <name>` push facts 落 external memory。理由：1 個鐘嘅 coding work 可能 produce 5-10 個 decisions，唔同步等於 lost。
- **紅線 26**：**每個 Decision 必須有 WHY** — 唔可以淨寫 "Use Hono"，要寫 "Use Hono 4x 細, edge 啱用"。理由：Compression 會 strip detail，但 WHY 必須 keep，否則下個 session 會重新犯同樣嘅 mistake。
- **紅線 27**：**Resume 時必須先 `load_state.py --project <name> --search-sessions`**，唔可以假設自己記得上一個 session 做過咩。理由：LLM memory 唔可靠，file system 至可靠。
- **紅線 28**：**State file 唔可以 commit 落 git** — `docs/_meta/*` 同 `dev-task-state.md` 必須喺每個 project 嘅 `.gitignore`。每個新 project 必須 `bash skills/dev-task-memory/scripts/setup_gitignore.sh <path>` 一次。理由：State 係 runtime metadata，唔係 source code。

### 紅線 29-30（zombie / compaction 防護）

- **紅線 29**：**Session stuck in `[CONTEXT COMPACTION]` loop > 2 turn 必須主動建議 /new**（2026-06-06 親驗 stuck case：過去 6 個 turn 全部 emit 同一個 handoff reference 唔做 work）。理由：Hermes 內部 compaction handoff 喺某啲情況會代替真正 response，session 變 zombie 但 gateway 仲 display 正常。
  - **Detection**：連續 2+ 個 turn，個 latest assistant message 開頭係 `[CONTEXT COMPACTION — REFERENCE ONLY]` 而且 `api_calls=1, finish_reason=stop`，冇真正 work。
  - **Action**：立即 mark session 為 ended（`UPDATE sessions SET ended_at=..., end_reason='stuck_in_compaction_loop' WHERE id=<stuck_id>`）+ insert sentinel message + load_state.py 開新 session。
- **紅線 30**：**任何 `delegate_task` / spawn subagent 之前必須先 emit 明確通知** + 用 [Subagent X] prefix 包住 subagent 嘅 response（2026-06-06 親驗 zombie subagent 跑 66 tool calls，喺 Discord streaming 中斷，partial content 漏出嚟，David 完全冇 context 知道係 subagent 唔係 main response）。理由：Discord 將 main response 同 subagent streaming 混埋 display，user 無從分辨，而且 subagent streaming 唔穩定（Unicode `▉` 字符即係 streaming 中斷 artifact）。

### 紅線 31-34（interruption / resume / preflight）

- **紅線 31**：**中斷前必須 call `recovery.sh <project> "<reason>"` 自動 save + 印 resume command**（2026-06-06 完工）。理由：David 親驗「中斷後返嚟 agent 唔知做緊咩」嘅痛點，必須有 systematic 流程。
  - **Triggers**：收工 / `/new` / gateway 重啟 / context 爆 / SIGTERM / 「我今晚做到呢度」/ 任何明顯中斷。
  - **Action**：`bash skills/interruption-recovery/scripts/recovery.sh <project> "<reason>"` 自動寫 `docs/_meta/dev-task-state.md` + interruption log，印 3 個 resume options。
- **紅線 32**：**David 醒返 / 開新 session 必須 `resume.sh <project>` 先睇 summary**（2026-06-06 完工）。理由：Resume 唔可以假設自己記得。
  - **Action**：`bash skills/interruption-recovery/scripts/resume.sh <project>` 印 Goal / Decisions / Next Steps / Past Sessions 摘要 + 3 個 resume options。
  - **Recommendation**：過 1 日 / 50 turns → 用 Option C（fresh + state inject）；< 1 小時 → Option A（`--resume`）；中間 → Option B（`--continue`）。
- **紅線 33**：**長期跑 dev task 必須用 `terminal_preflight.sh <cmd>` 預檢 long-lived command**（2026-06-07 完工）。理由：Hermes 內建 300s timeout + long-lived server detection 攔截 foreground `npm run dev` / `docker compose up` / `vite` 等等（過去 log 入面 26 次 error）。修法：跑 `bash skills/interruption-recovery/scripts/terminal_preflight.sh "<cmd>"` 預檢，真正 long-lived 就改用 `terminal(background=true, notify_on_complete=true)` pattern。
- **紅線 34**：**MEMORY.md / USER.md 編輯後必須 `memory_normalize.sh` 確保 §-delimiter round-trip clean**（2026-06-07 完工）。理由：我哋之前直接用 `write_file` / `patch` 加 entry，但 tool 嘅 `_detect_external_drift` 喺 line 555 會 check `raw.strip() != roundtrip`，`\n§\n` 嘅 multi-char delimiter 會撞到 drift check，之後每次 `memory(action=add)` 都會 refuse 寫。修法：`bash skills/interruption-recovery/scripts/memory_normalize.sh` 自動 normalize（`...entry.\n§\nnext` → `entry.§next`），跑完之後 round-trip 100% clean。

### 紅線 35-37（maintenance + backup + checkpoint）

- **紅線 35**：**Auto-maintenance cron 唔好 block**（2026-06-07 完工，2 jobs created）。理由：過夜 run 嘅 session 會累積 zombie，必須自動清。Cron jobs：
  - `757736b81b92` nightly-memory-normalize（02:00 daily）→ 自動 normalize MEMORY/USER
  - `be6b1aadc9cd` auto-archive-sessions（03:00 daily）→ 自動 archive > 13h inactive discord sessions
  - 兩者都用 `--no-agent` mode，output 落 `~/.hermes/cron/output/`，唔會 spam Discord。
- **紅線 36**：**Agent 編輯 ~/.hermes/memories/ 之前必須 backup**（2026-06-07 完工）。理由：memory_normalize.sh 自動 .bak.<ts> backup，但直接 `write_file` MEMORY.md 唔會。寫 `~/.hermes/memories/MEMORY.md` / `USER.md` 之前先 `cp file file.bak.$(date +%s)`。
- **紅線 37**：**長期 dev task 嘅 `write_file` / `patch` / 破壞性 `terminal` 之前必須 `pre_tool_checkpoint.sh <workdir> "<reason>"`**（2026-06-07 完工，skill：`long-task-resilience`）。理由：Hermes 0.15.1 嘅內建 CheckpointManager 雖然 config `enabled: true`，但 AIAgent 嘅 tool_executor code path 喺 Developer Profile 從未 trigger（`hermes checkpoints status` 永遠 0 projects）。修法：跑 `bash skills/long-task-resilience/scripts/pre_tool_checkpoint.sh "$WORKDIR" "before write_file: $FILE"` 喺 mutation 之前，將 working tree 嘅 dirty state 落 git ref `refs/checkpoints/<dir>/<ts>`，之後隨時 `git checkout <ref> -- <file>` 復原。Hook 自動 stash/pop 保留 working tree 不變。

### 紅線 38-41（context pressure + handoff）

- **紅線 38**：**Session > 100 API calls 主動 emit `📊 context_status`（in/out/msgs/api/pressure）**（2026-06-07 完工）。理由：Hermes 嘅 `compression.threshold: 0.30` 雖然會自動 trigger，但**自動 compression 唔主動通知 user**，David 會誤以為 hang。Pressure > 50%（warn）寫 progress checkpoint，> 100%（crit）自動 fork handoff。
- **紅線 39**：**Context pressure ≥ warn（0.5）唔可以再起新 subagent**（2026-06-07 完工）。理由：起 subagent 會 push 額外 context 入 main session，加速迫爆。改用 `delegate_task`（獨立 session，唔污染 main context）或者直接 fork 個 session 落 handoff。
- **紅線 40**：**中斷 > 5 分鐘後 resume 時，必須先睇 `~/.hermes/profiles/developer/handoffs/` 最新嘅 `<sid>.handoff.md` + 跑 `resume_task.py <sid> [--workdir <path]`**（2026-06-07 完工）。理由：自動 fork handoff 已經寫咗 session summary、token usage、reference state。直接 resume 唔睇 handoff = 失去 fork 嘅意義。Resume brief 包含 5 個 section：handoff / progress / dev-task-state / git log / pre-tool journal。
- **紅線 41**：**永遠唔可以 manual delete handoff file**（2026-06-07 完工）。理由：handoff 係 self-healing 嘅 audit trail，將來 debug 必需要。Archive 由 cron / `process_fork_queue.py` 自動清，唔需要手動。

### 紅線 42-48（CheckpointManager + Compression executor）

- **紅線 42**：**Hermes 內建 `CheckpointManager` 唔可靠**（2026-06-07 完工）。理由：即使 `config.yaml` 寫 `checkpoints.enabled: true`，AIAgent 嘅 `agent_init.py:1021` 雖然 init `_checkpoint_mgr`，但 `tool_executor.py:215-228` 個 trigger code path 喺 Developer Profile 從未執行過（`hermes checkpoints status` 永遠 `Projects: 0`）。**必須用我哋自己嘅 `pre_tool_checkpoint.sh`**，唔好 assume 內建 work。
- **紅線 43**：**Session `api_call_count` > 200 必須主動建議 /new 或者等 context_pressure_monitor.py 自動 fork**（2026-06-07 完工）。理由：100+ API calls 嘅 session 已經累積 4-6M cumulative input tokens，任何 compression 都救唔到。自動 fork 會將 handoff + git state 保存，fresh session 0 包袱 resume。Fork queue：`~/.hermes/profiles/developer/session_fork_queue.jsonl`，處理 script：`process_fork_queue.py`。
- **紅線 44**：**Long task 達到 pressure 0.85-1.20 必須執行 `compression_executor.py auto`** 自動 LLM-summarize 舊 messages，唔可以等 Hermes 內建 silent auto-compress（2026-06-07 完工，skill：`long-task-resilience/compression_subagent`）。理由：Hermes 內建 `compression.threshold: 0.30` 雖然自動 trigger 但**唔主動通知 user**，而且**冇 structured summary** — David 醒返睇唔明 session 做過咩。我哋個 executor 用 minimax-m3 LLM 產生 6 sections（Goal/Decisions/State/Next/Insights/Risks），寫入新 system message，將 head messages mark `active=0`，保留 tail verbatim。Compression 唔等如 kill — session ID 唔變，淨係清 context。
- **紅線 45**：**Pressure > 1.20 必須 fork 而唔可以壓縮**（2026-06-07 完工）。理由：超過 1.20 pressure 嘅 session 即使 compressed 都有 >50K tokens，任何後續 tool call 嘅 cumulative cost 會爆。Fork + fresh session 係唯一可持續做法。判斷喺 `compression_executor.py:decide_action` 自動做。
- **紅線 46**：**Compression 之後必須保留最後 4 個 exchanges（16 messages）verbatim**（2026-06-07 完工）。理由：純 compressed summary 唔可以取代「最近 user 講咗咩」+「最近 tool result」，否則 agent 會失去即時 context。`partition_head_tail` fallback：zombie session < 4 user turns → 保留最後 16 條 total messages。
- **紅線 47**：**永遠唔好手動 DELETE `active=0` 嘅 compressed messages**（2026-06-07 完工）。理由：`active=0` 係「壓縮咗但保留 audit trail」，將來 debug 同 /rollback 必需要。SQL：`UPDATE messages SET active=1 WHERE session_id=<sid> AND observed=1` 隨時 un-compress。刪除 = 永久失去 history。
- **紅線 48**：**Compression executor 用 LLM 之前必 verify endpoint format**（2026-06-07 完工，已撞牆教訓）。理由：個 endpoint URL 含 `/anthropic` 嘅時候用 Messages API（`/v1/messages` + `x-api-key` header），否則用 OpenAI chat.completions（`Authorization: Bearer`）。Developer Profile 個 minimax endpoint 係 anthropic format（`/anthropic/v1/messages`），唔係 chat.completions。`call_llm_summarize` 自動 detect by URL pattern，fallback extractive summary 如果 LLM fail。

### 紅線 49-51（response 風格 / 速度 / multi-task）

- **紅線 49**：**Response > 2000 chars 必須先列 outline，唔好 3000+ chars 嘅單一 response**（2026-06-07 完工 v2，evidence：過去 24h 39% response > 3000 chars，90-percentile 6171 chars，最高 34827 chars；同日 17:23 「A+B+C」multi-task 個 agent 14,158 chars inline report 證明原 wording 失效）。理由：David 明確投訴「不斷出詳細」係 verbose 唔係 zombie。規則：
  1. Response 開始時 1-3 個 emoji bullet 列 outline，畀用戶睇到 scope
  2. Detail 部分如果 < 2000 chars 就 inline，> 2000 chars 就開 sub-section 折疊
  3. 唔好 repeat 解釋同一個 concept
  4. Default 用 markdown list，唔用 paragraph
  5. 例外：Build 階段嘅 detail code block / file content 唔算 response chars
  6. **v2 加強**：Final response 本身有 hard cap — 就算 outline-final，deliverable 都唔可以 > 3500 chars（≈ 700-1000 中文字）。如需多過，**必須 emit 多次 final response**，中間用 `📍 progress 點 N/M` 標記，用戶可以中途插嘴 / 修正 scope。
- **紅線 50**：**慢 response（avg > 200s）主動 emit `📊 speed_status` + 自動 fork 高-API-call session**（2026-06-07 完工，evidence：過去 24h avg response time 453s，p90 1450s，27/56（48%）responses > 3 API calls，最長 2326s + 97 API calls）。理由：Hermes 嘅 `agent.max_turns: 150` 我哋 200→150 已經降低左，但**真正慢嘅 root cause 係 agent 連環起 subagent / re-read 同一個 file**。規則：
  1. Session api_call_count > 50 主動 emit `📊 speed_status: api=N/150, time=Ns`
  2. 同一個 file 連續 read 2 次 = 用 `search_files` 而唔再 `read_file`
  3. > 100 API calls 主動建議 fork handoff + fresh session 接手
  4. Config 已改：`agent.max_turns: 200→150`，`display.language: en→zh-Hant`，`display.streaming: false→true`
- **紅線 51**：**Multi-task 訊息（e.g. "A+B+C", "做 X 同 Y 同 Z"）必須先 push back 問 split strategy，唔好假設可以 1 個 final response 搞掂**（2026-06-07 完工，evidence：17:23 David send "A+B+C"（3 task review）→ 個 agent 直接 12-todo inline report 14,158 chars）。理由：紅線 49 v1 講「response > 2000 chars 開 sub-section」，但**multi-task 嘅 sub-section 加埋仲係 14K chars**，因為 agent 將 3 個 task 當 1 個 consolidated report。規則：
  1. User send multi-task 訊息時，**agent 第一次 response 必須係 push back**：「呢個有 N 個 task，我建議：(a) 每個 task 1 個 final response（低 verbosity），(b) 1 個 consolidated report（高 verbosity），(c) 你揀 1 個先做，之後再講揀邊個」
  2. User 確認 strategy 之後先開工，唔好假設 default
  3. 如果 user 明確講「A+B+C 全做，1 個 final response OK」，跟佢，否則默認係 multi-response
  4. 配紅線 49 v2 hard cap 3500 chars 使用

---

## 3 個 trigger 時機（dev-task-memory，詳細見 SKILL.md）

| 時機 | 命令 | 輸出 |
|------|------|------|
| **Task 開始** | `python3 scripts/save_state.py --project <name> --goal "..." --trigger task-start` | 建立 fresh state file |
| **Task 中段** | `python3 scripts/save_state.py --project <name> --trigger auto-mid-task`<br>`python3 scripts/sync_external.py --project <name>` | Update state + push facts |
| **Resume** | `python3 scripts/load_state.py --project <name> --search-sessions` | 注入 context，跟 "Next 3-5 Steps" 繼續 |

---

## 同其他 skills 嘅關係

- `context-summarizer`（existing）— 自動壓 context，**但** decisions 會 lost。dev-task-memory 補佢嘅缺點。
- `regression-guard`（existing）— 防舊 bug 翻發。dev-task-memory 嘅 Risks section 配 RG-XXX ID。
- `auto-doc-gen`（existing）— 自動 API doc。dev-task-memory 嘅 Decisions 配 doc rationale。

---

## User-visible 預期

- Hang 後 resume 0 個 decision lost
- Compression 後 30s 內 emit "📍 progress 點 N/M" + 跟住 next steps 繼續
- 1 個鐘後再開新 session 問 "之前我哋做咗咩"，agent 即時 recall top-3 relevant sessions

---

## Related docs

- [Documentation index](00-index.md)
- [Core identity](../SOUL.md)
- [Failure policy](failure-policy.md)
- [Gateway conflict incident](incident-20260619-gateway-conflict-v2.md)
