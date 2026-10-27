# TDD Test Writer 示例

> 本檔係「點樣將 AC 寫成測試」嘅速查：Frontend / Backend 工具棧 + 可直接抄嘅骨架。
> 測試方法（單元 / 集成 / E2E 嘅分別）→ 見同套 `dav-developer` skill 子檔（需同套安裝）。

---

## 🌐 Frontend 測試指南

### 測試金字塔（Frontend）

- **頂**
  - 測試對象：E2E：完整用戶流程
  - 工具：Playwright, Cypress
- **中**
  - 測試對象：集成：組件協作、Context / Store
  - 工具：RTL + 測試 Provider
- **底**
  - 測試對象：單元：組件、Hook、Utils
  - 工具：RTL, Vue Test Utils

### Frontend 測試工具棧

- **測試運行器**
  - 工具：Jest, Vitest, Karma
  - 適用場景：單元 / 集成測試
- **組件測試**
  - 工具：React Testing Library, Vue Test Utils
  - 適用場景：UI 組件
- **Hook 測試**
  - 工具：@testing-library/react-hooks
  - 適用場景：自定義 Hooks
- **狀態管理**
  - 工具：Mock Store (Redux / Zustand)
  - 適用場景：全局狀態
- **E2E**
  - 工具：Playwright, Cypress
  - 適用場景：完整用戶流程
- **視覺回歸**
  - 工具：Percy, Chromatic, Happo
  - 適用場景：UI 視覺一致性
- **Accessibility**
  - 工具：jest-axe, axe-core
  - 適用場景：a11y 合規

### Frontend 測試文件放置

```src
/

├── components/           # *.test.tsx
├── hooks/                # *.hook.test.ts
├── context/              # *.context.test.ts
├── store/                # *.store.test.ts
├── utils/                # *.util.test.ts
└── services/             # API 調用
```

### Frontend 測試示例：React + Testing Library

假設 Backlog 有一個 User Story：
> 作為顧客，我想看到**登入表單驗證**，以便即時知道輸入錯誤。

```tsx
// src/components/LoginForm.test.tsx

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  // ✅ 單元測試：組件渲染
  describe('rendering', () => {
    it('should render email and password fields', () => {
      render(<LoginForm onSubmit={jest.fn()} />);
      expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    });
  });

  // ✅ 單元測試：用戶交互（對應 AC「顯示紅字提示」）
  describe('user interaction', () => {
    it('should show validation error for invalid email', async () => {
      render(<LoginForm onSubmit={jest.fn()} />);
      fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'invalid-email' } });

      await waitFor(() => {
        expect(screen.getByText(/請輸入有效 email/i)).toBeInTheDocument();
      });
    });

    it('should show error message in red for invalid input', async () => {
      render(<LoginForm onSubmit={jest.fn()} />);
      fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'invalid' } });

      const errorMsg = await screen.findByText(/請輸入有效 email/i);
      expect(errorMsg).toHaveClass('text-red-500'); // ✅ AC: 顯示紅字提示
    });
  });

  // ✅ 集成測試：表單提交
  describe('form submission', () => {
    it('should call onSubmit with form data when valid', async () => {
      const onSubmit = jest.fn();
      render(<LoginForm onSubmit={onSubmit} />);
      fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'user@example.com' } });
      fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'password123' } });
      fireEvent.click(screen.getByRole('button', { name: /login/i }));

      await waitFor(() => {
        expect(onSubmit).toHaveBeenCalledWith({
          email: 'user@example.com',
          password: 'password123'
        });
      });
    });
  });
});
```

### Frontend 其他骨架

```typescript
// Vue Test Utils

const wrapper = mount(UserProfile, { props: { name: '張三', avatar: '' } });
expect(wrapper.find('.avatar-placeholder').exists()).toBe(true);

// Hook（renderHook + act）
const { result, rerender } = renderHook(
  ({ value, delay }) => useDebounce(value, delay),
  { initialProps: { value: 'initial', delay: 500 } }
);
rerender({ value: 'updated2', delay: 500 });
await act(async () => { await new Promise(r => setTimeout(r, 600)); });
expect(result.current).toBe('updated2');
```

```typescript
// Playwright E2E

test('should show validation errors in red', async ({ page }) => {
  await page.goto('/login');
  await page.click('[data-testid="submit-btn"]');

  const emailError = page.locator('[data-testid="email-error"]');
  await expect(emailError).toBeVisible();
  const color = await emailError.evaluate(el => window.getComputedStyle(el).color);
  expect(color).toBe('rgb(239, 68, 68)'); // 紅色
});
```

---

## ⚙️ Backend 測試指南

### 測試金字塔（Backend）

- **頂**
  - 測試對象：E2E / Contract：API 完整流程
  - 工具：Supertest + 真的 server
- **中**
  - 測試對象：集成：API + Database、訊息隊列
  - 工具：Testcontainers / sqlite
- **底**
  - 測試對象：單元：業務邏輯、驗證、轉換
  - 工具：Jest / pytest / JUnit

### Backend 測試工具棧

- **測試運行器**
  - 工具：Jest, pytest, JUnit, Go testing
  - 適用場景：通用測試
- **API 測試**
  - 工具：Supertest, requests, httpx
  - 適用場景：REST API
- **數據庫**
  - 工具：Testcontainers, sqlite
  - 適用場景：集成測試
- **Mock**
  - 工具：sinon, unittest.mock, mockito
  - 適用場景：依賴隔離
- **壓力測試**
  - 工具：k6, Artillery, JMeter
  - 適用場景：性能驗收
- **安全**
  - 工具：OWASP ZAP, SQLMap
  - 適用場景：安全測試

### Backend 測試文件放置

```src
/

├── controllers/          # *.test.ts
├── services/              # *.service.test.ts
├── models/                # *.model.test.ts
├── validators/            # *.validator.test.ts
└── utils/                 # *.util.test.ts

tests/
├── unit/
├── integration/
│   └── __tests__/api/
└── fixtures/
```

### Backend 測試示例：Node.js + Jest + Supertest

```typescript
// tests/integration/payment.test.ts

import request from 'supertest';
import { app } from '../../src/app';
import { db } from '../../src/database';

describe('POST /api/payments', () => {
  beforeEach(async () => {
    await db.query('DELETE FROM payments');
  });

  it('should create payment and return 201', async () => {
    const res = await request(app)
      .post('/api/payments')
      .send({ amount: 100, currency: 'USD' })
      .expect(201);

    expect(res.body.transaction_id).toBeDefined();
    expect(res.body.status).toBe('completed');
  });

  it('should return 400 for invalid amount', async () => {
    await request(app)
      .post('/api/payments')
      .send({ amount: -1, currency: 'USD' })
      .expect(400);
  });
});
```

### Backend 其他骨架

```python
# tests/unit/test_payment_service.py

def test_payment_processing():
    result = payment_service.process({'amount': 100, 'currency': 'USD'})
    assert result.status == 'completed'
    assert result.transaction_id is not None

def test_payment_rejects_invalid_amount():
    with pytest.raises(ValueError):
        payment_service.process({'amount': -1, 'currency': 'USD'})
```

```go
// payment_test.go

func TestPaymentProcess(t *testing.T) {
    result, err := service.Process(100, "USD")
    assert.NoError(t, err)
    assert.Equal(t, "completed", result.Status)
}
```

---

## 🎯 常見測試模式對照

- **單元測試**
  - Frontend 關注點：組件渲染、狀態更新、事件處理
  - Backend 關注點：業務邏輯、數據驗證、轉換函數
- **集成測試**
  - Frontend 關注點：組件協作、Context 提供者
  - Backend 關注點：API + Database、服務協作
- **E2E 測試**
  - Frontend 關注點：完整用戶流程、頁面跳轉
  - Backend 關注點：API 端到端、訊息流程
- **特殊測試**
  - Frontend 關注點：Accessibility、視覺回歸
  - Backend 關注點：性能測試、安全測試

### 測試文件命名約定

```
# Frontend

LoginForm.test.tsx
useAuth.hook.test.ts
authContext.test.tsx

# Backend
payment.service.test.ts
payment.controller.test.ts
test_payment_api.py
payment_test.go
```
