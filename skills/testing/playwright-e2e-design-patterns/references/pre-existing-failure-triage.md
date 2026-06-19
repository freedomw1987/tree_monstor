# Pre-existing E2E failure triage — playbook + real example

> **Pair with**: `playwright-e2e-design-patterns` SKILL.md § Pattern 8
> **Last verified**: 2026-06-10 (pm-system Sprint 13 setup)
> **Author**: David + main agent (RootSystem + Developer profile)

## 為什麼需要呢個 playbook

Sprint closure 跑 full E2E suite 撞 N 個 pre-existing failure 係**必然發生**(5-15% 嘅 suite 一路以來都 fail,但 sprint 期間冇時間處理)。**盲目** 用 3 個 anti-pattern 收場 = 紅線 13/14 違規:

1. **「`describe.skip` + DEPRECATED comment」掩蓋 security bug** — 撞過 crm-system Sprint 11 拎走 `/bugs` 嗰陣 skip 6 個 test,但**新 spec 寫 `expect(403)` 反而揭發 backend 真係漏 RBAC gate**。skip 完唔等於修咗。
2. **「helper patch only」處理 backend bug** — 用 Pattern 7 嘅 fallback pattern 改 helper,但 backend 嘅 real RBAC bug 仍然喺度
3. **「fix without test」** — 修 backend 但冇 unit test 守住 invariant,將來 refactor 返轉

呢個 playbook 教點樣 diagnose 4 個 failure → 分類 test-bug vs backend-bug → 寫 4-option triage → default Option 2(修 + 測試)→ commit series。

---

## 7-step diagnostic procedure(2026-06-10 Sprint 13 — 加 Step 0 + 0.5)

### Step 0: 先 git status — 上一個 session 可能已經寫咗 fix 但冇 commit

**撞 E2E failure 嘅第一步,唔係 reproduce,而係 `git status -s` 睇有冇 uncommitted work**。Sprint 12 收工後 (pm-system 2026-06-10) 試過:Sprint 13 開工時發現 5 個 files (backend RBAC fix + unit test + RG entry + tracker updates) 已經 modify 但**冇 commit** — 之前 session 寫咗但漏咗 `git add . && git commit`。

```bash
# Step 0a: 睇有冇 uncommitted work
cd ~/www/<project>
git status -s
# Output 例子:
#  M backend/src/routes/tasks.ts        ← RBAC fix 未 commit
#  M backend/src/routes/tasks.test.ts   ← boundary test 未 commit
#  M docs/REGRESSION-GUARD.md           ← RG-015 entry 未 commit
#  M docs/QA-TRACKER.md                 ← tracker update 未 commit
#  M e2e/tests/bugs-fix.spec.ts         ← helper patch 未 commit

# Step 0b: 如果有未 commit 嘅 work,睇下佢啱唔啱
git diff backend/src/routes/tasks.ts | head -50
# 已經 fix 過嘅 RBAC bug? 已經加咗 unit test? 已經有 RG entry?
# → 直接 commit + push (唔好從頭再寫)
```

**撞過 pitfall (2026-06-10 pm-system Sprint 13)**:我以為要自己 patch backend `tasks.ts` 嘅 RBAC gate,`patch` 嘅 `old_string` match 錯位刪咗另一個 function (`getFirstBugId` 撞 `getSampleProjectId` 嘅 JSDoc 開頭)。最終發現 backend 早已有 `canEditTaskFields` 純 function + 9 個 boundary test,只係**上一個 session 漏 commit**。**浪費 5-10 個 tool calls 重新 audit + recover file**。教訓:`git status -s` 必須係 first step。

### Step 0.5: 確認 running container 嘅 source code 同 disk 一致

Docker-based dev stack 嘅**經典 trap**:`backend/src/routes/tasks.ts` 已經改咗,但 `<project>-backend-1` container 仲 running 緊**舊 image**(冇 rebuild)。**Disk 同 running code 唔 sync**。

**快速 check** (5 秒):
```bash
# 對 backend 個 file,睇 running container 嘅 source 係咪同 disk 一致
docker exec <backend-container> cat /app/src/routes/<file>.ts 2>/dev/null | grep -c "functionName"

# 對比 disk version
grep -c "functionName" backend/src/routes/<file>.ts

# 兩個 number 唔一致 → container running stale code
# → 唔好浪費時間 re-fix 已經 fix 過嘅嘢,rebuild + restart 先
```

**撞過 (2026-06-10 pm-system)**: 我跑 `curl PUT /api/tasks/:id` 用 dev token 真係返 200,以為 backend 真係漏 RBAC gate(預備要 patch tasks.ts 嘅 if-else 結構)。**後來發現** container 內 `/app/src/routes/tasks.ts` 早已有 `canEditTaskFields` function + 9 個 boundary test(RG-015 entry 喺 REGRESSION-GUARD.md 都寫咗)— 純粹係**之前 session 漏咗 commit** 而唔係 bug 存在。**Step 0 + Step 0.5 一齊跑會避免呢個 confusion**。

**重要**:呢個 check 對 E2E failure triage 嘅影響:
- 如果 disk 冇 fix + container 都冇 fix → 真實 bug,要修
- 如果 disk 已經有 fix + container 都有 fix → 之前漏 commit,直接 commit
- 如果 disk 已經有 fix + container 冇 fix → 漏 rebuild,rebuild + restart

### Step 1: 跑 full E2E,collect failure list

```bash
cd ~/www/<project>/e2e
npx playwright test 2>&1 | tail -30
```

**Output 例子**(pm-system 2026-06-10):
```
3 failed
  [chromium] › tests/bugs-fix.spec.ts:381:9 › Bug fix 2026-06-09 — 7 bugs P0 regression › Attachments tab image preview + download › image attachment renders <img> preview thumbnail and lightbox (bug #5)
  [chromium] › tests/bugs-fix.spec.ts:466:9 › Project card click navigation › clicking anywhere on project card (not just name) navigates to detail (bug #8)
  [chromium] › tests/project-kanban.spec.ts:284:7 › US-4.5 (Sprint 10): Project Kanban status 變更 › RBAC: developer 改 status 只限於自己 assignee 嘅 task
```

### Step 2: 對每個 failure 拎 root error

```bash
npx playwright test <failing-test-name> 2>&1 | grep -A 8 "Error:" | head -20
```

**Output 例子**:
- `bugs-fix.spec.ts:381` → `Error: expected a sample project to be seeded`(seed data 名變咗)
- `bugs-fix.spec.ts:466` → `Error: expected a sample project to be seeded`(同 helper)
- `project-kanban.spec.ts:284` → `Error: expect(received).toBe(expected) // Object.is equality` + `Expected: 403` + `Received: 200`

### Step 3: 對每個 root error 判定 class

| Root error pattern | Class | Action |
|---|---|---|
| `expected <seed-data-name> to be seeded` | **A. Test-helper bug** | Pattern 7 fallback |
| `expected <X> toBe <Y>` 但係 (a) 冇 seed 字眼,(b) 涉及 4xx/5xx status | **B. Test expectation OR backend bug** | 落 Step 4 reproduce 確認 |
| `expected <X> toBeVisible` 但係 timeout | **A. Test-helper bug** (可能 backend 真係冇呢個 UI element) | 落 Step 4 reproduce |
| Curl `PUT /api/X` 真係返錯 status(backend log 都印) | **C. 真實 backend bug** | 落 Step 4 reproduce 確認 |

### Step 4: Reproduce 確認(curl + grep source code)

**對每個 B/C class failure**:

```bash
# 1. Login 拎 token
ADMIN_TOK=$(curl -s -X POST http://localhost:4001/auth/login \
  -H 'X-Forwarded-For: 127.0.0.99' \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@test.com","password":"admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 2. 用 dev role 撞撞個 endpoint(就係 spec 期望撞 403 嗰個)
DEV_TOK=$(curl -s -X POST http://localhost:4001/auth/login \
  -H 'X-Forwarded-For: 127.0.0.98' \
  -H 'Content-Type: application/json' \
  -d '{"email":"dev@test.com","password":"dev123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 3. 用 admin 建 fixture project + task
PROJ_ID=$(curl -s -X POST http://localhost:4001/api/projects \
  -H "Authorization: Bearer *** -H 'Content-Type: application/json' \
  -d '{"name":"RBAC-test","description":"x"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['project']['id'])")
# (... req, task, etc.)

# 4. Dev role PUT /api/tasks/:id {title:...} 期望 403
curl -s -X PUT http://localhost:4001/api/tasks/$TASK_ID \
  -H "Authorization: Bearer *** -H 'Content-Type: application/json' \
  -d '{"title":"hijacked by developer"}' \
  -w "\nPUT title as dev: %{http_code}\n"
```

**如果 200 OK 確認係 backend 真係漏 RBAC gate** — backend 真實 bug,紅線 13 + 14 違規。

### Step 5: Grep source code 確認真實位置

```bash
# 1. 搵 route file
grep -rn "developer.*title\|hasPermission.*tasks.edit" backend/src/routes/tasks.ts

# 2. 睇個 RBAC gate
sed -n '280,295p' backend/src/routes/tasks.ts
```

**Output 例子**(pm-system 2026-06-10):
```typescript
// Check permission: tasks.edit OR admin/tech_lead for backward compat
if (!user || (!hasPermission(user, 'tasks.edit') && user.role !== 'admin' && user.role !== 'tech_lead')) {
  // Developers can only update status
  if (user?.role === 'developer' && (title || description || assigneeId || ...)) {
    set.status = 403
    return { error: { code: 'FORBIDDEN', message: "Permission denied: 'tasks.edit' is required" } }
  }
}
```

**睇 source code 嘅發現**:
- L282 嘅 outer if 條件:`!hasPermission + 唔係 admin/tech_lead` → developer 入分支(因為冇 tasks.edit 唔係 admin/tech_lead)
- L284 嘅 inner if:developer + 有 title/description → 應該 return 403
- **理論上 work**, 但 `set.status = 403` 喺 inner if 內,**冇 `return set.status`** 而係 `return { error }` — Elysia 嘅 set.status + return 嘅互動可能 fail

**進一步 reproduce**:
- Dev PUT title → 200 OK(backend 真係漏咗 gate)
- 確認係 `set.status = 403` 嘅 Elysia handler 唔 return 個 status

---

## 4-option triage table 寫法(推薦 Option 2)

跟 `feature-plan-alignment` § "Output structure" 嘅 4-option pattern:

```markdown
## Sprint 13 Plan — 修 4 個 pre-existing E2E failure

| # | Failure | Root cause | 修法 | 影響範圍 |
|---|---|---|---|---|
| A | `bugs-fix.spec.ts` #5 attachments | `getSampleProjectId` 搵「範例」失敗(Sprint 8+ docker entrypoint 改咗) | Patch helper 用 T15a 嘅 graceful pattern | 1 helper,~20 行 |
| B | `bugs-fix.spec.ts` #8 project card click (test 466) | 同 A | A 嘅 patch 連帶搞掂 | 0 行 |
| C | `bugs-fix.spec.ts` #8 project card click (test 494) | 同 A | A 嘅 patch 連帶搞掂 | 0 行 |
| D | `project-kanban.spec.ts:284` developer PUT title 預期 403 收到 200 | **真實 backend RBAC bug** | Patch backend `tasks.ts:281-288` | 1 file,~10 行 + 1-2 unit test |

### 4 個選擇

| Option | Scope | 預估 | 風險 |
|---|---|---|---|
| 1 | 只修 helper(A/B/C)+ 確認 D 係真實 bug 入 `REGRESSION-GUARD.md` RG-016,留俾下個 sprint 修 | Spec-only | ~20 分鐘 | 紅線 13 守,但 D 漏住 production 漏洞 |
| **2** | **修 A/B/C + 修 D 嘅 backend RBAC + 加 unit test 守住 invariant** | **Spec + Backend** | **~45 分鐘** | **全綠,紅線 13/14 都守** |
| 3 | 修 A/B/C + 修 D 但唔加 unit test | Spec + Backend (小) | ~30 分鐘 | Backend 修咗但冇 invariant test |
| 4 | 全部 `describe.skip` + DEPRECATED label | Docs-only | ~10 分鐘 | Test 表面乾淨但 D 嘅 RBAC bug 留喺 production |

**我推薦 Option 2** — D 係真實 security-relevant bug,紅線 13 + 14 規定 bug fix 必須有 root cause + prevention + regression test entry。
```

### Why Option 2 default

| 線索 | 偏向 Option 1 / 3 | 偏向 Option 2 |
|------|-------------------|-----------------|
| Bug 涉及 status code(4xx vs 2xx) | 任何 | **Always Option 2**(security bug) |
| Bug 涉及 UI element 唔存在(可能係 frontend 改咗) | 1/3 | (frontend 改可能係 1) |
| Backend source 有 `// TODO: enforce RBAC` 之類 comment | 任何 | **Always Option 2**(known bug 紅線 13 違規) |
| 改 helper 已經 100% work,backend 確認正常 | 1 | (冇 backend bug 唔需要修) |

**`// TODO: enforce X` 嘅 comment 係 highest signal** — 個 project 知道有 bug 但冇 RG-XXX entry,**必須 Option 2(紅線 13 違規)**。

---

## 完整 pm-system Sprint 13 setup 嘅 reproduce

**4 個 failure 嘅 root cause + 修法**(預備 Sprint 13 開工時直接對住做):

### A/B/C — `getSampleProjectId` helper patch

**Root cause**: `bugs-fix.spec.ts:76-85` 寫死 seed data 名 `範例`,Sprint 8+ docker entrypoint 改咗,backend 只係有 `E2E-PG-*` 自動 gen 嘅 fixture projects,**冇 `範例項目` 嘅 seed**。**全部 helper caller 失敗**:`expect(sample, 'expected a sample project to be seeded').toBeTruthy()`。

**修法**:Patch `bugs-fix.spec.ts` 嘅 `getSampleProjectId` 用 Pattern 7 嘅 graceful fallback(搵「範例」→ fallback `projects[0]` → 自己 create)。**3 個 test 全部會過**(同 helper 共用)。

**Optional cleanup**:跟 `regression-guard` §「fix 名義 = 移除 X」pitfall,sprint 13 commit message 順手 audit 其他 `e2e/tests/*.spec.ts` 嘅 `getSampleProjectId` helper — `rbac-negative.spec.ts:173` 已經有 `?? projects[0]` pattern 但冇 self-create fallback。

### D — `project-kanban.spec.ts:284` developer PUT title 真實 RBAC bug

**Root cause**(L281-288 backend `tasks.ts`):

```typescript
if (!user || (!hasPermission(user, 'tasks.edit') && user.role !== 'admin' && user.role !== 'tech_lead')) {
  // Developers can only update status
  if (user?.role === 'developer' && (title || description || assigneeId || assigneeIds || participantIds || parentTaskId || estimatedHours)) {
    set.status = 403
    return { error: { code: 'FORBIDDEN', message: "Permission denied: 'tasks.edit' is required" } }
  }
}
```

**Bug**:
1. `developer@test.com` seed 冇 `tasks.edit` permission(Sprint 1 rolePermissionCache 移除後,seed 對齊 work 但**冇 add 過 `tasks.edit` 畀 developer role**)
2. 落到 L282 outer if → `!user || true`(因為冇 perm 唔係 admin/tech_lead)= true → 入分支
3. 落到 L284 inner if:`user.role === 'developer' && title='hijacked by developer'` → true → 應該 return 403
4. 但 Elysia 嘅 `set.status = 403` 配 return 嘅 sync 機制有 edge case 唔 trigger(可能係 `set` object 已經 mutate,但後面 return 嘅 `set.status` override 走)— developer 200 OK

**Fix**(2 個改動):
1. **`backend/src/routes/tasks.ts:281-288`** 改做 `else` 結構:
   ```typescript
   // 新版
   const hasEditPerm = hasPermission(user, 'tasks.edit')
   if (!user || (!hasEditPerm && user.role !== 'admin' && user.role !== 'tech_lead')) {
     if (user?.role === 'developer' && (title || description || assigneeId || assigneeIds || participantIds || parentTaskId || estimatedHours)) {
       set.status = 403
       return { error: { code: 'FORBIDDEN', message: "Permission denied: 'tasks.edit' is required" } }
     }
     // ← 加呢行:developer PUT status-only 都 OK,fall through 落 prisma.task.update
   } else if (!hasEditPerm && user.role !== 'admin' && user.role !== 'tech_lead') {
     // non-developer non-admin non-tech_lead 冇 tasks.edit → 403 全 field
     set.status = 403
     return { error: { code: 'FORBIDDEN', message: "Permission denied: 'tasks.edit' is required" } }
   }
   ```

   或者更 clean:重組 if-else chain,先 developer 嘅 status-only 守衛,再其他人 嘅全 field 守衛。

2. **`backend/src/routes/tasks.test.ts`** 加 unit test 守住 invariant:
   - 6 個 test case:developer PUT title → 403, developer PUT description → 403, developer PUT assigneeId → 403, developer PUT status-only → 200, admin PUT title → 200, tech_lead PUT title → 200
   - 跟 `unit-test-coverage-push` § 3 derive pattern(如果 helper 唔 export)
   - 跟 `regression-guard` § Step 6 寫 RG-XXX entry

**Optional cleanup**:
- 跟 `qa-tracker-us-closure` § "Multiple US in one commit" 嘅 exception:helper patch 1 個 commit + backend RBAC fix 1 個 commit + unit test 1 個 commit + RG entry 1 個 commit = 4 個 commit series
- 跟 `regression-guard` §「Source-check regression test」pitfall:backend fix 之後要 grep 全部 `developer.*tasks.edit` 嘅 pattern 確認冇其他漏 gate 嘅 endpoint

---

## 配套 checklist(任何「Playwright failure → 4-option triage」session 必跑)

- [ ] 跑 full E2E,grep 出 pre-existing failure list
- [ ] 對每個 failure 跑 `npx playwright test <name>` 拎 root error
- [ ] 對每個 failure curl reproduce 確認係 test bug 定 backend bug
- [ ] 寫 4-option triage table(結構跟 `feature-plan-alignment` § "Output structure")
- [ ] 預設 recommendation = Option 2(紅線 13/14 合規)
- [ ] User 揀咗之後先動 code,唔好 default 落 Option 4(skip-without-fix)
- [ ] Backend fix 必跟 `regression-guard` 8-step flow:reproduce → failing test → root cause → fix → regression test → RG entry → code comment → commit 引用 RG ID
- [ ] Helper patch 必跟 Pattern 7(graceful fallback)避免 sprint N+1 又要再 patch

---

## 何時用

- Sprint closure 跑 full E2E 撞 N 個 pre-existing failure
- User 話「修」「fix the failing tests」
- 跑 `npx playwright test` 撞 4xx/5xx status code 唔係 2xx 嘅 assertion failure
- 撞 `// TODO: enforce X` 嘅 code comment 喺 backend 嘅 RBAC gate

## 唔好用

- 純 helper bug(seed data 名變咗)— 用 Pattern 7
- 純 test typo — 直接 patch
- 純 flaky test(rate limit 撞)— 用 Pattern 1(caller IP isolation)
- 純 docs-only 嘅 E2E follow-up register — 用 `qa-tracker-us-closure` § Sprint follow-up registration

---

## 相關 references

- `playwright-e2e-design-patterns` SKILL.md § Pattern 7(graceful seed fallback)— helper bug 嘅修法
- `regression-guard` SKILL.md § 8-step bug fix flow — backend bug 嘅修法
- `unit-test-coverage-push` SKILL.md — per-US test closure rhythm
- `qa-tracker-us-closure` SKILL.md § Sprint follow-up registration — docs-only 嘅 follow-up 處理
- `feature-plan-alignment` SKILL.md § "Output structure" — 4-option triage table 嘅結構
