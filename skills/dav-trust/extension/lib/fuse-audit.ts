/**
 * dav-trust 嘅 fuse 審核（純函數、無 I/O）。
 *
 * 為什麼：trust mode 嘅前提係「壓縮會自己發生」。pi 只會喺
 * `contextTokens > contextWindow − reserveTokens` 時自動壓縮，而 agent **冇手掣**
 * 可以自己壓 —— 所以 fuse 設得太遲 = 到 hard block 都冇人壓，一路撐到 overflow。
 * 呢支函數就係喺 trust 啟動／每輪驗一次，唔對就即刻叫。
 *
 * 門檻契約同 `dav-self-compact` skill 一致（soft／opportunity／hard 三段 ＋
 * `absoluteCapTokens` 絕對上限），呢邊只讀同一份 `~/.pi/agent/dav-self-compact.json`。
 */

export type TrustZones = {
	softPercent: number;
	opportunityPercent: number;
	hardPercent: number;
	absoluteCapTokens: number;
};

export const DEFAULT_TRUST_ZONES: TrustZones = {
	softPercent: 50,
	opportunityPercent: 55,
	hardPercent: 60,
	absoluteCapTokens: 0,
};

export const FALLBACK_RESERVE_TOKENS = 16384;

function clampPercent(value: unknown, fallback: number): number {
	if (typeof value !== "number" || !Number.isFinite(value) || value < 1 || value > 100) return fallback;
	return value;
}

/** 讀 `~/.pi/agent/dav-self-compact.json` 出嚟嘅原始物件 → 合法門檻（壞值用默認）。 */
export function normalizeTrustZones(raw: unknown): TrustZones {
	const parsed = (typeof raw === "object" && raw !== null ? raw : {}) as Partial<TrustZones>;
	const softPercent = clampPercent(parsed.softPercent, DEFAULT_TRUST_ZONES.softPercent);
	const hardPercent = clampPercent(parsed.hardPercent, DEFAULT_TRUST_ZONES.hardPercent);
	const opportunityPercent = clampPercent(parsed.opportunityPercent, DEFAULT_TRUST_ZONES.opportunityPercent);
	const cap =
		typeof parsed.absoluteCapTokens === "number" && Number.isFinite(parsed.absoluteCapTokens) && parsed.absoluteCapTokens >= 0
			? parsed.absoluteCapTokens
			: DEFAULT_TRUST_ZONES.absoluteCapTokens;
	return {
		softPercent,
		hardPercent,
		// 同 dav-self-compact 一樣：機會窗口必須落喺 (soft, hard]
		opportunityPercent: Math.min(Math.max(opportunityPercent, softPercent + 1), hardPercent),
		absoluteCapTokens: cap,
	};
}

/**
 * pi settings 嘅 compaction 段 → 目前 model 嘅 reserveTokens
 * （project model override → user model override → project → user → pi 默認）。
 */
export function resolveReserveTokens(
	compaction: { reserveTokens?: unknown; modelOverrides?: Record<string, { reserveTokens?: unknown }> } | undefined,
	modelKey: string | undefined,
	userCompaction?: { reserveTokens?: unknown; modelOverrides?: Record<string, { reserveTokens?: unknown }> },
): number {
	const pick = (value: unknown): number | undefined =>
		typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : undefined;
	const candidates = [
		modelKey ? pick(compaction?.modelOverrides?.[modelKey]?.reserveTokens) : undefined,
		modelKey ? pick(userCompaction?.modelOverrides?.[modelKey]?.reserveTokens) : undefined,
		pick(compaction?.reserveTokens),
		pick(userCompaction?.reserveTokens),
	];
	for (const candidate of candidates) if (candidate !== undefined) return candidate;
	return FALLBACK_RESERVE_TOKENS;
}

export type FuseAudit = {
	contextWindow: number;
	effectiveWindow: number;
	softTokens: number;
	opportunityTokens: number;
	hardTokens: number;
	triggerTokens: number;
	/** fuse 係唔係喺機會窗口內開火（soft < trigger <= opportunity） */
	ok: boolean;
	/** true = 太遲（會一路撐到 hard 之後） */
	tooLate: boolean;
	/** true = 太早（未離開聰明區就壓） */
	tooEarly: boolean;
	/** 想 fuse 落喺機會窗口，reserveTokens 應該設幾多 */
	reserveNeeded: number;
};

export function auditFuse(contextWindow: number, reserveTokens: number, zones: TrustZones): FuseAudit {
	const effectiveWindow =
		zones.absoluteCapTokens > 0 && contextWindow > 0
			? Math.min(contextWindow, zones.absoluteCapTokens)
			: zones.absoluteCapTokens > 0
				? zones.absoluteCapTokens
				: contextWindow;
	const softTokens = Math.floor((effectiveWindow * zones.softPercent) / 100);
	const opportunityTokens = Math.floor((effectiveWindow * zones.opportunityPercent) / 100);
	const hardTokens = Math.floor((effectiveWindow * zones.hardPercent) / 100);
	const triggerTokens = contextWindow - reserveTokens;
	return {
		contextWindow,
		effectiveWindow,
		softTokens,
		opportunityTokens,
		hardTokens,
		triggerTokens,
		ok: triggerTokens > softTokens && triggerTokens <= opportunityTokens,
		tooLate: triggerTokens > opportunityTokens,
		tooEarly: triggerTokens <= softTokens,
		reserveNeeded: contextWindow - opportunityTokens,
	};
}

/** 被擋／提示用嘅文字：一定要同時講「數字」同「點修」。 */
export function fuseAuditText(audit: FuseAudit, zones: TrustZones): string {
	if (audit.ok) {
		return `fuse OK: auto-compaction fires at ${audit.triggerTokens} tokens (opportunity window ${audit.opportunityTokens})`;
	}
	return (
		`⚠ trust mode fuse problem: auto-compaction fires at ${audit.triggerTokens} tokens — ` +
		`${audit.tooLate ? "TOO LATE (hard deadline is " + audit.hardTokens + " tokens)" : "too early (smart zone ends at " + audit.softTokens + " tokens)"}. ` +
		`The agent cannot compact by itself, so nothing would compact before the hard block. ` +
		`Fix: set ~/.pi/agent/settings.json → compaction.modelOverrides["<provider>/<model>"].reserveTokens = ${audit.reserveNeeded} ` +
		`(or compaction.reserveTokens = ${audit.reserveNeeded} for one model), then restart pi.`
	);
}
