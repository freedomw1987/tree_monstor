# dav-self-compact — host 適配層

> 主檔同 `protocol.md` 講通用紀律；呢度講**每個 host 嘅機械層**（點量度、點觸發、點驗證）。
> 判定咗 host 之後**只讀嗰一段**，唔好讀晒（省 context）。

## §1 判定 host

- 最準：讀 skill 目錄**上一層**嘅 `dav-self-compact.host`（安裝時由 installer 生成，內容＝host 名）。
- 冇綁定檔就用環境變數：`PI_CODING_AGENT`→pi；`CLAUDECODE`→Claude Code；任何 `QODER_*`→Qoder。
- 再冇就用工具特徵：有 `ctx_status` 工具 → pi；`~/.claude/projects` 有本專案 session → Claude Code；`~/.qoder/projects` 有 → Qoder。
- 全部判斷唔到 → 只做紀律層（`protocol.md`），並喺報告講明「host 未知，冇機械層，冇自動保險絲」。
- **唔准假設**：冇量度工具就唔好報百分比；用 adapter 指定嘅方式，報唔到就報「攞唔到」。

## §2 pi（extension 提供機械層）

- **量度**：`ctx_status` 工具 → 讀 pi 內部 usage，回傳 tokens／contextWindow／percent／zone／action，附保險絲觸發點審核。
  - 冇工具（前台 subagent 未掛 extension）→ 叫父 agent 幫手查，或問用戶睇 pi footer %；兩樣都冇就當 soft 區。
- **里程碑**：跨過 20%／40%／60% 自動印（extension `turn_end`）；離開 smart 區每輪自動注入提示（`before_agent_start`）。
- **觸發（agent 主動）**：`ctx_compact` 工具 → 令門檻即刻跨過（`reserveTokens = contextWindow`）
  → pi 喺下一個安全邊界用**原生**路徑壓縮 → **唔 abort、壓完繼續跑**。
  - 護欄：對話未過 `keepRecentTokens`（默認 20000）→ 工具會拒絕並講明「對話只有 X tokens，冇嘢可壓」→ 唔准硬 loop。
  - ⚠️ 唔好喺 tool call 內直接叫 `ctx.compact()`：pi 1.4.0 會 abort 整個回合（實測 `This operation was aborted`）。
- **保險絲對齊（live fuse）**：extension patch `SettingsManager.getCompactionSettings()` → 每回合用 config 即時計
  → 改閾值即生效，唔使 `/reload`；session 開始自動寫 per-model override 入 `~/.pi/agent/settings.json`。
  - 公式：`reserveTokens = contextWindow − 有效窗口 × opportunityPercent`；只改 config 檔，唔好手改 settings.json 嘅 `reserveTokens`。
- **交接筆記**：agent 自己寫（`protocol.md` §4），soft 區就開始保持最新。
- **驗證**：壓縮後 usage → null，等下一輪回應再 `ctx_status`；睇 session JSONL 有冇 `"type":"compaction"` 確認真壓過。
- **subagent**：派工要帶 skill（`options: { skill: "dav-self-compact" }` 或 agent frontmatter `skills:`）。
  - 前台 subagent 要喺 frontmatter 加 `extensions:`（指向本 skill 嘅 extension 目錄）**而且** `tools` 要含 `ctx_status`。
  - `tools` 係嚴格 allowlist：唔列名就 call 唔到（extension 載入咗都冇用）。

## §3 Claude Code（原生 threshold auto-compact，冇 agent 壓縮入口）

- **量度**：agent 睇唔到 `/context` → 讀 transcript：跑同 skill 同一層嘅 `ctx-usage.py --host claude`。
  - 解析 `~/.claude/projects/<encoded-cwd>/` 最新 session JSONL 最後一次 assistant 嘅 usage
    （input ＋ cache_creation ＋ cache_read ＋ output）→ 輸出 used／window／percent／zone／action。
  - 窗口來源（依序）：`CTX_WINDOW` → `~/.claude/dav-self-compact.json` 嘅 `contextWindow` → 默認 200000。
  - 解析唔到 → 當 soft 區保守處理，唔好亂報百分比。
- **觸發（冇 agent 可呼叫嘅壓縮入口）**：Claude Code 只有 threshold auto-compact → 令佢**提早開火**：
  - `~/.claude/settings.json` 開 `autoCompactEnabled: true`，`env` 加 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = 55`。
  - 觸發點 = 有效窗口 − summary buffer，再被嗰個百分比拉低；唔設就係 ~95% 先壓 → 太遲（一定撞 hard）。
  - 改完重開 session 生效；唔好叫用戶撳 `/compact`：靠 auto-compact ＋ 交接筆記。
- **交接筆記**：soft 區由 agent 寫落檔；可加 `PreCompact` hook 做保險（hook 輸入有 `transcript_path`／`cwd`／`session_id`）。
- **驗證**：transcript 內搵 `compact_boundary`（附 `compact_metadata`：trigger manual／auto、pre_tokens／post_tokens）。
- **限制**：冇「我而家壓縮」嘅 agent 入口 → 只能「提早開火 ＋ 預備好筆記」；microcompact 只清工具輸出，唔係真摘要。

## §4 Qoder（原生 `/compact` ＋ auto-compact）

- **量度**：跑同 skill 同一層嘅 `ctx-usage.py --host qoder` → 解析 `~/.qoder/projects/<encoded-cwd>/` 最新 session JSONL。
  - transcript 同 Anthropic 格式（與 Claude 一致）；人手可另跑 `/context` 核對。
  - 窗口來源（依序）：`CTX_WINDOW` → `~/.qoder/dav-self-compact.json` 嘅 `contextWindow` → 默認 200000。
- **觸發**：
  - 原生 `/compact`（alias `/summarize`、`/compress`）→ 用摘要替換舊 context；呢個係 user 命令，唔好叫用戶撳。
  - auto-compact 由 Qoder 內建管理（閾值 ＋ buffer）→ 想提早開火就用 `/context-window` 把當前模型窗口設細啲（等效 pi 嘅「絕對上限」）。
  - 熔斷注意：`autoCompact.maxConsecutiveFailures` 默認 3 → 連續失敗 3 次就唔再自動壓 → 見到連續失敗要即刻手動 `/compact` 並報告。
- **交接筆記**：soft 區由 agent 寫落檔；Qoder 有 `PreCompact`／`PostCompact` hook 可做保險。
- **驗證**：session 內搵壓縮事件；人手可用 `/context` 核對剩餘空間。
- **限制**：CLI 同 IDE 行為可能有差 → 以實測為準；冇 agent 可呼叫嘅壓縮入口（`/compact` 係 user 側命令）。
