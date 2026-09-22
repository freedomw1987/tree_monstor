---
name: sop-evolver
description: RSI（Recursive Self-Improvement）機制專用 skill。裝在專案裡只能**觀察**，裝回源 repo 才能**聚合 + 改 SOP**。包含觀察、聚合、提案、安全規則 4 個子模組。
---

# sop-evolver — RSI 遞歸自我改進 SOP skill

> **版本**：v1.0（2025-09-20 隨 Sprint 09 US-013 引入；Sprint 12 重建修復 symlink 循環）
> **對應 SOP**：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md)
> **對應 V03 紀律**：AGENTS.md §1.5 V03（RSI 文檔修改必經 Reviewer 二審）

---

## 1. 用途

本章定義 **RSI（Recursive Self-Improvement）機制** skill，包含：

- 觀察模式：寫 observation JSON 到 `~/.tree-monstor/observations/`
- 聚合模式：收集所有專案的 observation（**只在源 repo**）
- 提案：聚合結果變成「候選 diff」（含 confidence score）
- 安全規則：4 條不可違反

---

## 2. 兩種模式分離（核心安全原則）

| 模式 | 環境 | 能力 | 觸發點 |
|---|---|---|---|
| **觀察模式** | 任何裝了 tree_monstor 的專案 | **只寫** observation JSON | 任務完成時自動（Gate 5 觸發） |
| **聚合模式** | **源 repo**（`tree_monstor/`） | 收集觀察 + 聚合 + 產出 diff 提案 | 用戶打 `/reflect` 或 `/propose` |

**為什麼分離**：裝在用戶專案裡的 agent 沒有權限動用戶的 SOP 源頭。改 SOP 只能由用戶**在源 repo**明確觸發。

---

## 3. 子模組索引

| 子檔案 | 用途 |
|---|---|
| [`observation.md`](./observation.md) | 觀察模式規範（schema、寫入、錯誤處理）|
| [`aggregator.md`](./aggregator.md) | 聚合模式規範（收集、統計、去重）|
| [`proposer.md`](./proposer.md) | 提案生成（diff 模板、confidence score）|
| [`safety.md`](./safety.md) | 4 條不可違反安全規則 + Reviewer 二審 |

---

## 4. 快速開始

### 4.1 在「裝了 tree_monstor 的專案」（觀察模式）

```bash
./install.sh --enable-rsi
# 預設 — 部署 sop-evolver skill + 建觀察目錄
```

裝完後，每次任務完成時 Gate 5 自動觸發：

1. 寫 observation JSON 到 `~/.tree-monstor/observations/{project-id}/{YYYY-MM-DD}.json`
2. 觀察失敗不阻塞任務（log warning，跳過寫入）

### 4.2 在「源 repo」（聚合模式）

```bash
# cd 回源 repo
cd /path/to/tree_monstor

# 跑聚合
./tools/rsi-aggregate.sh --output docs/sop/rsi-aggregated-2026-09-20.md

# 看提案
./tools/rsi-propose.sh --report docs/sop/rsi-aggregated-2026-09-20.md --confidence 0.5

# ⚠️ Reviewer 二審（V03 必經）
# Agent 啟動 dev-checker-loop (Reviewer subagent) 看 verdict

# 批准後合併
git tag rsi-v{YYYYMMDD}-{NN}
./tools/rsi-sync.sh --all  # 同步到所有已裝專案
```

---

## 5. 觀察記錄存放位置

```
~/.tree-monstor/observations/{project-id}/{YYYY-MM-DD}.json
```

- `project-id` = `SHA256(安裝路徑).substring(0,8)`（**絕不存明文路徑**）

---

## 6. 4 條不可違反安全規則

詳見 [`safety.md`](./safety.md)。

1. **觀察/改動分離**：裝在專案裡的 agent 只能觀察，不能改 SOP
2. **匿名化**：存結構化信號，禁存 raw text / 路徑 / 程式碼
3. **Reviewer 二審必經**（V03）：所有 SOP / AGENTS.md 改動必經 dev-checker-loop
4. **一鍵回滾**：每次合併自動寫 git tag `rsi-v{YYYYMMDD}-{NN}`

---

## 7. 工具清單

| 工具 | 用途 |
|---|---|
| `tools/rsi-aggregate.sh` | 收集 + 聚合 observation → 報告 |
| `tools/rsi-propose.sh` | 報告 → 候選 diff 提案（含 confidence）|
| `tools/rsi-metrics.sh` | 量化指標計算（completion_rate / violation / trend）|
| `tools/rsi-sync.sh` | 源 repo SOP 同步到所有已裝專案 |
| `tools/rsi-rollback.sh` | 自動 git tag + 一鍵回滾 |

---

## 8. 與 SOP 其他章節關係

| 章節 | 關係 |
|---|---|
| §2.1 規劃 | RSI 是 §2.4 反省 → §2.1 規劃的自動化閉環 |
| §2.3 執行 | Gate 5（RSI gate）由 sop-evolver skill 觸發 |
| §2.5 提交 | diff 合併後必更新 rsi-log.md + 同步到其他專案 |

---

## 9. 相關文件

- SOP 完整版：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md)
- PRD：[`docs/prd/04-self-evolution.md`](../../../docs/prd/04-self-evolution.md)
- Backlog：[`docs/backlog.md`](../../../docs/backlog.md)
- 系統設計：[`docs/system-design.md`](../../../docs/system-design.md)
- 設計文件：[`docs/plan/2025-09-20-rsi-mechanism.md`](../../../docs/plan/2025-09-20-rsi-mechanism.md)

---

## 10. 版本

- v1.0（2025-09-20）— 隨 Sprint 09 US-013 引入
- v1.0-fix（2026-09-20）— Sprint 12 重建，源檔案修復 symlink 循環
