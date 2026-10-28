# dav-self-compact — 參考

## §1 區間定義（聰明區）

- **smart（聰明區）**：`percent < softPercent`（默認 50%）→ 照常做嘢，唔使理 context。
- **soft block**：`percent >= softPercent`（默認 50%）→ 軟阻塞：開始為壓縮做準備（寫交接筆記、記低下一步），**唔代表一定要即刻壓縮**。
- **opportunity（機會窗口）**：`percent >= opportunityPercent`（默認 55%）→ **最佳壓縮時機**：揀一個好邊界（原子步驟完成／測試綠／筆記已更新）就壓，唔好再等。
- **hard block**：`percent >= hardPercent`（默認 60%）→ **死線／警報**：正常應該已經壓咗；仍然見到代表 fuse 太遲，要收尾 ＋ 報告。
- **target（壓縮後落點）**：默認 20%–35%（建議值，唔係硬規定）；硬規定只有一條 —— 壓縮後必須 ≤ softPercent（50%）。
- `percent` 係「已用 tokens ÷ context window」；設咗 `absoluteCapTokens` 時，zone 判定改用「已用 tokens ÷ 有效窗口」。

## §2 閾值設定

- 設定檔：`~/.pi/agent/dav-self-compact.json`（唔存在就用默認值，唔會出錯；改完即時生效，唔使重啟）。
- 欄位：`softPercent`（默認 50）、`opportunityPercent`（默認 55）、`hardPercent`（默認 60）、`targetPercent`（默認 35）、`targetMinPercent`（默認 20）、`absoluteCapTokens`（默認 0 = 只用百分比）。
- `opportunityPercent` 會被夾入 `(softPercent, hardPercent]`：細過 soft 就同 soft 重疊、大過 hard 就永遠追唔到。
- `noticePercents`（默認 `[20, 40, 60]`）：**使用率里程碑**。每跨過一個就印一次訊息（使用率 ＋ zone ＋ 要做乜），一次最多印一個（最高嗰個），唔會重複；壓縮後使用率大跌（< 上次 × 0.6）會自動重置，之後再跨過會再通知。寫法：`[20, 40, 60, 80]`；唔合法／空陣列 → 用默認。
- `absoluteCapTokens > 0` → 有效窗口 = `min(contextWindow, absoluteCapTokens)`，百分比門檻按有效窗口計。
- 例：窗口 1,000,000、`absoluteCapTokens: 200000` → soft = 100,000、opportunity = 110,000、hard = 120,000 tokens。
- **點解要有絕對上限**：1M 窗口嘅 50% = 500k tokens，比例睇落「安全」，但模型注意力喺咁上下文明顯退化；絕對上限先真正貼近「聰明區」。

## §3 量度方式（由準到唔準）

- **`ctx_status` 工具**（本 skill 附帶嘅 extension）→ 最準：直接讀 pi 內部 `getContextUsage()`，回傳 tokens／contextWindow／percent／zone／action，並附「原生保險絲觸發點」審核。
- **里程碑訊息（自動）**：跨過 `noticePercents`（默認 20%／40%／60%）時，喺 `turn_end` 邊界掛一條 `custom_message`（transcript 可見 ＋ 入下一輪 context），例：`ctx 20.5% just crossed 20% — 27k/130k tokens · zone=smart (normal) · action=keep_working …`。TUI 之下同時出通知。
- **自動注入**：`before_agent_start` 喺 zone 離開 smart 之後，每輪 run 開始自動注入一行提示（唔會喺 smart 區浪費 token）。
- **pi footer** → TUI 底部嘅 context %，俾人睇；agent 睇唔到，要人主動講。
- **自己估算** → 最唔準，只作 fallback：估算對話字數 ÷ 4 ÷ contextWindow。

## §4 subagent 接線（令子 agent 都守到）

- **Skill 傳遞**：派工時用 `options: { skill: "dav-self-compact" }`（名字／CSV／陣列）；或 agent frontmatter 寫 `skills: [dav-self-compact]`。
- **工具傳遞**：**前台** subagent 唔會自動載入全域 extension，要在 agent frontmatter 加 `extensions: [<路徑>]`（指向 `<skill>/extension/` 目錄或其中嘅 `index.ts`）；**後台** subagent（`async: true`）預設載入 ambient extension。
- **allowlist 陷阱**（實測）：subagent 嘅 `tools` 係嚴格 allowlist —— extension 代碼載入咗，但 `ctx_status` 唔喺 `tools` 名單就一樣 call 唔到。要在 `tools` 補上 `ctx_status`。
- **全域預設**：settings `subagents.defaultSubagentOnlyExtensions: ["<路徑>"]` 令所有冇自己清單嘅 subagent 都載入 extension；被動提示（`before_agent_start` 注入）唔受 allowlist 限制，tool 就要。
- **注意（實測）**：一次性 subagent 嘅 run 開始時 usage 仍然未知（未有回應）→ `before_agent_start` 嘅被動提示**唔會觸發**（實測 background worker 回報 `NO_HINT`）。所以子 agent 只能**主動** call `ctx_status`，而前提係工具名喺 `tools` allowlist 內。
- **父 session 責任**：派長工時講明「到 50% 寫交接筆記、到 60% 停新工作」，並要求回報附 zone（例：「完成，ctx 42%」）。
- **注意**：`inheritSkills` 默認 false —— 唔顯式傳 skill，子 agent 根本睇唔到呢份指引。

## §5 同原生 pi 自動壓縮對齊（機會窗口嘅真保險絲）

- 觸發式：`contextTokens > contextWindow - reserveTokens`；默認 `reserveTokens = 16384` → 1M 窗口要 **98.4%** 先壓，遠超死線。
- **對齊目標係 opportunity（唔係 hard）**：`reserveTokens = contextWindow − opportunityTokens`（`opportunityTokens` = 有效窗口 × opportunityPercent）。
  - 純百分比模式：1M ＋ opportunity 55% → `reserveTokens = 450000`。
  - 設咗 `absoluteCapTokens: 200000`：opportunityTokens = 110k → `reserveTokens = 890000`（＝窗口嘅 89%；用到 11%／110k 就觸發）。
- 判 OK 的條件：`softTokens < nativeTriggerTokens <= opportunityTokens` —— fuse 要**喺機會窗口之內**開火；早過 soft（太早，會過度壓縮）或遲過 opportunity（太遲，會拖到 hard）都會出 ⚠ 同建議值。
- **對齊要用 tokens 比，唔好用百分比比**：設咗絕對上限之後，門檻係絕對 token 數。
- **fuse 嘅觸發位置**：pi 喺「工具批次完、下一個 assistant 回應之前」（`prepareNextTurn`）檢查 —— 呢個本身已經係一個安全邊界（冇半套 tool call）。所以「揀時機」嘅實際做法係**保持每步細**，令最近嘅邊界就係好邊界。
- pi 喺**多輪 run 中途**（工具結果 append 之後、下一個 assistant 回應之前，`prepareNextTurn`）會檢查並壓縮，壓縮完**繼續跑**——正好等於「做完當前步驟就壓」。
- `keepRecentTokens`（默認 20000）係壓縮後保留嘅近期 tokens：越大保越多細節，佔用越多。
- 同一份 settings 覆蓋父 session 同全部 subagent（含後台）。
- 原生機制**唔會**喺 soft 區出手 —— soft 區嘅準備工作（交接筆記）只有 skill 嘅紀律做得到。

## §6 為何本 extension 唔自己叫 compact（實測）

- `ctx.compact()` 內部第一步係 `await this.abort()`；喺 tool call 內觸發 → 連 summarization 都一齊被 abort（實測錯誤：`Turn prefix summarization failed: This operation was aborted`）。
- 改喺 `agent_end` handler 內 `await compact()` → **死鎖**（`abort()` 等 run 收尾，run 收尾又等 handler，實測卡死 90 秒）。
- 改 `setTimeout` 延後 → headless 收咗 session，`ctx` 已失效（`stale after session replacement`）。
- 結論：模型自己觸發壓縮喺 pi 1.4.0 唔可靠 → 硬保險絲交俾原生自動壓縮；要提早壓縮就用戶打 `/compact`。
- 「Nothing to compact（session too small）」係正常：context 未超過 `keepRecentTokens` 時冇嘢可壓。

## §7 術語

- **聰明區**：context window 用量低嘅區間，模型推理最穩。
- **soft block**：軟阻塞，預警級，要開始準備。
- **hard block**：硬阻塞，行動級，處理完當前步驟即刻壓縮。
- **compact**：把舊對話壓縮成摘要，釋放 context；摘要會有資訊損失，所以要靠交接筆記補。
- **交接筆記**：落檔案嘅任務狀態（已完成／下一步／關鍵路徑），係壓縮後嘅真相來源。
- **原生保險絲**：pi 內建自動壓縮（settings `compaction.reserveTokens`）。
