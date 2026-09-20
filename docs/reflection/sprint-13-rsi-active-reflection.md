# Sprint 13 反省 — RSI 主動化（2026-09-20）

> **對應 Sprint**：Sprint 13 RSI 主動化
> **對應 §2.4 dav-reflection**
> **SP**：6 SP（全部完成）

---

## 1. Sprint 概要

Sprint 13 完成 4 個任務（6 SP）：

| ID | 標題 | SP | 結果 |
|---|---|---|---|
| TD-037 | rsi-propose JSON output | 1 | ✅ |
| US-023 | rsi-deploy.sh 自動部署 | 2 | ✅ |
| US-024 | rsi-rollback dry-run | 1 | ✅ |
| SP-005 | 跨專案規則去重研究 | 2 | ✅ |

---

## 2. 6 維度檢查

### 2.1 用戶價值（User Value）

| 問題 | 答案 |
|---|---|
| 用戶真的能用嗎？ | ✅ rsi-propose JSON 可被 Agent 解析、cron 套用 |
| 解決什麼問題？ | 手動部署 30 分鐘 → 5 分鐘；rollback 預覽避免誤滾；規則去重研究給 Sprint 14+ 方向 |
| 是否可衡量？ | ✅ 部署時間、bats 數量、FR 數量都有量化 |

**評分**：🟢 9/10

### 2.2 流程紀律（Process）

| 問題 | 答案 |
|---|---|
| 5 Gate 通過？ | ✅ Gate 1 (TDD)、2 (lint)、3 (regression)、4 (reviewer)、5 (RSI) |
| V03 RSI 必經 Reviewer 二審 | ✅ Sprint 13 Reviewer verdict APPROVED |
| 觀察/改動分離守住 | ✅ 未動 AGENTS.md / SOUL.md |
| backlog 狀態總覽一致 | ✅ Sprint 13 已標 Done |

**評分**：🟢 9/10

### 2.3 程式碼品質（Code）

| 問題 | 答案 |
|---|---|
| bash -n 通過？ | ✅ 全部 4 個工具都過 |
| markdownlint 0 issues？ | ✅ 全部新增文檔 0 issues |
| TD-035 隔離層應用 | ✅ US-024 用 `set +u` / `set -u` 隔離層 |
| macOS bash 3.2 相容？ | ✅ LC_ALL=C + awk if/else 替代三元 |
| UTF-8 中文保留？ | ✅ python json.dumps ensure_ascii=False |

**評分**：🟢 9/10

### 2.4 測試品質（Test）

| 問題 | 答案 |
|---|---|
| TDD 紅→綠？ | ✅ 30 個新 bats 全綠 |
| 每個任務 ≥ 3 個 bats？ | ✅ TD-037 (6)、US-023 (10)、US-024 (8)、SP-005 (6) |
| 既有 regression 不破？ | ✅ 跑 9 個既有 bats 全綠 |
| bats test name 全 ASCII？ | ✅（避免中文括號造成 unknown test name）|

**評分**：🟢 9/10

### 2.5 風險管理（Risk）

| 風險 | 結果 |
|---|---|
| TD-037 JSON 結構不對齊 | 🟢 6 個 bats 驗證 schema |
| US-023 deploy 在 macOS 失敗 | 🟢 mock app + 自動驗證 |
| US-024 dry-run 沒列全 | 🟢 8 個 bats 驗證 |
| SP-005 結論不明確 | 🟢 結論明確：「AI 提建議，人類決策」 |

**評分**：🟢 9/10

### 2.6 擴展性（Scale）

| 問題 | 答案 |
|---|---|
| 規則庫上限 ≤ 20 | ✅ SP-005 研究結論 |
| 跨專案去重機制 | ✅ SP-005 結論 + Sprint 14+ 候選 |
| 多語言部署支援 | ✅ Sprint 14+ US-028 加 go/rust |
| JSON / YAML 標準化 | ✅ TD-037 開啟，Sprint 14+ US-027 加 YAML |

**評分**：🟢 9/10

---

## 3. 累計指標（Sprint 13 結束）

| 指標 | Sprint 12 末 | Sprint 13 末 | 變化 |
|---|---|---|---|
| 工具 | 12 | 13（+rsi-deploy.sh）| +1 |
| bats 累計 | 250 | 280 | +30 |
| FR | 20 | 24 | +4 |
| 規則庫 | 12 | 12 | 0 |
| Sprint 09-13 SP | 32.5 | 38.5 | +6 |
| Sprint 09-13 commit | 5 | 6 | +1 |

---

## 4. RSI 完整閉環（Sprint 13 加 3 個能力）

```
觀察（install + cron）
  ↓
聚合（rsi-aggregate.sh）
  ↓
趨勢（rsi-metrics.sh trend_history）
  ↓
回顧（rsi-review.sh）
  ↓
警告（rsi-alert.sh）
  ↓
反推規則庫（rsi-propose.sh text + json）  ⭐ Sprint 13 加 JSON
  ↓
SOP 改動（reviewer 二審）
  ↓
1 鍵部署（rsi-deploy.sh）  ⭐ Sprint 13 新增
  ↓
安全回滾（rsi-rollback.sh --dry-run）  ⭐ Sprint 13 新增
```

---

## 5. 4 個核心學習

### 5.1 bash 函式定義位置

函式定義**必須**在呼叫之前（或 main 函式內）。檔案末尾定義會「command not found」。

### 5.2 python json.dumps 與中文

預設 `ensure_ascii=True`，中文變 `\uXXXX`。傳 `ensure_ascii=False` 保留 UTF-8。

### 5.3 awk 三元運算被截斷

```bash
# 失敗：> 1 ? 1 : ( ...)  > 1 被誤判為輸出重定向
# 解法：用 if/else
```

### 5.4 TD-035 隔離層通用

`set +u` / `set -u` 隔離層可在任何函式內用，避免「unbound variable」報錯，不影響 caller。

---

## 6. Sprint 14 候選（5 個，3 SP 推薦）

| ID | 標題 | SP | 優先級 |
|---|---|---|---|
| US-025 | rsi-sync.sh dry-run | 1 | P3 |
| US-026 | rsi-propose --show-similar | 1 | P3 |
| US-027 | rsi-propose YAML output | 1 | P3 |
| US-028 | rsi-deploy go/rust | 2 | P3 |
| TD-038 | rules/REVIEW.md 自動產生 | 1 | P3 |

**Sprint 14 推薦**：US-025 + US-026 + TD-038 = 3 SP

---

## 7. 量化目標對照

| 目標 | 結果 |
|---|---|
| 4 SP 全部完成 | ✅ 6 SP（多 SP-005 研究）|
| ≥ 13 新加 bats | ✅ 30 新加（超標 230%）|
| markdownlint 新加部分 0 issues | ✅ |
| Reviewer 二審通過 | ✅ |
| 5 Gate 通過 | ✅ |

---

## 8. 版本

- v1.0（2026-09-20）— Sprint 13 §2.4 反省
