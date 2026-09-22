/**
 * extensions/types/pi-coding-agent.d.ts
 *
 * Minimal type stub for `@earendil-works/pi-coding-agent` so that
 * `tsc --noEmit` can statically check auto-observe.ts without depending
 * on the global Node module path of pi-coding-agent.
 *
 * 設計理由：
 *   - Pi extensions 在 runtime 透過 jiti 載入，可以解析全域 pi-coding-agent
 *   - 但本地 tsc 不知道全域路徑，硬寫硬編碼路徑不可移植（reviewer N1 的精神）
 *   - 用最精簡的 stub 只覆蓋我們用到的 API：
 *     1. `pi.on(eventName, handler)` — 註冊事件
 *     2. `ctx.sessionManager?.getSessionId?.()` — 拿 session ID
 *     3. `ctx.cwd` — 拿工作目錄
 *     4. `ctx.ui.notify(message, level)` — 顯示 toast
 *
 * 對應 docs/sop/rsi-reviewer-verdict-2026-09-22-auto-observe-v2.md APPROVE_WITH_NITS
 */

declare module "@earendil-works/pi-coding-agent" {
  export interface ExtensionContext {
    cwd: string;
    sessionManager?: {
      getSessionId?: () => string | undefined;
      getSessionFile?: () => string | undefined;
    };
    ui: {
      notify: (
        message: string,
        level: "info" | "warning" | "error"
      ) => void;
    };
  }

  export interface ToolCallEvent {
    toolName: string;
    input?: Record<string, unknown>;
    output?: unknown;
  }

  export interface ExtensionAPI {
    on: (
      eventName: "tool_call",
      handler: (event: ToolCallEvent, ctx: ExtensionContext) => void | Promise<void>
    ) => void;
  }
}

declare module "node:child_process" {
  export interface ExecFileOptions {
    cwd?: string;
    timeout?: number;
  }
  export function execFile(
    file: string,
    args: readonly string[] | undefined,
    options: ExecFileOptions,
    callback: (error: Error | null, stdout: string, stderr: string) => void
  ): import("node:events").EventEmitter;
  export function execFile(
    file: string,
    args: readonly string[] | undefined,
    options: ExecFileOptions
  ): import("node:events").EventEmitter & Promise<{ stdout: string; stderr: string }>;
}

declare module "node:util" {
  export function promisify<T extends (...args: any[]) => any>(
    fn: T
  ): (...args: Parameters<T>) => Promise<Awaited<ReturnType<T>>>;
}

declare module "node:path" {
  export function join(...parts: string[]): string;
  export function dirname(p: string): string;
}

declare module "node:url" {
  export function fileURLToPath(url: string | URL): string;
}

// ESM import.meta.url 支援
interface ImportMeta {
  readonly url: string;
}

// CJS __dirname 支援（jiti 預設 cjs）
declare const __dirname: string;
