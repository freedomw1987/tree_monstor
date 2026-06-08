<!--
references/recovery-template-limitation.md

Day 11 lesson (2026-06-09): `recovery.sh` + `save_state.py` 嘅 generic
template 永遠唔 fill 真正 state。Resume 時一定要手動 overwrite。

Why this file exists:
  - Day 10.1 + Day 11 兩次 trigger `recovery.sh` 嘅 output 都係 generic
    template (Decisions = `<Decision 1>`, Files touched = 全部 `(now)`,
    Next Steps = 5 條 placeholder)。Resume.sh load 入 context 之後,
    agent 只見到 empty state,完全失憶。
  - Root cause (2026-06-09 確認):
    1. `save_state.py` 嘅 `detect_decisions_from_session()` 係 stub —
       永遠 return `[]`,所以 Decisions section 唔會被 fill。
    2. `read_recent_session_turns()` 用 `hermes sessions list`
       (metadata only),唔讀真正 message content。
    3. `template.replace()` 漏咗大部分 placeholder(只 hit `branch`,
       `commit`, `uncommitted changes` 嗰 3 個),所以 Decisions /
       Files touched / Next Steps / Risks / Insights section 全部
       留 default 文字。
  - 修復中: `save_state.py` 嘅真正 fill 版(Patch D 設計中)。
  - 短期 workaround(呢個 document 嘅目的):Resume 之後,手動
    overwrite `dev-task-state.md`,fill 真正 state。

Workaround Recipe(Resume 之後 30 秒內做):
  1. `cat ~/www/<project>/docs/_meta/dev-task-state.md` 確認係 generic
     template
  2. 用以下結構 fill(對齊 crm-system 嘅 Day 11 真實 state pattern):

```markdown
## 🎯 Goal (一句話)
<一句話講清楚完成咗啲咩 + 仲有咩 pending>

## 📋 Decisions (with WHY)
1. **<decision 1>** — 點解揀
2. **<decision 2>** — 點解唔揀其他

## 🏗️ Current State
### Files touched (in this task)
| File | Status | Last edit |
| `<file>` | `M` / `NEW` | Day N — brief |

### Git state
- **Branch**: `<branch>`
- **Last 4 commits**:
  ```
  <SHA-7> <subject>
  <SHA-7> <subject>
  ...
  ```
- **Working tree**: clean / dirty (有 N 個 M + N 個 ??)

## ⏭️ Next 3-5 Steps
1. [ ] <step 1 — concrete file path>
2. [ ] ...

## 🚨 Risks / Blockers
- <risk or "None">

## 🧠 Key Insights
- **<insight 1>**: 對齊 6/6 lesson / Day 9 lesson 嘅 format
```

  3. Save。Agent 下一個 turn 會 read 返 file,睇到真正 state。

Why not just fix the script?
  - Skill 限制:review 階段只可改 SKILL.md / references / templates /
    scripts(透過 skill_manage action=edit)。改 scripts 需要完整
    re-write(save_state.py 500+ lines)。
  - Workaround 比較 safe:agent 識得 fill 真正 state,generic template
    變 fallback。

Future fix blueprint (留低做 Sprint N+1):
  - `save_state.py` 改用 sqlite3 讀 `state.db` 嘅 `messages` table
    (FTS5-backed)
  - `detect_decisions_from_session` 改 regex extract "Q1=A",
    "我哋做 X", "Decision:" 標記
  - Template replace 補返所有 placeholder(Decisions, Files touched,
    Next Steps, Risks, Insights, References)
  - 加 `--read-recent` flag 俾 `recovery.sh` 自動 `--read-recent --limit 20`

Verification: Day 11 Phase 1 / Day 10.1 兩個 case study 喺
`docs/retros/2026-06-09-recovery-template-limitation.md`。
