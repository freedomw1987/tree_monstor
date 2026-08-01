# Mock LLM Server — Offline AI Agent Verification

> **Context**: Backend 嘅 AI chat route `POST /chat/send` 喺冇 `OPENAI_API_KEY` 嘅情況下 return `503 'AI Agent not configured'`。Frontend 嘅 AI chat UI 永遠 verify 唔到。**Workaround**:用 OpenAI-compatible mock server 喺 `/tmp` 行,backend `OPENAI_BASE_URL` 指過去,完整跑通 agent loop。

## 為何要 mock

- ✅ **冇真 LLM key 都做得到 E2E verify**
- ✅ **Deterministic** — 同個 query 永遠返同個 response,易寫 test
- ✅ **可控** — 可以 mock tool call 嘅 args + result
- ✅ **冇成本** — 唔燒 token
- ⚠️ **唔 ship** — mock server 只係 dev 工具,**唔入** docker / CI

## Pattern 1: Node.js Express (推薦)

### Setup

```bash
mkdir -p /tmp/mock-llm
cd /tmp/mock-llm
npm init -y
npm install express
```

### Server (`/tmp/mock-llm/server.cjs`)

完整 starter 喺 `templates/mock-openai-server.cjs`。

```javascript
// 用法:
// PORT=9999 node server.cjs
//
// 然後 backend .env:
// OPENAI_BASE_URL=http://localhost:9999/v1
// OPENAI_API_KEY=mock-key
// OPENAI_MODEL=mock-gpt-4o

const express = require('express')
const app = express()
app.use(express.json({ limit: '10mb' }))

app.post('/v1/chat/completions', (req, res) => {
  const { messages, tools } = req.body
  
  // 1. 攞 last user message
  const lastUserMsg = [...messages].reverse().find(m => m.role === 'user')
  const prompt = lastUserMsg?.content || ''
  
  // 2. 決定點 reply — 可以根據 prompt keyword mock tool call
  let response
  
  if (prompt.includes('top 5 customers')) {
    // Mock 1 個 tool call
    response = {
      id: 'mock-1',
      object: 'chat.completion',
      created: Date.now(),
      model: req.body.model || 'mock-gpt-4o',
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: null,
          tool_calls: [{
            id: 'call_1',
            type: 'function',
            function: {
              name: 'get_top_customers',
              arguments: JSON.stringify({ limit: 5 })
            }
          }]
        },
        finish_reason: 'tool_calls'
      }],
      usage: { prompt_tokens: 100, completion_tokens: 20, total_tokens: 120 }
    }
  } else if (prompt.includes('search') || prompt.includes('find')) {
    response = {
      id: 'mock-2',
      object: 'chat.completion',
      created: Date.now(),
      model: req.body.model || 'mock-gpt-4o',
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: null,
          tool_calls: [{
            id: 'call_1',
            type: 'function',
            function: {
              name: 'search_companies',
              arguments: JSON.stringify({ query: 'ABC', limit: 5 })
            }
          }]
        },
        finish_reason: 'tool_calls'
      }],
      usage: { prompt_tokens: 80, completion_tokens: 15, total_tokens: 95 }
    }
  } else {
    // Default: 純文字 reply
    response = {
      id: 'mock-default',
      object: 'chat.completion',
      created: Date.now(),
      model: req.body.model || 'mock-gpt-4o',
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: `Mock response to: "${prompt}". (This is a deterministic mock — no real LLM.)`
        },
        finish_reason: 'stop'
      }],
      usage: { prompt_tokens: 50, completion_tokens: 30, total_tokens: 80 }
    }
  }
  
  res.json(response)
})

// Tool result mock — 如果用 tool,需要 second call
// 喺 /v1/chat/completions 入面,當 messages 包 tool result 時,mock 最終 reply
app.post('/v1/chat/completions/finalize', (req, res) => {
  const { messages } = req.body
  const lastToolResult = [...messages].reverse().find(m => m.role === 'tool')
  res.json({
    id: 'mock-final',
    object: 'chat.completion',
    created: Date.now(),
    model: req.body.model || 'mock-gpt-4o',
    choices: [{
      index: 0,
      message: {
        role: 'assistant',
        content: `Mocked: found ${lastToolResult?.content?.length || 0} results.`
      },
      finish_reason: 'stop'
    }],
    usage: { prompt_tokens: 200, completion_tokens: 50, total_tokens: 250 }
  })
})

const port = process.env.PORT || 9999
app.listen(port, () => {
  console.log(`Mock LLM server listening on :${port}/v1`)
})
```

### Run + use

```bash
# 1. Start mock
cd /tmp/mock-llm && PORT=9999 node server.cjs &

# 2. Set env
export OPENAI_BASE_URL=http://localhost:9999/v1
export OPENAI_API_KEY=mock-key
export OPENAI_MODEL=mock-gpt-4o

# 3. Restart backend with mock env
docker compose restart api  # or however backend runs

# 4. Test
curl -X POST http://localhost:3000/api/chat/send \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"message": "find top 5 customers"}'

# 5. Cleanup
kill $(lsof -ti:9999)
```

## Pattern 2: Python Flask (alternative)

如果開發環境用 Python 多過 Node:

```python
# /tmp/mock-llm/server.py
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/v1/chat/completions', methods=['POST'])
def chat():
    body = request.get_json()
    messages = body.get('messages', [])
    last_user = next((m for m in reversed(messages) if m['role'] == 'user'), None)
    prompt = last_user.get('content', '') if last_user else ''
    
    return jsonify({
        'id': 'mock-py-1',
        'object': 'chat.completion',
        'created': int(__import__('time').time()),
        'model': body.get('model', 'mock-gpt-4o'),
        'choices': [{
            'index': 0,
            'message': {
                'role': 'assistant',
                'content': f'Mock Python response: "{prompt}"'
            },
            'finish_reason': 'stop'
        }],
        'usage': {'prompt_tokens': 50, 'completion_tokens': 20, 'total_tokens': 70}
    })

if __name__ == '__main__':
    app.run(port=9999)
```

```bash
cd /tmp/mock-llm
python3 -m venv venv
source venv/bin/activate
pip install flask
python3 server.py
```

## Mock strategy — 點決定 reply 內容

| Use case | Mock 行為 |
|----------|----------|
| **Smoke happy path** | Default text reply,test UI 顯示 |
| **Tool call flow** | Mock 1 個 tool_call,backend 執行 tool,second call 返 text |
| **Error path** | Mock `400 Bad Request` response,test frontend error handling |
| **Rate limit** | Mock `429` response,test retry logic |
| **Streaming** | Mock SSE response(`text/event-stream`),test EventSource |
| **Long reply** | Mock 2000-token reply,test UI scroll + loading state |

## Cleanup checklist

- [ ] Mock server 寫喺 `/tmp/mock-llm/`,**唔**入 project
- [ ] `pkill -f "node server.cjs"` 或者 `lsof -ti:9999 | xargs kill` 之後 verify
- [ ] 唔 commit mock server 入 git
- [ ] 唔寫入 `docker-compose.yml`
- [ ] Mock server 唔可以 ship 落 production

## 紅線

> **Mock LLM 紅線**:
> - 永遠唔好 ship mock 落 docker / production
> - Mock server **唔可以**做為 production fallback — 冇 LLM key 就 return 503
> - Mock 用嚟 verify **frontend / agent loop 邏輯**,**唔係**做 E2E test
> - 真嘅 AI 改動必須用真 LLM(OpenAI / Anthropic)做最終 verify

## 配套 templates

- `templates/mock-openai-server.cjs` — 完整 Express OpenAI-compatible mock server starter
