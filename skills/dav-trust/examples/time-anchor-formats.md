# dav-trust 樣例檔 — 時間錨點格式（date 指令 / 啟動輸出 / 計算範例）

> 配合 [`../SKILL.md`](../SKILL.md) 同 [`../time-anchor.md`](../time-anchor.md) 使用：呢度只放**可直接複製嘅範本**，
> 紀律（4 個 checkpoint / T5 / 絕對時間戳 / 跨午夜 / 時區）→ 同套本 skill 子檔（`../time-anchor.md`）。

---

## 1. 查系統時間（date 指令範本）

```bash
# 查當前系統時間
date '+%Y-%m-%d %H:%M:%S %z'
```

```
# 輸出範例
2026-01-15 14:23:07 +0800
```

## 2. 啟動對話輸出範本（必含兩個錨點 + 流程 + 底線提醒）

```
🤖 啟動信任模式（Trust Mode）

📌 大目標:   完成 CRM 開發
⏰ Deadline: 2026-01-15 16:23:07 +0800（從現在 14:23:07 起的 2 小時後）
📋 流程:     SOP 執行段（執行 → 反省 → 提交；規劃 / 設計為啟動前置條件）
🕐 時間錨點:
   - START_TS     = 2026-01-15 14:23:07 +0800
   - DEADLINE_TS  = 2026-01-15 16:23:07 +0800
   - TOTAL_BUDGET = 120 分鐘

從現在開始，我不會打擾你。
```

## 3. T2 計算範例（完成一個 Backlog 後判斷是否進入 L3）

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

## 4. trust-log 絕對時間戳記錄範本（單條代答）

```markdown
#
# 2026-01-15 14:23:07 +0800 — Trust Mode 啟動

**問題**：...
**決策**：...
**理由**：...
**可推翻**：✅
```

## 5. 反例（不可）

```markdown
#
# 14:23 — 啟動         ❌ 沒日期、沒時區

## 剛才 — 啟動           ❌ 相對時間
## 2 小時前 — 啟動       ❌ 相對 deadline（v2.2 規定必用絕對時間戳）
```
