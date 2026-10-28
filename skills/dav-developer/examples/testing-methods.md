# 測試方法參考手冊

> 本檔係「揀邊種測試 + 點寫第一個」嘅速查：9 類方法對照表 + 可直接抄嘅骨架。
> **回歸探針**（regression guard）嘅多語言寫法 → 同套本 skill 子檔（`./examples.md`）。

---

## 1. 9 類測試方法對照

- **1**
  - 方法：單元
  - 測試範圍：函數 / 方法
  - 何時用：獨立業務邏輯、邊界條件、TDD
  - 常見工具：Jest / Vitest / pytest
- **2**
  - 方法：集成
  - 測試範圍：模組之間
  - 何時用：介面同資料流、DB 操作、API 路由
  - 常見工具：Supertest / Testcontainers
- **3**
  - 方法：E2E
  - 測試範圍：完整用戶流程
  - 何時用：關鍵旅程（登入、結帳）、發布前驗證
  - 常見工具：Playwright / Cypress
- **4**
  - 方法：快照
  - 測試範圍：輸出結構
  - 何時用：UI 渲染輸出、API 回應結構、配置格式
  - 常見工具：`toMatchSnapshot()`
- **5**
  - 方法：性能
  - 測試範圍：執行效率
  - 何時用：關鍵路徑響應時間、負載穩定性
  - 常見工具：k6 / JMeter / 自訂 benchmark
- **6**
  - 方法：視覺回歸
  - 測試範圍：UI 外觀
  - 何時用：樣式變更、響應式尺寸、多瀏覽器
  - 常見工具：Playwright `toHaveScreenshot()`
- **7**
  - 方法：API
  - 測試範圍：HTTP 端點
  - 何時用：CRUD、參數驗證、認證授權、文件一致性
  - 常見工具：Supertest / REST Client
- **8**
  - 方法：資料庫
  - 測試範圍：真實資料操作
  - 何時用：ORM 行為、遷移腳本、事務原子性
  - 常見工具：真實 DB + transaction rollback
- **9**
  - 方法：Mock / Stub
  - 測試範圍：隔離依賴
  - 何時用：外部服務、錯誤場景、超時、無法控制的第三方
  - 常見工具：jest.mock / nock / monkeypatch

**選型速查（測試金字塔）**：單元 70% ｜ 集成 20% ｜ E2E 10%。越靠上越慢越貴、越貼近用戶。

- **單元 / Mock**
  - 執行速度：⚡ 快
  - 維護成本：低
  - 主要發現：邏輯錯誤、依賴問題
- **集成 / API / DB**
  - 執行速度：🐢 中等
  - 維護成本：中
  - 主要發現：介面問題、查詢問題
- **E2E / 視覺 / 性能**
  - 執行速度：🐌 慢
  - 維護成本：高
  - 主要發現：端到端問題、樣式問題、效能瓶頸

---

## 2. 可直接抄嘅骨架

### 2.1 單元測試

```typescriptdescribe
('add function', () => {

  it('should return sum of two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });

  it('should handle negative numbers', () => {
    expect(add(-1, -2)).toBe(-3);
  });
});
```

### 2.2 集成測試（真實 DB / API）

```typescriptimpor
t request from 'supertest';

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

```typescriptimpor
t { test, expect } from '@playwright/test';

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

```typescriptimpor
t renderer from 'react-test-renderer';

import { Button } from './Button';

test('Button renders correctly', () => {
  const tree = renderer.create(<Button label="Click me" />).toJSON();
  expect(tree).toMatchSnapshot();
});

// 確認變更係預期時更新快照：npx jest --updateSnapshot
```

### 2.5 性能測試

```typescriptit
('API response time should be under 200ms', async () => {

  const start = performance.now();
  await fetch('/api/users');
  expect(performance.now() - start).toBeLessThan(200);
});
```

### 2.6 視覺回歸測試

```typescripttest
('homepage visual regression', async ({ page }) => {

  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('http://localhost:3000');
  await expect(page).toHaveScreenshot('homepage.png', { maxDiffPixelRatio: 0.1 });
});
```

### 2.7 API 測試

```typescriptdescribe
('Users API', () => {

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

```typescriptdescribe
('User Repository', () => {

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

- **純邏輯、純函數**
  - 應該用：單元測試
- **兩三個模組一齊行唔到**
  - 應該用：集成測試
- **用戶只關心「點撳落去」**
  - 應該用：E2E 測試
- **唔想手寫一長串期望值**
  - 應該用：快照測試
- **查資料、寫入、交易**
  - 應該用：資料庫測試
- **第三方 service 唔想真 call**
  - 應該用：Mock / Stub
- **改咗樣式唔知有冇走樣**
  - 應該用：視覺回歸
- **查詢愈嚟愈慢**
  - 應該用：性能測試
