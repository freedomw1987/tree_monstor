# 交付 — dav-self-compact（context 聰明區治理 skill ＋ extension）

> **交付日期**: 2026-10-29
> **對應 Backlog**: 無票（用戶直接對話指派；未經 `dav-planner` 建 US，屬流程偏差，見 §5）
> **交付狀態**: ✅ 完成（Gate 4 ＋ Gate 4.5 由獨立 subagent 完成；7/7 需求覆蓋，R1／R4 缺口已於第二輪補齊）

## 1. 這次完成什麼

用戶想要一個 skill，令 AI Agent 同 subagent 長期留喺 context window 嘅「聰明區」（<50% 使用率），
並且可以處理 long-running 長任務。經實測後落地為 **skill（紀律）＋ extension（量尺／提醒／保險絲審核）**：

- ✅ `skills/dav-self-compact/`：`SKILL.md`（46 行）＋ `protocol.md`（78）＋ `reference.md`（63）＋ `setup.md`（71）＝ context 258 行
- ✅ `skills/dav-self-compact/extension/`：`index.ts`（`ctx_status` 工具、每輪 run 開始自動注入 zone 提示（smart 區靜默）、`/ctx` 指令、原生保險絲審核）＋ `lib/zone.ts`（純計算層，可獨立單元測試）
- ✅ `skills/dav-self-compact/tests/zone.bats`：9 條單元測試鎖住軟／硬門檻（100k／120k）、fuse 觸發點（120k）、病態設定（reserve ≥ window）、壓縮後 `percent=null`
- ✅ `install.sh` ＋ `lib/install/agents.sh`：新增 `install_pi_extensions`／`uninstall_pi_extensions`（skill 內附 extension 自動裝卸，唔會誤刪用戶自己嘅 extension）
- ✅ 本機設定對齊：`compaction.modelOverrides.reserveTokens=880000`（三個 1M 模型）、`subagents.defaultSubagentOnlyExtensions`、`~/.pi/agent/dav-self-compact.json`（`absoluteCapTokens: 200000`）
- ✅ `skills/dav-trust/long-run-context.md`（新子檔）：trust mode 長跑嘅 context 紀律（3 個量度 checkpoint、checkpoint 格式、壓縮後續跑、subagent 派工）
- ✅ `AGENTS.md` 加 **V04 長跑必守聰明區**（把「派長工要帶 skill ＋ 寫 checkpoint」變成每次載入嘅硬規則）
- ✅ Gate 4（品質審核）＋ Gate 4.5（需求對帳）由獨立 subagent 完成；F1–F7 全部處理

**關鍵數字（本機設定）**：有效窗口 200k → soft 100k（50%）／hard 120k（60%）；原生自動壓縮觸發點 `1,000,000 − 880,000 = 120,000` ＝ hard block，三者對齊。

### 1.2 為什麼做這個改動

- **問題／脈絡**：LLM 嘅有效注意力遠低於 window 上限；1M 窗口用咗 50%＝500k tokens 時，模型早已「唔聰明」，但 pi 默認 `reserveTokens=16384` 要 98.4% 才壓縮。
- **為什麼選這個解法**：實測證明「模型自己叫 compact」喺 pi 1.4.0 唔可行（`compact()` 先 `abort()` → 連 summarization 一齊 abort；`agent_end` 內 await 會死鎖；`setTimeout` 延後會 ctx stale）。所以硬保險絲交俾 pi 原生自動壓縮（run 中途 `prepareNextTurn` 觸發並繼續跑），skill 只負責「量度 → 判定 → 準備（交接筆記）」。
- **成功怎麼看**：`ctx_status` 回傳得到 zone／action／fuse 狀態；zone 離開 smart 後每輪自動注入；原生壓縮觸發點與 hard block 一致；文件講清「唔准假報已 compact」。

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `skills/dav-self-compact/SKILL.md` | 主檔（4 段結構、46 行）|
| `skills/dav-self-compact/protocol.md` | 量度時機、soft／hard 程序、交接筆記模板、驗證、subagent 接線 |
| `skills/dav-self-compact/reference.md` | 區間定義、閾值設定、量度方式、原生壓縮對齊、為何 extension 唔自己壓縮（實測）|
| `skills/dav-self-compact/setup.md` | 安裝／驗證／故障排除 |
| `skills/dav-self-compact/extension/index.ts` | pi 入口：`ctx_status` ＋ `before_agent_start` 注入 ＋ `/ctx` ＋ fuse 審核（讀 settings／config）|
| `skills/dav-self-compact/extension/lib/zone.ts` | 純計算層（zone／fuse／文案），無 I/O 無 pi API → 可單元測試 |
| `skills/dav-self-compact/tests/zone.bats` | 9 條單元測試（Z1–Z9）鎖住關鍵數字 |
| `skills/dav-trust/long-run-context.md` | trust mode 長跑 context 紀律（57 行）|
| `tests/fixtures/mock-tree-monstor/skills/dav-planner/extension/index.ts` | install 測試用 fixture（驗證 skill 內附 extension 目錄嘅裝卸）|
| `agents/dav-long-run.md` | 現成 long-run subagent：`tools` 含 `ctx_status`、內建交接筆記模板、soft/hard 行為寫死（R1 subagent 側嘅機械保證）|
| `tests/fixtures/mock-tree-monstor/agents/mock-agent.md` | install 測試用 subagent fixture |
| `docs/deliverable/2026-10-29-dav-self-compact.md` | 本交付摘要 |

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
|---------|---------|
| `install.sh` | `print_plan` 加 extension 計劃行；`uninstall_pi()` 呼叫 `uninstall_pi_extensions`；新增 `uninstall_pi_extensions()`（只刪指向本 repo extension 嘅 symlink）|
| `lib/install/agents.sh` | 新增 `install_pi_extensions()`；`install_pi()` 呼叫佢；檔案頭「Defines」清單補一行 |
| `tests/install.bats` | AC-1 加 extension 目錄 symlink ＋ subagent symlink 斷言；AC-4(no-agents-dir) 改為斷言「唔裝 copy 但 subagent 仍 symlink」；AC-8 加「用戶自建 extension 不會被 uninstall 刪走」負向案例 |
| `skills/dav-trust/SKILL.md` | 子檔導航加 `./long-run-context.md`；「中斷後續跑」規則指向新子檔（行數仍 50）|
| `AGENTS.md` | 加 V04（長跑必守聰明區）；標題「三條行為紀律」→「四條行為紀律」（32 → 34 行）|

### 2.3 刪除檔案

無。

### 2.4 改動背後的理由

| 改動 | 為什麼這樣設計 | 放棄的選項 |
| --- | --------------- | ----------- |
| Extension 放 `skills/<name>/extension/` 而唔係 repo 根 `extensions/` | 用戶選「方案 A：skill ＋ extension 同一資料夾」；installer 由 `skills/*/extension/` 掃，任何 skill 都可以自帶工具 | 放 repo 根（同 orca-*.ts 一齊）——但就同「skill 自足」原則相反 |
| Extension 用目錄 symlink（`extensions/<skill>` → `<skill>/extension`）＋ `index.ts` 入口 | 純計算層要抽去 `lib/zone.ts` 才好測試，而相對 import 喺「單檔 symlink」下會解析錯（實測：`Cannot find module './lib/zone.ts'`）；pi 支援 `<dir>/index.ts` 發現方式，目錄 symlink 令相對 import 照樣解析到 | 單檔 symlink ＋ 唔抽 lib（但 extension 邏輯就零測試）；或改為 copy（失去即時更新）|
| 唔提供 `ctx_compact` 工具 | 實測三種觸發路徑全部失敗（abort 連摘要一齊死／死鎖／ctx stale）。留一個壞工具比冇工具更危險（會假報成功）| 保留工具 ＋ 文件寫「可能失敗」（用戶會依賴一個唔可靠嘅動作）|
| fuse 審核用 tokens 而唔係百分比 | 設咗 `absoluteCapTokens` 之後 hard block 係絕對 token 數（120k）；用百分比會出現「zone 話 hard、原生卻要 98% 才壓」嘅斷鏈 | 只用百分比（1M 窗口下 soft=500k，等於冇作用）|
| `uninstall_pi_extensions` 只刪「指向自己 extension」嘅 symlink | 用戶可能有自己嘅 extension 檔；install 路徑必須可逆而唔傷人 | 刪整個 extensions 目錄（會清走用戶資源）|
| 加 fixture extension 而唔係指向真 extension | install 測試要同真實 repo 解耦（fixture 模擬 source），否則測試會隨 skill 內容飄 | 直接用真 `dav-self-compact.ts`（測試會依賴真實檔存在，失去隔離）|

## 3. 驗收條件對應

本次冇正式 US／AC（見 §5）；以下用用戶原話嘅 7 條需求（R-ID）作驗收基準，逐條落地證據見 §3.1。

| 需求 | 描述 | 結果 | 證據 |
|----|------|------|------|
| R1 | Agent 同 subagent 都按 skill 指引自動 compact | ✅ | agent 側：注入 ＋ skill；subagent 側：extension code 自動（`defaultSubagentOnlyExtensions`）＋ **`AGENTS.md` V04 硬規則**（派長工必帶 skill ＋ 寫 checkpoint）＋ `dav-trust` §5；tool 名仍要入 `tools` allowlist（陷阱已寫入 `protocol.md` §7）|
| R2 | 長期留喺聰明區 | ✅ | `reference.md` §1／§2（`absoluteCapTokens` ＋ 理由）|
| R3 | 處理 long-running 長任務 | ✅ | `protocol.md` §3／§6（交接筆記 ＋ 長任務紀律）|
| R4 | 知道當前 LLM 嘅 context window | ✅ | `ctx_status` 印 `14k/200k tokens, window 1000k`（F3 修正後，真跑實測）；`skills/dav-self-compact/tests/zone.bats` Z4 鎖住 |
| R5 | ≥50% soft block：準備，唔一定要即刻壓縮 | ✅ | `reference.md` §1；`protocol.md` §2 |
| R6 | ≥60% hard block：做完當前任務即刻 compact | ✅ | 原生自動壓縮（`reserveTokens=880000`）；`protocol.md` §4；`reference.md` §6（實測）|
| R7 | 確認 compact 成功＋壓縮後 ≤50%（建議 20–35%）| ✅ | `protocol.md` §5（`percent=null` 處理、JSONL `"type": "compaction"` 事件層確認、連續兩次失敗停手）|

### 3.1 需求對帳（Gate 4.5 產物）

- 對帳者: 獨立 Reviewer subagent（未參與實作；2026-10-29）
- 覆蓋率: **7 / 7（100%）**；對帳時 R1／R4 標「部分」，兩條已於第二輪補齊（R4 → F3 修正 ＋ zone.bats Z4；R1 → AGENTS.md V04 ＋ dav-trust §5 ＋ defaultSubagentOnlyExtensions）
- 對帳員原話（摘要）：「7/7 需求錨點都有落地證據（覆蓋率 100%）；R1、R4 標 ⚠️ 部分…冇任何 ❌。Merge verdict: OK with notes」
- 對帳員提出嘅 P1 兩條：F1（`changes.patch` 與 working tree 不符 → 已重出 diff，714 行 9 個檔）、F2（50%／60% 基準未講清 → 已在 `SKILL.md` Step 2 ＋ `protocol.md` §1 補「百分比按有效窗口計／footer % 唔可以直接用」）

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| `bats tests/` 全量 | 128 / 128 | 包含 `skill-size`、`install`（32）、`mutant-must-die`、`env-equivalence` 等 |
| `bats skills/*/tests/*.bats`（skill 自帶探針）| 441 / 441 | 含新增 `skills/dav-self-compact/tests/zone.bats` 9 條 |
| `bats tests/skill-size.bats` | 6 / 6 | 主檔 46 ≤50、子檔 ≤150、context 258 ≤400 |
| `bats tests/install.bats` | 32 / 32 | 含新 extension 裝／卸斷言 |
| 文件漂移檢查 D1–D8 | 綠（11 項豁免）| `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-20` |
| Subagent smoke（實跑 `dav-long-run`）| ✅ | `ctx_status` 存在並回傳 `ctx 1.6% (3k/200k tokens, window 1000k)`；紀律指令確認收到 |
| Extension smoke（實跑 pi）| 4 個情境全過 | smart 區輸出（`14k/200k tokens, window 1000k`）、soft／hard 注入、fuse ⚠ 分支、目錄 symlink 載入（`extensions/dav-self-compact/index.ts`）|
| Gate 4（品質審核）| OK with notes | 7 findings，全部 minor；F1／F2／F6 已修 |

## 5. 已知問題 / 限制

| 問題 | 嚴重性 | 已記錄位置 |
|------|--------|-----------|
| 本次**冇 US-ID／需求錨點檔**（`docs/req/`），因為直接由對話指派、未走 `dav-planner`；對帳改用對話原話作錨點 | P1（流程）| 本檔 §3.1 |
| **實測（已解）**：現成 agent `dav-long-run` 實跑 → `ctx_status` 存在、回傳 `ctx 1.6% (3k/200k tokens, window 1000k)`、並確認收到紀律指令；即 subagent 側而家有機械保證 | ✅ | `agents/dav-long-run.md`；`protocol.md` §7；`dav-trust/long-run-context.md` §5 |
| **實測**：一次性 subagent 嘅 `before_agent_start` 被動提示**唔會觸發**（run 開始時 usage 未知 → zone=unknown → 靜默）；background `worker` 實跑回報 `NO_HINT`，且其 `tools` 亦冇 `ctx_status` | P2 | `reference.md` §4；`dav-trust/long-run-context.md` §5 |
| subagent 用 `ctx_status` 仍要將工具名加入 agent 嘅 `tools` allowlist（extension 代碼載入唔等於 tool 可用）| P2 | `reference.md` §4；`protocol.md` §7；`AGENTS.md` V04（已把 checkpoint 要求變成硬規則，令冇 tool 都用得）|
| 三個模型一律設 `reserveTokens=880000`，只有窗口 ≥880k 才安全；錯配會有 ⚠ 警示（唔會靜靜錯）| P2 | `~/.pi/agent/settings.json`；`setup.md` §1 |
| pi 用嚴格 `>` 比較，實際喺 120,001 tokens 觸發（hard 定義 ≥120,000）→ 差 1 token | P3 | `reference.md` §5 |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **`AGENTS.md` 加一條硬規則：派 long-running subagent 必須帶 `skill: dav-self-compact` 並要求回報 zone** —— 補 R1 subagent 側嘅唯一缺口（依家只有 skill 文件講，冇每次都會載入嘅規則檔講）。
2. **為 extension 加一支單元測試**（export `readUsage`／`fuseNote`，用假 `ctx` 斷言 zone／fuse）—— 令 120k／880k 呢類關鍵數字有機械鎖，唔靠文件。
3. **`ctx_compact` 類工具唔好再試**：已記錄三種失敗模式；如 pi 日後修好 `compact()` 嘅 abort 行為，再開票評估。

### 6.2 下一個 Sprint 考慮

- [ ] 把 `absoluteCapTokens` 寫入 installer 預設（今日要人手建 `~/.pi/agent/dav-self-compact.json`）
- [ ] 為其他 provider（窗口 <880k）提供 per-model 建議值計算器（`/ctx` 已印建議值，但冇自動寫入）

### 6.3 長期方向（Think Big）

- Context 治理可以延伸到「階段化任務」：每個階段完結就係天然壓縮點，交接筆記可以標準化成 `docs/state/<task>.md`，令跨 session／跨 agent 接手變成例行程序
- 若 pi 支援「模型可要求壓縮」，本 skill 只需換一條 Step 3，其餘紀律不變（設計已預留 `reference.md` §6 呢一節）

## 7. 相關文檔連結

- Skill 主檔: `skills/dav-self-compact/SKILL.md`
- 執行程序: `skills/dav-self-compact/protocol.md`
- 參考（區間／閾值／實測）: `skills/dav-self-compact/reference.md`
- 安裝／驗證: `skills/dav-self-compact/setup.md`
- Extension: `skills/dav-self-compact/extension/dav-self-compact.ts`
- pi 官方壓縮文件: `https://pi.dev/docs/latest/compaction`

## 8. 反思

### 8.1 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | ✅ | 只有 `/ctx` 通知同工具輸出；smart 區完全靜默（零 token 成本）|
| 2 | RWD 響應式設計 | N/A | 無介面 |
| 3 | 技術債 | ✅ | extension 邏輯已有 9 條單元測試；subagent 側有 V04 硬規則 ＋ trust 子檔 |
| 4 | 可維護性 | ✅ | 閾值集中一個 JSON 檔；fuse 審核會自報錯配；文件分行數上限 |
| 5 | 測試覆蓋率 | ✅ | install 32 條、skill-size 6 條、extension 計算 9 條、全量 128 條 |
| 6 | 需求對齊 | ✅ | 7/7 覆蓋；R1／R4 由「部分」補到「落地」（F2／F3）|

### 8.2 問題清單

- ✅ [P2]（已修）Extension 計算邏輯零測試 → 以 `extension/lib/zone.ts` 抽純函式 ＋ `skills/dav-self-compact/tests/zone.bats`（`node --experimental-strip-types`）鎖住關鍵數字
- ✅ [P2]（已修）subagent 側「自動遵守」原本只係紀律 → 加 `AGENTS.md` V04 ＋ `dav-trust/long-run-context.md` §5；餘下限制：`tools` 嚴格 allowlist 令 `ctx_status` 要顯式列名
- ⚠️ [P1] 流程偏差：直接做 skill 冇建 US／需求錨點 → 根因：用戶即時指派、我未堅持走 `dav-planner` → 建議：下次同類「新 skill」任務先建一支 US（1 SP）再開工，令 Gate 4.5 有正式錨點

### 8.3 Action Items

| # | 動作 | 類型（TECH/DE/US/Spike）| 驗收條件 | 預估 |
| - | -- | ----------------------- | -------- | ---- |
| 1 | ~~`AGENTS.md` 加長跑硬規則~~ **已完成**（V04）| DE | 規則檔有該條 ＋ 唔與 V01–V03 衝突 | ✅ |
| 2 | ~~Extension 計算邏輯單元測試~~ **已完成**（`zone.bats` 9 條）| TECH | 假 ctx（120k/1M）→ `zone=hard`、`nativeFuseOk=true`；錯配設定 → ⚠ | ✅ |
| 3 | installer 自動建 `dav-self-compact.json` 預設 | TECH | 新機安裝後 `/ctx` 即顯示 cap 生效 | 1 SP |

### 8.4 Reviewer 二審結果（V03 紀律）

- Gate 4（品質審核）＋ Gate 4.5（需求對帳）已由**未參與實作**嘅獨立 Reviewer subagent 完成（2026-10-29）
- Gate 4 結論：**OK with notes**（7 findings、全 minor；F1／F2／F6 已修，F3／F4 為文件／UX nit 已記錄）
- Gate 4.5 結論：**OK with notes**（7/7 覆蓋、2 條 ⚠️ 已補 F2／F3）
- 行數自查：主檔 46 ≤50、子檔 78／63／71 ≤150、context 258 ≤400（`bats tests/skill-size.bats` 全綠）

---

**產生者**: Agent（透過 dav-reviewer skill）
**產生時間**: 2026-10-29 01:10
