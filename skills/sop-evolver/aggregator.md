# aggregator.md — 聚合模式規範

> **對應 SKILL.md**：[`SKILL.md`](./SKILL.md) §3 子模組
> **對應 SOP**：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md) §4

---

## 1. 用途

定義「聚合模式」的完整規範：如何收集所有專案的 observation → 統計 → 產出聚合報告。

**聚合模式只能在源 repo**（`tree_monstor/`）跑。裝在用戶專案裡的 agent 不能跑。

---

## 2. 何時跑聚合

```bash
# 1. 用戶 cd 回源 repo
cd /path/to/tree_monstor

# 2. 打 /reflect 或手動跑工具
./tools/rsi-aggregate.sh --output docs/sop/rsi-aggregated-{YYYY-MM-DD}.md
```

預設聚合**最近 30 天**的觀察，可用 `--days N` 改。

---

## 3. 聚合流程

```
1. 掃描 ~/.tree-monstor/observations/*/YYYY-MM-DD.json
   ↓
2. 對每個檔案做 schema 驗證（白名單）
   ↓
3. 按 project_id 分組
   ↓
4. 計算每個信號的：
   - frequency（總次數）
   - projects（跨專案數）
   - confidence = min(1.0, freq × 0.05 + projects × 0.1)
   ↓
5. 排序、統計
   ↓
6. 產出 docs/sop/rsi-aggregated-{YYYY-MM-DD}.md
```

---

## 4. 聚合報告結構

```markdown
# RSI 聚合報告 — YYYY-MM-DD

## 1. 觀察資料概覽

| 項目 | 數量 |
|---|---|
| 觀察天數 | 30 |
| 觀察專案數 | 5 |
| 總 observation 數 | 150 |
| 觀察失敗率 | < 5% |

## 2. 信號排序

| 信號類型 | 頻次 | 跨專案數 | confidence |
|---|---|---|---|
| ... | ... | ... | ... |

## 3. 違規事件

（若 gate_results 有 fail 列在此）

## 4. 跨專案分佈

| 專案 | observation 數 | 主要失敗模式 |
|---|---|---|
| a3b4c5d6 | 30 | (無) |
| ... | ... | ... |
```

---

## 5. 工具

### 5.1 rsi-aggregate.sh

```bash
./tools/rsi-aggregate.sh [options]

--days N          # 聚合天數（預設 30）
--output FILE     # 輸出報告路徑（預設 docs/sop/rsi-aggregated-{date}.md）
--min-freq N      # 最小頻次（預設 1）
```

### 5.2 rsi-metrics.sh

```bash
./tools/rsi-metrics.sh [options]

--days N          # 計算天數（預設 1）
trend_history     # 子命令：30 天滑動趨勢
```

---

## 6. 故障排除

| 症狀 | 處理 |
|---|---|
| 聚合報告空 | 確認 `ls ~/.tree-monstor/observations/` 有 JSON 檔 |
| 觀察時間範圍不對 | 改 `--days` 參數 |
| Schema 拒絕 | 對照 [observation.md](./observation.md) §3 白名單 |

---

## 7. 版本

- v1.0（2025-09-20）— 隨 Sprint 09 US-013 引入
- v1.0-fix（2026-09-20）— Sprint 12 重建，源檔案修復
