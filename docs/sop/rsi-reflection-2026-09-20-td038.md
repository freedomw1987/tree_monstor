# Sprint 14 RSI 反省 — TD-038 rules/REVIEW.md 自動產生（2026-09-20）

## 基本資訊

- **Tech Debt**：TD-038 — tools/rules/REVIEW.md 自動產生
- **對應 SP**：1 SP
- **對應 Sprint 14 主軸**：RSI 規則庫定期 review
- **對應設計文件**：
  - docs/prd/04-self-evolution.md §11.7
  - docs/system-design.md ADR-027（rules review 原則）

## 變更摘要

1. 建 `tools/rsi-rules-review.sh`（新工具）
2. 機制：
   - 讀 `docs/sop/rsi-rules.md`（規則庫）
   - 統計（總規則數 + 按前綴分類）
   - 呼叫 `rsi-propose --show-similar` 找相似規則
   - 寫 `tools/rules/REVIEW.md`（含統計 + 相似對 + 建議合併）
   - 規則數 > 閾值（預設 20）時加警告
3. 觸發頻率（依 2.8-rsi-evolution.md §6.6）：
   - 累積 5 個新事件後提醒
   - Sprint 結束時強制
   - 規則庫 ≥ 20 條時強制

## 量化指標

| 指標 | 數值 |
| --- | --- |
| 新增/修改檔案 | 2（tools/rsi-rules-review.sh + tests/td038-rsi-rules-review.bats）|
| bats 數量 | 5（td038-1 ~ td038-5）|
| bats 通過率 | 5/5（100%）|
| markdownlint | 0 errors |

## 設計重點

### 1. REVIEW.md 結構

```markdown
# RSI 規則庫 Review
## 統計（總規則數、按前綴分類）
## ⚠️ 警告（若 > 閾值）
## 相似規則對（JSON）
## 建議合併方案（人類決策）
## 何時該跑
## 參考
```

### 2. 規則庫路徑對齊

- 規則庫：`docs/sop/rsi-rules.md`（隨 rsync 同步）
- REVIEW.md：`tools/rules/REVIEW.md`（隨 rsync 同步）

兩個檔案都隨 SOP 同步，所以 review 是「所有專案共享的標準」。

### 3. 雙腳本互鎖

- `rsi-rules-review.sh` 呼叫 `rsi-propose.sh --show-similar`
- 確保「規則 review 用的是最新的相似度算法」（不重複實作）

## 風險評估

- **風險 1**：rsi-propose 子shell 失敗導致 REVIEW.md 內容缺相似 JSON
  - **緩解**：用 try/catch（Python JSON parse 失敗回 fallback JSON）
- **風險 2**：BATS_TEST_DIRNAME 在 CLI 跑時 unbound
  - **緩解**：用 `set -uo pipefail` + `: "${BATS_TEST_DIRNAME:=}"` 預設
- **風險 3**：規則庫 markdown 表格格式變動
  - **緩解**：awk 用 `| [0-9]+ |` 嚴格匹配 + fallback

## SOP 規範遵守

- [x] TDD 紅 → 綠
- [x] 工具與現有規則庫對齊
- [x] REVIEW.md 含統計 + 相似 + 建議 + 觸發頻率
- [x] bats 覆蓋：help / 產檔 / 統計 / 相似 / 警告
- [x] markdownlint 0 errors
- [x] bash -n 通過
- [x] 不阻擋流程（規則數 > 閾值時仍 exit 0）

## 下一步

- [ ] Sprint 14 §2.4 反省
- [ ] Sprint 14 §2.5 提交
- [ ] Sprint 15 候選：自動 commit REVIEW.md 到 git + Slack/email 通知

## 反思

TD-038 是 RSI 閉環的「最後一塊拼圖」：

```
觀察 → 聚合 → 趨勢 → 回顧 → 警告
  ↓
反推（含 --show-similar）⭐
  ↓
人類決策合併 / 拆分
  ↓
規則庫 review（rules/REVIEW.md）⭐  ← TD-038
  ↓
SOP 改動（reviewer 二審）
  ↓
部署 / 同步 / 回滾（皆 --dry-run）
```

REVIEW.md 把「人類決策」這步「視覺化、結構化、可追溯」，
讓 SOP-Evolver 真正做到「自我演化」而非「無止境膨脹」。

下次若改 REVIEW.md 結構，要同步更新 `rsi-rules-review.sh` 範本。
