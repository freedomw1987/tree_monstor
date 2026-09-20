# Sprint 12 反省 — RSI 回顧 + 回歸警告（2026-09-20）

> **Sprint**：Sprint 12
> **SP**：5.5
> **狀態**：✅ **DONE**

## 1. Sprint 12 概覽

| ID | 類型 | 標題 | SP | 狀態 |
|---|---|---|---|---|
| TD-035 | TD | 修 `local -a arr=()` 在 `set -u` 下報 unbound | 0.5 | ✅ |
| US-022 | US | rsi-metrics 加回歸警告 | 2 | ✅ |
| US-021 | US | 真實觀察 14 天後回顧 + 從 cron.log 反推新規則 | 3 | ✅ |

## 2. 6 維度檢查

### 2.1 UX/UI

Sprint 12 為基礎設施型 sprint，無直接 UX/UI 變動。 ✅

### 2.2 RWD

N/A（no RWD-related changes）

### 2.3 技術債

| 項目 | 解決 | 備註 |
|---|---|---|
| TD-035 (Sprint 11 留下) | ✅ 解決 | `set +u` / `set -u` 隔離層 |
| TD-036 (Sprint 11 留下) | ✅ 解決 | TD-035 順手解決了 |
| TD-037 (Sprint 12 預留) | 🟡 Sprint 13 | `--output-format json` for rsi-propose |

### 2.4 可維護性

Sprint 12 新加 3 工具，每個都對應：

- `rsi-alert.sh` ←→ `us022-rsi-alert.bats`（5 bats）
- `rsi-review.sh` ←→ `us021-rsi-review.bats`（6 bats）

每個工具都加了 `--help`、markdownlint 0 issues、bats 涵蓋 5 個場景（empty / normal / threshold / custom / fail）。 ✅

### 2.5 測試覆蓋率

| 指標 | Sprint 11 末 | Sprint 12 末 | 變化 |
|---|---|---|---|
| 工具 | 10 | 12（+alert +review）| +2 |
| bats | 244 | 250 | +6 |
| 規則庫 | 12 | 12 | 0 |
| FR | 17 | 20 | +3 |

### 2.6 需求對齊

| 用戶故事 | AC | 達成 |
|---|---|---|
| US-021 | 14 天回顧 + ≥6 bats + 0 markdownlint | ✅ |
| US-022 | 回歸警告 + ≥5 bats + 0 markdownlint | ✅ |
| TD-035 | 修 set -u + ≥4 bats | ✅ |

## 3. Sprint 12 量化指標

| 指標 | Sprint 11 末 | Sprint 12 末 | 變化 |
|---|---|---|---|
| SP | 6 | 5.5 | -0.5（技術債 0.5）|
| 工具 | 10 | 12 | +2 |
| 規則庫 | 12 | 12 | 0 |
| bats | 244 | 250 | +6 |
| FR | 17 | 20 | +3 |

## 4. Sprint 12 重要發現

### 4.1 RSI 從「被動觀察」到「主動監控」

```
舊：observe → aggregate → propose → 修改 SOP（手動）
新：observe → aggregate → trend_history → review（自動）+ alert（主動監控）→ propose → 修改 SOP
```

### 4.2 14 天回顧是必經儀式

Sprint 11 部署指南完成 + cron 自動跑 14 天，但 Sprint 12 才補上「跑完必有人類回顧」機制（rsi-review.sh）。

### 4.3 主動監控避免靜默失效

「裝了但壞了」是 RSI 最大風險 — rsi-alert.sh 觀察數下降 30%+ 觸發告警，避免「裝了但壞了」的靜默失效。

### 4.4 macOS bash 3.2 + set -u 坑

Sprint 11 留下的 TD-035 是 macOS bash 3.2 不支援 `local -a arr=()` 的坑。用 `set +u` / `set -u` 隔離層解決，不需改 caller。

## 5. Sprint 13+ 候選項

| ID | 類型 | 標題 | 預估 SP |
|---|---|---|---|
| TD-037 | TD | `--output-format json` for rsi-propose | 0.5 |
| US-023 | US | rsi-deploy.sh 自動部署指南 | 2 |
| US-024 | US | rsi-rollback 加 dry-run | 1 |
| SP-005 | SP | Sprint 13 全部 sprint | 5 |

## 6. Sprint 12 累計（Sprint 09-12 全部）

| Sprint | SP | 狀態 |
|---|---|---|
| Sprint 09 RSI 機制建立 | 16 | ✅ |
| Sprint 10 RSI 增強 | 5 | ✅ |
| Sprint 11 RSI 真實部署 | 6 | ✅ |
| Sprint 12 RSI 回顧 + 告警 | 5.5 | ✅ |
| **累計** | **32.5** | |

## 7. 完成

Sprint 12 結束。RSI 機制從「觀察 → 聚合 → 改 SOP」完整閉環，且加上「回顧」+「告警」兩個主動監控能力。
