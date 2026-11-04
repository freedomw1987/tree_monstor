---
name: dav-self-compact
description: >-
  context window 聰明區治理（跨 pi／Claude Code／Qoder）：量度使用率、判定 smart／soft／opportunity／hard 區、
  寫交接筆記、揀好邊界壓縮、壓縮後驗證。適用於長任務、多階段任務、長跑 subagent；
  不適用於一次性短答、純查資料、純技術問答。
---

# Dav Self Compact

## TL;DR

1. **做什麼**：守住聰明區 → 判定 host → 量度 → 判定區 → 寫交接筆記 → 揀好邊界壓縮 → 驗證（≤50%）。
2. **何時觸發**：長任務（多階段／多輪工具呼叫）、subagent 長跑、跨 session 續做。
3. **關鍵紀律**：交接筆記先於壓縮；opportunity 區一開就揀邊界壓縮；壓縮係 agent 嘅事。
4. **host 適配**：機械層（點量度／點觸發）各 agent 不同 → 先判定 host，再只讀對應 adapter。
5. **必產出物**：交接筆記（落檔案）＋ 壓縮後 zone 確認。

## 觸發時機

- ✅ **觸發**：長任務／多階段任務、連續 20＋ 次工具呼叫、跨 session 續做、subagent 長跑。
- ⚡ **建議**：進入新階段、或連續 20＋ 次工具呼叫後先量一次。
- ❌ **不觸發**：一次性短答、純查資料、純技術問答（壓縮只會白燒 token）。

## 流程（4 步）

- **Step 0 判定 host** — 讀 skill 上一層嘅 `dav-self-compact.host` 綁定檔；冇就按環境變數判
  （`PI_CODING_AGENT`／`CLAUDECODE`／`QODER_*`）；再判唔到 → 只做紀律層 → `./adapters.md` §1
- **Step 1 量度** — 用 adapter 指定嘅方式攞 tokens／窗口／percent；攞唔到 → 當 soft 區保守處理 → `./adapters.md` §2
- **Step 2 判定** — smart(<50%) 繼續／soft(≥50%) 準備／opportunity(≥55%) 壓縮窗口／hard(≥60%) 死線 → `./protocol.md` §1
- **Step 3 執行** — soft：寫交接筆記＋避開大讀取；opportunity：揀好邊界＋更新筆記＋用 adapter 嘅觸發方式壓縮；hard：只收尾 → `./protocol.md` §3
- **Step 4 驗證** — 壓縮後 usage 變 unknown，**下一輪回應之後**再量：必須 ≤50%（目標 20–35%）→ `./protocol.md` §5

## 規則 / 例外 / 限制

- **交接筆記先於壓縮** — 例外：session 極短、冇嘢值得記；限制：最少「已完成／下一步／關鍵檔案路徑」三項，且必須落檔案 → `./protocol.md` §4
- **opportunity 一開就要揀時機** — 例外：正在跑不可中斷嘅指令；限制：唔准拖過 hard（hard 係死線，唔係觸發點）→ `./protocol.md` §3
- **hard block 係警報** — 例外：保險絲未設好；限制：收尾報告＋提示改閾值，唔可以靜靜當正常 → `./protocol.md` §3
- **壓縮由 agent 發起，唔推俾用戶** — 例外：該 host 冇 agent 可呼叫嘅壓縮入口 → 用該 host 原生自動壓縮提早開火，唔好叫人撳 `/compact` → `./adapters.md` §3–§4
- **閾值係單一真相源** — 例外：無；限制：只改該 host 嘅閾值設定來源，唔好手改引擎保險絲欄位 → `./adapters.md` §2
- **壓縮後唔准即刻報數** — 例外：無；限制：usage 讀到 null／unknown，要等下一輪模型回應先算數 → `./protocol.md` §5
- **subagent 一樣要守** — 例外：極短一次性任務；限制：派工要帶 skill，long-run agent 要明掛量度工具 → `./adapters.md` §4
- **連續兩次壓縮都唔跌返 ≤50%** — 例外：無；限制：停低報告，唔准硬 loop 重試 → `./protocol.md` §5

## 交叉引用（純文字）

- 區間定義、量度程序、soft／opportunity／hard 執行程序、交接筆記模板、壓縮後驗證 → 同套 `./protocol.md`
- 各 host 嘅量度／觸發／交接筆記／驗證方式（pi／Claude Code／Qoder）→ 同套 `./adapters.md`
- 安裝、驗證、故障排除 → 同套 `./setup.md`
