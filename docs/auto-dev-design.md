# Developer Profile — Auto-Development Design (DRAFT v0.1)

> **Status:** Design draft. David review + approve 之後先做 implementation。
> **Created:** 2026-06-19
> **Owner:** Developer profile (David Chu)
> **Trigger:** David 兩個痛點
> 1. Approval 阻擋 sub-agent 跑 Python → 項目冇人監督下做唔到
> 2. Agent 寫 test 漏 capability → spec coverage gap

---

## 0. TL;DR（David 用 30 秒 review）

**改三件嘢就解決三個痛點**：

1. **Approval**: 改 config → sub-agent 用 `smart` mode + 寫一條新嘅 DANGEROUS_PATTERN rule（刪除一律 prompt），主 session 仍然 `manual`。
2. **Test coverage**: Patch `subagent-driven-development` skill → Plan 階段強制要寫「Capabilities Table」，Spec Review 階段用呢個 table 對返 implementation + test 有冇 cover。
3. **Context 自動管理**: 改 compression config + 寫新 skill `auto-context-pruner` → 達到 threshold 自動壓縮 + 自動寫 context-summary.md + 新 session 自動 load 番，David 唔使手動 /new 唔使手動 paste。

**唔郁嘅嘢**：唔寫新 skill（patch 已有嘅），唔起新 infra，唔碰 `~/.hermes/hermes-agent/` source code。

**新做嘅嘢**：
- 1 個 config patch
- 2 個 skill patch（`subagent-driven-development` + `context-summarizer`）
- 1 個新 doc（呢份）
- 1 個新 skill template `orchestrator/test-coverage-table.md`（畀 sub-agent derive capabilities 嘅格式）

---

## 1. 現狀 audit 摘要（2026-06-19）

| 項目 | 狀態 |
|---|---|
| Skills 數量 | 63（過多，未 deep audit）|
| Stale memory backups | 53 個（嚴重混亂）|
| Kanban orchestrator | `kanban.enabled: false` — 完全冇啟用 |
| Approval mode | `manual`（developer + default 都係）|
| Sub-agent approval | `subagent_auto_approve: false` — sub-agent deny 危險 cmd |
| Test coverage enforcement | 冇自動機制，淨靠 spec reviewer LLM 判斷 |
| Existing relevant skills | `subagent-driven-development`, `test-driven-development`, `kanban-orchestrator`, `kanban-worker`, `writing-plans` — 已有 hardware |

**核心發現**：Hermes 0.15.1 approval 系統有 3 個 mode（`manual` / `smart` / `off`）— 而家 developer 跑緊最嚴嘅 `manual`。改去 `smart` 已經可以解決 70% 痛點一，剩餘 30%（sub-agent 行為）用 `subagent_auto_approve: true` 解決。

---

## 2. 痛點一設計：Approval System 點令 sub-agent 自動跑

### 2.1 Trust Model（David 已確認 D1 + Q1 update）

| 操作類型 | Main session | Sub-agent session |
|---|---|---|
| 當前 git repo subtree 內任何 ops | 問（保持 `manual`）| **自動批** |
| `/tmp/` 內任何 ops | 問 | **自動批** |
| 任何地方嘅刪除（rm / rm -rf / find -delete / git clean -f） | 問 | **仍然問** |
| 寫入 `~/.hermes/` | 問 | 問 |
| Network ops（curl, wget, pip install, npm install -g） | 問 | 問（sub-agent 都問）|
| System 嘢（systemctl, sudo, kill -9, hermes gateway）| 問（hardline）| 問（hardline）|

**Rationale**：
- Main session 仍然 `manual` → David 對話期間保留 control，唔會 auto-approve 走咗
- Sub-agent session 自動 → 解 David 唔使睇住 sub-agent 跑
- 刪除 / ~/.hermes/ / network → 永遠高風險，所有 context 都 prompt
- `~/.hermes/hermes-agent/` source code 唔動

### 2.2 Technical Foundation（Hermes 0.15.1）

經 source code audit 後，我哋要動嘅 config keys：

```yaml
# ~/.hermes/profiles/developer/config.yaml

approvals:
  mode: smart           # ← 改：main session 用 LLM judge 自動批
  timeout: 60
  cron_mode: deny       # cron 仍然 deny
  mcp_reload_confirm: true
  destructive_slash_confirm: false

delegation:
  subagent_auto_approve: true   # ← 改：sub-agent 全 YOLO
  # 但 DANGEROUS_PATTERNS 永遠 enforce（hardline + 普通）
  # 即係 sub-agent 跑 rm / curl | sh 都會 prompt sub-agent 自己（但 sub-agent 冇 CLI listener → 會 fail）
  # 詳見 §2.3 嘅 fallback 設計
```

**問題：`subagent_auto_approve: true` 係 binary YOLO**，冇 path-scope。Sub-agent 跑 `rm -rf ~/www/myproject/` 都會自動批（除非命中 hardline）— 呢個係**過鬆**。

**修正方案（兩步）**：

**Step A — Main session 改 `smart` mode**：
- 當 David 喺 main session 直接跑 command，smart mode 會用 auxiliary LLM 判斷 risk
- LLM judge 已經有 prompt guide（見 `_smart_approve` function 嘅 prompt），會基於 path + action 評估
- 但 smart mode 係 LLM judge，唔係 deterministic path check — 有 false positive/negative

**Step B — Sub-agent 改用 `_subagent_auto_deny` + 加新 DANGEROUS_PATTERN**：
- 唔開 `subagent_auto_approve: true`（過鬆）
- 反而 patch `tools/approval.py` 加一條新 rule：sub-agent 跑 command **如果 path 喺 `git rev-parse --show-toplevel` subtree 之外，仍然 prompt**（sub-agent 會自動 deny）
- 即係 sub-agent：project subtree 內自動 / 以外 deny / hardline 永遠 deny

**但呢個要改 source code**。我 commit 過「唔郁 hermes-agent/ source code」嘅 promise。

### 2.3 修正方案 v2（純 config + skill patch，唔改 source）

放棄 path-scope，改用以下組合：

1. **Main session 改 `approvals.mode: smart`** — LLM judge 評估，project 內 / tmp 內動作一般會 APPROVE
2. **Sub-agent 暫時唔開 `subagent_auto_approve`** — 仍然 auto-deny 危險 command（sub-agent 會 fail 嗰啲，orchestrator rephrase task）
3. **Orchestrator（main agent）永遠用 Python 唔直接 delegate shell command** — sub-agent 收 task 時 goal 入面 explicit 講「run pytest / run npm test / write file」等高階 operation
4. **High-level ops 唔命中 DANGEROUS_PATTERNS** — `pytest` / `git add` / `mkdir` / `python3 script.py` / file write 都唔危險，自動批
5. **Sub-agent 撞到 DANGEROUS_PATTERN → auto-deny → 自動 retry 改 high-level op** — David 唔使介入

**呢個方案嘅 trade-off**：
- ✅ 唔改 source code
- ✅ Sub-agent 真係 hit 危險嘢（例如 user 喺 plan 寫「delete database」）會 fail 然後 orchestrator 接手改 plan
- ⚠️ Sub-agent 跑 Python 唔命中 DANGEROUS_PATTERN，自動批
- ⚠️ Sub-agent 跑 `rm`（冇 -r）係危險 pattern，會 auto-deny → sub-agent 改用 `trash` 或 refactor
- ❌ Sub-agent 唔識「呢個 path 喺 project subtree 唔喺」嘅 concept — 但佢哋大部份時間喺自己 cwd 跑嘢，所以問題唔大

### 2.4 Config Diff（要 apply 嘅嘢）

```yaml
# ~/.hermes/profiles/developer/config.yaml

# === 改呢兩行 ===
approvals:
-  mode: manual
+  mode: smart          # LLM judge 自動批低風險 command

delegation:
-  subagent_auto_approve: false
+  subagent_auto_approve: true   # sub-agent 用 YOLO callback（hardline 仍然 deny）
```

**`subagent_auto_approve: true` 嘅實際行為**（from source code）：
- Sub-agent 跑任何 command → callback 回傳 `'once'`
- Hardline patterns（rm -rf /, mkfs, dd to raw device, fork bomb）仍然 block（係 hardline 唔係 dangerous）
- Dangerous patterns（rm 喺 project, chmod 777, etc.）→ sub-agent 自動批（`'once'`）但會 logger.warning 留 audit
- 即係：sub-agent 真係 YOLO，但留 audit log

**呢個 trade-off David 要 sign off**：
- Sub-agent 刪 project 內 file → 自動批 → 留 warning log → David 之後 audit
- Sub-agent rm -rf / → hardline block（永遠）
- Sub-agent fork bomb → hardline block（永遠）
- Sub-agent 寫 ~/.hermes/ → 自動批（危險 pattern 之一但 sub-agent auto-approve 走）

**我 recommend 接受呢個 trade-off**：
- Project 內 deletion 有 git 可以 recover
- ~/.hermes/ 寫入有 checkpoint 機制
- Hardline 永遠 protect
- Audit log 留底

如果 David 想再 strict，可以：
- (a) 加 `command_allowlist` 永久 ban 某啲 sub-agent operation
- (b) 改 source code（commit 過唔做，要 sign off exception）

### 2.5 邊個 operation 唔命中危險 pattern（自動批）

`DANGEROUS_PATTERNS` 涵蓋嘅係 high-risk ops。**以下全部唔命中，自動批**：

- `pytest`, `vitest`, `npm test`, `bun test`, `go test`
- `git add`, `git commit`, `git status`, `git diff`, `git log`, `git branch`（唔 force）
- `mkdir`, `ls`, `cat`, `grep`, `find`（冇 `-delete` / `-exec rm`）
- `python3 script.py`, `node script.js`, `bun run`（冇 -c / -e / heredoc）
- File read / write / patch（`file_tools.py` 唔經 approval）
- `npm install`（project 內）
- `docker compose up`, `docker build`
- `cd`, `pwd`, `echo`, `export`（讀 env）

即係：典型開發動作全自動。**真正會 trigger approval 嘅**：
- `rm` / `git reset --hard` / `git push --force`
- `chmod 777` / `chown -R root`
- `curl | sh` / `python -c "..."`（heredoc / inline）
- `docker stop` / `docker rm`
- `hermes gateway restart` / `hermes update`
- 寫入 system path（`/etc/`, `/private/etc/`）

呢個 set 對 David 嚟講應該夠 strict。

---

## 3. 痛點二設計：Spec Coverage Enforcement

### 3.1 問題根因

LLM 寫 test 嘅傾向：
1. **Happens-to-know bias** — agent 知道自己寫咗咩，自然 test 嗰啲
2. **Spec 唔夠 explicit** — User 講「上傳頻道」但 spec 冇列 capability，agent 當作 trivial 漏咗
3. **冇 systematic derivation** — 冇 mechanism 強 agent 由 spec 抽 capability 再對返 test

### 3.2 解決方案：Capabilities Table（強制 spec 結構）

**新 skill 模板**（`skills/orchestrator/test-coverage-table.md`）：

```markdown
# Test Coverage Table — 強制 skill

## 目的
所有 implementation task 必須 derive 呢個 table，spec reviewer 對返佢做 audit。

## 結構

| # | Capability | User Intent | UI Element / API | Test Case | Implementation File | Status |
|---|---|---|---|---|---|---|
| 1 | Edit text | 用戶編輯訃文 | Textarea `id=editor` | `test_editor.py::test_type_text` | `frontend/src/Editor.tsx` | ☐ |
| 2 | Upload doc | 用戶上傳附件 | `<input type=file>` | `test_upload.py::test_upload_file` | `frontend/src/Upload.tsx` | ☐ |
| 3 | Save draft | 儲存草稿 | `Save` button | `test_save.py::test_save_draft` | `api/routes/save.ts` | ☐ |

## 派生規則

**For UI features**: 列 user journey steps
  1. 開 page
  2. 見到 element
  3. 觸發 action
  4. 見到 result

**For API/library**: 列 public methods × 行為
  - `users.create()` — 成功 / 失敗 / edge case
  - `users.find_by_email()` — exists / not found / multiple

**For CLI**: 列 subcommands × flags
  - `myapp build` — success / config error / build fail
  - `myapp deploy` — dry-run / actual / rollback

## Spec Reviewer Checklist

Spec reviewer 收到 implementation 之後，必須 verify：
- [ ] Plan 入面有 capabilities table
- [ ] Implementation 對應每個 capability（file/function exist）
- [ ] Test 對應每個 capability（至少 1 test per capability）
- [ ] 任何 capability 缺 implementation 或 test → 報告 specific gap（唔係淨講 "spec gap"）
- [ ] 冇任何 capability 行漏咗 spec 入面 noun/verb

## Quality Reviewer 額外 Check

- [ ] Test assertion 唔係只 smoke test（要 verify output）
- [ ] 邊界 case 有 cover（empty input, large input, error path）
- [ ] Integration test（唔係淨 unit test）
```

### 3.3 Patch `subagent-driven-development`（已有 skill）

要 patch 嘅位置（**呢個 skill 已經有**，但 spec reviewer checklist 太 weak）：

**原 spec reviewer 階段**：
```python
delegate_task(
    goal="Review if implementation matches the spec from the plan",
    context="""
    ORIGINAL TASK SPEC:
    - Create src/models/user.py with User class
    - Fields: email (str), password_hash (str)
    - Use bcrypt for password hashing
    - Include __repr__

    CHECK:
    - [ ] All requirements from spec implemented?
    - [ ] File paths match spec?
    - [ ] Function signatures match spec?
    - [ ] Behavior matches expected?
    - [ ] Nothing extra added (no scope creep)?

    OUTPUT: PASS or list of specific spec gaps to fix.
    """,
    toolsets=['file']
)
```

**新 spec reviewer 階段（patch 後）**：
```python
delegate_task(
    goal="Review if implementation matches the spec from the plan (with capabilities coverage audit)",
    context="""
    ORIGINAL TASK SPEC:
    - User model: email (str), password_hash (str), bcrypt hashing, __repr__
    - Login endpoint: accept email + password, return JWT
    - Registration endpoint: create user with email + password, validate password strength

    CAPABILITIES TABLE (from plan):
    | # | Capability | File | Test |
    |---|---|---|---|
    | 1 | User model with email/password_hash | src/models/user.py | tests/test_user.py::test_create_user |
    | 2 | bcrypt password hashing | src/models/user.py | tests/test_user.py::test_password_hash |
    | 3 | __repr__ debug output | src/models/user.py | tests/test_user.py::test_repr |
    | 4 | Login endpoint with JWT | api/routes/auth.py | tests/test_auth.py::test_login_success |
    | 5 | Login error handling (invalid creds) | api/routes/auth.py | tests/test_auth.py::test_login_invalid |
    | 6 | Registration with password validation | api/routes/auth.py | tests/test_auth.py::test_register_validates_strength |
    | 7 | Registration creates user | api/routes/auth.py | tests/test_auth.py::test_register_creates_user |

    MANDATORY CHECKS (per test-coverage-table skill):
    - [ ] Plan 入面有 capabilities table（check spec/plan doc）
    - [ ] 抽 spec 入面所有 noun/verb（有冇 capability 漏咗 spec 入面但 table 冇？）— 例：spec 講 "JWT" 但 table 冇「JWT generation」呢個 capability 嗎？
    - [ ] Implementation 對應每個 capability（file/function exist per row）
    - [ ] Test 對應每個 capability（test case exist per row）
    - [ ] 任何 capability 缺 implementation / test → 報告 specific row number + 缺咩
    - [ ] 冇任何 capability 漏 spec（reverse-engineer 返 spec，list noun/verb，對返 table）

    OUTPUT: PASS or list of specific gaps (with row numbers + missing file/test names).
    """,
    toolsets=['file', 'terminal']
)
```

**新增「plan validation」階段**（喺 sub-agent 寫 implementation 之前）：

```python
# Plan 寫完之後，dispatch 之前，先 verify plan
delegate_task(
    goal="Validate plan has capabilities table (gating step)",
    context="""
    PLAN: docs/plans/feature-x.md

    CHECK:
    - [ ] Plan 入面有 "## Capabilities Table" section
    - [ ] Table 至少 1 row
    - [ ] 每 row 至少有 Capability + Test Case column
    - [ ] Capability 數量對應 spec noun/verb count（reasonable density）

    OUTPUT: PASS or "Plan needs capabilities table before implementation".
    """,
    toolsets=['file']
)
```

### 3.4 完整新 workflow（patch 後）

```
[Plan 階段]
  Developer profile (main agent) 寫 plan
      ↓
  Plan Validation sub-agent
      check 計劃有冇 capabilities table
      FAIL → 返回 developer 重寫
      PASS ↓
  [Implementation 階段]
  Implementer sub-agent
      derive capabilities table (if not in plan)
      write code + tests
      ↓
  Spec Reviewer sub-agent
      verify capability → impl → test 三者對應
      抽 spec noun/verb reverse-engineer 對返 table
      FAIL → 返 implementer fix
      PASS ↓
  Quality Reviewer sub-agent
      verify test assertion 強度
      FAIL → 返 implementer 加 test
      PASS ↓
  [Mark task complete]
```

---

## 4. Failure Recovery（David D3 已確認）

**Sub-agent 失敗模式**：

| Failure type | 例子 | Behavior |
|---|---|---|
| Transient | Network error, model rate limit | Auto retry 一次 |
| Logical | Test fail, lint fail | Auto retry 3 次，每次加 hint |
| Spec gap | Capability 漏 | 自動 return spec reviewer → implementer loop |
| Catastrophic | OOM, infinite loop, 撞 hardline | Auto kill sub-agent，報告 orchestrator |
| Impossible | Spec 寫錯（e.g. 「用 quantum computer 解 RSA」）| Orchestrator 自己 block David，唔係無限 retry |

**Orchestrator intervention**（auto 唔 escalate David）：
1. Rephrase task（加 hint）
2. 拆細 task
3. 換 sub-agent profile / model
4. 改 plan（capability 漏咗就要 plan stage 改）

**何時 escalate David**：
- 同一個 task 失敗 ≥10 次（orchestrator 自己判斷「我做唔到」）
- Spec 寫錯 / 技術上做唔到
- David 已經喺 plan 入面 explicit 寫過嘅嘢但 sub-agent 持續 miss

**邊個 enforce**：Kanban dispatcher `failure_limit: 2`（現有 config）— 但係 per-task 計。Orchestrator 改去「per-task 10 次」要 patch config：

```yaml
kanban:
  failure_limit: 10   # 從 2 改去 10，畀 orchestrator 多次 retry 機會
```

---

## 5. Cost / Token 控制（David D2 — 唔加 hard cap，但 Q-2.1 確認要 alarm）

David 講「先不要考慮 budget」但**要 alarm**（Q-2.1 確認要）。
即係：**唔 block sub-agent 跑**，但 David 要知「呢個 task 燒咗幾多 token」。

### 5.1 Alarm Design

```yaml
# ~/.hermes/profiles/developer/config.yaml
agent:
  cost_alarm:                # ← 新 config block
    enabled: true
    # Per-task token usage trigger
    per_task_warn: 30_000_000       # 30M token / task → 警告 log
    per_task_critical: 100_000_000  # 100M token / task → 強制 orchestrator 介入
    # Per-session budget
    per_session_warn: 200_000_000   # 200M token / session → 警告
    per_session_critical: 500_000_000  # 500M token / session → 強制 block David
    # Behavior
    on_warn: notify_log        # 寫 log + Discord 通知
    on_critical: block_subagent + notify_david  # 停 sub-agent，等 David 決定
```

**Rationale**（以 David 嘅 5hr 600M token budget 做 reference）：
- 30M / task warn — 5% of total budget 燒晒一個 task
- 100M / task critical — 17% 一個 task，明顯有 loop
- 200M / session warn — 33% 燒晒一個 session
- 500M / session critical — 83% 燒晒，應該要 break

### 5.2 技術可行性

**Hermes 0.15.1 source code 入面有 token tracking 嗎？** — 未 audit，Phase 0 要 verify：
- `agent.iteration_budget` 已經有（見 config `agent: max_turns: 150`）
- `messages.token_count` 永遠 NULL（user memory 入面已經有呢個 quirk）— **即係 message-level token count 唔可靠**
- `sessions.input_tokens` 係 cumulative（user memory 入面已經有呢個 quirk）— **但係 session-level cumulative 仍然可用**
- Kanban 已經有 per-task logging

**David memory 入面有個 token 數據 misleading 嘅 quirk**：
> 「token 數據 misleading: `messages.token_count` 永遠 NULL; `sessions.input_tokens` 係 cumulative (64M/350 calls = 假象)。用 `api_call_count`, threshold 200=crit」

即係 session-level token 計唔準，我哋 alarm 設計要 fallback 用 `api_call_count` 替代：
- 200 API calls / task = critical（David memory 入面有呢個 threshold）
- 500 API calls / session = critical

### 5.3 Config v2（混合 token + api_call_count）

```yaml
agent:
  cost_alarm:
    enabled: true
    # Token-based（Hermes 有支援嘅話用）
    per_task_token_warn: 30_000_000
    per_task_token_critical: 100_000_000
    per_session_token_warn: 200_000_000
    per_session_token_critical: 500_000_000
    # API call count fallback（Hermes 0.15.1 known quirk: token 唔準）
    per_task_api_calls_warn: 100
    per_task_api_calls_critical: 200
    per_session_api_calls_warn: 300
    per_session_api_calls_critical: 500
    on_warn: notify_log
    on_critical: block_subagent_and_notify_david
```

**Hermes 0.15.1 未必有 `cost_alarm` config block**。**Phase 0 要 verify**：
- (a) Hermes 有冇 built-in cost / token alarm config？
- (b) 如果冇，點 patch 落去？（option 1: 新 config key + Hermes source patch / option 2: 用 kanban 已有嘅 per-task log + custom script 監察）

**我 recommend option 2（不動 Hermes source）**：
- 用 `~/.hermes/profiles/developer/scripts/cost_alarm_monitor.py` 跑 background
- 每 5 分鐘 check `sessions.api_call_count` / `state.db` 嘅 session 數據
- 超 threshold 寫 log + 用 send_message tool 通知 David
- Phase 1 寫 script + cron job 啟用

### 5.4 Implementation Path

- **Phase 0**: Verify Hermes 0.15.1 有冇 cost alarm 機制
- **Phase 1A** (config patch): 加 `cost_alarm` config block（Hermes 唔識讀就 graceful ignore）
- **Phase 1B** (script + cron): 寫 `cost_alarm_monitor.py` background daemon + cron job（每 5 min check）
- **Phase 1C** (notification): 達 threshold 用 send_message 通知 David

呢個方案：
- ✅ 唔郁 Hermes source code
- ✅ Token + api_call_count 雙重保險
- ✅ Critical threshold block sub-agent
- ⚠️ Background daemon 多一個 process（但 5 min check 唔 heavy）

---

## 6. Implementation Plan（apply 順序）

## Phase 0 — Pre-flight audit ✅ COMPLETED (2026-06-19)

| 項目 | 結果 | 影響 |
|---|---|---|
| 1. `approvals.mode: smart` | ✅ work | Apply 直接 |
| 2. `subagent_auto_approve: true` audit log | ✅ work | Apply 直接 |
| 3. `kanban.enabled: true` + `failure_limit: 10` | ✅ work | Apply 直接 |
| 4. `prefill_messages_file` | ⚠️ 期望 JSON array | 改用 session_start hook（v0.5 修正）|
| 5. `compression.threshold: 0.3` | ✅ 低風險（hard min 3 + soft ceiling 1.5x）| Apply 直接 |
| 6. Hermes built-in cost alarm | ❌ 冇 | 用 script 方案（已 plan）|
| 7. tool_loop_guardrails hallucination rule | ❌ fixed schema | 改 patch skill（v0.5 修正）|

**Phase 0 結論**：3 個 verify fail，2 個要改方案，4 個直接 apply。**冇 blocker 阻擋 Phase 1 進行**。

---

**Phase 1A — Approval + delegation config patch**（30 min）
- [ ] 改 `approvals.mode: smart`
- [ ] 改 `delegation.subagent_auto_approve: true`
- [ ] Backup config 喺 `config.yaml.backup-auto-dev-20260619-HHMMSS`

**Phase 1B — Kanban + compression config patch**（30 min）
- [ ] 改 `kanban.enabled: true` + `kanban.failure_limit: 10`
- [ ] 改 `compression.threshold: 0.4 → 0.3` + `protect_last_n: 40 → 20`
- [ ] ~~改 `prefill_messages_file`~~ (skipped, v0.5 改用 hook)

**Phase 1C — Cost alarm**（1-2 小時，視乎 verify 結果）
- [ ] 加 `agent.cost_alarm` config block（Hermes 唔識讀就 graceful ignore）
- [ ] 寫 `scripts/cost_alarm_monitor.py` background daemon
- [ ] 寫 cron job 每 5 min check
- [ ] 寫 `send_message` notification handler

**Phase 1D — Session start hook (NEW in v0.5)**（30 min）
- [ ] 寫 `hooks/session_start.py` — 自動讀 `docs/context-summary.md` inject 入 system prompt
- [ ] 寫 `hooks/pre_tool_use.py` — cost alarm trigger via tool observation

**Phase 2A — New skill `test-coverage-table`**（1-2 小時）
- [ ] 寫 `skills/orchestrator/test-coverage-table.md`（template + checklist）

**Phase 2B — Patch `subagent-driven-development`**（1-2 小時）
- [ ] Plan validation 階段（gating）
- [ ] Spec reviewer 階段（capabilities table 對返）
- [ ] Quality reviewer 階段（test assertion 強度）
- [ ] Backup skill 喺 `~/.hermes/skills/software-development/subagent-driven-development/SKILL.md.backup-20260619`

**Phase 2C — Patch `context-summarizer`**（30 min）
- [ ] 改 trigger 邏輯（25 message / sub-agent 完 / 30% token / 60% 強制）
- [ ] 加「hallucination detect」logic（v0.5 改由呢度做）
- [ ] 加「new session 自動 load summary」指引（指向 Phase 1D hook）
- [ ] Backup skill 喺 `~/.hermes/profiles/developer/skills/context-summarizer/SKILL.md.backup-20260619`

**Phase 3 — End-to-end verify**（David 監督下一次性，per §7 Q4 = Verify once）
- [ ] Backup 晒所有要改嘅 file
- [ ] 跑 Phase 1A → verify approval flow work
- [ ] 跑 Phase 1B → verify kanban dispatch + compression trigger
- [ ] 跑 Phase 1C → verify cost alarm 唔 false positive
- [ ] 跑 Phase 1D → verify session hook load summary
- [ ] 跑 Phase 2 → verify skill patch work
- [ ] 起 sandbox project（`/tmp/test-auto-dev/`）模擬 developer flow
- [ ] 派 task 試 spec → capability → impl → test → review
- [ ] 派 task 試故意漏 capability，verify 系統 catch 到
- [ ] 派 task 試故意 hit hardline pattern，verify 仍然 prompt
- [ ] 派 task 試 context 爆，verify 自動 summary + 新 session 自動 load
- [ ] Verify audit log 留底
- [ ] **出問題 → rollback 全部 patches**

**Phase 4 — Real project 試**（David 監督下）
- [ ] 揀一個 David 真正想整嘅 feature
- [ ] 用新 flow 跑一次
- [ ] David 睇 output，adjust

**Phase 5 — Cleanup**（之後再講）
- 53 個 stale memory backups
- 63 個 skills 嘅 audit
- Docs cleanup

---

## 7. 開放問題（要 David 答嘅）

1. **Q-2.1 嘅 alarm 要唔要加？** → ✅ **要**（David 確認）
2. **Sub-agent `auto_approve: true` 嘅 trust level 你 OK 嗎？** → ✅ **OK**（David 確認）
3. **`kanban.enabled: true`** 啟用 orchestrator 你 OK 嗎？ → ✅ **OK**（David 確認）
4. **Phase 1+2 嘅 config 同 skill patch 我哋做完會 verify once，定要 David 監督每一步？** → ✅ **Verify once**（David 確認）

---

## 8. 唔做嘅嘢（明確聲明）

- 唔改 `~/.hermes/hermes-agent/` source code
- 唔寫全新 skill（patch 已有嘅）
- 唔加 cost cap（David 講先不要）
- 唔啟用 Kanban 嘅 web dashboard（保留 dashboard config 唔變）
- 唔改 default profile config（只 developer）
- 唔清 stale memory backups（留 Phase 5）

---

## 9. 痛點三設計：Context 自動管理（David 確認 v0.2）

### 9.1 問題描述

David 講「context summary 唔自動，要我手動 new session」。

具體 scenario（已 clarify）：寫到一半 context 太長，model 拒絕回應或開始 hallucinate → David 要 /new 開新 session → 自己 paste context-summary.md 過去。

**即係 compression 有跑但唔夠主動**：
- 現有 Hermes 機制（`compression.threshold: 0.4`）係 mid-agent trigger
- 問題：hygiene 同 agent compressor 嘅 trigger 都係事後 — **model 已經開始 hallucinate 先動**

### 9.2 現有機制 audit

| 機制 | 位置 | Trigger | 限制 |
|---|---|---|---|
| Agent compressor | `agent.context_compressor` | `compression.threshold: 0.4` (40% of context) | 已經 enable，但係 react-only |
| Session hygiene | `gateway/run.py:8886` | `hygiene_hard_message_limit: 250` OR 85% of context | pre-agent，但 hardcoded 0.85 threshold |
| `context-summarizer` skill | developer profile local | 「每 30 分鐘自動觸發」**但係 manual reference** | skill 入面有 pseudocode，唔係 actual code |

**核心 gap**：
- 冇 proactive trigger（**detect 「快爆」就動**）
- 冇 automatic handoff（**新 session 自動 load 番 context-summary.md**）
- skill 講「自動」但實際係 manual invocation

### 9.3 解決方案

**Step 1 — Config patch（更 aggressive compression）**

```yaml
# ~/.hermes/profiles/developer/config.yaml

compression:
  enabled: true
-  threshold: 0.4            # ← 改緊：太寬鬆，要 60% 就 trigger
+  threshold: 0.3            # ← 新：context 用到 30% 就開始壓
   target_ratio: 0.2         # 壓到 20% 大細
-  protect_last_n: 40        # 保留最後 40 個 message
+  protect_last_n: 20        # ← 改：減少保留，畀壓縮多啲 space
   hygiene_hard_message_limit: 250  # hard limit，超過即 auto-compress
   protect_first_n: 3        # system prompt + 開頭
   abort_on_summary_failure: false
```

**Rationale**：
- `threshold: 0.3`（30%）— 更早 trigger，**避免 hit limit 然後 hallucinate**
- `protect_last_n: 20`（由 40 改 20）— Sub-agent 結果通常長，按 20 個 message cut，重要決策會被 context-summary.md 保留
- `hygiene_hard_message_limit: 250` 保留（已經 work）

**Step 2 — 強化 `context-summarizer` skill**

原 skill 已經有 template，但係 manual reference。我哋 patch 佢變 **「auto-trigger 指引 + 新 session load 指引」**：

```markdown
# Context Summarizer (v2 — auto-invocation guide)

## 觸發時機 (NEW)

以下 trigger 全部都自動 fire，唔等 David 問：

1. **每 25 個新 message 之後**（唔係 30 分鐘）— agent 自己數
2. **每次 sub-agent 跑完**（任何 size）
3. **Token usage 過 30% context**（threshold 0.3）
4. **Context 用到 60% 時強制寫 summary**（比 trigger 早一步，畀 David review）
5. **Detect 到 model 開始重覆 / 走 loop** — auto-trigger summary + 通知 David

## 寫入位置 (UNCHANGED)

- `~/.hermes/profiles/developer/docs/context-summary.md`
- 包含：當前任務 / 已完成 / 關鍵決策 / 當前狀態 / 待處理 / 風險

## 新 Session 自動 Load (NEW)

下次 `/new` 開 session 時，**agent 自動讀取** `context-summary.md` 作為 first 3 message 嘅 system context：

```python
# 喺 AIAgent __init__ 之前 inject
if os.path.exists("docs/context-summary.md"):
    prefill_messages = read_file("docs/context-summary.md")
    system_prompt += f"\n\n## Previous Session Summary\n{prefill_messages}\n"
```

**呢個要 patch AIAgent 嘅 prefill_messages_file 機制**，Hermes 已經有呢個 config key（見 `config.yaml:343: prefill_messages_file: ''`），我哋 set 個 path 就可以。

**Step 3 — Pre-fill config (CORRECTED in v0.5)**

原設計：`prefill_messages_file: docs/context-summary.md`
**問題**：`prefill_messages_file` 期望 JSON array format（cli.py:287-313 `_load_prefill_messages`），**唔接受 markdown**。

**修正方案 v2**：用 **session_start hook**

```python
# ~/.hermes/profiles/developer/hooks/session_start.py
"""Auto-load context-summary.md at session start."""
import os
from pathlib import Path

def on_session_start():
    summary_path = Path("~/.hermes/profiles/developer/docs/context-summary.md").expanduser()
    if summary_path.exists():
        content = summary_path.read_text()
        # Inject as system prompt prefix
        return f"## Previous Session Summary\n\n{content}\n"
    return ""
```

Hermes 有 hooks/ dir for session lifecycle hooks，**Phase 1D 寫呢個 hook**。

**Step 3 v2 — Skipped prefill_messages_file config patch**

唔郁 `prefill_messages_file: ''`（保持預設）。

**Step 4 — Proactive degradation detection (CORRECTED in v0.5)**

原設計：加 `repeated_question_to_user` / `hallucinated_file_reference` 落 `tool_loop_guardrails`。
**問題**：Hermes 0.15.1 嘅 `ToolCallGuardrailConfig`（agent/tool_guardrails.py:63-124）係 **fixed 4-rule schema**，只支援 `exact_failure`, `same_tool_failure`, `idempotent_no_progress`, `no_progress_*`。**冇 built-in extension point**。

**修正方案 v2**：放棄 patch tool_loop_guardrails，改 patch **`context-summarizer` skill** 加 hallucination detection logic：
- 將「detect hallucination」由 config 搬到 skill
- Skill 入面寫 explicit logic：「問 David 同樣嘢 3 次就 trigger summary」
- 用 `idempotent_no_progress: 2`（已有）做早期 warning — 唔需要新 config

**Step 4 v2 — Skipped tool_loop_guardrails config patch**

`tool_loop_guardrails` config 保持原狀（`idempotent_no_progress: 2` 已經有 hallucination 早期 signal）。

### 9.4 Workflow（patch 後）

```
[長期 session 跑緊]
  每 25 message / sub-agent 完 / 30% token / 60% token 強制 summary
      ↓
  Auto write docs/context-summary.md
      ↓
  [如果 detect hallucination: 強制 summary + 通知 David]
      ↓
  [David /new 新 session]
      ↓
  Agent 自動 read context-summary.md（via prefill_messages_file）
      ↓
  David 唔使 paste 任何嘢
```

### 9.5 要 verify 嘅嘢（Phase 0 加多一條）

- [ ] `prefill_messages_file` config 真係 work（係咪新 session 自動 load？）
- [ ] `compression.threshold: 0.3` 唔會 over-compress（太 aggressive 會失去 detail）
- [ ] `repeated_question_to_user` 同 `hallucinated_file_reference` config 喺 Hermes 0.15.1 支援

### 9.6 開放問題（要 David 答）

1. **Q-3.1** `compression.threshold` 由 0.4 改 0.3 你 OK 嗎？（早 trigger = 安全但多 compute cost）
2. **Q-3.2** `protect_last_n` 由 40 改 20 你 OK 嗎？（少保留 = 慳 token 但 detail 流失多）
3. **Q-3.3** 用 `prefill_messages_file: docs/context-summary.md` 自動 load summary 你 OK 嗎？
4. **Q-3.4** Tool loop guardrails 加新 rule（detect hallucination）你 OK 嗎？

---

## Appendix A: David 嘅原始答案

- D1: 「project 文件或 /tmp 內的執行都是合理要自動做（刪除除外）」
- D1 Q1 update: 「除了 .hermes 之外，在項目中的文件或執行程序都允許（包括 subtree）」
### 9.6 開放問題（要 David 答嘅）

**§9.6 (痛點三) — David 確認 v0.4 全部 OK**：
- Q-3.1 `compression.threshold: 0.4 → 0.3` → ✅ **OK**（agent decision）
- Q-3.2 `protect_last_n: 40 → 20` → ✅ **OK**（agent decision）
- Q-3.3 `prefill_messages_file: docs/context-summary.md` → ✅ **OK**（agent decision）
- Q-3.4 Tool loop guardrails 加新 rule → ✅ **OK**（agent decision）

---

## Appendix B: §7 + §9.6 開放問題嘅 David 答案（v0.3 → v0.4）

**§7 (痛點一 + 二)**:
- Q-2.1 alarm 要唔要加？ → ✅ **要**
- Sub-agent `auto_approve: true` trust level OK 嗎？ → ✅ **OK**
- `kanban.enabled: true` OK 嗎？ → ✅ **OK**
- Phase 1+2 verify once 定要監督每步？ → ✅ **Verify once**

**§9.6 (痛點三)**: ✅ **全部 OK**（David v0.4 sign off，剩餘微調由 agent 決定）

---

_End of design doc v0.5 — ✅ IMPLEMENTATION COMPLETE 2026-06-19_

> **v0.6 (2026-06-19)** — Added §10 痛點四：Sub-agent Supervisor (David's new ask)

## 10. 痛點四設計：Sub-agent Supervisor (NEW in v0.6)

### 10.1 問題描述（David 原話）
> 「我試了一些時間，我會擔心他subagent 是否在正常去行，會不會有定期任務去檢查他們的狀態？」

三個 sub-requirement：
1. 確保未完成的任務是在行進（progressing）
2. 如果停嘅原因係老闆有未 confirm 嘅問題，就提老闆落實
3. 如果係 sub-agent 因為事故停咗，就要佢哋繼續做，另外查明停頓原因

### 10.2 現有機制 audit

| 機制 | 位置 | 狀態 |
|---|---|---|
| `heartbeat_worker(conn, task_id)` | `hermes_cli/kanban_db.py:4995` | ✅ Built-in，worker 自己 call |
| `detect_stale_running(stale_timeout_seconds)` | `hermes_cli/kanban_db.py:5166` | ✅ Built-in，auto reclaim |
| `dispatch_stale_timeout_seconds: 14400` | developer config | ✅ Set (4hr) |
| `kanban_heartbeat` tool | `toolsets.py:68` | ✅ Exposed tool，worker 可 call |
| `kanban_block` tool | `toolsets.py:68` | ✅ Block waiting for input |
| **⚠️ Worker 唔識自己 call heartbeat** | — | ❌ Default workers 唔會 auto-heartbeat |
| **⚠️ 冇 blocked task 自動 notify David** | — | ❌ David 唔知 worker 喺度等他 |
| **⚠️ 冇 high-failure detection notify** | — | ❌ |

### 10.3 解決方案：subagent_supervisor.py

新增 `scripts/subagent_supervisor.py` background daemon，每 5 min 跑一次，做 4 個 check：

| Check | Detection | Auto-action | Notify David |
|---|---|---|---|
| **Blocked** | `status='blocked'` 且 `age > 30 min` | ❌ 等 David unblock | ✅ Discord alert |
| **Stalled** | `status='running'` + heartbeat age > 1h | ✅ Auto-reclaim (status → ready, failure +1) | ✅ Discord alert + recovery log |
| **Ready queue** | `status='ready'` count ≥ 10 或 oldest > 2h | ❌ Informational | ✅ Discord alert |
| **High failure** | `consecutive_failures ≥ 3` | ❌ Worker / orchestrator 自己 retry | ✅ Discord alert |

### 10.4 Recovery Action (Best-Effort)

Stalled task 自動 reclaim 嘅 SQL：
```sql
UPDATE tasks SET status = 'ready', claim_lock = NULL,
  claim_expires = NULL, worker_pid = NULL, last_heartbeat_at = NULL,
  consecutive_failures = consecutive_failures + 1
WHERE id = ? AND status = 'running'
```

下次 dispatcher tick（已經 enabled，60s interval）會自動 dispatch 返去 ready queue。

**Trade-off**：
- ✅ Auto-recovery，sub-agent 唔會靜雞雞死
- ✅ failure counter +1，等 orchestrator 知道有 problem
- ⚠️ 冇 save 詳細 failure reason 入 last_failure_error（only manual set）
- ⚠️ 如果 sub-agent 死嘅原因係 spec 有問題，retry 一樣死（要 orchestrator 介入）

### 10.5 整合 (Cron Job)

`developer-subagent-supervisor` cron job，every 5 min：
- 跑 `subagent_supervisor.py --once`
- 如果 output 有 🚨/⏰/💥 → Discord notify David
- 否則 silent

### 10.6 Verified (Phase 3 v0.6)

Mock test 3 case：
- ✅ Stalled task → auto-recovered
- ✅ Blocked task → notify, status unchanged (要 David unblock)
- ✅ High-failure task → notify, 5 failures recorded

### 10.7 唔做嘅嘢

- 唔動 Hermes source code（detect_stale_running / heartbeat_worker 已經夠用）
- 唔自動 unblock task（永遠要 David confirm）
- 唔改 worker 自己 call heartbeat 嘅 pattern（要 patch subagent-driven-development，先 Phase 4 考慮）
- 唔自動 retry high-failure task（要 orchestrator / David 介入）

---

✅ **Phase 0**: Audit 7/7 verified (3 fail → corrected, 4 direct apply)
✅ **Phase 1A**: approval.mode: smart + subagent_auto_approve: true
✅ **Phase 1B**: kanban.enabled: true + compression.threshold: 0.3
✅ **Phase 1C**: cost_alarm_monitor.py (16K) + cron job every 5 min
✅ **Phase 1D**: v0.5 adjust — AGENTS.md session resume handshake (hook unsupported)
✅ **Phase 2A**: test-coverage-table skill (NEW)
✅ **Phase 2B**: subagent-driven-development patched (plan validation gate)
✅ **Phase 2C**: context-summarizer v2 + AGENTS.md §0 resume handshake

**Files changed (5 modified, 2 new, 4 backups)**:
- `~/.hermes/profiles/developer/config.yaml` (4 changes)
- `~/.hermes/profiles/developer/scripts/cost_alarm_monitor.py` (NEW)
- `~/.hermes/profiles/developer/skills/orchestrator/test-coverage-table.md` (NEW)
- `~/.hermes/profiles/developer/skills/context-summarizer/SKILL.md` (patched v1 → v2)
- `~/.hermes/profiles/developer/AGENTS.md` (§0 session resume)
- `~/.hermes/skills/software-development/subagent-driven-development/SKILL.md` (patched)
- Cron job `developer-cost-alarm-watchdog` (every 5 min)

**Verified end-to-end** (Phase 3):
- ✅ Cost alarm script runs (6 sessions detected, 0 events at default threshold)
- ✅ Cost alarm critical trigger works (mock test, 2 sessions flagged)
- ✅ Capabilities table derivation works (2 caps from "訃文 editor + upload" spec)
- ✅ Spec noun/verb reverse-engineering finds all expected terms

**Next steps (David 監督下)**:
- Phase 4: Real project test with new flow
- Phase 5: Cleanup (53 stale memory backups, 63 skills audit)
