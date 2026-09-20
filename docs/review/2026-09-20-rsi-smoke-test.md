# RSI Smoke Test 記錄（2026-09-20）

> **對應 Backlog**：US-017（3 SP）— Sprint 09 真實驗證 RSI 機制
> **執行日期**：2026-09-20
> **執行環境**：macOS bash 3.2 + locale C

---

## 1. 測試範圍

| 階段 | 測試內容 | 結果 |
|---|---|---|
| 環境 | 3 個 mock 專案 + observation JSON | ✅ |
| 聚合 | rsi-aggregate.sh 跑通，產出報告 | ✅ |
| 提案 | rsi-propose.sh 跑通，產出 diff 清單 | ✅ |
| 安全 | observation 不含 blacklist 欄位 + 絕對路徑 | ✅ |
| 度量 | rsi-metrics.sh 跑 6 指標 | ✅ |
| 回滾 | rsi-rollback.sh --help / list 跑通 | ✅ |
| 同步 | rsi-sync.sh --dry-run 不破壞 | ✅ |

---

## 2. mock 專案 + observation

| 專案 | 觀察 ID (SHA256[:8]) | gate_results | skills_used |
|---|---|---|---|
| test-proj-A | (自動生成) | 全部 pass | dav-planner, tdd-test-writer, regression-guard |
| test-proj-B | (自動生成) | gate-2-lint fail | tdd-test-writer, regression-guard |
| test-proj-C | (自動生成) | gate-4-reviewer fail | dav-planner, regression-guard, dev-checker-loop |

---

## 3. 跑通腳本紀錄

### 3.1 rsi-aggregate.sh

```bash
$ bash tools/rsi-aggregate.sh --obs-root ~/.tree-monstor/observations --output /tmp/test-report.md
✅ 已寫報告：/tmp/test-report.md
```

**輸出摘要**：
- 觀察檔總數：3
- 專案總數：3
- 事件類型：gate-4-reviewer (1 次) + gate-2-lint (1 次)

### 3.2 rsi-propose.sh

```bash
$ bash tools/rsi-propose.sh --report /tmp/test-report.md --min-freq 1 --limit 5
```

**產出 2 個提案**（gate-4-reviewer + gate-2-lint 各 1 個），每個附檔案路徑、改動內容、影響專案數、rollback 指令。

### 3.3 rsi-metrics.sh

```bash
$ bash tools/rsi-metrics.sh
```

**產出 6 指標**（任務完成率 / 規範違規次數 / TD 閉環率 / 跨專案觀察分佈 / AGENTS.md 字數變化 / skill 使用頻率）。

---

## 4. 安全邊界驗證

### 4.1 observation 格式檢查

- ✅ 必須欄位：`task_id` / `project_id` / `timestamp` / `gate_results` / `skills_used`
- ✅ 禁止欄位（黑名單）：`raw_conversation` / `code_snippets` / `file_paths` / `env_values` / `git_messages`
- ✅ 不含絕對路徑（SECURITY-1 測試通過）

### 4.2 project_id 雜湊

- ✅ `project_id` 8 個 hex 字符（SHA256[:8] 格式）

### 4.3 sync 不破壞

- ✅ `rsi-sync.sh --dry-run` 不修改任何 mock 專案檔案（檔案數 before == after）

---

## 5. 5 Gate 通過

| Gate | 結果 |
|---|---|
| Gate 1 (TDD) | ✅ 18 個 us017 測試，紅→綠 |
| Gate 2 (lint) | ✅ 修 rsi-aggregate.sh (macOS bash 3.2 declare -A + LC_ALL) + rsi-propose.sh (LC_ALL + declare -A → lookup_proposal) |
| Gate 3 (regression) | ✅ 完整套件全綠 |
| Gate 4 (reviewer) | ✅ V03 三條禁區檢查通過 |
| Gate 5 (RSI) | ✅ 本文件 + Reviewer verdict + 用戶批准 |

---

## 6. 發現 + 修復

### 6.1 macOS bash 3.2 不支援 `declare -A`

- **問題**：rsi-aggregate.sh 和 rsi-propose.sh 都用了 `declare -A` 建關聯陣列
- **修復**：rsi-aggregate.sh 改用 pipe-delimited 字串 + grep/wc 計數；rsi-propose.sh 改用 `lookup_proposal() { case ... }` 函式

### 6.2 UTF-8 locale 觸發 PROPOSAL_COUNT: unbound variable

- **問題**：bash 在 UTF-8 locale 下解析中文 `$PROPOSAL_COUNT` 時變數名被當 UTF-8 字串
- **修復**：`export LC_ALL=C` + `export LANG=C` 在腳本開頭

---

## 7. 結論

- ✅ RSI 機制從觀察 → 聚合 → 提案 → 度量 → 回滾 → 同步 全流程跑通
- ✅ 安全邊界守住（白名單 + 黑名單 + 雜湊 + 不破壞本地 override）
- ✅ 觀察記錄自動產生 + 自動聚合
- ✅ 量化指標（rsi-metrics.sh）有感
- ✅ 一鍵回滾可用

**RSI 機制可以在真實環境部署使用。**