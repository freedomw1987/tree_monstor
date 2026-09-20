# Gate 5 RSI 反省 — Sprint 15 US-029-A 規則庫 + Review（2026-09-20）

> 對應 Sprint 15 US-029-A（建規則庫 + 跑 REVIEW.md，1 SP）

---

## 1. 學習到什麼

### 1.1 Sprint 14 工具從「未驗證」→「實戰可用」

- Sprint 14 TD-038 建了 `rsi-rules-review.sh` 但**規則庫根本不存在**
- Sprint 15 跑了實戰發現：Sprint 14 工具在第一次跑實規則庫時**有 3 個 BUG**：
  - `${TOTAL:-0}` 而非 `$TOTAL`（避免 subshell 內 unset）
  - `$(echo ... | awk ...)` 在 heredoc 內會貢獻多餘空行
  - `${WARNING_BLOCK:+$WARNING_BLOCK\n}` 即使 WARNING_BLOCK 空也會插入換行
- **沒有實戰就沒辦法發現這些 BUG**

### 1.2 Sprint 14 雙演算法的真實表現

- 12 條規則中：4 條 `markdown_*` 系列 + 3 條 `bash_*` 系列
- **結果**：6 對相似規則全部來自 `markdown_*` 系列
- **意義**：前綴相似度算法抓到「同主題集群」，而 Levenshtein 對它們區分度不足
- **驗證 Sprint 14 §2.2 設計正確**：雙演算法 OR 邏輯（prefix_sim > 0.4）能抓到同主題

### 1.3 「最小必要」原則

- 用戶提醒避免 over engineering
- Sprint 15 從 2 SP 精簡為 1 SP（不做人類決策合併）
- **節省的 SP**：1 SP 留給未來真實需求
- **啟示**：當規則庫 < 18 條時，強制合併 = 為合併而合併

---

## 2. 觀察到什麼

### 2.1 規則庫結構

- 12 條規則按前綴分類：

| 前綴 | 規則數 | 含義 |
| --- | --- | --- |
| markdown | 4 | markdown lint 常見錯 |
| bash | 3 | bash 語法陷阱 |
| shellcheck / py / json / bats / awk | 各 1 | 各類單點 |

### 2.2 實戰建議

- 規則庫 ≥ 12 條是 RSI 開始有用的**最小門檻**
- 規則庫 ≥ 18 條時應啟動人類決策合併（避免 ≥ 20 條閾值）

---

## 3. 對未來 Sprint 的影響

### 3.1 Sprint 16+ 候選調整

| 候選 | SP | 觸發條件 |
| --- | --- | --- |
| US-029-B 人類決策合併 | 1 SP | 規則庫 ≥ 18 條時啟動 |
| 規則庫 CI 整合 | 1 SP | 規則庫 ≥ 20 條 → CI fail |
| 跨專案規則去重 | 3 SP | 觀察 ≥ 2 個專案後啟動 |

### 3.2 對 SOP 的影響

- **TD-038 工具 + 規則庫實戰**已驗證 Sprint 14 的成熟化設計
- 之後每次新增規則都應跑 `rsi-rules-review.sh` 確認沒漏抓相似對
- handbook 2.8-rsi-evolution.md §6.6「規則庫 ≥ 20 條時強制 review」原則依然有效

---

## 4. 教訓

1. **不實戰 = 工具空轉**：Sprint 14 工具從未跑實規則庫，3 個 BUG 都靠 Sprint 15 實戰才暴露
2. **Heredoc 內 subshell 多空行**：`$(...)` 即使沒有輸出也會貢獻換行
3. **`set -u` 環境下要用 `${VAR:-0}` 預設**：避免 subshell 後 unset 報錯
4. **REVIEW.md 是活的**：每次新增規則後都應跑一次確認
5. **「最小必要」是 RSI 的核心**：避免為合併而合併、為 review 而 review

---

## 5. Sprint 15 量化

| 指標 | Sprint 14 末 | Sprint 15 末 | 變化 |
| --- | --- | --- | --- |
| 規則庫 | 0 | 12 | +12 |
| bats | 293 | 298 | +5 |
| FR | 27 | 28（+4.28）| +1 |
| 累計 SP | 41.5 | **42.5** | **+1** |

---

## 6. 結語

Sprint 15 用 1 SP 完成「RSI 工具從未驗證 → 實戰可用」的最後一步。

修 3 個 Sprint 14 工具的 BUG + 建 12 條規則 + 5 個新 bats 全綠。

從此 RSI 完整閉環不再只是「邏輯閉環」，而是「實戰閉環」：

```
觀察 → 聚合 → 趨勢 → 回顧 → 警告
 ↓
反推（含 --show-similar）→ 找相似規則（雙演算法 OR 邏輯）
 ↓
人類決策合併（暫緩，等規則庫 ≥ 18 條）
 ↓
規則庫 review（rsi-rules-review.sh → REVIEW.md）⭐ Sprint 15
 ↓
SOP 改動（reviewer 二審）
 ↓
部署（rsi-deploy.sh 1 鍵）
 ↓
同步（rsi-sync.sh，含 --dry-run）
 ↓
回滾（rsi-rollback.sh，含 --dry-run）
```

「規則庫 review」這個齒輪，現在有真東西可以咬了。
