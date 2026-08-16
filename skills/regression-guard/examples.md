# Regression Guard 多語言實現示例

---

## 🌐 Frontend 探針示例

### React 探針實現

```typescript
// probes/react-probes.ts
import { probe, assert, describe } from './probes';

export function useRegressionGuard() {
  const results: ProbeResult[] = [];

  return {
    // ✅ 組件渲染探針
    probeRender: (componentName: string, renderTime: number) => {
      probe(`render:${componentName}`, renderTime, {
        threshold: 100, // 渲染應在 100ms 內
        unit: 'ms'
      });
    },

    // ✅ 狀態更新探針
    probeStateUpdate: (stateName: string, oldValue: any, newValue: any) => {
      probe(`state:${stateName}`, { old: oldValue, new: newValue }, {
        validate: (actual) => actual.new !== undefined
      });
    },

    // ✅ API 調用探針
    probeApiCall: async (endpoint: string, response: Response) => {
      const probeResult = probe(`api:${endpoint}`, response.status, {
        expected: 200,
        validate: (status) => status >= 200 && status < 300
      });
      
      if (!probeResult.passed) {
        console.error(`💡 ${probeResult.suggestion}`);
      }
    },

    // ✅ 用戶交互探針
    probeInteraction: (eventType: string, target: string, duration: number) => {
      assert(duration < 200, `互動 ${eventType} 在 ${target} 耗時 ${duration}ms，應少於 200ms`);
    }
  };
}

// 使用示例
function UserProfile({ userId }: { userId: string }) {
  const guard = useRegressionGuard();
  const [user, setUser] = useState(null);
  const renderStart = performance.now();

  useEffect(() => {
    const startTime = performance.now();
    
    fetchUser(userId)
      .then(data => {
        probe('api:fetchUser', data, { notNull: true });
        setUser(data);
      });
      
    return () => {
      const duration = performance.now() - startTime;
      probe('api:fetchUser:duration', duration, { threshold: 500 });
    };
  }, [userId]);

  const renderTime = performance.now() - renderStart;
  probe('render:UserProfile', renderTime, { threshold: 100 });

  return <div>{user?.name}</div>;
}
```

### Vue 探針實現

```typescript
// probes/vue-probes.ts
export function useVueProbes() {
  return {
    setup: () => {
      probe('vue:setup', Date.now(), { label: 'Component setup' });
    },

    mounted: (componentName: string) => {
      probe(`vue:mounted:${componentName}`, Date.now(), { 
        label: `${componentName} mounted` 
      });
    },

    watch: (property: string, newValue: any, oldValue: any) => {
      probe(`vue:watch:${property}`, { new: newValue, old: oldValue }, {
        validate: (val) => val.new !== val.old
      });
    }
  };
}

// 使用示例
export default {
  setup() {
    const probes = useVueProbes();
    probes.setup();

    const user = ref(null);
    
    watch(user, (newVal, oldVal) => {
      probes.watch('user', newVal, oldVal);
    });

    onMounted(() => {
      probes.mounted('UserProfile');
    });

    return { user };
  }
};
```

### Frontend 常見探針點

| 探針類型 | 觸發時機 | 預期值 |
|---------|---------|--------|
| `render:componentName` | 組件渲染完成 | 渲染時間 < 100ms |
| `api:endpoint` | API 請求完成 | status 200, response 不為 null |
| `state:stateName` | 狀態更新 | 新值不等於舊值 |
| `interaction:eventType` | 用戶交互 | 響應時間 < 200ms |
| `error:errorType` | 錯誤發生 | 錯誤應被捕獲並記錄 |

---

## ⚙️ Backend 探針示例

### Node.js 探針實現

```typescript
// probes/backend-probes.ts
import { probe, assert, describe } from './probes';

describe('User Module', () => {
  describe('authentication', () => {
    probe('login:valid-credentials', actualUser, expectedUser);
    
    assert(user.id === expectedId, 'User ID should match');
  });

  describe('data-access', () => {
    const startTime = Date.now();
    
    // 數據庫查詢探針
    const result = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
    
    probe('db:query:users', result.rows.length, {
      expected: 1,
      validate: (count) => count >= 0
    });
    
    assert(Date.now() - startTime < 100, 'Query should complete within 100ms');
  });
});

// API 響應探針 Middleware
export function probeMiddleware(req: Request, res: Response, next: NextFunction) {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    probe(`api:${req.method}:${req.path}`, {
      status: res.statusCode,
      duration,
      timestamp: new Date().toISOString()
    }, {
      validate: (result) => result.status < 500
    });
    
    if (duration > 1000) {
      console.warn(`💡 Slow API: ${req.path} took ${duration}ms`);
    }
  });
  
  next();
}
```

### Python 探針實現

```python
# probes/python_probes.py
from probes import probe, assert_, describe

@describe('Payment Module')
class TestPaymentRegression:
    """支付模組回歸探針"""
    
    def test_payment_processing(self):
        """處理支付探針"""
        result = payment_service.process({
            'amount': 100,
            'currency': 'USD'
        })
        
        probe('payment:process:success', result.status, {
            'expected': 'completed',
            'validate': lambda r: r in ['completed', 'failed']
        })
        
        assert_(result.transaction_id is not None, 
                'Transaction ID should be generated')
    
    def test_database_query_performance(self):
        """數據庫查詢性能探針"""
        import time
        start = time.time()
        
        users = db.query('SELECT * FROM users')
        
        duration = time.time() - start
        probe('db:query:users:duration', duration, {
            'threshold': 0.1,  # 100ms
            'unit': 'seconds'
        })
        
        assert_(duration < 0.1, f'Query took {duration}s, should be < 0.1s')
```

### Go 探針實現

```go
// probes/go_probes.go
package probes

import (
    "time"
)

func ProbeHTTP(handler http.HandlerFunc, method, path string) {
    req := httptest.NewRequest(method, path, nil)
    w := httptest.NewRecorder()
    
    start := time.Now()
    handler(w, req)
    duration := time.Since(start)
    
    Probe("http:" + method + ":" + path, map[string]interface{}{
        "status":  w.Code,
        "duration": duration.Milliseconds(),
    }, ProbeConfig{
        Validate: func(data interface{}) bool {
            return w.Code < 500
        },
    })
}

func TestUserService(t *testing.T) {
    Describe("User Module", func() {
        It("should create user", func() {
            start := time.Now()
            user, err := service.CreateUser(&User{Name: "Test"})
            duration := time.Since(start)
            
            Probe("user:create", map[string]interface{}{
                "success":   err == nil,
                "user_id":   user.ID,
                "duration":  duration.Milliseconds(),
            }, ProbeConfig{
                Validate: func(data map[string]interface{}) bool {
                    return data["success"] == true && data["user_id"] != ""
                },
            })
            
            Assert(err == nil, "User creation should succeed")
            Assert(duration < 100, "Creation should take < 100ms")
        })
    })
}
```

---

## 🎯 探針命名規範

### Frontend 探針命名

```
✅ 格式: {category}:{component|action}:{detail}

render:UserProfile
render:ProductCard:list
api:GET:/users
api:POST:/checkout
state:userProfile:loading
state:cart:itemCount
interaction:button:click
error:validation:email
error:api:network
```

### Backend 探針命名

```
✅ 格式: {layer}:{operation}:{entity}

db:query:users
db:insert:orders
db:update:inventory
cache:get:session
cache:set:token
api:POST:/payments
api:GET:/orders/[id]
service:payment:process
service:auth:login
queue:publish:order-created
```

---

## 📊 探針輸出格式

### 文本輸出

```
✅ probe: render:UserProfile (45ms)
✅ probe: api:GET:/users (12ms)
❌ probe: db:query:orders (1234ms)
   actual: 1234ms
   expected: < 100ms
   💡 Suggestion: Add index on orders.user_id and orders.created_at
```

### JSON 報告

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "environment": "production",
  "summary": {
    "frontend": { "total": 5, "passed": 4, "failed": 1 },
    "backend": { "total": 10, "passed": 9, "failed": 1 }
  },
  "failures": [
    {
      "name": "db:query:orders",
      "layer": "backend",
      "actual": 1234,
      "expected": "< 100",
      "suggestion": "Add index on orders.user_id and orders.created_at"
    },
    {
      "name": "render:ProductList",
      "layer": "frontend",
      "actual": { "items": 0 },
      "expected": { "items": "> 0" },
      "suggestion": "Check API response and data binding"
    }
  ]
}
```
