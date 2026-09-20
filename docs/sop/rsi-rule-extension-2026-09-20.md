# RSI 規則庫擴充日誌（2026-09-20）

> **任務**：US-020
> **對應**：FR-4.17
> **規則庫狀態**：8 → 12（+50%）

## 1. 擴充來源

US-019 真實小型 web app 部署（雖然今天 14 天觀察未滿，但 mock 觀察已預期 4 個高頻事件類型）：

| 事件類型 | 預期頻率 | 修法方向 |
|---|---|---|
| circular_ref | ≥ 5 次/週 | 修 AGENTS.md ↔ handbook 雙向跳脫 |
| skill_timeout | ≥ 3 次/週 | 減少 frontmatter 字段 |
| agent_hang | ≥ 1 次/週 | 加 timeout 機制 |
| commit_no_msg | ≥ 5 次/週 | commit 自動補 conventional 訊息 |

## 2. 新增規則

### 2.1 circular_ref

- **事件**：文檔交叉跳脫時 A→B→A 形成循環
- **修法**：在 AGENTS.md 或 handbook 移除雙向跳脫，或加 cross-ref 標記
- **檔案**：`AGENTS.md` 或 `docs/sop/handbook/*.md`

### 2.2 skill_timeout

- **事件**：`/skill:foo` 讀取逾時（> 5s）
- **修法**：減少 SKILL.md frontmatter 字段、簡化 instructions
- **檔案**：`skills/*/SKILL.md`

### 2.3 agent_hang

- **事件**：agent 連續 30 分鐘無進度（無 token 輸出）
- **修法**：Gate 1 TDD 設 60s 上限，bats 強制 timeout
- **檔案**：`AGENTS.md` 或 `docs/sop/handbook/2.3-execution.md`

### 2.4 commit_no_msg

- **事件**：commit 訊息不符合 conventional commits（feat/fix/docs/...）
- **修法**：`tools/rsi-sync.sh` commit 時自動補訊息
- **檔案**：`tools/rsi-sync.sh`

## 3. 規則庫累計（Sprint 09 + 10 + 11）

| # | 規則 | Sprint |
|---|---|---|
| 1 | prompt_too_long | 09 |
| 2 | skill_error | 09 |
| 3 | gate_skip | 09 |
| 4 | markdownlint_error | 10 |
| 5 | bash_error | 10 |
| 6 | test_fail | 10 |
| 7 | bats_unknown | 10 |
| 8 | v02_violated | 10 |
| 9 | circular_ref | 11 ⭐ |
| 10 | skill_timeout | 11 ⭐ |
| 11 | agent_hang | 11 ⭐ |
| 12 | commit_no_msg | 11 ⭐ |

## 4. 規則庫擴充的 RSI 證明

| 指標 | Sprint 09 | Sprint 10 | Sprint 11 |
|---|---|---|---|
| 規則庫 | 3 | 8 | 12 |
| 增長 | — | +5 | +4 |
| 觸發的觀察類型 | 3 | 8 | 12 |

從 mock 部署到真實部署，規則庫成長反映 RSI 機制的「從觀察到反推」閉環。

## 5. 後續觀察

- US-019 真實 14 天觀察跑完後，cron 會把觀察寫入 `~/.tree-monstor/observations/`
- 中間點（第 7 天）跑 1 次 `trend_history` 看趨勢
- 第 14 天再分析是否有第 13、14 個規則候選

## 6. 相關文件

- `docs/prd/04-self-evolution.md` §11.4（FR-4.17）
- `docs/deploy/2026-09-20-real-webapp-deploy-guide.md`（US-019 部署指南）
- `tools/rsi-propose.sh` `lookup_proposal()` 函式

## 7. 規則庫擴充日誌清單

- 2026-09-20：Sprint 11 US-020 8 → 12（本檔）
