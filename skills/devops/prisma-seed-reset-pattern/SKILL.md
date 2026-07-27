---
name: prisma-seed-reset-pattern
description: Prisma seed 一定要每次重設 role 關聯，否則 AdminPanel 自訂角色會失效
trigger: 當 Prisma seed 需要配合 AdminPanel 角色管理功能時
---


Last-verified: 2026-07-28
# Prisma Seed 重設模式（配合 AdminPanel 角色管理）

## 問題

當 AdminPanel 可以讓管理者新增自訂角色後，seed.ts 如果只是：
```ts
create: { name: 'PM', role: 'pm' },  // 建立時設 role
update: {}                            // 更新時什麼都不做
```
則 AdminPanel 新增的角色永遠無法關聯到用戶。

## 根因

Prisma upsert 的 `update: {}` 是空物件時，**不會清除舊的关联**，而是保留當前狀態。但 seed 每次都重建用戶，第一次建立時有 role，之後 upsert 時 update 是空的，所以 role 維持不變。

但更深的問題是：seed 的邏輯根本不知道哪些用戶應該關聯哪些角色，因為 seed 不知道 AdminPanel 裡管理員新增了什麼角色。

## 正確模式：每次 seed 都重設所有角色

### 1. 建立 userByEmail lookup map

```ts
const builtInUsers = [
  { email: 'admin@test.com', name: '系統管理員', role: 'admin', projectRole: 'admin' },
  { email: 'pm@test.com',    name: '產品經理', role: 'pm',     projectRole: 'pm' },
  { email: 'tech_lead@test.com', name: '技術主管', role: 'tech_lead', projectRole: 'tech_lead' },
  { email: 'developer@test.com', name: '開發人員', role: 'developer', projectRole: 'developer' },
  { email: 'tester@test.com',   name: '測試人員', role: 'tester',   projectRole: 'tester' },
];

const userByEmail: Record<string, { id: string }> = {};
for (const u of builtInUsers) {
  const user = await prisma.user.upsert({ ... });
  userByEmail[u.email] = { id: user.id };
}
```

### 2. 每個內建用戶都用 `update` 明確重設 role

```ts
const user = await prisma.user.upsert({
  where: { email: u.email },
  create: { email: u.email, name: u.name, role: u.role },
  update: { name: u.name, role: u.role },  // ← 每次都重設
});
```

### 3. 如果需要 `createdById`，用 map 而非個別變數

```ts
// ❌ 會有 ReferenceError
create: { createdById: pm.id }  // pm 在迴圈後已不存在

// ✅ 用 map
create: { createdById: userByEmail['pm@test.com'].id }
```

## 驗證

seed 完成後，用以下指令確認角色是否正確：

```bash
npx ts-node --esm prisma/seed.ts
npx ts-node -e "
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();
  prisma.user.findMany().then(users => {
    users.forEach(u => console.log(u.name, '|', u.role));
    prisma.\$disconnect();
  });
"
```

預期輸出：
```
系統管理員 | admin
產品經理 | pm
技術主管 | tech_lead
開發人員 | developer
測試人員 | tester
```

## 關鍵教訓

> **Seed 是真相來源（source of truth）。如果 AdminPanel 允許管理員編輯角色，seed 必須每次都重設這些角色，否則 seed 執行一次後，AdminPanel 的改動就會被「固化」在資料庫裡，且無法通過 seed 修復。**

## 適用場景

- 有 AdminPanel 可新增自訂角色的系統
- Seed 需要配合 RBAC（角色型權限控制）
- 用戶角色需跨環境（dev/staging/prod）保持一致