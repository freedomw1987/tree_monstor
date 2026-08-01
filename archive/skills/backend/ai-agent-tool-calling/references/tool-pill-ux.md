# Tool Call UX — Inline Pill, NEVER a Message Bubble — 2026-06-09 David feedback

## Why this exists (David's feedback)

> 「AI 助手有這個情況,應該是調用工具時不用有 message bubble」 — David, Day 10.1

The first cut of the AI chat (Day 10) rendered tool invocations the
same way as assistant messages: wrapped in a `flex justify-start`
container with `max-w-[80%]` and a bot icon. The result was a vertical
column of grey bubbles that **looked like the agent was sending
multiple separate messages**, when in fact those were just metadata
about what the agent was doing in service of producing one reply.

This is the ChatGPT / Claude standard: tool calls are **inline
metadata** adjacent to the reply, not messages in their own right.

## The rule (write it in PR review comments)

> **Tool calls MUST be rendered as small inline pills adjacent to the
> assistant's reply. They MUST NEVER be rendered as standalone message
> bubbles.**

A pill is:
- small text (e.g. `text-xs` / `text-sm`)
- no max-width container (it sizes to its content)
- no bot icon
- sits in the same column as the bot's reply, **above** the reply
  bubble (so it reads as "context for what's coming")
- has a `▸` caret to expand the args + result JSON
- has a status indicator: pulse while running, muted when ok, red when failed

A bubble is:
- `flex justify-start` + `max-w-[80%]` + bg-muted + bot icon + `rounded-2xl`
- **FORBIDDEN** for `role: 'tool'`

## React component — `ToolPill`

```tsx
// apps/web/src/components/chat/ToolPill.tsx
import { Wrench, ChevronRight, ChevronDown, Check, AlertCircle, Loader2 } from 'lucide-react';
import { useState } from 'react';

export interface ToolCall {
  name: string;
  args?: unknown;
  result?: unknown;
  error?: string;
  status: 'running' | 'ok' | 'failed';
}

export function ToolPill({ call }: { call: ToolCall }) {
  const [expanded, setExpanded] = useState(false);

  const StatusIcon = {
    running: Loader2,
    ok: Check,
    failed: AlertCircle,
  }[call.status];

  const statusColor = {
    running: 'text-blue-600 border-blue-300 animate-pulse',
    ok: 'text-muted-foreground border-muted',
    failed: 'text-red-600 border-red-300',
  }[call.status];

  return (
    // ⚠️ NO flex/max-w/rounded-2xl/bot-icon wrapper — those are for real messages
    <div className="inline-block">
      <button
        type="button"
        onClick={() => setExpanded(v => !v)}
        className={`
          inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1
          text-xs font-mono ${statusColor}
          hover:bg-muted/50 transition-colors
        `}
        aria-expanded={expanded}
        aria-label={`Tool call ${call.name}, status ${call.status}`}
      >
        <Wrench className="h-3 w-3" />
        <span>{call.name}</span>
        <StatusIcon className={`h-3 w-3 ${call.status === 'running' ? 'animate-spin' : ''}`} />
        {expanded ? <ChevronDown className="h-3 w-3" /> : <ChevronRight className="h-3 w-3" />}
      </button>

      {expanded && (
        <div className="mt-1 ml-3 p-2 rounded border bg-muted/30 text-xs font-mono max-w-xl">
          {call.args !== undefined && (
            <div className="mb-1">
              <div className="text-muted-foreground mb-0.5">args:</div>
              <pre className="whitespace-pre-wrap break-all">{JSON.stringify(call.args, null, 2)}</pre>
            </div>
          )}
          {call.result !== undefined && (
            <div className="mb-1">
              <div className="text-muted-foreground mb-0.5">result:</div>
              <pre className="whitespace-pre-wrap break-all">{JSON.stringify(call.result, null, 2)}</pre>
            </div>
          )}
          {call.error && (
            <div className="text-red-600">
              <div className="text-muted-foreground mb-0.5">error:</div>
              <pre className="whitespace-pre-wrap break-all">{call.error}</pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

## Where the pills live — `StreamingBotMessage`

```tsx
// apps/web/src/components/chat/StreamingBotMessage.tsx
import { Bot } from 'lucide-react';
import { ToolPill, type ToolCall } from './ToolPill';

interface Props {
  inFlightTools: ToolCall[];
  streamingContent: string;
  isStreaming: boolean;
  persistedReply?: string;            // for re-render after done
  persistedTools?: ToolCall[];         // tools from DB on reload
}

export function StreamingBotMessage({
  inFlightTools, streamingContent, isStreaming, persistedReply, persistedTools,
}: Props) {
  const reply = persistedReply ?? streamingContent;
  const tools = persistedTools ?? inFlightTools;

  return (
    <div className="flex flex-col gap-1.5 max-w-[80%]">
      {/* Header: bot icon + name — ONE per group, NOT per message */}
      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <Bot className="h-3.5 w-3.5" />
        <span>CRM AI Assistant</span>
      </div>

      {/* Tool pills — INLINE, above the reply */}
      {tools.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {tools.map((t, i) => <ToolPill key={`${t.name}-${i}`} call={t} />)}
        </div>
      )}

      {/* Reply bubble — single container for the WHOLE reply */}
      <div className="rounded-2xl bg-muted px-4 py-2.5 text-sm whitespace-pre-wrap">
        {reply}
        {isStreaming && <span className="inline-block w-1.5 h-3.5 ml-0.5 bg-current animate-pulse" />}
      </div>
    </div>
  );
}
```

**Key insight**: even when there are 3 tool calls, there's **only ONE
reply bubble**. The pills sit *above* it, indicating "look, I needed
to do these 3 things to answer you". The user reads top-to-bottom:
"AI did 3 things → here's the answer".

## Anti-pattern — what NOT to ship

```tsx
// ❌ WRONG — tool calls as separate message bubbles
{messages.map(m => (
  <MessageBubble key={m.id} message={m}>
    {/* This treats role: 'tool' as a message */}
  </MessageBubble>
))}

// ❌ WRONG — wrapping pills in max-w-[80%] container
<div className="flex justify-start">
  <div className="max-w-[80%] flex flex-col gap-1.5">
    {tools.map(t => <ToolPill key={t.name} call={t} />)}
  </div>
</div>
```

Both make pills look like messages. Don't do this.

## Why this matters — UX intent

When the user asks "how many customers do I have?", the **answer is
the count**. The tool call (search_companies) is metadata. Showing
it as a separate message:

1. **Inflates the message count** — user thinks 3 things happened
2. **Breaks the "1 question → 1 answer" mental model**
3. **Wastes vertical space** — 3 grey bubbles that the user has to
   scroll past
4. **Hides the actual reply** — the user has to find which bubble is
   "the answer" vs which is "I did X first"

The pill format fixes all four.

## Persisted tool calls in `MessageBubble` (for reload)

When the user reloads the page or comes back later, the chat fetches
saved messages from the DB. `MessageBubble` for `role: 'tool'`
should still render as a pill, not a bubble.

```tsx
// apps/web/src/components/chat/MessageBubble.tsx
export function MessageBubble({ message }: { message: ChatMessage }) {
  // Tool messages get the SAME pill treatment, not a bubble
  if (message.role === 'tool') {
    const call = JSON.parse(message.content);  // { name, args, result }
    return <ToolPill call={{ ...call, status: 'ok' }} />;
  }

  // User + assistant use the regular bubble layout
  // ...
}
```

## Verification — visual + DOM

1. **DOM check**: in browser devtools, a tool pill element should
   have `class="inline-block"` and NOT be inside any
   `max-w-[80%]` or `rounded-2xl` wrapper.

2. **Screenshots**: see `docs/_html/crm-system-ai-chat.html` for the
   crm-system reference implementation. Pills sit flush-left above
   the bot bubble, sized to their text content.

3. **PRD US-C1 / US-C7 acceptance criteria** should explicitly
   require "inline pill, not a bubble" as a bullet, so a regression
   test can grep the rendered HTML for `class="inline-block"` and
   fail on `class="max-w-[80%] flex justify-start"`.
