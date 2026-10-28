# Dav Developer — 執行段規則

> 本檔係執行段嘅規則本體（2026-10-28 起由 `docs/sop/handbook/` 搬入本 skill）。
> Gate 1／2／3 嘅四欄定義 ＋ remediation → 同套 `./gates.md`；探針／回歸 → 同套 `./probes.md`。
> Gate 4 ＋ Gate 4.5 係**人手觸發**嘅 `dav-reviewer` skill 承載 → 唔喺本檔。

## 核心原則

在執行工作上，你要跟計劃文檔領取工作任務，也要做好校驗測試，去確保你做出來的結果是完整和完善的；

**核心原則：fail-fast gate** —— 不通過 gate = 不可進入反省段、不可宣稱任務完成。

## 點解要 fail-fast gate

> 「寫出來的東西會是錯誤，一行就有問題」—— 呢個係用戶最常見嘅痛點。

每一個 gate 都係「比上一個更慢但更深」嘅校驗。fail-fast 係因為：

- **Gate 2（lint）** 抓「一行就錯」嘅 syntax／shellcheck 警告 —— 修一行 10 秒
- **Gate 4（reviewer）** 抓「自查看不到」嘅盲點 —— 修一個檔案可能要 5 分鐘
- **Gate 漏過 → 累積到反省段先發現 → 已經遲咗**

關鍵心法：**先做最便宜嘅校驗**（Gate 2 只要 1 秒），再做最貴嘅校驗（Gate 4 reviewer 要 2–5 分鐘）；一旦發現錯誤，越早修越省時間。

## Agent 必做動作

**進到每一個 Gate 時**，Agent 必須喺對話明確引用該 Gate 嘅 `mandatory_phrase`（原文喺同套 `./gates.md`）。
**唔引用 ＝ 視為該 Gate 未觸發**（屬「偽裝通過」，依同套 `dav-router` skill 嘅違規回報規則處理；TD-016）。

當一個 Gate **失敗**時，Agent 必須：

1. **讀該 Gate 嘅 `remediation.strategy`**（見同套 `./gates.md`）
2. **照策略執行**（自動修／自動修有上限／問用戶）
3. **喺對話引用對應嘅 `mandatory_phrase` ＋ remediation 結果**
   - 例：「依 Gate 規範，Gate 2 (lint) 需要⋯已用 `auto_fix` 策略自動修好 3 個錯誤，而家重跑通過 ✅」

> **點解要呢層**：痛點係用戶反映「明明 test 做好了，但 agent 就停下來等」—— 根因係以前只寫咗 fail_action（禁止）冇寫補救，
> agent 預設保守 = 停下來等。加咗 remediation 之後：agent 知道失敗時該「自動修」定係「問用戶」；自動修有上限避免無限循環；
> 用戶只喺「真正需要決策」時先被打擾；整體等待時間預估減少 30–40%。

## 本機閘點跑（開發 loop vs push 前）

- **開發中（改完即跑）**：`bash scripts/check-all.sh --changed`
  → 只驗受改動影響嘅探針 ＋ 受影響嘅 mutant 列（≈ 20–40 秒；全量係 ≈ 4 分鐘）
  → 會明講邊步驟跳過同點解跳（base 打錯 → rc=2、冇改動 → rc=1，唔會靜靜哋當通過）
- **push 前（最後一道閘）**：`bash scripts/check-all.sh`（全量 11 步）
- ⚠️ `--changed` **唔等於全量閘通過** → 交付時要講明驗過嘅範圍（交付摘要嘅證據段）

## 例外：trust mode 進行中

trust 嘅紀律係「中途不問用戶」（見同套 `dav-trust` skill），所以：

1. Gate 失敗由 Agent 自行決策並寫進 trust-log（可推翻標記）
2. 需用戶決定嘅事寫進 need-you-help 檔，交由用戶喺 trust 結束後逐題回覆
3. Agent **唔可以**為咗「照 Gate 策略執行」而中途停下問用戶 —— 咁會直接破壞 trust 嘅執行段

（Gate 嘅預設策略係 `auto_fix`／`auto_fix_with_limit`／`ask_user`；trust 例外以本段為準。）
