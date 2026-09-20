# RSI 反思 — US-023（2026-09-20）

> **對應 Sprint**：Sprint 13 US-023
> **類型**：User Story（1 鍵部署）
> **SP**：2 SP

## 1. 做了什麼

新建 `tools/rsi-deploy.sh`，1 鍵部署小型工具或 web app。

- 支援 python / node 兩種語言
- 自動建 mock app
- 自動部署 sop-evolver skill（若 source 有）
- 自動加 cron（每日 metrics + alert）
- 自動跑 rsi-aggregate.sh 驗證部署
- 輸出部署報告（markdown + JSON）

## 2. 為什麼這樣做

Sprint 11 部署指南完成，但部署仍是手動 30 分鐘、易跳步。

| 階段 | 自動 |
|---|---|
| 建 mock app | ✅ |
| 部署 sop-evolver | ✅ |
| 加 cron | ✅ |
| 驗證部署 | ✅ |
| 輸出報告 | ✅ |
| **總時間** | **< 5 分鐘** |

## 3. 設計決策

### 3.1 預設 app type = python

python 跨平台、內建（macOS / Linux 都有），適合 mock app。

### 3.2 --yes 旗標

部署 sop-evolver skill 屬「自動寫入用戶目錄」操作，需顯式批准。

預設不部署 skill，--yes 才部署。

### 3.3 cron file 不直接 crontab 寫入

為避免誤改用戶 crontab，cron 寫到獨立 file `~/.rsi_cron_<project>`，用戶手動 `crontab ~/.rsi_cron_<project>` 載入。

## 4. 量化指標

| 指標 | 數值 |
|---|---|
| 工具總數 | 12 → 13（+rsi-deploy.sh）|
| bats 新增 | 10 個 |
| markdownlint | 0 issues |

## 5. 下一步建議

- Sprint 14+ 可加 `--app-type go` / `--app-type rust`
- 可加 `--health-check` 自動驗證 mock app 啟動成功

## 6. 版本

- v1.0（2026-09-20）— US-023 反思初版