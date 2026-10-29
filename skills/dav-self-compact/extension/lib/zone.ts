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

/** fuse 對齊狀態：觸發點同機會窗口嘅關係。 */
export type FuseAlignment = "aligned" | "too_late" | "too_early" | "invalid" | "unknown";

export type FusePlan = {
	alignment: FuseAlignment;
	/** 原生觸發點（tokens）；null = 窗口未知 */
	triggerTokens: number | null;
	/** 原生觸發點佔窗口百分比 */
	triggerPercent: number | null;
	/** 目標 reserveTokens（觸發點 = opportunityTokens）；null = 計唔到 */
	desiredReserveTokens: number | null;
};

/** 設定檔加埋兩個開關（單一真相源嘅延伸）。 */
export type Config = {
	zones: Zones;
	/** 即時對齊 fuse（patch pi 嘅門檻查詢 → 改 config 即時生效，唔使 reload） */
	liveFuse: boolean;
	/** 自動把對齊後嘅 reserveTokens 寫返 settings.json（per-model override） */
	autoSyncSettings: boolean;
};

export const DEFAULT_CONFIG: Config = {
	zones: DEFAULT_ZONES,
	liveFuse: true,
	autoSyncSettings: true,
};

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

/** 讀完整設定檔（閾值 + 兩個開關）；壞檔 → 默認值。 */
export function normalizeConfig(raw: unknown): Config {
	const parsed = (typeof raw === "object" && raw !== null ? raw : {}) as Partial<Config> & Partial<Zones>;
	const bool = (value: unknown, fallback: boolean): boolean => (typeof value === "boolean" ? value : fallback);
	return {
		zones: normalizeZones(parsed),
		liveFuse: bool(parsed.liveFuse, DEFAULT_CONFIG.liveFuse),
		autoSyncSettings: bool(parsed.autoSyncSettings, DEFAULT_CONFIG.autoSyncSettings),
	};
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

/**
 * 目標 reserveTokens：令原生觸發點（contextWindow − reserveTokens）啱啱好落喺機會窗口。
 * 計唔到（窗口未知／細到無嘢可壓）→ null（保持 pi 原本嘅值）。
 */
export function desiredReserveTokens(contextWindow: number, zones: Zones): number | null {
	if (!Number.isFinite(contextWindow) || contextWindow <= 0) return null;
	const effectiveWindow =
		zones.absoluteCapTokens > 0 ? Math.min(contextWindow, zones.absoluteCapTokens) : contextWindow;
	const opportunityTokens = Math.floor((effectiveWindow * zones.opportunityPercent) / 100);
	if (opportunityTokens <= 0) return null;
	const desired = Math.round(contextWindow - opportunityTokens);
	if (desired <= 0 || desired >= contextWindow) return null;
	return desired;
}

/** 計 fuse 現況：觸發點喺邊、同目標差幾遠。 */
export function fusePlan(contextWindow: number, effectiveReserveTokens: number, zones: Zones): FusePlan {
	const desired = desiredReserveTokens(contextWindow, zones);
	if (!Number.isFinite(contextWindow) || contextWindow <= 0) {
		return { alignment: "unknown", triggerTokens: null, triggerPercent: null, desiredReserveTokens: desired };
	}
	const triggerTokens = contextWindow - effectiveReserveTokens;
	const effectiveWindow =
		zones.absoluteCapTokens > 0 ? Math.min(contextWindow, zones.absoluteCapTokens) : contextWindow;
	const softTokens = Math.floor((effectiveWindow * zones.softPercent) / 100);
	const opportunityTokens = Math.floor((effectiveWindow * zones.opportunityPercent) / 100);
	const alignment: FuseAlignment =
		triggerTokens <= 0 ? "invalid" : triggerTokens > opportunityTokens ? "too_late" : triggerTokens <= softTokens ? "too_early" : "aligned";
	return {
		alignment,
		triggerTokens,
		triggerPercent: (triggerTokens / contextWindow) * 100,
		desiredReserveTokens: desired,
	};
}

/**
 * live fuse 嘅純邏輯：pi 每個回合問「幾時壓縮」時，用呢個函數改寫門檻。
 *   - 已經喺 (soft, opportunity] 窗口內 → 唔郁（尊重人手調過嘅值）
 *   - 太遲（預設 16384 → 98.4% 先壓）→ 改成目標值
 *   - 太早 → 改成目標值（避免過度壓縮）
 *   - 目標值會令「冇嘢可壓」（opportunity ≤ keepRecentTokens）→ 唔改
 */
export function applyLiveFuse(
	settings: { reserveTokens: number; keepRecentTokens: number },
	contextWindow: number,
	zones: Zones,
): { reserveTokens: number; keepRecentTokens: number; changed: boolean; reason: string } {
	const keep = { ...settings };
	const desired = desiredReserveTokens(contextWindow, zones);
	if (desired === null) return { ...keep, changed: false, reason: "no-target" };
	const effectiveWindow =
		zones.absoluteCapTokens > 0 ? Math.min(contextWindow, zones.absoluteCapTokens) : contextWindow;
	const opportunityTokens = Math.floor((effectiveWindow * zones.opportunityPercent) / 100);
	if (opportunityTokens <= settings.keepRecentTokens) {
		return { ...keep, changed: false, reason: "keep-recent-too-big" };
	}
	const plan = fusePlan(contextWindow, settings.reserveTokens, zones);
	if (plan.alignment === "aligned") return { ...keep, changed: false, reason: "aligned" };
	return { reserveTokens: desired, keepRecentTokens: settings.keepRecentTokens, changed: true, reason: plan.alignment };
}

/**
 * 強制壓縮用嘅 reserveTokens：令門檻即刻跨過（觸發點 = 0 tokens）。
 * 用喺「agent 主動要求壓縮」：pi 喺下一個安全邊界（工具批次完、下一個 assistant 回應之前）
 * 見到門檻已跨 → 用**原生**路徑壓縮 → 唔 abort、壓完繼續跑（唔會停低）。
 */
export function forcedReserveTokens(contextWindow: number): number {
	if (!Number.isFinite(contextWindow) || contextWindow <= 0) return 0;
	return Math.round(contextWindow);
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
