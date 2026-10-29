/**
 * settings.json 讀寫（原生保險絲嘅落地位）。
 *
 * 點解要有呢層：閾值嘅單一真相源係 ~/.pi/agent/dav-self-compact.json，但 pi 原生
 * 自動壓縮睇嘅係 settings.json 嘅 `compaction.reserveTokens`。兩邊人手同步就一定
 * 會漂移（改咗閾值、唔記得改 settings → fuse 98.4% 先開火 → hard block 先到）。
 *
 * 呢層做三件事：
 *   1. 讀出 pi 真正會用嘅 reserveTokens（跟足 pi 嘅覆蓋次序）
 *   2. 原子寫入 per-model override（compaction.modelOverrides["provider/modelId"]）
 *      —— per-model 先唔會污染窗口大小唔同嘅其他模型
 *   3. 寫入前留 .bak，寫入用 temp + rename（唔會寫壞 settings.json）
 *
 * 純 I/O，唔掂 pi API（可以獨立測試）。
 */

import { copyFileSync, existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";

export type CompactionSettingsFile = {
	reserveTokens?: number;
	keepRecentTokens?: number;
	enabled?: boolean;
	modelOverrides?: Record<string, { reserveTokens?: number; keepRecentTokens?: number }>;
};

export type SettingsFile = {
	compaction?: CompactionSettingsFile;
	[key: string]: unknown;
};

/** 讀 JSON；唔存在／壞 JSON → null（唔會令 session 死機）。 */
export function readJsonFile(path: string): SettingsFile | null {
	try {
		const parsed = JSON.parse(readFileSync(path, "utf8"));
		return typeof parsed === "object" && parsed !== null ? (parsed as SettingsFile) : null;
	} catch {
		return null;
	}
}

/**
 * pi 嘅覆蓋次序（跟 dist/core/settings-manager.js 一致）：
 *   project model override → global model override → project ordinary → global ordinary → 內建默認
 */
export function effectiveReserveTokens(
	globalSettings: SettingsFile | null,
	projectSettings: SettingsFile | null,
	modelKey: string,
	fallback: number,
): number {
	const candidates = [
		modelKey ? projectSettings?.compaction?.modelOverrides?.[modelKey]?.reserveTokens : undefined,
		modelKey ? globalSettings?.compaction?.modelOverrides?.[modelKey]?.reserveTokens : undefined,
		projectSettings?.compaction?.reserveTokens,
		globalSettings?.compaction?.reserveTokens,
	];
	for (const candidate of candidates) {
		if (typeof candidate === "number" && Number.isSafeInteger(candidate) && candidate >= 0) return candidate;
	}
	return fallback;
}

/**
 * 把對齊後嘅 reserveTokens 寫入一個「記憶體入面嘅 settings 物件」（pi 嘅 SettingsManager
 * `settings`／`globalSettings`）。
 *
 * 點解要：pi 嘅 settings 係 cache 咗嘅（改檔唔會即刻改記憶體）→ 其它讀設定嘅角色
 * （例如 dav-trust 嘅 fuse 審核、pi 自己下次存檔）會睇到舊值 → 誤報「fuse 太遲」。
 * 對齊記憶體 → 全個系統一致；pi 下次存檔亦會帶住呢個值（唔會還原我哋寫入嘅嘢）。
 */
export function alignSettingsObject(scope: SettingsFile | undefined, modelKey: string, reserveTokens: number): boolean {
	if (!scope || !modelKey) return false;
	const compaction = (scope.compaction ??= {}) as CompactionSettingsFile;
	const overrides = (compaction.modelOverrides ??= {});
	const entry = (overrides[modelKey] ??= {});
	if (entry.reserveTokens === reserveTokens) return false;
	entry.reserveTokens = reserveTokens;
	return true;
}

export type SyncResult = {
	ok: boolean;
	changed: boolean;
	previous: number | null;
	reason: string;
};

/**
 * 把對齊後嘅 reserveTokens 寫入 settings.json（per-model override）。
 * 已經係同一個值 → 唔寫（避免無謂改檔、避免同 pi 嘅存檔撞）。
 */
export function syncModelReserveTokens(
	settingsPath: string,
	modelKey: string,
	reserveTokens: number,
): SyncResult {
	if (!modelKey) return { ok: false, changed: false, previous: null, reason: "no-model-key" };
	const current = readJsonFile(settingsPath);
	if (!current) return { ok: false, changed: false, previous: null, reason: "unreadable-settings" };
	const overrides = current.compaction?.modelOverrides ?? {};
	const previous = overrides[modelKey]?.reserveTokens ?? current.compaction?.reserveTokens ?? null;
	if (previous === reserveTokens) return { ok: true, changed: false, previous, reason: "already-aligned" };

	const next: SettingsFile = {
		...current,
		compaction: {
			...current.compaction,
			modelOverrides: {
				...overrides,
				[modelKey]: { ...(overrides[modelKey] ?? {}), reserveTokens },
			},
		},
	};
	try {
		if (existsSync(settingsPath)) copyFileSync(settingsPath, `${settingsPath}.dav-self-compact.bak`);
		const tmp = `${settingsPath}.tmp-${process.pid}`;
		writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`, "utf8");
		renameSync(tmp, settingsPath);
		return { ok: true, changed: true, previous, reason: "written" };
	} catch (error) {
		return { ok: false, changed: false, previous, reason: `write-failed: ${error instanceof Error ? error.message : String(error)}` };
	}
}
