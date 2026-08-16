# 測試方法參考手冊

本文檔收錄日常開發中常用的測試方法，方便快速查找和參考。

---

## 目錄

1. [單元測試 (Unit Testing)](#1-單元測試-unit-testing)
2. [集成測試 (Integration Testing)](#2-集成測試-integration-testing)
3. [端到端測試 (E2E Testing)](#3-端到端測試-e2e-testing)
4. [快照測試 (Snapshot Testing)](#4-快照測試-snapshot-testing)
5. [性能測試 (Performance Testing)](#5-性能測試-performance-testing)
6. [視覺回歸測試 (Visual Regression Testing)](#6-視覺回歸測試-visual-regression-testing)
7. [API 測試](#7-api-測試)
8. [數據庫測試](#8-數據庫測試)
9. [Mocking / Stubbing](#9-mocking--stubbing)

---

## 1. 單元測試 (Unit Testing)

### 定義
測試應用程式中最小的可測試單位（通常是函數或方法），驗證其行為是否符合預期。

### 使用時機
- 測試獨立業務邏輯
- 驗證函數的邊界條件和錯誤處理
- TDD（測試驅動開發）流程
- 確保重構後功能不被破壞

### 簡單範例

```typescript
// 待測試函數
function add(a: number, b: number): number {
  return a + b;
}

// 單元測試
describe('add function', () => {
  it('should return sum of two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });

  it('should handle negative numbers', () => {
    expect(add(-1, -2)).toBe(-3);
  });

  it('should handle zero', () => {
    expect(add(5, 0)).toBe(5);
  });
});
```

---

## 2. 集成測試 (Integration Testing)

### 定義
測試多個模組或服務之間的協作，驗證它們共同運作時的正確性。

### 使用時機
- 測試模組之間的介面和資料流
- 驗證數據庫操作的正確性
- 測試 API 路由和中介層
- 確保組件整合後能正常運作

### 簡單範例

```typescript
import request from 'supertest';
import { app } from '../src/app';
import { db } from '../src/database';

describe('User API Integration', () => {
  beforeAll(async () => {
    await db.connect();
  });

  afterAll(async () => {
    await db.disconnect();
  });

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

---

## 3. 端到端測試 (E2E Testing)

### 定義
模擬真實用戶操作，從頭到尾測試整個應用程式的流程。

### 使用時機
- 驗證關鍵用戶流程（如登入、結帳）
- 測試前後端完整交互
- 發現單元/集成測試無法捕捉的問題
- 發布前的最終驗證

### 簡單範例

```typescript
// Playwright E2E 測試
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

---

## 4. 快照測試 (Snapshot Testing)

### 定義
將輸出結構序列化保存，後續測試時比對是否一致，捕捉非預期的變更。

### 使用時機
- 測試 UI 組件的渲染輸出
- 確保 API 回應結構不被意外改動
- 防止配置文件格式變更
- 大型重構時快速發現差異

### 簡單範例

```typescript
import renderer from 'react-test-renderer';
import { Button } from './Button';

test('Button renders correctly', () => {
  const tree = renderer.create(<Button label="Click me" />).toJSON();
  expect(tree).toMatchSnapshot();
});

// 更新快照（當確認變更是預期時）
// npx jest --updateSnapshot
```

---

## 5. 性能測試 (Performance Testing)

### 定義
測量程式碼或系統的執行效率，包括響應時間、資源消耗、負載能力等。

### 使用時機
- 確保關鍵路徑的響應時間符合要求
- 發現效能瓶頸和記憶體洩漏
- 驗證系統在高負載下的穩定性
- API 效能優化前後對比

### 簡單範例

```typescript
describe('Performance Tests', () => {
  it('API response time should be under 200ms', async () => {
    const start = performance.now();
    
    await fetch('/api/users');
    
    const duration = performance.now() - start;
    expect(duration).toBeLessThan(200);
  });

  it('should handle large data processing efficiently', () => {
    const largeArray = Array.from({ length: 10000 }, (_, i) => i);
    
    const start = performance.now();
    const result = processData(largeArray);
    const duration = performance.now() - start;
    
    expect(duration).toBeLessThan(100);
    expect(result.length).toBe(10000);
  });
});
```

---

## 6. 視覺回歸測試 (Visual Regression Testing)

### 定義
截圖比對 UI 界面，確保視覺呈現與基準版本一致。

### 使用時機
- UI 組件樣式變更檢測
- 確保響應式設計各尺寸一致
- 多瀏覽器/平台視覺兼容性
- 防止樣式意外破壞

### 簡單範例

```typescript
// 使用 Playwright + Visual Comparison
import { test, expect } from '@playwright/test';

test('homepage visual regression', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('http://localhost:3000');
  
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixelRatio: 0.1  // 允許 10% 差異
  });
});
```

---

## 7. API 測試

### 定義
直接對 API 端點發送請求，驗證回應的狀態碼、資料結構和內容。

### 使用時機
- 測試 RESTful API 的 CRUD 操作
- 驗證請求參數驗證和錯誤處理
- 測試認證和授權機制
- 確保 API 文件與實際行為一致

### 簡單範例

```typescript
import request from 'supertest';

describe('Users API', () => {
  describe('GET /api/users/:id', () => {
    it('should return 200 with user data', async () => {
      const res = await request(app)
        .get('/api/users/1')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(res.body).toMatchObject({
        id: 1,
        name: expect.any(String),
        email: expect.any(String)
      });
    });

    it('should return 404 for non-existent user', async () => {
      await request(app).get('/api/users/9999').expect(404);
    });
  });

  describe('POST /api/users', () => {
    it('should return 400 for invalid email', async () => {
      await request(app)
        .post('/api/users')
        .send({ name: 'John', email: 'invalid-email' })
        .expect(400);
    });
  });
});
```

---

## 8. 數據庫測試

### 定義
測試資料庫操作的真實行為，包括 CRUD 操作、事務、查詢效能等。

### 使用時機
- 驗證 ORM 或 Query Builder 的操作正確性
- 測試遷移腳本的執行結果
- 確保事務的原子性和隔離性
- 測試複雜查詢的預期輸出

### 簡單範例

```typescript
import { db } from '../src/database';

describe('User Repository', () => {
  beforeEach(async () => {
    await db.query('DELETE FROM users');
  });

  it('should create user with auto-generated ID', async () => {
    const user = await db.users.create({
      name: 'John',
      email: 'john@example.com'
    });

    expect(user.id).toBeDefined();
    expect(user.createdAt).toBeInstanceOf(Date);
  });

  it('should find user by email', async () => {
    await db.users.create({ name: 'John', email: 'john@example.com' });
    
    const found = await db.users.findByEmail('john@example.com');
    
    expect(found).not.toBeNull();
    expect(found.name).toBe('John');
  });

  it('should delete user and return affected rows', async () => {
    const user = await db.users.create({ name: 'John', email: 'john@example.com' });
    const affected = await db.users.delete(user.id);
    
    expect(affected).toBe(1);
  });
});
```

---

## 9. Mocking / Stubbing

### 定義
用模擬對象替代真實依賴，隔离被測試單元，控制外部行為。

### 使用時機
- 測試需要依賴外部服務（如 API、數據庫）
- 模擬特定場景（錯誤、超時）
- 加速測試執行（無需真實 IO）
- 測試無法控制的第三方組件

### 簡單範例

```typescript
// Mocking 函數
describe('UserService', () => {
  it('should call notification service on signup', async () => {
    const mockNotify = jest.fn();
    jest.mock('../services/notification', () => ({
      sendWelcome: mockNotify
    }));

    const service = new UserService();
    await service.signup({ email: 'test@example.com' });

    expect(mockNotify).toHaveBeenCalledWith('test@example.com');
  });
});

// Stubbing HTTP 請求
it('should handle API error gracefully', async () => {
  nock('https://api.example.com')
    .get('/users/1')
    .reply(500, { error: 'Server Error' });

  const result = await fetchUser(1);
  
  expect(result).toBeNull();
});
```

---

## 快速參考表

| 測試類型 | 測試範圍 | 執行速度 | 維護成本 | 發現問題 |
|---------|---------|---------|---------|---------|
| 單元測試 | 函數/方法 | ⚡ 快 | 低 | 邏輯錯誤 |
| 集成測試 | 模組協作 | 🐢 中等 | 中 | 介面問題 |
| E2E 測試 | 完整流程 | 🐌 慢 | 高 | 端到端問題 |
| 快照測試 | 輸出結構 | ⚡ 快 | 低 | 意外變更 |
| 性能測試 | 執行效率 | 🐌 慢 | 中 | 效能瓶頸 |
| 視覺回歸 | UI 外觀 | 🐌 慢 | 高 | 樣式問題 |
| API 測試 | HTTP 端點 | 🐢 中等 | 中 | API 錯誤 |
| 數據庫測試 | 資料操作 | 🐢 中等 | 中 | 查詢問題 |
| Mocking | 隔離依賴 | ⚡ 快 | 低 | 依賴問題 |

---

> 💡 **提示**：推薦測試金字塔比例
> - 單元測試：70%
> - 集成測試：20%
> - E2E 測試：10%
