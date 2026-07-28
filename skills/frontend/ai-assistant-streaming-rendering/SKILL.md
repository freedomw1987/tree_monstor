---
name: ai-assistant-streaming-rendering
description: When building a chat / AI assistant UI that streams tokens from an LLM, render the reply with full Markdown + chart.js + data-fence support, and treat the agent's "I invoked a tool" marker rows as metadata (not empty bubbles). Class-level skill — covers any "AI chat panel" UI in any framework (React, Vue, Svelte, vanilla). Also load when debugging "empty bubble after tool call" in any AI chat UI, or when David reports "the chart didn't render" / "the markdown looks raw" / "the agent's reply is missing".
license: MIT
applicability: generic-pattern
---

Last-verified: 2026-07-28
# AI Assistant Streaming + Rich Rendering

## What this skill covers

A chat panel where the **user** types a question, the **LLM** streams a
reply, and the **agent** may call tools mid-stream. The reply needs to
render with:

- **Markdown** (headings, lists, GFM tables, code blocks, links)
- **Charts** (bar / line / pie / doughnut, from a JSON spec the LLM emits)
- **Streaming-friendly** (partial tokens, partial fences, partial charts)
- **Tool-call marker rows** that DO NOT render as empty bubbles

If you only need plain text + Markdown, this is overkill — use
`react-markdown` directly. If you need charts, follow the fence pattern
below.

## Trigger conditions

Load this skill (don't guess) when:

- David says "AI 助手有 X 改動" / "chat panel bug" / "agent reply wrong"
- A user report mentions "empty bubble", "tool call shows nothing",
  "the chart didn't render", "the agent's reply has no formatting",
  "the markdown is raw text", "the agent says the tool name but no
  result"
- You see a `ConversationMessage` table with `toolName` + `role: 'assistant'`
  rows (the LLM history marker pattern)
- The bug is in `apps/.../pages/ai-chat.tsx` or equivalent chat page
- A user asks to add charts to the AI assistant's reply

## When to use

- Building or refactoring an AI chat panel (any framework)
- The LLM can call tools (function calling) and you persist those
  invocations as ConversationMessage rows
- The user wants data-dense answers (top customers, revenue trends,
  pipeline distribution, etc.) instead of prose

## Don't use

- The agent only ever emits plain text (no tools, no data tables) →
  `react-markdown` alone is enough
- You're rendering email-style content where the user writes the
  Markdown (security risk — see "User content" below)
- The chart data is interactive (drill-down, hover tooltips with
  clickable links) — use Recharts/Plotly instead, not Chart.js

## The four contracts (front-end ↔ back-end)

The whole pattern rests on **four stable contracts** between the LLM,
the backend, the streaming protocol, and the frontend renderer. If
any of these drift, you get empty bubbles / broken charts / leaked
HTML.

### Contract 1: tool-marker row content (the empty-bubble fix)

When the agent invokes a tool, the backend persists **two** rows:
one "marker" and one "result":

```ts
// Marker: "I invoked this tool" — metadata, not a bubble
await prisma.conversationMessage.create({
  data: { role: 'assistant', content: '🔧 ${toolName}', toolName, toolArgs }
})
// Result: the tool's actual output
await prisma.conversationMessage.create({
  data: { role: 'tool', content: JSON.stringify(result), toolName, toolResult: result }
})
```

The marker row's `content` MUST be a **sentinel string** (e.g.
`🔧 {toolName}`). The frontend detects it and renders as inline
metadata pill, not a bubble.

**Why sentinel, not `content: ''`**: with empty content, the frontend
can't tell "this is a tool marker" from "this is a real reply that
happens to be empty". The frontend will fall through to the generic
bubble branch and render a styled box with nothing in it. The
sentinel pattern + an `isToolMarker()` predicate solves this in
one place.

**Sentinel family reservation**: anything starting with `🔧` is a
marker. If you later need `🔧 foo (failed)`, that's fine — anything
matching `^🔧` works. Don't use `🔧` for anything else.

**Backward compat for legacy rows**: if you ship this fix to a DB
that already has `content: ''` rows from before, your `isToolMarker()`
predicate MUST also accept empty content (for any row with a
`toolName` set). See the `isToolMarker` reference snippet in
`references/is-tool-marker-react.md`.

### Contract 2: LLM history reconstruction (backend → LLM API)

When you rebuild the LLM request from persisted messages, the marker
row's `content` MUST be coerced to `null` before pushing to the
chat-completions API. OpenAI spec:

> An assistant message that carries `tool_calls` MUST have
> `content: null` (not empty string, not sentinel, not anything else).

```ts
if (m.role === 'assistant' && m.toolName) {
  return {
    role: 'assistant' as const,
    content: null,  // ALWAYS null, even if we persisted a sentinel
    tool_calls: [{
      id: m.toolName,
      type: 'function' as const,
      function: { name: m.toolName, arguments: JSON.stringify(m.toolArgs ?? {}) }
    }]
  }
}
```

If you skip this, the next turn fails with a 400 from OpenAI
(`Invalid value: 'string'. Expected one of null`).

### Contract 3: chart fence syntax (LLM → frontend)

The LLM is taught (in the system prompt) to emit a chart as a fenced
code block with language `chart`:

````
Here are the top 5 customers by revenue:

```chart
{
  "type": "bar",
  "data": {
    "labels": ["A", "B", "C", "D", "E"],
    "datasets": [
      { "label": "Revenue (HKD)", "data": [125000, 98000, 75000, 62000, 51000] }
    ]
  }
}
```
````

Contract rules:
- `type` ∈ {`bar`, `line`, `pie`, `doughnut`}
- `data.labels` is `string[]`
- `data.datasets` is `Array<{label, data: number[]}>`
- JSON on a single line OR pretty-printed (fence matches both)
- The LLM puts a one-line caption in prose ABOVE the fence
- NEVER put prose inside the fence — the renderer treats fence
  content as a JSON literal

### Contract 4: streaming safety

The streaming reply appends tokens one at a time. A ` ```chart `
fence can arrive split across 5+ tokens. The streaming renderer
MUST hold back Markdown rendering when a fence is open:

```ts
export function StreamingMarkdown({ source }: { source: string }) {
  const lastTriple = source.lastIndexOf('```');
  if (lastTriple !== -1) {
    const after = source.slice(lastTriple + 3);
    if (!after.includes('```')) {
      // Unclosed fence — don't try to render Markdown, just show the text
      return <>{source}<span className="cursor-blink" /></>;
    }
  }
  return <><MarkdownContent source={source} /><span className="cursor-blink" /></>;
}
```

The cursor blink is appended AFTER the rendered Markdown so the
"still typing" affordance is always visible. Re-render on every
token — the cost is bounded (Markdown is incremental and small).

## The implementation pattern (React + Vite + react-markdown + chart.js)

### Step 1: install deps

```bash
cd apps/web
bun add react-markdown remark-gfm chart.js react-chartjs-2
```

**Bundle cost warning**: `react-markdown` + `remark-gfm` + `chart.js` +
`react-chartjs-2` adds ~150KB gzipped. For a CRM / internal-tool
audience on a fast network this is fine. If you're targeting mobile
users on slow networks, consider:

- Lazy-load `ChartBlock` (e.g. `React.lazy(() => import('./ChartBlock'))`)
  so the Chart.js controllers only load when an actual chart fence
  is encountered.
- Skip `chart.js` entirely and use SVG-only chart libraries
  (`@visx/visx`, `recharts` with the SVG backend) — ~40KB lighter.
- Or use the LLM tool-call API to stream structured chart data
  instead of inline ` ```chart ` fences — moves the chart library
  to a separate lazy chunk.

For an internal CRM the default (all-in-bundle) is the right
trade-off. For a consumer product, lazy-load.

### Step 2: extract `isToolMarker` into a testable module

`apps/web/src/lib/chat-helpers.ts`:

```ts
import type { ChatMessage } from './api';

export function isToolMarker(message: ChatMessage): boolean {
  if (message.role !== 'assistant') return false;
  if (!message.toolName) return false;
  if (!message.content) return true;  // legacy empty-content rows
  return /^🔧/.test(message.content);
}
```

### Step 3: create `MarkdownContent` + `ChartBlock`

`apps/web/src/components/MarkdownContent.tsx` and
`apps/web/src/components/ChartBlock.tsx`. See the full source
in `references/chat-renderer-source.md` (<project> copy from
2026-06-08, MIT-licensed and <project>-internal).

The split-on-fences pattern (pre-process the source string) is
chosen over `react-markdown`'s `components` map because we want
the FENCE CONTENT to drive what we render, not the code-block
node itself.

### Step 4: update the chat page

In your `MessageBubble` component, render order is:
1. `if (isTool) || isToolMarker(message)` → metadata pill (no bubble)
2. `if (isUser)` → plain text in primary-coloured bubble
3. otherwise → `<MarkdownContent source={message.content} />`
   in muted-coloured bubble

Remove `whitespace-pre-wrap` from the bubble class. Markdown
handles line breaks via `prose` styling.

In your `StreamingBotMessage`, replace the raw-text render with
`<StreamingMarkdown source={reply} />` so streaming replies get
the same treatment.

### Step 5: teach the LLM the chart syntax

In your system prompt (e.g. `packages/ai/src/prompts.ts`), add
a "Markdown and charts" section that includes:
- The full fence syntax with a worked example
- A list of valid `type` values
- The rule that prose goes OUTSIDE the fence
- A note that the chart renders inside a small card (keep
  datasets ≤ 2 unless comparing more)

Without this, the LLM will invent its own chart syntax and the
fence detection will silently fall back to "render as code block".

### Step 6: write the regression test

`apps/web/src/lib/__tests__/chat-helpers.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { isToolMarker } from '../chat-helpers';
import type { ChatMessage } from '../api';

const mk = (overrides: Partial<ChatMessage>): ChatMessage => ({
  id: 'm1', role: 'assistant', content: '', createdAt: '...',
  ...overrides
} as ChatMessage);

describe('isToolMarker', () => {
  it('detects the new sentinel content', () => {
    expect(isToolMarker(mk({ toolName: 'foo', content: '🔧 foo' }))).toBe(true);
  });
  it('detects legacy empty-content rows', () => {
    expect(isToolMarker(mk({ toolName: 'foo', content: '' }))).toBe(true);
  });
  it('does not match normal assistant replies', () => {
    expect(isToolMarker(mk({ toolName: null, content: 'Here are the top 5...' }))).toBe(false);
  });
  it('does not match user messages', () => {
    expect(isToolMarker(mk({ role: 'user', toolName: 'foo', content: '🔧 foo' }))).toBe(false);
  });
});
```

## Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| `bun test` (not `bun test --env=jsdom`) for a test that touches `localStorage` | 6 tests fail with `Can't find variable: localStorage` | Either use `vitest run` (the project's test runner), or add `--env=jsdom`. The `bun test` binary doesn't auto-load jsdom. |
| `react-markdown` renders HTML in `user`-authored content | XSS | User-authored messages: render as plain text. Only `assistant` messages go through Markdown. |
| Chart.js v4 doesn't auto-register anything | `controller is not registered` console error | Call `Chart.register(...)` once at module load (see `ChartBlock.tsx`). |
| `react-chartjs-2` doesn't expose `<Chart type={...}>` | The component you'd want doesn't exist | Switch on `type` and pick `<Bar>` / `<Line>` / `<Pie>` / `<Doughnut>` (see `ChartBlock.tsx`). |
| LLM writes ` ```chartjs ` instead of ` ```chart ` | Chart falls back to a normal code block | Either update the regex to `/```(chart\|chartjs)/`, or re-teach the LLM via system prompt. |
| Marker row's `content: '🔧 foo'` leaks into the LLM request on the next turn | OpenAI 400: "Invalid value: 'string'. Expected one of null" | Coerce to `null` in the history reconstructor (Contract 2). |
| Partial ` ```chart ` fence during streaming renders as broken code block | User sees `{"type":"bar",` for a second before the closing ``` | Use `StreamingMarkdown` (Contract 4) — hold back when a fence is open. |
| Chart JSON inside fence has trailing comma | React-chartjs-2 crashes silently with "Cannot read properties of undefined" | Wrap the JSON parse in a try/catch and render a "Chart JSON parse error" card with the raw JSON (the user can still see the numbers). |
| `unstable-override` import in `ChartBlock.tsx` accidentally pulls in all of chart.js | Bundle grows by ~300KB | Only register the controllers/elements you use. See `references/chat-renderer-source.md` for the minimal registration. |
| Dev forgets to rebuild the container after adding deps | Browser shows "Cannot find module 'react-markdown'" | `docker compose up -d --build web` (or whatever your deploy step is) |

## Verification

After implementing, run:

```bash
# 1. typecheck (must be 0 new errors)
bun run --filter '@crm/web' typecheck

# 2. unit test the isToolMarker contract
bun test src/lib/__tests__/chat-helpers.test.ts
# expect: 7 pass, 0 fail (or whatever count your predicates need)

# 3. build the frontend (catches missing import / wrong import path)
cd apps/web && bun run build

# 4. smoke test in the browser:
#    a. ask the agent a question that triggers a tool call
#    b. confirm: no empty bubble appears
#    c. ask the agent "top 5 customers by revenue"
#    d. confirm: a bar chart renders with the numbers
```

## After deploy: ship verification loop (David confirmation)

Once the code is committed + pushed and containers are rebuilt, the
fix isn't "done" until David confirms it works on the running
service. This loop catches a class of bugs where local typecheck +
tests pass but the running container is still serving the OLD image,
or the user sees a different bug in the running UI.

**1. Capture baseline SHAs before rebuild** (so you can confirm
the new image actually replaced the old one):

```bash
docker inspect --format '{{.Image}}' crm-web > /tmp/web-sha-before.txt
docker inspect --format '{{.Image}}' crm-api > /tmp/api-sha-before.txt
```

**2. David rebuilds + restarts the containers**:

```bash
cd ~/www/<project>
docker compose up -d --build web api
docker compose ps    # confirm new SHA + healthy
```

**3. David hard-reloads the browser** (Cmd-Shift-R). Vite / nginx
may serve the old JS bundle from cache even after a fresh
container; the hard reload guarantees the new `react-markdown` /
`chart.js` code is actually loaded.

**4. David smoke-tests 3 prompts** covering: a tool call
(no-empty-bubble), a chart (bar or line), and a non-analytics
question (markdown without a chart).

**5. Verify the deploy actually shipped** (Revert detection, per
SOUL.md 紅線 23+): after David says "OK", confirm with your own
eyes that the remote is on the new commit:

```bash
git log --oneline origin/main..HEAD
# must be empty (everything is pushed)
git status
# must say "working tree clean"
docker inspect --format '{{.Image}}' crm-web
# must differ from /tmp/web-sha-before.txt
```

**6. Write the retro doc** following the project's existing
template. For <project>, this is
`docs/retros/YYYY-MM-DD-<feature>.md` with sections: TL;DR table,
root cause recap, what changed, design rationale, lessons, out of
scope, verification artefacts, files touched. Pin the retro
commit in a follow-up so the doc travels with the code (e.g.
`docs(retro): <feature> ship verification + design rationale`).

This loop is what catches "I shipped a fix but my headless check
missed it because the user reverted / the image was old / the
browser was caching".

## Support files

- `references/chat-renderer-source.md` — full source of
  `MarkdownContent.tsx` and `ChartBlock.tsx` (<project> 2026-06-08).
  Copy and adapt to your project's component library.
- `references/is-tool-marker-react.md` — `isToolMarker` predicate
  with the 7 unit tests that pin the contract.
- `references/system-prompt-snippet.md` — "Markdown and charts"
  section to drop into your LLM's system prompt.

## When the pattern doesn't fit

- **You're using Tailwind v4 + `@tailwindcss/typography`**: the
  `prose` classes work out of the box. If you see `[&_p]:my-1.5`
  style overrides not applying, see the
  `skills/frontend/tailwindcss-v4-plugin-typography/SKILL.md` skill.
- **Your chart data is hierarchical / drill-down**: use Recharts
  or Plotly instead of Chart.js. Chart.js v4 doesn't have built-in
  support for nested data.
- **You need to embed images, videos, or interactive components
  in the reply**: extend `react-markdown`'s `components` map to
  handle custom nodes. The fence-splitting pattern is only for
  "code block content drives what we render" — for inline custom
  nodes, use the `components` API.
- **You need server-side rendering of the chart (for OG images
  / PDF export)**: render the chart on the backend with
  `chartjs-node-canvas` or convert it to a static SVG via
  `chartjs-svg`.
