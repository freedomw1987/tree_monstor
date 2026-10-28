# Dav Developer 多語言實現示例

> 本檔是「探針點樣寫」嘅速查表：跨語言 API 對照 + 命名規範 + 輸出格式。
> **Jev Oracle 嘅完整用法**（M6 / M6.1 / M6.2 / M6.3 / M7 / M8 / flaky / CI matrix）→ 同套本 skill 子檔（`./jev-oracle.md`）；
> PoC 嘅程式碼、milestone 證據、fixture → `PoC/README.md`。

---

## 1. 探針 API 跨語言對照

- **TypeScript / JS**
  - probe：`probe(name, value, cfg)`
  - assert：`assert(cond, msg)`
  - describe：`describe(name, fn)`
  - 探針點例：`render:X` / `api:GET:/users` / `state:user`
- **Python**
  - probe：`probe(name, value, cfg)`
  - assert：`assert_(cond, msg)`
  - describe：`@describe` 裝飾器
  - 探針點例：`payment:process` / `db:query:users`
- **Go**
  - probe：`Probe(name, value, ProbeConfig{...})`
  - assert：`Assert(cond, msg)`
  - describe：`Describe(name, fn)`
  - 探針點例：`http:GET:/orders` / `user:create`
- **Vue**
  - probe：同 TS（`probe` / `assert`）
  - assert：同 TS
  - describe：`setup()` 內掛鉤
  - 探針點例：`vue:mounted:X` / `vue:watch:prop`

**共通形狀**：`probe(名稱, 實際值, 期望條件)` → 產出一筆可回放嘅紀錄；`assert(條件, 失敗訊息)` → 硬失敗。
條件欄位：`expected` / `threshold` / `validate` / `notNull`。

**通用探針點**（跨層）：

- **`render:componentName`**
  - 觸發時機：組件渲染完成
  - 預期值：渲染時間 < 100ms
- **`api:endpoint`**
  - 觸發時機：API 請求完成
  - 預期值：status 2xx、response 非 null
- **`state:stateName`**
  - 觸發時機：狀態更新
  - 預期值：新值 ≠ 舊值
- **`interaction:eventType`**
  - 觸發時機：用戶交互
  - 預期值：響應時間 < 200ms
- **`db:query:entity`**
  - 觸發時機：資料存取
  - 預期值：耗時 < 100ms、筆數符合預期
- **`error:errorType`**
  - 觸發時機：錯誤發生
  - 預期值：錯誤應被捕獲並記錄

---

## 2. 最小可用範例

### 2.1 Frontend（React + TypeScript）

```typescript
// probes/react-probes.ts

import { probe, assert } from './probes';

export function useRegressionGuard() {
  return {
    probeRender: (componentName: string, renderTime: number) =>
      probe(`render:${componentName}`, renderTime, { threshold: 100, unit: 'ms' }),

    probeStateUpdate: (stateName: string, oldValue: unknown, newValue: unknown) =>
      probe(`state:${stateName}`, { old: oldValue, new: newValue }, {
        validate: (actual) => actual.new !== undefined
      }),

    probeApiCall: (endpoint: string, response: Response) => {
      const result = probe(`api:${endpoint}`, response.status, {
        expected: 200,
        validate: (status) => status >= 200 && status < 300
      });
      if (!result.passed) console.error(`💡 ${result.suggestion}`);
    },

    probeInteraction: (eventType: string, target: string, duration: number) =>
      assert(duration < 200, `互動 ${eventType} 在 ${target} 耗時 ${duration}ms，應少於 200ms`)
  };
}
```

### 2.2 Frontend（Vue）

```typescript
// probes/vue-probes.ts

export function useVueProbes() {
  return {
    setup: () => probe('vue:setup', Date.now(), { label: 'Component setup' }),
    mounted: (componentName: string) =>
      probe(`vue:mounted:${componentName}`, Date.now(), { label: `${componentName} mounted` }),
    watch: (property: string, newValue: unknown, oldValue: unknown) =>
      probe(`vue:watch:${property}`, { new: newValue, old: oldValue }, {
        validate: (val) => val.new !== val.old
      })
  };
}
```

### 2.3 Backend（Node.js）

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
    const result = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
    probe('db:query:users', result.rows.length, { expected: 1, validate: (n) => n >= 0 });
    assert(Date.now() - startTime < 100, 'Query should complete within 100ms');
  });
});
```

### 2.4 Backend（Python）

```python
# probes/python_probes.py

from probes import probe, assert_, describe

@describe('Payment Module')
class TestPaymentRegression:
    def test_payment_processing(self):
        result = payment_service.process({'amount': 100, 'currency': 'USD'})
        probe('payment:process:success', result.status, {
            'expected': 'completed',
            'validate': lambda r: r in ['completed', 'failed']
        })
        assert_(result.transaction_id is not None, 'Transaction ID should be generated')

    def test_database_query_performance(self):
        import time
        start = time.time()
        users = db.query('SELECT * FROM users')
        duration = time.time() - start
        probe('db:query:users:duration', duration, {'threshold': 0.1, 'unit': 'seconds'})
        assert_(duration < 0.1, f'Query took {duration}s, should be < 0.1s')
```

### 2.5 Backend（Go）

```go
// probes/go_probes.go

package probes

func ProbeHTTP(handler http.HandlerFunc, method, path string) {
    req := httptest.NewRequest(method, path, nil)
    w := httptest.NewRecorder()
    start := time.Now()
    handler(w, req)
    Probe("http:"+method+":"+path, map[string]interface{}{
        "status": w.Code, "duration": time.Since(start).Milliseconds(),
    }, ProbeConfig{Validate: func(data interface{}) bool { return w.Code < 500 }})
}
```

---

## 3. 探針命名規範

**格式**：Frontend `{category}:{component|action}:{detail}`；Backend `{layer}:{operation}:{entity}`。

```render
:UserProfile          db:query:users

render:ProductCard:list     db:insert:orders
api:GET:/users              db:update:inventory
api:POST:/checkout          cache:get:session
state:userProfile:loading   cache:set:token
state:cart:itemCount        service:payment:process
interaction:button:click    service:auth:login
error:validation:email      queue:publish:order-created
```

進階（採用 Jev oracle 時）可加 `JEV-` prefix，與傳統 `US-101-AC01` 並行不重疊。

---

## 4. 探針輸出格式

### 4.1 文本輸出

```
✅ probe: render:UserProfile (45ms)

✅ probe: api:GET:/users (12ms)
❌ probe: db:query:orders (1234ms)
   actual: 1234ms
   expected: < 100ms
   💡 Suggestion: Add index on orders.user_id and orders.created_at
```

### 4.2 JSON 報告

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
    }
  ]
}
```

---

## 🧠 Jev Oracle 範例（進階）

> **可選章節**：預設 dav-developer 流程（Steps 1-4 + 上面全部規則）對多数項目已足夠。
> 下面只列**四種輸出嘅長相**；完整用法、gating 規則、safety 規則、CI matrix → 同套本 skill 子檔（`./jev-oracle.md`）。

### 5.1 四種輸出物

- **journey YAML**
  - 例子：`journeys/US-101.yaml`（M2 產，每步對應一條 AC）
  - 用途：描述要跑的步驟
- **dry-run 主迴路**
  - 例子：`US-101-AC01-s1 setup_state verdict=pass conf=0.96 sev=0.08 bug=0.10`
  - 用途：每步判定 + 信心度
- **batch report**
  - 例子：`report.md`（M4）：健康度 🔴/🟡/🟢 + 修復優先級 + flaky 機率
  - 用途：end-of-run 總覽
- **JSON 報告**
  - 例子：`report.json`（CI 用，含 `return_code`）
  - 用途：pipeline gate

**三種 observer backend**（`ac_aware` / `mock` / `playwright`）切換指令見 `./jev-oracle.md`。

### 5.2 Fix proposal（M6）

跑出 `real_bug` verdict 後，自動產出**信心度報告**（不是自動寫 fix）：

```bash
JEV_FIX_PROPOSAL
=1 REGRESSION_REPORT_PATH=/tmp/report ./run_pipeline.sh US-101

# → /tmp/report-fix-proposal.md
```

```markdown
# Fix Proposal — US-101

**整體信心度**：0.41 (🟠 低信心)

## 信心度評估

| 維度 | 信心度 | 評級 |
|---|---|---|
| 問題摘要 | 0.44 | 🟠 低信心 |
| 建議修正 | 0.35 | 🟠 低信心 |
| 驗證步驟 | 0.44 | 🟠 低信心 |

## 原始失敗走跡（reviewer 接手起點）

  [US-101-AC04-s1] setup_state → FAIL conf=0.99 sev=2.76 bug=0.56
    status: 500
```

**Reviewer workflow**：① 看整體信心度（≥0.5 直接接手；<0.5 先加 observer context）② 找最低那一維 ③ 對走跡定位 component。

### 5.3 Fix proposal v2（M6.1 LLM Relay）

整體信心度 **≥ 0.5** 時，召喚**當下對話嘅 LLM agent**接力寫 fix 文字：

```bash
# 1. pipeline 產 v1 + v2 + prompt bundle

JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  REGRESSION_REPORT_PATH=/tmp/r ./run_pipeline.sh US-101
# → /tmp/r-fix-proposal-v2.md + /tmp/US-101-run.relay/prompt.md

# 2. 在對話中接力：讀 prompt.md → 寫 fix → 存 answer.md
#    （由 subagent / pi 本身按 prompt template 的「產出」段寫）

# 3. 拼 final report
.venv/bin/python fix_proposal_v2.py /tmp/US-101-run.json \
  /tmp/r-final.md --answer-from /tmp/US-101-run.relay/answer.md
```

```markdown
# Fix Proposal — US-101

## LLM Relay Fix Proposal（M6.1）

**問題分析**：信心度 0.81（高）佐證 — 從走跡看，`/checkout/payment` 連續 2 步回 500…

**建議修正**：檢查 `/api/payment` route 的 exception handling…

**驗證步驟**：
1. `JEV_FIX_PROPOSAL=1 ./run_pipeline.sh US-101` — 預期 9 pass / 0 fail
```

**gating 規則**：

- **≥ 0.5**
  - 行為：召喚 LLM relay，產 prompt bundle
  - final report 內容：信心度報告 + LLM 接力文字 + 走跡對照
- **< 0.5**
  - 行為：跳過 LLM relay
  - final report 內容：信心度報告 + 走跡，標「reviewer 接手」

**為什麼是 skill 本身 LLM（不接外部 Claude/GPT）**：
- dav-developer 本身係個 skill → 召喚佢時嘅 LLM（subagent / pi 本身）就係接力嘅 LLM
- 不增加外部依賴、prompt template 係「檔案」可版本化
- prompt template 位置：`PoC/prompts/fix_relay.md`
