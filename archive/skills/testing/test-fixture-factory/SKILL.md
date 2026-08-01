---
name: test-fixture-factory
description: |
  Test data factory pattern — 用統一 builder / factory 產生 test fixture,
  避免每個 test file 重複 inline object、避免 fragile shared fixture、
  支援 per-test override + 自動 cleanup。
  工具:FactoryBot(Ruby)、factory-boy(Python)、@mswjs/data(JS MSW 整合)、
  自家 lightweight factory function(TypeScript / Go 都通用)。
  觸發情境:test 數量 > 50、有複雜 relation graph、要 cross-test consistency。
  對應 docs/testing-strategy-tiered.md T2 / T3 嘅應測層 / 必測層。
trigger: |
  「test fixture」「test data factory」「重複 inline object」「shared fixture 撞」
  或任何 test data 散落、test 之間互相污染
applicability: generic-pattern
---

Last-verified: 2026-07-28
# Test Fixture Factory — 統一 Test Data 產生

> **為何需要這個 skill** — Test fixture 散落各 test file 嘅 inline object 有 4 大問題:(1)改 entity shape 要逐個 test 改(2)shared fixture 易污染(3)cross-entity relation 難 setup(4)無 default,test 變 verbose。**Factory pattern** 把 fixture 集中管理,每個 test 自帶 override + 自動 cleanup。
>
> **對應 `docs/testing-strategy-tiered.md`**:T2 開始推薦,T3 必備。

---

## When to load

- Test 數量 > 50,而且 entity shape 開始變
- Entity 有 nested relation(User → Company → Order → LineItem)
- Shared fixture 開始撞(state pollution across tests)
- 新 developer 加入時唔知點 setup test data
- Sprint 經常需要「喺 production 抽 X entity 嘅樣子做 test data」

## When NOT to load

- Project 仲喺 T1 MVP stage(< 20 test)— inline object 仲 OK
- Pure function test(無 entity / DB)— 直接 call function,factory 冇用
- Single-shot spike / throwaway script — 過度抽象

---

## 🎯 三個層次的 Fixture 管理

| 層次 | 抽象度 | 適用 |
|------|--------|------|
| **L1: Inline object** | 低 | < 20 tests,simple entity |
| **L2: Factory function** | 中 | 50-200 tests,簡單 relation |
| **L3: Factory library**(FactoryBot / factory-boy) | 高 | 200+ tests,複雜 relation,multi-team |

> **起點**:永遠由 L2 factory function 開始。需要時升 L3,唔好 over-engineer。

---

## 🔧 L2: Factory Function(推薦起點,任何 stack)

### TypeScript 範本

```typescript
// test/factories/user-factory.ts
import { faker } from '@faker-js/faker';  // optional,for realistic data

export interface UserAttrs {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user' | 'guest';
  companyId: string;
  createdAt: Date;
}

export function buildUser(overrides: Partial<UserAttrs> = {}): UserAttrs {
  const defaults: UserAttrs = {
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    role: 'user',
    companyId: 'company-default',
    createdAt: new Date('2026-07-28'),
  };
  return { ...defaults, ...overrides };
}

// Use
const alice = buildUser({ role: 'admin' });
const bob = buildUser({ email: 'bob@test.com' });
```

### Sequence 支援(避免 id collision)

```typescript
// test/factories/user-factory.ts
let userSeq = 0;
export function buildUser(overrides: Partial<UserAttrs> = {}): UserAttrs {
  userSeq++;
  const defaults: UserAttrs = {
    id: `user-${userSeq}`,
    email: `user${userSeq}@test.com`,
    // ...
  };
  return { ...defaults, ...overrides };
}
```

### Trailing(relations)

```typescript
// test/factories/order-factory.ts
import { buildUser } from './user-factory';

export interface OrderAttrs {
  id: string;
  userId: string;
  total: number;
  status: 'pending' | 'paid' | 'shipped';
}

export function buildOrder(overrides: Partial<OrderAttrs> = {}): OrderAttrs {
  const user = buildUser();  // trailing: 自動 generate parent
  return {
    id: faker.string.uuid(),
    userId: user.id,
    total: 100,
    status: 'pending',
    ...overrides,
  };
}
```

---

## 🔧 L3: Factory Library(進階)

### Python — factory_boy

```bash
pip install factory-boy faker
```

```python
# tests/factories.py
import factory
from factory.django import DjangoModelFactory
from myapp.models import User, Company, Order

class CompanyFactory(DjangoModelFactory):
    class Meta:
        model = Company
    name = factory.Faker('company')
    created_at = factory.LazyFunction(timezone.now)

class UserFactory(DjangoModelFactory):
    class Meta:
        model = User
    email = factory.Sequence(lambda n: f'user{n}@test.com')
    name = factory.Faker('name')
    company = factory.SubFactory(CompanyFactory)  # trailing
    role = 'user'

class OrderFactory(DjangoModelFactory):
    class Meta:
        model = Order
    user = factory.SubFactory(UserFactory)
    total = 100
    status = 'pending'

# Use
def test_user_can_view_own_order():
    user = UserFactory(role='admin')
    order = OrderFactory(user=user, status='paid')
    assert can_view(user, order) is True

def test_user_blocked_from_other_order():
    user = UserFactory()
    other = UserFactory()  # automatic isolation
    order = OrderFactory(user=other)
    assert can_view(user, order) is False
```

**好處**:
- `factory.SubFactory` 自動 generate parent
- `factory.Sequence` 自動 unique 編號
- `factory.LazyFunction` 支援 callable default
- Django ORM 自動 `django_get_or_create`(DB state 自動管理)

### Ruby — FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@test.com" }
    name { Faker::Name.name }
    role { 'user' }
    company
  end

  factory :admin, parent: :user do
    role { 'admin' }
  end

  factory :order do
    user
    total { 100 }
    status { 'pending' }
  end
end

# Use
user = FactoryBot.create(:admin)
order = FactoryBot.create(:order, user: user)
```

### TypeScript — @mswjs/data(MSW 整合)

```typescript
// 適用於需要 mock server 嘅 E2E / integration test
import { factory, primaryKey } from '@mswjs/data';

export const db = factory({
  user: {
    id: primaryKey(faker.string.uuid),
    email: faker.internet.email,
    name: faker.person.fullName,
    role: () => 'user',
  },
  order: {
    id: primaryKey(faker.string.uuid),
    userId: faker.string.uuid,
    total: () => 100,
  },
});

// Use
const alice = db.user.create({ role: 'admin' });
const order = db.order.create({ userId: alice.id });
// Cleanup
db.user.delete();
db.order.delete();
```

---

## 🧹 Cleanup Strategy

每個 factory 必須有對應 cleanup:

### Pattern 1:Transaction rollback(推薦,DB test)

```typescript
// vitest.setup.ts
beforeEach(async () => {
  await db.transaction.begin();
});

afterEach(async () => {
  await db.transaction.rollback();  // 全部 test data 自動消失
});
```

**好處**:比 truncate 快 10x,且 parallel-safe。

### Pattern 2:Per-test factory reset(MSW / in-memory)

```typescript
afterEach(() => {
  db.user.delete();
  db.order.delete();
});
```

### Pattern 3:Truncate(慢但簡單)

```typescript
afterEach(async () => {
  await db.users.delete({});
  await db.orders.delete({});
});
```

---

## 🎯 Best Practices

### Rule 1:Factory produce defaults,test specify deltas

```typescript
// ❌ Bad:每個 field 寫晒
const user = { id: '...', email: '...', name: '...', role: 'admin', companyId: '...', createdAt: new Date() };

// ✅ Good:只寫 relevant field
const user = buildUser({ role: 'admin' });
```

### Rule 2:Trait / SubType pattern

```typescript
// test/factories/user-factory.ts
export function buildAdminUser(overrides = {}) {
  return buildUser({ role: 'admin', ...overrides });
}
export function buildGuestUser(overrides = {}) {
  return buildUser({ role: 'guest', email: null, ...overrides });
}

// Use
const admin = buildAdminUser();
const guest = buildGuestUser();
```

### Rule 3:Static ID for assertions

```typescript
// 預設 fixture ID 用 deterministic string,方便 assertion
buildUser({ id: 'user-fixed-1', email: 'fixed@test.com' });
// 多個 test 用同一個 fixed ID = cross-test contract 清晰
```

### Rule 4:Realistic data ≠ Production data

```typescript
// ❌ 用真實 production 嘅 user record
const user = { email: 'ceo@bigcorp.com', name: 'John Smith', ... };

// ✅ 用 realistic 但 fictional
const user = buildUser();  // faker 生成 'alice123@example.com'
```

**Why**:Production data 包含 PII + 唔同 production 環境跑 test 會 leak 真實 user 行為。

---

## 🚨 Common Pitfalls

### Pitfall 1:Factory 變 god object

```typescript
// ❌ 一個 factory 200 行,50 個 override field
export function buildMegaEntity(overrides: Partial<MegaAttrs> = {}): MegaAttrs {
  // ...
}

// ✅ 拆 sub-factory
buildCompany({ size: 'enterprise' }).then(company => buildUser({ companyId: company.id }))
```

### Pitfall 2:Shared fixture ID 撞

```typescript
// ❌ 兩個 test 都用 'user-1'
it('test A', () => { db.users.insert({ id: 'user-1', ... }); });
it('test B', () => { db.users.insert({ id: 'user-1', ... }); });  // collision

// ✅ Sequence 或 uuid
let userSeq = 0;
export function buildUser() {
  userSeq++;
  return { id: `user-${userSeq}`, ... };
}
```

### Pitfall 3:Factory 寫入 production-like side effect

```typescript
// ❌ Factory trigger email
export function buildUserWithWelcomeEmail() {
  const user = db.users.insert({ ... });
  await sendEmail(user.email, 'welcome');  // 真發 email!
  return user;
}

// ✅ 把 side effect 分離
export function buildUser() { return db.users.insert({ ... }); }
it('sends welcome email on signup', async () => {
  const user = buildUser();
  await signupService(user);
  expect(mailbox.findByRecipient(user.email)).toBeDefined();
});
```

### Pitfall 4:忘記 cleanup 導致 test pollution

```typescript
// ❌ 冇 cleanup
beforeEach(() => { db.users.insert(buildUser()); });
// 跑 100 個 test 後,DB 有 100 個 user,慢到爆

// ✅ 用 transaction rollback 或 explicit cleanup
```

---

## 📊 衡量指標

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| 同一個 entity 嘅 factory / inline ratio | ≥ 80% factory | 50-80% | < 50%(inline 太多) |
| Test 之間 fixture 污染 events / sprint | 0 | 1-3 | > 3 |
| Fixture 變動影響嘅 test 數(改 1 個 field) | < 5 | 5-20 | > 20(factory 太散) |
| Test setup 平均行數 | ≤ 5 行 / test | 5-15 行 | > 15 行 |

---

## 🆚 同其他測試 pattern 嘅關係

| Pattern | 用嚟做 | 互補 |
|---------|--------|------|
| **Fixture Factory**(本 skill) | 統一 test data 產生 | Pair with unit test / integration test |
| **Builder pattern** | 同一個 entity 嘅 fluent setup | 適合 super-complex entity,但 verbose |
| **Object Mother** | 預先 bake 嘅 named fixtures | 適合 share "alice-the-admin" 跨多 test |
| **Test Data Builder** | 強調 immutable + chain | 適合 functional style |

**Rule**:**Fixture Factory 為主**,Object Mother 為輔(用嚟表達 scenario),Builder 喺 super-complex 嘅時候先引入。

---

## 🎬 David 嘅實戰情境

情境:某 E-commerce project 有 200+ test,每個 test 開頭都係:
```typescript
const user = { id: '...', email: '...', name: '...', role: 'user', companyId: '...', ... };
const order = { id: '...', userId: user.id, total: 100, ... };
const product = { id: '...', price: 50, stock: 10, ... };
```

加新 field 嘅時候要逐個改,refactor 痛苦。

**正確流程**(用本 skill):
1. **建 `test/factories/user-factory.ts`**:把 default object 搬入 `buildUser(overrides)`
2. **建 `test/factories/order-factory.ts`** + `product-factory.ts`
3. **加 `factory.SubFactory` pattern**:Order 自動 trailing User,Product
4. **每個 test 改用 factory**:`const user = buildUser({ role: 'admin' })`
5. **加 cleanup**(transaction rollback)
6. **結果**:
   - 加新 field → 改 factory 一處
   - 跨 test 污染 → 0
   - 新 developer onboarding → 1 個 import + 1 個 function call

**錯誤流程**:
- 「Inline OK 啦,改動都唔多」→ 50 → 100 → 200 test 後變噩夢
- 「抄個 fixture file 共享啦」→ 改 entity shape 要改 N 個 test file

---

## Related docs

- [Testing strategy](../testing-strategy.md)
- [Testing strategy tiered](../testing-strategy-tiered.md)
- [Flaky test handling](../flaky-test-handling.md)
- [Regression guard skill](../regression-guard/SKILL.md)
- [Unit test coverage push skill](./unit-test-coverage-push/SKILL.md)