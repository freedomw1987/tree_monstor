/**
 * Mock OpenAI-Compatible Server
 * ─────────────────────────────
 * 用嚟 offline verify AI agent 對接 (冇真 LLM key 都 work)。
 *
 * 用法:
 *   PORT=9999 node server.cjs
 *
 * 然後 backend env:
 *   OPENAI_BASE_URL=http://localhost:9999/v1
 *   OPENAI_API_KEY=***  (any non-empty value)
 *   OPENAI_MODEL=mock-gpt-4o
 *
 * 永遠唔 ship 落 docker / production。寫喺 /tmp/,唔入 git。
 *
 * 配套 reference: ../references/mock-llm-server.md
 */

const express = require('express')
const app = express()

app.use(express.json({ limit: '10mb' }))

// ============================================================
// In-memory conversation state — track tool_call → tool_result
// ============================================================
const conversations = new Map() // conversationId → messages[]

// ============================================================
// Main endpoint: POST /v1/chat/completions
// ============================================================
app.post('/v1/chat/completions', (req, res) => {
  const { messages, model, tools } = req.body
  const conversationId = req.headers['x-mock-conversation-id'] || 'default'

  if (!conversations.has(conversationId)) {
    conversations.set(conversationId, [])
  }
  const history = conversations.get(conversationId)

  // Save incoming messages
  history.push(...messages)

  // Decide what to do
  const lastUserMsg = [...history].reverse().find((m) => m.role === 'user')
  const lastToolResult = [...history].reverse().find((m) => m.role === 'tool')
  const prompt = lastUserMsg?.content || ''

  let response

  if (lastToolResult) {
    // Second call: tool result 已經收到,finalize
    response = makeTextResponse(
      `Mock LLM: based on tool result "${truncate(lastToolResult.content, 50)}", 搵到 3 個結果。`,
      model
    )
  } else if (/top.*customer|revenue|biggest/i.test(prompt)) {
    // Mock tool_call: get_top_customers
    response = makeToolCallResponse('get_top_customers', { limit: 5 }, model)
  } else if (/search|find|搵/i.test(prompt)) {
    // Mock tool_call: search_companies
    response = makeToolCallResponse('search_companies', { query: 'ABC', limit: 5 }, model)
  } else if (/quote|報價|quotation/i.test(prompt)) {
    // Mock tool_call: draft_quotation
    response = makeToolCallResponse(
      'draft_quotation',
      {
        companyId: 'mock-company-id',
        items: [{ name: 'Mock Product', quantity: 1, unitPrice: 1000 }],
      },
      model
    )
  } else if (/log.*activity|call|email|meeting/i.test(prompt)) {
    // Mock tool_call: log_activity
    response = makeToolCallResponse(
      'log_activity',
      { type: 'CALL', subject: `Mock: ${truncate(prompt, 30)}` },
      model
    )
  } else {
    // Default: 純文字 reply
    response = makeTextResponse(
      `Mock LLM response to: "${truncate(prompt, 100)}". (Deterministic mock — no real LLM.)`,
      model
    )
  }

  // Save assistant response
  history.push(response.choices[0].message)

  res.json(response)
})

// ============================================================
// Health check (for backend readiness probes)
// ============================================================
app.get('/v1/health', (req, res) => {
  res.json({ status: 'ok', mock: true, conversations: conversations.size })
})

// ============================================================
// Helpers
// ============================================================
function makeTextResponse(content, model = 'mock-gpt-4o') {
  return {
    id: `mock-${Date.now()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [
      {
        index: 0,
        message: { role: 'assistant', content },
        finish_reason: 'stop',
      },
    ],
    usage: { prompt_tokens: 50, completion_tokens: content.length / 4, total_tokens: 0 },
  }
}

function makeToolCallResponse(name, args, model = 'mock-gpt-4o') {
  return {
    id: `mock-${Date.now()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [
      {
        index: 0,
        message: {
          role: 'assistant',
          content: null,
          tool_calls: [
            {
              id: `call_${Date.now()}`,
              type: 'function',
              function: {
                name,
                arguments: JSON.stringify(args),
              },
            },
          ],
        },
        finish_reason: 'tool_calls',
      },
    ],
    usage: { prompt_tokens: 80, completion_tokens: 20, total_tokens: 0 },
  }
}

function truncate(s, n) {
  if (typeof s !== 'string') return String(s).slice(0, n)
  return s.length > n ? s.slice(0, n) + '...' : s
}

// ============================================================
// Start
// ============================================================
const port = process.env.PORT || 9999
app.listen(port, () => {
  console.log(`🤖 Mock OpenAI-Compatible LLM Server`)
  console.log(`   Listening on: http://localhost:${port}/v1`)
  console.log(`   Set backend env:`)
  console.log(`     OPENAI_BASE_URL=http://localhost:${port}/v1`)
  console.log(`     OPENAI_API_KEY=*** (any value)`)
  console.log(`     OPENAI_MODEL=mock-gpt-4o`)
  console.log(`   Health: http://localhost:${port}/v1/health`)
  console.log(`   Press Ctrl+C to stop.`)
})
