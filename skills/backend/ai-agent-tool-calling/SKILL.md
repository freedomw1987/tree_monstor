---
name: ai-agent-tool-calling
description: Build a tool-calling AI agent (function calling + tool registry + conversation memory + RAG over app data) for any product — CRM, support, internal tools. Use when the user wants a chat assistant that can ACT on the database (not just answer questions), multi-step reasoning, or integration with Slack/WhatsApp/email channels. Works with OpenAI / Anthropic / OpenRouter / MiniMax compatible APIs.
tags: ["ai-agent", "tool-calling", "function-calling", "openai", "anthropic", "rag", "memory", "langchain", "mastra", "langgraph", "chatbot", "whatsapp", "slack"]
---

# AI Agent with Tool Calling (Function Calling + Memory + RAG)

## 觸發時機

- 用戶講「AI agent」「chatbot 可以做嘢」「function calling」「tool use」「agent 識查 DB」
- 用戶要 chat assistant 唔只答問題, 仲要做到嘢 (查詢、新增、更新 CRM records)
- 用戶要 multi-step reasoning: 「問客戶叫咩名 → 查 DB → 計 price → 生成報價單草稿」
- 用戶要做 WhatsApp / Slack / email 嘅 AI agent
- 用戶要 RAG: 將自己嘅 docs / 數據餵畀 LLM 攞準確答案
- 用戶要 memory: agent 記得之前傾過咩 (per conversation / per user)

## 設計原則

1. **Agent ≠ LLM** — Agent = LLM + Tool registry + Memory + Loop 嘅 orchestration
2. **Tools 第一公民** — 每個 tool 一個 typed function + Zod/Valibot schema + 寫死嘅 side-effect 描述
3. **LLM 唔可信** — Tool execution 必須驗證 args (zod parse) + RBAC 限 user permission + 限 rate
4. **Memory 分層**:
   - **Short-term** = 對話 history (ContextWindow)
   - **Long-term** = fact extraction (per-user preferences / facts, 落 DB)
   - **RAG** = semantic search over documents / DB rows (embeddings + vector store)
5. **Streaming by default** — 長 response 用 SSE / WebSocket, UX 唔好等 10 秒先見字
6. **冇 LLM call 都要 work** — Agent 入口必須有 fallback (e.g. command list / search)
7. **Observability 必備** — Log: prompt, tool calls, args, results, tokens, latency. 用 LangSmith / Langfuse / 自家
8. **Token cost 預算** — 設 max_iterations (5-10), max_tokens, 防止 agent loop 失控燒銀紙

## 四件核心 component

```
┌────────────────────────────────────────────────────────┐
│                    Chat Endpoint                        │
│   POST /api/chat   (message + conversationId + userId)  │
└──────────────────────┬─────────────────────────────────┘
                       ↓
        ┌──────────────▼──────────────┐
        │      Agent Orchestrator     │
        │  - load memory (short+long) │
        │  - build system prompt      │
        │  - call LLM with tools      │
        │  - parse tool calls         │
        │  - execute tools (RBAC)     │
        │  - loop until final answer  │
        └──────────────┬──────────────┘
                       ↓
   ┌───────────┬──────┴──────┬───────────┐
   ↓           ↓             ↓           ↓
┌──────┐  ┌─────────┐  ┌────────┐  ┌────────┐
│ LLM  │  │  Tool   │  │ Memory │  │  RAG   │
│ OpenAI│ │Registry │  │  DB    │  │Vector  │
│Anthro│ │ (Zod)   │  │  + KV  │  │  Store │
└──────┘  └─────────┘  └────────┘  └────────┘
```

## Component 1: Tool Registry (核心)

每個 tool = 一個 `{ name, description, schema, execute }` object. 用 Zod / Valibot 定義 schema (LLM 靠 description + schema 揀 tool).

### Tool Interface

```typescript
// packages/ai/tools/types.ts
import { z } from "zod"

export interface Tool<T extends z.ZodTypeAny = z.ZodTypeAny> {
  name: string                       // "create_quotation"
  description: string                // LLM 睇呢度揀 tool. 寫得越清楚越好
  schema: T                          // Zod schema, 自動變 JSON Schema 餵 LLM
  requiresPermission?: Permission[]  // RBAC: ["sales:write"]
  execute: (args: z.infer<T>, ctx: ToolContext) => Promise<ToolResult>
}

export interface ToolContext {
  userId: string
  companyId?: string
  prisma: PrismaClient
  conversationId: string
  abortSignal?: AbortSignal
}

export type ToolResult = 
  | { ok: true; data: unknown; summary: string }  // 成功, 餵返 LLM
  | { ok: false; error: string; retryable: boolean }  // 失敗
```

### 範例: 5 個 CRM tools

```typescript
// packages/ai/tools/crm.ts
import { z } from "zod"
import type { Tool } from "./types"

export const searchCompanies: Tool = {
  name: "search_companies",
  description: "Search companies by name, industry, or status. Use when user asks 'find company X' or 'list my customers in industry Y'.",
  schema: z.object({
    query: z.string().optional().describe("Name or partial name to search"),
    industry: z.string().optional(),
    status: z.enum(["ACTIVE", "INACTIVE", "CHURNED"]).optional(),
    limit: z.number().int().min(1).max(50).default(10),
  }),
  requiresPermission: ["sales:read"],
  execute: async (args, { prisma, userId }) => {
    const companies = await prisma.company.findMany({
      where: {
        deletedAt: null,
        ownerId: userId,
        ...(args.query && { name: { contains: args.query, mode: "insensitive" } }),
        ...(args.industry && { industry: args.industry }),
        ...(args.status && { status: args.status }),
      },
      take: args.limit,
      orderBy: { updatedAt: "desc" },
    })
    return {
      ok: true,
      data: companies,
      summary: `Found ${companies.length} companies matching criteria.`,
    }
  },
}

export const createQuotation: Tool = {
  name: "create_quotation",
  description: "Create a new draft quotation for a company. Generates number Q-YYYY-NNNN. Items must include product SKU, quantity, unit price.",
  schema: z.object({
    companyId: z.string().describe("Company ID (cuid)"),
    contactId: z.string().optional(),
    validDays: z.number().int().min(1).max(365).default(30),
    items: z.array(z.object({
      sku: z.string().describe("Product SKU"),
      quantity: z.number().positive(),
      unitPrice: z.number().nonnegative().describe("Override default; use 0 for free items"),
    })).min(1).max(100),
    notes: z.string().optional(),
  }),
  requiresPermission: ["sales:write"],
  execute: async (args, { prisma, userId }) => {
    // 1. Validate company exists & user owns it
    const company = await prisma.company.findFirst({
      where: { id: args.companyId, ownerId: userId, deletedAt: null },
    })
    if (!company) return { ok: false, error: "Company not found or not owned by you", retryable: false }

    // 2. Snapshot products (use latest, but copy to QuotationItem)
    const products = await prisma.product.findMany({
      where: { sku: { in: args.items.map(i => i.sku) }, isActive: true, deletedAt: null },
    })
    if (products.length !== args.items.length) {
      return { ok: false, error: `Some SKUs not found: ${args.items.map(i => i.sku).filter(s => !products.find(p => p.sku === s)).join(", ")}`, retryable: false }
    }

    // 3. Generate number (Q-YYYY-NNNN via app-level counter)
    const year = new Date().getFullYear()
    const counter = await prisma.counter.upsert({
      where: { name: `quotation-${year}` },
      create: { name: `quotation-${year}`, value: 1 },
      update: { value: { increment: 1 } },
    })
    const number = `Q-${year}-${String(counter.value).padStart(4, "0")}`

    // 4. Calculate totals
    const items = args.items.map((item, i) => {
      const product = products.find(p => p.sku === item.sku)!
      const lineTotal = item.quantity * item.unitPrice
      return {
        order: i,
        productId: product.id,
        sku: product.sku,
        name: product.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        taxRate: product.taxRate,
        lineTotal,
      }
    })
    const subtotal = items.reduce((sum, i) => sum + Number(i.lineTotal), 0)
    const taxTotal = items.reduce((sum, i) => sum + Number(i.lineTotal) * Number(i.taxRate) / 100, 0)
    const total = subtotal + taxTotal

    // 5. Create
    const validUntil = new Date()
    validUntil.setDate(validUntil.getDate() + args.validDays)

    const quotation = await prisma.quotation.create({
      data: {
        number,
        status: "DRAFT",
        validUntil,
        subtotal, taxTotal, total,
        companyId: args.companyId,
        contactId: args.contactId,
        createdById: userId,
        notes: args.notes,
        items: { create: items },
      },
      include: { items: true },
    })

    // 6. Log activity
    await prisma.activityLog.create({
      data: {
        type: "AI_AGENT_ACTION",
        subject: `Created quotation ${number} via AI agent`,
        companyId: args.companyId,
        userId,
        isAiAgent: true,
        metadata: { tool: "create_quotation", args },
      },
    })

    return { ok: true, data: quotation, summary: `Created draft quotation ${number} for ${company.name}, total $${total.toFixed(2)}.` }
  },
}

// ... 3 個 more: get_quotation, send_quotation_email, list_pipeline_deals
```

### Tool Schema → LLM JSON Schema

Zod schema 用 `zod-to-json-schema` 自動轉, 或者用 LLM 嘅原生 function calling format (OpenAI `tools: [{type: "function", function: {name, description, parameters}}]`).

## Component 2: Agent Orchestrator (LLM + loop)

### 基本 loop (5-10 iterations max)

```typescript
// packages/ai/agent.ts
import OpenAI from "openai"
import { zodToJsonSchema } from "zod-to-json-schema"
import { allTools } from "./tools"

const client = new OpenAI()  // or Anthropic, OpenRouter
const MAX_ITERATIONS = 8

interface AgentInput {
  userId: string
  conversationId: string
  message: string
  channel: "WEB" | "WHATSAPP" | "SLACK"
}

export async function runAgent(input: AgentInput, prisma: PrismaClient) {
  // 1. Load conversation history (short-term memory)
  const history = await prisma.message.findMany({
    where: { conversationId: input.conversationId },
    orderBy: { createdAt: "asc" },
    take: 50,  // last 50 messages
  })

  // 2. Load long-term memory (user facts, preferences)
  const user = await prisma.user.findUniqueOrThrow({ where: { id: input.userId } })
  const userFacts = await prisma.userFact.findMany({ where: { userId: input.userId } })

  // 3. Build system prompt with tools + context
  const systemPrompt = buildSystemPrompt({
    user,
    userFacts,
    currentDate: new Date().toISOString().slice(0, 10),
    availableTools: allTools.map(t => t.name),
  })

  // 4. Save user message
  await prisma.message.create({
    data: { conversationId: input.conversationId, role: "USER", content: input.message },
  })

  // 5. Build messages array
  const messages: OpenAI.ChatCompletionMessageParam[] = [
    { role: "system", content: systemPrompt },
    ...history.map(m => ({ role: m.role.toLowerCase() as any, content: m.content })),
    { role: "user", content: input.message },
  ]

  // 6. Loop: LLM ↔ tool execution
  const toolDefs = allTools.map(t => ({
    type: "function" as const,
    function: {
      name: t.name,
      description: t.description,
      parameters: zodToJsonSchema(t.schema),
    },
  }))

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const start = Date.now()
    const response = await client.chat.completions.create({
      model: "gpt-4o",
      messages,
      tools: toolDefs,
      tool_choice: "auto",
      temperature: 0.2,
    })
    const latencyMs = Date.now() - start
    const message = response.choices[0].message

    // 7. No tool calls → final answer
    if (!message.tool_calls || message.tool_calls.length === 0) {
      await prisma.message.create({
        data: {
          conversationId: input.conversationId,
          role: "ASSISTANT",
          content: message.content || "",
          tokens: response.usage?.total_tokens,
          latencyMs,
        },
      })
      return { content: message.content, iterations: i + 1 }
    }

    // 8. Execute tool calls
    messages.push(message)
    const toolResults = []
    for (const call of message.tool_calls) {
      const tool = allTools.find(t => t.name === call.function.name)
      if (!tool) {
        toolResults.push({ tool_call_id: call.id, role: "tool" as const, content: JSON.stringify({ ok: false, error: `Unknown tool: ${call.function.name}` }) })
        continue
      }

      // 8a. RBAC check
      if (tool.requiresPermission && !userHasPermissions(user, tool.requiresPermission)) {
        toolResults.push({ tool_call_id: call.id, role: "tool" as const, content: JSON.stringify({ ok: false, error: "Permission denied" }) })
        continue
      }

      // 8b. Parse args (Zod validates)
      const parseResult = tool.schema.safeParse(JSON.parse(call.function.arguments))
      if (!parseResult.success) {
        toolResults.push({ tool_call_id: call.id, role: "tool" as const, content: JSON.stringify({ ok: false, error: `Invalid args: ${parseResult.error.message}` }) })
        continue
      }

      // 8c. Execute
      try {
        const result = await tool.execute(parseResult.data, {
          userId: input.userId,
          prisma,
          conversationId: input.conversationId,
        })
        toolResults.push({ tool_call_id: call.id, role: "tool" as const, content: JSON.stringify(result) })
        // Log tool call
        await prisma.message.create({
          data: {
            conversationId: input.conversationId,
            role: "TOOL",
            content: JSON.stringify(result),
            toolCalls: [{ name: tool.name, args: parseResult.data, result }],
            latencyMs,
          },
        })
      } catch (e: any) {
        toolResults.push({ tool_call_id: call.id, role: "tool" as const, content: JSON.stringify({ ok: false, error: e.message, retryable: false }) })
      }
    }
    messages.push(...toolResults)
  }

  // 9. Hit max iterations
  return { content: "I got stuck in a loop. Let me try a different approach.", iterations: MAX_ITERATIONS }
}
```

## Component 3: System Prompt 結構

```typescript
function buildSystemPrompt({ user, userFacts, currentDate, availableTools }: any): string {
  return `You are a CRM assistant for ${user.name}, a ${user.role.toLowerCase()} at this company.

Current date: ${currentDate}

## Your capabilities
You have access to these tools: ${availableTools.join(", ")}.

Use them to:
- Search and update customer records
- Create and send quotations
- Look up deal pipeline status
- Generate activity logs

## Guidelines
- Always confirm destructive actions (delete, send email) by describing what you'll do first.
- Never make up data. If you don't know, use a tool to look it up.
- Be concise. Use bullet points for lists.
- For currency, use HKD format ($1,234.56) by default unless user specifies.
- When creating quotations, always snapshot product names and prices from the tool response.

## User context
${userFacts.map((f: any) => `- ${f.key}: ${f.value}`).join("\n")}

## Response format
Default to short, scannable answers. Use markdown only when listing >3 items.`
}
```

## Component 4: RAG (Retrieval-Augmented Generation)

RAG = 將 DB rows / docs 切成 chunk → embed (OpenAI text-embedding-3-small) → 存 vector store (pgvector / Pinecone / Qdrant) → 查嘅時候 top-k → 入 LLM context.

### 簡單 RAG over CRM data

```typescript
// packages/ai/rag.ts
import OpenAI from "openai"
import { Prisma } from "@prisma/client"

const openai = new OpenAI()

// 1. Embed
export async function embed(text: string): Promise<number[]> {
  const res = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: text,
  })
  return res.data[0].embedding
}

// 2. Index a company (called when created/updated)
export async function indexCompany(companyId: string, prisma: PrismaClient) {
  const company = await prisma.company.findUniqueOrThrow({
    where: { id: companyId },
    include: { contacts: true },
  })
  const text = [
    `Company: ${company.name}`,
    company.industry && `Industry: ${company.industry}`,
    company.notes,
    company.contacts.map(c => `Contact: ${c.fullName} (${c.jobTitle}) - ${c.email}`).join("\n"),
  ].filter(Boolean).join("\n")

  const embedding = await embed(text)
  await prisma.companyEmbedding.upsert({
    where: { companyId },
    create: { companyId, embedding, text },
    update: { embedding, text },
  })
}

// 3. Semantic search
export async function semanticSearchCompanies(query: string, prisma: PrismaClient, limit = 5) {
  const embedding = await embed(query)
  // pgvector cosine distance
  const results = await prisma.$queryRaw<Array<{id: string, name: string, text: string, distance: number}>>`
    SELECT c.id, c.name, ce.text, ce.embedding <=> ${embedding}::vector AS distance
    FROM company_embeddings ce
    JOIN companies c ON c.id = ce."companyId"
    WHERE c."deletedAt" IS NULL
    ORDER BY distance ASC
    LIMIT ${limit}
  `
  return results
}
```

### RAG tool for agent

```typescript
export const semanticSearchCompanies: Tool = {
  name: "semantic_search_companies",
  description: "Search companies using natural language (e.g. 'logistics companies in HK' or 'customers we lost last year'). Better than keyword search for vague queries.",
  schema: z.object({
    query: z.string().describe("Natural language search query"),
    limit: z.number().int().min(1).max(20).default(5),
  }),
  execute: async (args, { prisma }) => {
    const results = await semanticSearchCompanies(args.query, prisma, args.limit)
    return {
      ok: true,
      data: results,
      summary: `Found ${results.length} companies semantically similar to "${args.query}".`,
    }
  },
}
```

### pgvector 設定 (Prisma migration)

```sql
-- migrations/xxx_add_pgvector/migration.sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE company_embeddings (
  id TEXT PRIMARY KEY DEFAULT cuid(),
  "companyId" TEXT UNIQUE NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  embedding vector(1536),  -- text-embedding-3-small = 1536 dims
  text TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON company_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

```prisma
// prisma/schema.prisma 加呢段 (Prisma 唔識 pgvector, 用 Unsupported)
model CompanyEmbedding {
  id        String   @id @default(cuid())
  companyId String   @unique
  company   Company  @relation(fields: [companyId], references: [id], onDelete: Cascade)
  embedding Unsupported("vector(1536)")
  text      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

## Component 5: Long-term Memory (User Facts)

```prisma
model UserFact {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  key       String   // "preferred_currency", "default_pipeline", "timezone"
  value     String
  source    String?  // "user_stated" | "inferred" | "tool_observed"
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([userId, key])
  @@map("user_facts")
}
```

每 X 條對話 (e.g. 20) 用 LLM extract facts 入呢個 table。下次 system prompt inject 返。

## Component 6: Multi-channel (Web / WhatsApp / Slack / Email)

唔好將 channel logic 寫入 agent, 用 adapter pattern:

```typescript
// packages/ai/channels/web.ts
export const webChannel = {
  type: "WEB" as const,
  receive: async (req) => {
    const { message, conversationId } = await req.json()
    return { userId: req.user.id, conversationId, message, channel: "WEB" as const }
  },
  send: async (conversationId, content, prisma) => {
    // SSE stream, save to DB
    await prisma.message.create({ data: { conversationId, role: "ASSISTANT", content } })
    return sseResponse(content)
  },
}

// packages/ai/channels/whatsapp.ts
export const whatsappChannel = {
  type: "WHATSAPP" as const,
  receive: async (req) => {
    const body = await req.json()  // WhatsApp webhook payload
    const from = body.entry[0].changes[0].value.messages[0].from
    const text = body.entry[0].changes[0].value.messages[0].text.body
    // Find or create conversation by phone
    let conv = await prisma.conversation.findFirst({ where: { channel: "WHATSAPP", metadata: { path: ["phone"], equals: from } } })
    if (!conv) conv = await prisma.conversation.create({ data: { channel: "WHATSAPP", userId: SYSTEM_USER_ID, metadata: { phone: from } } })
    return { userId: SYSTEM_USER_ID, conversationId: conv.id, message: text, channel: "WHATSAPP" as const }
  },
  send: async (conversationId, content, prisma) => {
    const conv = await prisma.conversation.findUniqueOrThrow({ where: { id: conversationId } })
    const phone = (conv.metadata as any).phone
    await sendWhatsAppMessage(phone, content)  // via Meta Cloud API
  },
}
```

## Streaming Response (SSE)

```typescript
// apps/api/src/routes/chat.ts (Elysia)
.post("/api/chat/stream", async ({ body, user, set }) => {
  set.headers["Content-Type"] = "text/event-stream"
  set.headers["Cache-Control"] = "no-cache"
  set.headers["Connection"] = "keep-alive"

  return new Response(
    new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder()
        const send = (data: any) => controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`))
        const done = () => controller.close()

        try {
          const stream = await openai.chat.completions.create({
            model: "gpt-4o",
            messages: [...],
            stream: true,
            tools: toolDefs,
          })
          for await (const chunk of stream) {
            const delta = chunk.choices[0]?.delta
            if (delta?.content) send({ type: "content", delta: delta.content })
            if (delta?.tool_calls) send({ type: "tool_call", delta: delta.tool_calls })
          }
          send({ type: "done" })
        } catch (e) {
          send({ type: "error", message: (e as Error).message })
        } finally {
          done()
        }
      },
    }),
  )
})
```

Frontend 用 EventSource:
```typescript
const es = new EventSource("/api/chat/stream")
es.onmessage = (e) => {
  const data = JSON.parse(e.data)
  if (data.type === "content") appendToUI(data.delta)
  if (data.type === "tool_call") showToolIndicator(data.delta.function.name)
  if (data.type === "done") es.close()
}
```

## Library 選擇 (build vs buy)

| 做法 | 適合 | Trade-off |
|---|---|---|
| **自己寫 (上面 pattern)** | 1-2 個 channel, 5-20 個 tool, 簡單 RAG | 完全 control, 冇 vendor lock-in, 寫 1-2 週 |
| **Vercel AI SDK** | 純 web, React Next.js | 超方便 streaming, tool calling, 多 model |
| **LangChain.js** | 想要 RAG / agent framework 現成 | 重, abstraction 太厚, 客製化時 debug 痛苦 |
| **Mastra** | TypeScript-first, 多 channel | 新但 solid, 自帶 tool registry + RAG + memory |
| **LangGraph** | 複雜 multi-step 流程 (stateful graph) | 適合多 branch / 條件 workflow, 學習曲線高 |

**建議**: 1-20 tool + 1 channel → 自己寫 (上面 pattern). 20+ tool / 多 channel / 複雜 graph → 用 **Mastra** 或 **LangGraph**.

## 必備嘅 8 個 production hardening

1. **Rate limit** per user: `10 msg/min`. 用 Redis / DB counter
2. **Token cost cap**: 每對話 max 50K tokens, 超過就提示 user 開新對話
3. **Tool execution audit log**: 每個 tool call 落 `ActivityLog` (有 `metadata: {tool, args, result}`)
4. **PII redaction**: 敏感 fields (phone, email, 身份證) response 前 mask, 除 non-`@sales` user
5. **Error fallback**: LLM call fail → 回「我而家答唔到你, 已通知 admin」+ alert
6. **Hallucination guard**: 涉及金額 / 數量嘅 answer 必須基於 tool result, 唔好 LLM 自己噏
7. **Streaming abort**: User 停咗睇 / 換頁 → `AbortController.abort()` 中斷 LLM call
8. **Eval suite**: 20 個真實問答 + 預期 tool calls, CI 跑

## 反 pattern (唔好做)

- ❌ 將 system prompt 寫超過 3000 tokens (浪費 + 容易 outdated)
- ❌ Tool description 寫得模糊 ("manages customer") → LLM 揀錯 tool
- ❌ 冇 RBAC → sales user 可以 call admin-only tool
- ❌ 直接將 DB 全部 row 餵 LLM (token 爆 + privacy leak)
- ❌ 將 tool result 唔 parse 就入 LLM context (大 object 浪費 token)
- ❌ 冇 max_iterations → 無限 loop
- ❌ 將 LLM response 直接顯示畀 user 唔 validate (hallucination 風險)
- ❌ 用 prompt injection 嘅 user input 直接 execute tool args (務必 zod parse)

## 配套 skills

- `devops/bun-elysia-react-vite-stack` — Elysia backend + SSE setup
- `crm-data-model` — 11 個 CRM models, Conversation/Message 已就位
- `elysia-llm-graceful-fallback` — LLM call 失敗嘅 fallback pattern
- `prisma-sqlite-bun-setup` — Prisma 5 (支援 pgvector 唔好, 落 Postgres 啱)
- `prisma-migrate-private-rds` — Production RDS 嘅 migration SOP

## 配套 references

- `references/lightweight-no-zod-pattern.md` — 唔用 Zod / 唔用 RAG 嘅極簡 Day 1 模式(適合 crm-system 規模)

## 配套 templates

- `templates/tool-registry-template.ts` — 8 個 CRM tools (search / draft / log) 嘅 starter code
