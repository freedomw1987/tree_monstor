# TDD Test Writer 示例

---

## 🌐 Frontend 測試指南

### Frontend 測試金字塔

```
        ┌─────────────┐
        │    E2E      │  ← Playwright, Cypress
        │   測試      │
        ├─────────────┤
        │   集成      │  ← 組件協作、Context/Store
        │   測試      │
        ├─────────────┤
        │   單元      │  ← 組件、Hook、Utils
        │   測試      │
        └─────────────┘
```

### Frontend 測試工具棧

| 類型 | 工具 | 適用場景 |
|------|------|----------|
| 測試運行器 | Jest, Vitest, Karma | 單元/集成測試 |
| 組件測試 | React Testing Library, Vue Test Utils | UI 組件 |
| Hook 測試 | @testing-library/react-hooks | 自定義 Hooks |
| 狀態管理 | Mock Store (Redux/Zustand) | 全局狀態 |
| E2E | Playwright, Cypress | 完整用戶流程 |
| 視覺回歸 | Percy, Chromatic, Happo | UI 視覺一致性 |
| Accessibility | jest-axe, axe-core | a11y 合規 |

### Frontend 測試文件放置

```
src/
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

    it('should render submit button', () => {
      render(<LoginForm onSubmit={jest.fn()} />);
      expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument();
    });
  });

  // ✅ 單元測試：用戶交互
  describe('user interaction', () => {
    it('should show validation error for invalid email', async () => {
      const onSubmit = jest.fn();
      render(<LoginForm onSubmit={onSubmit} />);
      
      fireEvent.change(screen.getByLabelText(/email/i), {
        target: { value: 'invalid-email' }
      });
      
      await waitFor(() => {
        expect(screen.getByText(/請輸入有效 email/i)).toBeInTheDocument();
      });
    });

    it('should show error message in red for invalid input', async () => {
      const onSubmit = jest.fn();
      render(<LoginForm onSubmit={onSubmit} />);
      
      fireEvent.change(screen.getByLabelText(/email/i), {
        target: { value: 'invalid' }
      });
      
      const errorMsg = await screen.findByText(/請輸入有效 email/i);
      // ✅ AC: 顯示紅字提示
      expect(errorMsg).toHaveClass('text-red-500'); // 或使用 getComputedStyle
    });
  });

  // ✅ 集成測試：表單提交
  describe('form submission', () => {
    it('should call onSubmit with form data when valid', async () => {
      const onSubmit = jest.fn();
      render(<LoginForm onSubmit={onSubmit} />);
      
      fireEvent.change(screen.getByLabelText(/email/i), {
        target: { value: 'user@example.com' }
      });
      fireEvent.change(screen.getByLabelText(/password/i), {
        target: { value: 'password123' }
      });
      
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

### Frontend 測試示例：Vue + Vue Test Utils

```typescript
// src/components/UserProfile.test.ts
import { mount } from '@vue/test-utils';
import UserProfile from './UserProfile.vue';

describe('UserProfile', () => {
  describe('rendering', () => {
    it('should display user name', () => {
      const wrapper = mount(UserProfile, {
        props: { name: '張三', avatar: '/avatar.png' }
      });
      
      expect(wrapper.text()).toContain('張三');
    });
  });

  describe('props validation', () => {
    it('should show placeholder when no avatar', () => {
      const wrapper = mount(UserProfile, {
        props: { name: '張三', avatar: '' }
      });
      
      expect(wrapper.find('.avatar-placeholder').exists()).toBe(true);
    });
  });
});
```

### Frontend Hook 測試示例

```typescript
// src/hooks/useDebounce.test.ts
import { renderHook, act } from '@testing-library/react';
import { useDebounce } from './useDebounce';

describe('useDebounce', () => {
  it('should debounce value changes', async () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'initial', delay: 500 } }
    );
    
    expect(result.current).toBe('initial');
    
    // 快速更新值
    rerender({ value: 'updated1', delay: 500 });
    rerender({ value: 'updated2', delay: 500 });
    
    // 500ms 後才會 debounce
    await act(async () => {
      await new Promise(resolve => setTimeout(resolve, 600));
    });
    
    expect(result.current).toBe('updated2');
  });
});
```

### Frontend E2E 測試示例：Playwright

```typescript
// tests/e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('登入流程 E2E', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('should show validation errors in red', async ({ page }) => {
    // 點擊提交而不填寫任何內容
    await page.click('[data-testid="submit-btn"]');
    
    // 驗證錯誤訊息是紅色
    const emailError = page.locator('[data-testid="email-error"]');
    await expect(emailError).toBeVisible();
    
    const color = await emailError.evaluate(el => 
      window.getComputedStyle(el).color
    );
    expect(color).toBe('rgb(239, 68, 68)'); // 紅色
  });

  test('should navigate to dashboard after successful login', async ({ page }) => {
    await page.fill('[data-testid="email"]', 'user@example.com');
    await page.fill('[data-testid="password"]', 'password123');
    await page.click('[data-testid="submit-btn"]');
    
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="welcome"]')).toBeVisible();
  });
});
```

---

## ⚙️ Backend 測試指南

### Backend 測試金字塔

```
        ┌─────────────┐
        │   E2E /     │
        │   Contract  │  ← API 完整流程、API Contract
        │   測試      │
        ├─────────────┤
        │   集成      │  ← API + Database、訊息隊列
        │   測試      │
        ├─────────────┤
        │   單元      │  ← 業務邏輯、驗證、轉換
        │   測試      │
        └─────────────┘
```

### Backend 測試工具棧

| 類型 | 工具 | 適用場景 |
|------|------|----------|
| 測試運行器 | Jest, pytest, JUnit, Go testing | 通用測試 |
| API 測試 | Supertest, requests, httpx | REST API |
| 數據庫 | Testcontainers, sqlite | 集成測試 |
| Mock | sinon, unittest.mock, mockito | 依賴隔離 |
| 壓力測試 | k6, Artillery, JMeter | 性能驗收 |
| 安全 | OWASP ZAP, SQLMap | 安全測試 |

### Backend 測試文件放置

```
src/
├── controllers/          # *.test.ts
├── services/              # *.service.test.ts
├── models/                # *.model.test.ts
├── validators/            # *.validator.test.ts
└── utils/                 # *.util.test.ts

tests/
├── unit/
├── integration/
│   └── __tests__/
│       └── api/
└── fixtures/
```

### Backend 測試示例：Node.js + Jest + Supertest

```typescript
// tests/unit/services/payment.service.test.ts
import { PaymentService } from '../../src/services/payment.service';

describe('PaymentService', () => {
  let paymentService: PaymentService;
  
  beforeEach(() => {
    paymentService = new PaymentService();
  });

  describe('validateCard', () => {
    it('should accept valid Visa card', () => {
      const result = paymentService.validateCard('4111111111111111', 'visa');
      expect(result.isValid).toBe(true);
    });

    it('should accept valid MasterCard', () => {
      const result = paymentService.validateCard('5555555555554444', 'mastercard');
      expect(result.isValid).toBe(true);
    });

    it('should reject invalid card number', () => {
      const result = paymentService.validateCard('1234567890123456', 'visa');
      expect(result.isValid).toBe(false);
      expect(result.error).toBe('Invalid card number');
    });
  });

  describe('processPayment', () => {
    it('should return success for valid payment', async () => {
      const result = await paymentService.processPayment({
        cardNumber: '4111111111111111',
        amount: 100,
        currency: 'USD'
      });
      
      expect(result.success).toBe(true);
      expect(result.transactionId).toBeDefined();
    });
  });
});

// tests/integration/api/payment.test.ts
import request from 'supertest';
import { app } from '../../src/app';
import { setupTestDatabase, teardownTestDatabase } from '../helpers';

describe('POST /api/payments', () => {
  beforeAll(async () => {
    await setupTestDatabase();
  });

  afterAll(async () => {
    await teardownTestDatabase();
  });

  describe('validation', () => {
    it('should return 400 for invalid card number', async () => {
      const response = await request(app)
        .post('/api/payments')
        .send({
          cardNumber: 'invalid',
          amount: 100
        });
      
      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Invalid card number');
    });

    it('should return 400 for missing required fields', async () => {
      const response = await request(app)
        .post('/api/payments')
        .send({});
      
      expect(response.status).toBe(400);
      expect(response.body.errors).toBeDefined();
    });
  });

  describe('payment processing', () => {
    it('should process payment and return transaction id', async () => {
      const response = await request(app)
        .post('/api/payments')
        .send({
          cardNumber: '4111111111111111',
          amount: 100,
          currency: 'USD'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.transactionId).toBeDefined();
      expect(response.body.status).toBe('completed');
    });
  });
});
```

### Backend 測試示例：Python + pytest

```python
# tests/unit/test_payment_service.py
import pytest
from unittest.mock import Mock, patch
from src.services.payment import PaymentService

class TestPaymentService:
    """支付服務單元測試"""
    
    def setup_method(self):
        self.service = PaymentService()
    
    def test_validate_card_accepts_visa(self):
        """測試接受有效 Visa 卡號"""
        result = self.service.validate_card('4111111111111111', 'visa')
        assert result.is_valid is True
    
    def test_validate_card_rejects_invalid(self):
        """測試拒絕無效卡號"""
        result = self.service.validate_card('invalid', 'visa')
        assert result.is_valid is False
        assert 'Invalid card number' in result.error
    
    @patch('src.services.payment.PaymentGateway')
    def test_process_payment_calls_gateway(self, mock_gateway):
        """測試處理支付時調用支付網關"""
        mock_gateway.return_value.process.return_value = {
            'status': 'success',
            'transaction_id': 'txn_123'
        }
        
        result = self.service.process_payment({
            'card_number': '4111111111111111',
            'amount': 100
        })
        
        assert result.success is True
        assert result.transaction_id == 'txn_123'


# tests/integration/test_payment_api.py
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

class TestPaymentAPI:
    """支付 API 集成測試"""
    
    def test_create_payment_success(self):
        """測試成功創建支付"""
        response = client.post('/api/payments', json={
            'card_number': '4111111111111111',
            'amount': 100,
            'currency': 'USD'
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'completed'
        assert 'transaction_id' in data
    
    def test_create_payment_validation_error(self):
        """測試支付驗證錯誤"""
        response = client.post('/api/payments', json={
            'card_number': 'invalid',
            'amount': -100  # 負數金額
        })
        
        assert response.status_code == 400
        assert 'errors' in response.json()
```

### Backend 測試示例：Go

```go
// services/payment_test.go
package services

import (
    "testing"
)

func TestValidateCard(t *testing.T) {
    service := NewPaymentService()

    tests := []struct {
        name     string
        card     string
        cardType string
        want     bool
    }{
        {"valid visa", "4111111111111111", "visa", true},
        {"valid mastercard", "5555555555554444", "mastercard", true},
        {"invalid card", "1234567890123456", "visa", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := service.ValidateCard(tt.card, tt.cardType)
            if result.IsValid != tt.want {
                t.Errorf("ValidateCard() = %v, want %v", result.IsValid, tt.want)
            }
        })
    }
}

// api/payment_test.go
package api

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestCreatePayment(t *testing.T) {
    router := SetupRouter()

    tests := []struct {
        name       string
        payload    map[string]interface{}
        wantStatus int
    }{
        {
            name: "valid payment",
            payload: map[string]interface{}{
                "card_number": "4111111111111111",
                "amount":      100,
                "currency":    "USD",
            },
            wantStatus: http.StatusOK,
        },
        {
            name: "invalid card",
            payload: map[string]interface{}{
                "card_number": "invalid",
                "amount":      100,
            },
            wantStatus: http.StatusBadRequest,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            body, _ := json.Marshal(tt.payload)
            req, _ := http.NewRequest("POST", "/api/payments", bytes.NewBuffer(body))
            req.Header.Set("Content-Type", "application/json")

            w := httptest.NewRecorder()
            router.ServeHTTP(w, req)

            if w.Code != tt.wantStatus {
                t.Errorf("CreatePayment() status = %v, want %v", w.Code, tt.wantStatus)
            }
        })
    }
}
```

---

## 🎯 常見測試模式對照

### Frontend vs Backend 測試重點

| 測試類型 | Frontend 關注點 | Backend 關注點 |
|---------|----------------|----------------|
| **單元測試** | 組件渲染、狀態更新、事件處理 | 業務邏輯、數據驗證、轉換函數 |
| **集成測試** | 組件協作、Context 提供者 | API + Database、服務協作 |
| **E2E 測試** | 完整用戶流程、頁面跳轉 | API 端到端、訊息流程 |
| **特殊測試** | Accessibility、視覺回歸 | 性能測試、安全測試 |

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
