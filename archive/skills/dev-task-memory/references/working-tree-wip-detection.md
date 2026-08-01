# Working-Tree WIP Detection — Coexistence With David

Day 11 lesson (2026-06-09): When agent 喺 same worktree commit work,
David 可能同時用同一個 worktree 做 WIP changes(5 個 modified + 3 個
untracked,全部唔屬於 agent 嘅 scope)。`git add .` 會 mix 埋一齊,
overwrite David 嘅 uncommitted changes 喺 commit series 入面。

## Symptom

`git status --porcelain` 顯示一堆 M 同 ??,**部份**係 agent 嘅 scope,
**部份**係 David 嘅 WIP。Agent 用 `git add .` 之後 `git commit -m "feat: ..."`
會將 David 嘅 WIP **綁入** agent 嘅 commit,即使 David 冇 push 都會
出現喺 local working tree 嘅 next commit,甚至被 push 落 origin/main。

## Detection Recipe(commit 前必做)

```bash
cd ~/www/<project>

# 1) Full status
git status

# 2) Porcelain output — 短格式方便 grep
git status --porcelain

# 3) Stat 總覽(每個 modified file 嘅 +/- 行數)
git diff --stat HEAD

# 4) 最近 10 個 commit 嘅 subject
git log --oneline -10
```

睇返 4 個 output,將 file 分 3 類:
- **Agent 嘅 scope** (modified by 你今次 task)— 揀出嚟 `git add <file>`
- **David 嘅 WIP** (modified by David 之前嘅 WIP, comment 入面有
  今日日期、recent dates 唔屬於 agent)— **唔可以 add**
- **Untracked** (`??` prefix)— 睇返 file 內容/owner comment,
  屬於 David → **唔可以 add**

## Pitfall: David 嘅 WIP 唔一定 stash 咗

David 嘅 WIP 可能係 staged **或** unstaged。`git status --short` 入面:
- ` M` (space + M) = unstaged modified
- `M ` (M + space) = staged modified
- `M ` (M + space, 第二 column 空) = staged + 跟住 un-staged (mixed)
- `??` = untracked

如果 agent 用 `git add <file>` 揀返,untracked 唔會自動 add(要 explicit
`git add <file>`)。`git commit -a` 唔 add untracked,所以 `git add .`
先係危險嘅 command(將所有 untracked 都加入)。

## Selective Commit Recipe

```bash
# Step 1: List agent 嘅 scope 嘅 files (人手 judge)
# 例如 Day 11:
#   - apps/api/src/index.ts (M)
#   - apps/api/src/routes/settings.ts (NEW)
#   - apps/web/src/pages/settings.tsx (NEW)
#   - apps/web/src/lib/api.ts (M)
#   - docs/PRD.md (M)
#   - packages/ai/src/tools.ts (M)
#   ...

# Step 2: Selective add
git add \
  apps/api/src/index.ts \
  apps/api/src/routes/settings.ts \
  apps/web/src/pages/settings.tsx \
  apps/web/src/lib/api.ts \
  docs/PRD.md \
  packages/ai/src/tools.ts \
  ...

# Step 3: Verify
git diff --cached --stat

# Step 4: Commit + 留低 David 嘅 WIP 喺 working tree
git commit -m "..."

# Step 5: Push + 確認 David 嘅 WIP 仲喺度
git push
git status --short  # 應該見到 David 嘅 WIP 仲 untracked/modified
```

## Case Study: crm-system Day 11 Phase 1 (2026-06-09)

- Agent scope: backend (settings.ts, index.ts, tools.ts, prompts.ts) +
  frontend (settings.tsx, lib/api.ts, App.tsx, layout, package.json) +
  doc (PRD.md, QA-TRACKER.md, api.md)
- David WIP detected: `apps/api/src/routes/deal.ts` (M, comment `2026-06-09`
  multi-select filter) + `quotation.ts` (M) + `deals.tsx` (M) +
  `quotations.tsx` (M) + 3 個 `multi-*.tsx` untracked components
- Selective add: 13 個 file 落 commit,David 嘅 5M + 3?? 留低
- Result: 4 個 atomic commit 推到 origin/main,**冇 touch** David 嘅 WIP

## Red Lines (Day 11)

- **紅線 34**:**Commit 之前必 `git status --short` + `git diff --cached --stat`**
  三秒,確認 staged 嘅 file 全部屬於 agent 嘅 scope,冇夾雜 David 嘅 WIP
- **紅線 35**:**David 嘅 WIP 唔可以入 agent 嘅 commit** — 即使 local working tree
  冇衝突,將 David 嘅 modified file 落 commit 會 overwrite David 之後嘅
  `git commit` 系列(雖然 file content 一樣,但 commit metadata + author 唔係
  David 嘅,違反「唔可以 overwrite David 嘅 commit」紀律)
- **紅線 36**:**Push 之前必 `git log --oneline origin/main..HEAD` + `git status --short`**
  確認 David 嘅 WIP 仲喺 working tree(對齊 6/6 revert lesson)

## 對齊其他 skills

- `regression-guard` (existing): 講「bug fix 必須有 RG-XXX」,但
  **冇** 講「git commit scope 必須乾淨」— 呢個 reference file 補嗰缺點
- `dev-task-memory/references/subagent-wip-pickup-recipe.md`:
  講 subagent 嘅 WIP pickup(不同嘅 problem class),呢個 file 講
  **David + agent 同 worktree** 嘅 WIP coexistence
