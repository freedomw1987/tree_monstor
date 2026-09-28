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

---

## 🧠 Jev Oracle 範例（進階）

> 這章是**可選章節**。主流程（上面所有 JSON / bash 範例）對多数項目已足夠。
> 以下是 skill PoC `skills/regression-guard/PoC/` 跑出 M1-M5 的範例輸出，給決定要採用 Jev oracle 的项目參考。

### 範例 User Story：US-101 付款頁

來源：`docs/ac/US-101.md`（4 條 AC：付款頁、錯誤卡、訂單成立、500 錯誤）

#### 範例 1：journey YAML（M2 產出）

```yaml
# journeys/US-101.yaml — 自動生成（M2 Jev 評估出 9 步、2.25/AC 複雜度）
journey_id: US-101
title: AC 範本
source: ../../docs/ac/US-101.md
generated_by: typesafe/jev-1.13
generated_at: '2026-09-28T14:33:19+00:00'
total_steps: 9
steps:
  - id: US-101-AC01-s1
    action: setup_state
    verifying_ac: US-101-AC01
  - id: US-101-AC01-s2
    action: setup_state
    verifying_ac: US-101-AC01
  - id: US-101-AC01-s3
    action: click
    target_text: 結帳
    verifying_ac: US-101-AC01
  # ... 以此類推
```

#### 範例 2：dry-run 主迴路輸出（M3）

```
  US-101-AC01-s1           setup_state   verdict=pass           conf=0.96 sev=0.08 bug=0.10
  US-101-AC01-s2           setup_state   verdict=pass           conf=0.94 sev=0.09 bug=0.12
  US-101-AC01-s3           click         verdict=pass           conf=0.98 sev=0.05 bug=0.08
  US-101-AC02-s1           setup_state   verdict=fail           conf=0.99 sev=1.60 bug=0.43
  US-101-AC02-s2           type          verdict=fail           conf=0.99 sev=1.62 bug=0.50
  US-101-AC03-s1           setup_state   verdict=fail           conf=0.92 sev=1.75 bug=0.45
  US-101-AC03-s2           wait          verdict=fail           conf=0.59 sev=1.18 bug=0.40
  US-101-AC04-s1           setup_state   verdict=fail           conf=0.99 sev=2.76 bug=0.56
  US-101-AC04-s2           observe       verdict=fail           conf=0.99 sev=2.77 bug=0.67

📊 Summary:
   total_steps:        9
   verdict counts:     {'pass': 3, 'fail': 6}
   blocked:            False ()
   total latency:      0ms
   total cost:         $0.000320
   cache hits:         9/9
```

#### 範例 3：end-of-run batch report（M4）

Markdown 報告（`report.md`）：

```markdown
# Regression Report — US-101

**整體健康度**：🔴 red
**修復優先級**：2.96 / 3
**Flaky 可能性**：0.25
**Regression 類型**：real_bug

## 各步 verdict 摘要

| 步驟 | 動作 | 判定 | 信心 | 嚴重度 | 真 bug 機率 |
|------|------|------|------|--------|-------------|
| US-101-AC01-s1 | setup_state | pass | 0.96 | 0.08 | 0.10 |
| US-101-AC04-s2 | observe | fail | 0.99 | 2.77 | 0.67 |
```

#### 範例 4：JSON 報告（CI 用，`report.json`）

```json
{
  "journey_id": "US-101",
  "overall_health": "red",
  "fix_priority": 2.96,
  "flaky_likelihood": 0.25,
  "regression_type": "real_bug",
  "return_code": 1,
  "verdict_counts": {"pass": 3, "fail": 6}
}
```

> **CI 整合提示**：`return_code` 是 `green=0 / yellow=2 / red=1`，可直接讀進 pipeline 決定是否阻擋部署。

### 三種 observer backend 切換

```bash
# 預設 ac_aware（從 fixtures/<story_id>.yaml 讀）
.venv/bin/python run_journey.py journeys/US-101.yaml

# 純 mock（不接 fixture，oracle 會看到空 body 全判 fail）
OBSERVER_BACKEND=mock .venv/bin/python run_journey.py journeys/US-101.yaml

# 真 Chrome driver（M3.1+；要 uv pip install playwright + playwright install chromium）
OBSERVER_BACKEND=playwright .venv/bin/python run_journey.py journeys/US-101.yaml
```

### PoC 詳情

完整 milestone 記錄、程式碼、探針守護見 `PoC/README.md`。
詳細 SKILL 整合見 `SKILL.md` 章節「Jev Oracle 補充（進階）」。

### Fix proposal 範例（M6）

跑出 `real_bug` verdict 後，自動產出信心度報告：

```bash
JEV_FIX_PROPOSAL=1 REGRESSION_REPORT_PATH=/tmp/report ./run_pipeline.sh US-101
```

產出 `/tmp/report-fix-proposal.md`：

```markdown
# Fix Proposal — US-101

> **M6 Jev 信心度報告**（3 題 noul batch call）— PoC 階段，需人工接手寫 fix 細節。

**整體信心度**：0.41 (🟠 低信心)

## 信心度評估

| 維度 | 信心度 | 評級 | 備註 |
|---|---|---|---|
| 問題摘要 | 0.44 | 🟠 低信心 | Jev 認為能寫出 1 句話明確總結 |
| 建議修正 | 0.35 | 🟠 低信心 | Jev 認為能指向特定 component |
| 驗證步驟 | 0.44 | 🟠 低信心 | Jev 認為步驟能在 <5min CI-runnable |

## 原始失敗走跡（reviewer 接手起點）

  [US-101-AC04-s1] setup_state → FAIL conf=0.99 sev=2.76 bug=0.56
    url:    https://example.com/checkout/payment?order=A123
    status: 500
    body:   [setup for US-101-AC04] 服務暫時無法使用，請稍後重試
```

**Reviewer workflow**：
1. 看「整體信心度」— ≥0.5 直接接手；<0.5 先加 observer context
2. 找「評估表」最低那一維 — 通常是「建議修正」維度低，需要更多 code reading
3. 對「原始失敗走跡」找 status 500 步 → 定位 component

### Fix proposal v2 範例（M6.1 LLM Relay）

整體信心度 ≥ 0.5 時，召喚當下對話的 LLM agent 接力寫 fix 文字：

```bash
# 1. 跑 pipeline 產 v1 + v2 prompt bundle
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-101

# 2. 看 prompt bundle
cat /tmp/US-101-run.relay/prompt.md
# → 含 Jev 信心度報告 + 原始失敗走跡 + template

# 3. 在對話中：讀 prompt.md → 寫 fix → 存到 answer.md
#    （由 subagent / pi 本身根據 prompt template 的「產出」段寫）

# 4. 拼 final report
.venv/bin/python fix_proposal_v2.py /tmp/US-101-run.json \
  /tmp/r-final.md --answer-from /tmp/US-101-run.relay/answer.md
```

產出 `/tmp/r-final.md`（LLM 接力成功時）：

```markdown
# Fix Proposal — US-101

（... Jev 信心度報告 ...）

---

## LLM Relay Fix Proposal（M6.1）

**問題分析**：信心度 0.81（高）佐證 — 從走跡看，`/checkout/payment` 在 AC04 連續 2 步
回 500 + 「服務暫時無法使用」訊息，這是真 bug 的典型特徵...

**建議修正**：檢查 `/api/payment` route 的 exception handling（推測）...
應加 try/except 包住 Stripe call 並回 200 + 友善錯誤頁。

**驗證步驟**：
1. `JEV_FIX_PROPOSAL=1 ./run_pipeline.sh US-101` — 預期 9 pass / 0 fail
2. 手動：在 /checkout/payment 用測試卡 4242 4242 4242 4242

**AC 建議**：無

### 信心度佐證對照

- 整體信心度：0.81（門檻 0.5）
- Gating：✅ 通過
- 走跡筆數：6
```

**gating 規則**：

| 整體信心度 | 行為 | final report 內容 |
|---|---|---|
| ≥ 0.5 | 召喚 LLM relay，產 prompt bundle | 信心度報告 + LLM 接力文字 + 走跡對照 |
| < 0.5 | 跳過 LLM relay | 信心度報告 + 走跡，標「reviewer 接手」|

**為什麼是 skill 本身 LLM（不接外部 Claude/GPT）**：
- regression-guard 本身是個 skill → 召喚它時的 LLM（subagent / pi 本身）就是接力的 LLM
- 不增加外部依賴、prompt template 是「檔案」可版本化
- prompt template 位置：`PoC/prompts/fix_relay.md`

### M6.2 patch + re-validate 閉環範例

```bash
# 1. 跑 pipeline 產 fix_proposal_v2.md + patches.json
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 JEV_PATCH_AND_REVALIDATE=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-M62
# → /tmp/r-fix-proposal-v2.md
# → /tmp/r-patches.json  (patch_parser 抽出的結構化 patch 列表)

# 2. 看 patch 列表
cat /tmp/r-patches.json | jq '.patches[] | {file, format, confidence}'
# → [{"file": "fix_proposal.py", "format": "describe_only", "confidence": 0.4}]

# 3. Dry-run patch（看 diff 不改檔案）
.venv/bin/python playwright_patcher.py fix_proposal.py \
  --old '    result = ParseResult()' \
  --new '    result = ParseResult()\n    return result'
# → 👀 action: dry_run + unified diff + .bak 已建

# 4. 真的 apply
.venv/bin/python playwright_patcher.py fix_proposal.py \
  --old '    result = ParseResult()' \
  --new '    result = ParseResult()\n    return result' \
  --apply

# 5. 重跑 journey（patch 後）
.venv/bin/python run_journey.py journeys/US-M62.yaml \
  --json-output /tmp/US-M62-after.json

# 6. 比較 verdict 變化
.venv/bin/python re_validate.py /tmp/US-M62-before.json /tmp/US-M62-after.json
# → # Re-validate Report — US-M62
# → **分類**：🟢 improvement
# → **建議**：keep patch
```

**safety 規則**：

| 條件 | 動作 |
|---|---|
| `old_text` 不存在 | ❌ abort |
| `old_text` 出現 > 1 次 | ❌ abort（拒絕靜默套用）|
| `old_text` 出現 1 次 + dry-run | 👀 產 diff 報告 + 建 .bak，不改檔案 |
| `old_text` 出現 1 次 + --apply | ✅ apply + .bak 已建 |
| `--rollback` | ⏪ 從 .bak 還原 |

**自動分類**：

| fail delta | 分類 | 建議 |
|---|---|---|
| < 0 | 🟢 improvement | keep patch |
| > 0 | 🔴 regression | rollback |
| = 0 | 🟡 no_change | review |

**為什麼 apply + re-validate 不全自動**：
- sandbox 限制：CI 環境不能無人工 commit
- LLM 接力文字可能錯，需人工 review
- M6.2 pipeline 階段只「產 patch 素材」，apply / re-validate 在 sandbox 手動跑
