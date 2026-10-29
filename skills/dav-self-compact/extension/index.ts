/**
 * dav-self-compact — context 壓力錶 ＋ 聰明區守門 ＋ 原生保險絲自動對齊。
 *
 * 為什麼：LLM 喺 context window 用得少（聰明區）時推理最穩；長任務會把 context 撐爆，
 * 模型注意力下降、指令遺失。呢個 extension 令 model 同 subagent 自己睇得到使用率
 * （`ctx_status` 工具 ＋ 每輪 run 開始時自動注入提示），唔需要靠估。
 *
 * 四區（默認值；可用 ~/.pi/agent/dav-self-compact.json 覆寫）：
 *   smart       <  soft (50%)        → 繼續做
 *   soft        >= soft (50%)        → 寫交接筆記、避開大讀取，等機會窗口
 *   opportunity >= win (55%)         → 機會窗口：揀最好嘅邊界壓縮（最佳時機）
 *   hard        >= hard (60%)        → 死線：唔開新大工作；fuse 理應已喺窗口內開火
 *
 * 目標係「喺機會窗口內壓縮」，唔好等到 hard 之後才被迫壓縮 —— 所以 fuse 對齊嘅係
 * opportunityTokens（唔係 hardTokens）。
 *
 * 另外每跨過一個使用率里程碑（默認 20%／40%／60%）就印一次：使用率 ＋ zone ＋ 要做乜
 * （transcript 可見 ＋ 入下一輪 context）。
 *
 * 「有效 window」= min(contextWindow, absoluteCapTokens)；absoluteCapTokens > 0 時，
 * 1M window 模型嘅 50% 唔會等於 50 萬 tokens（實際上早已唔聰明）。
 *
 * ── 保險絲自動對齊（v2）────────────────────────────────────────────────
 * 舊問題：閾值（dav-self-compact.json）同 pi 原生門檻（settings.json reserveTokens）
 * 係兩個地方，人手同步 → 改咗閾值就會漂移 → fuse 98.4% 先開火 → hard block 先到 →
 * 無人睇嘅長任務就停咗（用戶冇人手動 /compact）。
 * v2 做法：
 *   1. live fuse：patch `SettingsManager.getCompactionSettings()` → pi 每個回合問門檻
 *      都用 config 即時計出嚟嘅值 → 改 config 即時生效，唔使 /reload、唔使新 session。
 *   2. 自動對齊 settings.json：session 開始時把對齊值寫成 per-model override
 *      （compaction.modelOverrides["provider/modelId"]），令其他工具／下次 session 都啱。
 *   3. 壓縮仍然由 pi 原生機制做（prepareNextTurn 之間、唔 abort、壓完繼續跑）——
 *      所以無人睇嘅長任務都會自動壓縮同繼續。
 *
 * 純計算（zone／fuse／目標值）喺 ./lib/zone.ts；settings 讀寫喺 ./lib/settings.ts。
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
// namespace import：萬一將來 pi 唔再 export SettingsManager，都唔會令成個 extension 載入失敗
// （named import 遇到唔存在嘅 export 係 link error → 連 ctx_status 都冇）。
import * as PiCodingAgent from "@earendil-works/pi-coding-agent";
import {
	advice,
	applyLiveFuse,
	computeReading,
	DEFAULT_CONFIG,
	desiredReserveTokens,
	FALLBACK_RESERVE_TOKENS,
	fuseNote,
	fusePlan,
	milestoneText,
	nextNotice,
	normalizeConfig,
	oneLine,
	shouldResetNotices,
	type Config,
	type Reading,
} from "./lib/zone.ts";
import { alignSettingsObject, effectiveReserveTokens, readJsonFile, syncModelReserveTokens } from "./lib/settings.ts";

const CONFIG_PATH = join(homedir(), ".pi", "agent", "dav-self-compact.json");
const GLOBAL_SETTINGS_PATH = join(homedir(), ".pi", "agent", "settings.json");
const LIVE_FUSE_FLAG = "__davSelfCompactLiveFuse";

/** 讀設定檔；唔存在／壞 JSON → 默認值（唔會令 session 死機）。 */
function loadConfig(): Config {
	try {
		return normalizeConfig(JSON.parse(readFileSync(CONFIG_PATH, "utf8")));
	} catch {
		return { ...DEFAULT_CONFIG };
	}
}

/** pi 真正會用嘅 reserveTokens（讀檔，跟足 pi 嘅覆蓋次序）。 */
function fileReserveTokens(ctx: ExtensionContext): { key: string; reserve: number } {
	const key = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "";
	const global = readJsonFile(GLOBAL_SETTINGS_PATH);
	const project = readJsonFile(join(ctx.cwd, ".pi", "settings.json"));
	return { key, reserve: effectiveReserveTokens(global, project, key, FALLBACK_RESERVE_TOKENS) };
}

/** live fuse 狀態：file（settings.json 嘅值）＋ live（pi 實際會用嘅值）。 */
type FuseStatus = {
	key: string;
	window: number;
	fileReserve: number;
	liveReserve: number;
	changed: boolean;
	reason: string;
};

function fuseStatus(ctx: ExtensionContext, config: Config): FuseStatus {
	const { key, reserve } = fileReserveTokens(ctx);
	const window = ctx.model?.contextWindow ?? 0;
	const global = readJsonFile(GLOBAL_SETTINGS_PATH);
	const keepRecent =
		global?.compaction?.modelOverrides?.[key]?.keepRecentTokens ?? global?.compaction?.keepRecentTokens ?? 20_000;
	const live = applyLiveFuse({ reserveTokens: reserve, keepRecentTokens: keepRecent }, window, config.zones);
	return { key, window, fileReserve: reserve, liveReserve: live.reserveTokens, changed: live.changed, reason: live.reason };
}

/**
 * 裝 live fuse：pi 每個回合問「幾時壓縮」時，都用 config 即時計出嚟嘅門檻。
 * 純計算喺 zone.ts（applyLiveFuse），呢度只負責駁去 pi。
 */
function installLiveFuse(): { installed: boolean; reason: string } {
	const ctor = (PiCodingAgent as { SettingsManager?: { prototype: unknown } }).SettingsManager;
	const proto = ctor?.prototype as unknown as Record<string, unknown> | undefined;
	if (!proto || typeof proto.getCompactionSettings !== "function") return { installed: false, reason: "pi-api-changed" };
	if (proto[LIVE_FUSE_FLAG]) return { installed: true, reason: "already-installed" };
	const original = proto.getCompactionSettings as (this: unknown, model: unknown) => { reserveTokens: number; keepRecentTokens: number };
	proto.getCompactionSettings = function (this: unknown, model: unknown) {
		const settings = original.call(this, model);
		try {
			const config = loadConfig();
			if (!config.liveFuse) return settings;
			const contextWindow = (model as { contextWindow?: number } | undefined)?.contextWindow ?? 0;
			const next = applyLiveFuse(settings, contextWindow, config.zones);
			if (!next.changed) return settings;
			// 順手對齊 pi 記憶體入面嘅 settings → 其它讀設定嘅角色（例如 dav-trust 嘅 fuse
			// 審核）都會見到同一個值，唔會誤報「fuse 太遲」。
			const current = model as { provider?: string; id?: string } | undefined;
			const modelKey = current?.provider && current?.id ? `${current.provider}/${current.id}` : "";
			const manager = this as { settings?: unknown; globalSettings?: unknown };
			for (const scope of [manager.settings, manager.globalSettings]) {
				alignSettingsObject(scope as Parameters<typeof alignSettingsObject>[0], modelKey, next.reserveTokens);
			}
			return { ...settings, reserveTokens: next.reserveTokens };
		} catch {
			return settings;
		}
	};
	proto[LIVE_FUSE_FLAG] = true;
	return { installed: true, reason: "installed" };
}

/** 把對齊值寫入 settings.json（per-model override）；寫唔到都唔會死機。 */
function autoSync(ctx: ExtensionContext, config: Config): { changed: boolean; reason: string } {
	if (!config.autoSyncSettings) return { changed: false, reason: "disabled" };
	const status = fuseStatus(ctx, config);
	if (!status.key || status.window <= 0) return { changed: false, reason: "no-model" };
	const desired = desiredReserveTokens(status.window, config.zones);
	if (desired === null) return { changed: false, reason: "no-target" };
	const result = syncModelReserveTokens(GLOBAL_SETTINGS_PATH, status.key, desired);
	return { changed: result.changed, reason: result.reason };
}

/** 顯示用：fuse 狀態一句（live 生效值 + settings.json 檔案值）。 */
function fuseStatusNote(status: FuseStatus, config: Config): string {
	const plan = fusePlan(status.window, status.liveReserve, config.zones);
	const live =
		`native auto-compaction fires at ${plan.triggerPercent?.toFixed(1) ?? "?"}% (${Math.round(status.liveReserve)} reserveTokens)` +
		` → ${plan.alignment === "aligned" ? "inside the opportunity window ✓ (live fuse)" : plan.alignment}`;
	if (status.changed) {
		const filePercent = status.window > 0 ? ((status.window - status.fileReserve) / status.window) * 100 : null;
		return `${live}; settings.json 仲係 ${filePercent?.toFixed(1) ?? "?"}% → 自動對齊中（下次 session 生效）`;
	}
	return live;
}

function read(ctx: ExtensionContext, config: Config): Reading {
	return computeReading(ctx.getContextUsage(), fuseStatus(ctx, config).liveReserve, config.zones);
}

/**
 * 里程碑狀態（每個 session 一份）：
 *   lastPercent  = 上一次觀察到嘅使用率（用嚟偵測壓縮後大跌）
 *   announced    = 已經通知過嘅里程碑（壓縮後會清空，令之後可以再通知）
 */
let lastPercent: number | null = null;
let announced = new Set<number>();

export function resetMilestoneState_(): void {
	lastPercent = null;
	announced = new Set<number>();
}

/** 跨過里程碑就回傳一條要顯示／要入 context 嘅訊息（一次最多一條）。 */
function takeMilestone(config: Config, reading: Reading): string | null {
	const percent = reading.percent;
	if (shouldResetNotices(lastPercent, percent) && config.zones.noticePercents.some((m) => !announced.has(m))) {
		announced = new Set<number>();
	}
	const { notice, announced: next } = nextNotice(percent, config.zones.noticePercents, announced);
	announced = next;
	if (percent !== null) lastPercent = percent;
	return notice === null ? null : milestoneText(reading, config.zones, notice);
}

const ctxStatusTool = defineTool({
	name: "ctx_status",
	label: "Context Status",
	description:
		"Report this session's context-window usage (tokens, percent, zone) and the action it demands: " +
		"keep_working (<50%), prepare_then_compact (>=50%: write the handoff note, keep next steps small), " +
		"compact_at_boundary (>=55%: the window to compact — pick the best boundary now), " +
		"compact_now (>=60%: past the deadline — stop opening new large work). " +
		"Call it before a big step in a long task. After a compaction, usage reads as unknown until the next " +
		"model response, so call it again then to confirm the window is back inside the smart zone.",
	parameters: Type.Object({}),
	async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
		const config = loadConfig();
		const reading = read(ctx, config);
		const status = fuseStatus(ctx, config);
		const fuse = config.liveFuse ? fuseStatusNote(status, config) : fuseNote(reading, config.zones);
		const text =
			reading.zone === "unknown"
				? `${oneLine(reading)} — usage is unknown until the next model response (normal right after compaction); call ctx_status again after it. (${fuse}).`
				: `${oneLine(reading)} — ${advice(reading, config.zones)} (${fuse}).`;
		return { content: [{ type: "text", text }], details: { ...reading, zones: config.zones, fuse: status } };
	},
});

export default function (pi: ExtensionAPI): void {
	pi.registerTool(ctxStatusTool);

	// Live fuse 一定要喺第一個回合之前裝好 → extension 載入時即裝。
	const live = installLiveFuse();

	// Session 開始：自動把對齊值寫入 settings.json（per-model override）。
	// 令「改咗 config 但 settings.json 唔對齊」唔會再發生（下一個 session／reload 即生效）。
	pi.on("session_start", (_event, ctx) => {
		const config = loadConfig();
		autoSync(ctx, config);
	});

	// Inject the reading at the start of each run, but only once the window leaves the
	// smart zone: silence costs nothing, a warning costs a few tokens.
	pi.on("before_agent_start", (_event, ctx) => {
		const config = loadConfig();
		const reading = read(ctx, config);
		if (reading.zone === "smart" || reading.zone === "unknown") return;
		return {
			message: {
				customType: "dav-self-compact",
				display: false,
				content: `[dav-self-compact] ${oneLine(reading)} — ${advice(reading, config.zones)}.`,
			},
		};
	});

	// 跨過 20%／40%／60%（可設定）就印一次：使用率 ＋ zone ＋ 要做乜。
	// turn_end 係可掛 entry 嘅邊界：custom_message 會入下一輪 context，display:true 令
	// 人類喺 transcript 都見到（唔需要額外 renderer）。
	pi.on("turn_end", (_event, ctx) => {
		const config = loadConfig();
		const reading = read(ctx, config);
		const text = takeMilestone(config, reading);
		if (!text) return;
		if (ctx.hasUI) ctx.ui.notify(text, reading.zone === "smart" ? "info" : "warning");
		return {
			entries: [
				{
					type: "custom_message",
					customType: "dav-self-compact",
					content: text,
					display: true,
				},
			],
		};
	});

	// 換 session 就重新開始計里程碑（否則新 session 會漏通知）。
	pi.on("session_start", () => {
		resetMilestoneState_();
	});

	pi.registerCommand("ctx", {
		description: "Show context-window usage, zone and the action it demands (add --sync to re-align settings.json now)",
		handler: async (args, ctx) => {
			const config = loadConfig();
			const status = fuseStatus(ctx, config);
			const reading = read(ctx, config);
			const lines = [oneLine(reading), advice(reading, config.zones), config.liveFuse ? fuseStatusNote(status, config) : fuseNote(reading, config.zones)];
			if (String(args ?? "").includes("--sync")) {
				const sync = autoSync(ctx, config);
				lines.push(sync.changed ? `settings.json 已對齊（寫入完成）` : `settings.json 唔使改（${sync.reason}）`);
				if (!live.installed) lines.push(`⚠ live fuse 裝唔到（${live.reason}）→ 靠 settings.json 對齊`);
				ctx.ui.notify(lines.join("\n"), reading.zone === "smart" ? "info" : "warning");
				// reload 令 pi 即刻用返新值（settings 係 cache 咗，唔 reload 唔會生效）。
				// ⚠ reload 之後嘅 code 屬於舊 runtime → 唔好再當 ctx 仲有效（要 try/catch）。
				await ctx.reload();
				try {
					ctx.ui.notify("已 reload（fuse 即刻生效）", "info");
				} catch {
					// 舊 runtime 已失效 → 靜靜哋收工（寫檔已經成功）。
				}
				return;
			}
			if (!live.installed) lines.push(`⚠ live fuse 裝唔到（${live.reason}）→ 靠 settings.json 對齊`);
			ctx.ui.notify(lines.join("\n"), reading.zone === "smart" ? "info" : "warning");
		},
	});
}
