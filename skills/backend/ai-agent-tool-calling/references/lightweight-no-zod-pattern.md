# Lightweight AI Agent Pattern (no Zod, no RAG)

When the user explicitly chooses "輕量自製" — meaning a Day 1 agent with 1-10 CRM tools, no RAG yet, no streaming, single user, single channel — **do not use Zod, do not use RAG, do not use streaming**. The skill's main body assumes a heavier setup.

## When this applies

- Product is small (CRM, internal tool, support bot)
- 1-10 tools total
- Single channel (web only — no WhatsApp/Slack/email yet)
- No vector store available yet
- Time-to-first-AI-demo matters more than 100% type safety
- "Just want function calling over our own DB" — no document Q&A needed

## Core simplifications vs the main skill

| Component | Heavy (skill body) | Lightweight (this pattern) |
|---|---|---|
| Tool args schema | Zod + `zod-to-json-schema` | Plain JSON Schema (TS object literal) |
| Tool execution args | `z.infer<T>` typed | `args: any` — runtime `JSON.parse()` only |
| Memory | DB + KV + vector store | Just DB (`Conversation` + `ConversationMessage`) |
| RAG | Embeddings + pgvector | None — agent uses tools to query DB |
| Streaming | SSE | Single response (full reply at end) |
| RBAC | `requiresPermission: string[]` per tool | None in v1 — auth via JWT only |
| Tool result wrapper | `{ok, data, summary}` discriminated union | Just return whatever Prisma returns |
| Library deps | `zod`, `zod-to-json-schema`, `langchain` etc. | Just `openai` SDK |

## Tool interface (this pattern)

```typescript
export interface Tool {
  name: string;
  description: string;       // LLM reads this to decide which tool to call
  parameters: {              // OpenAI function calling JSON Schema
    type: 'object';
    properties: Record<string, unknown>;
    required?: string[];
  };
  execute: (args: any, ctx: ToolContext) => Promise<unknown>;
}

export interface ToolContext {
  userId: string;
}
```

That's it. No Zod, no `safeParse`, no discriminated union on the result. The agent's orchestration code wraps `JSON.parse(args)` in a try/catch and passes whatever to the tool. If the tool receives bad args, Prisma will throw and the agent will report it.

## Agent loop (this pattern)

```typescript
const MAX_TOOL_ITERATIONS = 6;

for (let iter = 0; iter < MAX_TOOL_ITERATIONS; iter++) {
  const resp = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages,
    tools: toolRegistry.map(t => ({
      type: 'function' as const,
      function: { name: t.name, description: t.description, parameters: t.parameters },
    })),
    tool_choice: 'auto',
  });

  const msg = resp.choices[0]?.message;
  if (!msg) break;
  messages.push(msg);

  // No tool calls → final answer
  if (!msg.tool_calls || msg.tool_calls.length === 0) {
    return msg.content ?? '';
  }

  // Execute each tool call
  for (const tc of msg.tool_calls) {
    const tool = toolRegistry.find(t => t.name === tc.function.name);
    if (!tool) {
      messages.push({ role: 'tool', tool_call_id: tc.id, content: `Unknown tool: ${tc.function.name}` });
      continue;
    }
    let parsedArgs: any = {};
    try { parsedArgs = JSON.parse(tc.function.arguments); } catch {}
    let result: unknown;
    try {
      result = await tool.execute(parsedArgs, { userId });
    } catch (err) {
      result = { error: (err as Error).message };
    }
    messages.push({ role: 'tool', tool_call_id: tc.id, content: JSON.stringify(result) });
  }
}
```

That's the whole loop. ~30 LOC. No fancy error recovery, no RBAC, no retry logic. Works.

## 8 starter tools for a CRM agent

These cover ~80% of "useful" CRM agent use cases without RAG:

| Tool | When agent calls it |
|---|---|
| `search_companies` | "Find company X" / "List customers in industry Y" |
| `get_company` | "Tell me about company X" (drill-down after search) |
| `search_products` | "What products do we have in category X" / "Find product Y" |
| `list_quotations` | "Show me recent quotes" / "What did we quote X" |
| `list_deals` | "What's in our pipeline" / "Show open deals" |
| `draft_quotation` | "Make a quote for X with products Y, Z" |
| `log_activity` | "I called X about Y" / "Note that Z" |
| `get_top_customers` | "Who are our top 5 customers by revenue" |

All 8 are in `templates/tool-registry-template.ts` ready to copy.

## Migration path: lightweight → heavy

When the user later needs RAG / streaming / multi-channel / RBAC, the migration is:
1. Add Zod schemas to each tool's `parameters` (one tool at a time, no big bang)
2. Wrap tool result in `{ ok, data, summary }` discriminated union
3. Add `pgvector` + `indexCompany`/`semanticSearch` tools
4. Switch `POST /chat/send` to `POST /chat/stream` with SSE
5. Add `requiresPermission` per tool

Each step is additive — the lightweight pattern is a strict subset of the heavy pattern, so nothing is "thrown away".

## Lessons from the crm-system Day 1 build

- **`gpt-4o-mini` is the right default for Day 1** — fast, cheap, good enough for 8 tools. Upgrade to `gpt-4o` only when the agent fails on a specific tool use.
- **MAX_TOOL_ITERATIONS = 6 is enough for 8 tools** — agents rarely need more than 3-4 tool calls per turn. 6 gives headroom for "search products → draft quotation → log activity" chains.
- **Conversation memory in DB is more than enough** for a single user with ~50 conversations. No need for vector store for "remember previous conversations" — just load last 20 messages and pass to LLM.
- **Audit trail columns on `Quotation` (`aiPrompt`, `generatedByAi`)** are the single most useful thing to add. When the agent makes a mistake, you can grep `aiPrompt LIKE '%wrong customer%'` and find every quote it generated.
