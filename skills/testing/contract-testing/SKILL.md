---
name: contract-testing
description: |
  Consumer-driven contract testing — 用 Pact 驗證 microservice / API boundary 雙邊對 contract 嘅共識,
  避免 breaking change 喺 production 先發現。
  工具:Pact(JS / Python / Go / JVM 全支援)、OpenAPI / GraphQL schema validation。
  觸發情境:有 microservice 邊界、有第三方 API 整合、frontend / backend 拆分團隊。
  對應 docs/testing-strategy-tiered.md 嘅 T3 Mature 應測層。
trigger: |
  「contract test」「Pact」「microservice 邊界」「consumer-driven」「breaking change 點 catch」
  或任何跨 service / 跨團隊 API 整合
applicability: generic-pattern
---

Last-verified: 2026-07-28
# Contract Testing — Pact Consumer-Driven 完整 SOP

> **為何需要這個 skill** — Microservice / API boundary 嘅 breaking change 通常 production 先 catch 到,因為 integration test 唔會每次 release 跑所有 service。**Contract testing** 將「邊個 endpoint 出乜嘢 response」變成可驗證 artifact,Provider 同 Consumer 各自獨立 verify。
>
> **對應 `docs/testing-strategy-tiered.md`**:T3 Mature 嘅「必測層」之一;T1/T2 階段 monorepo / 單 backend 內部 API 唔需要。

---

## When to load

- Microservice / monorepo 拆 service / API 邊界由唔同團隊維護
- Frontend(consumer)同 backend(provider)拆分 commit cycle
- 第三方 SaaS API 整合(用 Pact 模擬 contract,真 call 用 sandbox)
- 預防「provider 改 field name,consumer 3 日後 production 500」

## When NOT to load

- Monorepo 內部 monolith API(consumer 同 provider 一齊 release)— 用 integration test 就夠
- T1 / T2 階段無 microservice — 屬於 over-engineering
- Static OpenAPI spec only(無 consumer-driven)— 用 swagger-cli validation
- Pure serverless / single endpoint / no state

---

## 🎯 核心概念

### Consumer-Driven Contract Testing(CDCT)

```
Consumer(eg. frontend)
    ↓ 寫 expectation:「我 expect GET /user 返 {id, name, email}」
Pact file(JSON)
    ↓ 上傳到 Pact Broker
Provider(eg. backend)
    ↓ 自動 verify 個 contract:啟動 mock state,返符合 expectation 嘅 response
    ↓ 確認:「我真係返呢個 shape」
```

**好處**:
- Provider 唔需要部署就 verify contract(本地跑 mock state)
- Consumer 唔需要起真 backend 就寫 contract(Pact mock server)
- Breaking change 喺 PR 階段 catch 到

### 三個角色

| 角色 | 動作 | 工具 |
|------|------|------|
| **Consumer** | 寫 expectation,generate pact file | `@pact-foundation/pact`(JS)、`pact-python` |
| **Provider** | 讀 pact file,verify 返符合 expectation | `@pact-foundation/pact`(JS provider verify)、`pact-python verify` |
| **Broker**(可選,推薦) | 集中儲存 pact + 版本對應 + can-i-deploy | Pactflow(saaS)或 self-host |

---

## 🔄 Pact JS SOP(最常見 stack)

### Setup(monorepo)

```bash
# Consumer side
npm i -D @pact-foundation/pact

# Provider side
npm i -D @pact-foundation/pact @pact-foundation/pact-node

# Broker(可選,self-host Docker)
docker run -d --name pact-broker \
  -p 9292:9292 \
  -e PACT_BROKER_DATABASE_ADAPTER=sqlite \
  pactfoundation/pact-broker
```

### Step 1 — Consumer 寫 Pact test

```typescript
// consumer/user-service.pact.test.ts
import { pactWith } from 'pact-js';
import { fetchUser } from '../src/api/user-client';

pactWith({ consumer: 'FrontendApp', provider: 'UserService' }, provider => {
  describe('GET /api/users/:id', () => {
    beforeEach(() => {
      provider
        .given('user with id 123 exists')
        .uponReceiving('a request for user 123')
        .withRequest({
          method: 'GET',
          path: '/api/users/123',
          headers: { Authorization: 'Bearer xxx' },
        })
        .willRespondWith({
          status: 200,
          headers: { 'Content-Type': 'application/json' },
          body: {
            id: '123',
            name: 'Alice',
            email: 'alice@example.com',
            role: 'admin',
          },
        });
    });

    it('returns user data', async () => {
      const user = await fetchUser('123');  // call goes to Pact mock server
      expect(user).toEqual({
        id: '123',
        name: 'Alice',
        email: 'alice@example.com',
        role: 'admin',
      });
    });
  });
});
```

**跑**:`npm test -- user-service.pact.test.ts`
**產物**:`pacts/FrontendApp-UserService.json`(自動生成)

### Step 2 — Publish Pact 到 Broker

```yaml
# .github/workflows/consumer-contract-publish.yml
name: Publish Consumer Contract
on: [push]
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm test
      - name: Publish to Pact Broker
        run: |
          npx pact-broker publish pacts/ \
            --broker-base-url=${{ secrets.PACT_BROKER_URL }} \
            --consumer-app-version=${{ github.sha }} \
            --branch=${{ github.ref_name }}
```

### Step 3 — Provider 寫 Verify test

```typescript
// provider/user-service.pact.verify.test.ts
import { Verifier } from '@pact-foundation/pact';
import { startMockServer } from './helpers/mock-state';

describe('UserService Pact Verification', () => {
  it('validates the expectations of FrontendApp', async () => {
    const opts = {
      provider: 'UserService',
      providerBaseUrl: 'http://localhost:3001',  // 真 service / mock 都得
      pactUrls: ['http://pact-broker/pacts/provider/UserService/consumer/FrontendApp/latest'],
      stateHandlers: {
        'user with id 123 exists': async () => {
          await db.users.insert({ id: '123', name: 'Alice', email: 'alice@example.com', role: 'admin' });
        },
      },
    };

    await new Verifier(opts).verifyProvider();
  });
});
```

### Step 4 — CI:Can-I-Deploy Gate

```yaml
# .github/workflows/can-i-deploy.yml
name: Can I Deploy?
on: [push]
jobs:
  can-i-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Check provider
        run: |
          npx pact-broker can-i-deploy \
            --pacticipant=UserService \
            --version=${{ github.sha }} \
            --to=production \
            --broker-base-url=${{ secrets.PACT_BROKER_URL }}
      - name: Check consumer
        run: |
          npx pact-broker can-i-deploy \
            --pacticipant=FrontendApp \
            --version=${{ github.sha }} \
            --to=production \
            --broker-base-url=${{ secrets.PACT_BROKER_URL }}
```

如果 provider 同 consumer 任何一方 contract 過期 / 唔 match → can-i-deploy 失敗,PR block。

---

## 🔧 常見 Contract Pattern

### Pattern 1:Optional field

```typescript
// Consumer expectation
body: {
  id: '123',
  name: 'Alice',
  email: 'alice@example.com',
  // role field optional — 將來 provider 唔返都唔 break
}

// Consumer code
const user = await fetchUser('123');
const role = user.role ?? 'guest';  // defensive
```

### Pattern 2:Array shape

```typescript
body: {
  items: eachLike({
    id: '123',
    name: 'Alice',
  }),
  total: 100,
}
```

### Pattern 3:Error response

```typescript
provider
  .given('user with id 999 does not exist')
  .uponReceiving('a request for missing user')
  .withRequest({ method: 'GET', path: '/api/users/999' })
  .willRespondWith({
    status: 404,
    body: { error: 'USER_NOT_FOUND', message: 'User 999 does not exist' },
  });
```

### Pattern 4:State setup(provider 側)

```typescript
stateHandlers: {
  'user with id 123 exists and is admin': async () => {
    // 真 DB / mock / test container 都得
    await db.users.insert({ id: '123', name: 'Alice', role: 'admin' });
  },
  'no users exist': async () => {
    await db.users.delete({});
  },
}
```

---

## 🚨 Common Pitfalls

### Pitfall 1:Provider verify 用咗 production state

```typescript
// ❌ Verifier 打真 production DB
stateHandlers: {
  'user exists': async () => {
    await db.users.insert({ id: '123' });  // 寫入真 production!
  },
}

// ✅ 用 test DB / sandbox / test container
beforeAll(async () => {
  process.env.DB_URL = 'postgresql://localhost:5432/test_db';
});
```

**Rule**:Contract verify 永遠用 test DB,**永遠唔可以** 用 production / staging with real data。

### Pitfall 2:Consumer contract 太 strict

```typescript
// ❌ 太 strict:任何 field 新加都 break
body: {
  id: '123',
  name: 'Alice',  // 加 email = contract break
}

// ✅ 用 matcher 寬鬆啲
body: {
  id: '123',
  name: 'Alice',
  // 其他 field optional
}

// 更好:Pact 內建 matcher
body: like({
  id: '123',
  name: 'Alice',
  email: 'alice@example.com',
})
```

### Pitfall 3:冇用 Pact Broker

```typescript
// ❌ Consumer 同 Provider 都用同一個 pacts/ folder(git commit)
// 問題:monorepo 之外嘅 team 拎唔到

// ✅ 集中 broker(SaaS 或 self-host)
// - Pactflow:免費 tier 夠 MVP
// - self-host Docker:適合 compliance 嚴格嘅 team
```

### Pitfall 4:忽略 verification publish

Consumer publish contract 後,**Provider 也要 publish verification result**:

```bash
npx pact-broker publish-verification \
  --provider-app-version=${{ github.sha }} \
  --pacticipant=UserService \
  --broker-base-url=${{ secrets.PACT_BROKER_URL }}
```

冇 verification publish → can-i-deploy 永遠 fail。

---

## 📊 與 Integration / E2E Test 嘅分工

| 測試類型 | 衡量 | 速度 | 場景 |
|---------|------|------|------|
| **Unit test** | 函式正確 | < 1s/test | 內部 logic |
| **Integration test** | Module + DB 互動 | 1-10s/test | 內部 API |
| **Contract test(Pact)** | API 邊界契約 | < 5s/test | Microservice / Frontend-Backend |
| **E2E test** | 用戶 flow | 30-300s/test | Critical user journey |
| **Smoke test** | Deploy 後存活 | < 30s | Post-deploy |

**Rule**:**Contract test 唔係取代 integration test**,係補中間缺口 — Provider 同 Consumer commit cycle 唔一致時 catch breaking change。

---

## 🛠 OpenAPI Schema Validation(替代方案)

如果唔想用 Pact 嘅 consumer-driven model,**至少** 做 schema validation:

```typescript
// OpenAPI spec 喺 /openapi.yaml
import Ajv from 'ajv';
import addFormats from 'ajv-formats';

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);

const validate = ajv.compile(openApiSpec.components.schemas.UserResponse);

it('GET /api/users/:id matches schema', async () => {
  const response = await fetch('/api/users/123');
  expect(validate(response.data)).toBe(true);
});
```

**優點**:Provider-side,簡單直接
**缺點**:冇 consumer-driven,**只有 Provider 知道自己有咩 field**;Consumer 唔會自動 discover

---

## 📅 When to Adopt

**T1 階段**:不採用(overhead > value)
**T2 階段**:2 個 service 以上 + 跨團隊 → 採用 OpenAPI schema validation;consumer-driven 等 T3
**T3 階段**:必須有 — full Pact + Broker + can-i-deploy gate

---

## 🎬 David 嘅實戰情境

情境:Frontend team 同 Backend team 拆咗 repository。Backend 將 `GET /api/users/:id` 嘅 response 由 `{id, name}` 改成 `{user_id, full_name}`,frontend 仲用緊舊 contract。Production 上線 2 小時後先發現,user list 頁空白。

**正確流程**(用本 skill):
1. **Frontend 寫 Pact test**:`GET /api/users/123` expect `{id, name}`
2. **Publish 到 Pact Broker**
3. **Backend CI**:`can-i-deploy` 自動跑 → Backend 改 `{user_id, full_name}` 後,verifier 失敗,因為 frontend 仲 expect 舊 shape
4. **Backend PR block** → Backend team 同 Frontend team 對齊,雙方決定:
   - Option A:Backend 維持舊 shape(短期)
   - Option B:Frontend 改用新 shape + update contract(長期)
5. **結果**:production 唔會 break

**錯誤流程**:
- 「Integration test 都 pass 啦」→ Integration test 用最新 backend code,冇 catch 到
- 「E2E test 會 catch 到」→ E2E 太慢 + 部署 staging 才跑,改 contract 後 deploy window miss
- 「Frontend 用 default field name 啦」→ 等 production 5xx 先知

---

## Related docs

- [Testing strategy](../testing-strategy.md)
- [Testing strategy tiered](../testing-strategy-tiered.md)
- [Regression guard skill](../regression-guard/SKILL.md)
- [API documentation standard](../project-documentation-standard.md)