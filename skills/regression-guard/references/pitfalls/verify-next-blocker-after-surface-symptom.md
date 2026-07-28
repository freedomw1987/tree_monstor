# ⚠️ Pitfall — 解決 surface symptom 之後必 verify 下一個 blocker(cross-stack iteration loop, 2026-06-09 pm-system)

**場景**:Sprint 5 closure,David 講「馬上處理埋 frontend build 不到的問題」。我發現 frontend `WorkLogsPage.tsx:413` 嘅 `await` in non-async `onClick` 阻 Vite build。Fix 之後,跟住跑 `docker compose up -d --build` 想 verify E2E 跑得通,**但撞第二個 blocker**:`backend` container exit(1),log 報:
```
Prisma schema loaded from prisma/schema.prisma.
Error: The datasource.url property is required in your Prisma config file
when using prisma db push.
```

呢個 issue 唔關 frontend fix 事,**亦唔關 TD-003/004/014 事**。係 Sprint 3 sibling 引入 `prisma.config.ts` 嗰陣漏咗 Dockerfile `COPY` + `prisma.config.ts` 用咗 `process.env["..."]` 唔接受嘅 Prisma 7 strict validation。

**Cross-stack iteration loop**(2026-06-09 親驗要識用):

```
User: 「處理埋 X」
    ↓
Fix X(可能係 frontend build / backend error / docker stack 起唔到)
    ↓
Verify X 修咗(rerun docker build / docker compose up)
    ↓
撞下一個 blocker(可能關 Y,Z,完全唔關 X)
    ↓
Ask user: 「Fix X 之後再撞 Y,要唔要連 Y 一齊清?」
    ↓
Yes → loop(每個 blocker 視為獨立 task 收 todo + commit)
No → 留 Y 喺 TECH-DEBT + commit
```

**關鍵 rule**(David 嘅「馬上處理埋 X」cue):
1. **不要悶頭一個 fix 完就 ship**。每次 fix surface symptom 之後,**必 verify stack 真正 work**(docker compose ps / curl health endpoint / 跑 E2E 一輪),而唔係「我覺得 fix 咗就 fix 咗」。
2. **撞下一個 blocker 唔好 assum 屬今次 scope**。Ask user 確認 scope,尤其 blocker 係 sibling 引入嘅 regression 嗰陣(我撞嘅 Prisma 7 係 Sprint 3 sibling 嘅 fix 引入,非今次 scope)。
3. **每個 blocker 視為獨立 task**。3 個 P1 fix 之後撞 Prisma 7 — 唔可以將 Prisma 7 fix 偷渡入 Sprint 5 commit。**要獨立 commit message + RG entry + REGRESSION-GUARD.md entry**。
4. **「同一個 task 包多個 blocker」係 anti-pattern**。David 嘅「failure-state cue pattern」(A / B / C / 停 / 收工)代表「解決嗰個,然後停,等下個 cue」,唔係「解決嗰個 + 順手 N 個」。

**反例 — 我今次差啲做錯嘅嘢**:
David 講「馬上處理埋 frontend build 不到的問題」,我 fix frontend 之後,直接走去 debug docker stack 嘅 Prisma 7 issue,**冇 confirm scope**。好彩 David 用 clarification tool 回應「改 prisma.config.ts: import + env 2 行, root cause fix」先做,**否則我會 silent scope-creep 將 Prisma 7 fix 塞入 Sprint 5 commit,污染 commit history**。

**Prevention checklist**(收到「處理埋 X」cue 之後):
- [ ] 確認 X 嘅 surface symptom(symptom ≠ root cause)
- [ ] Fix X 嘅 root cause
- [ ] Verify X 修咗(stack 真正 work,not「我覺得」)
- [ ] **撞下一個 blocker 必 ask user 確認 scope**(`clarify` tool,2-4 個 options)
- [ ] 如果 user 確認 scope:**獨立 commit + 獨立 RG entry**,唔好混入原本 task
- [ ] 如果 user 唔確認 scope:**TECH-DEBT.md 記低 + 提交 blocker report**,唔好 silent 處理

**Detection signal**(出現以下就要 stop and clarify):
- User cue 講「A」但你手頭撞住 B、C、D 嘅 fix
- 你嘅 todo list 越加越長但冇 user 確認過
- Commit message 講 1 個 fix 但 git diff 顯示 N 個 file 改動,當中 K 個 file 唔關原本 task
- 你嘅 todo list 入面「fix X + fix Y + fix Z + 順手 audit」> 5 個 items

**Lesson**:**收到「處理埋 X」cue → fix X → verify X → ask user about next blocker, 不要悶頭做**。Cross-stack scope 嘅 iteration loop 必須 explicit clarify,**user 嘅 failure-state cue 係「解決嗰個 + 停 + 等下個 cue」**, 唔係「解決嗰個 + 順手 chain reaction fix N 個」。

---
