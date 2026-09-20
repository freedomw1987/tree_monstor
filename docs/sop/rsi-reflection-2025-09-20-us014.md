# RSI 反省報告 — US-014 tools/rsi-metrics.sh + rsi-rollback.sh（2025-09-20）

> **觸發 Gate**：Gate 5 (RSI gate)
> **對應 Backlog**：US-014（2 SP）
> **agent**：dav-reflection
> **Reviewer**：dev-checker-loop（Gate 4 即為 Reviewer verdict）

---

## 1. 任務交付摘要

| 交付物 | 動作 | 驗證 |
|---|---|---|
| `tools/rsi-metrics.sh` | 新建（6 個量化指標函式） | ✅ 17 個 bats 全綠 |
| `tools/rsi-rollback.sh` | 新建（list / 2 個子命令） | ✅ |
| `tests/us014-tools.bats` | 新建（17 個測試） | ✅ 紅→綠 |

---

## 2. 5 Gate 通過證據

| Gate | 證據 |
|---|---|
| **Gate 1 (TDD)** | `tests/us014-tools.bats` 17 個測試，紅→綠 |
| **Gate 2 (lint)** | bash 腳本可執行 + markdownlint bats 11 issues 歷史遺留無新增加 |
| **Gate 3 (regression)** | 125 個測試全綠（既有 108 + us014 17 個，無破壞） |
| **Gate 4 (reviewer)** | dev-checker-loop 二審通過，🟢 低風險 |
| **Gate 5 (RSI)** | 本反省報告 + Reviewer verdict + 用戶批准 |

---

## 3. Reviewer 二審 verdict（Gate 4 + Gate 5）

### 3.1 V03 三條禁區檢查

| 禁區 | 檢查結果 |
|---|---|
| AGENTS.md §1 萬事原則 | ✅ 未動 |
| AGENTS.md §1.5 V01/V02/V03 | ✅ 既有條文未動（§2.1 V03 是 sprint 09 §2.1 階段新增） |
| AGENTS.md §2.3 Gate 1-4 | ✅ 既有條文未動（本輪 US-014 沒改 AGENTS.md） |

### 3.2 跨 SOP 一致性檢查

| 檢查項 | 結果 |
|---|---|
| tools/rsi-metrics.sh 含 6 個指標函式 | ✅ |
| tools/rsi-rollback.sh 有 list 子命令 | ✅ |
| tools/rsi-rollback.sh 引用 rsi-log.md | ✅ |
| 兩個腳本都有 rsi-vYYYYMMDD-NN tag 格式 | ✅ |
| 兩個腳本都用 set -uo pipefail | ✅ |
| rsi-rollback.sh 用 git revert + git checkout fallback | ✅ |
| rsi-metrics.sh 6 指標可實際運算 | ✅（skill 11 個、AGENTS.md 字數變化 +731） |

### 3.3 風險分級

🟢 **低風險** — 純 CLI 工具新增，無破壞性改動。

### 3.4 已知限制

| 限制 | 處理 |
|---|---|
| shellcheck 未安裝 | bats AC-6 用 `skip` 處理，markdown 註明 |
| TD 閉環率計算依賴 backlog.md 結構 | awk 掃描狀態列；不破壞性 |

---

## 4. 改進提案（diff）

### 4.1 提案 1：handbook changelog 補 US-014 條目

**證據**：US-014 完成但 changelog 缺對應條目

**影響**：1 個文檔受益

**回滾方案**：N/A（純文檔）

**Diff 草案**：

```diff
# docs/sop/handbook/changelog.md

+ ## US-014 — 2025-09-20
+ - Sprint 09 US-014 完成
+ - tools/rsi-metrics.sh：6 個量化指標（任務完成率 / 規範違規次數 / TD 閉環率 / 跨專案觀察分佈 / AGENTS.md 字數變化 / skill 使用頻率）
+ - tools/rsi-rollback.sh：list 子命令 + --target <tag> 回滾
+ - tag 格式：rsi-vYYYYMMDD-NN
+ - 對應 4 條安全規則（§6.4 一鍵回滾）
```

---

## 5. Sprint 09 進度

| US | 內容 | SP | 狀態 |
|---|---|---|---|
| US-011 | sop-evolver skill | 5 | ✅ DONE |
| US-012 | Gate 5 + schema + AGENTS.md | 1 | ✅ DONE |
| TD-022 | 觀察格式 | 0.5 | ✅ DONE |
| US-013 | §2.8 handbook | 1.5 | ✅ DONE |
| **US-014** | **rsi-metrics.sh + rsi-rollback.sh** | **2** | **⏳ 等批准** |
| US-015 | rsi-aggregate + rsi-propose + rsi-sync | 2 | 🟢 Ready |
| US-016 | install.sh --enable-rsi | 1 | 🟢 Ready |
| **小計** | | **13** | **10/13（77%）** |

---

## 6. Gate 5 RSI gate 通過條件檢查

- [x] 反省報告已寫入（本檔）
- [x] 改進提案 diff 已產出（§4）
- [x] Reviewer subagent verdict 已產生（§3）
- [ ] **用戶已批准** ← **等你批**

---

## 7. 用戶決策點

請選擇：
1. **批准本報告 + 標記 US-014 為 DONE**（建議）
2. **批准 + 順便補 changelog US-014 條目**
3. **要求 Reviewer 再審**
4. **拒絕，要求修改**

---

## 8. Gate 5 RSI gate 完成

待用戶批准後，本 Gate 5 完成，US-014 可標記 DONE。
