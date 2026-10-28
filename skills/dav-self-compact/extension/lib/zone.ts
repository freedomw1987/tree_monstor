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
	/** 機會窗口門檻（佔有效 context window 百分比）：細過 hard 但大過 soft */
	opportunityPercent: number;
	/** hard block 門檻（佔有效 context window 百分比） */
	hardPercent: number;
	/** 壓縮後建議落點下限（百分比） */
	targetMinPercent: number;
	/** 壓縮後建議落點上限（百分比） */
	targetPercent: number;
	/** 有效 window 的絕對上限（tokens）；0 = 只用百分比 */
	absoluteCapTokens: number;
	/** 使用率里程碑（%）：跨過就通知一次（默認 20／40／60） */
	noticePercents: number[];
};

export type Usage = {
	tokens: number | null;
	contextWindow: number;
	percent: number | null;
};

export type Reading = {
	zone: "smart" | "soft" | "opportunity" | "hard" | "unknown";
	action: "keep_working" | "prepare_then_compact" | "compact_at_boundary" | "compact_now" | "unknown";
	percent: number | null;
	tokens: number | null;
	contextWindow: number;
	effectiveWindow: number;
	softTokens: number;
	opportunityTokens: number;
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
	opportunityPercent: 55,
	hardPercent: 60,
	targetMinPercent: 20,
	targetPercent: 35,
	absoluteCapTokens: 0,
	noticePercents: [20, 40, 60],
};

/** pi 未設 compaction.reserveTokens 時嘅內建默認值。 */
export const FALLBACK_RESERVE_TOKENS = 16384;

function num(value: unknown, fallback: number, min: number, max: number): number {
	if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
	if (value < min || value > max) return fallback;
	return value;
}

/** 把設定檔（可能係壞 JSON 或缺欄位）夾成合法 Zones。 */
/** 里程碑清單：只收 1..100 嘅有限數，去重後升序（唔合法 → 用默認）。 */
function noticeList(value: unknown): number[] {
	if (!Array.isArray(value)) return [...DEFAULT_ZONES.noticePercents];
	const cleaned = [...new Set(value.filter((n): n is number => typeof n === "number" && Number.isFinite(n) && n >= 1 && n <= 100))].sort(
		(a, b) => a - b,
	);
	return cleaned.length > 0 ? cleaned : [...DEFAULT_ZONES.noticePercents];
}

export function normalizeZones(raw: unknown): Zones {
	const parsed = (typeof raw === "object" && raw !== null ? raw : {}) as Partial<Zones>;
	const softPercent = num(parsed.softPercent, DEFAULT_ZONES.softPercent, 1, 100);
	const hardPercent = num(parsed.hardPercent, DEFAULT_ZONES.hardPercent, 1, 100);
	// 機會窗口必須落喺 (soft, hard] 之內：細過 soft 會同 soft 重疊，大過 hard 就永遠追唔到。
	const rawOpportunity = num(parsed.opportunityPercent, DEFAULT_ZONES.opportunityPercent, 1, 100);
	return {
		softPercent,
		hardPercent,
		opportunityPercent: Math.min(Math.max(rawOpportunity, softPercent + 1), hardPercent),
		targetMinPercent: num(parsed.targetMinPercent, DEFAULT_ZONES.targetMinPercent, 0, 100),
		targetPercent: num(parsed.targetPercent, DEFAULT_ZONES.targetPercent, 1, 100),
		absoluteCapTokens: num(parsed.absoluteCapTokens, DEFAULT_ZONES.absoluteCapTokens, 0, 100_000_000),
		noticePercents: noticeList(parsed.noticePercents),
	};
}

/** 人話 zone 標籤（用戶要求見到 normal／soft block／hard block）。 */
export function zoneLabel(zone: Reading["zone"]): string {
	switch (zone) {
		case "smart":
			return "normal";
		case "soft":
			return "soft block";
		case "opportunity":
			return "opportunity window";
		case "hard":
			return "hard block";
		default:
			return "unknown";
	}
}

/**
 * 跨過里程碑嘅判定（純函數）：回傳今次應該通知嘅里程碑（一次最多一個 = 最高嗰個），
 * 同更新後嘅已通知集合。`percent === null`（剛壓縮完）唔會改動狀態。
 */
export function nextNotice(
	percent: number | null,
	noticePercents: number[],
	announced: ReadonlySet<number>,
): { notice: number | null; announced: Set<number> } {
	const kept = new Set(announced);
	if (percent === null) return { notice: null, announced: kept };
	const pending = noticePercents.filter((m) => percent >= m && !kept.has(m));
	if (pending.length === 0) return { notice: null, announced: kept };
	for (const m of pending) kept.add(m);
	return { notice: pending[pending.length - 1] ?? null, announced: kept };
}

/** 壓縮後使用率大跌 → 清掉已通知集合，之後再跨過里程碑要再通知。 */
export function shouldResetNotices(previousPercent: number | null, percent: number | null): boolean {
	if (previousPercent === null || percent === null) return false;
	return percent < previousPercent * 0.6;
}

/** 里程碑訊息（跨過門檻嗰一刻印出：使用率 ＋ zone ＋ 要做乜）。 */
export function milestoneText(r: Reading, zones: Zones, notice: number): string {
	const denominator = r.effectiveWindow > 0 && r.effectiveWindow < r.contextWindow ? r.effectiveWindow : r.contextWindow;
	return (
		`[dav-self-compact] ctx ${pct(r.percent)} just crossed ${notice}% — ` +
		`${k(r.tokens)}/${k(denominator)} tokens${denominator !== r.contextWindow ? ` (window ${k(r.contextWindow)})` : ""} · ` +
		`zone=${r.zone} (${zoneLabel(r.zone)}) · action=${r.action} · soft=${k(r.softTokens)} win=${k(r.opportunityTokens)} hard=${k(r.hardTokens)}` +
		` — ${advice(r, zones)}.`
	);
}

export function computeReading(usage: Usage | undefined, reserveTokens: number, zones: Zones): Reading {
	const contextWindow = usage?.contextWindow ?? 0;
	const effectiveWindow =
		zones.absoluteCapTokens > 0
			? Math.min(contextWindow > 0 ? contextWindow : zones.absoluteCapTokens, zones.absoluteCapTokens)
			: contextWindow;
	const softTokens = Math.floor((effectiveWindow * zones.softPercent) / 100);
	const opportunityTokens = Math.floor((effectiveWindow * zones.opportunityPercent) / 100);
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
		opportunityTokens,
		hardTokens,
		nativeTriggerPercent: nativeTriggerTokens !== null ? (nativeTriggerTokens / contextWindow) * 100 : null,
		nativeTriggerTokens,
		// 目標：fuse 喺「機會窗口」內開火，唔好等到 hard 之後才被迫壓縮。
		// trigger <= 0 代表 reserveTokens >= contextWindow（病態設定，每輪都會壓縮）→ 唔算 OK。
		nativeFuseOk:
			nativeTriggerTokens !== null &&
			nativeTriggerTokens > 0 &&
			nativeTriggerTokens <= opportunityTokens &&
			nativeTriggerTokens > softTokens,
	};
	if (!usage || contextWindow <= 0 || tokens === null) return base;
	const percent = effectiveWindow > 0 ? (tokens / effectiveWindow) * 100 : null;
	const zone =
		tokens >= hardTokens
			? "hard"
			: tokens >= opportunityTokens
				? "opportunity"
				: tokens >= softTokens
					? "soft"
					: "smart";
	const action =
		zone === "hard"
			? "compact_now"
			: zone === "opportunity"
				? "compact_at_boundary"
				: zone === "soft"
					? "prepare_then_compact"
					: "keep_working";
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
		`soft=${k(r.softTokens)} win=${k(r.opportunityTokens)} hard=${k(r.hardTokens)}`,
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
		return (
			`native auto-compaction fires at ${pct(r.nativeTriggerPercent)} (${k(r.nativeTriggerTokens)} tokens) = inside the opportunity window`
		);
	}
	const reserve = Math.round(r.contextWindow - r.opportunityTokens);
	const late = r.nativeTriggerTokens > r.opportunityTokens;
	return (
		`⚠ native auto-compaction fires at ${pct(r.nativeTriggerPercent)} (${k(r.nativeTriggerTokens)} tokens) — ` +
		`${late ? "too late (hard block is " + k(r.hardTokens) + " tokens)" : "too early (soft block is " + k(r.softTokens) + " tokens)"}; ` +
		`set compaction.reserveTokens=${reserve} to fire inside the opportunity window (${k(r.opportunityTokens)} tokens)`
	);
}

export function advice(r: Reading, zones: Zones): string {
	if (r.zone === "hard") {
		return (
			"PAST the deadline: stop opening new work, finish the current atomic step, write the handoff note, and let " +
			"compaction happen (the fuse should have fired earlier — report the late trigger if you see this)"
		);
	}
	if (r.zone === "opportunity") {
		return (
			"this is the window to compact: pick the best boundary now (atomic step done, tests green, files written), " +
			"refresh the handoff note, then let the fuse fire on it — in an interactive session ask the user to run /compact here"
		);
	}
	if (r.zone === "soft") {
		return (
			"write the handoff note now (done / next / key paths) and keep every step small, so any later compaction lands " +
			`in ${zones.targetMinPercent}%-${zones.targetPercent}% — the opportunity window opens at ${zones.opportunityPercent}%`
		);
	}
	return "keep working; no action needed";
}
