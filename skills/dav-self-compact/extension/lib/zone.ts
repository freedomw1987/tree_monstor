/**
 * dav-self-compact 嘅純計算層（無 I/O、無 pi API）—— 方便用單元測試鎖住關鍵數字。
 *
 * 三個關鍵數字必須一致：
 *   softTokens      = 有效窗口 × softPercent
 *   hardTokens      = 有效窗口 × hardPercent
 *   nativeTriggerTokens = contextWindow − reserveTokens（pi 原生自動壓縮幾時開火）
 * 判定 fuse 夠唔夠早，要用 tokens 比（唔係百分比），因為設咗 absoluteCapTokens 之後
 * hard block 係絕對 token 數。
 */

export type Zones = {
	/** soft block 門檻（佔有效 context window 百分比） */
	softPercent: number;
	/** hard block 門檻（佔有效 context window 百分比） */
	hardPercent: number;
	/** 壓縮後建議落點下限（百分比） */
	targetMinPercent: number;
	/** 壓縮後建議落點上限（百分比） */
	targetPercent: number;
	/** 有效 window 的絕對上限（tokens）；0 = 只用百分比 */
	absoluteCapTokens: number;
};

export type Usage = {
	tokens: number | null;
	contextWindow: number;
	percent: number | null;
};

export type Reading = {
	zone: "smart" | "soft" | "hard" | "unknown";
	action: "keep_working" | "prepare_then_compact" | "compact_now" | "unknown";
	percent: number | null;
	tokens: number | null;
	contextWindow: number;
	effectiveWindow: number;
	softTokens: number;
	hardTokens: number;
	/** 原生自動壓縮嘅觸發點（% of window） */
	nativeTriggerPercent: number | null;
	/** 原生自動壓縮嘅觸發點（tokens） */
	nativeTriggerTokens: number | null;
	/** 原生 fuse 係唔係喺 hard block 之前生效 */
	nativeFuseOk: boolean;
};

export const DEFAULT_ZONES: Zones = {
	softPercent: 50,
	hardPercent: 60,
	targetMinPercent: 20,
	targetPercent: 35,
	absoluteCapTokens: 0,
};

/** pi 未設 compaction.reserveTokens 時嘅內建默認值。 */
export const FALLBACK_RESERVE_TOKENS = 16384;

function num(value: unknown, fallback: number, min: number, max: number): number {
	if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
	if (value < min || value > max) return fallback;
	return value;
}

/** 把設定檔（可能係壞 JSON 或缺欄位）夾成合法 Zones。 */
export function normalizeZones(raw: unknown): Zones {
	const parsed = (typeof raw === "object" && raw !== null ? raw : {}) as Partial<Zones>;
	return {
		softPercent: num(parsed.softPercent, DEFAULT_ZONES.softPercent, 1, 100),
		hardPercent: num(parsed.hardPercent, DEFAULT_ZONES.hardPercent, 1, 100),
		targetMinPercent: num(parsed.targetMinPercent, DEFAULT_ZONES.targetMinPercent, 0, 100),
		targetPercent: num(parsed.targetPercent, DEFAULT_ZONES.targetPercent, 1, 100),
		absoluteCapTokens: num(parsed.absoluteCapTokens, DEFAULT_ZONES.absoluteCapTokens, 0, 100_000_000),
	};
}

export function computeReading(usage: Usage | undefined, reserveTokens: number, zones: Zones): Reading {
	const contextWindow = usage?.contextWindow ?? 0;
	const effectiveWindow =
		zones.absoluteCapTokens > 0
			? Math.min(contextWindow > 0 ? contextWindow : zones.absoluteCapTokens, zones.absoluteCapTokens)
			: contextWindow;
	const softTokens = Math.floor((effectiveWindow * zones.softPercent) / 100);
	const hardTokens = Math.floor((effectiveWindow * zones.hardPercent) / 100);
	const tokens = usage?.tokens ?? null;
	const nativeTriggerTokens = contextWindow > 0 ? contextWindow - reserveTokens : null;
	const base: Reading = {
		zone: "unknown",
		action: "unknown",
		percent: usage?.percent ?? null,
		tokens,
		contextWindow,
		effectiveWindow,
		softTokens,
		hardTokens,
		nativeTriggerPercent: nativeTriggerTokens !== null ? (nativeTriggerTokens / contextWindow) * 100 : null,
		nativeTriggerTokens,
		// trigger <= 0 代表 reserveTokens >= contextWindow（病態設定，每輪都會壓縮）→ 唔算 OK。
		nativeFuseOk: nativeTriggerTokens !== null && nativeTriggerTokens > 0 && nativeTriggerTokens <= hardTokens,
	};
	if (!usage || contextWindow <= 0 || tokens === null) return base;
	const percent = effectiveWindow > 0 ? (tokens / effectiveWindow) * 100 : null;
	const zone = tokens >= hardTokens ? "hard" : tokens >= softTokens ? "soft" : "smart";
	const action = zone === "hard" ? "compact_now" : zone === "soft" ? "prepare_then_compact" : "keep_working";
	return { ...base, zone, action, percent };
}

export function k(n: number | null): string {
	if (n === null) return "?";
	return n >= 1000 ? `${Math.round(n / 1000)}k` : String(n);
}

export function pct(n: number | null): string {
	return n === null ? "?" : `${n.toFixed(1)}%`;
}

export function oneLine(r: Reading): string {
	const capped = r.effectiveWindow > 0 && r.effectiveWindow < r.contextWindow;
	const denominator = capped ? r.effectiveWindow : r.contextWindow;
	return [
		`ctx ${pct(r.percent)} (${k(r.tokens)}/${k(denominator)} tokens${capped ? `, window ${k(r.contextWindow)}` : ""})`,
		`zone=${r.zone}`,
		`action=${r.action}`,
		`soft=${k(r.softTokens)} hard=${k(r.hardTokens)}`,
	].join(" · ");
}

export function fuseNote(r: Reading, zones: Zones): string {
	if (r.nativeTriggerPercent === null || r.nativeTriggerTokens === null) return "";
	if (r.nativeTriggerTokens <= 0) {
		return (
			`⚠ compaction.reserveTokens is larger than the context window — pi would compact on every turn. ` +
			`Set it to ${Math.round(r.contextWindow - r.hardTokens)} (or a per-model override)`
		);
	}
	if (r.nativeFuseOk) {
		return `native auto-compaction fires at ${pct(r.nativeTriggerPercent)} (${k(r.nativeTriggerTokens)} tokens) = hard block`;
	}
	const reserve = Math.round(r.contextWindow - r.hardTokens);
	return (
		`⚠ native auto-compaction only fires at ${pct(r.nativeTriggerPercent)} (${k(r.nativeTriggerTokens)} tokens) — ` +
		`set compaction.reserveTokens=${reserve} (or a per-model override) to make it fire at the hard block (${k(r.hardTokens)} tokens)`
	);
}

export function advice(r: Reading, zones: Zones): string {
	if (r.zone === "hard") {
		return (
			"do not start a new large read or wide refactor; finish the current atomic step, write the handoff note " +
			"to disk, and let compaction happen (pi compacts mid-run at this level, or the user runs /compact)"
		);
	}
	if (r.zone === "soft") {
		return (
			"write the handoff note now (done / next / key paths) and keep the next steps small so the " +
			`post-compaction reading lands in ${zones.targetMinPercent}%-${zones.targetPercent}%`
		);
	}
	return "keep working; no action needed";
}
