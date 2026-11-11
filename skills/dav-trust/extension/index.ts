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
 * 另外三件事（同一個 trust 前提有關）：
 *   1. **機械報時（time tick）**：agent 冇自己嘅鐘，只喺 4 個 checkpoint 主動 `date`。
 *      trust mode 期間每 `timeTickMinutes`（默認 30）分鐘注入一次「現在時間 ＋ 剩餘預算
 *      ＋ 依剩餘比例嘅指令（接力 / 收斂 / 收工）」—— 唔會再寫假時間戳、唔會過咗 deadline 唔知。
 *      `PHASE=終局`（已結束）同 `PHASE=暫停`（用戶揸方向盤）都唔報時。
 *      文字同判定**唔喺呢度**：一律叫 `./clock-tick.py`（pi／Claude Code／Qoder 共用嘅
 *      單一真相；Claude Code／Qoder 冇 timer，用 hook 叫同一支腳本）。
 *   2. **fuse 審核**：trust mode 期間每次 run 開始都驗 `compaction.reserveTokens` 係唔係令
 *      原生壓縮落喺機會窗口內。設得太遲 = agent 冇手掣、到 hard block 都冇人壓 → 出聲。
 *   3. **hard block 強制指令**：trust mode 一到 hard 區，每輪注入一條唔可以當睇唔到嘅指令
 *      （停新工作 ＋ 更新 trust-log checkpoint ＋ 報告 fuse 太遲）。agent 自己按唔到壓縮掣
 *      （pi 1.4.0 實測），所以呢啲提示就係唯一可以「逼佢遵守 dav-self-compact」嘅手段。
 *
 * 設定：`~/.pi/agent/dav-trust.json`（唔存在就用默認；`enabled: false` 可關掉，
 * `timeTickMinutes: 0` 可單獨關報時）
 * 純判定邏輯喺 ./lib/sleep-guard.ts 同 ./lib/fuse-audit.ts（無 I/O、可單獨測試）。
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { blockReason, DEFAULT_MAX_SLEEP_SECONDS, findIdleWait } from "./lib/sleep-guard.ts";
import { auditFuse, fuseAuditText, normalizeTrustZones, resolveReserveTokens } from "./lib/fuse-audit.ts";

const CONFIG_PATH = join(homedir(), ".pi", "agent", "dav-trust.json");
const ZONES_PATH = join(homedir(), ".pi", "agent", "dav-self-compact.json");
const SLEEP_TOOLS = new Set(["bash", "powershell", "shell"]);
/** 跨 host 共用嘅報時腳本（同一支腳本 Claude Code／Qoder 嘅 hook 都叫）。 */
const TICK_SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "clock-tick.py");

/** 報時間隔默認 30 分鐘（用戶要求：確保 agent 知道現在時間）。 */
export const DEFAULT_TIME_TICK_MINUTES = 30;

type Config = {
	enabled: boolean;
	maxSleepSeconds: number;
	/** 0 = 關掉機械報時 */
	timeTickMinutes: number;
};

function loadConfig(): Config {
	let parsed: { enabled?: unknown; maxSleepSeconds?: unknown; timeTickMinutes?: unknown } = {};
	try {
		parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as typeof parsed;
	} catch {
		parsed = {};
	}
	const max =
		typeof parsed.maxSleepSeconds === "number" && Number.isFinite(parsed.maxSleepSeconds) && parsed.maxSleepSeconds >= 0
			? parsed.maxSleepSeconds
			: DEFAULT_MAX_SLEEP_SECONDS;
	const tick =
		typeof parsed.timeTickMinutes === "number" && Number.isFinite(parsed.timeTickMinutes) && parsed.timeTickMinutes >= 0
			? parsed.timeTickMinutes
			: DEFAULT_TIME_TICK_MINUTES;
	return { enabled: parsed.enabled !== false, maxSleepSeconds: max, timeTickMinutes: tick };
}

/** 讀專案嘅 `docs/trust-log.md`（唔存在 → null）。 */
function readTrustLog(ctx: ExtensionContext): string | null {
	try {
		return readFileSync(join(ctx.cwd, "docs", "trust-log.md"), "utf8");
	} catch {
		return null;
	}
}

/**
 * trust mode 係唔係進行中：睇專案嘅 docs/trust-log.md 檔頭。
 * 冇檔／冇 `Deadline:` → 唔係 trust mode（唔干預）；`PHASE=終局` → 已結束（唔干預）。
 * （呢度唔叫 python 腳本：每次 tool call 都要跑，要快同要冇依賴。）
 */
function trustModeActive(ctx: ExtensionContext): boolean {
	const log = readTrustLog(ctx);
	if (!log) return false;
	const deadline = /^\s*>?\s*Deadline:/m.test(log);
	const phase = log.match(/^\s*>?\s*進度錨點:[^\n]*PHASE=([^\s、，]+)/m)?.[1] ?? "";
	return deadline && !phase.includes("終局");
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

/** 機械報時嘅 timer（session-scoped：session_start 起、session_shutdown 清）。 */
let tickTimer: ReturnType<typeof setInterval> | null = null;
/** python3 唔在 → 只出一次聲，唔好每 30 分鐘炒一次。 */
let tickWarned = false;

function stopTimeTick(): void {
	if (tickTimer !== null) {
		clearInterval(tickTimer);
		tickTimer = null;
	}
}

/**
 * 每 `timeTickMinutes` 分鐘把「現在時間 ＋ 剩餘預算 ＋ 跟住點做」注入對話。
 * 只喺 trust mode 生效；`PHASE=終局`／`PHASE=暫停` 唔報（判定同文字都在 ./clock-tick.py）。
 * 點解要注入而唔係叫 agent 自己查：trust mode 長跑幾個鐘，agent 只喺 4 個 checkpoint 查時間，
 * 中間嘅時間盲區就係「假時間戳」同「過咗 deadline 唔知」嘅根源。
 */
function startTimeTick(pi: ExtensionAPI, ctx: ExtensionContext): void {
	stopTimeTick();
	const minutes = loadConfig().timeTickMinutes;
	if (minutes <= 0) return;
	tickTimer = setInterval(() => {
		if (!loadConfig().enabled) return;
		const text = clockTickText(ctx.cwd, minutes);
		if (!text) return;
		pi.sendMessage(
			{ customType: "dav-trust", content: text, display: true },
			// followUp = 等 agent 做完手頭嘅工具序列才插入（唔切斷一輪工作）；
			// triggerTurn = agent 閒置（trust mode 唔應該發生）時叫醒佢對錶。
			{ deliverAs: "followUp", triggerTurn: true },
		);
	}, minutes * 60_000);
	tickTimer.unref?.();
}

/** 叫跨 host 共用嘅報時腳本；唔夠鐘／唔係 trust mode／冇 python3 → 靜靜回 null。 */
function clockTickText(cwd: string, minutes: number): string | null {
	try {
		const result = spawnSync(
			"python3",
			[TICK_SCRIPT, "--format", "text", "--project", cwd, "--interval-minutes", String(minutes)],
			{ encoding: "utf8", timeout: 15_000 },
		);
		if (result.error) {
			if (!tickWarned) {
				tickWarned = true;
				console.error(`[dav-trust] clock tick disabled: ${String(result.error)}`);
			}
			return null;
		}
		return (result.stdout ?? "").trim() || null;
	} catch (error) {
		if (process.env.DAV_TRUST_DEBUG) console.error(`[dav-trust] clock tick failed: ${String(error)}`);
		return null;
	}
}

export function resetHardNoticeState_(): void {
	turnCounter = 0;
	lastHardNoticeTurn = -1;
}

export default function (pi: ExtensionAPI): void {
	// trust mode 期間每次 run 開始：fuse 唔對就一定要出聲（model 同人都要見到）。
	pi.on("session_start", (_event, ctx) => {
		resetHardNoticeState_();
		startTimeTick(pi, ctx);
	});

	// 唔可以留住 background timer（session 換／退出都要清）。
	pi.on("session_shutdown", () => {
		stopTimeTick();
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
