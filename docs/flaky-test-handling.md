# Flaky Test Handling — 偵測 / Quarantine / 修 / 預防 SOP

> **Status:** Canonical. Source of truth for flaky test治理:lifecycle、quarantine 機制、根因分類、預防 checklist、CI 觀測指標。

> **為何需要這份**:Flaky test 係 CI 噩夢 — 跑 100 次過 99 次嘅 test 會(1)block 正常 PR(2)訓練團隊「見紅就 re-run」(3)掩蓋真 bug。**冇 SOP = flaky test 永遠存在**,David 過去 session 已經撞過幾次。

> **配套**:本 SOP 對齊 `docs/qa-gate.md` §6 持續改進 Loop + `docs/testing-strategy.md` 嘅 Test Pyramid 健康指標。

---

## 🎯 Flaky test 定義

**Flaky test** = 同一個 commit / source code,連續 N 次跑出現不一致結果(pass / fail 交替),而**唔係** source code 變動導致。

> **唔係 flaky** 嘅情況(獨立處理):
> - 改咗 source → test 改 fail → 正常
> - 依賴服務 down → 全部 test 失敗 → infra issue,非 flaky
> - 環境變數改變 → config-dependent test → 加 fixture 修正

---

## 🔍 偵測(Detection)

### 指標

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| **Flakiness rate**(過去 30 日) | < 1% | 1-5% | > 5% |
| **Quarantined test 數** | < 3 | 3-10 | > 10(債務過多) |
| **Quarantine 停留時間**(中位數) | < 7 日 | 7-30 日 | > 30 日(遺棄) |
| **同一個 test 因 flaky 阻擋 merge 嘅次數** | 0 | 1-3 | > 3(必 quarantine) |

### 偵測機制

1. **Test runner 內建**(首選):
   - **Jest**:`jest --detectOpenHandles` + `jest-circus` 嘅 retry + report
   - **Vitest**:`vitest run --reporter=verbose` + `--retry=3`(留意:retry 會掩蓋問題,只用作偵測)
   - **Playwright**:`--retries=2` 預設 + `--report-unstable` 顯示 flaky

2. **CI 觀測**(必須):
   ```yaml
   # .github/workflows/test-flakiness.yml
   name: Test Flakiness Tracker
   on:
     workflow_run:
       workflows: ["Test Suite"]
       types: [completed]
   jobs:
     track:
       runs-on: ubuntu-latest
       steps:
         - name: Download test results
           uses: actions/download-artifact@v4
         - name: Compute flakiness
           run: |
             python3 scripts/track_flakiness.py \
               --results test-results.json \
               --window 30 \
               --output docs/flakiness-report.md
         - name: Fail if rate > 5%
           run: |
             rate=$(jq '.flakiness_rate' docs/flakiness-report.md)
             if (( $(echo "$rate > 0.05" | bc -l) )); then
               echo "❌ Flakiness rate $rate > 5% threshold"
               exit 1
             fi
   ```

3. **手動 flag**(輔助):
   - CI 紅咗 → developer 立刻 re-run → 第二次綠 → `gh run comment` 標 `[FLAKY] <test-name>`
   - 每月 review 一次 `gh run list --workflow=test --json conclusion,name | jq ...`

---

## 🚧 Quarantine SOP

**Quarantine** = 暫時跳過某個 flaky test,但**繼續記錄 + 限期修**。**唔係** delete / skip forever。

### Step 1 — 標記

```typescript
// 用 it.skip / describe.skip 加 [QUARANTINE] prefix
describe.skip('[QUARANTINE RG-005] User upload edge cases', () => {
  it('rejects file with unicode name', () => {
    // Owner: @alice, Quarantined: 2026-07-28, Reason: see RG-005
    // Ticket: https://github.com/.../issues/123
  });
});
```

**必填 metadata**:
- `[QUARANTINE <RG-XXX>]` 前綴(RG = Regression Guard;冇 RG = 新 ticket ID)
- Owner
- Quarantined 日期
- Reason / Ticket 連結
- 預計 fix 日期(預設 +14 日,最大 +30 日)

### Step 2 — 註冊

寫入該 project 嘅 flaky-test register(每個 project 一份;非本 profile artifact,採用本 SOP 嘅 project 自行建立):

```markdown
# Flaky Test Register

| Test ID | File | Owner | Quarantined | Reason | Fix By | Status |
|---------|------|-------|-------------|--------|--------|--------|
| RG-005 | test/upload.test.ts#unicode | @alice | 2026-07-28 | unicode filename parser race | 2026-08-11 | OPEN |
| RG-008 | e2e/checkout.spec.ts#payment | @bob | 2026-07-15 | third-party payment mock drift | 2026-08-05 | FIXED 2026-08-02 |

**Rules**:
- OPEN 超過 30 日 = escalate 到 `docs/tech-debt-register.md`
- 超過 5 個 OPEN = 該 owner 嘅 PR 必須先關 1 個 flaky 先可以 merge 新 code
```

### Step 3 — 不 block CI

```yaml
# vitest.config.ts
export default defineConfig({
  test: {
    sequence: { hooks: 'list' },
    // Quarantined tests 仍然跑,結果寫入 report,但 exit code 不受影響
    reporters: ['default', ['flaky-report', { outputFile: 'flaky-report.json' }]],
  },
});
```

### Step 4 — 限期升級

- **14 日內** → owner 必修
- **30 日內** → 升級到 tech debt,記錄喺該 project 嘅 tech-debt register
- **60 日內** → 該 test 可能要刪除,或者 owner 換人
- **每日 standup / sprint review** review OPEN flaky test

---

## 🔧 修復(Root Cause Categories)

按 David 過去 session 嘅實際撞過嘅 flaky,常見根因分 6 類:

### Category 1:時間依賴(`Date.now()` / `setTimeout` / `sleep`)

**症狀**:本地 pass / CI 偶發 fail / 凌晨跑 100% fail

**修法**:
```typescript
// ❌ Flaky
const expiresAt = Date.now() + 60_000;
expect(token.expiresAt).toBe(expiresAt);

// ✅ Deterministic
import { fakeTimers } from '@std/testing/time';
fakeTimers.install({ now: new Date('2026-07-28T00:00:00Z') });
const expiresAt = Date.now() + 60_000;
fakeTimers.tick(60_000);
expect(token.expiresAt).toBe(expiresAt);
fakeTimers.uninstall();
```

**通用守則**:
- 永遠**唔好用** `setTimeout` / `await sleep()` 同步
- 用 `fakeTimers`(Vitest / Jest 內建)或 `@sinonjs/fake-timers`
- Production code 如要 time-based logic,inject `Clock` interface(test 時注入 fake)

### Category 2:網絡 / 第三方 API

**症狀**:本地 pass / CI 慢 / 偶發 5xx

**修法**:
```typescript
// ❌ Flaky(打真 Stripe)
test('checkout flow', async () => {
  const session = await stripe.checkout.sessions.create({...});
  expect(session.id).toMatch(/^cs_/);
});

// ✅ Mock + 契約驗證
test('checkout flow', async () => {
  nock('https://api.stripe.com')
    .post('/v1/checkout/sessions')
    .reply(200, { id: 'cs_test_123', ... });
  const session = await stripe.checkout.sessions.create({...});
  expect(session.id).toBe('cs_test_123');
});
```

**通用守則**:
- 第三方 API 必須 mock(用 MSW / nock / WireMock)
- 真網絡 call 只喺「契約測試」(Pact)或 smoke test(staging)
- E2E 內部 backend call 都要 mock,只有 frontend → 真 backend 嘅邊界用真 call

### Category 3:DB state 污染(test 之間互相影響)

**症狀**:單跑 pass / 一起跑 fail / 順序敏感

**修法**:
```typescript
// ❌ Flaky(共享 DB state)
beforeAll(async () => {
  await db.users.create({ id: 1, name: 'alice' });
});

it('test A', () => { /* 假設 user 1 存在 */ });
it('test B', () => { /* 假設 user 1 唔存在 → 失敗 */ });

// ✅ 隔離(test 內 setup + teardown)
beforeEach(async () => {
  await db.users.delete({}); // 清乾淨
  await db.users.create({ id: 1, name: 'alice' });
});

afterEach(async () => {
  await db.users.delete({});
});
```

**通用守則**:
- 每個 test 自帶 `beforeEach` / `afterEach` 還原 state
- 用 **transactional rollback** pattern(test 開 transaction → 結束 rollback)— 比 delete 更快
- 絕對唔好靠 test execution order

### Category 4:Race condition / 並發

**症狀**:本地串行跑 pass / 並行跑 fail

**修法**:
- 識別共享 mutable state(全局變量、module-level cache、DB row)
- 加 mutex / lock,或用 immutable data structure
- Test 內用 `Promise.all` 嘅時候要確保**真係可以並行**(no shared state)

### Category 5:Test isolation 不足(共享 file system / port)

**症狀**:本機 pass / CI 撞 port / 同名 file

**修法**:
- 每個 test 用 **unique port**(random / 分配)+ **unique tmp dir**
- 用 `testcontainers` / Docker 隔離外部依賴

### Category 6:Frontend timing(SPA render / animation)

**症狀**:本地 pass / CI headless fail

**修法**:
```typescript
// ❌ Flaky
await page.click('button');
expect(page.locator('.modal')).toBeVisible();

// ✅ 等到 stable state
await page.click('button');
await expect(page.locator('.modal')).toBeVisible({ timeout: 5000 });

// ✅ 更好:用 Playwright auto-waiting locator
await page.getByRole('button', { name: 'Submit' }).click();
await expect(page.getByRole('dialog')).toBeVisible();
```

**通用守則**:
- 用 Playwright `expect(locator).toBeVisible({ timeout })` 而非 manual sleep
- 避免依賴 animation / transition 時序,測 functional 行為而唔係 visual 動畫

---

## 🛡 預防(Prevention Checklist)

新寫 test 嘅時候,過呢個 checklist:

- [ ] **冇** `setTimeout` / `await sleep(N)` 同步 — 用 fake timers
- [ ] **冇** 任何外部 HTTP call(用 mock)
- [ ] **冇** 共享 mutable state(全局變量 / module cache)— 用 dependency injection
- [ ] **冇** 依賴 test execution order — 每個 test 自帶 setup + teardown
- [ ] **冇** hardcoded `Date.now()` / 時間敏感 logic
- [ ] **冇** 隨機數據無固定 seed
- [ ] **冇** hardcoded port / file path — 用 random / tmp dir
- [ ] **冇** 第三方 library 真實初始化(SDK client / DB connection)— mock 或 testcontainer

**Linter 自動檢查**(進階):
- **ESLint custom rule** 禁止 `await new Promise(r => setTimeout(r, N))` 喺 test file
- **grep pre-commit**:`grep -rn "Date.now()\|new Date()" test/ | grep -v "fixtures"` → 警告

---

## 📊 觀測指標(Monthly Review)

每月 sprint review 報告加一段:

```markdown
## Test Flakiness — 2026-07
- Flakiness rate: 2.1%(↑ 0.5% vs last month)
- Quarantined tests: 4 OPEN(RG-005, RG-008, RG-011, NEW-007)
- Quarantined > 30 日: 0(✅ 健康)
- Root cause 分布:
  - 時間依賴: 1
  - DB state: 2
  - Race condition: 1
- 預防 checklist 新增:1 條 ESLint rule
```

---

## 🎬 David 嘅實戰情境

情境:`test/checkout.test.ts` 嘅 `it('payment retry after network timeout')` 喺 CI 跑 5 次有 1 次 fail,本地 100% pass。

**正確流程**(用本 SOP):
1. **偵測**:CI 自動 flakiness tracker 發現 rate > 1% → 標 `[FLAKY]`
2. **Quarantine**:加 `describe.skip` + 寫入 flaky-test register,Owner = @alice, Fix by = 2026-08-15
3. **根因分析**:看 source code → 發現 `await sleep(100)` 等 retry backoff
4. **修法**:用 fake timers 控制 retry timing
5. **驗證**:連跑 100 次 local + CI 5 次 → 全綠
6. **移除 quarantine**:撤 `describe.skip`,更新 register 為 `FIXED 2026-08-10`

**錯誤流程**(冇用本 SOP):
- 「CI 又紅啦,re-run 啦」→ 訓練壞習慣
- 「delete 咗佢啦,反正本地 pass」→ 真 bug 走甩
- 「加 retry 10 次啦」→ 掩蓋問題,下次更難 debug

---

## Related docs

- [Testing strategy](testing-strategy.md)
- [Testing strategy tiered](testing-strategy-tiered.md)
- [QA Gate](qa-gate.md)
- [Regression guard skill](../skills/regression-guard/SKILL.md)
- [Tech debt register skill](../skills/tech-debt-register/SKILL.md)
- [Project documentation standard](project-documentation-standard.md)
- [Failure policy](failure-policy.md)