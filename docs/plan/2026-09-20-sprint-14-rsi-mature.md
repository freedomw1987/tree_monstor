# Sprint 14 規劃 — RSI 成熟化（2026-09-20）

> **對應 §2.1 dav-planner**
> **Sprint**：Sprint 14 RSI 成熟化
> **SP**：3 SP（推薦）
> **狀態**：🟡 Planning

---

## 1. Sprint 14 主軸

**主軸**：RSI 從「主動化」進化到「成熟化」。

Sprint 13 已建立主動化能力（JSON / 1鍵部署 / dry-run）。
Sprint 14 主攻：
- **同步安全**（US-025）：rsi-sync.sh 也加 dry-run
- **規則庫健康**（US-026 + TD-038）：相似規則偵測 + review 提示

---

## 2. Sprint 14 候選任務（從 backlog Sprint 14 推薦）

| ID | 標題 | SP | 優先級 |
|---|---|---|---|
| **US-025** | rsi-sync.sh 加 dry-run | 1 | P3 |
| **US-026** | rsi-propose 加 `--show-similar` | 1 | P3 |
| **TD-038** | rules/REVIEW.md 自動產生 | 1 | P3 |
| **小計** | | **3** | |

### 2.1 US-025（1 SP）— rsi-sync.sh dry-run

**需求**：rsi-sync 從源 repo 拉更新到目標專案，目前無預覽機制。

**目標**：
- 加 `--dry-run` 旗標
- 列出將被同步的檔案清單
- 對比本地 vs 源頭 hash
- 模擬將執行的 cp / merge 操作
- ≥ 3 個 bats

**設計重點**：
- 與 rsi-rollback dry-run 對稱（兩者都是「危險操作的預覽」）
- 沿用 TD-035 隔離層

### 2.2 US-026（1 SP）— rsi-propose `--show-similar`

**需求**：SP-005 研究結論「AI 列相似規則、人類決策合併」，需實作 `--show-similar` 旗標。

**目標**：
- 加 `--show-similar` 旗標
- 列出可能有相似規則的事件（fingerprint 差 ≤ 2 字）
- 給人類建議合併方案
- ≥ 4 個 bats

**設計重點**：
- 相似度算法：Levenshtein 距離 ≤ 3
- 相似度計算用 awk 或 python（python 較容易）

### 2.3 TD-038（1 SP）— rules/REVIEW.md 自動產生

**需求**：規則庫 ≤ 20 健康，但需工具主動提醒「該 review 了」。

**目標**：
- 加 `tools/rsi-rules-review.sh`
- 規則庫 ≤ 20 自動產 review 提示
- 列相似規則（呼叫 US-026 的相似度邏輯）
- ≥ 3 個 bats

**設計重點**：
- REVIEW.md 寫入 `tools/rules/REVIEW.md`（隨 rsync 同步）
- 含健康指標 + 相似規則對

---

## 3. 預期量化指標（Sprint 14 結束）

| 指標 | Sprint 13 末 | Sprint 14 末 | 變化 |
|---|---|---|---|
| 工具 | 13 | 14（+rsi-rules-review.sh） | +1 |
| bats | 280 | 293（+13） | +13 |
| 規則庫 | 12 | 12（可能因 review 合併變少） | 0~-2 |
| FR | 24 | 27（+4.25/4.26/4.27） | +3 |
| Sprint 09-14 SP | 38.5 | **41.5** | **+3** |

---

## 4. Sprint 14 推薦組合（3 SP）

### Sprint 14 推薦組合（3 SP）

US-025 + US-026 + TD-038 = 3 SP

理由：
- US-025 補齊「危險操作預覽」（rollback + sync 雙保險）
- US-026 補齊「規則庫健康」（AI 提建議、人類決策）
- TD-038 把 US-026 的相似度邏輯應用到「定期 review」

3 個任務互補：
1. US-025：使用者面向（dry-run 安全）
2. US-026：功能面（同類規則偵測）
3. TD-038：自動面（定期 review）

---

## 5. 5 Gate 計劃

| Gate | 觸發時機 | 證據 |
|---|---|---|
| **Gate 1 (TDD)** | §2.3 開始時 | 13 新加 bats 全綠 |
| **Gate 2 (lint)** | §2.3 寫完時 | bash -n + markdownlint 0 |
| **Gate 3 (regression)** | §2.3 寫完時 | 跑所有既有 bats |
| **Gate 4 (reviewer)** | §2.2 完成時 | V03 + Reviewer APPROVED |
| **Gate 5 (RSI)** | §2.3 完成時 | 3 份 Gate 5 反省 |

---

## 6. 風險與緩解

| 風險 | 緩解 |
|---|---|
| US-025 sync dry-run 邏輯複雜 | 對齊 rsi-rollback dry-run 結構 |
| US-026 相似度算法用 python | 已在 SOP 中熟悉用法 |
| TD-038 規則 review 觸發頻率 | 預設「累積 5 個新事件才提醒」|

---

## 7. Sprint 14 完成的 RSI 能力

Sprint 14 完成後 RSI 將有完整「成熟化」能力：

```
觀察 → 聚合 → 趨勢 → 回顧 → 警告 → 反推（含相似度） → SOP 改動
  ↓
部署（含 dry-run + multi-lang）
  ↓
同步（含 dry-run）
  ↓
回滾（含 dry-run）
  ↓
規則庫 review（含相似規則提示）
```

---

## 8. Sprint 14 任務拆解

### §2.1（這個文件）+ §2.2 + §2.3

- [ ] §2.2 設計：PRD §11.7 + ADR-025/026/027 + Reviewer verdict
- [ ] §2.3 執行：
  - [ ] US-025：tools/rsi-sync.sh 加 --dry-run + ≥ 3 bats
  - [ ] US-026：tools/rsi-propose.sh 加 --show-similar + ≥ 4 bats
  - [ ] TD-038：tools/rsi-rules-review.sh 新建 + ≥ 3 bats

---

## 9. 版本

- v1.0（2026-09-20）— Sprint 14 規劃初版
