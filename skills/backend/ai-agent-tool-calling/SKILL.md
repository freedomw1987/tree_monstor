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

## Component 7: Streaming Response (SSE) — `runAgentStream` async generator

**Day 10.1 (2026-06-09) is the canonical reference.** Bare-bones SSE
snippet below; full pattern in
[`references/streaming-sse-protocol.md`](references/streaming-sse-protocol.md).

```typescript
// packages/ai/src/index.ts
export type StreamEvent =
  | { type: 'token';      delta: string }
  | { type: 'tool_start'; name: string; args: unknown }
  | { type: 'tool_end';   name: string; result: unknown; error?: string }
  | { type: 'done';       conversationId: string; usage?: { promptTokens: number; completionTokens: number; totalTokens: number } }
  | { type: 'error';      message: string; code?: string };

export async function* runAgentStream(input: AgentStreamInput): AsyncGenerator<StreamEvent> {
  // 1. Pre-check AiConfig (no env fallback — RG-002)
  const cfg = await prisma.aiConfig.findUnique({ where: { id: 1 } });
  if (!cfg) { yield { type: 'error', message: 'AI Assistant is not configured', code: 'NOT_CONFIGURED' }; return; }

  // 2. LLM call with stream: true
  const stream = await client.chat.completions.create({
    model: cfg.modelName, messages, tools: toolDefs, tool_choice: 'auto',
    stream: true,
    stream_options: { include_usage: true },
  });

  let fullReply = '';
  for await (const chunk of stream) {
    const delta = chunk.choices?.[0]?.delta;
    if (delta?.content) { fullReply += delta.content; yield { type: 'token', delta: delta.content }; }
    // ... accumulate tool_calls ...
  }

  if (noToolCalls) { yield { type: 'done', conversationId: await save(...), usage }; return; }

  // 3. Execute tools serially, emit tool_start/tool_end
  for (const call of toolCalls) {
    yield { type: 'tool_start', name: call.name, args: call.args };
    try { const result = await executeTool(...); yield { type: 'tool_end', name: call.name, result }; }
    catch (err) { yield { type: 'tool_end', name: call.name, result: null, error: String(err) }; }
  }
}
```

Elysia route wraps the generator in a `ReadableStream` and returns
`new Response(stream, { headers: { 'Content-Type': 'text/event-stream',
..., 'X-Accel-Buffering': 'no' } })`. **`X-Accel-Buffering: no` is
the one that 99% of people forget** — without it, nginx buffers the
whole response and you lose streaming. See
`devops/nginx-sse-streaming-fix` for the full nginx side.

Frontend uses `fetch` (NOT `EventSource`, because we need POST) +
`response.body.getReader()` + manual `\n\n` frame splitting. See
[`references/streaming-sse-protocol.md`](references/streaming-sse-protocol.md)
for the full React hook + TypeScript types.

**Why async generator (not just streaming)**: it composes with
`for await (const event of runAgentStream(...))` for natural
backpressure, and a `try/finally` around the loop catches the
`AiNotConfiguredError` defence-in-depth (RG-002/RG-003).

## Component 8: Tool Call UX — Inline Pill, NEVER a Message Bubble

**This is a user-preference rule, locked in after David's Day 10.1
feedback:**

> 「AI 助手有這個情況,應該是調用工具時不用有 message bubble」 — David

The first cut rendered tool invocations the same way as assistant
messages: wrapped in `flex justify-start` + `max-w-[80%]` + bot icon.
User saw a column of grey bubbles that **looked like the agent was
sending multiple messages**, when they were just metadata.

**The rule** (write it in PR review):

> Tool calls MUST render as **small inline pills** above the bot's
> reply bubble. They MUST NEVER render as standalone message bubbles.

A pill:
- small text (text-xs / text-sm)
- **no max-width container** (sizes to content)
- no bot icon
- sits flush-left above the bot reply
- has a `▸` caret to expand args + result JSON
- has a status: pulse while running, muted when ok, red when failed

A bubble (forbidden for tool calls):
- `flex justify-start` + `max-w-[80%]` + `rounded-2xl` + bot icon
- that layout is **only** for user + assistant messages

Full Tailwind + React component spec, DOM verification recipe, and
anti-patterns to grep for, in
[`references/tool-pill-ux.md`](references/tool-pill-ux.md).

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
- `references/audit-existing-before-build.md` — 入 task 之前先 audit 現有 infrastructure 嘅 checklist + 點 discover 已存在嘅 AI agent
- `references/audit-existing-ai-infrastructure.md` — **5-step audit protocol** (filesystem + schema + route listing + container API probe + DB query) — 用嚟 avoid 誤判「backend 冇」嘅 recon error (2026-06-07 lesson)
- `references/mock-llm-server.md` — 冇真 LLM key 點 verify AI agent 對接 — OpenAI-compatible mock server pattern
- `references/ai-config-encryption.md` — DB 存 encrypted API key + env var 拎 encryption key 嘅 production pattern
- `references/streaming-sse-protocol.md` — **2026-06-09 lesson** — 完整 `runAgentStream` async-generator + SSE wire protocol + 5 個 event types + nginx `X-Accel-Buffering: no` 防 buffering + 前端 ReadableStream consume pattern + abort 處理
- `references/tool-pill-ux.md` — **2026-06-09 David feedback** — tool call 嘅 inline pill UX 規則(永遠唔可以做獨立 message bubble)+ `ToolPill` component 設計 + tailwind 細節 + DOM verification recipe

## 配套 templates

- `templates/tool-registry-template.ts` — 8 個 CRM tools (search / draft / log) 嘅 starter code
- `templates/mock-openai-server.cjs` — Express OpenAI-compatible mock server,模擬 tool call 用嚟本地 verify AI agent

## ⚠️ Pitfalls (crm-system 2026-06-08 lessons)

### Pitfall 1: `tsc pass` ≠ `feature work` — 必須 browser/E2E smoke 確認

**場景**(crm-system 2026-06-08,統一 `ManDayEditor` refactor):

我抽 `ManDayEditor` 共享 component 嚟取代 `service-detail.tsx` 同 `QuickCreateServiceDialog` 兩處獨立嘅 form,加晒 import + 改晒 `toWireRows` 邏輯。`tsc --noEmit` 過 ✅,Docker build 過 ✅,**push 去 origin/main** ✅。

**真正問題**:
- `ManDayEditor` 用 `value: ServiceManDay[]` props 但 parent 個 `lines: ServiceManDay[]` state 從未 sync 入 component
- 5 個 `Input` 全部 share 同一個 `row.roleName` global,唔係 per-row binding
- 個 form submit 出去嘅 wire payload 有 5 個空 row `{ role: null, dayRate: 0, days: 0, manDayRoleId: undefined }`
- Backend `/services` route 收到 `data.manDayLines` 個 `TypeError: Cannot read 'properties' of undefined (reading 'map')` → 500

**David 嘅鐵律**:**「睇唔到 = 冇做」** — backend tsc pass + curl 200 唔代表 frontend 唔破壞。

**教訓**:
- ❌ 任何 frontend form refactor **唔可以**只靠 `tsc --noEmit` 就 push
- ❌ 唔可以靠「git diff 睇起來合理」就當 done
- ✅ 必須 browser smoke 真係行個 form + 睇 DB round-trip
- ✅ 如果寫唔到 E2E test,至少要手動 navigate 去個 page + 試 form 嘅 happy path

**Action checklist 喺 frontend refactor 之後**:
1. `tsc --noEmit --skipLibCheck` 過
2. `vite build` 過
3. Docker compose up 過
4. **Browser smoke**:開個 form → 填 → submit → 撳返 detail page 確認 DB round-trip 啱
5. (P0 US) 至少 1 個 happy-path E2E test

### Pitfall 2: Audit existing infrastructure before build (Lesson 2026-06-07)

**場景**(crm-system 2026-06-07,David 提交 T1-T3 嘅 3 個 AI task):

我入 task 第一件事就 plan 寫 5 個 component 嘅 scope + 報 8-9 小時 effort。**但 user 用「A」要求 audit 之後發現**:backend `packages/ai/`(894 lines config + encryption + tools)+ `Conversation` / `ConversationMessage` / `AiConfig` schema + `chat.ts` / `ai-config.ts` route + `ai-chat.tsx` / `ai-config.tsx` page 已經**全部 ship 咗**。我嘅 recon 結論「frontend 寫咗但 backend 完全冇」**完全錯** — 只 grep 咗 5 個 file,冇做 filesystem + DB + container 嘅 systemic audit。

**真正 audit 嘅 5 步 protocol**(從是次 session 學到):

1. **Filesystem search**(narrow, multi-token):
   ```bash
   find apps/ packages/ -type f \( -name "*ai*" -o -name "*chat*" -o -name "*assistant*" -o -name "*llm*" \)
   ```
   唔好只 grep 1-2 個 keyword(`ai` / `chat`),要 grep **所有可能命名**(`assistant` / `llm` / `agent` / `tool`)+ 大細楷 case-insensitive

2. **Schema grep**(DB layer 嘅 evidence):
   ```bash
   grep -n "model\s+AiConfig\|model\s+Conversation\|model\s+ChatMessage\|model\s+Agent" packages/db/prisma/schema.prisma
   ```
   即使冇 backend route, schema model 已代表 design intent

3. **Route / page listing**:
   ```bash
   ls apps/api/src/routes/   # 全部 routes
   ls apps/web/src/pages/    # 全部 pages
   ls packages/               # 有冇 AI / agent 專屬 package
   ```

4. **Container 內實際 API probe**(最關鍵 — 確認 code 唔只係「在」file 入面,**真係 deploy + 跑緊**):
   ```bash
   docker exec crm-api sh -c 'cat > /tmp/probe.mjs << "EOF"
   const r = await fetch("http://localhost:3001/chat/conversations", {
     headers: { Authorization: `Bearer ${token}` }
   });
   console.log(r.status, await r.text());
   EOF
   node /tmp/probe.mjs'
   ```

5. **DB 內容 query**(permissive check — 配 user role 對應 permission 入冇入 table):
   ```bash
   docker exec crm-postgres psql -U crm -d crm_system \
     -c "SELECT permission FROM role_permissions WHERE \"roleId\" = '<admin-role-id>';"
   ```

**教訓**:
- ❌ **Recon 唔可以靠 grep 1-2 個 keyword 然後報「缺咩缺咩」** — 會誤報整個 task 嘅 scope
- ❌ **Recon 唔可以靠「我記憶中冇呢個 component」** — 過去 session 可能已經 build 咗,但 memory 已經 lost
- ✅ **Audit 必做齊 5 步**(filesystem + schema + route listing + container probe + DB query)
- ✅ **Audit 之後先 recon firm 畀 user 揀 option** — 唔係悶頭 plan 5 個 component
- ✅ **Audit 結論寫低落 skill references** — 下次唔好再誤判

**Step 0: Audit before plan, audit before estimate, audit before scope** — 任何 user 報「加 X」嘅 task,**入正題之前**先 audit。

### Pitfall 3: Mock LLM server pattern for offline AI agent verification

**問題**:冇真 LLM key → backend `POST /chat/send` route return `503 'AI Agent not configured'` → 個 AI chat frontend 永遠 verify 唔到。

**Workaround**:喺 `/tmp` 起個 OpenAI-compatible Express mock server(200 行),accept POST `/v1/chat/completions` + 返 deterministic response(可選 mock tool calls),然後 backend env `OPENAI_BASE_URL=http://localhost:9999/v1` 走 mock。

**教訓**:
- Mock server 寫喺 `/tmp/mock-llm/`,**唔寫**入 project
- Express + 1 個 endpoint 就夠,唔需要 sophisticate
- 個 mock 識返 OpenAI function-calling 嘅 SSE format + tool_calls shape
- Verify 完即 kill(`kill $MOCK_PID`),mock 唔 ship 落 docker

**完整 pattern** 見 `references/mock-llm-server.md` + `templates/mock-openai-server.cjs`。

### Pitfall 4: AiConfig encryption — DB 存 encrypted secret, env var 拎 key

**問題**:Admin UI 改 LLM API key 嘅 spec,要求 key 必須存落 DB(唔可以 env-only),**但紅線 1 禁止 plaintext secret 落 DB**。

**Production pattern**(crm-system 2026-06-08):

1. **Schema**:
   ```prisma
   model AiConfig {
     id          Int      @id @default(1)  // singleton
     endpointUrl String
     apiKey      String   // encrypted, never plaintext
     modelName   String
     systemPrompt String? @db.Text
     createdAt   DateTime @default(now())
     updatedAt   DateTime @updatedAt
   }
   ```

2. **Encryption**:`AES-256-GCM`,key 從 `process.env.AI_CONFIG_ENCRYPTION_KEY` 拎(32 bytes hex)
3. **Env var source**:`.env` file(gitignore)+ docker-compose env section,**唔 hardcode**
4. **Migration**:`prisma migrate dev --create-only --name add_ai_config` — 手動睇 SQL
5. **API**:
   - `GET /ai/config` 返 config 但**唔**返 `apiKey` plaintext(返 `apiKeySet: true/false`)
   - `PUT /ai/config` 接受 `apiKey`(optional,如果 pass 落就 encrypt 落 DB)
6. **Frontend**:
   - Form 嘅 API key field 用 `<Input type="password">` + placeholder `現有 API key 已設定,留空保持不變`
   - 唔可以 cleartext 顯示

**完整 code + pitfalls** 見 `references/ai-config-encryption.md`。

### Pitfall 5: AI tool 「full CRUD」interpretation — propose-and-confirm

**問題**:David spec 講「full CRUD」Q2=C — 但 AI 直接做 destructive ops (delete deal, change stage) 風險高。

**Production pattern**(crm-system 2026-06-08):
- **Read + Create safe** — `search_companies`, `draft_quotation` (DRAFT status,user 喺 UI promote), `log_activity` 全部 AI 直接做 OK
- **Update sensitive** — `update_deal_stage`, `update_quotation_status` → **AI 只 propose,唔直接寫**。Frontend 顯示「AI 建議將 deal stage 由 `OPEN` → `WON`,確認執行?」+ user click Confirm
- **Delete** — **AI 永遠唔可以 delete**。如果要 delete,AI 引導 user 去 UI 做

**Schema 標記**:
```typescript
interface Tool {
  name: string
  requiresPermission: Permission[]   // RBAC
  requiresConfirmation?: 'destructive' | 'sensitive' | 'safe'  // UX guard
  execute: (args, ctx) => Promise<unknown>
}
```

**Frontend tool call display**:
- `safe` tool 結果 → 直接 render
- `sensitive` tool 結果 → 顯示「Confirm / Cancel」button 先 fire `execute`
- `destructive` tool 結果 → 永遠冇 button,只係顯示「請去 UI 做」

### Pitfall 6: Chat route 唔可以 check env var,改用 DB `AiConfig` pre-check + typed error translation (RG-002 + RG-003)

**問題**(crm-system 2026-06-09 audit):寫 `chat.ts` 嗰陣作者「defensive」咁加咗一段 `if (!process.env.OPENAI_API_KEY) return 503`,以為「冇 LLM key 就唔好 call LLM」。**呢個違反咗 schema design 嘅 explicit invariant** — `AiConfig` schema 寫咗「singleton row, no env-var fallback, by design (David's T2 spec: 'no LLM env defaults')」。

後果:
- Even with `OPENAI_API_KEY` set, `runAgent()` 用 DB config,**env var 係 dead code**
- But the env-var check still kicks in, returning a misleading 503 唔做實際 LLM call
- TypeScript / runtime 冇 catch 到 — 因為**`process.env.X` 唔喺 type system 入面**

**修正 pattern**:
```typescript
// ❌ WRONG — env var drift, 違反 schema invariant
if (!process.env.OPENAI_API_KEY) {
  set.status = 503;
  return { error: 'AI Agent not configured (OPENAI_API_KEY missing)' };
}

// ✅ CORRECT — DB pre-check + typed error translation
import { AiNotConfiguredError } from '@crm/ai';

// Pre-check (cheap, 1 row by PK)
const aiConfig = await prisma.aiConfig.findUnique({
  where: { id: 1 },
  select: { id: true },
});
if (!aiConfig) {
  set.status = 503;
  return {
    error: 'AI Assistant is not configured',
    message: 'Ask an admin to set up the AI Assistant at /admin/ai-config.',
  };
}

try {
  return await runAgent({ userId, message, conversationId });
} catch (err) {
  // Defence-in-depth: in case the row is deleted between pre-check and runAgent
  if (err instanceof AiNotConfiguredError) {
    set.status = 503;
    return { error: 'AI Assistant is not configured', message: err.message };
  }
  console.error('[chat] Agent error:', err);
  set.status = 500;
  return { error: 'Agent failed', message: (err as Error).message };
}
```

**Invariant**(寫喺 `docs/REGRESSION-GUARD.md` RG-002):
> `runAgent()` and `/chat/send` MUST use the DB `AiConfig` row. They MUST NEVER read `OPENAI_API_KEY` (or any LLM-related env var) for routing / authorization / pre-flight decisions.

**教訓**:
- ❌ **唔好假設 env var 係「defensive check」** — 如果 schema 寫咗「no env fallback」,env check 已經係 bug
- ❌ **唔好用 generic `(err as Error).message`** — 失去 typed error 嘅好處,503 變 500
- ✅ **Throw typed error class**(`AiNotConfiguredError extends Error`),`instanceof` check 翻譯
- ✅ **Pre-check 喺 runAgent 之前**(cheap DB read),race window 內 fall back to instanceof
- ✅ **Code comment 寫明 invariant**(防止 refactor 重新加 env check)

**Test pattern**(冇 test framework 時 manual smoke):
```bash
# 1. DELETE FROM ai_config → POST /chat/send 應該 503 + 'ask admin'
# 2. PUT /ai/config with mock URL/key → POST /chat/send 應該 attempt 然後 500 with OpenAI 401
#    (證明 LLM 真係用 DB config,唔係 env)
```

### Pitfall 7: RBAC permission enum ↔ role setup drift (RG-004)

**問題**(crm-system 2026-06-09 audit):加新 permission `ai-config:read` / `ai-config:update` 入 `packages/shared/src/permissions.ts` PERMISSIONS map,backend route 用 `userHasPermission(userId, 'ai-config:read')` 保護。**但 seed.ts / role setup 冇 grant 呢 2 個 permission 落 ADMIN role** — 即係 **admin 自己 GET /api/ai/config 都 403**。

後果:
- 35 個 permission 入面冇 `ai-config:*` → backend 返 403 `Forbidden: missing permission 'ai-config:read'`
- 唔影響 normal user(根本冇 access 個 nav link),但**完全 block admin 用新 feature**
- TypeScript 唔 catch(TypeScript 睇唔到 DB row),manual smoke 唔跑(冇 admin 自己試)

**修正 pattern** — 3 條強制:
1. **新加 permission 嘅 commit 必須包埋 1 個 DB INSERT**:
   ```sql
   -- 同一個 migration 或者 same-PR DB script:
   INSERT INTO role_permissions ("roleId", permission, "createdAt")
   VALUES ('role_admin_system_001', 'ai-config:read', NOW()),
          ('role_admin_system_001', 'ai-config:update', NOW())
   ON CONFLICT DO NOTHING;
   ```
2. **Migration discipline**:`prisma migrate dev --create-only` 嘅 SQL 入面加埋 `INSERT INTO role_permissions` (對 system roles 適用)
3. **Startup invariant check**(future):Backend boot 時 assert `every(perm in PERMISSIONS, exists in role_permissions where roleId = ADMIN)`,out-of-sync throw 立即

**Audit step**(發現呢類 bug 嘅 5 分鐘 check):
```bash
docker exec crm-postgres psql -U crm -d <db> -c "
  SELECT DISTINCT permission FROM role_permissions
  WHERE \"roleId\" = 'role_admin_system_001'
  ORDER BY permission;
"
# vs
cat packages/shared/src/permissions.ts | grep -oP "'\K[^:]+(?=:)" | sort -u
# 兩個 output diff 即係 missing permissions
```

**教訓**:
- ❌ **Permission enum 唔可以獨立 commit** — backend route / migration / seed / admin UI 必須**同一個 PR 同步**
- ❌ **Backend route 寫好就當 done** — 冇 admin user 親手試過 = 冇 guarantee 唔 403
- ✅ **3 條 invariant(NEW permission 必同步 3 處)**:enum / route check / role grant
- ✅ **Audit grep 5 分鐘**:`role_permissions` vs `PERMISSIONS` map 嘅 diff
- ✅ **Code comment 喺 seed.ts** 列明「adding new permission here? 記得 GRANT to ADMIN」

**Lesson**:Permission-driven RBAC system 嘅 cross-stack sync 必須係 commit-time invariant,唔可以靠 deployment 後手動補。

### Pitfall 8: AI agent "no streaming" + tool-as-bubble (RG-005, 2026-06-09)

**問題**(crm-system Day 10 ship 嘅 2 個 UX bug):

1. **No streaming.** `client.chat.completions.create()` 冇 `stream: true`
   → 整個 LLM call 完成先返一次 response。Frontend 顯示「AI 諗緊...」
   spinner 5-15 秒,user 覺得 agent **冇回應**(即使 wall time 一樣)。

2. **Tool calls rendered as standalone message bubbles.** `MessageBubble`
   將 `role: 'tool'` 當一般 message,wrap 喺 `flex justify-start` +
   `max-w-[80%]` + bot icon 入面 → 灰色 bubble column 似 "agent send
   咗 3 個 message",其實只係 metadata。

David 嘅 screenshot feedback 同日 ship 兩個 fix:
- Backend `runAgent` 改 `runAgentStream`(async generator),
  yield `{type: 'token'|'tool_start'|'tool_end'|'done'|'error'}`
  events
- Route 返 `text/event-stream` + **`X-Accel-Buffering: no`** header
  (防 nginx buffer)
- Frontend `chatApi.send` 改用 `fetch + ReadableStream`,callback 模式
- New `ToolPill` component — small inline pill, 冇 max-w / 冇 bot icon

**完整 pattern + 5 個 event types** 見 [`references/streaming-sse-protocol.md`](references/streaming-sse-protocol.md) + [`references/tool-pill-ux.md`](references/tool-pill-ux.md)。

**Invariant**(寫喺 `docs/REGRESSION-GUARD.md` RG-005):

> `/chat/send` MUST stream Server-Sent Events as the LLM produces
> tokens, and the UI MUST render tool calls as small inline pills
> adjacent to the assistant's reply — never as standalone message
> bubbles.

**教訓**:
- ❌ **「冇 streaming」唔只係 slow** — 係 UX 死罪,user 覺得 agent hang
- ❌ **Tool call 唔可以包 max-w 容器** — pill 而非 bubble
- ❌ **唔好用 generic catch (`err as Error`)** — `AiNotConfiguredError`
  instanceof 翻譯返 503
- ✅ **LLM call hard-code `stream: true` + `stream_options: { include_usage: true }`**
- ✅ **`X-Accel-Buffering: no` header** 必加(防 nginx buffer)
- ✅ **SSE frame 必須 `\n\n` 結尾** — frontend 靠呢個 split
- ✅ **Use `fetch` not `EventSource`** — POST + JSON body 必須用 fetch
- ✅ **`signal: AbortController.signal`** 一定要 wire 落 fetch — user
  cancel / 換頁要 abort
- ✅ **Pill 嘅 DOM verification**:`grep class="inline-block"` 唔可以
  入 max-w 容器

**Verification recipe**(冇 test framework 時 manual smoke):

```bash
# 1. 確認 SSE headers
curl -i -N -X POST http://localhost/api/chat/send \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d '{"message":"count 1 to 3"}' | head -10
# Expect: content-type: text/event-stream, x-accel-buffering: no

# 2. 確認 5 個 event type
curl -N ... | grep '^data:' | head -20
# Expect: token events (one per chunk), done event with usage
# Tool call: tool_start, tool_end, then more tokens
```

### Pitfall 9: `docker compose up -d` 撞 foreground warning 時,要用 `background=true` flag 唔係 default

**問題**(crm-system Day 10.1):要 force-recreate container 以 pick up
新 build 嘅 image:

```bash
# ❌ 撞 foreground warning + 個 output 截斷
docker compose up -d --force-recreate api
```

個 command 撞咗 "input is not a terminal" warning, 個 exit code 仍然 0
但個 output 唔可靠,後續 `docker exec` 嘅 grep 顯示 container **仲係
舊 source**(新 build 根本冇生效)。

**修正**:

```bash
# ✅ 用 background flag 避 foreground warning
docker compose up -d --force-recreate api &
sleep 12
docker inspect --format='{{.State.Health.Status}}' crm-api
# 然後 verify source pick up
docker exec crm-api grep -c "new-code-marker" /app/path/to/file
```

**Generic lesson**(適用於任何 `docker compose` / `kubectl apply` /
`terraform apply` 撞 foreground warning 嘅情況):
- ✅ 任何 long-lived container command → `background=true, notify_on_complete=true`
- ✅ Force-recreate → `--force-recreate <service>` 必加,否則 container
  仲用舊 image
- ✅ `up -d` 之後 sleep 10-15s 等 health check 過,然後 **grep container
  內** confirm 個新 code 喺度(runtime 唔等於 build success)

### Pitfall 10: TypeScript LSP stale ≠ runtime 真的有錯

**問題**(crm-system Day 10.1):改 `chat.ts` 落 source disk 後,
TypeScript language server 即刻報 `Module '@crm/ai' has no exported
member 'runAgent'` + `prisma.aiConfig` 唔識。

但 **真 runtime / 個 container** 係新 build,**冇錯**(我哋用
`docker exec crm-api grep -c` 確認 6 個新 code 引用喺 container 入面)。

**Symptoms of LSP stale**:
- 改 `package.json` 加 dependency 之後
- `prisma generate` 之後
- `bun install` 之後
- build 之後 LSP 仲係 stale

**修正**:
- ✅ **唔好因為 LSP 報錯就 revert 改動** — 先 build + run smoke 確認
  runtime 真係錯
- ✅ **`docker exec <container> node -e "<smoke>"`** 係 ground truth
- ✅ **LSP 報錯只係 IDE 提示**, 唔係 deployment 阻擋
- ✅ **VSCode `Cmd+Shift+P` → "TypeScript: Restart TS Server"** fix 大部分
  stale case
- ❌ 唔好喺 `import type` 移除/加返時被 LSP 嚇親 — 多 build 一次確認

### Pitfall 11: David 親手 commit fix 嘅時候 — 唔好重做

**問題**(crm-system Day 10.1):我哋 `c0d11b1` commit 入面改咗 `chat.ts`
+ 加咗 2 個 permission 落 RBAC。但 David 同一個時間**親手做咗
呢 3 個 fix** 喺 `d79930e`。

**Detection**:
```bash
git show d79930e --stat        # 睇 David 改咗咩 file
git diff d79930e HEAD -- <file> # 睇我哋 HEAD 同 David 個 commit 嘅 diff
# 0 lines diff = duplicate work
```

**修正**:
- ✅ **commit / push 之前必 `git fetch` + `git log origin/main..HEAD`** — 知道 remote 有冇新 commit
- ✅ **發現我哋同 remote 重疊** → `git reset --soft HEAD~1` 返
  之前 state,`git reset HEAD <overlap-file>` unstage 重疊部分,再
  commit 真正新嘅改動
- ✅ **Cross-reference 寫入 commit message**(`Refs: d79930e`)—
  之後睇 git log 知道兩個 commit 互補
- ❌ 唔好因為「我已經做咗」就 push duplicate — 污染 commit history
- ❌ 唔好因為 David 嘅 commit 用另一個 message 就當唔關我哋事

**Lesson**:Push 之前 5 秒 `git diff origin/main --stat` 可以避免
30 分鐘嘅 rebase cleanup。

### Pitfall 12: Tool arguments that LLM can pass as either ID or natural language name — always build a name↔id resolver (added 2026-06-16, pm-system US-21.6)

**Problem**: AI assistant user types "我想問範例項目的進度" in chat. The LLM, faithfully transcribing the user's intent, calls `get_project_stats({ projectId: "範例項目" })` — passing the **project name** as the projectId argument. Backend `assertProjectAccess(projectId: string)` does `prisma.project.findUnique({ where: { id: "範例項目" } })`, gets `null`, returns `{ ok: false, status: 404, message: "找不到名為『範例項目』的項目" }`. User sees the error, concludes the system is broken.

This is **NOT a backend bug. It is a schema-vs-natural-language interface gap.** The LLM does the only thing its training data suggests: pass the user-named string. The tool schema accepted a generic `string` for `projectId` with no hint that names are valid.

**Symptoms of this trap** (in any tool-calling AI agent):
- User says "show me Acme's deals" → LLM calls `{ companyId: "Acme" }` → 404
- User says "send the email to John" → LLM calls `{ userId: "John" }` → 404
- User says "create a task in Marketing" → LLM calls `{ teamId: "Marketing" }` → 404
- User says "filter by status=Open" → LLM calls `{ statusId: "Open" }` → 404 (vs the proper enum)

**Rule — every tool argument that maps to a user-named entity MUST accept either ID or name** (and the backend must resolve). Affects any tool that operates on:
- `projectId`, `companyId`, `teamId`, `workspaceId` (org structures)
- `userId`, `assigneeId`, `reporterId` (people — usually email-or-name, see Pitfall 12b)
- `tagId`, `categoryId`, `statusId` (taxonomies)
- `customerId`, `vendorId`, `accountId` (CRM entities)

**Pattern — `resolveEntityIdentifier` helper** (proven in pm-system 2026-06-16):

```typescript
// backend/src/utils/project-resolver.ts (template)
import { isUuidLike } from "./is-uuid";

export interface ResolvedEntity {
  ok: true;
  entity: { id: string; name: string };
}
export interface ResolveFailure {
  ok: false;
  message: string;       // user-friendly error
  candidates?: string[]; // accessible alternatives, for LLM to retry
}

export async function resolveEntityIdentifier(
  identifier: string,
  opts: {
    prisma: PrismaClient;
    user: { id: string; role: string };     // for member scoping (privacy)
    isAdmin: (role: string) => boolean;
    scopeToMemberProjects?: boolean;          // true for non-admin
    listAccessibleNames: () => Promise<string[]>;  // helper for error message
  }
): Promise<ResolvedEntity | ResolveFailure> {
  if (!identifier || !identifier.trim()) {
    return { ok: false, message: "未提供 ID 或名稱" };
  }
  const trimmed = identifier.trim();

  // 1. Try as ID first (UUID-shaped or whatever the PK format is)
  if (isUuidLike(trimmed)) {
    const byId = await opts.prisma.entity.findUnique({
      where: { id: trimmed },
      select: { id: true, name: true },
    });
    if (byId) return { ok: true, entity: byId };
  }

  // 2. Try as exact name (case-insensitive)
  const byName = await opts.prisma.entity.findFirst({
    where: {
      name: { equals: trimmed, mode: "insensitive" },
      ...(opts.scopeToMemberProjects && !opts.isAdmin(opts.user.role)
        ? { projectMembers: { some: { userId: opts.user.id } } }
        : {}),
    },
    select: { id: true, name: true },
  });
  if (byName) return { ok: true, entity: byName };

  // 3. Contains fallback (e.g. "範例" → "範例項目")
  const contains = await opts.prisma.entity.findFirst({
    where: {
      name: { contains: trimmed, mode: "insensitive" },
      ...(opts.scopeToMemberProjects && !opts.isAdmin(opts.user.role)
        ? { projectMembers: { some: { userId: opts.user.id } } }
        : {}),
    },
    select: { id: true, name: true },
  });
  if (contains) return { ok: true, entity: contains };

  // 4. Failed — provide accessible alternatives so LLM can retry
  const candidates = await opts.listAccessibleNames();
  return {
    ok: false,
    message: `找不到名為「${trimmed}」的項目。可用的項目: ${candidates.join("、") || "(無)"}`,
    candidates,
  };
}
```

**Tool handler integration** (8-line wrapper replaces the broken pattern):

```typescript
// In chat.ts tool case handler — BEFORE
const { projectId } = args;
const effectiveProjectId = projectId || ctx.projectId;
if (!effectiveProjectId) return { error: "projectId required" };
const access = await assertProjectAccess(ctx.user, effectiveProjectId);
if (!access.ok) return { error: access.message };

// AFTER
const { projectId } = args;
const resolved = await resolveAndAssertProject(projectId, ctx);
if (!resolved.ok) return { error: resolved.message };
// resolved.project.id is the canonical ID
```

**Tool description MUST hint the dual format** (LLM relies on `description` to learn arg semantics):

```typescript
// BAD — schema-only, no hint
description: "取得項目的統計數據,用於生成圖表"

// GOOD — explicit dual format
description: "取得項目的統計數據,用於生成圖表。Sprint 21 US-21.6: projectId 參數可接受項目 ID (UUID) 或項目名稱(例如「範例項目」),會自動 resolve 到對應項目。"
```

**Test coverage required** (20 cases, all PR-merge-blocking for tools that accept user-named args):
- `isUuidLike`: accepts UUID v1-v5 + case-insensitive
- `resolveEntityIdentifier`:
  - empty input → fail with "未提供"
  - UUID exact match → ok
  - UUID not found → fall through to name search
  - name exact match (case-insensitive) → ok
  - name with leading/trailing whitespace → ok
  - name contains fallback (e.g. "範例" → "範例項目") → ok
  - multiple matches with same prefix → returns first (deterministic sort)
  - not found → returns candidates list (1-20 names)
  - non-admin name search scoped to member projects (privacy)
  - admin name search can find any project
  - non-admin's name search for a project they're not in → not found
- `listAccessibleNames`: respects `take: 20` limit, admin → all, sorted

**Pitfall 12b — ID-for-people (email, name)**: For tool args that identify a person (`userId`, `assigneeId`, `reporterId`, `ownerId`), the same rule applies but the resolution key is usually **email** (case-insensitive exact match) rather than name. Names collide too often ("John Smith" × 2). Use `findFirst({ where: { email: { equals: identifier, mode: "insensitive" } } })` as the primary, with display name as fallback.

**Pitfall 12c — Don't break the existing ID fast path**: When a tool already accepts `projectId: "uuid-string"`, the new resolver MUST short-circuit on UUID first (cost: 1 indexed lookup) and only fall through to name search on miss. Do not change behavior for callers passing real IDs — they'd hit a 10x slowdown otherwise.

**Why this isn't "just add a fuzzy search"** — fuzzy search introduces ambiguity. The right model is **deterministic preference order**: UUID → exact name (case-insensitive) → contains fallback. Each step is a single query with an index (or short scan). Total cost: 1-3 DB lookups, < 50ms.

**Why not push the fix into the LLM prompt** — "Always call list_projects first" is a brittle fix. The LLM forgets, the user copies different phrasings, the LLM is asked to batch with other tools. A backend resolver works in 100% of cases regardless of how the LLM chose to phrase the call.

**Invariant** (write in `docs/REGRESSION-GUARD.md`):

> Every tool argument that maps to a user-named entity MUST accept either
> the canonical ID or the entity's name (and any reasonable substring).
> The backend MUST resolve via `resolveEntityIdentifier` and return
> friendly error messages with accessible alternatives.

**Reference implementation** — pm-system `backend/src/utils/project-resolver.ts` + `project-resolver.test.ts` (20 cases), commit `9315a20` on `feat/chat-resolve-project-by-name` branch. Wrapped 8 tool handlers in `resolveAndAssertProject()` helper. Net diff: +450 / -54 lines, 0 regressions. Tool descriptions updated for `get_project_stats` and `search_wiki` to explicitly state the dual format.
