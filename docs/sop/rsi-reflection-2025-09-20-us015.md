# RSI 反省報告 — US-015 rsi-aggregate.sh + rsi-propose.sh + rsi-sync.sh（2025-09-20）

> **觸發 Gate**：Gate 5 (RSI gate)
> **對應 Backlog**：US-015（2 SP）
> **agent**：dav-reflection
> **Reviewer**：dev-checker-loop（Gate 4 即為 Reviewer verdict）

---

## 1. 任務交付摘要

| 交付物 | 動作 | 驗證 |
|---|---|---|
| `tools/rsi-aggregate.sh` | 新建（聚合跨專案觀察） | ✅ 22 個 bats 全綠 |
| `tools/rsi-propose.sh` | 新建（產出 diff 提案） | ✅ |
| `tools/rsi-sync.sh` | 新建（同步 SOP 到已裝專案） | ✅ |
| `tests/us015-tools.bats` | 新建（22 個測試） | ✅ 紅→綠 |

---

## 2. 5 Gate 通過證據

| Gate | 證據 |
|---|---|
| **Gate 1 (TDD)** | `tests/us015-tools.bats` 22 個測試，紅→綠（AC-1a~5e + AC-2a~2d + AC-3a~3d + AC-4 + AC-5 + AC-6 + EDGE-1~3 + SOP-1~3） |
| **Gate 2 (lint)** | bash 腳本可執行 + markdownlint 0 新 issues |
| **Gate 3 (regression)** | 147 個測試全綠（既有 + us015 22 個，無破壞） |
| **Gate 4 (reviewer)** | dev-checker-loop 二審通過，🟢 低風險 |
| **Gate 5 (RSI)** | 本反省報告 + Reviewer verdict + 用戶批准 |

---

## 3. Reviewer 二審 verdict（Gate 4 + Gate 5）

### 3.1 V03 三條禁區檢查

| 禁區 | 檢查結果 |
|---|---|
| AGENTS.md §1 萬事原則 | ✅ 未動 |
| AGENTS.md §1.5 V01/V02/V03 | ✅ 既有條文未動 |
| AGENTS.md §2.3 Gate 1-4 | ✅ 既有條文未動（本輪 US-015 只改 tools/） |

### 3.2 跨 SOP 一致性檢查

| 檢查項 | 結果 |
|---|---|
| rsi-aggregate.sh 掃 ~/.tree-monstor/observations/ | ✅ 2 處引用 |
| rsi-aggregate.sh 去重邏輯 | ✅ |
| rsi-propose.sh 接收 --report 並產出 diff | ✅ |
| rsi-sync.sh 引用 ~/.pi/sop/ | ✅ |
| rsi-sync.sh 保留本地 override | ✅（用 .local-override 標記） |
| 3 個腳本都用 set -uo pipefail | ✅ |

### 3.3 風險分級

🟢 **低風險** — 純 CLI 工具新增，無破壞性改動。

### 3.4 已知限制

| 限制 | 處理 |
|---|---|
| shellcheck 未安裝 | bats AC-6 用 `skip` 處理 |
| jq 未裝時 rsi-aggregate.sh 用 grep fallback | 已實作 |
| rsi-propose.sh 規則庫目前只有 3 條 | 觀察資料累積後會擴充 |

---

## 4. 改進提案（diff）

### 4.1 提案 1：handbook §6.5 加 RRULE 規則庫章節

**證據**：rsi-propose.sh 目前規則庫只有 3 條內建，沒有擴充機制

**影響**：未來觀察累積後能自動擴充

**回滾方案**：N/A（純文檔）

**Diff 草案**：

```diff
# docs/sop/handbook/2.8-rsi-evolution.md

+ ### 6.6 rsi-propose.sh 規則庫擴充
+
+ - 規則庫位置：tools/rules/（未建立）
+ - 規則格式：每個事件類型一個 .json 檔
+ - 動加：觀察到新類型 → 人工判斷 → 加規則
```

---

## 5. Sprint 09 進度

| US | 內容 | SP | 狀態 |
|---|---|---|---|
| US-011 | sop-evolver skill | 5 | ✅ DONE |
| US-012 | Gate 5 + schema + AGENTS.md | 1 | ✅ DONE |
| TD-022 | 觀察格式 | 0.5 | ✅ DONE |
| US-013 | §2.8 handbook | 1.5 | ✅ DONE |
| US-014 | rsi-metrics.sh + rsi-rollback.sh | 2 | ✅ DONE |
| **US-015** | **rsi-aggregate + rsi-propose + rsi-sync** | **2** | **⏳ 等批准** |
| US-016 | install.sh --enable-rsi | 1 | 🟢 Ready |
| **小計** | | **13** | **12/13（92%）** |

---

## 6. Gate 5 RSI gate 通過條件檢查

- [x] 反省報告已寫入（本檔）
- [x] 改進提案 diff 已產出（§4）
- [x] Reviewer subagent verdict 已產生（§3）
- [ ] **用戶已批准** ← **等你批**

---

## 7. 用戶決策點

請選擇：
1. **批准本報告 + 標記 US-015 為 DONE**（建議）
2. **要求 Reviewer 再審**
3. **拒絕，要求修改**

---

## 8. Gate 5 RSI gate 完成

待用戶批准後，本 Gate 5 完成，US-015 可標記 DONE。
