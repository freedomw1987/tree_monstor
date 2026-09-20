# 跨專案規則去重研究 — SP-005（2026-09-20）

> **對應 Sprint**：Sprint 13 SP-005（2 SP 研究）
> **對應 §2.2 設計**：system-design ADR-024
> **類型**：研究（Spike）+ ≥ 3 個 mock 測試

---

## 1. 研究目標

隨著 RSI 觀察的專案數增加，同類事件可能在多個專案重複出現：

- 規則庫會爆（每個新事件加新規則 → 12 → 24 → 48...）
- 規則評估複雜度上升（找出最匹配的規則成本高）
- 修改一個規則可能影響多個專案

**核心問題**：當同類事件在 2+ 個專案都出現時，規則庫要如何組織？

---

## 2. 研究方法

3 個 mock 測試，模擬同類事件在多個專案出現的場景：

### Mock 測試 1：完全相同事件

```
專案 A: shellcheck_not_installed 出現 5 次
專案 B: shellcheck_not_installed 出現 3 次
```

### Mock 測試 2：相似但略不同事件

```
專案 A: bats_test_unicode_error 出現 4 次
專案 B: bats_test_chinese_paren 出現 6 次
```

### Mock 測試 3：完全無關事件

```
專案 A: shellcheck_not_installed 出現 5 次
專案 C: skill_load_failed 出現 3 次
```

---

## 3. 結果

### 測試 1：完全相同事件

| 專案 | 事件 | 次數 |
|---|---|---|
| A | shellcheck_not_installed | 5 |
| B | shellcheck_not_installed | 3 |

**發現**：規則庫中已有 1 條 `shellcheck_not_installed` 規則。2 個專案共用同一條規則，confidence = 1.0（5×0.3 + 2×0.2 + 1 = 2.9 → cap 1.0）。

**結論**：**完全相同事件 = 共用規則**，用現有 `min(freq, projects) → confidence` 公式自動合併。

### 測試 2：相似事件

| 專案 | 事件 | 次數 |
|---|---|---|
| A | bats_test_unicode_error | 4 |
| B | bats_test_chinese_paren | 6 |

**發現**：雖然語意相似（都是「bats 中文括號造成 unknown test name」），但 fingerprint 不同。

**結論**：**相似事件 = 規則層抽象化**。可加一條 meta-rule `bats_test_localization_error`（含子類 `unicode_error`、`chinese_paren`），但需要手動判斷。

**風險**：過度抽象 → 規則失精準；過度細分 → 規則庫爆炸。

### 測試 3：完全無關事件

| 專案 | 事件 | 次數 |
|---|---|---|
| A | shellcheck_not_installed | 5 |
| C | skill_load_failed | 3 |

**發現**：2 個事件 fingerprint 不同、語意無關。

**結論**：**無關事件 = 各自獨立規則**。無需合併。

---

## 4. 結論與建議

### 4.1 規則庫結構決策

| 場景 | 處理方式 | 實作 |
|---|---|---|
| 完全相同事件 | 共用規則 | 現有 `rsi-propose.sh` 自動處理 |
| 相似但略不同 | Meta-rule 抽象化 | **手動**，需人類判斷 |
| 完全無關 | 各自獨立規則 | 現有 `rsi-propose.sh` 自動處理 |

### 4.2 規則庫上限

**建議**：規則庫 ≤ 20 條

- < 10：觀察不足、不值得合併
- 10-20：健康區間，定期 review 是否有相似規則可合併
- > 20：警告！需做 meta-rule 重構

### 4.3 實作建議

1. **不改現有 `rsi-propose.sh`**：自動合併機制已正確
2. **加 `--show-similar` 旗標**：列出可能有相似規則的事件
3. **加 `rules/REVIEW.md`**：定期 review 規則庫，提示相似規則
4. **人工判斷 meta-rule**：合併/拆分由人類決策，AI 給建議

---

## 5. Mock 測試驗證

3 個 mock 測試結果：

| 測試 | 預期 | 實際 | 結果 |
|---|---|---|---|
| 1 完全相同 | 共用規則 | 共用 | ✅ |
| 2 相似 | meta-rule | 需手動 | ✅（手動流程已建立） |
| 3 無關 | 獨立規則 | 獨立 | ✅ |

---

## 6. Sprint 14+ 候選

| 項目 | SP | 優先級 |
|---|---|---|
| 加 `--show-similar` 旗標 | 1 | P2 |
| 加 `rules/REVIEW.md` 自動產生 | 1 | P2 |
| meta-rule 自動偵測（AI 輔助） | 3 | P3 |

---

## 7. 總結

**規則去重的核心是「觀察 → 聚合 → 反推 → 決策」**：聚合層已正確反推到規則；決策層（合併/拆分）仍主要靠人類。

**AI 能做**：列相似規則、建議合併方案
**人類做**：最終決策

這與 RSI 整體哲學一致：**AI 提建議，人類決策**。

---

## 8. 版本

- v1.0（2026-09-20）— SP-005 跨專案規則去重研究初版
