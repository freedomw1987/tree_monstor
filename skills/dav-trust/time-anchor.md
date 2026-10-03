# Dav Trust — Time Anchor（時間錨點）

> 本檔為 dav-trust v2.2 新增子檔。引用：`SKILL.md` §Step 1.5 + §規則「時間錨點」
>
> 主檔只保留 Step 1.5 簡述；完整時間紀律、date 指令範本、邊角情境都在本檔。

## 為什麼需要時間錨點

dav-trust 沒有系統時間能力時，所有時間戳都是 Agent 自己編的假時間 → 三個問題：

1. **deadline 不可驗證**：用戶說「跑 1 小時」，Agent 不知道現在幾點、deadline 幾點
2. **過 deadline 還在跑**：Agent 算錯時間差，過 deadline 沒停止
3. **trust-log 時間戳不可信**：Agent 可能寫 `## 14:05` 但其實是 16:30

**時間錨點** = 啟動時一次鎖死 `START_TS` + `DEADLINE_TS`，後續所有時間判斷都對照這兩個值。

---

## §1 啟動時鎖死時間錨點

### 1.1 動作

```bash
# 1. 查當前系統時間
date '+%Y-%m-%d %H:%M:%S %z'
```

```
# 輸出範例
2026-01-15 14:23:07 +0800
```

### 1.2 解析 deadline（兩種形式）

| 用戶說 | Agent 動作 | 結果 |
|--------|-----------|------|
| 「trust mode 跑 1 小時」 | 啟動時**必須問**：今天 15:23 還是明天 15:23？ | 取得明確絕對時間 |
| 「trust mode 到 18:00 停」 | 直接解析為今天 18:00:00 +0800 | 若已過 18:00 → 問用戶是否明天 |

### 1.3 啟動對話輸出（必含錨點）

```
🤖 啟動信任模式（Trust Mode）

📌 大目標:   完成 CRM 開發
⏰ Deadline: 2026-01-15 16:23:07 +0800（從現在 14:23:07 起的 2 小時後）
📋 流程:     SOP 5 階段（規劃 → 設計 → 執行 → 反省 → 提交）
🕐 時間錨點:
   - START_TS     = 2026-01-15 14:23:07 +0800
   - DEADLINE_TS  = 2026-01-15 16:23:07 +0800
   - TOTAL_BUDGET = 120 分鐘

從現在開始，我不會打擾你。
```

**關鍵**：錨點一啟動就鎖死、不准修改（見 §底線規則 3）。

---

## §2 關鍵節點查時間（節奏）

不是每次動作都查時間，只在**5 個關鍵節點**查：

| # | 節點 | 動作 |
|---|------|------|
| **T1** | 啟動 trust mode | 鎖死 START_TS + DEADLINE_TS |
| **T2** | 完成一個 Backlog | 算剩餘時間 → 判斷是否進入 L3 |
| **T3** | L3 收斂判斷 | 確認「deadline 剩餘 < 10%」 |
| **T4** | 退出 trust mode | 算總耗時 → 寫進 deliverable |
| **T5** | trust-log 每條記錄 | 對照當前時間寫絕對時間戳 |

### T2 範例：完成 Backlog 後判斷是否進入 L3

```bash
# 查當前時間
NOW=$(date '+%s')
REMAIN=$((DEADLINE_TS_EPOCH - NOW))
REMAIN_PCT=$((REMAIN * 100 / TOTAL_BUDGET_EPOCH))

# Agent 內部判斷
if [ "$REMAIN_PCT" -lt 10 ]; then
  echo "deadline 剩餘 ${REMAIN_PCT}% < 10%，主動收斂、不啟動 L3"
elif [ "$REMAIN_PCT" -lt 20 ]; then
  echo "deadline 剩餘 ${REMAIN_PCT}%，警告：L3 啟動前先評估時間"
fi
```

> ⚠️ Agent 不必真的跑 shell，內心用同樣邏輯判斷即可。

---

## §3 trust-log 絕對時間戳格式

### 3.1 格式

```markdown
## 2026-01-15 14:23:07 +0800 — Trust Mode 啟動

**問題**：...
**決策**：...
**理由**：...
**可推翻**：✅
```

**必含 4 元素**：
1. `YYYY-MM-DD HH:MM:SS ±HHMM` 格式
2. 階段標籤（啟動 / 規劃 / 設計 / 執行 / 反省 / 提交 / 終局）
3. 問題 + 決策 + 理由 + 可推翻

### 3.2 反例（不可）

```markdown
## 14:23 — 啟動         ❌ 沒日期、沒時區
## 剛才 — 啟動           ❌ 相對時間
## 2 小時前 — 啟動       ❌ 相對 deadline（v2.2 規定必用絕對時間戳）
```

---

## §4 邊角情境

### 4.1 跨午夜

```bash
# 假設 23:50 啟動、deadline 1 小時後 = 00:50 明天
date -d "now + 1 hour" '+%Y-%m-%d %H:%M:%S %z'
```

**若用戶給「X 小時後」跨越午夜** → Agent 必須問用戶「是明天 X 點還是今天稍後」。

### 4.2 時區

- 用戶沒指定時區 → 用 Agent 所在時區（`date` 查到的 `+0800` 之類）
- 用戶明示「UTC」/「台北」→ 鎖死該時區

### 4.3 deadline 已過

```bash
# 啟動時若 DEADLINE_TS 已過
NOW_EPOCH=$(date '+%s')
if [ "$DEADLINE_TS_EPOCH" -lt "$NOW_EPOCH" ]; then
  echo "⚠️ deadline 已過，Agent 必須停下、不能啟動 trust mode"
fi
```

**Agent 動作**：停下問用戶「deadline 已過，請重新給」。

### 4.4 用戶中途改 deadline

| 用戶訊息 | Agent 動作 |
|---------|-----------|
| 「改 deadline 到 18:00」 | ✅ 可更新錨點 + trust-log 加記錄 `📝 deadline 變更` |
| 「不要 trust mode 了」 | 結束 trust mode（見 SKILL.md §Step 5）|

### 4.5 沙盒環境無法跑 `date` shell

- **情境**：Agent 在受限沙盒（無 shell、無 `date` 指令）
- **Agent 動作**：
  1. 停下問用戶「環境無法跑 `date`，請給我當前時間（精確到秒）」
  2. 用用戶給的時間作為 `START_TS`
  3. trust-log 第一條加 `📝 時間由用戶提供（非系統查詢）`
- **限制**：T2-T5 仍需用戶提供每個關鍵節點的時間（無法自主算剩餘時間）

### 4.6 極短 deadline（< 10 分鐘）

- **情境**：用戶給「trust mode 跑 5 分鐘」
- **Agent 動作**：
  1. 啟動時明示警告「deadline 極短、L3 不會啟動、僅能完成 0-1 個 Backlog」
  2. 跳過 L1→L2 階段、直接評估單一 Backlog 是否值得做
  3. 若 Backlog 預估時間 > deadline → 標 ⏸️ 不啟動 trust

### 4.7 DST 切換日（春令/秋令）

- **情境**：3 月春令（少 1 小時）或 11 月秋令（多 1 小時）
- **Agent 動作**：
  1. 啟動時若跨 DST 日 → 用 `date -d "DEADLINE_TS"` 驗證系統是否自動處理 DST
  2. 若用戶給「今天 18:00」、deadline 跨 DST → 系統時間可能差 1 小時
  3. 鎖死時用 epoch 換算（`date -d "DEADLINE" '+%s'`）→ 避免字串比對 DST 漂移

### 4.8 Agent 與用戶時區不同

- **情境**：Agent 在 UTC、用戶在 +0800
- **Agent 動作**：
  1. 啟動時問用戶「您在哪個時區？」（`date` 查 Agent 自己的時區可能誤判）
  2. DEADLINE_TS 同時記兩個：`USER_TS = 2026-01-15 18:00 +0800`、`AGENT_TS = 2026-01-15 10:00 UTC`
  3. trust-log 用 **用戶時區**（USER_TS）顯示，內部計算用 epoch 避免漂移

---

## §5 與 SOP 規範的關係

| SOP 規範 | 與本檔關係 |
|---------|-----------|
| `AGENTS.md` §1.5 V01（一次一個問題）| 時間錨點鎖死 deadline 只問一次，合規 |
| `AGENTS.md` §1.5 V02（必標推薦）| 啟動對話明示時間錨點（START/DEADLINE）合規 |
| `AGENTS.md` §1.5 V03（SOP 改走二審）| 本次 v2.2 走 V03 Reviewer 二審通過 |
| `dav-skill-creater` 主檔行數上限 150 | 本檔外移避免主檔觸上限 |

---

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|--------|
| v2.2 | 2026-01-15 | 新增時間錨點子檔（含 5 個關鍵節點、絕對時間戳格式、跨午夜 / 時區 / 已過 deadline 邊角）| 用戶回饋「時間不準」；讓 deadline 可驗證、信任可審查；V03 Reviewer 二審通過 |