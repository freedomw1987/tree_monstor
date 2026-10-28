# dav-trust — trust mode 嘅長跑 context 紀律

trust mode 動輒跑幾個鐘、跨多個 Backlog（Step 4 三段接力 L1→L2→L3），context 一定會撐爆。
呢份子檔講：**幾時量、幾時寫 checkpoint、幾時交俾原生壓縮**。詳細閾值／工具 → 同套 `dav-self-compact` skill。

## §1 同 SOP 嘅接口（3 個 checkpoint）

| 時機 | 做乜 | 落檔位置 |
|---|---|---|
| 啟動（Step 1 之後） | 量一次 baseline，記低 zone | `docs/trust-log.md` 檔頭 |
| 每完成一個 Backlog | 量一次；soft 區就寫 checkpoint | `docs/trust-log.md` ＋ `docs/backlog.md` row |
| 退出（Step 5 之前） | 量一次，記最終 zone | `docs/trust-log.md` |

**為什麼**：trust mode 唔可以停低問用戶（Step 3 紀律）——context 爆咗 = 中途崩潰 = 用戶返嚟見到一鑊粥。
所以量度同 checkpoint 係**唔需要用戶參與**嘅自救動作，唔算「打斷」。

## §2 三區判定同動作（沿用 dav-self-compact 定義）

- **smart（<50% 有效窗口）** → 照跑，唔使理。
- **soft（≥50%）** → **仍然繼續跑**（trust mode 唔停），但即刻：
  1. 更新 `docs/trust-log.md` 檔頭 checkpoint（見 §3）；
  2. 確保 `docs/backlog.md` 當前 row 狀態／剩餘項已寫實；
  3. 下一步避開「大字串」：唔好一次讀超長檔／貼大 log，改 `limit` 分段讀。
- **hard（≥60%）** → 唔准開新 Backlog／新大範圍改動；**收尾當前原子步驟 → 寫 checkpoint → 交俾 pi 原生自動壓縮**（佢喺下一個模型回應前會壓），壓縮完繼續 L1/L2/L3。
- **unknown（剛壓縮完，`percent` 讀到 null）** → 唔准當「已回落」；下一輪模型回應後即刻再量一次。

**唔准自己叫 compact**：trust mode 內一樣受 `dav-self-compact` 嘅限制 —— pi 1.4.0 喺 tool call 內觸發壓縮會連摘要一齊 abort。
要即時壓縮只有兩條路：交俾原生保險絲（`compaction.reserveTokens`），或者由用戶打 `/compact`。

## §3 checkpoint 格式（寫入 `docs/trust-log.md` 檔頭）

```markdown
## Context checkpoint — <ISO 時間> · zone=<smart|soft|hard|unknown> · ctx=<percent>%

- **已完成**：<US-ID + 一句成果>（逐條）
- **進行中**：<US-ID + 當前做到邊一步>
- **下一步**：<具體下一個動作，唔准寫「繼續做」>
- **關鍵檔案路徑**：<改過／要改嘅檔，逐條>
- **待用戶覆核**：<trust-log 內已代答嘅決定，逐條列 ID>
```

**為什麼要落檔**：壓縮只保摘要、會失真；checkpoint 係壓縮後重建狀態嘅**真相來源**（`resume.md` §2 已要求讀檔頭 checkpoint 續跑）。
**限制**：最少要有「已完成／下一步／關鍵檔案路徑」三項；太薄 = 壓縮後等於失憶。

## §4 壓縮後續跑（接 `resume.md`）

1. 先讀 `docs/trust-log.md` 檔頭 checkpoint，再讀 `docs/backlog.md` 當前 row。
2. 再量一次 context（`ctx_status`）；**>50%** → 唔准開新工作，先補 checkpoint 再等下一輪壓縮。
3. 兩次壓縮都跌唔返 ≤50% → **唔准硬闖**：寫 checkpoint ＋ 喺 `docs/need-you-help.md` 開一條待回覆，等 deadline 到或用戶叫停（trust mode 內唔問用戶）。
4. 續跑期間所有代答照舊寫 `docs/trust-log.md`（Step 3 紀律不變）。

## §5 subagent 派工（trust mode 常用）

- **優先用現成 agent**：`agent: dav-long-run`（repo `agents/dav-long-run.md`，`tools` 已含 `ctx_status` ＋ 內建交接筆記模板）→ 佢自己會量 zone、soft 寫筆記、hard 收尾停手。
- 派長工（預計 >20 次工具呼叫／要讀多個大檔）→ Task 描述**必**寫：交付物落檔位置、checkpoint 落檔位置、「≥50% 寫 checkpoint、≥60% 收尾等原生壓縮」。
- 有 `ctx_status` 就要求 subagent 回報時附 zone（例：「完成，ctx 42%」）；**冇**就要求佢報「大概做咗幾多輪工具呼叫」＋ 主動寫 checkpoint。
- 前台 subagent **唔會**自動載入全域 extension，`tools` 亦係嚴格 allowlist → 想佢自己量度，要喺 agent frontmatter 加 `extensions:` 同 `tools: [..., ctx_status]`（陷阱細節 → 同套 `dav-self-compact` 嘅 `protocol.md` §7）。
- **實測**：一次性 subagent 嘅被動提示唔會觸發（run 開始時 usage 未知）→ 子 agent 一定係「有 tool 就主動 call、冇 tool 就靠 Task 指令寫 checkpoint」兩種情況，唔存在「佢自己會知」。
- 冇 `ctx_status` 就靠 fallback：**每個 Backlog 完成即寫 checkpoint**，唔好等 context 爆。
