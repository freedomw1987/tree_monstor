# Smoke-before-Merge Flow — Trunk-based 4-phase PR pattern

Class-level pattern for shipping any non-trivial feature branch. Discovered
2026-06-07 crm-system Day 14.7 (System Settings + Tax Rate + Deal Autocomplete)
when David asked "Smoke 過完才 merge 會好點?" — answered "係" + 補完
4-phase flow + 3 `/tmp` script chain.

## 為什麼 smoke-before-merge 重要

**Trunk-based rationale**:
- 壞咗唔污染 main history(唔需要 revert merge commit)
- staging host 完整 verify 過 main 自己有 promise 嘅 quality
- 紅線 4 (環境隔離) 守住:dev rebuild OK,prod rebuild 留 David
- Post-merge fail = revert,post-merge pass = ship

**舊 "dev host 跑過就 merge" 嘅 problem**:
- Dev host 通常有 1+ 個 uncommitted file,build 過唔代表 prod build 過
- Dev `docker compose up` 跑嘅 image bake 早過 latest commit = stale bundle
- Dev 直接 push 落 main = 冇 staging gate,prod 就係 first 個 customer

## 4-phase flow

```
Phase 1: Pre-merge  ── dev host
  1a. Recipe A check (untracked providers)
      bash $SKILL_DIR/scripts/post_recovery_untracked_check.sh
  1b. 1-click commit untracked providers
      bash templates/commit-untracked-files.sh
  1c. 1-click push to origin
      bash templates/push-after-commit.sh

Phase 2: Staging smoke ── staging host
  2a. checkout branch + pull
      git fetch origin
      git checkout <branch>
      git pull origin <branch>
  2b. apply prisma migration drift check
      docker compose ... run --rm api bunx prisma migrate deploy
      docker compose ... run --rm api bunx prisma migrate status
  2c. rebuild + bring up
      docker compose ... up -d --build web api
  2d. run 14-step E2E smoke
      export ADMIN_USER=... ADMIN_PASS=...
      bash templates/smoke-before-merge.sh
  2e. if smoke FAIL → DO NOT MERGE,回到 Phase 1 fix

Phase 3: Merge ── dev host (smoke 過咗之後)
  3a. git checkout main
  3b. git merge --no-ff <branch>
  3c. git push origin main

Phase 4: Prod deploy ── prod host (紅線 4, 完全留 David)
  4a. git pull origin main
  4b. docker compose ... run --rm api bunx prisma migrate deploy
  4c. docker compose ... run --rm api bun run db:seed (RBAC re-seed)
  4d. docker compose ... up -d --build web (rebuild image)
  4e. post-deploy smoke (same 14 steps, run on prod)
```

## 3 `/tmp` script 嘅 chain 設計

**每個 script 跑完 print 下一個 command**,David 唔需要記住順序:

```bash
# commit-untracked-files.sh 結尾:
echo "Next step: bash templates/push-after-commit.sh"

# push-after-commit.sh 結尾:
echo "Next step: ssh staging-host; bash templates/smoke-before-merge.sh"

# smoke-before-merge.sh 結尾:
echo "Next step: git checkout main && git merge --no-ff <branch>"
```

**好處**:
- David 淨係需要記住第 1 個 script, 之後 paste-and-run
- Agent 寫 PR description 時 reference 同一套 script 編號 (Phase 1/2/3/4)
- Smoke failed 自動 abort (`exit 1`) → David 唔會手賤 merge 過 smoke-failed branch

## 14-step smoke 嘅 reference list

唔係每個 stack 都同 crm-system 一樣, 以下係 generic 14 steps + 點樣 adapt:

| # | crm-system 2026-06-07 step | Generic equivalent |
|---|----------------------------|--------------------|
| 1 | Login as Admin | Login as test user (admin) |
| 2 | GET /api/auth/me | GET /api/me (verify JWT works) |
| 3 | 7 settings tabs reachable | All top-level resources return 200 |
| 4 | GET tax.rate | GET a "version-pinned" config value |
| 5 | PUT tax.rate=17 | PUT a config value, expect echo |
| 6 | GET tax.rate=17 (verify) | GET same config, expect updated value |
| 7 | Restore tax | Restore original (avoid polluting next test) |
| 8 | Audit log entry created | Verify write was logged |
| 9 | GET /api/deals | GET a list endpoint, expect ≥1 row |
| 10 | QuotationBuilder tax prefill | Verify downstream consumer uses updated config |
| 11 | /deals bundle includes filter UI | GET /, parse HTML, find bundle hash, verify feature string in bundle |
| 12 | /quotations bundle 同上 | Same as 11, but for sibling route |
| 13 | 3 untracked files now tracked | `git ls-files --error-unmatch <file>` 3 times |
| 14 | Bundle Last-Modified fresh | `curl -I <bundle> \| grep Last-Modified` matches image bake time |

**每步嘅 design principle**:
- Step 1-2: prove auth works (冇 auth = 100% fail other steps)
- Step 3-7: prove CRUD round-trip on a real config
- Step 8: prove side-effect (audit log) actually fires
- Step 9-10: prove list + downstream consumer
- Step 11-12: prove client bundle includes new feature (防 stale bundle)
- Step 13: prove Recipe A fix landed (untracked → tracked)
- Step 14: prove image freshness

## 點樣 adapt 到其他 stack

**Backend-only (FastAPI / Express / Hono / Elysia)**:
- Skip Step 11-12 (冇 SPA bundle)
- Replace Step 9-10 with: GET list, POST/PUT, GET single, verify diff
- Keep Step 13-14 if applicable (git verify + image last-modified)

**Mobile (React Native / Swift / Kotlin)**:
- Replace Step 11-12 with: build artifact contains new feature string
  (`unzip app.apk | grep -c "NEW_FEATURE"`)
- Step 14 becomes: app version code incremented

**純 backend library (e.g. publish to npm)**:
- Skip Step 11-12-14
- Add Step 15: `npm pack`, verify tarball includes new files

## PR description 嘅 reference 寫法

```markdown
## Merge plan (Smoke-before-Merge flow)

[Trunk-based rationale 1 sentence]

### Pre-merge — Step A: 1-click commit untracked files
\`\`\`bash
bash templates/commit-untracked-files.sh
\`\`\`
[Expected output]

### Pre-merge — Step B: push to origin
\`\`\`bash
bash templates/push-after-commit.sh
\`\`\`

### Pre-merge — Step C: staging smoke
\`\`\`bash
ssh staging-host
cd /opt/<project>
git fetch && git checkout <branch> && git pull
docker compose ... run --rm api bunx prisma migrate deploy
docker compose ... up -d --build web api
export ADMIN_USER=... ADMIN_PASS=...
bash templates/smoke-before-merge.sh
\`\`\`

[14-step expected output summary]

**Smoke failed = DO NOT MERGE。**

### Merge
\`\`\`bash
git checkout main
git merge --no-ff <branch>
git push origin main
\`\`\`
```

crm-system 2026-06-07 PR description 嘅 `Merge plan` section 係 full 例子
(`/tmp/pr-description-feat-system-settings.md` line 126-191)。

## Related

- `references/post-recovery-verification.md` — Recipe A (untracked) + Recipe B (stale bundle),Smoke 之前必跑
- `references/e2e-smoke-script-authoring.md` — Hermes-redact-safe smoke script pattern
- `templates/commit-untracked-files.sh` — Phase 1a
- `templates/push-after-commit.sh` — Phase 1b
- `templates/smoke-before-merge.sh` — Phase 2d
- `interruption-recovery/SKILL.md` ⚠️ Day 14.7 Final Lesson 段 — 4-phase overview
