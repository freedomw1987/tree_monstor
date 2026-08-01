# Testing Strategy — 全面且詳盡的測試策略

> **Status:** Canonical. Source of truth for testing layers, quality metrics, and tooling strategy.

> **為什麼需要這份文件** — David 在 2026-06-06 kanban task 明確指出:
> 「QA 也要持續按用戶的需求去更新測試任務...之後可以作全面且詳盡的測試」
>
> 之前 `docs/qa-gate.md` 同 `docs/phases.md` 提及測試但**沒有**:
> - 完整嘅測試類型清單(只講 unit / integration / E2E)
> - 測試優先級分層
> - 每種測試嘅具體執行方法
> - Coverage 指標同 trade-off
>
> **這份文件就是補呢個洞** — 將「全面且詳盡的測試」變成可執行的策略。

---

## 🎯 核心原則

> **唔好追求 100% coverage。要追求「critical paths 100%, edges 合理覆蓋」**。

```
覆蓋率的金字塔
                ▲
               /  \
              / E2E \         ← 少而精,只測 critical user flows
             /───────\
            /Integration\      ← 跨 module 嘅互動
           /──────────────\
          /     Unit         \   ← 大宗,每個 function / class
         /────────────────────\
        /   Static + Lint       \  ← TypeScript, ESLint, pre-commit
       /──────────────────────────\
```

**Cobertura 健康指標**(唔係越高越好):
- 50% unit + 30% integration + 15% E2E + 5% manual = 100% confidence
- 80% unit + 0% integration + 0% E2E = 假象嘅 80%

---

## 📋 測試類型全清單

按「測咩 / 點測 / 點樣自動化 / 點樣手動」分:

### Layer 1: 靜態分析 (Static Analysis)

| 測試類型 | 工具 | 自動化時機 | 失敗處理 |
|---------|------|----------|---------|
| **Type checking** | TypeScript `tsc --noEmit` / mypy | 每次 commit(husky pre-commit) | 阻擋 commit |
| **Linting** | ESLint / Ruff / golangci-lint | 每次 commit | 阻擋 commit(可 `--no-verify` 跳過但要解釋) |
| **Formatting** | Prettier / Black / gofmt | 每次 commit | 自動修正後 commit |
| **Dependency 漏洞掃描** | `npm audit` / `pip-audit` / `snyk` | 每次 PR + 每日 cron | Critical/High 阻擋 merge |
| **Secret 掃描** | `gitleaks` / `trufflehog` | 每次 commit | 阻擋 commit |
| **License compliance** | `license-checker` | 每次 PR | 阻擋未知 license |
| **Code complexity** | `complexity-report` / `radon` | 每次 PR(變更嘅 file) | 警告(不阻擋) |

**Setup 模板**:
```json
// package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "npm run lint && npm run typecheck && npm run test:unit",
      "pre-push": "npm run test:integration"
    }
  }
}
```

### Layer 2: Unit Tests

**目標**:測試**單一 function / class / module** 嘅行為,隔離所有 dependency。

**規則**:
- 每個 export 嘅 function 至少 1 個 test
- 每個 public method 至少 2 個 test(happy path + 1 edge case)
- Mock 所有 external dependency(DB / API / filesystem)
- 唔好 test private function(透過 public API 測)
- 唔好 test 第三方 library(假設佢哋自己 tested)

**工具選擇**:
| 語言 | 推薦 | 次選 |
|------|------|------|
| TypeScript | Vitest(快,native ESM) | Jest |
| Python | pytest + pytest-cov | unittest |
| Go | 內建 testing + testify | Ginkgo |
| Rust | 內建 cargo test | - |

**Coverage 目標**:
- P0 US: 100% line + branch
- P1 US: 90% line + 80% branch
- P2 US: 70% line
- P3 US: 50% line(都可有可無)

### Layer 3: Integration Tests

**目標**:測**多個 module 一齊運作**,但仍然隔離外部服務(用 test container / fake server)。

**測試對象**:
- API endpoint + database(真 DB,用 Docker container / test fixture)
- Multiple services 互動(用 WireMock / Mountebank mock external API)
- Frontend component + backend(用 MSW 攔截 fetch)
- Database query 嘅 SQL 正確性(用 test DB + 真 schema migration)

**工具**:
| 語言/Stack | 推薦 |
|-----------|------|
| Node.js | Supertest + testcontainers-node |
| Python | pytest + pytest-postgresql / testcontainers-python |
| Database | Testcontainers(Docker-based,production-like) |
| HTTP mocking | WireMock / MSW(Mock Service Worker) |
| React/Frontend | React Testing Library + MSW |

**Coverage 目標**:
- 每個 API endpoint 至少 1 個 happy path + 1 個 error path
- 每個 US 至少 1 個 integration test(端到端但 mock 外部)


### Layer 4: Regression Mode Hooks / Switches

**目標**:讓 QA 可以友善、穩定、可重跑地啟用 regression fixtures / hooks，驗證 `US-XXX` / `RG-XXX` 的行為仍正常，同時確保 regression mode **不是** production bypass。

> **安全邊界與 merge blocker 條件以 `docs/qa-gate.md` §3A（Regression Mode Gate）為唯一正本**——production safety checks、`/__qa/*` merge policy、docs sync 要求、禁止嘅 bypass 語義（skipAuth / bypassPermission / disableRateLimit 等）全部見該節。本節只講實作 pattern（how-to）。

#### Frontend regression hooks

**允許**:
- 穩定 selector：semantic HTML、`name`、`aria-label`，必要時使用 `data-testid`
- dev/staging-only QA panel（例如 `/__qa/regression`）
- visual regression controls：freeze animation / time / random seed（只用嚟穩定 screenshot，不可改 business behavior）
- regression fixture selector，但資料動作必須呼叫 backend QA endpoint，由 backend 驗證
- 顯示 test tenant、seed version、active role、API base URL 等 QA 診斷資訊

**實作慣例**:
- `data-testid` 是 QA contract，改名必須同時更新 E2E test
- Frontend switch 永遠不是 security boundary；權限判斷一律由 backend 做

#### Backend regression hooks

**允許 examples**:
- `GET /__qa/health` — regression mode 狀態、seed version、test tenant、mock service status
- `POST /__qa/seed` — idempotent 建 test fixture，只寫 test tenant / test schema / test DB
- `POST /__qa/reset` — scoped reset，嚴禁全庫 destructive reset
- `GET /__qa/mailbox` — fake/test mailbox，檢查 email / SMS / notification 的 sandbox output
- `POST /__qa/time` — test clock：freeze / travel / reset time，驗證 TTL、trial、subscription、scheduled job
- `POST /__qa/jobs/drain` — queue drain，讓 async jobs 可重跑、可觀察，不靠 sleep
- external fixture control — 控制 payment / webhook / LLM / storage 等 sandbox response
- `GET /__qa/regression/:rgId` — per-`RG-XXX` setup / assert / cleanup（例如 `/__qa/regression/RG-004`）

**實作慣例**:
- seed / reset 必須 idempotent，可重跑，不依賴順序
- `/__qa/*` 只可以用作 deterministic QA / test controls，不是 product API，也不是 user-facing feature；目標係建立可測試狀態，而不是 bypass 真實行為

#### QA script naming convention

各 project 可按 stack 實作，但語意應一致：

```bash
npm run test:regression
npm run test:regression:unit
npm run test:regression:integration
npm run test:regression:e2e
npm run test:regression:visual
npm run test:regression:rg -- RG-004
npm run qa:seed -- RG-004
npm run qa:reset
npm run qa:health
```

非 Node project 可用等價命名，例如 `make test-regression` / `pytest -m regression`。

**Anti-pattern**:唔好 disable rate limit 來令 E2E pass；應使用 test tenant / test user / per-test caller identity，讓 backend 真實 rate limit behavior 仍被覆蓋。

### Layer 5: E2E (End-to-End) Tests

**目標**:模擬**真實用戶**操作,覆蓋 critical user flow。

**工具**:
| 場景 | 工具 |
|------|------|
| Web app | Playwright(推薦)/ Cypress / Puppeteer |
| Mobile | Detox / Appium / Maestro |
| API-only | Postman + Newman / k6 |
| CLI tool | bats / shunit2 / Python pytest-subprocess |

**Critical User Flow**(必須 E2E 覆蓋):
- 註冊 → Email 驗證 → 首次登入
- 登入 → 核心操作(下單 / 發文 / 查詢)→ 登出
- 付款流程(P0 必須)
- 主要管理員操作
- 任何有金流 / 數據 loss 風險嘅 flow

**規則**:
- E2E 唔好覆蓋所有 case(慢、易碎)
- 每個 critical flow **1 個 happy path E2E + 邊界情況用 integration test 補**
- E2E 必須喺 staging / preview environment 跑(唔好喺 production)
- 用 Page Object Model 設計 test code(減少維護成本)

**Setup**:
```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test('user can sign up, verify email, and log in', async ({ page, request }) => {
  // 1. 註冊
  await page.goto('/signup');
  await page.fill('[name=email]', `test-${Date.now()}@example.com`);
  await page.fill('[name=password]', 'Test1234!');
  await page.click('button[type=submit]');

  // 2. Email 驗證(從 test mailbox fetch link)
  const emailLink = await getLatestEmailLink(testEmail);
  await page.goto(emailLink);

  // 3. 登入
  await page.fill('[name=email]', testEmail);
  await page.fill('[name=password]', 'Test1234!');
  await page.click('button[type=submit]');

  // 4. 確認 landing page
  await expect(page).toHaveURL('/dashboard');
});
```

### Layer 6: Performance Tests

**目標**:確保系統喺**預期 load** 下表現正常。

**類型**:
| 類型 | 工具 | 目標 |
|------|------|------|
| Load test | k6 / Gatling / Locust | 模擬 N 個 concurrent 用戶,確保 response time < SLO |
| Stress test | k6 / Gatling | 推到系統極限,搵 breaking point |
| Spike test | k6 | 突然 10x 流量,系統會唔會 crash |
| Soak test | k6 | 24-72 小時穩定 load,搵 memory leak |
| Benchmark | Benchmark.js / pytest-benchmark | 比較 implementation 嘅 performance |

**規則**:
- 每個 P0 endpoint 必須有 load test,定 SLA
- 每次重大改動(refactor / 新功能)跑一次,確認冇 regression
- 結果 commit 入 git(performance baseline),PR 顯示 delta
- 警告:**唔好用 production 跑 performance test**(可能搞壞 production)

**範例**(k6):
```javascript
// perf/login-loadtest.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 100 },   // ramp up to 100 users
    { duration: '5m', target: 100 },   // stay at 100
    { duration: '1m', target: 0 },     // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% requests < 200ms
    http_req_failed: ['rate<0.01'],    // error rate < 1%
  },
};

export default function () {
  const res = http.post('https://staging.api.example.com/login', {
    email: 'loadtest@example.com',
    password: 'Test1234!',
  });
  check(res, { 'status was 200': (r) => r.status === 200 });
  sleep(1);
}
```

### Layer 7: Security Tests

**目標**:發現**安全漏洞**,符合 compliance。

**類型**:
| 類型 | 工具 | 覆蓋 |
|------|------|------|
| **SAST**(Static) | Semgrep / Snyk Code / CodeQL | SQL Injection, XSS, hardcoded secrets |
| **DAST**(Dynamic) | OWASP ZAP / Burp Suite | 跑 E2E 形式攻擊自己 |
| **Dependency scan** | `npm audit` / Snyk Open Source / OWASP Dependency-Check | 已知 CVE |
| **Secret scan** | `gitleaks` / `trufflehog` | 提交嘅 code 有冇 API key |
| **Container scan** | Trivy / Snyk Container | Docker image 嘅漏洞 |
| **Penetration test** | 手動(每年 1 次) + 自動化 ZAP | 真實攻擊模擬 |
| **Compliance** | SOC2 / GDPR 自動 check tools | 數據處理合規 |

**紅線**:
- **任何 Critical/High CVE 阻擋 merge**
- 自動化掃描每次 PR 必跑
- 季度手動 pentest(外聘或自 team)

### Layer 8: Accessibility (A11y) Tests

**目標**:確保**所有用戶**(包括殘障人士)能用。

**標準**:**WCAG 2.1 AA**(最低),AAA(理想)。

**工具**:
| 工具 | 用途 |
|------|------|
| **axe-core**(自動) | 喺 E2E 跑,check 標準 violation |
| **Pa11y**(自動) | CI 跑 multi-page 掃描 |
| **Lighthouse**(自動) | Chrome DevTools / CLI 嘅 a11y score |
| **Screen reader 手動測試** | 季度:用 VoiceOver / NVDA 試 critical flow |
| **Keyboard nav 手動測試** | 確保唔靠 mouse 都能用 |

**規則**:
- 每個 E2E 包含 `axe-core` check
- Lighthouse a11y score ≥ 95 才算 PASS
- 唔好只靠自動化(axe 只 find ~30% issues),重要 flow 季度手動驗證

### Layer 9: Visual Regression Tests

**目標**:確保 UI 改動**唔會**意外破壞現有視覺。

**工具**:
- Percy(cloud-based,跨瀏覽器)
- Chromatic(Storybook 整合)
- Playwright `toHaveScreenshot()`
- BackstopJS(self-hosted)

**規則**:
- Critical page(landing / checkout / dashboard)必須有 visual baseline
- PR 改 UI 自動 compare,**意外改動阻擋 merge**
- Visual test 嘅 baseline 必須 review(唔好盲目 accept)

### Layer 10: Contract Tests

**目標**:確保 **API provider 同 consumer 對 contract 嘅共識**保持一致(避免 breaking change)。

**工具**:
- Pact(consumer-driven contract testing)
- OpenAPI / GraphQL schema validation
- JSON Schema 驗證 response

**規則**:
- 每個 microservice 邊界必須有 contract test
- Schema 變更 = breaking change,需要 major version bump
- 自動跑喺 CI,失敗即阻擋

### Layer 11: Smoke Tests

**目標**:**部署後**快速驗證「最基本嘅嘢未死」。

**執行時機**:每次 deploy 到 staging / production 之後。

**典型 smoke test set**:
```bash
# deploy-smoke.sh
#!/bin/bash
set -e

# 1. Health check
curl -fsS https://api.example.com/health

# 2. 重要 endpoint 200
for endpoint in /api/users/me /api/products /api/orders/recent; do
  status=$(curl -fsS -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "https://api.example.com$endpoint")
  if [ "$status" != "200" ]; then
    echo "❌ $endpoint returned $status"
    exit 1
  fi
done

# 3. 註冊新用戶(用 disposable email)
# ...

echo "✅ Smoke test passed"
```

**規則**:**必須喺 production deploy 後跑**。失敗即 rollback。

### Layer 12: Chaos / Resilience Tests

**目標**:確保系統喺**部分失敗**時仍能運作。

**工具**:
- Chaos Monkey(隨機 kill instances)
- AWS Fault Injection Service
- Litmus(kubernetes chaos)
- Toxiproxy(simulate network failure / latency)

**規則**:
- 季度 chaos drill(刻意 kill 一個 pod / DB replica)
- 確認 auto-recovery / graceful degradation 有效
- Production 唔可以默認啟用 chaos,只在 staging

### Layer 13: Compatibility Tests

**目標**:確保**跨瀏覽器 / 跨 OS / 跨 device** 一致體驗。

**工具**:
- BrowserStack / Sauce Labs(cross-browser cloud)
- Playwright multi-browser config
- LambdaTest

**覆蓋 matrix**(依用戶實際使用調整):
| 瀏覽器 | Desktop | Mobile |
|--------|---------|--------|
| Chrome (latest 2) | ✅ | ✅ |
| Safari (latest 2) | ✅ | ✅ iOS |
| Firefox (latest 2) | ✅ | ❌(低市佔) |
| Edge (latest) | ✅ | ❌ |

**Mobile Device Lab**:
- iPhone 13 / 15(主流)
- iPad
- Android Pixel 7 / Samsung S23(主流)
- 低端 Android(Redmi 9A)— 確認 performance

---

## 🏗️ 測試金字塔配置

不同 project size 嘅**推薦比例**:

### 小型 (1-3 個 dev, MVP 階段)

```
重點:Unit + 少量 E2E
比例:
- Unit: 70%
- Integration: 20%
- E2E: 10%(只 critical flows)

投資: Performance / Security / Chaos 可以 skip
```

### 中型 (4-10 個 dev, Growth 階段)

```
重點:Unit + Integration + E2E 平衡
比例:
- Unit: 50%
- Integration: 30%
- E2E: 15%
- Performance: 3%
- Security scan: 2%

投資: Performance + Security 自動化
```

### 大型 (10+ 個 dev, Mature 階段)

```
重點:全棧 + 持續優化
比例:
- Unit: 40%
- Integration: 30%
- E2E: 15%
- Performance: 5%
- Security: 5%
- Visual / Contract / Chaos: 5%

投資: 全自動化,專職 QA / SRE
```

---

## 📊 Test Coverage 健康指標

唔同類型嘅覆蓋率,**唔係越高越好**:

| 指標 | 健康 | 警告 | 不健康 | 備註 |
|------|------|------|--------|------|
| Unit line coverage | 70-85% | 60-70% 或 >90% | <60% 或 100% | 100% 通常代表測試冇 quality(寫過 test 嘅 code 先 commit) |
| Branch coverage | 60-75% | 50-60% | <50% | 重要 logic if/else 都要 cover |
| Critical path coverage | 100% | 90-99% | <90% | P0 US 嘅 happy path + error path |
| E2E critical flows | 100% | 90-99% | <90% | Critical user flow |
| Performance baseline | 100% 監控 | 50% 監控 | <50% | P0 endpoint 必須有 baseline |
| Security scan pass rate | 100% | 95-99% | <95% | 任何 Critical/High CVE 必須 0 |
| A11y score (Lighthouse) | ≥95 | 85-94 | <85 | 唔可以低於 85 |
| MTTR (Mean Time To Recover) | < 1h | 1-4h | >4h | Incident response time |
| Change failure rate | < 15% | 15-30% | >30% | % deploys 導致 incident |

---

## 🔄 測試任務管理(對應 `docs/qa-tracker.md`)

每個 US 對應嘅測試任務分配:

| US 優先級 | 必做測試類型 | 可選測試類型 |
|----------|------------|------------|
| **P0** | Unit + Integration + E2E + Performance + Security + A11y | Visual + Contract |
| **P1** | Unit + Integration + E2E + Security | Performance + A11y + Visual |
| **P2** | Unit + Integration | E2E + A11y |
| **P3** | Unit | Integration |

詳細工作流程見 `docs/qa-tracker.md`。

---

## 🛠️ 工具生態推薦

### 統一 Test Runner + Reporter

| 語言 | 推薦 |
|------|------|
| TypeScript | Vitest(快,ESM native)+ Playwright |
| Python | pytest + pytest-cov + pytest-xdist(並行) |
| Go | 內建 testing + testify + go-test-report |
| Rust | cargo test + cargo-tarpaulin(coverage) |

### CI 整合

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-and-integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run test:unit -- --coverage
      - run: npm run test:integration
      - uses: codecov/codecov-action@v3

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:e2e
      - uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm audit --audit-level=high
      - uses: github/codeql-action/analyze@v2

  performance:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run test:perf
```

---

## 📚 跟其他文件的關係

- `docs/qa-gate.md` 嘅交付清單:本文件擴展為「持續測試策略」
- `docs/qa-tracker.md`:本文件提供「每個 US 必做測試」嘅規格
- `docs/project-documentation-standard.md` §TEST-COVERAGE.md:本文件提供「coverage 健康指標」
- `skills/regression-guard/`:bug fix 後嘅 regression test 跟本文件嘅 testing 規格一致
- `docs/phases.md` §Test:本文件補完「Test 階段嘅細節」

---

> 紅線 16 / 17 / 18（三層測試、smoke test、CVE 0）全文以 `SOUL.md` 紅線清單為唯一正本。

---

## 🎬 David 嘅實戰情境

情境:David 嘅新功能「用戶可以一鍵清空所有閱讀紀錄」,US 優先級 P1。

**完整測試 plan**(用本策略):

| 測試類型 | 測試內容 | 工具 |
|---------|---------|------|
| Unit | `clearAllReadHistory()` 函式:happy path、empty list、permission check | Vitest |
| Integration | `DELETE /api/users/me/history` endpoint:200 / 401 / 403 各 case | Supertest |
| E2E | 用戶登入 → 進設定 → 點清空 → 確認 UI 變化 | Playwright |
| Security | IDOR(其他用戶嘅 history 唔可以清到) | 手動 + OWASP ZAP |
| A11y | 確認清空按鈕有 aria-label,keyboard 可達 | axe-core |
| Performance | 清空 10,000 條 history 嘅 response time | k6 |
| Visual | 清空後嘅 empty state screenshot baseline | Playwright screenshot |
| Regression | 確保唔影響「單筆刪除」嘅功能 | 跑 RG-005 test(假設有) |

**8 個測試類型**全部都有 → **全面且詳盡的測試**。

---

## Related docs

- [Documentation index](00-index.md)
- [QA Gate](qa-gate.md)
- [QA tracker](qa-tracker.md)
- [Project documentation standard](project-documentation-standard.md)
