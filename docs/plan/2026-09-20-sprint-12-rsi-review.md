# Sprint 12 RSI 回顧 + 回歸警告計劃（2026-09-20）

> **Sprint**：12
> **主軸**：RSI 回顧 + 回歸警告
> **預估總 SP**：5.5 SP
> **前置**：Sprint 09 ✅ DONE（16 SP）、Sprint 10 ✅ DONE（5 SP）、Sprint 11 ✅ DONE（6 SP）

---

## 1. Sprint 目標

> **讓 RSI 機制從「部署上線」進化到「持續監控 + 回歸警告」** — 14 天 cron.log 跑完後用真實觀察回顧並反推規則庫成長（12→14+），同時加回歸警告機制讓觀察數下降 30% 時自動告警，避免靜默失效。

---

## 2. 用戶故事

### 2.1 US-021：真實觀察 14 天後回顧 + 從 cron.log 反推新規則（3 SP，P1）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：Sprint 11 部署指南已建、cron 已設，但 14 天後要分析 cron.log 是否產生新規則候選

#### AC（驗收標準）

- [ ] 跑 `rsi-aggregate.sh` 聚合 14 天 cron.log 觀察
- [ ] 分析 `trend_history --days 14` 趨勢
- [ ] 識別是否有第 13、14 個規則候選
- [ ] 寫 1 份 `docs/review/2026-10-04-rsi-real-deploy-result.md`
- [ ] ≥ 6 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 從 `~/.tree-monstor/cron.log` 讀 14 天 metrics 累計
- 用 `rsi-aggregate.sh` 聚合
- 跑 `rsi-propose.sh --confidence 0.5 --min-freq 3` 看新候選
- 如有新事件類型，加到 `lookup_proposal()`，否則做「無新事件」報告

### 2.2 US-022：rsi-metrics 加回歸警告（2 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：當前 RSI 是「事後看」，沒有「觀察數下降」告警

#### AC（驗收標準）

- [ ] 加 `tools/rsi-alert.sh` 工具
- [ ] 觀察數下降 30%+ 觸發告警
- [ ] 設基線（≥ 0.7 confidence 的歷史平均值）
- [ ] 告警輸出到 stderr + log file
- [ ] ≥ 5 個 bats 測試
- [ ] markdownlint 0 issues

#### 實作策略

- 建 `rsi-alert.sh`：讀 cron.log 對比基線
- 公式：當前觀察數 / 基線觀察數 < 0.7 → 告警
- 整合到 cron（每日跑 metrics + alert）

### 2.3 TD-035：修 `local -a arr=()` 在 `set -u` 下報 unbound（0.5 SP，P2）

- **模組**：M4 — Self-Evolution (RSI)
- **對應 backlog**：🟡 Backlog
- **問題**：Sprint 11 留下技術債，macOS bash 3.2 + set -u 不支援 `local -a arr=()`

#### AC（驗收標準）

- [ ] 全 sprint 10/11 工具改用 string 累加
- [ ] ≥ 4 個 bats 驗證
- [ ] markdownlint 0 issues

#### 實作策略

- 修 `tools/rsi-metrics.sh` `trend_history()` 函式
- 修 `tools/rsi-propose.sh` `calc_confidence()` 相關
- 加 `tests/td035-bash-setu.bats`

---

## 3. 順序與依賴

```
TD-035 ──┐
         ├──► US-022 ──► US-021（建議順序，技術債先清、回歸警告優先）
                 ▲
                 │
              US-021 依賴 14 天觀察（10/04 前完成）
```

### 執行順序

1. **TD-035**（0.5 SP）— 清技術債
2. **US-022**（2 SP）— 加回歸警告
3. **US-021**（3 SP）— 14 天回顧

---

## 4. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| TD-035 改 string 累加破壞既有功能 | 🟡 中 | 🟢 低 | 既有 60 sprint 10/11 bats 當回歸 |
| US-022 警告閾值設錯（0.7 太鬆/緊） | 🟡 中 | 🟡 中 | 先用 mock 測試 + 對 3 個歷史場景驗證 |
| US-021 14 天觀察沒新事件 → 無規則候選 | 🟡 中 | 🟢 低 | 降門檻（freq × 0.5 仍算） |
| US-021 用戶沒跑過 14 天 cron | 🟡 中 | 🟢 低 | 從今天起跑、14 天後自動產 review |

---

## 5. Sprint 12 量化指標預期

| 指標 | Sprint 11 末 | Sprint 12 預期 | 變化 |
|---|---|---|---|
| 工具 | 6 | 7（＋rsi-alert.sh） | +1 |
| 規則庫 | 12 | 12~14 | +0~2 |
| bats 累計 | 235 | 250 | +15 |
| 真實觀察天數 | 0（剛部署）| 14 | +14 |
| FR | 17 | 19 | +2 |

---

## 6. Sprint 12 預期效益

- RSI 機制從「被動觀察」升級到「主動監控」
- 14 天回顧產出第一份真實觀察報告
- 技術債清掉，後續 sprint 不會被 TD-035 卡住

---

## 7. 下一步

進 §2.2 設計（PRD §11.5 + system-design.md ADR-018/019 + Reviewer verdict）。
