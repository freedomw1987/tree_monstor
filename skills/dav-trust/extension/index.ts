/**
 * dav-trust — 「唔准等時間」機械守門。
 *
 * 為什麼：trust mode 俾咗大目標 ＋ deadline 之後，agent 做完手頭工作會自己發明
 * `sleep 3600` 之類嘅指令「等夠鐘」。deadline 係**授權上限**（幾時一定要停），
 * 唔係「要坐夠鐘」—— 等時間純粹浪費，而且唔係 skill 要求嘅行為。
 *
 * 呢個 extension 喺 **trust mode 進行中**（`docs/<cwd>/trust-log.md` 檔頭有
 * `Deadline:` 而且 `PHASE` 唔係終局）擋走「等時間」嘅 shell 指令：
 *   - `sleep` 長過 `maxSleepSeconds`（默認 30 秒）
 *   - `sleep` 長度證明唔到（變數／命令替換，例如 `sleep $(date +%s)`）
 *   - 空轉迴圈（`while true` / `until false`）、淨係 `wait`
 * 短 sleep（≤ 30 秒）照樣放行 —— 等 port 起、retry backoff 都係正常需要。
 *
 * 另外兩件事（同一個 trust 前提有關）：
 *   1. **fuse 審核**：trust mode 期間每次 run 開始都驗 `compaction.reserveTokens` 係唔係令
 *      原生壓縮落喺機會窗口內。設得太遲 = agent 冇手掣、到 hard block 都冇人壓 → 出聲。
 *   2. **hard block 強制指令**：trust mode 一到 hard 區，每輪注入一條唔可以當睇唔到嘅指令
 *      （停新工作 ＋ 更新 trust-log checkpoint ＋ 報告 fuse 太遲）。agent 自己按唔到壓縮掣
 *      （pi 1.4.0 實測），所以呢啲提示就係唯一可以「逼佢遵守 dav-self-compact」嘅手段。
 *
 * 設定：`~/.pi/agent/dav-trust.json`（唔存在就用默認；`enabled: false` 可關掉）
 * 純判定邏輯喺 ./lib/sleep-guard.ts 同 ./lib/fuse-audit.ts（無 I/O、可單獨測試）。
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { blockReason, DEFAULT_MAX_SLEEP_SECONDS, findIdleWait } from "./lib/sleep-guard.ts";
import { auditFuse, fuseAuditText, normalizeTrustZones, resolveReserveTokens } from "./lib/fuse-audit.ts";

const CONFIG_PATH = join(homedir(), ".pi", "agent", "dav-trust.json");
const ZONES_PATH = join(homedir(), ".pi", "agent", "dav-self-compact.json");
const SLEEP_TOOLS = new Set(["bash", "powershell", "shell"]);

type Config = {
	enabled: boolean;
	maxSleepSeconds: number;
};

function loadConfig(): Config {
	let parsed: { enabled?: unknown; maxSleepSeconds?: unknown } = {};
	try {
		parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as typeof parsed;
	} catch {
		parsed = {};
	}
	const max =
		typeof parsed.maxSleepSeconds === "number" && Number.isFinite(parsed.maxSleepSeconds) && parsed.maxSleepSeconds >= 0
			? parsed.maxSleepSeconds
			: DEFAULT_MAX_SLEEP_SECONDS;
	return { enabled: parsed.enabled !== false, maxSleepSeconds: max };
}

/**
 * trust mode 係唔係進行中：睇專案嘅 docs/trust-log.md 檔頭。
 * 冇檔／冇 `Deadline:` → 唔係 trust mode（唔干預）；`PHASE=終局` → 已結束（唔干預）。
 */
function trustModeActive(ctx: ExtensionContext): boolean {
	try {
		const log = readFileSync(join(ctx.cwd, "docs", "trust-log.md"), "utf8");
		const deadline = /^>\s*Deadline:/m.test(log);
		const phase = log.match(/^>\s*進度錨點:[^\n]*PHASE=([^\s、]+)/m)?.[1] ?? "";
		return deadline && !phase.includes("終局");
	} catch {
		return false;
	}
}

/** dav-self-compact 嘅門檻（同一份檔案，唔另開設定；唔存在 → 用該 skill 嘅默認值）。 */
function loadZones() {
	try {
		return normalizeTrustZones(JSON.parse(readFileSync(ZONES_PATH, "utf8")));
	} catch {
		return normalizeTrustZones({});
	}
}

type CompactionSettings = { reserveTokens?: unknown; modelOverrides?: Record<string, { reserveTokens?: unknown }> };

/** 目前 model 嘅 fuse 狀態（fuse 太遲 = trust mode 撐到 hard 都冇人壓縮）。 */
function fuseStatus(
	ctx: ExtensionContext,
	settings: { compaction?: CompactionSettings } | undefined,
) {
	const zones = loadZones();
	const contextWindow = ctx.getContextUsage()?.contextWindow ?? ctx.model?.contextWindow ?? 0;
	const modelKey = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined;
	const reserve = resolveReserveTokens(settings?.compaction, modelKey);
	if (contextWindow <= 0) return null;
	return { zones, audit: auditFuse(contextWindow, reserve, zones) };
}

/** hard 區提示節流：首次即出，之後每 N 輪補一次（唔想每輪炒同一句話）。 */
const HARD_NOTICE_EVERY_TURNS = 5;
let turnCounter = 0;
let lastHardNoticeTurn = -1;

export function resetHardNoticeState_(): void {
	turnCounter = 0;
	lastHardNoticeTurn = -1;
}

export default function (pi: ExtensionAPI): void {
	// trust mode 期間每次 run 開始：fuse 唔對就一定要出聲（model 同人都要見到）。
	pi.on("session_start", () => {
		resetHardNoticeState_();
	});

	pi.on("before_agent_start", (_event, ctx) => {
		if (process.env.DAV_TRUST_DEBUG) {
			console.error(`[dav-trust] before_agent_start trusted=${trustModeActive(ctx)} enabled=${loadConfig().enabled}`);
		}
		if (!loadConfig().enabled || !trustModeActive(ctx)) return;
		const status = fuseStatus(ctx, pi.getSettings() as { compaction?: CompactionSettings });
		if (process.env.DAV_TRUST_DEBUG) {
			console.error(`[dav-trust] fuse=${JSON.stringify(status?.audit ?? null)}`);
		}
		if (!status || status.audit.ok) return;
		const text = fuseAuditText(status.audit, status.zones);
		if (ctx.hasUI) ctx.ui.notify(text, "warning");
		return {
			message: {
				customType: "dav-trust",
				display: true,
				content: `[dav-trust] ${text} Until it is fixed: stop opening new work at the opportunity window, refresh docs/trust-log.md checkpoint, and report — do not push past the hard block.`,
			},
		};
	});

	// trust mode 期間到 hard 區：每輪一條強制指令（agent 冇壓縮手掣，所以唔可以靜靜當冇事）。
	pi.on("turn_end", (_event, ctx) => {
		if (!loadConfig().enabled || !trustModeActive(ctx)) return;
		const status = fuseStatus(ctx, pi.getSettings() as { compaction?: CompactionSettings });
		if (!status) return;
		turnCounter += 1;
		const tokens = ctx.getContextUsage()?.tokens ?? null;
		if (tokens === null || tokens < status.audit.hardTokens) return;
		if (lastHardNoticeTurn >= 0 && turnCounter - lastHardNoticeTurn < HARD_NOTICE_EVERY_TURNS) return;
		lastHardNoticeTurn = turnCounter;
		const text =
			`[dav-trust] hard block reached in trust mode: ${tokens} tokens >= hard deadline ${status.audit.hardTokens}. ` +
			"dav-self-compact is mandatory here — stop opening new work, finish the atomic step, refresh the docs/trust-log.md checkpoint, " +
			`then let compaction happen and continue the L1 → L2 → L3 relay. ${fuseAuditText(status.audit, status.zones)}`;
		if (ctx.hasUI) ctx.ui.notify(text, "warning");
		return {
			entries: [{ type: "custom_message", customType: "dav-trust", content: text, display: true }],
		};
	});
	pi.on("tool_call", (event, ctx) => {
		if (!SLEEP_TOOLS.has(event.toolName)) return;
		const config = loadConfig();
		if (!config.enabled) return;
		if (!trustModeActive(ctx)) return;
		const command = (event.input as { command?: unknown })?.command;
		if (typeof command !== "string") return;
		const wait = findIdleWait(command, config.maxSleepSeconds);
		if (!wait) return;
		return { block: true, reason: blockReason(wait, config.maxSleepSeconds) };
	});
}
