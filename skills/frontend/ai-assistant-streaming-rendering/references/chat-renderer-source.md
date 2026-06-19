# MarkdownContent + ChartBlock full source

Reference implementation from **crm-system** (2026-06-08, RG-CHAT-001).
The crm-system code is MIT-licensed and crm-system-internal — copy the
*patterns* and adapt to your project; don't just paste verbatim.

## Why split fences first, then render with react-markdown

`react-markdown`'s `components` map lets you override how a code
block renders, but the FENCE CONTENT (the JSON inside) is opaque to
the renderer. Pre-processing the source string is cleaner:

1. Split source on `/```chart\n([\s\S]*?)\n```/gi`
2. For each segment: text → react-markdown, chart → ChartBlock
3. Preserve original order

This also keeps the streaming-safe check simple: if a fence is
unclosed, the trailing text stays as a plain string instead of
going through Markdown (which would render an open code block).

## `apps/web/src/components/MarkdownContent.tsx`

```tsx
import { useMemo } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ChartBlock } from './ChartBlock';

interface MarkdownContentProps {
  source: string;
  className?: string;
}

type Segment =
  | { kind: 'markdown'; text: string }
  | { kind: 'chart'; json: string };

function splitOnChartFences(source: string): Segment[] {
  const out: Segment[] = [];
  const re = /```chart\s*\n([\s\S]*?)\n```/gi;
  let lastIdx = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(source)) !== null) {
    if (m.index > lastIdx) {
      out.push({ kind: 'markdown', text: source.slice(lastIdx, m.index) });
    }
    out.push({ kind: 'chart', json: m[1].trim() });
    lastIdx = re.lastIndex;
  }
  if (lastIdx < source.length) {
    out.push({ kind: 'markdown', text: source.slice(lastIdx) });
  }
  return out;
}

export function MarkdownContent({ source, className }: MarkdownContentProps) {
  const segments = useMemo(() => splitOnChartFences(source), [source]);
  return (
    <div className={className}>
      {segments.map((seg, i) =>
        seg.kind === 'markdown' ? (
          <MarkdownSegment key={i} text={seg.text} />
        ) : (
          <ChartBlock key={i} json={seg.json} />
        ),
      )}
    </div>
  );
}

function MarkdownSegment({ text }: { text: string }) {
  if (!text.trim()) return null;
  return (
    <div className="prose prose-sm dark:prose-invert max-w-none
                    [&_p]:my-1.5 [&_ul]:my-1.5 [&_ol]:my-1.5
                    [&_h1]:text-base [&_h2]:text-sm [&_h3]:text-sm [&_h4]:text-sm
                    [&_table]:text-xs [&_code]:text-xs [&_pre]:text-xs">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>
        {text}
      </ReactMarkdown>
    </div>
  );
}

// Streaming-safe variant: holds back Markdown rendering if a
// ```chart fence is still open (so a partial fence doesn't get
// rendered as a broken code block).
export function StreamingMarkdown({ source }: { source: string }) {
  const lastTriple = source.lastIndexOf('```');
  if (lastTriple !== -1) {
    const after = source.slice(lastTriple + 3);
    if (!after.includes('```')) {
      return (
        <>
          {source}
          <span className="inline-block w-1.5 h-4 bg-primary ml-0.5 align-middle animate-pulse" />
        </>
      );
    }
  }
  return (
    <>
      <MarkdownContent source={source} />
      <span className="inline-block w-1.5 h-4 bg-primary ml-0.5 align-middle animate-pulse" />
    </>
  );
}
```

## `apps/web/src/components/ChartBlock.tsx`

```tsx
import {
  Chart as ChartJS,
  BarController, LineController, PieController, DoughnutController,
  CategoryScale, LinearScale,
  PointElement, LineElement, BarElement, ArcElement,
  Title, Tooltip, Legend, Filler,
} from 'chart.js';
import { Bar, Line, Pie, Doughnut } from 'react-chartjs-2';

// Register the controllers / elements / plugins we need. Chart.js
// v4 does not auto-register anything; this explicit path keeps
// the bundle tight (unused scales don't get pulled in).
ChartJS.register(
  BarController, LineController, PieController, DoughnutController,
  CategoryScale, LinearScale,
  PointElement, LineElement, BarElement, ArcElement,
  Title, Tooltip, Legend, Filler,
);

type ChartType = 'bar' | 'line' | 'pie' | 'doughnut';

interface ChartSpec {
  type: ChartType;
  data: {
    labels: string[];
    datasets: Array<{
      label?: string;
      data: number[];
      backgroundColor?: string | string[];
      borderColor?: string;
      borderWidth?: number;
      fill?: boolean;
      tension?: number;
    }>;
  };
  options?: Record<string, unknown>;
}

const DEFAULT_PALETTE = [
  'rgba(59, 130, 246, 0.7)',  // blue-500
  'rgba(16, 185, 129, 0.7)',  // emerald-500
  'rgba(245, 158, 11, 0.7)',  // amber-500
  'rgba(239, 68, 68, 0.7)',   // red-500
  'rgba(139, 92, 246, 0.7)',  // violet-500
  'rgba(14, 165, 233, 0.7)',  // sky-500
  'rgba(236, 72, 153, 0.7)',  // pink-500
  'rgba(34, 197, 94, 0.7)',   // green-500
];

function fillDefaults(spec: ChartSpec): ChartSpec {
  const datasets = spec.data.datasets.map((ds, i) => ({
    ...ds,
    backgroundColor:
      ds.backgroundColor ??
      (spec.type === 'pie' || spec.type === 'doughnut'
        ? DEFAULT_PALETTE
        : DEFAULT_PALETTE[i % DEFAULT_PALETTE.length]),
    borderColor: ds.borderColor ?? DEFAULT_PALETTE[i % DEFAULT_PALETTE.length],
    borderWidth: ds.borderWidth ?? (spec.type === 'line' ? 2 : 1),
  }));
  return { ...spec, data: { ...spec.data, datasets } };
}

export function ChartBlock({ json }: { json: string }) {
  let spec: ChartSpec;
  try {
    spec = JSON.parse(json) as ChartSpec;
  } catch {
    return (
      <div className="my-2 rounded border border-destructive/30 bg-destructive/5 p-2 text-xs">
        <div className="font-semibold text-destructive mb-1">Chart JSON parse error</div>
        <pre className="whitespace-pre-wrap break-all text-foreground/80">{json}</pre>
      </div>
    );
  }

  if (!spec.type || !spec.data || !Array.isArray(spec.data.datasets)) {
    return (
      <div className="my-2 rounded border border-amber-500/30 bg-amber-500/5 p-2 text-xs">
        <div className="font-semibold text-amber-700 dark:text-amber-400 mb-1">Incomplete chart spec</div>
        <pre className="whitespace-pre-wrap break-all">{json}</pre>
      </div>
    );
  }

  const filled = fillDefaults(spec);
  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: filled.data.datasets.length > 1, position: 'bottom' as const },
    },
    ...(filled.options as object),
  };

  return (
    <div className="my-3 rounded border bg-card p-3 shadow-sm">
      <div className="h-64 w-full">
        <ChartRenderer type={filled.type} data={filled.data} options={options} />
      </div>
    </div>
  );
}

function ChartRenderer({
  type, data, options,
}: { type: ChartType; data: ChartSpec['data']; options: object }) {
  switch (type) {
    case 'bar':      return <Bar data={data} options={options} />;
    case 'line':     return <Line data={data} options={options} />;
    case 'pie':      return <Pie data={data} options={options} />;
    case 'doughnut': return <Doughnut data={data} options={options} />;
    default: return <div className="text-xs text-destructive">Unsupported chart type: {String(type)}</div>;
  }
}
```

## Adapt to your project

- **Component library**: the `cn()` calls assume Tailwind. If you're
  on a different styling system, replace with your project's
  conditional class helper.
- **Dark mode**: the colour palette is hard-coded with alpha 0.7.
  If you need dark-mode contrast, swap the palette for CSS
  variables.
- **Multi-dataset charts**: the `DEFAULT_PALETTE` cycles, so the
  3rd+ dataset reuses palette colours. If you have more than
  8 datasets, add more colours.
