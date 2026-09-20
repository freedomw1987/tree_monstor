# Sprint 10 RSI 增強計劃（2026-09-20）

> **Sprint**：10
> **主軸**：RSI 機制增強
> **預估總 SP**：5 SP
> **前置**：Sprint 09 ✅ DONE

---

## 1. Sprint 目標

> **讓 RSI 機制從「驗證可跑」變成「生產可信賴」** — 自動 tag、可預覽 sync、規則庫擴充、真實部署觀察。

---

## 2. 用戶故事

### 2.1 TD-031：rsi-rollback.sh 自動寫 git tag（0.5 SP，P1）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：PENDING
- **問題**：合併 RSI 改動時，要手動 git tag，容易漏

#### AC（驗收標準）

- [x] 合併 RSI 改動時自動寫 tag
- [x] tag 格式 `rsi-vYYYYMMDD-NN`（`NN` 為當天序號 01, 02, ...）
- [x] `rsi-rollback.sh list` 能列出所有 `rsi-v*` tag
- [x] `rsi-rollback.sh --target <tag>` 能回滾到指定版本
- [x] ≥ 6 個 bats 測試
- [x] shellcheck 0 warning（用 skip 機制）

#### 實作策略

- 在 `tools/rsi-rollback.sh` 加 `tag` 子命令
- `rsi-rollback.sh tag --message "<msg>"` → 自動算序號 + git tag
- 序號邏輯：grep `rsi-v2026-09-20-*` 找現有最大序號 + 1

### 2.2 TD-032：rsi-sync.sh --dry-run 列出將同步的檔案清單（0.5 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：PENDING
- **問題**：`rsi-sync.sh --dry-run` 只顯示「會同步 N 個」但不列具體檔案

#### AC（驗收標準）

- [x] 預覽同步會改的檔案清單（具體路徑 + 動作：add / modify / delete）
- [x] 含本地 vs 源頭 hash 對比
- [x] 預設不破壞（dry-run 模式）
- [x] ≥ 5 個 bats 測試
- [x] shellcheck 0 warning

#### 實作策略

- 擴充 `tools/rsi-sync.sh` 的 `--dry-run` 邏輯
- 對每個檔案：算源頭 hash + 本地 hash，比對差異
- 輸出 markdown table

### 2.3 TD-030：擴充 rsi-propose.sh 規則庫（1 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：PENDING
- **問題**：規則庫只有 3 個內建規則（prompt_too_long / skill_error / gate_skip），新觀察類型都會 fallback 到「待人工分析」

#### AC（驗收標準）

- [x] 加 5 個新內建規則（既有 3 個保留 → 共 8 個）：
  - `prompt_too_long`（已有）→ 改用 markdownlink escape
  - `skill_error`（已有）
  - `gate_skip`（已有）
  - `markdownlint_error`（新）— AGENTS.md / handbook markdownlint 違規
  - `bash_error`（新）— shellcheck 報錯或 set -e 觸發
  - `test_fail`（新）— bats 測試失敗
  - `bats_unknown`（新）— test name 編碼錯誤 unknown
  - `v02_violated`（新）— 一次問多個問題，違反 V02
- [x] AC 涵蓋每個規則（含 mock observation 觸發）
- [x] ≥ 8 個 bats 測試
- [x] shellcheck 0 warning

#### 實作策略

- 擴充 `lookup_proposal()` 函式
- 對每個新規則加 case 分支

### 2.4 US-018：Sprint 10 真實部署驗證（3 SP，P1）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：PENDING
- **問題**：Sprint 09 US-017 只用 mock 專案驗證單日，沒觀察「實際觀察 → 聚合 → 提案」整個週期

#### AC（驗收標準）

- [x] 部署 RSI **觀察模式**到 3 個 mock 專案（看但不主動 sync）
- [x] 跑 7 天，每天自動寫 observation JSON
- [x] 7 天後跑 `rsi-aggregate.sh` + `rsi-propose.sh` + `rsi-metrics.sh`
- [x] 驗證觀察/合併層次正確（裝在 mock 裡只能觀察，不會主動改 SOP）
- [x] 建議 Sprint 11 是否加規則（根據觀察到的真實類型）
- [x] 寫 1 份 7 天觀察報告（`docs/review/2026-XX-XX-sprint10-observation-report.md`）
- [x] ≥ 8 個 bats 測試

#### 實作策略

- 在 `tests/` 加 `rsi-deployment-mock.sh`（比 Sprint 09 多模擬 7 天）
- 加 `tests/us018-deployment.bats`

---

## 3. Sprint 10 順序

```
[TD-031: 0.5 SP] → [TD-032: 0.5 SP] → [TD-030: 1 SP] → [US-018: 3 SP]
   自動 tag         dry-run 列出       規則庫 5 個       7 天觀察
   ↓               ↓                  ↓                 ↓
   Gate 1~5        Gate 1~5           Gate 1~5          Gate 1~5
   ↓               ↓                  ↓                 ↓
   0.5/0.5         1.0/1.0            2.0/2.0           5.0/5.0 ✅
```

---

## 4. 依賴關係

```
TD-031 → TD-032 → TD-030 → US-018
```

- TD-031（自動 tag）可獨立做
- TD-032（dry-run 列出）依賴 TD-031（要先有 tag 系統才能 sync 回滾）
- TD-030（規則庫擴充）依賴 TD-032（要先有 dry-run 才能驗證新規則）
- US-018（真實部署）依賴 TD-030（要先有完整規則庫才部署）

---

## 5. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|
| TD-031 git tag 序號衝突 | 低 | 中 | grep 找當天最大序號 + 1 |
| TD-032 hash 計算影響效能 | 中 | 中 | 用 md5（足夠）而非 sha256 |
| TD-030 規則庫擴充打破既有 | 中 | 高 | 既有 3 規則測試必過 + 加 8 個新測試 |
| US-018 7 天太長 | 高 | 中 | Sprint 10 結束時可選縮成 3 天 |

---

## 6. 部署策略（US-018 重點）

- **模式**：只觀察，不主動 sync（用戶選擇）
- **觀察路徑**：`~/.tree-monstor/observations/{mock-project-id}/`
- **部署方式**：
  1. `tests/rsi-deployment-mock.sh`：建 3 個 mock 專案 + 模擬 7 天使用
  2. 每天寫 1 個 observation JSON（含真實的 gate_results）
  3. 7 天後跑 rsi-aggregate.sh / rsi-propose.sh / rsi-metrics.sh 看結果
- **同步觸發**：Sprint 10 結束時不主動 sync，需用戶說「sync」才 sync

---

## 7. 量化指標預期（Sprint 10 結束時）

預期 rsi-metrics.sh 跑出來：

```
1. 任務完成率：0.00% → 觀察模式不算完成
2. 規範違規次數：1~5（mock 中故意違規 3 次）
3. TD 閉環率：50.00% → TD-031 + TD-032 + TD-030 關掉，3/6
4. 跨專案觀察分佈：3 個專案 → 3 個觀察
5. AGENTS.md 字數變化：+731 → +731+150（Sprint 10 新加）
6. skill 使用頻率：11 → 11+3（sop-evolver + rsi-*）
```

---

## 8. §2.1 規劃完成

- ✅ 5 階段 SOP 進入 §2.1
- ✅ 4 個 item 登記 backlog（PENDING）
- ✅ 5 SP 估算
- ✅ 順序 + 依賴 + 風險 + 部署策略 + 驗收標準全列

下一步可進 §2.2 設計階段。
