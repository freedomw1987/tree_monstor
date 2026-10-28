# Dav Trust — Time Anchor（時間錨點）

> 本檔為 dav-trust 子檔。引用：`SKILL.md` §Step 1 + §規則「時間錨點」
> 主檔只保留 Step 1 簡述；完整時間紀律、date 指令範本、邊角情境都在本檔。

## 為什麼需要時間錨點

dav-trust 沒有系統時間能力時，所有時間戳都是 Agent 自己編的假時間 → 三個問題：

1. **deadline 不可驗證**：用戶說「跑 1 小時」，Agent 不知道現在幾點、deadline 幾點
2. **過 deadline 還在跑**：Agent 算錯時間差，過 deadline 沒停止
3. **trust-log 時間戳不可信**：Agent 可能寫 `## 14:05` 但其實是 16:30

**時間錨點** = 啟動時一次鎖死 `START_TS` + `DEADLINE_TS`，後續所有時間判斷都對照這兩個值。

## §1 啟動時鎖死時間錨點

### 1.1 動作

- 用 `date` 查系統時間（指令範本 → 同套本 skill 樣例檔（`./examples/time-anchor-formats.md`）§1）→ 取得當前時間
- 解析為絕對 deadline（見 §1.2）→ 鎖死 `START_TS` + `DEADLINE_TS`

### 1.2 解析 deadline（兩種形式）

- **「trust mode 跑 1 小時」** — Agent 動作：啟動時**必須問**：今天 15:23 還是明天 15:23？；結果：取得明確絕對時間
- **「trust mode 到 18:00 停」** — Agent 動作：直接解析為今天 18:00:00 +0800；結果：若已過 18:00 → 問用戶是否明天

### 1.3 啟動對話輸出（必含錨點）

- 輸出範本（可直接複製）→ 同套本 skill 樣例檔（`./examples/time-anchor-formats.md`）§2
- **關鍵**：錨點一啟動就鎖死、不准修改（見主檔底線規則 ③）

## §2 關鍵節點查時間（4 個 checkpoint + T5 trust-log 記錄）

不是每次動作都查時間，只在**4 個 checkpoint** 查；trust-log 每條記錄隨寫隨查（T5）＝第 5 個節點：

- **T1** — 節點：啟動 trust mode；動作：鎖死 START_TS + DEADLINE_TS
- **T2** — 節點：完成一個 Backlog；動作：算剩餘時間 → 判斷是否進入 L3（計算範例 → 同套本 skill 樣例檔（`./examples/time-anchor-formats.md`）§3；Agent 不必真跑
shell，內心用同樣邏輯判斷即可）
- **T3** — 節點：L3 收斂判斷；動作：確認「deadline 剩餘 < 10%」
- **T4** — 節點：退出 trust mode；動作：算總耗時 → 寫進 deliverable
- **T5** — 節點：trust-log 每條記錄；動作：對照當前時間寫絕對時間戳

## §3 trust-log 絕對時間戳格式

### 3.1 格式要求

- **必含 3 項**：
  1. `YYYY-MM-DD HH:MM:SS ±HHMM` 格式
  2. 階段標籤（啟動 / 執行 / 反省 / 提交 / 終局 / 執行期最小設計；另有「啟動前（規劃）」/「啟動前（設計）」用於 trust 啟動前完成的記錄）
  3. 問題 + 決策 + 理由 + 可推翻
- **事件標記慣例**：事件類記錄以 `📝` 開頭、置於 `**決策**` 欄首（例：`📝 用戶覆核：設計全缺啟動`、`📝 deadline 變更`、`📝 時間由用戶提供`、`📝 用戶叫停`）
- **進度錨點**：trust-log **檔頭**另需一行 `> 進度錨點: PHASE=…、DONE=…、NEXT=…、UPDATED_AT=…`，每完成一個 US 或階段切換就更新 —— 中斷（session 崩潰 /
context 壓縮）後靠它續跑（契約見 resume.md §2）
- 單條記錄格式範本 ＋ **反例**（沒日期 / 相對時間 / 相對 deadline 皆不可）→ 同套本 skill 樣例檔（`./examples/time-anchor-formats.md`）§4、§5

## §4 邊角情境（8 種）

- **4.1 跨午夜**（「X 小時後」跨過午夜）— Agent 動作：必須問用戶「是明天 X 點還是今天稍後」（epoch 換算：`date -d "now + 1 hour"`）
- **4.2 時區未指定 / 明示** — Agent 動作：未指定 → 用 Agent 所在時區（`date` 查到的 `+0800` 類）；明示 UTC／台北 → 鎖死該時區
- **4.3 啟動時 deadline 已過** — Agent 動作：停下問用戶「deadline 已過，請重新給」（唔可以啟動 trust mode）
- **4.4 用戶中途改 deadline** — Agent 動作：✅ 可更新錨點 + trust-log 加記錄 `📝 deadline 變更`；「不要 trust mode 了」→ 結束 trust mode
- **4.5 沙盒無法跑 `date`** — Agent 動作：停下問用戶當前時間（精確到秒）→ 用該時間作 `START_TS` → trust-log 第一條加 `📝 時間由用戶提供（非系統查詢）`；T2-T5 仍需用戶逐個提供
- **4.6 極短 deadline（< 10 分鐘）** — Agent 動作：啟動時明示警告「L3 不會啟動、僅能完成 0-1 個 Backlog」；跳過 L1→L2；預估時間 > deadline → 標 ⏸️ 不啟動 trust
- **4.7 DST 切換日**（春/秋令）— Agent 動作：用 `date -d "DEADLINE_TS"` 驗證系統是否自動處理 DST；⚠️ 跨 DST 日子**系統時間可能差 1 小時**；鎖死時用 epoch
換算（`date -d "DEADLINE"'+%s'`）避免字串比對漂移
- **4.8 Agent 與用戶時區不同** — Agent 動作：啟動時問用戶時區；同時記 `USER_TS` 同 `AGENT_TS`；trust-log 用用戶時區顯示、內部計算用 epoch

## §6 唔准等時間（deadline 係上限，唔係要坐夠鐘）

- **禁止**：`sleep` 長過 30 秒、長度證明唔到嘅 `sleep`（例：`sleep $(date +%s)`）、空轉迴圈（`while true`／`until false`）、淨係 `wait`。**機械守門**：`skills/dav-trust/extension/`（喺 trust mode 進行中擋走呢類 bash 指令，並回覆「應該點做」；門檻／開關 → `~/.pi/agent/dav-trust.json` 嘅 `maxSleepSeconds`／`enabled`）。
- **為什麼**：deadline 係「幾時一定要停」嘅授權上限；提早做完就係做完，坐夠鐘唔會多咗價值，只燒 token 同時間。
- **提早做完嘅正確出口**：L1（下一個 PENDING）→ L2（重訪 ⏸️）→ L3（`docs/` 預先規劃擴量）；**全部耗盡** → 收斂 → 同套 `dav-reviewer` skill 交付 → 輸出 `🏁 Trust Mode 已結束（提早完成）` → 明示「已無可做工作，要繼續請重新發起」（唔需要等到 deadline，亦唔准問用戶 —— 呢個係報告唔係提問）。
- **唯一例外**：真係等外部事件（background job／CI／port 起）→ 短 sleep（≤ 30 秒）＋ 必須講明等乜；要等好耐 → 用 `bg_wait`／subagent 或收窄 polling 上限，唔准 `sleep 3600`。
