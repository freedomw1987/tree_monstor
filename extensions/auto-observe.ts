/**
 * extensions/auto-observe.ts
 *
 * Pi Extension that hooks `tool_call(TaskUpdate)` events and writes a
 * RSI observation whenever an LLM marks a task as completed.
 *
 * 對應 docs/sop/rsi-reviewer-verdict-2026-09-22-auto-observe-v2.md APPROVE_WITH_NITS
 * 對應 docs/sop/handbook/2.8-rsi-evolution.md §7.4
 *
 * 設計原則：
 *   - 不依賴 agent 自律：extension 在每次 TaskUpdate(completed) 時自動觸發
 *   - 觀察失敗不阻塞任務：execFileAsync 不 await，.catch 兜底
 *   - 降噪：每 session 只通知一次成功（避免高頻 task 完成時 spam UI）
 *   - 失敗每次都警告（罕見）
 *   - Script 路徑解析：用 import.meta.url 找 Extension 自己所在 dir，與 observe-pi-task.sh 同目錄
 *     安裝時 Extension 跟 Script 都部署到 ${agent_root}/extensions/
 *
 * 部署位置（由 install.sh 設定）：
 *   - ~/.pi/agent/extensions/auto-observe.ts        （global install）
 *   - <project>/.pi/agent/extensions/auto-observe.ts （--target mode）
 *   - 兩者旁邊都有 observe-pi-task.sh
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);

// 計算自己所在 dir（與 observe-pi-task.sh 同目錄）
function getScriptPath(): string {
  let myDir: string;
  try {
    // ESM (jiti 預設)
    myDir = dirname(fileURLToPath(import.meta.url));
  } catch {
    // CJS fallback
    myDir = __dirname;
  }
  return join(myDir, "observe-pi-task.sh");
}

// 降噪：每 session 只 notify 一次成功
let successNotified = false;

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    // 只攔截 TaskUpdate(status=completed)
    if (event.toolName !== "TaskUpdate") return;
    if (event.input?.status !== "completed") return;

    // 取得 session ID 跟 task ID
    const sessionId = ctx.sessionManager?.getSessionId?.() ?? "unknown";
    const taskId = String(event.input.taskId ?? "");
    if (!taskId) return;

    // 觀察腳本路徑（與 Extension 同目錄）
    const scriptPath = getScriptPath();

    // fire-and-forget：失敗不阻塞 TaskUpdate 結果
    execFileAsync(
      scriptPath,
      ["--cwd", ctx.cwd, "--task-id", taskId, "--session-id", sessionId],
      { cwd: ctx.cwd, timeout: 5000 }
    )
      .then(() => {
        if (!successNotified) {
          ctx.ui.notify("RSI observation auto-writer active", "info");
          successNotified = true;
        }
      })
      .catch((e: Error) => {
        ctx.ui.notify(
          `RSI observation failed: ${String(e.message ?? e).slice(0, 200)}`,
          "warning"
        );
      });
  });
}
