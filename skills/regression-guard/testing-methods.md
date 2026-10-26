# 測試方法參考手冊

> 本檔係「揀邊種測試 + 點寫第一個」嘅速查：9 類方法對照表 + 可直接抄嘅骨架。
> **回歸探針**（regression guard）嘅多語言寫法 → 同套本 skill 子檔（`./examples.md`）。

---

## 1. 9 類測試方法對照

| # | 方法 | 測試範圍 | 何時用 | 常見工具 |
|---|------|---------|--------|---------|
| 1 | 單元 | 函數 / 方法 | 獨立業務邏輯、邊界條件、TDD | Jest / Vitest / pytest |
| 2 | 集成 | 模組之間 | 介面同資料流、DB 操作、API 路由 | Supertest / Testcontainers |
| 3 | E2E | 完整用戶流程 | 關鍵旅程（登入、結帳）、發布前驗證 | Playwright / Cypress |
| 4 | 快照 | 輸出結構 | UI 渲染輸出、API 回應結構、配置格式 | `toMatchSnapshot()` |
| 5 | 性能 | 執行效率 | 關鍵路徑響應時間、負載穩定性 | k6 / JMeter / 自訂 benchmark |
| 6 | 視覺回歸 | UI 外觀 | 樣式變更、響應式尺寸、多瀏覽器 | Playwright `toHaveScreenshot()` |
| 7 | API | HTTP 端點 | CRUD、參數驗證、認證授權、文件一致性 | Supertest / REST Client |
| 8 | 資料庫 | 真實資料操作 | ORM 行為、遷移腳本、事務原子性 | 真實 DB + transaction rollback |
| 9 | Mock / Stub | 隔離依賴 | 外部服務、錯誤場景、超時、無法控制的第三方 | jest.mock / nock / monkeypatch |

**選型速查（測試金字塔）**：單元 70% ｜ 集成 20% ｜ E2E 10%。越靠上越慢越貴、越貼近用戶。

| 測試類型 | 執行速度 | 維護成本 | 主要發現 |
|---------|---------|---------|---------|
| 單元 / Mock | ⚡ 快 | 低 | 邏輯錯誤、依賴問題 |
| 集成 / API / DB | 🐢 中等 | 中 | 介面問題、查詢問題 |
| E2E / 視覺 / 性能 | 🐌 慢 | 高 | 端到端問題、樣式問題、效能瓶頸 |

---

## 2. 可直接抄嘅骨架

### 2.1 單元測試

```typescript
describe('add function', () => {
  it('should return sum of two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });

  it('should handle negative numbers', () => {
    expect(add(-1, -2)).toBe(-3);
  });
});
```

### 2.2 集成測試（真實 DB / API）

```typescript
import request from 'supertest';
import { app } from '../src/app';
import { db } from '../src/database';

describe('User API Integration', () => {
  beforeAll(async () => { await db.connect(); });
  afterAll(async () => { await db.disconnect(); });

  it('should create user and return correct data', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ name: 'John', email: 'john@example.com' })
      .expect(201);

    expect(response.body.name).toBe('John');
    expect(response.body.id).toBeDefined();
  });
});
```

### 2.3 E2E 測試

```typescript
import { test, expect } from '@playwright/test';

test('user can login and view dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'user@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="submit-btn"]');

  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('h1')).toContainText('Welcome');
});
```

### 2.4 快照測試

```typescript
import renderer from 'react-test-renderer';
import { Button } from './Button';

test('Button renders correctly', () => {
  const tree = renderer.create(<Button label="Click me" />).toJSON();
  expect(tree).toMatchSnapshot();
});

// 確認變更係預期時更新快照：npx jest --updateSnapshot
```

### 2.5 性能測試

```typescript
it('API response time should be under 200ms', async () => {
  const start = performance.now();
  await fetch('/api/users');
  expect(performance.now() - start).toBeLessThan(200);
});
```

### 2.6 視覺回歸測試

```typescript
test('homepage visual regression', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('http://localhost:3000');
  await expect(page).toHaveScreenshot('homepage.png', { maxDiffPixelRatio: 0.1 });
});
```

### 2.7 API 測試

```typescript
describe('Users API', () => {
  it('should return 200 with user data', async () => {
    const res = await request(app)
      .get('/api/users/1')
      .expect('Content-Type', /json/)
      .expect(200);
    expect(res.body).toMatchObject({ id: 1, name: expect.any(String) });
  });

  it('should return 404 for non-existent user', async () => {
    await request(app).get('/api/users/9999').expect(404);
  });
});
```

### 2.8 資料庫測試

```typescript
describe('User Repository', () => {
  beforeEach(async () => { await db.query('DELETE FROM users'); });

  it('should create user with auto-generated ID', async () => {
    const user = await db.users.create({ name: 'John', email: 'john@example.com' });
    expect(user.id).toBeDefined();
    expect(user.createdAt).toBeInstanceOf(Date);
  });
});
```

### 2.9 Mocking / Stubbing

```typescript
// Mock 函數
it('should call notification service on signup', async () => {
  const mockNotify = jest.fn();
  jest.mock('../services/notification', () => ({ sendWelcome: mockNotify }));
  await new UserService().signup({ email: 'test@example.com' });
  expect(mockNotify).toHaveBeenCalledWith('test@example.com');
});

// Stub HTTP 錯誤回應
it('should handle API error gracefully', async () => {
  nock('https://api.example.com').get('/users/1').reply(500, { error: 'Server Error' });
  expect(await fetchUser(1)).toBeNull();
});
```

---

## 3. 揀法提醒

| 情況 | 應該用 |
|------|-------|
| 純邏輯、純函數 | 單元測試 |
| 兩三個模組一齊行唔到 | 集成測試 |
| 用戶只關心「點撳落去」 | E2E 測試 |
| 唔想手寫一長串期望值 | 快照測試 |
| 查資料、寫入、交易 | 資料庫測試 |
| 第三方 service 唔想真 call | Mock / Stub |
| 改咗樣式唔知有冇走樣 | 視覺回歸 |
| 查詢愈嚟愈慢 | 性能測試 |
