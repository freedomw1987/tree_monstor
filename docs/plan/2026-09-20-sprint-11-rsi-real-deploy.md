# Sprint 11 RSI 真實部署 + 規則庫擴充計劃（2026-09-20）

> **Sprint**：11
> **主軸**：真實部署 + 規則庫擴充
> **預估總 SP**：6 SP
> **前置**：Sprint 09 ✅ DONE（16 SP）、Sprint 10 ✅ DONE（5 SP）

---

## 1. Sprint 目標

> **讓 RSI 機制從「mock 驗證」變成「真實部署」** — 部署到 1 個輕量小型 web app 觀察 14 天，再用真實觀察反推擴充規則庫（8→12+），加 30 天 trend 和 confidence score 兩項基礎增強。

---

## 2. 用戶故事

### 2.1 TD-033：rsi-metrics.sh 加 30 天滑動 trend（0.5 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：當前 metrics 只能看「當下快照」，沒有歷史趨勢

#### AC（驗收標準）

- [ ] `rsi-metrics.sh trend_history` 子命令
- [ ] 顯示 30 天滑動視窗
- [ ] ≥ 4 個指標有 trend（completion_rate / td_close_rate / violation_count / skill_usage）
- [ ] 趨勢用 sparkline 或 ASCII bar 顯示
- [ ] ≥ 5 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 在 `tools/rsi-metrics.sh` 加 `trend_history` 子命令
- 從 `~/.tree-monstor/observations/` 抓最近 30 天的 daily metrics
- 畫 sparkline（用 `awk` 或 `printf` 字符）

### 2.2 TD-034：rsi-propose.sh 加 confidence score（0.5 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：當前 propose 沒有「信心分數」，容易把噪音當提案

#### AC（驗收標準）

- [ ] 計算每個提案的 confidence（0~1）
- [ ] ≥ 0.7 才列為主要提案
- [ ] < 0.7 列為「需人工確認」
- [ ] ≥ 5 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 在 `tools/rsi-propose.sh` 加 confidence 計算（基於觀察次數 / 跨專案數）
- 公式：confidence = `min(1.0, freq × 0.3 + projects × 0.2 + 1)`
- 預設 threshold 0.7

### 2.3 US-019：真實部署到輕量小型 web app 14 天（3 SP，P1）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：Sprint 09/10 都用 mock 驗證，沒有真實跨專案訊號

#### AC（驗收標準）

- [ ] 選 1 個輕量小型 web app（如 Express.js / Flask / Sinatra）
- [ ] 用 `install.sh --enable-rsi` 裝 RSI 觀察模式
- [ ] 啟用每日 cron（`rsi-metrics.sh` 每日跑一次）
- [ ] 觀察 14 天（每天驗證 observation 寫入正確）
- [ ] 結束後跑 `rsi-metrics.sh trend_history` 看 14 天趨勢
- [ ] 寫 1 份真實觀察趨勢報告
- [ ] 觀察/改動分離守住（不破壞 web app 本體）
- [ ] ≥ 8 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 選 Express.js Hello World 或 Flask Hello World
- 部署到 `~/.tree-monstor/projects/web-app-test/`
- 設 cron `0 0 * * *` 跑 `rsi-metrics.sh`
- 14 天後產出 `docs/review/2026-10-04-rsi-real-deploy.md`

### 2.4 US-020：從真實觀察反推 + 補規則（8→12+，2 SP，P1）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：Sprint 10 規則庫只有 8 個，可能漏常見失敗訊號

#### AC（驗收標準）

- [ ] 分析 US-019 14 天觀察資料
- [ ] 找出 ≥ 4 個新常見事件類型
- [ ] 加 4 個新規則到 `lookup_proposal()`（8→12）
- [ ] AC 涵蓋每個新規則
- [ ] ≥ 8 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 跑 `rsi-aggregate.sh` 對 US-019 觀察聚合
- 用 `rsi-propose.sh --confidence 0.5` 找候選
- 從候選挑 ≥ 4 個新常見類型
- 加到 `lookup_proposal()` case 列表

---

## 3. 順序與依賴

| 順序 | ID | 內容 | 為什麼這個順序 |
|---|---|---|---|
| 1 | TD-033 | rsi-metrics 加 30 天 trend | 為 US-019 鋪路（沒 trend 看不到跨日變化）|
| 2 | TD-034 | rsi-propose 加 confidence | 為 US-020 鋪路（沒 score 不知提案可不可信）|
| 3 | US-019 | 真實部署 14 天 | 用 TD-033/034 工具做觀察 |
| 4 | US-020 | 從 US-019 反推補規則 | 用 TD-034 confidence 篩選 |

## 4. 依賴圖

```
TD-033 ──┐
         ├──► US-019 ──► US-020
TD-034 ──┘
```

- TD-033 與 TD-034 互相獨立
- US-019 依賴 TD-033/034（用 trend 和 confidence 工具）
- US-020 依賴 US-019（用其 14 天觀察資料）

## 5. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| TD-033 sparkline 在 macOS bash 排版亂 | 低 | 中 | 用 printf `▁▂▃▄▅▆▇█` 8 級字符 |
| TD-034 信心分數門檻定錯 | 中 | 中 | 預設 0.7（待 US-019 觀察再調）|
| US-019 web app 沒觸發任何 gate | 高 | 高 | 故意在 web app 加些違反 gate 的小動作（如少測試）|
| US-019 14 天太長 | 中 | 中 | 中間點可跑 1 次 trend 確認有效 |
| US-020 觀察沒新事件類型 | 中 | 高 | 用 `rsi-aggregate.sh` 看全部事件，必要時降門檻 |
| 真實部署破壞 web app | 低 | 高 | 觀察/改動分離 + dry-run 預設 + install --enable-rsi 不改原專案 |

## 6. 部署方式（觀察/改動分離）

- 用 `install.sh --enable-rsi --target /path/to/web-app`
- install.sh 不動 web app 本體，只在 `web-app/.pi/sop/` 加 RSI 觀察
- observation 寫到 `~/.tree-monstor/observations/`
- 同步 SOP 用 `--dry-run` 預設
- 一鍵回滾用 `rsi-rollback.sh`

## 7. 量化指標預期（結束時）

| 指標 | Sprint 10 末 | Sprint 11 預期 | 變化 |
|---|---|---|---|
| 內建規則 | 8 | 12+ | +4 |
| 真實觀察專案 | 0 | 1（web app） | +1 |
| 觀察天數 | 1（mock） | 14（web app）| +13 |
| AGENTS.md 字數 | 推測 +881 | 推測 +1000 | +119 |
| skill 使用 | 推測 14 | 推測 16 | +2 |

## 8. 規劃完成

- [x] Sprint 目標明確（真實部署 + 規則庫擴充）
- [x] 4 個 item AC 完整
- [x] 順序與依賴確認（TD-033/034 → US-019 → US-020）
- [x] 風險識別與緩解
- [x] 量化指標預期

請用戶批准 §2.1 進 §2.2 設計階段。
