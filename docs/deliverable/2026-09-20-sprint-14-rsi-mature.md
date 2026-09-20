# Sprint 14 交付 — RSI 成熟化（2026-09-20）

> **對應 §2.5 dav-submitter**
> **Sprint**：Sprint 14 RSI 成熟化
> **SP**：3 SP（全部完成）
> **狀態**：✅ DONE

---

## 1. Sprint 14 概要

Sprint 14 為 RSI 機制加入 3 個成熟化能力：

- **同步安全**（US-025）：rsi-sync 加 --dry-run 預覽（對齊 Sprint 13 US-024）
- **相似度計算**（US-026）：rsi-propose 加 --show-similar（前綴相似 + Levenshtein）
- **定期 review**（TD-038）：rsi-rules-review.sh 自動產 REVIEW.md

主軸：RSI 從「主動化」進化到「成熟化」。

---

## 2. 量化指標

| 指標 | Sprint 13 末 | Sprint 14 末 | 變化 |
|---|---|---|---|
| 工具總數 | 13 | 14（+rsi-rules-review.sh）| +1 |
| bats 累計 | 280 | 293 | +13 |
| FR 累計 | 24 | 27（+4.25~4.27）| +3 |
| 規則庫 | 12 | 12 | 0（REVIEW.md 尚未跑）|
| Sprint 09-14 SP | 38.5 | **41.5** | **+3** |

---

## 3. 變更檔案清單

### 3.1 新建工具（1 個）

| 工具 | SP | 用途 |
|---|---|---|
| `tools/rsi-rules-review.sh` | 1 | 自動產生 `tools/rules/REVIEW.md` |

### 3.2 工具擴充（2 個）

| 工具 | SP | 改動 |
|---|---|---|
| `tools/rsi-sync.sh` | 1 | 加 `--target` 旗標（既有 `--dry-run` 對齊 US-024）|
| `tools/rsi-propose.sh` | 1 | 加 `--show-similar` + `--rules` + `cmd_similar` 函式 |

### 3.3 新建 bats（3 檔，15 個測試）

| bats 檔 | 數量 |
|---|---|
| `tests/us025-rsi-sync-dryrun.bats` | 5 |
| `tests/us026-rsi-propose-similar.bats` | 5 |
| `tests/td038-rsi-rules-review.bats` | 5 |

### 3.4 新建文檔

| 文檔 | 對應 |
|---|---|
| `docs/plan/2026-09-20-sprint-14-rsi-mature.md` | §2.1 規劃 |
| `docs/prd/04-self-evolution.md §11.7` | §2.2 設計 |
| `docs/system-design.md` ADR-025/026/027 | §2.2 設計 |
| `docs/sop/rsi-reviewer-verdict-2026-09-20-sprint14.md` | Gate 4 |
| `docs/sop/rsi-reflection-2026-09-20-us025.md` | Gate 5 |
| `docs/sop/rsi-reflection-2026-09-20-us026.md` | Gate 5 |
| `docs/sop/rsi-reflection-2026-09-20-td038.md` | Gate 5 |
| `docs/sop/rsi-sprint14-execution-summary.md` | §2.3 摘要 |
| `docs/reflection/sprint-14-rsi-mature-reflection.md` | §2.4 反省 |

---

## 4. Gate 驗證總結

| Gate | 名稱 | 結果 |
|---|---|---|
| Gate 1 | TDD（紅 → 綠）| ✅ 15/15 bats |
| Gate 2 | lint | ✅ bash -n 通過 + markdownlint 0 errors |
| Gate 3 | regression | ✅ Sprint 13 + 12 + 10-11 全綠 |
| Gate 4 | reviewer | ✅ Sprint 14 verdict 🟡 APPROVED |
| Gate 5 | RSI | ✅ 3 份 Gate 5 反省完成 |

---

## 5. 核心設計亮點

### 5.1 對稱設計（US-025）

| 操作 | 旗標 | Sprint |
|---|---|---|
| rollback | `--dry-run` | Sprint 13 US-024 |
| **sync** | **`--dry-run`** | **Sprint 14 US-025** |

兩者採同 pattern（列動作 + md5 對比 + 不實際執行）。

### 5.2 雙演算法 OR 邏輯（US-026）

- **prefix_sim**（前綴相似度）：`bats_test_unicode_error` vs `bats_test_chinese_paren` 抓得到
- **Levenshtein ≤ 12**：`gate_skip_v1` vs `gate_skip_v2` 抓得到
- 任一滿足即視為相似

### 5.3 互鎖架構（TD-038）

```
rsi-rules-review.sh
  ↓ 呼叫
rsi-propose.sh --show-similar
  ↓ 統一相似度算法
確保規則 review 用的是最新算法（單一真理源）
```

### 5.4 規則庫保護

- 規則數 > 20（預設閾值）→ REVIEW.md 加警告
- 觸發頻率明確：5 事件 / Sprint 結束 / 規則庫 ≥ 20

---

## 6. Sprint 14 量化

| 指標 | 數值 |
|---|---|
| 工具 +1 | rsi-rules-review.sh |
| 工具擴充 +2 | rsi-sync.sh、rsi-propose.sh |
| 新增 bats | 15 |
| 新增文檔 | 9 |
| 新增 SP | 3 |
| 累計 SP（Sprint 09-14）| **41.5** |

---

## 7. Sprint 14 收穫

1. **對稱設計威力**：rollback dry-run ↔ sync dry-run 學習一次兩處都用
2. **雙演算法 OR 邏輯**：前綴相似 + 編輯距離覆蓋兩種場景
3. **互鎖架構**：rsi-rules-review 呼叫 rsi-propose --show-similar（單一真理源）
4. **規則庫保護**：20 條上限 + REVIEW.md 警告 + 人類決策合併（SP-005）

## 8. Sprint 14 教訓

1. **Python heredoc 在 bash 中要小心**：函式內的 Python 優先用 `-c '...'`
2. **相似度門檻需實測調校**：不能憑直覺，要看實際資料分布
3. **regex 過於寬鬆會誤判**：抓 markdown 表格欄位優先用 awk 而非 grep
4. **bash 函式定義位置**：必須在呼叫前，即使 `set -u` 也救不了

---

## 9. Sprint 15 候選

| 候選 | 說明 | SP |
|---|---|---|
| **規則庫實戰 review（推薦）** | 跑 rsi-rules-review.sh + 合併 1-2 條相似規則 | 2 |
| sync 衝突策略 | 自動 3-way merge（高風險）| 3 |
| 自動 Slack/email 通知 | REVIEW.md commit 後通知 | 2 |
| rsi-propose --auto-merge | 高風險需人類審批旗標 | 3 |

---

## 10. RSI 完整閉環（Sprint 14 末）

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

**Sprint 14 新增 3 個「⭐ 成熟化」標記**，RSI 從「主動化」進化到「成熟化」。

---

## 11. 結語

Sprint 14 完成 RSI 成熟化三本柱：
1. **同步安全**（US-025）
2. **相似度計算**（US-026）
3. **定期 review**（TD-038）

累計 41.5 SP（9 個 Sprint），RSI 完整閉環已建立。
從「觀察 → 部署」到「review → 同步」皆具備 dry-run + 評估 + 警告機制。

下一步：commit Sprint 14 全部交付 → 進 Sprint 15 規劃（推薦：規則庫實戰 review）。
