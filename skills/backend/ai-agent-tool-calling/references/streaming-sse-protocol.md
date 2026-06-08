# Streaming Responses (SSE protocol) — 2026-06-09 crm-system lesson

## Why streaming (David's feedback)

> 「AI 助手是沒有做流式,所以要等到有晒全部結果才會有回覆」 — David, Day 10.1

Without streaming, the user sees a "AI 諗緊..." spinner for 5–15
seconds while the entire LLM completion is fetched in one shot. From
the user's perspective the agent **feels unresponsive**, even if the
total wall time is the same. Token-by-token emission is the minimum
bar for any chat-style AI agent in 2026.

## Wire protocol — `text/event-stream`

The route returns **one HTTP response with `Content-Type:
text/event-stream`**, and the body is a series of `data: <json>\n\n`
frames. Each frame is exactly one `StreamEvent` JSON object.

### Required response headers

| Header | Value | Why |
|--------|-------|-----|
| `Content-Type` | `text/event-stream; charset=utf-8` | Tells client it's SSE |
| `Cache-Control` | `no-cache, no-transform` | Disables proxy caching |
| `Connection` | `keep-alive` | Keep chunked stream open |
| `X-Accel-Buffering` | `no` | **Critical** — tells nginx NOT to buffer |

`X-Accel-Buffering: no` is the one that 99% of people forget. Without
it, nginx will buffer the entire SSE response until the agent finishes,
defeating the whole point of streaming. See
`devops/nginx-sse-streaming-fix` for the full nginx config.

## Event types — 5 total

```typescript
// packages/ai/src/index.ts
export type StreamEvent =
  | { type: 'token';           delta: string }
  | { type: 'tool_start';      name: string; args: unknown }
  | { type: 'tool_end';        name: string; result: unknown; error?: string }
  | { type: 'done';            conversationId: string; usage?: { promptTokens: number; completionTokens: number; totalTokens: number } }
  | { type: 'error';           message: string; code?: string }
```

| Event | When | Client action |
|-------|------|---------------|
| `token` | LLM emits a content chunk (one per OpenAI streaming delta) | Append `delta` to streaming reply buffer |
| `tool_start` | LLM requested a tool, **about to execute** | Show in-flight pill (pulse + "執行中…") |
| `tool_end` | Tool finished, result fed back to LLM | Pill dims to "ok" / "failed", add result detail toggle |
| `done` | Final reply committed to DB | Close stream, finalize UI state, save conversationId |
| `error` | Unrecoverable error mid-stream (LLM 5xx, DB drop, etc.) | Show error toast, close stream |

**Order rules:**
- `tool_start` ALWAYS precedes its matching `tool_end` (no orphans)
- `done` is the **last** event; the client must close the reader on it
- `error` may appear anywhere; client must close on it

## Backend — `runAgentStream` async generator

```typescript
// packages/ai/src/index.ts
import OpenAI from 'openai';

export interface AgentStreamInput {
  userId: string;
  conversationId: string;
  message: string;
}

export type StreamEvent =
  | { type: 'token'; delta: string }
  | { type: 'tool_start'; name: string; args: unknown }
  | { type: 'tool_end'; name: string; result: unknown; error?: string }
  | { type: 'done'; conversationId: string; usage?: { promptTokens: number; completionTokens: number; totalTokens: number } }
  | { type: 'error'; message: string; code?: string };

const MAX_ITERATIONS = 6;          // hard cap (Day 10: 6, was 8)
const MAX_MESSAGES = 20;            // sliding context window

export async function* runAgentStream(input: AgentStreamInput): AsyncGenerator<StreamEvent> {
  // 1. Pre-check: DB AiConfig row must exist (no env fallback — see RG-002)
  const cfg = await prisma.aiConfig.findUnique({ where: { id: 1 } });
  if (!cfg) {
    yield { type: 'error', message: 'AI Assistant is not configured', code: 'NOT_CONFIGURED' };
    return;
  }

  const client = new OpenAI({ apiKey: decryptSecret(cfg.apiKey), baseURL: cfg.endpointUrl });
  // ... build system prompt + load history ...

  let fullReply = '';

  for (let iter = 0; iter < MAX_ITERATIONS; iter++) {
    // 2. Call LLM with stream: true
    const stream = await client.chat.completions.create({
      model: cfg.modelName,
      messages,
      tools: toolDefs,
      tool_choice: 'auto',
      stream: true,
      stream_options: { include_usage: true },    // get usage in last chunk
    });

    // 3. Iterate chunks, accumulate tool_calls, emit tokens
    const accumulator = { toolCalls: [] as any[] };
    for await (const chunk of stream) {
      const delta = chunk.choices?.[0]?.delta;
      if (delta?.content) {
        fullReply += delta.content;
        yield { type: 'token', delta: delta.content };
      }
      // ... accumulate tool_calls deltas ...
    }
    // chunk.usage → save for done event

    // 4. If no tool calls → final answer, save to DB
    if (accumulator.toolCalls.length === 0) {
      const conversationId = await saveMessages(input, fullReply, usage);
      yield { type: 'done', conversationId, usage };
      return;
    }

    // 5. Execute each tool call serially, emit tool_start/tool_end
    for (const call of accumulator.toolCalls) {
      yield { type: 'tool_start', name: call.name, args: call.args };
      try {
        const result = await executeTool(call.name, call.args, ctx);
        yield { type: 'tool_end', name: call.name, result };
        messages.push({ role: 'tool', tool_call_id: call.id, content: JSON.stringify(result) });
      } catch (err) {
        yield { type: 'tool_end', name: call.name, result: null, error: String(err) };
        messages.push({ role: 'tool', tool_call_id: call.id, content: JSON.stringify({ ok: false, error: String(err) }) });
      }
    }
  }

  yield { type: 'error', message: 'Max iterations reached', code: 'MAX_ITER' };
}
```

## Backend — Elysia route that wraps the async generator

```typescript
// apps/api/src/routes/chat.ts
import { Elysia } from 'elysia';
import { runAgentStream, AiNotConfiguredError } from '@crm/ai';

const sseFrame = (e: StreamEvent) => `data: ${JSON.stringify(e)}\n\n`;
const encoder = new TextEncoder();

export const chatRoutes = new Elysia()
  .post('/chat/send', async ({ body, set, request }) => {
    // 1. Auth (Bearer JWT)
    const token = request.headers.get('authorization')?.replace('Bearer ', '');
    const user = await verifyToken(token);
    if (!user) { set.status = 401; return { error: 'Unauthorized' }; }

    // 2. Pre-check AiConfig (cheap DB read; defence-in-depth below)
    const cfg = await prisma.aiConfig.findUnique({ where: { id: 1 }, select: { id: true } });
    if (!cfg) {
      set.status = 503;
      return { error: 'AI Assistant is not configured', message: 'Ask an admin to set up the AI Assistant at /admin/ai-config.' };
    }

    // 3. Return streaming Response
    set.headers['Content-Type'] = 'text/event-stream; charset=utf-8';
    set.headers['Cache-Control'] = 'no-cache, no-transform';
    set.headers['Connection'] = 'keep-alive';
    set.headers['X-Accel-Buffering'] = 'no';     // CRITICAL for nginx

    const stream = new ReadableStream({
      async start(controller) {
        try {
          for await (const event of runAgentStream({
            userId: user.id,
            conversationId: body.conversationId ?? crypto.randomUUID(),
            message: body.message,
          })) {
            controller.enqueue(encoder.encode(sseFrame(event)));
          }
        } catch (err) {
          if (err instanceof AiNotConfiguredError) {
            controller.enqueue(encoder.encode(sseFrame({ type: 'error', message: 'AI Assistant is not configured', code: 'NOT_CONFIGURED' })));
          } else {
            controller.enqueue(encoder.encode(sseFrame({ type: 'error', message: String(err) })));
          }
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, { status: 200 });
  });
```

## Frontend — fetch + ReadableStream consumer

The frontend uses `fetch` (NOT `EventSource`) because we need to send
a `POST` with a JSON body. `EventSource` only supports GET.

```typescript
// apps/web/src/lib/api.ts
export interface StreamCallbacks {
  onToken: (delta: string) => void;
  onToolStart: (name: string, args: unknown) => void;
  onToolEnd: (name: string, result: unknown, error?: string) => void;
  onDone: (conversationId: string, usage?: { promptTokens: number; completionTokens: number; totalTokens: number }) => void;
  onError: (message: string, code?: string) => void;
}

export async function chatSend(
  message: string,
  conversationId: string | undefined,
  cb: StreamCallbacks,
  signal?: AbortSignal,
): Promise<void> {
  const res = await fetch(`${API_BASE}/chat/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${getToken()}` },
    body: JSON.stringify({ message, conversationId }),
    signal,                      // allows user-initiated cancel
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    cb.onError(body.error ?? `HTTP ${res.status}`, body.code);
    return;
  }

  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    // Split on \n\n (SSE frame boundary)
    let frameEnd: number;
    while ((frameEnd = buffer.indexOf('\n\n')) !== -1) {
      const frame = buffer.slice(0, frameEnd);
      buffer = buffer.slice(frameEnd + 2);
      const dataLine = frame.split('\n').find(l => l.startsWith('data: '));
      if (!dataLine) continue;
      const json = dataLine.slice(6);
      try {
        const event = JSON.parse(json) as StreamEvent;
        switch (event.type) {
          case 'token':      cb.onToken(event.delta); break;
          case 'tool_start': cb.onToolStart(event.name, event.args); break;
          case 'tool_end':   cb.onToolEnd(event.name, event.result, event.error); break;
          case 'done':       cb.onDone(event.conversationId, event.usage); break;
          case 'error':      cb.onError(event.message, event.code); break;
        }
      } catch (e) {
        console.error('Bad SSE frame', e);
      }
    }
  }
}
```

## React usage — `streamingReply` + `inFlightTools` state

```typescript
// apps/web/src/pages/ai-chat.tsx
const [streamingReply, setStreamingReply] = useState<string>('');
const [inFlightTools, setInFlightTools] = useState<Array<{ name: string; status: 'running' | 'ok' | 'failed'; result?: unknown }>>([]);

async function sendMessage(text: string) {
  setStreamingReply('');
  setInFlightTools([]);

  await chatSend(text, currentConversationId, {
    onToken: (delta) => setStreamingReply(prev => prev + delta),
    onToolStart: (name) => setInFlightTools(prev => [...prev, { name, status: 'running' }]),
    onToolEnd: (name, result, error) => setInFlightTools(prev =>
      prev.map(t => t.name === name ? { ...t, status: error ? 'failed' : 'ok', result } : t)
    ),
    onDone: (conversationId) => {
      queryClient.invalidateQueries(['conversations']);
      queryClient.invalidateQueries(['conversation', conversationId]);
    },
    onError: (message) => toast.error(message),
  });
}
```

## Verification — curl

```bash
TOKEN=$(curl -s -X POST http://localhost/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@crm.local","password":"admin123"}' | jq -r .token)

curl -i -N -X POST http://localhost/api/chat/send \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d '{"message":"count 1 to 3"}'
# Expect:
# HTTP/1.1 200
# content-type: text/event-stream; charset=utf-8
# cache-control: no-cache, no-transform
# x-accel-buffering: no
# transfer-encoding: chunked
#
# data: {"type":"token","delta":"1"}
#
# data: {"type":"token","delta":"\n"}
# ... etc
# data: {"type":"done","conversationId":"...","usage":{...}}
```

## Common pitfalls

1. **Forgetting `X-Accel-Buffering: no`** — nginx buffers the whole
   response, user sees one big reply after 15 sec. Symptom: smoke
   works with `curl -N` (no nginx) but not via `/api` (through nginx).
2. **Using `EventSource` instead of `fetch`** — EventSource only
   supports GET, no body. Need POST with JSON.
3. **Forgetting `signal` on fetch** — user clicks "stop" but stream
   keeps running server-side, wasting tokens. Always wire AbortController.
4. **`prisma.aiConfig` not on client** — `prisma generate` not run
   after schema change. TypeScript errors at build, runtime would
   crash. Run `prisma generate` AND `docker compose build api` (the
   generated client is baked into the image).
5. **Pushing tool messages as `role: 'tool'` in DB** — fine for OpenAI
   API, but make sure `messages.push` uses the right shape:
   `{ role: 'tool', tool_call_id: call.id, content: JSON.stringify(result) }`.
6. **Token accumulation in `fullReply` MUST match what was yielded** —
   if you lose characters, the DB-saved final message differs from
   what the user saw. Test with a counting prompt like
   `"count 1 to 100, no other text"`.
