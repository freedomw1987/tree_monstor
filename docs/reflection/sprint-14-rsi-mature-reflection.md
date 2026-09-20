# Sprint 14 反省 — RSI 成熟化（2026-09-20）

> **對應 Sprint**：Sprint 14 RSI 成熟化
> **對應 §2.4 dav-reflection**
> **SP**：3 SP（全部完成）

---

## 1. Sprint 概要

Sprint 14 完成 3 個任務（3 SP）：

| ID | 標題 | SP | 結果 |
| --- | --- | --- | --- |
| US-025 | rsi-sync --dry-run | 1 | ✅ |
| US-026 | rsi-propose --show-similar | 1 | ✅ |
| TD-038 | rules/REVIEW.md 自動產生 | 1 | ✅ |

---

## 2. 6 維度檢查

### 2.1 用戶價值（User Value）

| 問題 | 答案 |
| --- | --- |
| 用戶真的能用嗎？ | ✅ sync 前可預覽、相似規則自動列、REVIEW.md 一鍵產 |
| 解決什麼問題？ | 對稱 Sprint 13 US-024 的 dry-run 心智模型；規則庫膨脹風險前置發現；review 觸發頻率明確 |
| 是否可衡量？ | ✅ 工具 +1、bats +13、累計 SP 41.5 |

**評分**：🟢 9/10

### 2.2 流程紀律（Process）

| 問題 | 答案 |
| --- | --- |
| 5 Gate 通過？ | ✅ Gate 1（TDD 15/15）、2（lint 0 errors）、3（regression 全綠）、4（reviewer Sprint 14 verdict APPROVED）、5（RSI 3 份反省） |
| V03 RSI 必經 Reviewer 二審 | ✅ Sprint 14 §2.2 Reviewer verdict 已產出 |
| 觀察/改動分離守住 | ✅ 未動 AGENTS.md / SOUL.md / 安裝路徑 |
| backlog 狀態總覽一致 | ✅ Sprint 14 將在本檔標 Done |

**評分**：🟢 9/10

### 2.3 程式碼品質（Code）

| 問題 | 答案 |
| --- | --- |
| bash -n 通過？ | ✅ 全部 3 個工具（rsi-sync、rsi-propose、rsi-rules-review） |
| markdownlint 0 issues？ | ✅ 4 份 Sprint 14 文檔 + 3 份 Gate 5 反省全部 0 |
| TDD 紅 → 綠？ | ✅ 15 bats 先寫後實作 |
| 函式定義在呼叫前？ | ✅ cmd_similar 移到主程式開頭（避開 -u 報錯） |

**評分**：🟢 9/10

### 2.4 文件完整性（Documentation）

| 問題 | 答案 |
| --- | --- |
| Sprint 規劃有？ | ✅ docs/plan/2026-09-20-sprint-14-rsi-mature.md |
| 設計有 PRD/SystemDesign？ | ✅ docs/prd/04-self-evolution.md §11.7 + 3 ADR |
| Reviewer verdict 有？ | ✅ docs/sop/rsi-reviewer-verdict-2026-09-20-sprint14.md |
| Gate 5 RSI 反省有？ | ✅ 3 份 us025/us026/td038 |
| §2.3 執行摘要有？ | ✅ docs/sop/rsi-sprint14-execution-summary.md |

**評分**：🟢 9/10

### 2.5 可維護性（Maintainability）

| 問題 | 答案 |
| --- | --- |
| 對稱性？ | ✅ US-024（rollback dry-run）↔ US-025（sync dry-run） |
| 互鎖性？ | ✅ rsi-rules-review 呼叫 rsi-propose --show-similar（單一真理源） |
| 文件隨 rsync 同步？ | ✅ REVIEW.md 在 tools/rules/、規則庫在 docs/sop/ |
| 觸發頻率明確？ | ✅ 5 事件 / Sprint 結束 / 規則庫 ≥ 20 |

**評分**：🟢 9/10

### 2.6 安全 / 風險（Safety）

| 問題 | 答案 |
| --- | --- |
| 破壞性操作有 dry-run？ | ✅ sync（US-025） |
| AI 提建議不自動執行？ | ✅ show-similar 僅列，人類決策（依 SP-005） |
| 規則庫上限保護？ | ✅ TD-038 規則數 > 閾值時警告 |
| 子shell 失敗 fallback？ | ✅ rsi-rules-review 用 try/catch 防 rsi-propose 失敗 |
| 未動觀察/安裝路徑？ | ✅ |

**評分**：🟢 9/10

---

## 3. 量化總結

| 指標 | Sprint 13 末 | Sprint 14 末 | 變化 |
| --- | --- | --- | --- |
| RSI 工具 | 13 | 14 | +1 |
| bats 數 | 280 | 293 | +13 |
| 規則庫 | 12 | 12 | 0（REVIEW.md 尚未跑）|
| FR | 24 | 27 | +3（4.25/4.26/4.27）|
| **累計 SP** | **38.5** | **41.5** | **+3** |

### 工具演化

| Sprint | 新增工具 |
| --- | --- |
| 09-12 | rsi-aggregate / rsi-propose / rsi-review / rsi-metrics / rsi-alert / rsi-deploy / rsi-rollback / rsi-sync 等 13 個 |
| 13 | rsi-propose JSON output（既有工具擴充）|
| **14** | **rsi-rules-review（新工具，TD-038）** |

### 累計 SP（Sprint 09-14）

| Sprint | 主軸 | SP | 累計 |
| --- | --- | --- | --- |
| 09 | RSI 機制建立 | 16 | 16 |
| 10 | RSI 增強 | 5 | 21 |
| 11 | RSI 真實部署 | 6 | 27 |
| 12 | RSI 回顧 + 告警 | 5.5 | 32.5 |
| 13 | RSI 主動化 | 6 | 38.5 |
| **14** | **RSI 成熟化** | **3** | **41.5** |

---

## 4. 收穫與教訓

### 4.1 收穫

1. **對稱性設計威力**：US-024（rollback dry-run）和 US-025（sync dry-run）
   採同 pattern（列動作 + md5 對比 + 不實際執行），學習一次兩處都用。

2. **雙演算法 OR 邏輯**：prefix_sim（前綴相似度）+ Levenshtein（編輯距離）
   兩者任一滿足即視為相似，覆蓋「短字串差異」與「長字串前綴相似」兩種場景。

3. **互鎖架構**：rsi-rules-review 呼叫 rsi-propose --show-similar，
   確保「規則 review 用的是最新的相似度算法」（不重複實作、單一真理源）。

4. **規則庫保護機制**：20 條上限 + REVIEW.md 警告 + 人類決策合併（依 SP-005），
   避免規則庫膨脹到「看不懂」的程度。

### 4.2 教訓

1. **Python heredoc 在 bash 中要小心**：
   - 第一次實作 US-026 時用 `python3 << 'PYEOF' ... PYEOF`，
     在 cmd_similar 函式內 close heredoc 失敗導致 SHOW_SIMILAR 短路邏輯被當成 Python 程式碼
   - 解法：改用 `python3 -c '...'` + 變數傳遞（避免 heredoc close 問題）
   - **經驗**：bash 函式內的 Python 程式碼優先用 `-c '...'` 而非 heredoc

2. **相似度算法門檻需實測調校**：
   - Levenshtein ≤ 3 太嚴格（bats_test_unicode_error vs bats_test_chinese_paren 距離 = 9）
   - Levenshtein ≤ 12 + prefix_sim > 0.4 才合適
   - **經驗**：相似度門檻需依實際資料分布調校，不能憑直覺

3. **regex 過於寬鬆會誤判**：
   - `[a-z]+_[a-z_]+` 抓不到 `gate_skip_v1`（v1 被截掉）
   - `[a-z]+[a-z0-9_]*` 又太寬（抓到 `ules`、`vent` 等 markdown 標題片段）
   - 解法：用 `awk -F'|' '{print $3}'` 抓 markdown 表格欄位
   - **經驗**：抓 markdown 結構化資料，優先用 awk 而非 grep regex

4. **函式定義位置在 bash 很重要**：
   - `cmd_similar` 第一次放在檔案末尾，主程式開頭呼叫 → `command not found`
   - 函式定義必須在呼叫之前（即使 `set -u` 也救不了）
   - **經驗**：bash 函式一律放檔案頂部（旗標解析後）或主程式前

---

## 5. RSI 完整閉環（Sprint 14 末）

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
反推（rsi-propose.sh text + json）
  ↓
含 --show-similar（找相似規則）⭐ Sprint 14
  ↓
人類決策合併 / 拆分
  ↓
規則庫 review（rsi-rules-review.sh → tools/rules/REVIEW.md）⭐ Sprint 14
  ↓
SOP 改動（reviewer 二審）
  ↓
部署（rsi-deploy.sh 1 鍵）
  ↓
同步（rsi-sync.sh，含 --dry-run）⭐ Sprint 14
  ↓
回滾（rsi-rollback.sh，含 --dry-run）
```

**Sprint 14 新增 3 個「⭐ 成熟化」標記**，讓 RSI 從「主動化」進化到「成熟化」。

---

## 6. Sprint 15 候選

| 候選 | 說明 | SP |
| --- | --- | --- |
| Sprint 15 規則庫實戰 review | 跑 rsi-rules-review.sh + 合併 1-2 條相似規則 | 2 |
| Sprint 15 sync 衝突策略 | 自動 3-way merge（高風險） | 3 |
| Sprint 15 自動 Slack/email 通知 | REVIEW.md commit 後通知 | 2 |
| Sprint 15 rsi-propose --auto-merge | 高風險需人類審批旗標 | 3 |

**推薦**：Sprint 15 規則庫實戰 review（低風險、可驗證 Sprint 14 工具實用性）。

---

## 7. 自我評分

| 維度 | 分數 |
| --- | --- |
| 用戶價值 | 🟢 9/10 |
| 流程紀律 | 🟢 9/10 |
| 程式碼品質 | 🟢 9/10 |
| 文件完整性 | 🟢 9/10 |
| 可維護性 | 🟢 9/10 |
| 安全 / 風險 | 🟢 9/10 |
| **總分** | **🟢 9/10** |

---

## 8. 結語

Sprint 14 是 RSI「主動化 → 成熟化」的關鍵 Sprint：

1. **US-025** 讓「破壞性操作必有預覽」原則擴展到 sync
2. **US-026** 讓「AI 提建議、人類決策」原則工具有化
3. **TD-038** 讓「規則庫定期 review」原則流程化

Sprint 09-14 累計 41.5 SP，RSI 已建立完整閉環，
從「觀察 → 部署」到「review → 同步」皆具備 dry-run + 評估 + 警告機制。

下一步：§2.5 Sprint 14 提交（dav-submitter）→ commit → 進 Sprint 15 規劃。
