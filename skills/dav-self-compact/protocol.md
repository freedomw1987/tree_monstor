# dav-self-compact — 執行程序

## §1 量度（每個階段開始前）

- 呼叫 `ctx_status`，讀 `zone` 同 `action`：`keep_working` / `prepare_then_compact` / `compact_now`。
- 冇 `ctx_status` 工具（前台 subagent 未掛 extension）→ 叫父 agent 幫手查，或者問用戶睇 pi footer；兩樣都冇就當 soft 區保守處理。
- **footer 嘅 % 唔可以直接用**：footer 用真實窗口做分母。設咗 `absoluteCapTokens: 200000`（窗口 1M）時，hard block 係 120k tokens ＝ footer 12%；footer 顯示 30% 其實已經係 300k，早已過 hard。
- **唔好每個工具呼叫都查**；查嘅時機：進入新階段、連續 20＋ 次工具呼叫、覺得「唔記得早前做咗乜」、或者見到注入提示。
- **里程碑訊息**：跨過 20%／40%／60% 會自動印一條（使用率 ＋ zone ＋ 要做乜）—— 見到就順手對一次自己嘅判斷，唔需要另外查。
- `zone=unknown` = 剛剛壓縮完、未有新模型回應 → 唔係錯誤，等下一輪再查。

## §2 soft block 準備程序（percent ≥ 50%）

1. **判斷仲有幾多要做**：剩低工作仲有好多輪 → 值得準備；只剩一兩步 → 可以繼續做，唔使急。
2. **寫交接筆記**（見 §3），落檔案。位置建議 `docs/ctx-handoff/<task-slug>.md`；冇 `docs/` 就放工作目錄根。
3. **避開大讀取**：下一步唔好讀大檔案／貼長 log；要讀就只讀必要段落（`offset`／`limit`）或者叫 subagent 讀完只交結論。
4. **細步前進**：把剩低工作切成細步，令每一步都可以喺 hard block 之前收尾。
5. **唔使自己叫 compact**：soft 區唔急；但**筆記要由呢一刻起保持最新**，因為之後任何一個模型回合邊界都可能被壓縮（機會窗口 55% 一開就隨時發生）。

## §3 交接筆記模板（最少三項）

```markdown
# 任務交接筆記 — <任務名> — <YYYY-MM-DD HH:MM>

## 已完成
- [x] <做咗咩／邊個檔案>

## 而家卡喺邊
- <下一步要即刻做嘅嘢，一句講清>

## 下一步（按次序）
1. <步驟 1>
2. <步驟 2>

## 關鍵檔案路徑
- `path/to/file.ts` — <點用>

## 關鍵決定同約束
- <做過嘅取捨、唔可以違反嘅嘢>

## 未解決問題
- <仍然未答、或者要問用戶嘅嘢>
```

- **必須落檔案**：摘要會壓縮細節，檔案先係真相；壓縮後第一件事係讀返呢份筆記。
- **覆寫而唔係追加**：保持「最新狀態」，唔好變日誌。
- **寫得夠密**：摘要會保留嘅係「有寫落筆記嘅嘢」，冇寫嘅就等於自願失憶。

## §4 揀最好時機（機會窗口，percent ≥ 55%）

**目標**：喺機會窗口內、喺一個「好邊界」被壓縮 —— 唔好拖到 hard 之後才被迫壓。

### §4.1 好邊界清單（全部要成立才叫好時機）

- ✅ 手頭上嗰個**原子步驟已完成**（該寫嘅檔已寫入、該跑嘅測試已跑完）
- ✅ **測試係綠**或者已記錄紅在哪（唔好喺紅嘅中途交出去）
- ✅ **交接筆記已更新**（已完成／下一步／關鍵路徑）
- ✅ 冇不可中斷嘅背景動作（部署、長時間 bash、大範圍 rename 去到一半）
- ❌ 反例：改檔改到一半、測試跑緊、下一步係「大範圍重構」但未拆步

### §4.2 機會窗口入面做乜

1. **唔准開新嘅大範圍工作**（大讀取／大重構／新 Backlog）；將剩低工作切成細步，令「好邊界」盡快出現。
2. **主動造出好邊界**：收尾當前步驟 → 更新筆記 → 呢一輪就係邊界。
3. **互動 session**：喺邊界主動叫用戶打 `/compact`（呢個係唯一可以由你揀時機嘅做法；講明「而家係好時機：本階段已完成 ＋ 筆記已更新」）。
4. **非互動 session（trust mode／subagent）**：你冇手掣可以按 —— 交俾 fuse。pi 喺「工具批次完、下一個 assistant 回應之前」檢查門檻，所以**只要保持每步細，下一個邊界就喺幾步之內**，fuse 自然喺窗口內開火。
5. **壓縮後**：下一輪回應之後 `ctx_status` 驗證（§6）。

### §4.3 為何唔可以「再等一個更好嘅時機」

fuse 係 token 門檻，唔識分辨好唔好嘅時機；拖得越久，越可能喺 hard 之後、甚至 overflow 之後才被迫壓縮（咁樣摘要會夾雜失敗嘗試）。所以：**窗口內每個邊界都值得接受**。

## §5 hard block 程序（percent ≥ 60% = 死線）

1. **唔准開新工作**：只做緊嗰個步驟收尾（如果係不可中斷嘅寫檔／部署，就等佢完成）。
2. **收尾即更新交接筆記**（§3）。
3. **停手交俾原生壓縮**：pi 喺下一個 assistant 回應之前（`prepareNextTurn`）見到門檻就會自動壓縮，壓縮完繼續跑 —— 你只需要「唔再開新工作」。
4. **見到 hard 就係警報**：正常情況 fuse 應該喺 opportunity（55%）已經開火，所以 60% 仍然見到代表 **fuse 設得太遲** → 報告 ＋ 叫用戶照 `./setup.md` §1 改 `reserveTokens`（`ctx_status` 會顯示 `⚠ …too late…` 同建議值）；唔好靜靜當無事。
5. **壓縮失敗／太細**：`Nothing to compact（session too small）` = 正常（context 未超過 `keepRecentTokens`）；其他錯誤 → 報告，唔好硬 loop 重試。

## §6 壓縮後驗證

- 壓縮之後 `percent` 會變 `null`（要等新一次模型回應先有 usage）→ **唔准即刻報「已回落」**。
- 下一輪回應之後即刻 `ctx_status`；合格線：`percent ≤ 50%`，目標 20%–35%。
- 唔合格 → 通常係交接筆記太薄或者對話有超大字串 → 補筆記 → 叫用戶再 `/compact`。
- **想確認真係壓縮咗（唔止 usage 跌）**：睇 session JSONL 有冇 `"type": "compaction"`，或者 pi 有冇出壓縮提示。
- **連續兩次壓縮都唔跌返 ≤50%** → 停低報告：邊個步驟令 context 爆（通常係讀大檔／貼長 log），建議拆細。

## §7 長任務紀律

- **每個階段結束就寫交接筆記**，唔好等到真係要壓縮先寫（到時可能記唔起）。
- **唔好靠對話長期記住狀態**：跨階段事實（做咗乜、改咗邊個檔、仲有咩未做）一律落檔案。
- **大輸出唔好入 context**：長 log／大檔案 → 摘要落檔案，context 只留摘要同路徑。
- **subagent 結果**：只攞結論同路徑返嚟，唔好將完整推理帶返嚟（context 貴）。
- **壓縮後開工第一步**：讀交接筆記，唔好靠摘要嘅記憶亂猜。

## §8 派工俾 subagent（父 agent 視角）

- 帶 skill：`options: { skill: "dav-self-compact" }`（或 agent frontmatter `skills: [dav-self-compact]`）。
- **現成方案**：repo 內 `agents/dav-long-run.md`（`tools` 已含 `ctx_status`、附交接筆記模板）→ installer 會 symlink 去 `~/.agents/`，派工直接用 `agent: dav-long-run` 就自己量得到。
- 想自己定義 agent：agent frontmatter 加 `extensions: [<extension 目錄路徑>]`（前台 subagent 唔自動載入全域 extension；後台預設載入），**並且** `tools` 要包含 `ctx_status` —— `tools` 係嚴格 allowlist，唔列名嘅 tool 會被過濾（extension 代碼載入都冇用）。
- 全域一次過搞掂：settings 加 `subagents.defaultSubagentOnlyExtensions: ["<路徑>"]` → 所有冇自己清單嘅 subagent 都會載入 extension（被動提示照生效；tool 仍然要入 allowlist 先 call 得到）。
- Task 描述寫明三樣：**交付物邊度落檔**、**交接筆記邊度寫**、**到 50%／60% 要點做**。
- 要求回報附 zone（例：「完成，ctx 42%」），父 agent 就知子 agent 仲有幾多氣。
