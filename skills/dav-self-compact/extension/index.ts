/**
 * dav-self-compact — context 壓力錶 ＋ 聰明區守門。
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
 * 「有效 window」= min(contextWindow, absoluteCapTokens)；absoluteCapTokens > 0 時，
 * 1M window 模型嘅 50% 唔會等於 50 萬 tokens（實際上早已唔聰明）。
 *
 * 壓縮本身唔由本 extension 觸發：pi 1.4.0 嘅 compact() 會先 abort 當前 run，喺 tool
 * call 內觸發會連 summarization 一齊被 abort（實測失敗）。真正嘅硬保險絲係 pi 原生
 * 自動壓縮（settings `compaction.reserveTokens`，喺 run 中途 prepareNextTurn 觸發並
 * 繼續跑）。本 extension 負責「量度 ＋ 提醒 ＋ 審核保險絲設定」。
 *
 * 純計算（zone／fuse／文字）喺 ./lib/zone.ts —— 無 I/O、可獨立單元測試。
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	advice,
	computeReading,
	DEFAULT_ZONES,
	FALLBACK_RESERVE_TOKENS,
	fuseNote,
	normalizeZones,
	oneLine,
	type Reading,
	type Zones,
} from "./lib/zone.ts";

const CONFIG_PATH = join(homedir(), ".pi", "agent", "dav-self-compact.json");

/** 讀閾值設定檔；唔存在／壞 JSON → 用默認值（唔會令 session 死機）。 */
function loadZones(): Zones {
	try {
		return normalizeZones(JSON.parse(readFileSync(CONFIG_PATH, "utf8")));
	} catch {
		return { ...DEFAULT_ZONES };
	}
}

/** pi 原生自動壓縮嘅 reserveTokens（settings: project model override → global model override → project → global → 默認）。 */
function readReserveTokens(ctx: ExtensionContext): number {
	const read = (path: string): Record<string, unknown> | null => {
		try {
			return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
		} catch {
			return null;
		}
	};
	const compactionOf = (settings: Record<string, unknown> | null) =>
		settings?.compaction as
			| { reserveTokens?: unknown; modelOverrides?: Record<string, { reserveTokens?: unknown }> }
			| undefined;
	const globalSettings = compactionOf(read(join(homedir(), ".pi", "agent", "settings.json")));
	const projectSettings = compactionOf(read(join(ctx.cwd, ".pi", "settings.json")));
	const key = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "";
	// pi merges settings as global ← project (project wins), then
	// override ?? ordinary ?? default. Match that order exactly, otherwise this
	// fuse audit reports a value pi is not actually using.
	const candidates = [
		key ? projectSettings?.modelOverrides?.[key]?.reserveTokens : undefined,
		key ? globalSettings?.modelOverrides?.[key]?.reserveTokens : undefined,
		projectSettings?.reserveTokens,
		globalSettings?.reserveTokens,
	];
	for (const candidate of candidates) {
		if (typeof candidate === "number" && Number.isSafeInteger(candidate) && candidate >= 0) return candidate;
	}
	return FALLBACK_RESERVE_TOKENS;
}

function read(ctx: ExtensionContext, zones: Zones): Reading {
	return computeReading(ctx.getContextUsage(), readReserveTokens(ctx), zones);
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
		const zones = loadZones();
		const reading = read(ctx, zones);
		const fuse = fuseNote(reading, zones);
		const text =
			reading.zone === "unknown"
				? `${oneLine(reading)} — usage is unknown until the next model response (normal right after compaction); call ctx_status again after it.${fuse ? ` ${fuse}.` : ""}`
				: `${oneLine(reading)} — ${advice(reading, zones)}${fuse ? ` (${fuse}).` : ""}`;
		return { content: [{ type: "text", text }], details: { ...reading, zones } };
	},
});

export default function (pi: ExtensionAPI): void {
	pi.registerTool(ctxStatusTool);

	// Inject the reading at the start of each run, but only once the window leaves the
	// smart zone: silence costs nothing, a warning costs a few tokens.
	pi.on("before_agent_start", (_event, ctx) => {
		const zones = loadZones();
		const reading = read(ctx, zones);
		if (reading.zone === "smart" || reading.zone === "unknown") return;
		return {
			message: {
				customType: "dav-self-compact",
				display: false,
				content: `[dav-self-compact] ${oneLine(reading)} — ${advice(reading, zones)}.`,
			},
		};
	});

	pi.registerCommand("ctx", {
		description: "Show context-window usage, zone and the action it demands",
		handler: async (_args, ctx) => {
			const zones = loadZones();
			const reading = read(ctx, zones);
			const fuse = fuseNote(reading, zones);
			const lines = [oneLine(reading), advice(reading, zones)];
			if (fuse) lines.push(fuse);
			ctx.ui.notify(lines.join("\n"), reading.zone === "smart" ? "info" : "warning");
		},
	});
}
