---
name: dav-self-compact
description: >-
  context window 聰明區治理：量度使用率、soft／hard block 判定、寫交接筆記、對齊 pi 原生自動壓縮（live fuse：閾值改完即時生效），
  令 Agent 同 subagent 喺長任務中長期留喺聰明區（<50%）。適用於長任務、多階段任務、會撐爆 context 嘅工作；
  不適用於一次性短答、純查資料、純技術問答。
---

# Dav Self Compact

## TL;DR

1. **做什麼**：守住聰明區 → 量度 → 判定區 → soft 寫交接筆記 → **機會窗口揀最好時機壓縮** → 壓縮後驗證（≤50%）。
2. **何時觸發**：長任務（多階段／多輪工具呼叫）、覺得「唔記得早前做咗乜」、subagent 長跑、跨多個 US 嘅工作。
3. **關鍵紀律**：soft 起就要保持筆記最新；**機會窗口（55%）一開就揀邊界壓縮，唔好等 hard**；hard 係死線唔係觸發點；壓縮後要等下一輪回應先驗證。
4. **必產出物**：交接筆記（落檔案）＋ 壓縮後 zone 確認。
5. **壓縮邊個做**：**你自己發起** —— 好邊界叫 `ctx_compact`（pi 喺下一個安全邊界壓、壓完繼續跑）；或者等原生 fuse（live 對齊）。**唔關用戶事，唔准叫佢撳 `/compact`**。

## 觸發時機

- ✅ **觸發**：長任務／多階段任務、連續多輪工具呼叫、跨 session 續做、subagent 長跑。
- ⚡ **建議**：進入新階段、或連續 20＋ 次工具呼叫後，先查一次 `ctx_status`。
- ❌ **不觸發**：一次性短答、純查資料、純技術問答（壓縮只會白燒 token）。

## 流程（4 步）

- **Step 1 量度** — `ctx_status` 讀 `zone` 同 `action`；跨過 20%／40%／60% 會自動印里程碑訊息；冇工具就睇 footer % → `./protocol.md` §1
- **Step 2 判定** — smart（<50%）繼續；soft（≥50%）準備；**opportunity（≥55%）＝壓縮窗口**；
  hard（≥60%）= 死線（百分比按**有效窗口**計，footer 嘅 % 要用真實窗口換算）→ `./reference.md` §1
- **Step 3 執行** — soft：寫交接筆記 ＋ 避開大讀取；opportunity：**揀最好邊界**（原子步驟完成／測試綠／檔案已寫）＋ 更新筆記 ＋ 叫 `ctx_compact`；
  hard：死線，只收尾報告 → `./protocol.md` §2–§5
- **Step 4 驗證** — 壓縮後 usage 變 unknown，**下一輪回應之後**再 `ctx_status`：必須 ≤50%（目標 20–35%）；唔合格 → 補筆記再壓 → `./protocol.md` §6

## 規則 / 例外 / 限制

- **交接筆記先於壓縮** — 例外：session 極短、冇嘢值得記；限制：最少有「已完成／下一步／關鍵檔案路徑」三項，且必須落檔案
- **機會窗口一開就要揀時機** — 例外：正在跑不可中斷嘅指令；限制：唔准為咗「等更好嘅時機」而拖過 hard（hard 只係死線，唔係觸發點）→ `./protocol.md` §4
- **hard block 係警報** — 例外：fuse 未設好；限制：見到 hard 代表 fuse 太遲，要收尾報告 ＋ 提示改閾值，唔可以靜靜當正常
- **閾值係單一真相源** — 例外：無；限制：只改 config 檔，**唔准**手動改 settings.json 嘅 `reserveTokens` → `./reference.md` §5
- **壓縮由 agent 自己發起** — 例外：對話未過 keepRecentTokens（冇嘢可壓）；限制：**唔准叫用戶撳 `/compact`**；叫 `ctx_compact` → `./reference.md` §5
- **壓縮後唔准即刻報數** — 例外：無；限制：壓縮後 `percent` 讀到 `null`，要等下一輪模型回應先算數
- **原生保險絲必須對齊** — 例外：窗口細到 60% 已接近上限；限制：live fuse 會自動對齊；對唔上要報警 → `./setup.md` §1
- **subagent 一樣要守** — 例外：極短一次性任務；限制：派工要帶 skill，前台 subagent 要明掛 extension → `./protocol.md` §7
- **連續兩次壓縮都唔跌返 ≤50%** — 例外：無；限制：停低報告，唔准硬 loop 重試

## 交叉引用（純文字）

- 區間定義、閾值設定、量度方式、原生壓縮對齊、live fuse 機制 → 同套 `./reference.md`
- 量度時機、soft／hard 執行程序、交接筆記模板、驗證、subagent 接線 → 同套 `./protocol.md`
- 安裝、驗證、故障排除 → 同套 `./setup.md`
