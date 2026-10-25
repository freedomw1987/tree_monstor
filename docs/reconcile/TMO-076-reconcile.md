# TMO-076 需求對帳表

> 對帳者: `reviewer` subagent（Gate 4.5 獨立對帳者，**未參與實作**）| 對帳時間: 2026-10-26
> 錨點: docs/req/TMO-076-requirement.md
> 覆蓋率: **4/4**
> 對帳者獨立性: 非降級路徑（未參與本次實作）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | `AGENTS.md` 不再內嵌 SOP，且沒有指向舊 §2 的 live 引用 | ✅ 已實作 | `AGENTS.md`（121 → 35 行）| `tests/agents-md.bats` TD-017 AC-1/AC-2；17 個檔案（12 處直接指名）已修 | 歷史 CHANGELOG 的提及刻意保留 |
| R2 | 預設不再強制跑流程 | ✅ 已實作 | `AGENTS.md` 開頭說明段 | 明示「沒有指定 Gate 時預設直接做」＋三種升級條件 | 舊 §2.0 分流表退場（已於交付摘要 §5 揭露）|
| R3 | 每道 Gate 定義落在承載它的 skill，且與 `gates.json` 一致 | ✅ 已實作 | 4 支 skill 的「## Gate 定義」段 | `tests/gate-in-skill.bats` GATE-SKILL-1/2/4（逐條比對＋比對器自證）| Gate 4.5 的 single source 是 handbook 2.3 |
| R4 | SOP 本體全部原地保留 | ✅ 已實作 | `docs/sop/handbook/`、`gates.json`、SOP 階段 skill、`lib/install/sop.sh` | 本次 diff 無任何刪除檔（`git diff --diff-filter=D --name-only` 為空）| 本次是搬移不是刪除 |

## 結論

- 4 項已實作、0 項部分實作、0 項未實作。覆蓋率 **4/4**（100%）。
- 本次為**規範層搬移**：SOP 從「每次都被讀的 AGENTS.md」移到「被觸發時才讀的 skill」，
  機制本體（handbook / gates.json / install）一件未刪。
