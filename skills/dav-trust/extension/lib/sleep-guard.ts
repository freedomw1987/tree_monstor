/**
 * dav-trust 嘅純判定層：認出「等時間」嘅 shell 指令（無 I/O、可單獨測試）。
 *
 * 為什麼要有呢個：trust mode 俾咗 deadline 之後，agent 做完手頭工作會自己發明
 * `sleep 3600` 之類嘅指令「等夠鐘」—— 呢個唔係 skill 要求嘅行為，係浪費。
 * 正確出口係 L1 → L2 → L3 接力，全部耗盡就收斂提早結束。
 */

export type IdleWait = {
	/** 命中嘅形態：long-sleep / unknown-sleep / busy-loop / bare-wait */
	kind: "long-sleep" | "unknown-sleep" | "busy-loop" | "bare-wait";
	/** 人類可讀證據（引用原文片段） */
	detail: string;
};

export const DEFAULT_MAX_SLEEP_SECONDS = 30;

/** "600" → 600；"5m" → 300；"1h" → 3600；"0.5" → 0.5；變數／命令替換 → null（長度不明）。 */
export function parseSleepSeconds(arg: string): number | null {
	const value = arg.trim().replace(/^["']|["']$/g, "");
	if (value === "") return null;
	// 變數、命令替換、算術展開：證明唔到佢短 → 當「長度不明」
	if (/[$`(]/.test(value)) return null;
	const match = value.match(/^(\d+(?:\.\d+)?)([smhd]?)$/);
	if (!match) return null;
	const amount = Number(match[1]);
	if (!Number.isFinite(amount)) return null;
	switch (match[2]) {
		case "m":
			return amount * 60;
		case "h":
			return amount * 3600;
		case "d":
			return amount * 86400;
		default:
			return amount;
	}
}

/** 逐段拆開 shell 一行（; && || | 換行），避免只看第一個指令就漏掉後面嗰個 sleep。 */
function segments(command: string): string[] {
	return command.split(/;|&&|\|\||\||\n/).map((part) => part.trim()).filter((part) => part.length > 0);
}

/**
 * 判斷一條 bash 指令係唔係「等時間」。
 * maxSleepSeconds：短過呢個秒數嘅 sleep 當正常（等 port 起、retry backoff 等）。
 */
export function findIdleWait(command: string, maxSleepSeconds: number = DEFAULT_MAX_SLEEP_SECONDS): IdleWait | null {
	// 空轉迴圈要喺切段之前睇（`while true; do …; done` 一經 `;` 切開就認唔到）
	if (/(?:while\s+(?:true|\:)\b|until\s+false\b)/.test(command)) {
		return { kind: "busy-loop", detail: command.trim().slice(0, 120) };
	}
	for (const raw of segments(command)) {
		// `timeout 10 sleep 600` / `command sleep 600` 都要認到
		const segment = raw.replace(/^(?:\w+\s+)*?(?:\d+(?:\.\d+)?[smhd]?\s+)?sleep\b/, "sleep").trim();
		const sleepMatch = segment.match(/^sleep\b\s*(.*)$/);
		if (!sleepMatch) {
			if (segment === "wait") return { kind: "bare-wait", detail: raw.slice(0, 120) };
			continue;
		}
		const seconds = parseSleepSeconds(sleepMatch[1] ?? "");
		if (seconds === null) {
			return { kind: "unknown-sleep", detail: raw.slice(0, 120) };
		}
		if (seconds > maxSleepSeconds) {
			return { kind: "long-sleep", detail: raw.slice(0, 120) };
		}
	}
	return null;
}

/** 被擋嘅時候回俾 model 嘅理由（要同時講「點解」同「應該點做」）。 */
export function blockReason(wait: IdleWait, maxSleepSeconds: number): string {
	const head: Record<IdleWait["kind"], string> = {
		"long-sleep": `Blocked: \`sleep\` longer than ${maxSleepSeconds}s is not allowed here —`,
		"unknown-sleep": "Blocked: a `sleep` whose length cannot be proven short is not allowed here —",
		"busy-loop": "Blocked: an idle busy-loop (`while true`/`until false`) is not allowed here —",
		"bare-wait": "Blocked: a bare `wait` that only idles is not allowed here —",
	};
	return [
		`${head[wait.kind]} waiting for the clock is never the way to finish trust mode.`,
		`Evidence: ${wait.detail}`,
		"Trust mode grants scope, not a requirement to stay busy until the deadline (skills/dav-trust/time-anchor.md §6).",
		"Do this instead: continue the L1 → L2 → L3 relay; when the backlog and the docs/ plans are exhausted, consolidate, deliver, report early completion and exit trust mode.",
		`If you genuinely must wait for an external event (a background job, CI, a port), keep it short (<= ${maxSleepSeconds}s) and say what you are waiting for.`,
	].join("\n");
}
