# Sprint 13 交付 — RSI 主動化（2026-09-20）

> **對應 §2.5 dav-submitter**
> **Sprint**：Sprint 13 RSI 主動化
> **SP**：6 SP（全部完成）
> **狀態**：✅ DONE

---

## 1. Sprint 13 概要

Sprint 13 為 RSI 機制加入 3 個主動化能力：

- **JSON 標準化**（TD-037）：rsi-propose 加 JSON output
- **1 鍵部署**（US-023）：rsi-deploy.sh 自動部署小型工具
- **Dry-run 預覽**（US-024）：rsi-rollback 先看再滾

加上 1 個研究項目：

- **跨專案規則去重研究**（SP-005）：3 個 mock 場景、明確結論。結論：AI 提建議，人類決策合併；規則庫 ≤ 20 條

---

## 2. 量化指標

| 指標 | Sprint 12 末 | Sprint 13 末 | 變化 |
|---|---|---|---|
| 工具總數 | 12 | 13（+rsi-deploy.sh） | +1 |
| bats 累計 | 250 | 280 | +30 |
| FR 累計 | 20 | 24（+4.21~4.24） | +4 |
| 規則庫 | 12 | 12 | 0 |
| Sprint 09-13 SP | 32.5 | **38.5** | **+6** |

---

## 3. 變更檔案清單

### 3.1 新建工具（1 個）

| 工具 | SP | 用途 |
|---|---|---|
| `tools/rsi-deploy.sh` | 2 | 1 鍵部署小型 web app（含 python / node）|

### 3.2 工具擴充（2 個）

| 工具 | SP | 改動 |
|---|---|---|
| `tools/rsi-propose.sh` | 1 | 加 `--output-format json` |
| `tools/rsi-rollback.sh` | 1 | 加 `--dry-run` |

### 3.3 新建 bats（4 檔，30 個測試）

| bats 檔 | 數量 |
|---|---|
| `tests/td037-propose-json.bats` | 6 |
| `tests/us023-rsi-deploy.bats` | 10 |
| `tests/us024-rsi-rollback-dryrun.bats` | 8 |
| `tests/sp005-rule-dedup.bats` | 6 |

### 3.4 新建文檔

| 文檔 | 章節 |
|---|---|
| `docs/research/2026-09-20-cross-project-rule-dedup.md` | 8 章節 |
| `docs/sop/rsi-reviewer-verdict-2026-09-20-sprint13.md` | 11 章節 |
| `docs/sop/rsi-reflection-2026-09-20-td037.md` | 6 章節 |
| `docs/sop/rsi-reflection-2026-09-20-us023.md` | 6 章節 |
| `docs/sop/rsi-reflection-2026-09-20-us024.md` | 6 章節 |
| `docs/sop/rsi-reflection-2026-09-20-sp005.md` | 7 章節 |
| `docs/reflection/sprint-13-rsi-active-reflection.md` | 8 章節 |

---

## 4. RSI 完整閉環（Sprint 13 加 3 能力）

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

## 5. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 30 新加 bats + 紅→綠 |
| Gate 2 (lint) | ✅ | bash -n + markdownlint 0 |
| Gate 3 (regression) | ✅ | 跑 9 個既有 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 + Reviewer verdict APPROVED |
| Gate 5 (RSI) | ✅ | 4 份 Gate 5 反省 |

---

## 6. Sprint 09-13 累計（38.5 SP）

| Sprint | SP | 主軸 | 狀態 |
|---|---|---|---|
| Sprint 09 | 16 | RSI 機制建立 | ✅ |
| Sprint 10 | 5 | RSI 增強（tag + dry-run + 規則庫）| ✅ |
| Sprint 11 | 6 | RSI 真實部署 + 規則擴充 | ✅ |
| Sprint 12 | 5.5 | RSI 回顧 + 告警 | ✅ |
| **Sprint 13** | **6** | **RSI 主動化（JSON + 1鍵部署 + dry-run）** | **✅** |
| **累計** | **38.5** | | **100%** |

---

## 7. Sprint 14 候選（5 個，3 SP 推薦）

| ID | 標題 | SP | 優先級 |
|---|---|---|---|
| US-025 | rsi-sync.sh dry-run | 1 | P3 |
| US-026 | rsi-propose --show-similar | 1 | P3 |
| US-027 | rsi-propose YAML output | 1 | P3 |
| US-028 | rsi-deploy go/rust | 2 | P3 |
| TD-038 | rules/REVIEW.md 自動產生 | 1 | P3 |

**Sprint 14 推薦**：US-025 + US-026 + TD-038 = 3 SP

---

## 8. 核心學習（Sprint 13）

### 8.1 bash 函式定義位置

函式定義必須在呼叫之前（或 main 函式內）。檔案末尾定義會「command not found」。

### 8.2 python json.dumps 與中文

預設 `ensure_ascii=True`，中文變 `\uXXXX`。傳 `ensure_ascii=False` 保留 UTF-8。

### 8.3 awk 三元運算被截斷

`... > 1 ? 1 : (...)` 的 `> 1` 被誤判為輸出重定向。改用 `if/else` 即可。

### 8.4 TD-035 隔離層通用

`set +u` / `set -u` 隔離層可在任何函式內用，避免「unbound variable」報錯，不影響 caller。

---

## 9. 完成

Sprint 13 結束。RSI 從「被動監控」進化到「主動化」：

- [x] JSON 標準化輸出
- [x] 1 鍵部署（30 分鐘 → 5 分鐘）
- [x] Dry-run 預覽回滾
- [x] 跨專案規則去重研究（AI 提建議、人類決策）
- [x] 6 SP 全數完成
- [x] 30 新加 bats 全綠
- [x] 9 個既有 bats 全綠

---

## 10. 版本

- v1.0（2026-09-20）— Sprint 13 交付
