# Sprint 09 反省（2026-01-15）

> 對應 SOP §2.4 dav-reflection 階段

## 1. 6 維度檢查

### 1.1 完整性
- 計劃 1.25 SP / 實際 1.25 SP = 100%
- 3 個 PENDING 全清 ✅

### 1.2 正確性
- 207/207 tests 全綠（含 Sprint 05-08 既有測試）
- 既有 wiki-cross-ref.bats 12 個測試**未**被新規則破壞（向後相容）
- self-review 揭露 8 P1 即時修

### 1.3 可維護性
- `wiki-index.sh` 用 Python 處理 frontmatter（避免 bash 字串處理 bug）
- `wiki-cross-ref.sh` 擴充而非重寫（保留向後相容介面）
- `--no-multimodal` 旗標提供「關掉多模組」的選項

### 1.4 可用性
- 3 個工具全部 mock 預設不需 API key
- `--help` 全部清楚
- 錯誤訊息明確（exit 2 vs 4）

### 5. 性能
- `_index.json` 用 Python JSON 序列化（無瓶頸）
- 大型 wiki（>1000 文件）場景：os.walk + 一次性 dict 收集，O(n) 線性

### 6. 安全性
- Python 處理 user input 不用 `eval`
- 不用 `os.system` / shell injection
- 前檔 `find` 用 `-print0` 處理檔名特殊字元

## 2. 學到的教訓

### 教訓 1：bash 跨平台陷阱再次出現
`local` 在 script 頂層不合法（macOS bash 3.2）。我已經在 Sprint 08 學過 `${var,,}`，
但 `local` 又踩一次。**結論：bash 3.2 對函數外 `local` 完全禁用，要用普通變數 + 命名區隔**。

### 教訓 2：cross-ref 規則改動要小心
我為了「多模組 source 也算相關」而把 AND 改成 OR，但這破壞了 Sprint 05 的 12 個既有測試。**結論：演算法擴充時，先讀既有測試當 spec**，不要隨意改 semantic。

### 教訓 3：測試 fixture 命名要一致
我寫了 `red.png` fixture 但 source 是 `a.png`。**結論：fixture 命名要與 source 一致，或 source 要與 fixture 命名一致**。

### 教訓 4：markdownlint 該 lint `.md` 不是 `.bats`
markdownlint-cli2 對 `.bats` 報 MD023。**結論：globs 限制 `.md` only**，bats 走 shell lint。

## 3. Sprint 10 / 後續

| 項目 | 優先 | 說明 |
| --- | --- | --- |
| FR-3 深化：image similarity hash | P1 | 找重複 / 相似圖片 |
| 真實 OCR + Vision API 整合 | P2 | 需 API key（可選）|
| 自動 deprecation（Sprint 09 預留）| P2 | TD-019 方案 A 實作 |
| wiki-merge-media 強化：合併 metadata | P3 | 已有 frontmatter 整合 |

## 4. 累積狀態

```
Sprint 04-07:  110 tests (dfc59fa)
Sprint 08:     189 tests (5a17444) — 視覺驗證 + 多模組
Sprint 09:     207 tests (即將 commit) — OCR + 多模組索引

PENDING: 17 → 3 → 0
DONE:    27 → 41 → 44

FR 全部狀態:
- FR-2.1.* ✅ (Sprint 08)
- FR-2.2.* ✅ (Sprint 08 + 09)
- FR-2.3.* ✅ (Sprint 08)
- FR-2.4.* ✅ (Sprint 08)
- FR-2.5.* ✅ (Sprint 09)
- FR-2.6.* ✅ (Sprint 08)
```

## 5. 用戶決策（接下來）

### A. Sprint 10 規劃

可選方向：
- FR-3 深化（image similarity）
- 自動 deprecation
- 真實 API 整合

### B. 收尾 + 換方向

dav-wiki M3 模組完成 ✅，可換其他模組方向：
- M4: 知識圖譜視覺化
- M5: 自動寫作助理
- M6: 跨模組檢索

### C. 文件 / installer / 整合

README 更新、CI badge 補 URL、其他生態整合。

## 6. Reflection 維度

| 維度 | 評分 |
| --- | --- |
| 完整性 | ⭐⭐⭐⭐⭐ |
| 正確性 | ⭐⭐⭐⭐⭐ |
| 可維護性 | ⭐⭐⭐⭐⭐ |
| 可用性 | ⭐⭐⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐ |
| 安全性 | ⭐⭐⭐⭐⭐ |
