# `isToolMarker` predicate — the empty-bubble fix

## What it does

Takes a `ChatMessage` and returns `true` if the row should be
treated as **agent metadata** (a "I invoked this tool" marker) and
NOT rendered as an assistant bubble.

## Why it lives in a separate file

`ai-chat.tsx` is 480+ lines of React. Testing the predicate in
isolation is much faster than spinning up the whole tree with
`@testing-library/react`. Extract it once, test it once, import
it from the page.

## The predicate (`apps/web/src/lib/chat-helpers.ts`)

```ts
import type { ChatMessage } from './api';

/**
 * A persisted message is a "tool marker" if it represents the
 * agent's "I'm about to invoke this tool" record rather than a
 * real reply. The backend writes:
 *
 *   role: 'assistant', content: '🔧 {toolName}', toolName: 'foo'
 *
 * The frontend must not render this row as a bubble.
 *
 * Sentinel expansion: we accept any content that starts with 🔧,
 * which gives us room to add e.g. `🔧 foo (failed)` later without
 * breaking the contract. Empty content (legacy persisted rows
 * from before 2026-06-08) is also accepted so old conversations
 * render correctly after the deploy.
 */
export function isToolMarker(message: ChatMessage): boolean {
  if (message.role !== 'assistant') return false;
  if (!message.toolName) return false;
  if (!message.content) return true;
  return /^🔧/.test(message.content);
}
```

## The 7 unit tests (`apps/web/src/lib/__tests__/chat-helpers.test.ts`)

```ts
import { describe, it, expect } from 'vitest';
import { isToolMarker } from '../chat-helpers';
import type { ChatMessage } from '../api';

const mk = (overrides: Partial<ChatMessage>): ChatMessage => ({
  id: 'm1', role: 'assistant', content: '', createdAt: '2026-06-08T00:00:00Z',
  ...overrides,
} as ChatMessage);

describe('isToolMarker (RG-CHAT-001)', () => {
  it('returns true for the new sentinel content "🔧 foo"', () => {
    expect(isToolMarker(mk({ toolName: 'foo', content: '🔧 foo' }))).toBe(true);
  });

  it('returns true for "🔧 foo (failed)" (future-proofing)', () => {
    expect(isToolMarker(mk({ toolName: 'foo', content: '🔧 foo (failed)' }))).toBe(true);
  });

  it('returns true for legacy rows with empty content + toolName', () => {
    // Pre-fix DB rows must still be detected.
    expect(isToolMarker(mk({ toolName: 'foo', content: '' }))).toBe(true);
  });

  it('returns false for a normal assistant reply with prose', () => {
    expect(isToolMarker(mk({ toolName: null, content: 'Here are the top 5 customers...' }))).toBe(false);
  });

  it('returns false for an assistant message with toolName but real text', () => {
    // Defensive: future bug where the backend writes both toolName AND
    // real content. We want the prose to win.
    expect(isToolMarker(mk({ toolName: 'foo', content: 'I found 3 matches' }))).toBe(false);
  });

  it('returns false for a user message even if toolName is somehow set', () => {
    expect(isToolMarker(mk({ role: 'user', toolName: 'foo', content: '🔧 foo' }))).toBe(false);
  });

  it('returns false for a tool-result message (role: tool)', () => {
    expect(isToolMarker(mk({ role: 'tool', toolName: 'foo', content: '{"ok":true}' }))).toBe(false);
  });
});
```

## How to run

```bash
cd apps/web
bun test src/lib/__tests__/chat-helpers.test.ts
# expect: 7 pass, 0 fail
```

If `bun test` complains about `localStorage` (in a *different* test
file in the same suite), use `vitest run` instead — it loads the
jsdom env from your `vitest.config.ts`:

```bash
bunx vitest run src/lib/__tests__/chat-helpers.test.ts
```
