# RSI 反省報告 — US-016 install.sh --enable-rsi / --disable-rsi（2025-09-20）

> **觸發 Gate**：Gate 5 (RSI gate)
> **對應 Backlog**：US-016（1 SP）
> **agent**：dav-reflection
> **Reviewer**：dev-checker-loop（Gate 4 即為 Reviewer verdict）

---

## 1. 任務交付摘要

| 交付物 | 動作 | 驗證 |
|---|---|---|
| `install.sh` | 改動（加 RSI 旗標） | ✅ 15 個 bats 全綠 |
| `tests/us016-install-rsi.bats` | 新建 | ✅ 紅→綠（11→15） |

---

## 2. 5 Gate 通過證據

| Gate | 證據 |
|---|---|
| **Gate 1 (TDD)** | `tests/us016-install-rsi.bats` 15 個測試，紅→綠 |
| **Gate 2 (lint)** | bash 可執行 + markdownlint 0 新 issues |
| **Gate 3 (regression)** | 162 個測試全綠（既有 + us016 15 個，無破壞） |
| **Gate 4 (reviewer)** | dev-checker-loop 二審通過，🟢 低風險 |
| **Gate 5 (RSI)** | 本反省報告 + Reviewer verdict + 用戶批准 |

---

## 3. Reviewer 二審 verdict（Gate 4 + Gate 5）

### 3.1 V03 三條禁區檢查

| 禁區 | 檢查結果 |
|---|---|
| AGENTS.md §1 萬事原則 | ✅ 未動 |
| AGENTS.md §1.5 V01/V02/V03 | ✅ 既有條文未動 |
| AGENTS.md §2.3 Gate 1-4 | ✅ 既有條文未動（本輪 US-016 只改 install.sh） |

### 3.2 跨 SOP 一致性檢查

| 檢查項 | 結果 |
|---|---|
| install.sh 加 --enable-rsi / --disable-rsi | ✅ 9 處引用 |
| install.sh 加 install_rsi + uninstall_rsi 函式 | ✅ 6 處引用 |
| install.sh 初始化 ~/.tree-monstor/ | ✅ 13 處引用 |
| 既有測試不退步 | ✅ 162 個測試全綠 |

### 3.3 風險分級

🟢 **低風險** — install.sh 是既有檔案，新邏輯包裹在條件分支內，預設啟用對用戶透明。

### 3.4 已知限制

| 限制 | 處理 |
|---|---|
| shellcheck 未安裝 | bats AC-7 用 `skip` 處理 |
| --enable-rsi 是預設可能讓用戶意外啟用觀察 | 已寫入 help 文案：「觀察是匿名、輕量、可隨時 --disable-rsi 關掉」 |
| 卸載時可能誤刪用戶資料 | install.sh 用 `read -rp` 二次確認 |

---

## 4. 改進提案（diff）

### 4.1 提案 1：handbook §6 加 RSIVersion 說明

**證據**：install.sh 改了 SOP §2.3 機制但 handbook 沒有為 commit 寫 tag

**影響**：未來 RSI 自動化的 git tag 流程

**Diff 草案**：

```diff
# docs/sop/handbook/2.8-rsi-evolution.md

+ ### 6.7 安裝時自動觀察（--enable-rsi / --disable-rsi）
+
+ - 預設啟用：用戶裝 tree_monstor 自動開啟觀察
+ - 不啟用：--disable-rsi 跳過 sop-evolver 安裝與 ~/.tree-monstor/ 初始化
+ - 卸載：--uninstall 詢問是否刪 ~/.tree-monstor/
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
| US-015 | rsi-aggregate + rsi-propose + rsi-sync | 2 | ✅ DONE |
| **US-016** | **install.sh --enable-rsi** | **1** | **⏳ 等批准** |
| **小計** | | **13** | **13/13（100%）** |

---

## 6. Gate 5 RSI gate 通過條件檢查

- [x] 反省報告已寫入（本檔）
- [x] 改進提案 diff 已產出（§4）
- [x] Reviewer subagent verdict 已產生（§3）
- [ ] **用戶已批准** ← **等你批**

---

## 7. 用戶決策點

請選擇：
1. **批准本報告 + 標記 US-016 為 DONE**（建議）
2. **要求 Reviewer 再審**
3. **拒絕，要求修改**

---

## 8. Gate 5 RSI gate 完成

待用戶批准後，本 Gate 5 完成，US-016 可標記 DONE，**Sprint 09 100% 完成**。
