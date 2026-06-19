# System prompt snippet — "Markdown and charts" section

Drop this into your LLM's system prompt (`packages/ai/src/prompts.ts`
or equivalent). Adjust the exact list of valid `type` values to
match what your `ChartBlock` supports.

## The snippet

```markdown
# Markdown and charts

Your replies are rendered as Markdown, so you can use:
- **Bold**, *italic*, \`inline code\`
- Numbered and bulleted lists
- GFM tables (\`| col | col |\` with a separator row)
- Fenced code blocks (\`\`\`language ... \`\`\`) for raw data
- Headings (\`## Section\`) for long answers

For numeric comparisons or trends (top customers, revenue over time,
deal pipeline distribution), always emit a chart in addition to any
text. The chart syntax is a fenced code block with language \`chart\`:

\`\`\`chart
{
  "type": "bar",
  "data": {
    "labels": ["Jan", "Feb", "Mar", "Apr"],
    "datasets": [
      { "label": "Revenue (HKD)", "data": [12000, 18500, 14200, 22000] }
    ]
  }
}
\`\`\`

- \`type\` must be one of: \`bar\`, \`line\`, \`pie\`, \`doughnut\`.
- \`data.labels\` is an array of strings (categories / time buckets).
- \`data.datasets\` is an array; each dataset needs a \`label\` and a
  \`data\` array of numbers (same length as \`labels\`).
- For \`pie\` / \`doughnut\` only one dataset is needed.
- The chart renders inside a small card, so keep datasets ≤ 2 unless
  comparing more.
- Always include a one-line caption above the chart in plain text
  (e.g. "Top 5 customers by revenue").

Do NOT include any prose inside the fence — only valid JSON.
```

## Why each rule is there

| Rule | Why |
|------|-----|
| "Always emit a chart in addition to any text" | Without this, the LLM often just writes prose. The user explicitly wanted charts for data answers — make it the default. |
| "`type` must be one of: bar, line, pie, doughnut" | The `ChartBlock` switches on these four. If the LLM emits `radar` or `scatter`, the renderer falls back to "Unsupported chart type". Keeping the list closed = predictable errors. |
| "Same length as `labels`" | Chart.js silently drops mismatched entries. Better to have the LLM get it right than to render an off-by-one chart. |
| "Keep datasets ≤ 2" | The default palette cycles every 8 colours. 3+ datasets start looking the same. If the user asks for "compare X, Y, Z", suggest narrowing the comparison. |
| "Caption above the chart" | The caption provides context the chart can't convey (units, time range, source). Putting it inside the fence would break the JSON parse. |
| "Do NOT include any prose inside the fence" | The renderer's first step is `JSON.parse(json)`. Any prose → parse error → user sees a "Chart JSON parse error" card. |

## Edge cases the LLM gets wrong

- **Trailing commas**: Some LLMs emit `["A", "B",]` (legal in JS, not
  in strict JSON). The `ChartBlock` will throw a parse error and
  show the raw JSON. If you see this in practice, add a JSON
  pre-process step that strips trailing commas before parsing.
- **Currency symbols in `data`**: `data: ["$12,500"]` is invalid (data
  must be `number[]`). Tell the LLM: "Numbers in `data` must be raw
  numerics; format with currency in the `label` or caption, not in
  the data array".
- **Empty datasets**: `datasets: []` crashes Chart.js. Add a
  pre-render check in `ChartBlock`: if `datasets.length === 0`,
  render an "Empty chart" placeholder.
- **Single label**: `labels: ["A"]` with `type: "line"` renders as a
  dot — not wrong, just useless. Tell the LLM: "Line charts need
  ≥ 2 labels to be meaningful; use bar instead for single points".

## Testing the system prompt

There's no easy way to unit-test the LLM's chart-emitting behaviour
without actually running the model. Two pragmatic checks:

1. **Smoke test in the chat UI**: after a deploy, ask the agent
   "top 5 customers by revenue" and confirm a bar chart renders.
2. **Capture golden outputs**: in your eval suite, log the model's
   response to a fixed set of 3-5 numeric questions. Manually
   inspect the first batch after a model upgrade or system-prompt
   change to catch syntax drift.
