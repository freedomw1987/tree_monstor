---
name: subagent-timeout-recovery
description: >
  1) Subagent 執行超時後嘅接管流程 (搶救 partial outputs 而唔係重新 delegation)。
  2) Subagent 準時 return `completed` 之後 parent 必須做嘅 trust-but-verify 步驟
  (subagent summary 係 self-report, 唔係 verified fact)。
  Use when: 派咗 delegate_task 想接管後續 / subagent timeout / subagent 報 done
  但你想 verify 啱先回 user。
version: 1.0.0
metadata:
  tags: [delegation, subagent, timeout, recovery]
  related_skills: [development-watchdog]
---
# subagent-timeout-recovery

Subagent 執行超時後的接管流程。

## 問題

當 subagent timeout 時，它的產出可能已經部分完成（如這個案例：frontend 和 backend 的多個文件都已經建立），只是 subagent 本身未能匯報結果。

## 搶救流程

### Step 1 — 檢查 Subagent 實際產出

```bash
# 列出 subagent 建的目錄結構
find ~/projects/wynn_seat/src -type f

# 檢查關鍵文件是否已存在
cat ~/projects/wynn_seat/src/api/index.ts
cat ~/projects/wynn_seat/src/frontend/package.json
```

### Step 2 — 驗證配置文件

Subagent 常會建好以下文件，需人工確認內容正確：
- `package.json` — scripts、dependencies
- `vite.config.ts` — proxy、port
- `tailwind.config.js` — custom colors、fonts
- `tsconfig.json`

### Step 3 — 啟動並測試

```bash
# 後端
cd ~/projects/wynn_seat && bun run src/api/index.ts &
sleep 2 && curl http://localhost:3001/health

# 前端
cd ~/projects/wynn_seat/src/frontend && bun run dev &
sleep 5 && curl -s -o /dev/null -w "%{http_code}" http://localhost:5174
```

### Step 4 — 快速代碼抽查

不要假設 subagent 的代碼是對的，隨機抽樣關鍵文件：
- API routes 是否完整
- TypeScript types 是否匹配
- 前端 API call 的 URL 是否正確

### Step 5 — 讀取並修正

如果發現問題，用 `read_file` + `patch` 修正，不重寫。

## 關鍵教訓

- **Subagent timeout ≠ 0 產出**。多數會 partial complete
- **不要重新 delegation**，浪費時間且結果相同
- **直接接管**，檢查 → 修補 → 啟動 → 測試
- 複雜任務（full-stack app generation）不適合丟給 subagent，超過 10 分鐘幾乎一定 timeout

## Subagent 撞 typecheck loop 嘅早期 stop 信號 (2026-06-06 crm-system Day 10 實測)

**觀察**: 派 subagent 寫 2 個新 component + 改 2 個 consumer file + 跑 verify (typecheck + HMR), 撞咗 600s timeout。事後 `session_search` 翻睇: **subagent 用咗 63 個 API calls, 全部文件改動喺前 ~30 calls 完成, 之後 ~33 calls 喺 typecheck 階段重複 fix 同一個 type error** (例如 import 漏咗某個 type → fix → 下一個 type error 出現 → 另一個 type error fix → 連環)。

**早期 stop 指標** (到達就 stop 唔好等 600s timeout):
- API calls > 50 而且 subagent 仲喺 `terminal` 跑緊 `tsc --noEmit` / `bun run build` 反覆 verify
- subagent log 顯示重複 `error TSxxxx: ...` > 3 個唔同 error
- 核心文件改動已經完成 (git status 顯示 4/4 file modified)

**Detection (subagent 跑緊 typecheck 階段嘅 signal)**:
1. 已經見到新 component / 修改嘅 file 喺 `search_files` 出嚟
2. `terminal()` 嘅 output 開始重複 `tsc --noEmit` exit code != 0
3. subagent log 出現 "fixed X error, Y remaining" pattern 連續 3+ 次

**Action — 唔好等 600s, ~350s 觀察到 signal 就 kill + 接管**:
```bash
# 接管流程
# 1. 確認核心改動 file 已經存在
search_files pattern="quick-create-*.tsx" path="~/www/<project>/apps/web/src/components"

# 2. 自己跑 typecheck (用 90s timeout, 唔似 subagent 撞 600s)
terminal command="cd ~/www/<project>/apps/web && bun run typecheck 2>&1 | tail -20" timeout=120

# 3. 剩係 fix 真實嘅 type error, 唔好 chase subagent 嘅 false positive
```

**Root cause of subagent typecheck loop**:
- subagent 撞到第一個 type error → 加 `as never` / `as any` cast → 下一個 type error 喺另一個 file → 反覆
- subagent 唔識判斷 "critical fix" vs "nice-to-have cast", 會 chase 每個 warning
- 接手人 (你) 有 context, 知道邊個 cast 啱, 邊個其實係 structural fix

**預防 rule**: 派 subagent 嘅 prompt 寫明:
- 「typecheck 跑一次 fail 就報告, 唔好 chase 連環 cast」
- 「用 `terminal(timeout=120)` 跑 `bun run typecheck`, 唔好 background」
- 「API calls 超過 50 主動 stop」

## 「Subagent 報告 completed ≠ 真係 done」 — trust-but-verify (2026-06-06 crm-system)

**情境**: Subagent 喺 timeout 以內 47 calls 內 return `status: completed` + self-summary 講「所有 phase 完成、typecheck pass」。**唔好盲信** — subagent 嘅 summary 係 self-report, 唔係 verified fact。Subagent 寫嘅 file 可能:
- import path 錯咗 (subagent 睇 file 嘅 cache version, host 已經有 patch 改咗)
- type cast 用咗 `as any` 收場 (technical 過 typecheck 但 runtime 死)
- 漏咗一個 consumer (subagent 唔知全 codebase 嘅 reference graph)
- migration file 寫咗 SQL 但 checksum 計錯 / INSERT `_prisma_migrations` 漏咗 row

**接管後 minimum verification 3 件** (5 分鐘內做得完):
1. **`bun run typecheck` 自己再跑一次** — 唔好信 subagent 嘅 `exit_code 0` claim. Subagent 嘅 final terminal call 可能係 stale buffer / background process.
2. **`search_files` 隨機抽 1-2 個 file grep 關鍵字** — 例如 "Dialog", "onSaved", "useState" — 確認改動真係落咗 host filesystem (subagent workdir 唔同 host 都可能)。
3. **Database-touching changes 必做 smoke**: `docker exec <db> psql` 一句 SELECT 試, 或者 `docker cp` 一個 node script 入 api container 試 prisma 操作。schema drift 唔會喺 typecheck stage 浮現, 一定要落 DB 試。

**實測 case (crm-system 2026-06-06)**: Subagent 報告 5 phases 完成 + typecheck pass。我自己 grep 後發現:
- `servicesApi.create` payload 仍然用 `manDays` 鍵 (502 bug 表面)
- `_prisma_migrations` 紀錄同 filesystem sync 確認過 ✅
- Prisma 落 `services.status` 仍然 TEXT, 唔係 enum

**唔好將 verification 推返畀 user** — David 喺 browser 試先發現, 即係浪費一 round-trip 來回。Parent agent 必須喺回 user 之前自己 verify 關鍵 invariant。

**Subagent prompt 必加嘅一行** (預防):
> "你嘅 summary 我會自己 verify typecheck + grep + smoke test 嘅. 你唔好為咗過 typecheck 而 cast `as any`, 因為我會 grep 嘅."

## 「Uncommitted work 我冇做過」 — pre-`git push` audit gate (2026-06-06 crm-system)

**情境**: David 叫我 `git push`,我行 `git status` 見到 20 個 modified files + 一堆 untracked. 我之前 90 分鐘嘅 session 只動咗 11 個 docs(寫/改/HTML build),其他 14 個 files(API routes、frontend pages、tailwind config、Prisma schema)係**之前 session 留低嘅 uncommitted work**。

**問題**:其中 `apps/api/src/lib/context.ts` 有一個**半完成嘅 auth bug fix**:

```ts
// authContext 而家 empty Elysia instance — 冇 derive
export const authContext = new Elysia({ name: 'auth-context' });

// 新 helper,但 0 個 route file 引用
export async function getUserIdFromRequest(request, jwt) { ... }
```

如果我盲目 `git add .` + `git commit -m "Day 9"`,push 出去會即刻:
- 所有 POST 嘅 `ctx.userId` 變 undefined → 全部 401 reject
- `quotation.ts` 引用咗 `getUserIdFromRequest` 但 export 唔見咗 → build fail

**Rule: 任何 `git push` 之前,做 trust-but-verify on uncommitted work**:

1. **`git status`** 列出 modified + untracked. 分類:今次 session 做嘅(我明白)vs 之前 session 留低嘅(我冇 audit 過)。
2. **對每個 not-this-session file 行 `git diff <file>` 全文**。如果 >50 lines 改動,起碼 grep 關鍵 import/export + function signature 改動。
3. **Trace dependencies**:如果 file A 引用咗 file B 嘅 export,confirm 嗰個 export 真係仲喺度。`git grep "from.*<file>"` + `git grep "import.*<file>"` 列出所有 consumer。
4. **Auth/security file 必跑 `bun run typecheck`**(或者手動 grep 個被宣稱修咗嘅 symbol)。`grep` 唔到 `userId`、`jwt.verify`、`requirePermission` 嘅新用法,代表 fix 唔完整。
5. **唔肯定就 `git checkout -- <file>` 還原**,push 跟住完成,嗰個 file 留返俾原本嗰個 session 嘅作者 finish。

**5 分鐘 audit 慳 30 分鐘 push 完 David 試到壞嘅 round-trip**。

**Anti-pattern**:agent session 之間嘅 uncommitted work 係**implicit handoff**(冇 PR,冇 description)。你接手 push 之前係 first person to actually read 嗰啲 diff。Subagent 嘅 partial output 你會 verify,但**你之前自己 session 嘅 partial output 都應該用同一把尺**。

**crm-system 嗰次實際**:`git diff apps/api/src/lib/context.ts` 顯示「auth fix」comment 講 `derive` 喺 Elysia 1.2 + POST + sibling GET 撞 validator cache 會 silently drop `userId`,個 fix 提議用 onRequest + 設 header。我審計後發現:
- `authContext` 而家 empty
- `getUserIdFromRequest` 寫咗但 0 route file 引用
- `quotation.ts` 引用咗 helper,但因為我頭先 `git checkout -- context.ts` 還原咗,quotation.ts 嘅 import 失效 → typecheck fail
- 我跟手 `git checkout -- quotation.ts` 還原埋佢,先 clean commit

最後拆做 5 個 atomic commits(`feat(day9): ...`, `feat(day9): schema + migrations`, `docs(day9): PROGRESS`, `docs: full reference set + executive PRD/Design`, `docs: self-contained HTML viewer`)push 出去 — 每個 commit scope 清晰,revert 都唔影響其他 work。
