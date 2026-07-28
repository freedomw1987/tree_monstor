# pm-system Sprint 13 failure-triage case history

## Pattern 8: Playwright 撞 pre-existing failure 嘅 triage(2026-06-10 pm-system Sprint 13)

### 問題

Sprint closure 跑 full E2E suite,撞 N 個 pre-existing failure(eg 4/55 fail)。**唔係所有 failure 都可以用 helper patch 解決** — 部分係**真實 backend bug**。盲目用「`describe.skip` + DEPRECATED comment」掩蓋 security bug = 紅線 13 違規(冇 RG entry 嘅 fix 唔可以 merge)+ 紅線 14 違規(冇 root cause + prevention)。

### Diagnostic 步驟(7 個 step,3 個 tool call 以內)

1. **Step 0:`git status -s` 睇有冇上一個 session 漏 commit 嘅 fix**(disk 有 source code 但 HEAD 冇)— 直接 commit + 唔好從頭再寫
2. **Step 0.5:`docker exec <backend> cat /app/src/routes/<file>.ts | grep <fn>` 確認 running container 嘅 source 同 disk 一致** — disk 有 fix 但 container running stale = rebuild + restart,唔係 bug
3. **Step 1:`npx playwright test <failing-test-name>`** 跑單一 test,睇 root error
4. **Step 2:睇 backend log 嘅實際 response**(唔靠 mental model)— `docker compose logs backend | tail -30`
5. **Step 3:睇 stack trace 嘅 source code**(必 `grep` 真實 file,例如 `grep -n "developer" backend/src/routes/tasks.ts`)— skip helper 通常係 sprint 7-9 引入嘅 P0 spec 加 `describe.skip`,而新 spec 直接寫 assertion 會揭真實 bug
6. **Step 4:直接 hit API reproduce**(用 curl + 已知 user role)— 確認係「test 期望錯」定「backend 真係錯」
7. **Step 5:判定每個 failure 嘅 root cause class**:
   - **A. Test-helper bug** — seed data 名變咗(Sprint 8+ docker entrypoint 改咗),或者 IP rate-limit 撞 → patch helper(Pattern 7 fallback 適用)
   - **B. Test expectation bug** — spec 期望 `expect(status).toBe(403)` 但 backend 返 200,**可能係 test 寫錯**或者**可能係 backend 真係 security bug**。要 reproduce 確認
   - **C. 真實 backend bug** — `curl PUT /api/tasks/:id -H "Authorization: Bearer dev-token" -d '{"title":"hijack"}'` 返 200,backend 真係漏 RBAC gate

**完整 7-step playbook + 撞過嘅 reproduce 例子** 喺 `references/pre-existing-failure-triage.md`。

### Triage 4-option table 寫法(必修,成段 ship 嘅 critical part)

**唔可以**直接撞 option。寫一段 4-option triage table 俾 user 揀,跟 `feature-plan-alignment` 嘅 4-option pattern:

| # | Option | Scope | 預估 | 風險 |
|---|--------|-------|------|------|
| 1 | 只修 helper(test bug) | Spec-only | 20 分鐘 | 紅線 13 守,但 D 漏住 production 漏洞 |
| 2 | **修 helper + 修 backend + 加 unit test 守住 invariant** | Spec + Backend | 45 分鐘 | **全綠,紅線 13/14 都守** |
| 3 | 修 helper + 修 backend 但唔加 unit test | Spec + Backend (小) | 30 分鐘 | Backend 修咗但冇 invariant test,將來可能返轉 |
| 4 | 全部 `describe.skip` + DEPRECATED label(同 Sprint 11 `/bugs` 拎走個做法) | Docs-only | 10 分鐘 | Test 表面乾淨但 security bug 留喺 production |

**我推薦 Option 2** — 因為 D 係真實 security bug,紅線 13 + 14 規定 bug fix 必須有 root cause + prevention + regression test entry。**skip-without-fix 唔合規**。

### 判斷「test bug vs backend bug」嘅 3 條 heuristic

| 線索 | 偏向 test bug | 偏向 backend bug |
|------|---------------|-----------------|
| Test 期望嘅 status code | 期望 `4xx` 但 backend 返 `2xx` | 期望 `4xx` 但 backend 返 `2xx`(backend 真係漏 gate) |
| Curl reproduce | Curl 一樣返錯 status(backend 真錯) | Curl 返 200(spec 期望錯) |
| 改 backend 後 test 過唔過 | N/A | 改 backend return 403 → test 過咗 = backend 真係 bug |
| Production audit log | N/A | 有 user 用 developer role 改 title = backend bug 已被 exploit |
| Code comment 寫住 `// TODO` / `// FIXME` | N/A | Backend 有 `// TODO: enforce RBAC` = known bug,未有 RG entry(紅線 13 違規) |

**`// TODO` / `// FIXME` 嘅 code comment 係 highest signal** — 個 project 知道有 bug 但冇 RG-XXX entry = 紅線 13 違規 = 必須修 + 加 entry + 加 test。

### 「fix 名義 = 移除 / deprecate」唔等於 cleanup 嘅 pitfall

撞過(Sprint 13 plan):舊 test 用 `describe.skip` + DEPRECATED comment 掩蓋 RBAC bug,**新 spec 寫斷言 `expect(403)` 反而揭發 backend 真係漏 gate**。**新 spec 唔可以默守舊 spec 嘅 skip pattern** — 必須 reproduce + 4-option triage + Option 2 default。

### 配套 checklist(任何「Playwright failure → 4-option triage」session 必跑)

- [ ] 跑 full E2E,grep 出 pre-existing failure list
- [ ] 對每個 failure 跑 `npx playwright test <name>` 拎 root error
- [ ] 對每個 failure curl reproduce 確認係 test bug 定 backend bug
- [ ] 寫 4-option triage table(結構跟 `feature-plan-alignment` § "Output structure")
- [ ] 預設 recommendation = Option 2(紅線 13/14 合規)
- [ ] User 揀咗之後先動 code,唔好 default 落 Option 4(skip-without-fix)

---


## Additional extracted project-specific wording

## Pattern 6: Testing Tiptap / ProseMirror rich text editors(2026-06-10 pm-system)

**Scope**: 任何用 Tiptap 嘅 React rich text editor(`<RichTextEditor value={x} onChange={setX} />` 帶 `.ProseMirror` contenteditable)— 通用於 pm-system / 將來其他 Tiptap-based apps。

## Pattern 7: Graceful seed-data fallback in test fixtures(2026-06-10 pm-system)

2. ✅ Seed 冇「範例」但有其他 project(Sprint 8+ docker entrypoint 改咗)

## Extracted legacy reference list

## 參考文件

- `references/caller-ip-isolation.md` — Per-test IP 完整 implementation 細節 + 點解 stable hash 而非用 Date.now
- `references/workers-parallel-design.md` — 邊度用 workers=1 vs parallel, shared seed 嘅 trade-off
- `references/stack-health-diagnostic.md` — Docker stack 起唔到 4 個 root cause(Vite build silent fail / Prisma 7 strict validation / volume mount 漏 migration / external dep miss)+ Stack health 100% checklist
- `references/tiptap-paste-patterns.md` — Tiptap / ProseMirror rich text editor E2E testing: 3 個 pitfall + 1 個 workaround template
- `references/pre-existing-failure-triage.md` — Sprint closure 撞 pre-existing failure 嘅 **7-step diagnostic**(Step 0: git status, Step 0.5: docker exec source check, Step 1-5)+ 4-option triage pattern(2026-06-10 pm-system)+ pm-system Sprint 13 嘅 4 個 failure 嘅 root cause 預分析
- `templates/_helpers.ts` — 已經 verified 嘅 `loginAs` helper(pm-system production use, 2026-06-09)
