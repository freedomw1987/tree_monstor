# Sprint 15 交付 — 規則庫 + 實戰 review（2026-09-20）

> **對應 §2.5 dav-submitter**
> **Sprint**：Sprint 15 規則庫實戰 review（精簡版）
> **SP**：1 SP（精簡 — 只做階段 A，避免 over engineering）
> **狀態**：✅ DONE

---

## 1. Sprint 15 概要（精簡版）

Sprint 15 從原 2 SP 精簡為 1 SP：

- **階段 A**：建基礎規則庫（12 條）+ 跑 `rsi-rules-review.sh` 產 REVIEW.md
- **階段 B**（不做）：人類決策合併 — 等規則庫 ≥ 18 條再說

主軸：驗證 Sprint 14 RSI 成熟化工具的實用性。

---

## 2. Sprint 15 主要發現

### 2.1 Sprint 14 工具修了 3 個 BUG

| BUG | 原因 | 修正 |
| --- | --- | --- |
| `${TOTAL}` unbound variable | `set -u` 環境下 subshell 內 unset | `${TOTAL:-0}` 預設 |
| REVIEW.md 多空行（MD012）| heredoc 內 `$(...)` 即使空也貢獻 \n | 把 awk 輸出先存 `$PREFIX_TABLE` 變量 |
| `${WARNING_BLOCK:+$WARNING_BLOCK\n}` 即使空也插入換行 | `${VAR:+WORD}` 行為 + 後置 `\n` | 改為 `${VAR:+\n$VAR\n}` |

### 2.2 規則庫結構（12 條）

| 前綴 | 規則數 | 範例 |
| --- | --- | --- |
| markdown | 4 | md029 / md036 / md047 / md058 |
| bash | 3 | set_u / declare_a / function_before_call |
| 其他 | 各 1 | shellcheck / py / json / bats / awk |

### 2.3 Sprint 14 雙演算法實戰表現

- 6 對相似規則全部來自 `markdown_*` 系列
- **前綴相似度**抓到同主題集群，**Levenshtein ≤ 12** 對其區分度不足
- **驗證 Sprint 14 §2.2 設計正確**

---

## 3. 量化指標

| 指標 | Sprint 14 末 | Sprint 15 末 | 變化 |
| --- | --- | --- | --- |
| 規則庫 | 0（未建）| **12** | +12 |
| FR | 27 | 28（+4.28）| +1 |
| bats | 293 | 298 | +5 |
| 累計 SP | 41.5 | **42.5** | **+1** |

---

## 4. 變更檔案清單

### 4.1 新建檔（4 個）

| 檔案 | 內容 |
| --- | --- |
| `docs/sop/rsi-rules.md` | 12 條規則（規則庫）|
| `tools/rules/REVIEW.md` | 自動產出（12 條 + 6 對相似 + 統計）|
| `tests/sprint15-rules-library.bats` | 5 個新 bats |
| `docs/sop/rsi-reflection-2026-09-20-sprint15.md` | Gate 5 反省 |

### 4.2 修改檔（1 個）

| 檔案 | 改動 |
| --- | --- |
| `tools/rsi-rules-review.sh` | 修 3 個 BUG（unbound / 多空行 / WARNING_BLOCK）|

### 4.3 新建文檔（1 個）

| 文檔 | 對應 |
| --- | --- |
| `docs/plan/2026-09-20-sprint-15-rules-review.md` | §2.1 規劃（精簡版）|

---

## 5. Gate 驗證總結

| Gate | 名稱 | 結果 |
| --- | --- | --- |
| Gate 1 | TDD（紅 → 綠）| ✅ 5/5 新 bats 全綠 |
| Gate 2 | lint | ✅ bash -n + markdownlint 0 errors |
| Gate 3 | regression | ✅ Sprint 14 + 13 + 12 全綠 |
| Gate 4 | reviewer | ⏭️ 精簡版跳過（依用戶：避免 over engineering）|
| Gate 5 | RSI | ✅ 1 份 Gate 5 反省 |

---

## 6. Sprint 15 收穫

1. **不實戰 = 工具空轉**：Sprint 14 3 個 BUG 靠 Sprint 15 實戰才暴露
2. **Heredoc 內 subshell 多空行**：`$(...)` 即使沒有輸出也會貢獻換行
3. **`set -u` + subshell 後必須 `${VAR:-0}`**：避免 unset 報錯
4. **Sprint 14 雙演算法實戰正確**：抓到同主題集群
5. **「最小必要」是 RSI 的核心**：避免為合併而合併

## 7. Sprint 15 教訓

1. **實戰驗證必要**：不要依賴 mock — 真實規則庫會暴露 mock 抓不到的 BUG
2. **heredoc 內謹慎用 `$(...)`**：容易貢獻多餘換行
3. **「精簡版」是健康的心態**：當用戶提醒 over engineering 時，立即調整範圍
4. **規則庫 = RSI 的燃料**：沒規則庫，REVIEW.md 工具就沒意義

---

## 8. Sprint 16+ 候選

| 候選 | 說明 | 觸發條件 |
| --- | --- | --- |
| US-029-B 人類決策合併 | 合併 1-2 對相似規則 | 規則庫 ≥ 18 條 |
| 規則庫 CI 整合 | 規則庫 ≥ 20 條 → CI fail | 有 CI 環境時 |
| 跨專案規則去重 | 多機器規則庫同步 | 觀察 ≥ 2 個專案時 |
| 規則庫 v2 結構 | event_type 改用樹狀前綴（markdown/md029_ol_prefix + markdown/md036_emphasis 拆出共同前綴）| 規則庫 ≥ 15 條時 |

---

## 9. RSI 完整閉環（Sprint 15 末）

```
觀察 → 聚合 → 趨勢 → 回顧 → 警告
 ↓
反推（含 --show-similar）→ 找相似規則（雙演算法 OR 邏輯）
 ↓
人類決策合併（暫緩，等規則庫 ≥ 18 條）
 ↓
規則庫 review（rsi-rules-review.sh → REVIEW.md）⭐ Sprint 15（實戰）
 ↓
SOP 改動（reviewer 二審）
 ↓
部署（rsi-deploy.sh 1 鍵）
 ↓
同步（rsi-sync.sh，含 --dry-run）
 ↓
回滾（rsi-rollback.sh，含 --dry-run）
```

「規則庫 review」這個齒輪現在有 12 條真規則可以咬合，RSI 從「邏輯閉環」進化到「實戰閉環」。

---

## 10. 結語

Sprint 15 是 RSI 機制「最後一塊拼圖」：

- Sprint 09-13：建 RSI 機制（觀察/聚合/反推/部署）
- Sprint 14：成熟化（dry-run / 相似度 / review 工具）
- **Sprint 15：實戰驗證**（建規則庫 + 跑 review + 修 3 個 BUG）

累計 **42.5 SP**（Sprint 09-15，10 個 Sprint）。

下一步：依用戶選擇 — Sprint 16 規劃，或休息 / 跑實際場景驗證。
