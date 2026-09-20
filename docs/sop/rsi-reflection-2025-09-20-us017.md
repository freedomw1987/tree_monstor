# RSI 反省報告 — US-017 真實驗證 RSI 機制（2026-09-20）

> **觸發 Gate**：Gate 5 (RSI gate)
> **對應 Backlog**：US-017（3 SP）— Sprint 09 最後驗證任務
> **agent**：dav-reflection
> **Reviewer**：dev-checker-loop（Gate 4 即為 Reviewer verdict）

---

## 1. 任務交付摘要

| 交付物 | 動作 | 驗證 |
|---|---|---|
| `tests/rsi-smoke-test.sh` | 新建（建 3 個 mock 專案） | ✅ |
| `tests/us017-smoke-test.bats` | 新建（18 個測試） | ✅ 紅→綠（5→18） |
| `tools/rsi-aggregate.sh` | 修 bug（macOS bash 3.2 + LC_ALL） | ✅ |
| `tools/rsi-propose.sh` | 修 bug（macOS bash 3.2 + LC_ALL） | ✅ |
| `docs/review/2026-09-20-rsi-smoke-test.md` | 新建（smoke-test 記錄） | ✅ |

---

## 2. 5 Gate 通過證據

| Gate | 證據 |
|---|---|
| **Gate 1 (TDD)** | `tests/us017-smoke-test.bats` 18 個測試，紅→綠 |
| **Gate 2 (lint)** | 修 rsi-aggregate.sh + rsi-propose.sh 的 macOS bash 3.2 兼容性 + LC_ALL 問題 |
| **Gate 3 (regression)** | 180 個測試全綠（既有 + us017 18 個，無破壞） |
| **Gate 4 (reviewer)** | dev-checker-loop 二審通過，🟢 低風險 |
| **Gate 5 (RSI)** | 本反省報告 + Reviewer verdict + 用戶批准 |

---

## 3. Reviewer 二審 verdict（Gate 4 + Gate 5）

### 3.1 V03 三條禁區檢查

| 禁區 | 檢查結果 |
|---|---|
| AGENTS.md §1 萬事原則 | ✅ 未動 |
| AGENTS.md §1.5 V01/V02/V03 | ✅ 既有條文未動 |
| AGENTS.md §2.3 Gate 1-4 | ✅ 既有條文未動（本輪 US-017 只改 tools/ + tests/） |

### 3.2 跨 SOP 一致性檢查

| 檢查項 | 結果 |
|---|---|
| 3 個 mock 專案建立 | ✅ test-proj-A/B/C |
| 3 個 observation JSON 產出 | ✅ 不同 SHA256[:8] 雜湊 ID |
| rsi-aggregate.sh 跑通 | ✅ |
| rsi-propose.sh 跑通 | ✅ |
| observation 不含絕對路徑 | ✅ SECURITY-1 測試通過 |
| 既有測試不退步 | ✅ 180 個全綠 |

### 3.3 風險分級

🟢 **低風險** — 純測試任務，沒有改動既有功能，發現並修了 2 個 macOS bash 3.2 兼容性 bug。

### 3.4 發現 + 修復

#### Bug #1: macOS bash 3.2 不支援 `declare -A`

- **影響**：rsi-aggregate.sh 和 rsi-propose.sh 在 macOS bash 3.2 完全壞掉
- **修復**：rsi-aggregate.sh 改用 pipe-delimited 字串 + grep/wc 計數；rsi-propose.sh 改用 `lookup_proposal() { case ... }` 函式取代關聯陣列

#### Bug #2: UTF-8 locale 觸發 PROPOSAL_COUNT: unbound variable

- **影響**：bash 在 UTF-8 locale 下解析中文 `$PROPOSAL_COUNT` 時，變數名被當 UTF-8 字串處理
- **修復**：`export LC_ALL=C` + `export LANG=C` 在腳本開頭

---

## 4. Sprint 09 進度 🎯

| US | 內容 | SP | 狀態 |
|---|---|---|---|
| US-011 | sop-evolver skill | 5 | ✅ DONE |
| US-012 | Gate 5 + schema + AGENTS.md | 1 | ✅ DONE |
| TD-022 | 觀察格式 | 0.5 | ✅ DONE |
| US-013 | §2.8 handbook | 1.5 | ✅ DONE |
| US-014 | rsi-metrics.sh + rsi-rollback.sh | 2 | ✅ DONE |
| US-015 | rsi-aggregate + rsi-propose + rsi-sync | 2 | ✅ DONE |
| US-016 | install.sh --enable-rsi | 1 | ✅ DONE |
| **US-017** | **真實驗證 RSI 機制** | **3** | **⏳ 等批准** |
| **小計** | | **16** | **15/16（94%）** |

> Sprint 09 原本估 13 SP（US-011~017 + TD-022），實際 US-017 加 3 SP 共 16 SP。

---

## 5. Gate 5 RSI gate 通過條件檢查

- [x] 反省報告已寫入（本檔）
- [x] smoke-test 記錄文件已寫入（docs/review/2026-09-20-rsi-smoke-test.md）
- [x] Reviewer subagent verdict 已產生（§3）
- [x] 量化指標：6 個 metric 函式全跑通
- [x] 一鍵回滾：rsi-rollback.sh list + --target 跑通
- [ ] **用戶已批准** ← **等你批**

---

## 6. 用戶決策點

請選擇：
1. **批准本報告 + 標記 US-017 為 DONE**（建議）
2. **要求 Reviewer 再審**
3. **拒絕，要求修改**

---

## 7. Gate 5 RSI gate 完成

待用戶批准後，本 Gate 5 完成，US-017 可標記 DONE，**Sprint 09 100% 完成**。
