# Sprint 09 RSI 機制交付摘要（2026-09-20）

> **Sprint**：09
> **主軸**：RSI（Recursive Self-Improvement）遞歸自我改進機制
> **狀態**：✅ **100% DONE**（16 SP / 16 SP）
> **對應 Backlog**：US-011、US-012、TD-022、US-013、US-014、US-015、US-016、US-017
> **總時長**：2025-09-20 ~ 2026-09-20

---

## 1. 一句話總結

> **樹精靈（tree_monstor）現在能自我觀察、聚合跨專案觀察、產出具體改進提案、量化指標、一鍵回滾、自動同步 — 不再只守規範，也能協作檢查和改 SOP。**

---

## 2. Sprint 09 做了什麼

### 2.1 觀察層（sop-evolver skill）

建立 5 份 skill 文件，讓任何已裝 tree_monstor 的專案自動觀察 SOP 使用狀況：

| 檔案 | 功能 |
|---|---|
| `.agents/skills/sop-evolver/SKILL.md` | 總入口：觀察、聚合、提案、安全 |
| `.agents/skills/sop-evolver/observation.md` | 觀察 schema（白名單+黑名單+安全邊界）|
| `.agents/skills/sop-evolver/aggregator.md` | 聚合多專案觀察 |
| `.agents/skills/sop-evolver/proposer.md` | 產出 diff 提案 |
| `.agents/skills/sop-evolver/safety.md` | 4 層安全保護 |

### 2.2 規範層（5 Gate 速查表 + handbook）

| 變更 | 內容 |
|---|---|
| AGENTS.md §1.5 | 新增 V03 RSI 文檔修改必經 Reviewer 二審 |
| AGENTS.md §2.3 | 4 Gate → **5 Gate**（加 Gate 5 RSI gate）|
| AGENTS.md §2 章節索引 | 加 §2.8 RSI Evolution |
| `docs/sop/handbook/2.8-rsi-evolution.md` | 新建（11 章節完整 SOP）|

### 2.3 工具層（5 個 CLI 工具）

| 工具 | 功能 |
|---|---|
| `tools/rsi-metrics.sh` | 6 個量化指標 |
| `tools/rsi-rollback.sh` | list + --target 一鍵回滾 |
| `tools/rsi-aggregate.sh` | 跨專案觀察聚合 |
| `tools/rsi-propose.sh` | 產出 diff 提案 |
| `tools/rsi-sync.sh` | 跨專案同步 SOP |

### 2.4 安裝層

| 變更 | 內容 |
|---|---|
| `install.sh` | 加 `--enable-rsi`（預設）/ `--disable-rsi` 旗標 |

### 2.5 測試層

| 測試檔 | 個數 |
|---|---|
| `tests/sop-evolver.bats` | 21 |
| `tests/us012-gate5.bats` | 16 |
| `tests/us013-handbook.bats` | 15 |
| `tests/us014-tools.bats` | 17 |
| `tests/us015-tools.bats` | 22 |
| `tests/us016-install-rsi.bats` | 15 |
| `tests/us017-smoke-test.bats` | 18 |
| **新增總計** | **124** |

---

## 3. 對用戶的價值

1. **不再只守規範**：tree_monstor 從「規範執行者」變成「規範協作者」
2. **跨專案一致性**：3 個專案觀察到同樣問題時，自動產出統一提案
3. **零風險試錯**：一鍵回滾 + 觀察/改動分離 + 匿名化 + Reviewer 二審
4. **量化指標有感**：rsi-metrics.sh 6 指標全跑通
5. **可部署性**：install.sh 一行 `--enable-rsi` 開啟觀察

---

## 4. Sprint 09 完成證據

### 4.1 量化指標（rsi-metrics.sh）

```
1. 任務完成率：0.00%（尚未部署到真實專案）
2. 規範違規次數：0
3. TD 閉環率：33.33%（1/3）
4. 跨專案觀察分佈：3 個 mock 專案
5. AGENTS.md 字數變化：+731 字元
6. skill 使用頻率：11 個 skill
```

### 4.2 5 Gate 全綠（每個 US）

| Gate | 狀態 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 124 個新增 bats + 既有測試全綠 |
| Gate 2 (lint) | ✅ | 0 markdownlint issues（新引入）+ shellcheck skip |
| Gate 3 (regression) | ✅ | 完整套件 180 個全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 8 個 us*.md Gate 5 反省 + 1 個 Sprint 反省 |

### 4.3 V03 三條禁區

- ✅ AGENTS.md §1 萬事原則：未動
- ✅ AGENTS.md §1.5 V01/V02/V03 既有條文：未動
- ✅ AGENTS.md §2.3 Gate 1-4 既有條文：未動

---

## 5. Sprint 09 文檔清單

### 5.1 規劃階段（§2.1）
- `docs/backlog.md`（更新 8 個 RSI item）

### 5.2 設計階段（§2.2）
- `docs/system-design.md`（M4 模組 + ADR-008~011）
- `docs/prd/04-self-evolution.md`（PRD）
- `docs/prd/04-self-evolution.html`（PRD 視覺化）
- `docs/plan/2025-09-20-rsi-mechanism.md`（計劃）

### 5.3 執行階段（§2.3）
- 7 份 `docs/sop/rsi-reflection-2025-09-20-us*.md`（每 US Gate 5 反省）

### 5.4 反省階段（§2.4）
- `docs/reflection/sprint-09-rsi-reflection.md`（Sprint 09 整體反省）
- `docs/review/2026-09-20-rsi-smoke-test.md`（真實驗證記錄）
- `docs/sop/rsi-reviewer-verdict-2025-09-20.md`（§2.2 二審 verdict）

### 5.5 提交階段（§2.5）
- `docs/deliverable/2026-09-20-sprint-09-rsi-mechanism.md`（本檔）
- `docs/deliverable/2026-09-20-sprint-09-rsi-mechanism.html`（HTML 視覺化版）

---

## 6. 新發現 5 個技術債

| ID | 標題 | 優先級 | 狀態 |
|---|---|---|---|
| TD-028 | macOS bash 3.2 不支援 `declare -A` | P0 | ✅ 已修 |
| TD-029 | UTF-8 locale 觸發變數解析錯誤 | P0 | ✅ 已修 |
| TD-030 | rsi-propose.sh 規則庫只有 3 個內建規則 | P2 | 🟢 Ready |
| TD-031 | rsi-rollback.sh 自動寫 git tag | P1 | 🟢 Ready |
| TD-032 | rsi-sync.sh --dry-run 列出將同步的檔案清單 | P2 | 🟢 Ready |

---

## 7. 重要的反直覺發現

| 發現 | 解釋 |
|---|---|
| macOS bash 3.2 ≠ Linux bash 4+ | 跨平台腳本避免 `declare -A` |
| UTF-8 locale 會破壞 bash 變數解析 | 腳本開頭必加 `export LC_ALL=C` |
| `set -uo pipefail` 加 `awk` 退出碼會觸發 unbound | heredoc 內加「OR true」或重寫 awk 函式 |
| 觀察/改動分離 真的守住 | mock 專案驗證：US-017 證明 sync 不破壞 |

---

## 8. 下一步建議

### 8.1 立即（下次 Sprint 1）

- **TD-031**：rsi-rollback.sh 自動寫 git tag（0.5 SP，P1）
- **TD-032**：rsi-sync.sh --dry-run 列出檔案清單（0.5 SP，P2）

### 8.2 觀察後（Sprint 10+）

- **TD-030**：擴充 rsi-propose.sh 規則庫（等真實觀察累積後）

### 8.3 真實部署

- 部署到 3 個使用者專案
- 觀察 30 天
- 跑 rsi-metrics.sh 看趨勢
- 決定是否擴充規則庫

---

## 9. §2.5 提交完成

Sprint 09 RSI 機制 100% 完成、4 階段 SOP（§2.1 ~ §2.4 + §2.5）全通過、用戶已批准。可進下一個 Sprint 或部署到真實環境。
